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
##
## A bot road is the other thing this scene does, and the one place where the
## clock is not the whole point. There a second car is built in code and driven
## by BotDriver, the two cars race, and what is measured is which of them
## crossed the line - no time written down, no medal earned, because a bot road
## is a door rather than a track. It lands here rather than in Main with the
## split collapsed because a bot race is a one-player thing, and everything
## Main is about is there being two of everything: two viewports, two cameras,
## two clocks, two keyboards. What it takes here is one more car, one arrow and
## a place readout, and the road, the camera and the HUD are the ones that were
## already there.

## The visual layer the world is drawn on, which is the only one this scene
## uses: there is one camera here, so nothing has to be hidden from a second
## view the way Main's private overlays do. The rival arrow goes on it like
## everything else.
const LAYER_WORLD := 1

## The car the bot drives, built from the same scene the player's is: it is the
## same car, differently driven, which is the whole of what stops a bot being
## quicker than the player.
const BOT_CAR_SCENE := "res://scenes/car/car.tscn"

## The colour the bot's car is always painted.
##
## Fixed rather than GameSettings.car_colour(1), because the bot is not player
## two. It is the same rival on every bot road, and a rival wearing whatever
## colour the second keyboard last chose would be a different car every time -
## a player who has learnt to watch for the amber one should not have to find
## out what colour the amber one is today.
##
## Amber because it is the one hue that holds up against every sky this game
## has. It is nowhere near the grass or the tarmac, it does not sink into a
## sunset or a night the way navy and black do, and it does not wash out against
## a bright noon sky the way white does.
const BOT_COLOUR := Color(0.98, 0.55, 0.06)

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
## How far either side of the middle the two cars of a bot race sit, in metres.
## One car on its own starts on the middle of the road, so this is only ever
## used when there is a second one.
@export var grid_spread := 3.6
## How far from the centreline still counts as being on the course, for
## deciding that the finish line was actually crossed.
@export var finish_corridor := 25.0
## How far past a checkpoint the car can still bank it, in metres, for the
## reason the race gives.
@export var checkpoint_window := 30.0

@export_group("Bot race")
## How good the bot is, from 0 to 1. One, because tools/checks/bot_race.gd says
## that is where it comes in around each track's gold - which is the "hard to
## beat" a bot road is for. Anything lower is a door that opens itself.
@export_range(0.0, 1.0) var bot_difficulty := 1.0
## How long a frame may spend working the bot's line out, in milliseconds.
##
## The whole of that line is half a second of work on The Gate, so it cannot
## happen on one frame: it is spread across the countdown a few milliseconds at
## a time. Four is small enough to be invisible in a sixteen millisecond frame
## and big enough that The Gate is planned in two of the three seconds the
## countdown lasts. A road whose line takes longer than its countdown holds the
## count rather than dropping a frame - see _start_after_countdown.
@export var plan_budget_ms := 4.0
## Metres of lead before the place readout says who is leading, and how far back
## inside counts as level again. Two numbers so it cannot strobe while the cars
## run wheel to wheel; the rule itself is Places'.
@export var lead_margin := 1.5
@export var level_margin := 0.6

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
@onready var _place: Label = $Hud/Corner/Box/Place
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
@onready var _lost: LostPrompt = $Hud/Lost
@onready var _choice: Control = $Hud/Result/Centre/Panel/Margin/Box/Choice
@onready var _again_button: Button = $Hud/Result/Centre/Panel/Margin/Box/Choice/Row/Restart
@onready var _next_button: Button = $Hud/Result/Centre/Panel/Margin/Box/Choice/Row/Next
@onready var _arrow: RivalArrow = $Arrow
@onready var _pause: PauseMenu = $Pause

