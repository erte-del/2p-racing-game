class_name Solo
extends Node3D

## One car, one road, one clock. Either a laid-out track, driven for a time,
## or the endless course, driven for its own sake.
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

@export_group("Race")
## How long the finished course is held before the next one is rolled. Only
## the endless course does this; a laid-out track waits to be asked.
@export var result_seconds := 2.4
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
@onready var _result: Control = $Hud/Result
@onready var _result_time: Label = $Hud/Result/Box/Time
@onready var _result_medal: Label = $Hud/Result/Box/Medal
@onready var _result_note: Label = $Hud/Result/Box/Note
@onready var _hint: Label = $Hud/Hint
@onready var _pause: PauseMenu = $Pause

## Ticking between GO and the line.
var _running := false
var _time := 0.0
## Which track is being driven, and the best run on it so far - below zero
## for a track nobody has finished. Held here as well as written down, so the
## screen has something to compare against without reading a file per lap.
var _track_file := ""
var _best := -1.0
## True when nothing picked a track, which is the endless course: a fresh road
## every time, so there is no time to beat and nothing to write down. What the
## clock is for there is the run you are on.
var _endless := false
## What chaos does to a rolled course, when it is asked for.
var _chaos: Chaos
var _chaos_rng := RandomNumberGenerator.new()
## What a lap of this track is worth: gold, silver and bronze, in seconds.
var _targets := Vector3.ZERO
## Where a reset puts the car, and which checkpoint it is looking for next.
var _respawn := 0.0
var _next_checkpoint := 0
## Which countdown is the current one, so an older one that is still waiting
## on a timer cannot clear the screen out from under a newer one.
var _countdown_run := 0


func _ready() -> void:
	_track_file = GameSettings.track_file
	_endless = _track_file.is_empty()
	# Nothing to draft behind and nothing to be shown an arrow to.
	_car.rival = null

	if _endless:
		# Chaos rolls the car and the shape of the course, so it has to be in
		# place before the first course is built.
		if GameSettings.chaos:
			var cars: Array[Car] = [_car]
			_chaos = Chaos.new(cars, _day_night, _track)
			_chaos_rng.randomize()
		_lines.wild = _chaos != null
		($Trees as Trees).wild = _chaos != null
		_roll_a_course()
	else:
		_track.track_file = _track_file
		_track.generate(0)
		_best = TrackTimes.best(_track_file)
		_targets = _track_targets()

	# After the track is built, since what a lap of it is worth is read off
	# the track rather than described a second time.
	_result.hide()
	# The paint the player chose, and a standing offer to change it: the pause
	# screen writes to the setting rather than reaching in here, so a swatch
	# pressed mid-run lands on the car through the same path the saved choice
	# takes at the start of one.
	_apply_paint()
	GameSettings.changed.connect(_apply_paint)
	_lines.watch(_car)
	_place_on_the_line()
	_camera.follow(_car)
	_show_best()
	_pause.restart_requested.connect(_restart)
	_pause.quit_requested.connect(_on_pause_quit)
	_hint.text = "%s        R  back to the last checkpoint        C  view        ESC  pause" % [
		"ENTER  next course" if _endless else "ENTER  run again"]
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


## Escape stops the run where it stands rather than throwing it away. Leaving
## is still one press further on, in the pause screen, where it says what it
## is going to do before it does it.
func _input(event: InputEvent) -> void:
	if _pause.visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_open_pause()


# --- pausing ------------------------------------------------------------

## Put the player's colour on the car. Chaos is the one thing that overrules
## it: it repaints the car for every course on purpose, and a chosen colour
## landing back on it halfway through would be the mode failing to do the one
## thing it says it does.
func _apply_paint() -> void:
	if _chaos != null:
		return
	_car.repaint(GameSettings.car_colour(0))



## What the pause screen says it is sitting on top of.
##
## The endless course has no name to give and no road to go back to, so it is
## named by what it is and its way out is the title screen. A laid-out track
## names itself, and leaving it goes back to the grid it was picked from -
## which is where the menu opens anyway, since nothing has cleared the track
## that is still chosen.
func _open_pause() -> void:
	if _endless:
		var what := "ENDLESS COURSE"
		if _chaos != null:
			what += "  \u2013  CHAOS"
		_pause.open(what, "NEXT COURSE", "QUIT TO MENU")
		return
	var definition := _track.definition()
	var named := definition.track_name.to_upper() if definition != null else ""
	_pause.open(named, "RESTART", "BACK TO TRACKS")


