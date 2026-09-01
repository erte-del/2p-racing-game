extends Node3D

## Builds the two split-screen views and runs the race loop.
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

## How many sectors a lap is split into for checkpoint purposes.
const SECTORS := 4

@onready var _car1: Car = $Car1
@onready var _car2: Car = $Car2
@onready var _camera1: ChaseCamera = $Split/TopView/SubViewport/Camera
@onready var _camera2: ChaseCamera = $Split/BottomView/SubViewport/Camera
@onready var _arrow1: RivalArrow = $ArrowP1
@onready var _arrow2: RivalArrow = $ArrowP2
@onready var _track: Track = $Track

@export_group("Starting grid")
## Sideways offset from the racing line, in metres.
@export var grid_spread := 3.6
## How far the second car starts back along the track, in metres.
@export var grid_stagger := 6.0
## Ride height above the road surface at the spawn point.
@export var grid_clearance := 0.05

@export_group("Race")
## Seed for the first track. Zero picks a random one each run.
@export var starting_seed := 0
## How long the cars are held still after a new track appears, so the players
## can look at what they are about to drive.
@export var preview_seconds := 3.0

var _cars: Array[Car] = []
## Distance along the curve where each car started this track.
var _spawn_offset := PackedFloat32Array()
## The sector each car must reach next. A lap counts only when all four are
## passed in order, which is the only way to tell a car that has driven round
## from one that is simply sitting just behind the line: both read as almost a
## full lap of progress. These sectors become Phase 6's checkpoints.
var _next_sector: Array[int] = []
var _racing := false


func _ready() -> void:
	_cars = [_car1, _car2]
	_car1.rival = _car2
	_car2.rival = _car1

	var first := starting_seed if starting_seed != 0 else randi()
	_track.generate(first)
	_place_on_grid()

	_camera1.follow(_car1)
	_camera2.follow(_car2)

	# Each player sees an arrow in the *other* car's colour.
	_arrow1.setup(_car1, _car2, _car2.body_color, LAYER_P1_ONLY, _camera1)
	_arrow2.setup(_car2, _car1, _car1.body_color, LAYER_P2_ONLY, _camera2)

	# Show everything except the rival's private layer. Subtracting one layer
	# rather than listing the wanted ones means anything added to the world
	# later is visible to both players by default.
	_camera1.cull_mask = ALL_LAYERS & ~_bit(LAYER_P2_ONLY)
	_camera2.cull_mask = ALL_LAYERS & ~_bit(LAYER_P1_ONLY)

	_start_racing()


func _physics_process(_delta: float) -> void:
	if not _racing:
		return
	var lap := _track.curve().get_baked_length()
	for i in _cars.size():
		var sector := _sector_of(_progress_of(i), lap)
		if sector != _next_sector[i]:
			continue
		_next_sector[i] = (sector + 1) % SECTORS
		# Arriving back in the first sector, having passed the rest in order,
		# is a completed lap.
		if sector == 0:
			_finish_lap()
			return


func _bit(layer: int) -> int:
	return 1 << (layer - 1)


## How far this car has travelled round the lap from where it started.
func _progress_of(index: int) -> float:
	var curve := _track.curve()
	var lap := curve.get_baked_length()
	var here := curve.get_closest_offset(_cars[index].global_position)
	return fposmod(here - _spawn_offset[index], lap)


## Freeze both cars, lay out a fresh track, and hold still long enough for the
## players to read the new circuit before letting them go again.
func _finish_lap() -> void:
	_racing = false
	for car in _cars:
		car.frozen = true
		car.reset_motion()

	_track.generate(randi())
	_place_on_grid()
	# Snap both cameras, or they fly across the world to the new grid.
	_camera1.follow(_car1)
	_camera2.follow(_car2)

	await get_tree().create_timer(preview_seconds).timeout

	for car in _cars:
		car.frozen = false
	_start_racing()


func _start_racing() -> void:
	_next_sector = []
	for i in _cars.size():
		# Always sector 1, rather than reading the car's current sector: cars
		# start on the line, where the curve's start and end coincide, so
		# get_closest_offset can report either nearly zero or nearly a full
		# lap. Requiring the quarter-lap mark first sidesteps that ambiguity.
		_next_sector.append(1)
	_racing = true


func _sector_of(progress: float, lap: float) -> int:
	return clampi(int(progress / (lap / SECTORS)), 0, SECTORS - 1)


## Line the cars up on the track's own curve, staggered, facing the racing
## direction. Deriving the grid from the path means it keeps working whenever
## the track is regenerated, and it avoids hand-written basis maths.
func _place_on_grid() -> void:
	var curve := _track.curve()
	var lap := curve.get_baked_length()
	_spawn_offset = PackedFloat32Array()

	for i in _cars.size():
		var along := fposmod(-grid_stagger * i, lap)
		var here := curve.sample_baked(along)
		var ahead := curve.sample_baked(fposmod(along + 1.0, lap))

		var forward := ahead - here
		forward.y = 0.0
		if forward.length_squared() < 0.000001:
			push_warning("Main: degenerate track tangent at %.1f m" % along)
			forward = Vector3.FORWARD
		forward = forward.normalized()
		var across := forward.cross(Vector3.UP)

		# Keep the grid inside the road even where it narrows into a corner.
		var room: float = maxf(_track.half_width_at(along) - 1.6, 0.5)
		var side: float = minf(grid_spread, room) * (1.0 if i % 2 == 1 else -1.0)

		var car := _cars[i]
		car.global_position = here + across * side + Vector3.UP * grid_clearance
		# look_at aims -Z, which is the car's forward.
		car.look_at(car.global_position + forward, Vector3.UP)
		_spawn_offset.append(along)