## Ticking between GO and the line.
var _running := false
var _time := 0.0
## Which track is being driven and which way, and the best run on it so far -
## below zero for a track nobody has finished. Held here as well as written
## down, so the screen has something to compare against without reading a file
## per lap.
var _track_file := ""
var _track_variant := TrackVariant.NORMAL
var _best := -1.0
## True when nothing picked a track, which is the endless course: a fresh road
## every time, so there is no time to beat and nothing to write down. What the
## clock is for there is the run you are on.
var _endless := false
## True when the road being driven is a bot road: a race against one
## computer-driven car rather than a run against the clock. Read once on the way
## in, the way the track is.
var _bot_race := false
## The bot's car and the driver behind it, both built in _ready and only on a
## bot road. Null everywhere else, which is the point of building them here
## instead of leaving them in solo.tscn: the endless course and the nineteen
## time trials must not pay for a car they do not have.
var _bot: Car
var _bot_driver: BotDriver
## The bot's own run down the same road: where a reset puts it, which
## checkpoints it has banked, and where its middle was a step ago. Its own set
## of all three, because two cars on one road are two runs, and a checkpoint
## one of them drove over is not one the other did.
var _bot_respawn := 0.0
var _bot_banked := PackedByteArray()
var _bot_was := Vector3.ZERO
## Who is ahead - 0 the player, 1 the bot - or -1 while they are level.
var _leader := -1
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
	_bot_race = TrackRoster.is_bot_road(_track_file)
	# A way the track does not offer is not driven, whatever asked for it: it
	# is a road nobody has checked, and a time on it would be a time on that.
	_track_variant = GameSettings.track_variant
	if _track_variant not in TrackVariant.offered(_track_file):
		_track_variant = TrackVariant.NORMAL
	# Nothing to draft behind and nothing to be shown an arrow to, until the bot
	# race puts a second car on the road.
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
		_track.variant = _track_variant
		_track.generate(0)
		# A bot road keeps no time and hands out no medal, so there is nothing
		# to read back and nothing to compare a run against. Left where they
		# started - no best, no targets - which is what leaves the corner of the
		# screen and the badge empty.
		if not _bot_race:
			_best = TrackTimes.best(_track_file, _track_variant)
			_targets = _track_targets()

	# Told rather than left to read the setting, the same way the wood is. The
	# bot is never told: its car is BOT_COLOUR and undecorated for the life of
	# the scene, for the reason `_build_the_bot` gives.
	_car.set_decals_wild(_chaos != null)

	# After the track is built, since what a lap of it is worth is read off
	# the track rather than described a second time.
	_result.hide()
	# The second car, once there is a road for it. Its driver comes later, once
	# the cars are on the grid: a line is planned for a car standing somewhere.
	if _bot_race:
		_build_the_bot()
	else:
		# Nothing for it to point at. Hidden already, but an arrow left with a
		# physics step is an arrow this scene is paying for on every other road
		# in the game.
		_arrow.set_physics_process(false)
	# The car and the paint the player chose, and a standing offer to change
	# either: the pause screen writes to the setting rather than reaching in
	# here, so a car or a swatch picked mid-run lands through the same path the
	# saved choice takes at the start of one. The garage is listened to as
	# well, because turning or deleting a car changes what is being driven
	# without changing which car was picked.
	_apply_cars()
	_apply_paint()
	_apply_decoration()
	GameSettings.changed.connect(_apply_cars)
	GameSettings.changed.connect(_apply_paint)
	GameSettings.changed.connect(_apply_decoration)
	Garage.changed.connect(_apply_cars)
	Decals.changed.connect(_on_decals_changed)
	_lines.watch(_car)
	# One player, one keyboard. Everything solo reads is a `solo_*` action,
	# which answers to player one's keys and player two's both, so either hand
	# drives, resets and changes the view.
	_lost.watch(_car, _track, "solo_reset")
	_place_on_the_line()
	# Now, and not in _build_the_bot, because the practice laps set off from
	# wherever the car is standing when the plan begins - which has to be the
	# grid, not wherever a freshly built car happened to land.
	if _bot != null:
		_start_the_bot_driving()
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
	# A bot road is a door, not a track in a row, so the second button is the way
	# back rather than the way on. Said once here rather than every time the
	# panel goes up: it is the same two ways out for the whole of the scene.
	if _bot_race:
		_again_button.text = "RACE AGAIN"
		_next_button.text = "BACK TO TRACKS"
	# The keys are read out of the input map rather than typed here, for the
	# reason the line that comes up off the road reads them: a key that moves
	# should move everywhere it is named, or nowhere.
	_hint.text = "%s  %s        %s  back to the last checkpoint        %s  view        ESC  pause" % [
		Controls.key_for("restart").to_upper(),
		"next course" if _endless else "run again",
		Controls.key_for("solo_reset").to_upper(),
		Controls.key_for("solo_view").to_upper()]
	_start_after_countdown()