func _on_pause_quit() -> void:
	get_tree().change_scene_to_file(menu_scene)


# --- the run ------------------------------------------------------------

## Put the car back on the line and count it down again. This is the whole of
## a retry: the track is not rebuilt, because it is the same track and
## rebuilding it would cost a second of watching a road appear that was
## already there.
func _restart() -> void:
	_running = false
	_hint.show()
	_result.hide()
	# The endless course is endless: asking for another go means another road,
	# not the same one again. A laid-out track is the opposite - the same road
	# is the whole point of it.
	if _endless:
		_roll_a_course()
	_place_on_the_line()
	_camera.follow(_car)
	_start_after_countdown()


## Throw away the course and roll a new one.
func _roll_a_course() -> void:
	if _chaos != null:
		_chaos.reroll(_chaos_rng)
	_track.track_file = ""
	_track.generate(randi())
	_targets = Vector3.ZERO


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
		await get_tree().create_timer(each, false).timeout
		if run != _countdown_run:
			return

	_countdown.text = "GO"
	_hint.hide()
	_car.frozen = false
	_running = true

	await get_tree().create_timer(go_seconds, false).timeout
	if run == _countdown_run:
		_countdown.text = ""


## Stop the clock and say what the run was worth.
func _finish() -> void:
	_running = false
	_hint.show()
	_car.frozen = true
	_car.reset_motion()
	# Set outright rather than left on whatever the last step wrote, so the
	# clock in the corner and the time in the middle are the same number.
	_clock.text = _format_time(_time)
	_result_time.text = _format_time(_time)
	_result.show()

	if _endless:
		await _and_on_to_the_next()
		return

	# Offered to the record before anything is said about it, so what appears
	# on the screen is what was actually written down.
	var beaten := TrackTimes.record(_track_file, _time)

	var medal := Medal.earned(_time, _targets)
	_result_medal.text = Medal.label(medal)
	_result_medal.add_theme_color_override("font_color", Medal.colour(medal))

	# What is worth saying under the medal is whichever of the two things the
	# player is closer to caring about: a run that beat their own best is
	# about the best, and one that did not is about the next medal up.
	if _best < 0.0:
		_result_note.text = "FIRST TIME SET"
	elif beaten:
		_result_note.text = "BEST BY %s" % _format_time(_best - _time)
	else:
		_result_note.text = "%s OFF THE BEST" % _format_time(_time - _best)
	var up: Array = Medal.next_up(_time, _targets)
	if int(up[0]) != Medal.NONE:
		_result_note.text += "        %s TO %s" % [
			_format_time(float(up[1])), Medal.label(int(up[0]))]

	if beaten:
		_best = _time
	_show_best()


## Hold the finished course for a moment, then roll another. There is nothing
## to compare an endless run against - the next road is a different road - so
## the time is all there is to say, and the way on is to keep driving.
func _and_on_to_the_next() -> void:
	_result_medal.text = ""
	_result_note.text = "NEXT COURSE"
	var run := _countdown_run
	await get_tree().create_timer(result_seconds, false).timeout
	# A player who pressed Enter rather than waiting has already started the
	# next one, and this must not start a third over the top of it.
	if run != _countdown_run:
		return
	_restart()


## The best so far, or nothing at all rather than a dash: an empty corner
## says "no time yet" without having to be read.
func _show_best() -> void:
	if _endless or _best < 0.0:
		_best_label.text = ""
		return
	var medal := Medal.earned(_best, _targets)
	_best_label.text = "BEST  %s" % _format_time(_best)
	if medal != Medal.NONE:
		_best_label.text += "   %s" % Medal.label(medal)
	# Coloured by what the standing time is worth, so the corner says how the
	# track is going without having to be read.
	_best_label.add_theme_color_override("font_color", Medal.colour(medal))


## What this track asks for. Read off the track that was actually built, so a
## definition is not described twice.
func _track_targets() -> Vector3:
	var definition := _track.definition()
	return definition.targets if definition != null else Vector3.ZERO


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
