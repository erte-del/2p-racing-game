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
## ending the run, because time is already the punishment this mode has. The
## one exception is a player who turned damage on and wore the car out: that
## ends the run, and sets no time, because the car never finished.

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
## How far past a checkpoint the car can still bank it, in metres, for the
## reason the race gives.
@export var checkpoint_window := 30.0

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
@onready var _condition: ConditionBar = $Hud/Corner/Box/Condition/Bar
@onready var _best_label: Label = $Hud/Best
@onready var _countdown: Label = $Hud/Countdown
@onready var _result: Control = $Hud/Result
@onready var _result_panel: Control = $Hud/Result/Centre/Panel
@onready var _result_time: Label = $Hud/Result/Centre/Panel/Margin/Box/Time
@onready var _result_medal: Label = $Hud/Result/Centre/Panel/Margin/Box/Medal
@onready var _result_note: Label = $Hud/Result/Centre/Panel/Margin/Box/Note
@onready var _badge: MedalBadge = $Hud/Result/Badge
@onready var _hint: Label = $Hud/Hint
@onready var _choice: Control = $Hud/Result/Centre/Panel/Margin/Box/Choice
@onready var _again_button: Button = $Hud/Result/Centre/Panel/Margin/Box/Choice/Row/Restart
@onready var _next_button: Button = $Hud/Result/Centre/Panel/Margin/Box/Choice/Row/Next
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
## Where a reset puts the car, and which checkpoints it has banked, a flag a
## checkpoint. They can be banked in any order; all of them are needed to finish.
var _respawn := 0.0
var _banked := PackedByteArray()
## Where the middle of the car was a step ago, on a track with rings. A ring is
## banked by the car's path going through it, and a path needs two ends.
var _was := Vector3.ZERO
## Which countdown is the current one, so an older one that is still waiting
## on a timer cannot clear the screen out from under a newer one.
var _countdown_run := 0
## What the keyboard was on when the pause screen went up, so closing it hands
## the keyboard back rather than leaving it dead. Hiding a control releases its
## focus, and the pause screen hides one on the way out.
var _focus_before_pause: Control


func _ready() -> void:
	_track_file = GameSettings.track_file
	_endless = _track_file.is_empty()
	# Nothing to draft behind and nothing to be shown an arrow to.
	_car.rival = null
	# Told to the car rather than left for it to read, for the reason Car.damage
	# gives. Read once, the way chaos is: a race does not change what it is
	# being driven under halfway down the road.
	_car.damage = GameSettings.damage
	_condition.watch(_car)

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
	# The car and the paint the player chose, and a standing offer to change
	# either: the pause screen writes to the setting rather than reaching in
	# here, so a car or a swatch picked mid-run lands through the same path the
	# saved choice takes at the start of one. The garage is listened to as
	# well, because turning or deleting a car changes what is being driven
	# without changing which car was picked.
	_apply_cars()
	_apply_paint()
	GameSettings.changed.connect(_apply_cars)
	GameSettings.changed.connect(_apply_paint)
	Garage.changed.connect(_apply_cars)
	_lines.watch(_car)
	_place_on_the_line()
	_camera.follow(_car)
	_show_best()
	_pause.restart_requested.connect(_restart)
	_pause.quit_requested.connect(_on_pause_quit)
	_pause.resumed.connect(_take_the_keyboard_back)
	_choice.hide()
	# The panel is only as wide as whatever is in it, and that changes with
	# the wording, so where its corner is has to be asked rather than written
	# down. It answers whenever it is laid out.
	_result_panel.resized.connect(_pin_the_badge)
	_again_button.pressed.connect(_restart)
	_next_button.pressed.connect(_on_next_track)
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
	# Not while the finished run is offering the choice: the same key works
	# the button the cursor is on, and a track that restarted itself on the
	# press that asked for the next one would be doing both.
	if Input.is_action_just_pressed("restart") and not _choice.visible:
		_restart()
		return
	if not _running:
		return
	# Broken on the step before this one. The clock is stopped where the car
	# stopped, not a step after it.
	if _car.is_broken():
		_break_down()
		return

	_time += delta
	_clock.text = RaceClock.format(_time)
	# Before the car moves, so what it drives into this step is where the
	# clock says it is.
	_track.set_race_time(_time)
	if Input.is_action_just_pressed("p1_reset"):
		_back_to_checkpoint()
		return
	# Looked up once for both, because finding the nearest point on the curve
	# is a walk along the whole of it.
	var offset := _track.offset_of(_car.global_position)
	_bank_checkpoints(offset)
	if _has_finished(offset):
		_finish()