## The bot's car was put into the scene by hand, so it is taken out of it by
## hand. The driver goes first: the car holds the driver and the driver holds the
## car, and the two cars hold each other, and a knot that only comes undone when
## the whole scene does is a knot that outlives the scene.
##
## The session's driving is flushed on the way out as well, so closing the
## window or leaving mid-race does not lose it.
func _exit_tree() -> void:
	Stats.flush()
	if _bot == null:
		return
	_bot.driver = null
	_bot_driver = null
	_bot.rival = null
	_car.rival = null
	_bot.queue_free()
	_bot = null


## Build the bot's car, paint it, and hand it a driver.
##
## Everything the bot has is here, and it is deliberately little: a car off the
## same scene the player's comes off, and something to work its pedals and its
## wheel. Nothing in this scene ever sets the bot's speed or turns its body. It
## is beaten by driving better than it, not by being given less than it, and a
## bot that cheats is the fastest way there is to make a player stop trusting a
## game.
func _build_the_bot() -> void:
	_bot = (load(BOT_CAR_SCENE) as PackedScene).instantiate() as Car
	# Never read, because the bot's car is asked for input rather than reading
	# the map - but a second car answering to player one on the one keyboard is
	# a trap waiting for the day something forgets to give it a driver.
	_bot.input_prefix = "p2"
	# Damage on both cars or on neither. A race where one car can be worn out
	# and the other cannot is not the race the setting turned on.
	_bot.damage = GameSettings.damage
	add_child(_bot)
	# The stock car, for the same reason the paint is fixed: the rival is the
	# same rival on every bot road, and one wearing whatever the player last
	# imported into the garage would be a different car every time - and on the
	# day the player is driving that model, two of the same car.
	Garage.dress(_bot, Garage.STOCK)
	_bot.repaint(BOT_COLOUR)
	# Both ways round, or the slipstream works for neither of them: a car only
	# drafts behind a car it has been told about.
	_car.rival = _bot
	_bot.rival = _car
	# The two shoving each other rather than passing through, settled in one
	# place for both of them at once; CarContact says why.
	add_child(CarContact.new(_car, _bot))

	# One camera in this scene, so the arrow needs no culling layer of its own -
	# there is no second view for it to leak into. Main's per-player layers are
	# a split screen's problem, and this is not a split screen.
	_arrow.show()
	_arrow.setup(_car, _bot, BOT_COLOUR, LAYER_WORLD, _camera)
	# The place readout is a bot race's alone. Hidden rather than blank, so the
	# clock under it does not sit a line lower on every other road.
	_place.show()


## Hand the bot's car its driver, and set the line going.
##
## Begun here and not finished here. Working the line out is about half a second
## on The Gate, and half a second on one frame is a hitch at the exact moment the
## player is watching a countdown, so _process carries it on a few milliseconds a
## frame and the countdown waits on it. That is what the countdown's three
## seconds are good for: nothing else is happening in them.
func _start_the_bot_driving() -> void:
	_bot_driver = BotDriver.new(_track, _bot, bot_difficulty)
	# Told about the player for the two reasons the player's car is told about
	# it: to draft behind it, and to go round it rather than into it.
	_bot_driver.rival = _car
	_bot.driver = _bot_driver


func _process(_delta: float) -> void:
	var level := smoothstep(lights_on_at, lights_full_at, _day_night.night_amount())
	_car.set_headlights(level)
	if _bot != null:
		_bot.set_headlights(level)
	# A few milliseconds of the bot's line, on every frame until it is worked
	# out. Here rather than in _physics_process because what is being protected
	# is the frame the player sees, and here rather than all at once in _ready
	# because all at once is half a second of nothing, right where the player is
	# watching a countdown.
	if _bot_driver != null and not _bot_driver.is_planned():
		_bot_driver.plan_a_little(plan_budget_ms)


