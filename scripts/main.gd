extends Node3D

## Builds the two split-screen views and runs the race.
##
## A course runs from a start line to a finish line rather than looping. When
## either player reaches the end, a fresh course is generated and both cars are
## held still for a moment so the players can read it before setting off again.
##
## The cars live here, in the main scene, so they share one World3D and can
## collide with each other. Each SubViewport inherits that same world and
## contributes only its own camera, which is what makes split screen work
## without duplicating the level.

## Visual layers carrying each player's private overlay. Because both halves
## of the screen render the same world, anything on these layers has to be
## culled by the other player's camera or it shows up in both views.
const LAYER_WORLD := 1
const LAYER_P1_ONLY := 2
const LAYER_P2_ONLY := 3

const ALL_LAYERS := 0xFFFFF  # Godot's 20 visual layers

@onready var _car1: Car = $Car1
@onready var _car2: Car = $Car2
@onready var _camera1: ChaseCamera = $Split/TopView/SubViewport/Camera
@onready var _camera2: ChaseCamera = $Split/BottomView/SubViewport/Camera
@onready var _arrow1: RivalArrow = $ArrowP1
@onready var _arrow2: RivalArrow = $ArrowP2
@onready var _track: Track = $Track

@export_group("Starting grid")
## Sideways offset from the centreline, in metres.
@export var grid_spread := 3.6
## How far past the start line the cars are placed.
@export var grid_offset := 10.0
## Ride height above the road surface at the spawn point.
@export var grid_clearance := 0.05

@export_group("Race")
## Seed for the first course. Zero picks a random one each run.
@export var starting_seed := 0
## How long the cars are held still after a new course appears, so the players
## can look at what they are about to drive.
@export var preview_seconds := 3.0
## A car further than this from the centreline is not really on the course, so
## it cannot trip the finish line from somewhere out in the scenery.
@export var finish_corridor := 25.0

var _cars: Array[Car] = []
var _racing := false


func _ready() -> void:
	_cars = [_car1, _car2]
	_car1.rival = _car2
	_car2.rival = _car1

	_new_course(starting_seed if starting_seed != 0 else randi())

	# Each player sees an arrow in the *other* car's colour.
	_arrow1.setup(_car1, _car2, _car2.body_color, LAYER_P1_ONLY, _camera1)
	_arrow2.setup(_car2, _car1, _car1.body_color, LAYER_P2_ONLY, _camera2)

	# Show everything except the rival's private layer. Subtracting one layer
	# rather than listing the wanted ones means anything added to the world
	# later is visible to both players by default.
	_camera1.cull_mask = ALL_LAYERS & ~_bit(LAYER_P2_ONLY)
	_camera2.cull_mask = ALL_LAYERS & ~_bit(LAYER_P1_ONLY)

	_racing = true


func _physics_process(_delta: float) -> void:
	if not _racing:
		return
	for car in _cars:
		if _has_finished(car):
			_finish_course()
			return


func _bit(layer: int) -> int:
	return 1 << (layer - 1)


## The curve's points are in the Track node's own space. Going through its
## transform keeps the grid and the finish line correct even if that node is
## moved or scaled, rather than silently assuming it sits at the origin.
func _to_world(local: Vector3) -> Vector3:
	return _track.global_transform * local


func _to_track(world: Vector3) -> Vector3:
	return _track.global_transform.affine_inverse() * world


## A car finishes by reaching the end of the course while still on it. The
## corridor check matters because a car lost out in the mountains can project
## onto any part of the centreline, including the finish.
func _has_finished(car: Car) -> bool:
	var curve := _track.curve()
	var offset := curve.get_closest_offset(_to_track(car.global_position))
	# The track owns where the finish is, so the painted line and the race
	# cannot drift apart.
	if offset < _track.finish_offset():
		return false
	var centre := _to_world(curve.sample_baked(offset))
	return car.global_position.distance_to(centre) < finish_corridor


## Lay out a new course and put the cars on the line.
func _new_course(course_seed: int) -> void:
	_track.generate(course_seed)
	_place_on_grid()
	# Snap both cameras, or they fly across the world to the new grid.
	_camera1.follow(_car1)
	_camera2.follow(_car2)


## Swap in a fresh course, then hold the cars still long enough for the players
## to read it before letting them go.
func _finish_course() -> void:
	_racing = false
	for car in _cars:
		car.frozen = true
		car.reset_motion()

	_new_course(randi())

	await get_tree().create_timer(preview_seconds).timeout

	for car in _cars:
		car.frozen = false
	_racing = true


## Line the cars up side by side on the start line, facing down the course.
## Deriving the grid from the curve means it keeps working for every course.
func _place_on_grid() -> void:
	var curve := _track.curve()
	var here := _to_world(curve.sample_baked(grid_offset))
	var ahead := _to_world(curve.sample_baked(grid_offset + 1.0))

	var forward := ahead - here
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		push_warning("Main: degenerate course tangent at the start")
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var across := forward.cross(Vector3.UP)

	# Keep the grid on the road even if the course opens narrow.
	var room: float = maxf(_track.half_width_at(grid_offset) - 1.6, 0.5)
	var side: float = minf(grid_spread, room)

	for i in _cars.size():
		var car := _cars[i]
		car.global_position = (here
				+ across * (side if i % 2 == 1 else -side)
				+ Vector3.UP * grid_clearance)
		# look_at aims -Z, which is the car's forward.
		car.look_at(car.global_position + forward, Vector3.UP)
