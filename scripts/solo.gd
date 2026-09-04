class_name Solo
extends Node3D

## One car, one road, one clock.
##
## A separate scene from the two-player race rather than that race with a
## player taken out of it. Almost everything in Main is about there being two
## of something - two viewports, two cameras, two arrows, a leader, a winner -
## and threading a count through all of it would leave the endless mode carrying
## a branch on every line for a mode it is not. What is shared is shared as
## nodes instead: the car, the track, the chase camera, the speed lines and the
## day and night cycle are the same ones the race uses.
##
## The clock is the whole point. It starts on GO and stops on the line, and
## nothing that happens in between stops it - going off the road, hitting a
## barrier and being put back at the last checkpoint all cost time rather than
## ending the run, because time is already the punishment this mode has.

## Where BACK goes.
@export_file("*.tscn") var menu_scene := "res://scenes/menu.tscn"
## The track to drive when nothing picked one, so the scene can be opened on
## its own and still be a track rather than an empty world.
@export_file("*.gd") var fallback_track := "res://tracks/01_first_light.gd"

@export_group("Race")
## How long the car is held on the line, and how long GO stays up after it.
@export var preview_seconds := 3.0
@export var go_seconds := 0.7
## How far behind the start line the car sits, and how far off the road it is
## dropped so it settles onto it rather than through it.
@export var grid_setback := 4.0
@export var grid_clearance := 0.05
## How far from the centreline still counts as being on the course, for
## deciding that the finish line was actually crossed.
@export var finish_corridor := 25.0

@export_group("Headlights")
## Where in the night the headlights come on and reach full.
@export var lights_on_at := 0.25
@export var lights_full_at := 0.6

@onready var _car: Car = $Car
@onready var _camera: ChaseCamera = $Camera
@onready var _lines: SpeedLines = $Lines
@onready var _track: Track = $Track
@onready var _day_night: DayNight = $DayNight
@onready var _clock: Label = $Hud/Corner/Box/Clock
@onready var _tally: Label = $Hud/Corner/Box/Tally
@onready var _best_label: Label = $Hud/Best
@onready var _countdown: Label = $Hud/Countdown
@onready var _result: Label = $Hud/Result
@onready var _hint: Label = $Hud/Hint

## Ticking between GO and the line.
var _running := false
var _time := 0.0
## Which track is being driven, and the best run on it so far - below zero
## for a track nobody has finished. Held here as well as written down, so the
## screen has something to compare against without reading a file per lap.
var _track_file := ""
var _best := -1.0
## Where a reset puts the car, and which checkpoint it is looking for next.
var _respawn := 0.0
var _next_checkpoint := 0
## Which countdown is the current one, so an older one that is still waiting
## on a timer cannot clear the screen out from under a newer one.
var _countdown_run := 0


func _ready() -> void:
	_track_file = (GameSettings.track_file if not GameSettings.track_file.is_empty()
			else fallback_track)
	_track.track_file = _track_file
	_best = TrackTimes.best(_track_file)
	# Nothing to draft behind and nothing to be shown an arrow to.
	_car.rival = null
	_track.generate(0)
	_lines.watch(_car)
	_place_on_the_line()
	_camera.follow(_car)
	_show_best()
	_hint.text = "ENTER  run again        R  back to the last checkpoint        C  view        ESC  tracks"
	# Up while the car is held and once it is home, down while it is driving.
	# What is on the screen mid-run should be the run.
	_start_after_countdown()


func _process(_delta: float) -> void:
	var level := smoothstep(lights_on_at, lights_full_at, _day_night.night_amount())
	_car.set_headlights(level)


func _physics_process(delta: float) -> void:
	# Both of these work whether or not the clock is running, so a player held
	# on the line can look around, and one sitting on a finished run can start
	# another without waiting for anything.
	if Input.is_action_just_pressed("p1_view"):
		_camera.set_inside(not _camera.is_inside())
	if Input.is_action_just_pressed("restart"):
		_restart()
		return
	if not _running:
		return

	_time += delta
	_clock.text = _format_time(_time)
	if Input.is_action_just_pressed("p1_reset"):
		_back_to_checkpoint()
		return
	_bank_checkpoints()
	if _has_finished():
		_finish()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		get_tree().change_scene_to_file(menu_scene)


# --- the run ------------------------------------------------------------

## Put the car back on the line and count it down again. This is the whole of
## a retry: the track is not rebuilt, because it is the same track and
## rebuilding it would cost a second of watching a road appear that was
## already there.
func _restart() -> void:
	_running = false
	_hint.show()
	_result.text = ""
	_place_on_the_line()
	_camera.follow(_car)
	_start_after_countdown()