func _physics_process(delta: float) -> void:
	# Both of these work whether or not the clock is running, so a player held
	# on the line can look around, and one sitting on a finished run can start
	# another without waiting for anything.
	if Input.is_action_just_pressed("solo_view"):
		_camera.set_inside(not _camera.is_inside())
	# Not while the finished run is offering the choice: the same key works
	# the button the cursor is on, and a track that restarted itself on the
	# press that asked for the next one would be doing both.
	if Input.is_action_just_pressed("restart") and not _choice.visible:
		_restart()
		return
	if not _running:
		# A car held on the line, or sat on a finished run, is not lost.
		_lost.forget()
		return
	# Broken on the step before this one. The clock is stopped where the car
	# stopped, not a step after it. On a bot road either car breaking ends the
	# race, so both are asked.
	if _car.is_broken() or (_bot != null and _bot.is_broken()):
		if _bot_race:
			_bot_broke_down()
		else:
			_break_down()
		return

	_time += delta
	_clock.text = RaceClock.format(_time)
	# Only while the clock runs, so a car driven about on the line or on a
	# finished run cannot farm kilometres. The player's car and never the bot's:
	# nobody drove the bot. Speed without its sign, because reversing out of a
	# hedge is driving too.
	Stats.add_distance(absf(_car.speed()) * delta, delta)
	# Before the cars move, so what they drive into this step is where the
	# clock says it is. The bot is told for the same reason the track is: the
	# traps run on the race clock, and a bot that does not know the time drives
	# into them.
	_track.set_race_time(_time)
	if _bot_driver != null:
		_bot_driver.race_time = _time
	if Input.is_action_just_pressed("solo_reset"):
		# Counted here, at the key, rather than in _back_to_checkpoint: the bot
		# goes down that same path, and the bot asking is not the player asking.
		Stats.reset_taken()
		_back_to_checkpoint()
		return
	# The bot asking to be put back is the bot pressing the key, and it goes
	# down the same path the key does - there is one way onto a checkpoint in
	# this scene and this is it. Then it is told, or it would go on driving as
	# though it were still where it was.
	if _bot_driver != null and _bot_driver.wants_reset():
		_back_to_checkpoint(_bot)
	# Looked up once for everything below, because finding the nearest point on
	# the curve is a walk along the whole of it.
	var offset := _track.offset_of(_car.global_position)
	_lost.check(delta, offset)
	_bank_checkpoints(_car, offset)
	if _bot == null:
		if _has_finished(_car, offset):
			_finish()
		return

	var theirs := _track.offset_of(_bot.global_position)
	_bank_checkpoints(_bot, theirs)
	_show_places(offset, theirs)
	# The player is asked first, so a dead heat inside one physics step - the
	# smallest piece of time this race has - goes to the player rather than to
	# whichever car the physics happened to move first.
	if _has_finished(_car, offset):
		_won_the_race()
	elif _has_finished(_bot, theirs):
		_lost_the_race()


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
##
## The bot's car is not in here. It is the stock car on every bot road, for the
## reason _build_the_bot gives, so turning or deleting a car in the garage is
## nothing to do with it.
func _apply_cars() -> void:
	Garage.dress(_car, GameSettings.car_id(0))


## Put the player's colour on the car. Chaos is the one thing that overrules
## it: it repaints the car for every course on purpose, and a chosen colour
## landing back on it halfway through would be the mode failing to do the one
## thing it says it does.
##
## The bot's car is not repainted here either, and neither is the arrow that
## points at it: both are BOT_COLOUR for the life of the scene, so there is
## nothing for a settings change to move.
func _apply_paint() -> void:
	if _chaos != null:
		return
	_car.repaint(GameSettings.car_colour(0))


## Put whatever the player's car has been decorated with back on it. Chaos does
## not overrule this: it turns the decoration through the colours and leaves
## the shapes alone, which is what `Car.set_decals_wild` is for.
##
## The bot's car is bare, for the reason its paint is fixed: the rival is the
## same car on every bot road, and a rival wearing the player's own stickers
## would be a split second of wondering which of them was which at the line.
func _apply_decoration() -> void:
	_car.decorate(Decals.marks_on(GameSettings.car_id(0)))


func _on_decals_changed(_id: String) -> void:
	_apply_decoration()


# --- pausing ------------------------------------------------------------