## Escape stops the run where it stands rather than throwing it away. Leaving
## is still one press further on, in the pause screen, where it says what it
## is going to do before it does it.
func _input(event: InputEvent) -> void:
	if _pause.visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	_open_pause()


## Put the player in the car they picked. Chaos leaves this alone: it rolls how
## the car handles and what colour it is, never what it is.
func _apply_cars() -> void:
	Garage.dress(_car, GameSettings.car_id(0))


## Put the player's colour on the car. Chaos is the one thing that overrules
## it: it repaints the car for every course on purpose, and a chosen colour
## landing back on it halfway through would be the mode failing to do the one
## thing it says it does.
func _apply_paint() -> void:
	if _chaos != null:
		return
	_car.repaint(GameSettings.car_colour(0))


# --- pausing ------------------------------------------------------------

## What the pause screen says it is sitting on top of.
##
## The endless course has no name to give and no road to go back to, so it is
## named by what it is and its way out is the title screen. A laid-out track
## names itself, and leaving it goes back to the grid it was picked from -
## which is where the menu opens anyway, since nothing has cleared the track
## that is still chosen.
func _open_pause() -> void:
	_focus_before_pause = get_viewport().gui_get_focus_owner()
	if _endless:
		var what := "ENDLESS COURSE"
		if _chaos != null:
			what += "  \u2013  CHAOS"
		_pause.open(what, "NEXT COURSE", "QUIT TO MENU")
		return
	var definition := _track.definition()
	var named := definition.track_name.to_upper() if definition != null else ""
	_pause.open(named, "RESTART", "BACK TO TRACKS")


## Coming back from the pause screen with nothing focused would leave the
## keyboard dead in front of a question, so whatever it was on goes back.
func _take_the_keyboard_back() -> void:
	if _focus_before_pause == null or not _focus_before_pause.is_visible_in_tree():
		return
	_focus_before_pause.grab_focus()
	_focus_before_pause = null


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
	_choice.hide()
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
	_clock.text = RaceClock.format(0.0)
	# The traps wait at GO with the car, so what the player reads off the
	# course while it counts down is what they will meet.
	_track.set_race_time(0.0)

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
	_clock.text = RaceClock.format(_time)
	_result_time.text = RaceClock.format(_time)
	_result.show()
	# Nothing to pin until a track says what was won; the endless course never
	# does, and takes the badge off on its way past.
	_badge.show_medal(Medal.NONE)

	if _endless:
		await _and_on_to_the_next()
		return

	# Offered to the record before anything is said about it, so what appears
	# on the screen is what was actually written down.
	var beaten := TrackTimes.record(_track_file, _time)

	# A run that earned nothing says so rather than leaving the line blank.
	# Silence where the medal goes reads as a screen that has not finished
	# drawing, and "no medal" is an answer to the question the player asked.
	var medal := Medal.earned(_time, _targets)
	_result_medal.text = Medal.label(medal) if medal != Medal.NONE else "NO MEDAL"
	_result_medal.add_theme_color_override("font_color", Medal.colour(medal))

	# What is worth saying under the medal is whichever of the two things the
	# player is closer to caring about: a run that beat their own best is
	# about the best, and one that did not is about the next medal up.
	if _best < 0.0:
		_result_note.text = "FIRST TIME SET"
	elif beaten:
		_result_note.text = "BEST BY %s" % RaceClock.format(_best - _time)
	else:
		_result_note.text = "%s OFF THE BEST" % RaceClock.format(_time - _best)
	var up: Array = Medal.next_up(_time, _targets)
	if int(up[0]) != Medal.NONE:
		_result_note.text += "        %s TO %s" % [
			RaceClock.format(float(up[1])), Medal.label(int(up[0]))]

	if beaten:
		_best = _time
	_show_best()
	_badge.show_medal(medal)
	_offer_the_way_on(medal)

	# Hung only once the buttons are on the panel, because they are what
	# decides how wide it is and the corner moves with them. One frame is what
	# it takes for the page to be laid out with them in it.
	await get_tree().process_frame
	_pin_the_badge()
	_badge.drop_in()