## Hold the car on the line, count down, and let it go. The clock starts on GO
## and not a moment before.
func _start_after_countdown() -> void:
	_countdown_run += 1
	var run := _countdown_run
	_car.frozen = true
	_car.reset_motion()
	_time = 0.0
	_clock.text = _format_time(0.0)

	var steps: int = maxi(1, int(round(preview_seconds)))
	var each := preview_seconds / float(steps)
	for remaining in range(steps, 0, -1):
		_countdown.text = str(remaining)
		await get_tree().create_timer(each).timeout
		if run != _countdown_run:
			return

	_countdown.text = "GO"
	_hint.hide()
	_car.frozen = false
	_running = true

	await get_tree().create_timer(go_seconds).timeout
	if run == _countdown_run:
		_countdown.text = ""


## Stop the clock and say what the run was worth.
func _finish() -> void:
	_running = false
	_hint.show()
	_car.frozen = true
	_car.reset_motion()

	# Offered to the record before anything is said about it, so what appears
	# on the screen is what was actually written down.
	var beaten := TrackTimes.record(_track_file, _time)
	var lines := PackedStringArray([_format_time(_time)])
	if _best < 0.0:
		lines.append("FIRST TIME SET")
	elif beaten:
		lines.append("BEST BY %s" % _format_time(_best - _time))
	else:
		lines.append("%s OFF THE BEST" % _format_time(_time - _best))
	if beaten:
		_best = _time
	_show_best()
	_result.text = "\n".join(lines)


## The best so far, or nothing at all rather than a dash: an empty corner
## says "no time yet" without having to be read.
func _show_best() -> void:
	_best_label.text = "" if _best < 0.0 else "BEST  %s" % _format_time(_best)


# --- where the car is ---------------------------------------------------

## True once the car is past the finish line and still on the course. The
## corridor matters because a car lost out in the mountains can project onto
## any part of the centreline, the finish included.
func _has_finished() -> bool:
	var offset := _offset_of(_car)
	if offset < _track.finish_offset():
		return false
	return _on_course(offset)


## Move the respawn up as the car passes checkpoints. It has to be on the
## course to bank one, so a player cannot cut across the scenery and then
## reset forward onto a checkpoint they never drove to.
func _bank_checkpoints() -> void:
	var marks := _track.checkpoint_offsets()
	var offset := _offset_of(_car)
	while _next_checkpoint < marks.size() and offset >= marks[_next_checkpoint]:
		if not _on_course(offset):
			return
		_respawn = marks[_next_checkpoint]
		_next_checkpoint += 1
		_show_tally()


## Put the car back on the course at its last checkpoint, facing the right way
## and stopped. The clock keeps running: this is the way out of a hole in the
## road, and what it costs is the time it costs.
func _back_to_checkpoint() -> void:
	var curve := _track.curve()
	var here := _to_world(curve.sample_baked(_respawn))
	var ahead := _to_world(curve.sample_baked(minf(_respawn + 1.0, _track.length())))
	_car.global_position = here + Vector3.UP * grid_clearance
	var forward := ahead - here
	forward.y = 0.0
	if forward.length_squared() > 0.000001:
		_car.look_at(_car.global_position + forward.normalized(), Vector3.UP)
	_car.reset_motion()
	_camera.follow(_car)


## Line the car up on the start line, facing down the course.
func _place_on_the_line() -> void:
	var curve := _track.curve()
	var at: float = maxf(_track.start_offset() - grid_setback, 0.0)
	var here := _to_world(curve.sample_baked(at))
	var ahead := _to_world(curve.sample_baked(at + 1.0))
	var forward := ahead - here
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		push_warning("Solo: degenerate course tangent at the start")
		forward = Vector3.FORWARD

	_car.global_position = here + Vector3.UP * grid_clearance
	_car.look_at(_car.global_position + forward.normalized(), Vector3.UP)
	_car.reset_motion()
	_respawn = at
	_next_checkpoint = 0
	_show_tally()


func _show_tally() -> void:
	_tally.text = "CHECKPOINT %d / %d" % [
		_next_checkpoint, _track.checkpoint_offsets().size()]


func _offset_of(car: Car) -> float:
	return _track.curve().get_closest_offset(_to_track(car.global_position))


func _on_course(offset: float) -> bool:
	var centre := _to_world(_track.curve().sample_baked(offset))
	return _car.global_position.distance_to(centre) < finish_corridor


## The curve's points are in the Track node's own space. Going through its
## transform keeps this right even if that node is moved or scaled.
func _to_world(local: Vector3) -> Vector3:
	return _track.global_transform * local


func _to_track(world: Vector3) -> Vector3:
	return _track.global_transform.affine_inverse() * world


## Minutes only once there are any, so a forty second run reads as a number
## rather than as a clock.
func _format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var rest := fmod(seconds, 60.0)
	if minutes > 0:
		return "%d:%05.2f" % [minutes, rest]
	return "%.2f" % rest