## What the pause screen says it is sitting on top of.
##
## The endless course has no name to give and no road to go back to, so it is
## named by what it is and its way out is the title screen. A laid-out track
## names itself, and leaving it goes back to the grid it was picked from -
## which is where the menu opens anyway, since nothing has cleared the track
## that is still chosen.
func _open_pause() -> void:
	Stats.flush()
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


## A run given up counts as nothing but the driving in it, and the driving is
## kept on purpose, for the reason a coin picked up on it is: it was driven.
func _on_pause_quit() -> void:
	Stats.flush()
	get_tree().change_scene_to_file(menu_scene)


# --- the run ------------------------------------------------------------

## Put the car back on the line and count it down again. This is the whole of
## a retry: the track is not rebuilt, because it is the same track and
## rebuilding it would cost a second of watching a road appear that was
## already there.
##
## A run restarted halfway announced nothing, so it completes nothing; only its
## driving is kept, as it is for a run quit from the pause screen.
func _restart() -> void:
	_running = false
	Stats.flush()
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
	for car in _on_the_road():
		car.frozen = true
		car.reset_motion()
	_time = 0.0
	_clock.text = RaceClock.format(0.0)
	# The traps wait at GO with the car, so what the player reads off the
	# course while it counts down is what they will meet. The bot waits with
	# them: it reads a trap off the same clock.
	_track.set_race_time(0.0)
	if _bot_driver != null:
		_bot_driver.race_time = 0.0

	var steps: int = maxi(1, int(round(preview_seconds)))
	var each := preview_seconds / float(steps)
	for remaining in range(steps, 0, -1):
		_countdown.text = str(remaining)
		await get_tree().create_timer(each, false).timeout
		if run != _countdown_run:
			return

	# The bot cannot be let go until it knows where it is going, and a driver
	# still working that out drives nowhere. The countdown is three seconds and
	# The Gate's line takes two of them, so this is normally already true by the
	# time the count runs out. When it is not, the count holds where it is and
	# the plan goes on a few milliseconds a frame - a held countdown rather than
	# a dropped frame, which is the whole point of spreading it.
	#
	# Planned here rather than left to _process, even though _process is doing
	# exactly this: the pause screen pauses the tree, and a paused tree has no
	# _process. A player who opened it while the line was still being worked out
	# would come back to a countdown waiting on a plan nothing was carrying on.
	while _bot_driver != null and not _bot_driver.is_planned():
		_bot_driver.plan_a_little(plan_budget_ms)
		await get_tree().process_frame
		if run != _countdown_run:
			return

	_countdown.text = "GO"
	_hint.hide()
	for car in _on_the_road():
		car.frozen = false
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
		# Every course crossed on the endless one is a completed race, which is
		# why the count climbs steadily there. Never a win: nobody was beaten.
		Stats.race_finished(false, false)
		await _and_on_to_the_next()
		return

	# Offered to the record before anything is said about it, so what appears
	# on the screen is what was actually written down.
	var beaten := TrackTimes.record(_track_file, _time, _track_variant)
	# A time trial is completed and never won - it has nobody to beat. What it
	# earns instead is a medal, and that is counted as a medal.
	Stats.race_finished(false, false)

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
	# Completed, and a wreck. It ended in a result, just a bad one.
	Stats.race_finished(false, false)
	Stats.wrecked()
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
	if not _on_course(_car, offset):
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
	# A bot road is a door rather than a track in a row, so there is no next one
	# from it. The button under it says so, and does the one thing left: back to
	# the tracks it was opened from.
	if _bot_race:
		_on_pause_quit()
		return
	var next := _next_track()
	if next < 0:
		return
	GameSettings.track_file = TrackRoster.file(next)
	# Driven the same way, where the next track offers it: a player working
	# through the mirrored tracks wants the next mirrored one.
	GameSettings.track_variant = (_track_variant
		if _track_variant in TrackVariant.offered(GameSettings.track_file)
		else TrackVariant.NORMAL)
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


# --- winning and losing a bot race --------------------------------------

