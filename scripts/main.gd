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
@onready var _day_night: DayNight = $DayNight
@onready var _counts: Array[Label] = [
	$Countdown/Top/Label, $Countdown/Bottom/Label,
]
@onready var _clocks: Array[Label] = [$Hud/Top/Box/Clock, $Hud/Bottom/Box/Clock]
@onready var _places: Array[Label] = [$Hud/Top/Box/Place, $Hud/Bottom/Box/Place]
@onready var _results: Array[Label] = [$Result/Top/Label, $Result/Bottom/Label]
@onready var _tallies: Array[Label] = [$Progress/Top/Label, $Progress/Bottom/Label]

@export_group("Starting grid")
## Sideways offset from the centreline, in metres.
@export var grid_spread := 3.6
## How far behind the painted start line the cars sit, in metres. The line
## itself is owned by the track, so the two cannot drift apart.
@export var grid_setback := 4.0
## Ride height above the road surface at the spawn point.
@export var grid_clearance := 0.05

@export_group("Headlights")
## How far into nightfall the headlights start to come on, and where they reach
## full. Both are points on the day/night cycle, 0 day and 1 night, so the cars
## light up during the sunset rather than snapping on at full dark.
@export var lights_on_at := 0.25
@export var lights_full_at := 0.6

@export_group("Race")
## Seed for the first course. Zero picks a random one each run.
@export var starting_seed := 0
## How long the cars are held still after a new course appears, so the players
## can look at what they are about to drive. The countdown fills this time.
@export var preview_seconds := 3.0
## How long "GO" stays up after the cars are released.
@export var go_seconds := 0.7
## How long the winner and their time stay up before the next course loads.
@export var result_seconds := 2.0
## A car further than this from the centreline is not really on the course, so
## it cannot trip the finish line from somewhere out in the scenery.
@export var finish_corridor := 25.0
## Metres of lead needed before a player is shown as leading. Until then, and
## whenever they are level again, both see a dash.
@export var lead_margin := 1.5
## Falling back inside this gap makes it level again. The two differ so the
## places cannot strobe while the cars run wheel to wheel.
@export var level_margin := 0.6

var _cars: Array[Car] = []
var _racing := false
## Bumped for every countdown, so a timer left over from the previous one
## cannot wipe the text of the current one.
var _countdown_run := 0
## Seconds of racing on the current course, running only while the cars are
## actually free, so the countdown and the result screen are not counted.
var _race_time := 0.0
## Distance along the course each car is sent back to when it resets. It
## starts at the grid and moves up as checkpoints are passed.
var _respawn := PackedFloat32Array()
## The next checkpoint each car has yet to reach.
var _next_checkpoint := PackedInt32Array()
## Who is currently ahead, or -1 while the cars are level.
var _leader := -1


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

	# The first course gets the same countdown as every later one.
	_start_after_countdown()


## The headlights follow the sky, not the race, so this runs whether or not
## the cars are moving - they should be on while a night course is still
## counting down.
func _process(_delta: float) -> void:
	var level := smoothstep(lights_on_at, lights_full_at, _day_night.night_amount())
	for car in _cars:
		car.set_headlights(level)


func _physics_process(delta: float) -> void:
	# The view can be swapped at any time, including while the cars are held
	# for the countdown, so this sits ahead of the racing check.
	_poll_view_toggles()
	if not _racing:
		return
	_race_time += delta
	_show_clock(_format_time(_race_time))
	_show_places()
	for i in _cars.size():
		if Input.is_action_just_pressed(_cars[i].input_prefix + "_reset"):
			_reset_to_checkpoint(i)
			continue
		_bank_checkpoints(i)
		if _has_finished(_cars[i]):
			_finish_course(i)
			return


## C and L flip each player between the chase camera and the driver's eye.
func _poll_view_toggles() -> void:
	var cameras: Array[ChaseCamera] = [_camera1, _camera2]
	for i in _cars.size():
		if Input.is_action_just_pressed(_cars[i].input_prefix + "_view"):
			cameras[i].set_inside(not cameras[i].is_inside())


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
	return _on_course(car, offset)


## Move a car's respawn point up as it passes checkpoints. A car has to be on
## the course to bank one, so a player cannot collect checkpoints by driving
## across the scenery, and then reset forward onto them.
func _bank_checkpoints(index: int) -> void:
	var marks := _track.checkpoint_offsets()
	var car := _cars[index]
	var offset := _offset_of(car)
	while _next_checkpoint[index] < marks.size() and offset >= marks[_next_checkpoint[index]]:
		if not _on_course(car, offset):
			return
		_respawn[index] = marks[_next_checkpoint[index]]
		_next_checkpoint[index] += 1
		_show_tally(index)


## Put a car back on the course at its last checkpoint, facing the right way
## and stopped. This is the way out of being stuck or falling off.
func _reset_to_checkpoint(index: int) -> void:
	var car := _cars[index]
	var curve := _track.curve()
	var at := _respawn[index]
	var here := _to_world(curve.sample_baked(at))
	var ahead := _to_world(curve.sample_baked(minf(at + 1.0, _track.length())))

	var forward := ahead - here
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		forward = -car.global_transform.basis.z
	forward = forward.normalized()

	car.reset_motion()
	car.global_position = here + Vector3.UP * grid_clearance
	car.look_at(car.global_position + forward, Vector3.UP)


func _offset_of(car: Car) -> float:
	return _track.curve().get_closest_offset(_to_track(car.global_position))