## The car is finished, and so is the run.
##
## Not a reset to the last checkpoint: damage is the one thing a checkpoint
## does not fix. Nothing is offered to the record either, since a broken car
## never finished and there is no time to keep - but the panel says how far it
## got, which is the one thing about the run that is still worth knowing. The
## car is left where it broke, in the air if that is where it was.
func _break_down() -> void:
	_running = false
	_car.frozen = true
	_clock.text = RaceClock.format(_time)
	_result_time.text = RaceClock.format(_time)
	_result_medal.text = "BROKEN"
	_result_medal.add_theme_color_override("font_color", _condition.warning_colour)
	_result_note.text = "%d%% OF THE WAY" % roundi(_how_far_along() * 100.0)
	_badge.show_medal(Medal.NONE)
	_result.show()
	if _endless:
		# The endless course usually rolls on by itself after a finish. Not
		# after this: a player whose run just ended should see that it did, and
		# Enter is right there for the next one.
		_hint.show()
		return
	_offer_the_way_on(Medal.NONE)


## How far from the start line to the finish the car got, from 0 to 1. A car
## that is off somewhere in the scenery is measured from the last checkpoint it
## banked, since the nearest point on the road to it could be anywhere.
func _how_far_along() -> float:
	var offset := _track.offset_of(_car.global_position)
	if not _on_course(offset):
		offset = _respawn
	var start := _track.start_offset()
	var run: float = maxf(_track.finish_offset() - start, 0.001)
	return clampf((offset - start) / run, 0.0, 1.0)


## Hang the medal on the top left corner of the panel.
##
## The disc sits *on* the corner rather than beside it, so the panel's own
## border runs under it - which is what makes it read as pinned to the box
## instead of floating next to one. Both live in the same space, so the corner
## the panel reports is the corner to hang it from.
func _pin_the_badge() -> void:
	if not _badge.visible:
		return
	_badge.pin_to(_result_panel.position + Vector2(16.0, 16.0))


## The two ways off a finished track: the same road again, or the next one.
##
## Put on the screen as buttons rather than left to the hint line, because
## this is the one moment in a run when the game is actually asking something
## - the rest of it the player is driving, and a line of small text along the
## bottom is right for keys that are always there and wrong for a question.
##
## The cursor starts on running it again, which is what a player who has just
## been told how far off the next medal they are almost always wants. Gold is
## the exception: there is nothing left to find on this road, so the cursor
## moves to the next one. A track with nothing after it yet keeps the button,
## greyed and saying why - the same nineteen doors the select screen shows.
func _offer_the_way_on(medal: int) -> void:
	var next := _next_track()
	_next_button.disabled = next < 0
	_next_button.tooltip_text = ("" if next >= 0
			else "This is the last track built so far.")
	# The hint line is about driving, and there is no driving to be done until
	# one of these is pressed.
	_hint.hide()
	_choice.show()
	if medal == Medal.GOLD and next >= 0:
		_next_button.grab_focus()
	else:
		_again_button.grab_focus()


## The slot after this one, or -1 when there is nothing built there yet. A
## track that is not on the roster at all has no next either, rather than
## quietly meaning the first one.
func _next_track() -> int:
	var here := TrackRoster.index_of(_track_file)
	# Not across from the last normal track into the first acrobatic one: the
	# next track is the next one in the grid it was picked from.
	if (here < 0 or not TrackRoster.exists(here + 1)
			or TrackRoster.kind_of(here + 1) != TrackRoster.kind_of(here)):
		return -1
	return here + 1