## The player got there first.
##
## Counted here and in its neighbours rather than in _write_the_win_down, which
## is about Progress opening a block. The two are not the same question: a draw
## is a completed race that is neither.
func _won_the_race() -> void:
	_stop_the_race(true)
	Stats.race_finished(true, true)
	_write_the_win_down()
	_say_who_won("YOU WIN", "BY %s" % _how_far_back(_bot), Color.WHITE)


## A won bot race is the only result in the game that opens anything, so it is
## the only one written down rather than merely shown. Everything else a race
## produces is a time, and a time is `TrackTimes`' business.
##
## Called from both ways of winning. Beating the bot to the flag and outlasting
## it are the same win: the road is shut behind a race, and the race is over.
func _write_the_win_down() -> void:
	var block := TrackRoster.block_of_bot_road(_track_file)
	if block >= 0:
		Progress.win(block)


## The bot did.
func _lost_the_race() -> void:
	_stop_the_race(true)
	Stats.race_finished(true, false)
	_say_who_won("THE BOT WINS", "BY %s" % _how_far_back(_car),
		_condition.warning_colour)


## A car wore out, and the race is over: there is nobody left for the other one
## to race, and it does not have to drive the rest of the road to prove it. Both
## breaking on the same step is a draw and says so, rather than being handed to
## whichever car the physics moved first.
##
## The cars are left where they broke, in the air if that is where they were, for
## the reason _break_down gives.
##
## Each of the three counts differently, and the draw is the one that gets
## forgotten: a completed race, the player's wreck, and no win. The bot's car
## breaking is never a wreck - nobody was driving it.
func _bot_broke_down() -> void:
	_stop_the_race(false)
	Stats.race_finished(true, _bot.is_broken() and not _car.is_broken())
	if _car.is_broken():
		Stats.wrecked()
	if _car.is_broken() and _bot.is_broken():
		_say_who_won("DRAW", "BOTH CARS BROKEN", _condition.warning_colour)
	elif _bot.is_broken():
		_write_the_win_down()
		_say_who_won("YOU WIN", "THE BOT BROKE DOWN", Color.WHITE)
	else:
		_say_who_won("THE BOT WINS", "YOUR CAR BROKE DOWN",
			_condition.warning_colour)


## How far a car still had to drive when the race ended, as a distance.
##
## A distance and not a time, because the clock stopped when the first car
## crossed: the other one has not finished, and how long it would have taken is
## not something this race knows. The road it still had is the one true measure
## of the gap at the moment the race ended.
func _how_far_back(car: Car) -> String:
	var behind: float = maxf(
		_track.finish_offset() - _track.offset_of(car.global_position), 0.0)
	return "%d m" % roundi(behind)


## Hold both cars where they are and stop the clock.
func _stop_the_race(settle: bool) -> void:
	_running = false
	_hint.show()
	for car in _on_the_road():
		car.frozen = true
		# A car that broke keeps whatever it was doing; only a car that was
		# still driving is put down.
		if settle:
			car.reset_motion()
	# Set outright rather than left on whatever the last step wrote, so the
	# clock in the corner and the time in the middle are the same number.
	_clock.text = RaceClock.format(_time)


## Put the verdict on the panel that a time trial puts a medal on.
##
## The same panel because it is the same question answered - how did that go -
## and a second panel for it would be a second thing to lay out, place a badge
## on and keep in step with the first. What changes is what the lines say: the
## time is still the time, the medal line carries who won, and the note carries
## by how much.
func _say_who_won(verdict: String, note: String, colour: Color) -> void:
	_result_time.text = RaceClock.format(_time)
	_result_medal.text = verdict
	_result_medal.add_theme_color_override("font_color", colour)
	_result_note.text = note
	_result.show()
	# No medal on a bot road. There is no time kept on one for a medal to be
	# worth, and a blank disc hanging off the corner of the panel would be
	# asking the player to wonder what they had missed.
	_badge.show_medal(Medal.NONE)
	# The hint line is about driving, and there is no driving to be done until
	# one of these is pressed. Both are always offered: a door can be tried
	# again, and the way out of one leads back to the tracks it was opened from,
	# whichever way the race went.
	_next_button.disabled = false
	_next_button.tooltip_text = ""
	_hint.hide()
	_choice.show()
	_again_button.grab_focus()


# --- where the car is ---------------------------------------------------