## Whether a car is close enough to the centreline to count as on the course.
func _on_course(car: Car, offset: float) -> bool:
	var centre := _to_world(_track.curve().sample_baked(offset))
	return car.global_position.distance_to(centre) < finish_corridor


## Lay out a new course and put the cars on the line.
func _new_course(course_seed: int) -> void:
	_track.generate(course_seed)
	_place_on_grid()
	# Snap both cameras, or they fly across the world to the new grid.
	_camera1.follow(_car1)
	_camera2.follow(_car2)


## Show who won and how long they took, then swap in a fresh course.
##
## The result is held on the finished course, before the new one is built, so
## the players see where they ended up rather than the announcement flashing
## over a track they have not driven yet.
func _finish_course(winner: int) -> void:
	_racing = false
	for car in _cars:
		car.frozen = true
		car.reset_motion()

	_show_result("%s WINS\n%s" % [
		_colour_name(_cars[winner].body_color), _format_time(_race_time)])
	await get_tree().create_timer(result_seconds).timeout
	_show_result("")

	_new_course(randi())
	_start_after_countdown()


## Hold the cars while the countdown runs, then let them go. The countdown
## fills the preview pause rather than adding to it, so the players spend that
## time reading the new course instead of waiting blind.
func _start_after_countdown() -> void:
	_countdown_run += 1
	var run := _countdown_run
	for car in _cars:
		car.frozen = true
		car.reset_motion()

	var steps: int = maxi(1, int(round(preview_seconds)))
	var each := preview_seconds / float(steps)
	for remaining in range(steps, 0, -1):
		_show_count(str(remaining))
		await get_tree().create_timer(each).timeout

	_show_count("GO")
	_race_time = 0.0
	_show_clock(_format_time(0.0))
	_show_places()
	for car in _cars:
		car.frozen = false
	_racing = true

	await get_tree().create_timer(go_seconds).timeout
	# Only clear if another countdown has not started in the meantime.
	if run == _countdown_run:
		_show_count("")


## The same text in both halves of the screen, since each player needs to see
## it in their own view.
func _show_count(text: String) -> void:
	for label in _counts:
		label.text = text


func _show_clock(text: String) -> void:
	for label in _clocks:
		label.text = text


## Who is ahead, by distance along the course. Each player is told their own
## position, in their own half.
##
## Nobody leads off the grid, where both cars are the same distance along, so
## the places start as a dash rather than picking one arbitrarily. The two
## margins give it hysteresis: a lead has to be earned, and only a clear return
## to level gives it up, so the display cannot strobe wheel to wheel.
func _show_places() -> void:
	var gap := _offset_of(_cars[0]) - _offset_of(_cars[1])
	if absf(gap) < level_margin:
		_leader = -1
	elif absf(gap) > lead_margin:
		_leader = 0 if gap > 0.0 else 1

	for i in _places.size():
		if _leader < 0:
			_places[i].text = "\u2013"
		else:
			_places[i].text = "1st" if i == _leader else "2nd"


## How many checkpoints this player has banked, in their own half only, since
## each player is tracking their own run.
func _show_tally(index: int) -> void:
	_tallies[index].text = "%d/%d" % [
		_next_checkpoint[index], _track.checkpoint_count]


func _show_result(text: String) -> void:
	for label in _results:
		label.text = text


## Name a car by its paint, so the announcement follows body_color instead of
## hard-coding which player drives which colour.
func _colour_name(colour: Color) -> String:
	if colour.s < 0.25:
		if colour.v > 0.6:
			return "WHITE"
		return "GREY" if colour.v > 0.25 else "BLACK"
	var hue := colour.h * 360.0
	if hue < 15.0 or hue >= 330.0:
		return "RED"
	if hue < 45.0:
		return "ORANGE"
	if hue < 70.0:
		return "YELLOW"
	if hue < 160.0:
		return "GREEN"
	if hue < 200.0:
		return "CYAN"
	if hue < 265.0:
		return "BLUE"
	if hue < 300.0:
		return "PURPLE"
	return "PINK"


## Minutes only once there are any, so a short course reads "42.16" rather
## than "0:42.16".
func _format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var rest := fmod(seconds, 60.0)
	if minutes > 0:
		return "%d:%05.2f" % [minutes, rest]
	return "%.2f" % rest


## Line the cars up side by side on the start line, facing down the course.
## Deriving the grid from the curve means it keeps working for every course.
func _place_on_grid() -> void:
	var curve := _track.curve()
	var at: float = maxf(_track.start_offset() - grid_setback, 0.0)
	var here := _to_world(curve.sample_baked(at))
	var ahead := _to_world(curve.sample_baked(at + 1.0))

	var forward := ahead - here
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		push_warning("Main: degenerate course tangent at the start")
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var across := forward.cross(Vector3.UP)

	# Every course starts the players over: the grid itself is the first
	# place a reset sends them.
	_respawn = PackedFloat32Array()
	_next_checkpoint = PackedInt32Array()
	for i in _cars.size():
		_respawn.append(at)
		_next_checkpoint.append(0)
		_show_tally(i)

	# Keep the grid on the road even if the course opens narrow.
	var room: float = maxf(_track.half_width_at(at) - 1.6, 0.5)
	var side: float = minf(grid_spread, room)

	for i in _cars.size():
		var car := _cars[i]
		car.global_position = (here
				+ across * (side if i % 2 == 1 else -side)
				+ Vector3.UP * grid_clearance)
		# look_at aims -Z, which is the car's forward.
		car.look_at(car.global_position + forward, Vector3.UP)

	# Only once the cars are actually on the grid, or this reads their old
	# positions and hands someone a lead they no longer have.
	_leader = -1
	_show_places()