## On to the next road. The scene reads which track it is on the way up, so
## changing track means building it again - which is also what throws away the
## course, the best time and the targets belonging to the old one.
func _on_next_track() -> void:
	var next := _next_track()
	if next < 0:
		return
	GameSettings.track_file = TrackRoster.file(next)
	get_tree().reload_current_scene()


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
	_best_label.text = "BEST  %s" % RaceClock.format(_best)
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

## True once the car is past the finish line, still on the course, on the road,
## with every checkpoint banked. The corridor matters because a car lost out in
## the mountains can project onto any part of the centreline, the finish
## included; the road and the checkpoints because a car that fell into a jump
## could otherwise drive across the grass to the flag and set a time for it.
func _has_finished(offset: float) -> bool:
	if offset < _track.finish_offset():
		return false
	return (_car.on_the_road() and _on_course(offset)
			and _banked.count(1) == _banked.size())


## Bank any checkpoint the car is passing: on the course, on the road, and
## only just past it, so coming back onto the road further on does not bank the
## ones left behind. In any order; a reset goes to whichever was banked last.
func _bank_checkpoints(offset: float) -> void:
	if _track.has_rings():
		_bank_rings()
		return
	if not _car.on_the_road() or not _on_course(offset):
		return
	var marks := _track.checkpoint_offsets()
	for mark in mini(marks.size(), _banked.size()):
		if (_banked[mark] == 0 and offset >= marks[mark]
				and offset < marks[mark] + checkpoint_window):
			_banked[mark] = 1
			_respawn = marks[mark]
			_show_tally()


## Bank any ring the car went through this step. Not on the road, by the nature
## of the thing, and not in any window along the course: through the hole, the
## right way, is the whole rule. A banked ring goes dark, so the ones still owed
## are the ones still lit.
func _bank_rings() -> void:
	var now := _car.middle()
	for mark in _banked.size():
		if _banked[mark] == 0 and _track.through_ring(mark, _was, now):
			_banked[mark] = 1
			_respawn = _track.respawn_offset(mark)
			_track.show_ring(mark, true)
			_show_tally()
	_was = now


## Put the car back on the course at its last checkpoint, facing the right way
## and stopped. The clock keeps running: this is the way out of a hole in the
## road, and what it costs is the time it costs.
func _back_to_checkpoint() -> void:
	var here := _track.centre_at(_respawn)
	var ahead := _track.centre_at(minf(_respawn + 1.0, _track.length()))
	_car.global_position = here + Vector3.UP * grid_clearance
	var forward := ahead - here
	forward.y = 0.0
	if forward.length_squared() > 0.000001:
		_car.look_at(_car.global_position + forward.normalized(), Vector3.UP)
	_car.reset_motion()
	# Put back rather than driven back, so it is drawn at the checkpoint on the
	# next frame instead of streaking there from wherever it was.
	_car.reset_physics_interpolation()
	_was = _car.middle()
	_camera.follow(_car)


## Line the car up on the start line, facing down the course.
func _place_on_the_line() -> void:
	var at: float = maxf(_track.start_offset() - grid_setback, 0.0)
	var here := _track.centre_at(at)
	var ahead := _track.centre_at(at + 1.0)
	var forward := ahead - here
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		push_warning("Solo: degenerate course tangent at the start")
		forward = Vector3.FORWARD

	_car.global_position = here + Vector3.UP * grid_clearance
	_car.look_at(_car.global_position + forward.normalized(), Vector3.UP)
	_car.reset_motion()
	# Back on the line is the one place a car is mended. A checkpoint is not.
	_car.repair()
	# Put there, not driven there, so it is drawn on the line straight away
	# rather than sliding across the world for a frame.
	_car.reset_physics_interpolation()
	_respawn = at
	_banked = PackedByteArray()
	_banked.resize(_track.checkpoint_offsets().size())
	_was = _car.middle()
	for mark in _banked.size():
		_track.show_ring(mark, false)
	_show_tally()


func _show_tally() -> void:
	_tally.text = "%s %d / %d" % [
		"RING" if _track.has_rings() else "CHECKPOINT", _banked.count(1), _banked.size()]


func _on_course(offset: float) -> bool:
	return _car.global_position.distance_to(_track.centre_at(offset)) < finish_corridor