## True once a car is past the finish line, still on the course, on the road,
## with every checkpoint banked. The corridor matters because a car lost out in
## the mountains can project onto any part of the centreline, the finish
## included; the road and the checkpoints because a car that fell into a jump
## could otherwise drive across the grass to the flag and set a time for it.
##
## Asked of a car rather than of the car, because on a bot road two of them are
## driving down it and the rule is the same one for both. The bot does not get an
## easier finish than the player.
func _has_finished(car: Car, offset: float) -> bool:
	if offset < _track.finish_offset():
		return false
	var banked := _bot_banked if car == _bot else _banked
	return (car.on_the_road() and _on_course(car, offset)
			and banked.count(1) == banked.size())


## Bank any checkpoint a car is passing: on the course, on the road, and only
## just past it, so coming back onto the road further on does not bank the ones
## left behind. In any order; a reset goes to whichever was banked last.
##
## The player and the bot bank separately - two cars on one road are two runs -
## but by this one rule, so the car says which set of flags is being written and
## the rule itself is written once.
func _bank_checkpoints(car: Car, offset: float) -> void:
	var bot := car == _bot
	if _track.has_rings():
		_bank_rings(car)
		return
	if not car.on_the_road() or not _on_course(car, offset):
		return
	var banked := _bot_banked if bot else _banked
	var marks := _track.checkpoint_offsets()
	var any := false
	for mark in mini(marks.size(), banked.size()):
		if (banked[mark] == 0 and offset >= marks[mark]
				and offset < marks[mark] + checkpoint_window):
			banked[mark] = 1
			any = true
			if bot:
				_bot_respawn = marks[mark]
			else:
				_respawn = marks[mark]
	# Written back rather than written through: a packed array handed to a local
	# is a copy of it, so the flags set above are set on the copy.
	if bot:
		_bot_banked = banked
		return
	_banked = banked
	if any:
		_show_tally()


## Bank any ring a car went through this step. Not on the road, by the nature of
## the thing, and not in any window along the course: through the hole, the right
## way, is the whole rule. A ring the player banked goes dark, so the ones still
## owed are the ones still lit.
##
## Only the player's. Both cars are looking at the same rings, and one going out
## because the bot flew through it would be telling the player about the wrong
## run.
func _bank_rings(car: Car) -> void:
	var bot := car == _bot
	var banked := _bot_banked if bot else _banked
	var was := _bot_was if bot else _was
	var now := car.middle()
	var any := false
	for mark in banked.size():
		if banked[mark] == 0 and _track.through_ring(mark, was, now):
			banked[mark] = 1
			any = true
			if bot:
				_bot_respawn = _track.respawn_offset(mark)
			else:
				_respawn = _track.respawn_offset(mark)
				_track.show_ring(mark, true)
	if bot:
		_bot_banked = banked
		_bot_was = now
		return
	_banked = banked
	_was = now
	if any:
		_show_tally()


## Put a car back on the course at its last checkpoint, facing the right way
## and stopped. The clock keeps running: this is the way out of a hole in the
## road, and what it costs is the time it costs.
##
## Null is the player's car, so the key and anything driving this scene from
## outside reach it by name with nothing to pass. The bot comes down the same
## path with its own car, because there is one way onto a checkpoint here and a
## bot rescued by a second one would be a bot rescued by different rules.
func _back_to_checkpoint(car: Car = null) -> void:
	var bot := car != null and car == _bot
	if car == null:
		car = _car
	var at := _bot_respawn if bot else _respawn
	var here := _track.centre_at(at)
	var ahead := _track.centre_at(minf(at + 1.0, _track.length()))
	car.global_position = here + Vector3.UP * grid_clearance
	var forward := ahead - here
	forward.y = 0.0
	if forward.length_squared() > 0.000001:
		car.look_at(car.global_position + forward.normalized(), Vector3.UP)
	car.reset_motion()
	# Put back rather than driven back, so it is drawn at the checkpoint on the
	# next frame instead of streaking there from wherever it was.
	car.reset_physics_interpolation()
	if bot:
		_bot_was = car.middle()
		# Told, or it goes on driving as though it were still where it was, and
		# asks to be put back again on the next step.
		_bot_driver.reset_progress()
	else:
		_was = car.middle()
		_camera.follow(car)
		# Asked for and given: the line has said what it had to say.
		_lost.forget()
	# Either car moving is a new bearing between them, and swinging round to it
	# would spend a moment pointing at a car that is no longer there.
	if _bot != null:
		_arrow.snap()


## Line the car up on the start line, facing down the course - or both cars side
## by side on it, the way the two-player grid does it, when there is a bot to
## race. Deriving the grid from the curve means it keeps working for every road.
func _place_on_the_line() -> void:
	var at: float = maxf(_track.start_offset() - grid_setback, 0.0)
	var here := _track.centre_at(at)
	var ahead := _track.centre_at(at + 1.0)
	var forward := ahead - here
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		push_warning("Solo: degenerate course tangent at the start")
		forward = Vector3.FORWARD
	forward = forward.normalized()

	# One car sits on the middle of the road. Two go either side of it, and no
	# further apart than the road at the line has room for, in case it opens
	# narrow.
	var side := 0.0
	if _bot != null:
		var room: float = maxf(_track.half_width_at(at) - 1.6, 0.5)
		side = minf(grid_spread, room)
	var across := forward.cross(Vector3.UP)

	_start_car(_car, here - across * side, forward)
	_respawn = at
	_banked = _no_checkpoints_yet()
	_was = _car.middle()
	if _bot != null:
		_start_car(_bot, here + across * side, forward)
		_bot_respawn = at
		_bot_banked = _no_checkpoints_yet()
		_bot_was = _bot.middle()
		# A fresh race is a driver that has never been down this road: the line
		# is the same one, but where it thinks the car is along it is not.
		#
		# Null on the way into the first race, where the driver comes after the
		# grid. And left alone while the line is still being worked out, which a
		# player pressing the restart key during the countdown can land in: the
		# practice laps run on this same progress, and resetting it in the middle
		# of one would be resetting the rehearsal rather than the race. There is
		# nothing to lose by waiting - a finished plan resets it on its way out.
		if _bot_driver != null and _bot_driver.is_planned():
			_bot_driver.reset_progress()
		_arrow.snap()
		# Read after the cars are on the grid, or this hands someone a lead they
		# no longer have. Both are the same distance along, so it is nobody.
		_leader = -1
		_show_places(at, at)
	for mark in _banked.size():
		_track.show_ring(mark, false)
	_show_tally()
	_lost.forget()


## Set a car down on the grid, facing down the course.
func _start_car(car: Car, at: Vector3, forward: Vector3) -> void:
	car.global_position = at + Vector3.UP * grid_clearance
	# look_at aims -Z, which is the car's forward.
	car.look_at(car.global_position + forward, Vector3.UP)
	car.reset_motion()
	# Back on the line is the one place a car is mended. A checkpoint is not.
	car.repair()
	# Put there, not driven there, so it is drawn on the line straight away
	# rather than sliding across the world for a frame.
	car.reset_physics_interpolation()


## A clean sheet of checkpoint flags for one car's run.
func _no_checkpoints_yet() -> PackedByteArray:
	var none := PackedByteArray()
	none.resize(_track.checkpoint_offsets().size())
	return none


## Every car actually on the road: the player's, and the bot's when there is
## one. What the countdown holds and lets go, and what a result stops.
func _on_the_road() -> Array[Car]:
	return [_car] if _bot == null else [_car, _bot]


## Who is leading, shown only on a bot road because it is the only place there
## is anyone to lead. When a lead counts as a lead is Places' rule, not this
## scene's: the two-player race asks the same question of the same two margins,
## and two copies of that rule would sooner or later disagree.
func _show_places(mine: float, theirs: float) -> void:
	_leader = Places.leader(mine - theirs, _leader, level_margin, lead_margin)
	if _leader < 0:
		_place.text = "\u2013"
	else:
		_place.text = "1st" if _leader == 0 else "2nd"


func _show_tally() -> void:
	_tally.text = "%s %d / %d" % [
		"RING" if _track.has_rings() else "CHECKPOINT", _banked.count(1), _banked.size()]


func _on_course(car: Car, offset: float) -> bool:
	return car.global_position.distance_to(_track.centre_at(offset)) < finish_corridor
