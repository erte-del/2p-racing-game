class_name Menu
extends Control

## The title screen: the name of the game, a button to start it and a button
## to change the settings, over the game itself.
##
## Play does not drop straight into a race. It asks which mode first: the
## endless course the game has always been, or laid-out tracks. Tracks is
## there and deliberately dead: the shape the game is heading towards is
## better shown as a button that is not ready yet than sprung on the players
## later.
##
## The mode page opens showing only the two modes. Infinite does not start a
## race either: it opens out, sliding the choice between a normal race and a
## chaotic one down from under itself, and it is that second click that
## starts the game. Asking one question at a time keeps the page down to what
## the players are actually deciding at that moment.
##
## What chaos actually does lives in `Chaos`; all that is settled here is
## which of the two the players picked.
##
## The backdrop is a real instance of the race scene in attract mode - the same
## generated course, scenery and day/night cycle the players are about to
## drive, with two cars parked on the grid - turning slowly under the title.
## Being the real thing rather than a picture means it can never go stale.
##
## The title never sits perfectly still either. It rocks and bobs gently, which
## is what keeps a screen that is doing nothing from looking frozen.

## The scene the Play button starts.
@export_file("*.tscn") var race_scene := "res://scenes/main.tscn"

@export_group("Backdrop")
## How fast the view turns about the cars, in degrees per second. A full
## circuit at 4 deg/s takes a minute and a half, which reads as drifting rather
## than as a turntable.
@export var orbit_speed := 4.0
## How far out and how high the camera sits, in metres.
@export var orbit_radius := 16.0
@export var orbit_height := 5.0
## Where the camera aims, above the point it is turning about.
@export var look_height := 1.4
## Where it starts, in degrees, so the cars open side on rather than tail on.
@export var orbit_start := 55.0

@export_group("Idle motion")
## How far the title rocks either side of upright, in degrees.
@export var tilt_degrees := 2.5
## How long one rock across and back takes, in seconds.
@export var tilt_period := 2.6
## How far it bobs, in pixels.
@export var bounce_pixels := 7.0
## Deliberately not a multiple of the rock: two motions on the same beat read
## as one mechanical wobble, while two that drift apart read as idling.
@export var bounce_period := 1.7

@export_group("Mode choice")
## How long the flavour buttons take to roll out from under infinite. Long
## enough to read as movement, short enough that a player who knows what they
## want is not waiting on it.
@export var slide_seconds := 0.22

@onready var _title: Label = $TitleSlot/Title
@onready var _play: Button = $Play
@onready var _settings_button: Button = $Settings
@onready var _settings_screen: SettingsMenu = $SettingsScreen
@onready var _mode_choice: Control = $ModeChoice
@onready var _infinite_button: Button = $ModeChoice/Page/Panel/Margin/Box/Infinite
@onready var _mode_back: Button = $ModeChoice/Page/Panel/Margin/Box/Back
@onready var _flavour_slot: Control = $ModeChoice/Page/Panel/Margin/Box/FlavourSlot
@onready var _flavour_inner: Control = $ModeChoice/Page/Panel/Margin/Box/FlavourSlot/Inner
@onready var _normal_button: Button = $ModeChoice/Page/Panel/Margin/Box/FlavourSlot/Inner/Row/Normal
@onready var _chaos_button: Button = $ModeChoice/Page/Panel/Margin/Box/FlavourSlot/Inner/Row/Chaos
@onready var _world: Node3D = $World
@onready var _orbit: Camera3D = $Orbit

var _elapsed := 0.0
var _flavour_tween: Tween


func _ready() -> void:
	_play.pressed.connect(_on_play_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_settings_screen.closed.connect(_on_settings_closed)
	_infinite_button.pressed.connect(_on_infinite_pressed)
	_mode_back.pressed.connect(_close_mode_choice)
	_normal_button.pressed.connect(_start_infinite.bind(false))
	_chaos_button.pressed.connect(_start_infinite.bind(true))
	# The slot is a plain Control, so nothing lays its contents out but this.
	_flavour_slot.resized.connect(_fit_flavour)
	# So the keyboard alone can start the game - both players are on one
	# keyboard, and neither has been asked to find the mouse yet.
	_play.grab_focus()


func _process(delta: float) -> void:
	_elapsed += delta
	_turn_the_backdrop()
	# The pivot has to be re-centred every frame: the label's size is not known
	# until it has been laid out, and it changes with the window.
	_title.pivot_offset = _title.size * 0.5
	_title.rotation = deg_to_rad(
		tilt_degrees * sin(TAU * _elapsed / tilt_period))
	# The label rides inside a slot that the layout positions, so its own
	# resting position is always zero. Bobbing it from a captured position
	# would drift, and would be wrong again the moment the window resized.
	_title.position = Vector2(
		0.0, bounce_pixels * sin(TAU * _elapsed / bounce_period))


## Swing the camera round the parked cars. The centre is asked for every frame
## rather than taken once: the backdrop generates its own course, and the grid
## is wherever that course happens to start.
func _turn_the_backdrop() -> void:
	var centre: Vector3 = _world.grid_centre()
	var angle := deg_to_rad(orbit_start + orbit_speed * _elapsed)
	_orbit.global_position = centre + Vector3(
		sin(angle) * orbit_radius, orbit_height, cos(angle) * orbit_radius)
	_orbit.look_at(centre + Vector3.UP * look_height, Vector3.UP)


## Play opens the mode choice over the title rather than starting a race, so
## the backdrop keeps turning behind it the way the settings do.
func _on_play_pressed() -> void:
	# Always opens closed, however it was left last time.
	_shut_flavour()
	_mode_choice.show()
	_infinite_button.grab_focus()


## Infinite is a door rather than a start: it opens out into the choice
## between a normal race and a chaotic one, and closes again if pressed a
## second time.
func _on_infinite_pressed() -> void:
	if _flavour_slot.visible:
		_slide_flavour(false)
		_infinite_button.grab_focus()
	else:
		_slide_flavour(true)
		_normal_button.grab_focus()


func _start_infinite(chaos: bool) -> void:
	GameSettings.chaos = chaos
	# Settled at the start of the race rather than on every press, so opening
	# and closing the choice is not a file write per click.
	GameSettings.save_settings()
	get_tree().change_scene_to_file(race_scene)


## Hold the flavour buttons to the width of the page.
##
## They hang inside a plain Control rather than a container, because a
## container would insist on being tall enough for them and so could never
## collapse. The cost of that is having to set their width here: left to its
## own anchors the row sizes itself to nothing in particular, spreads the two
## buttons across it, and hangs them out over both edges of the panel.
func _fit_flavour() -> void:
	_flavour_inner.size.x = _flavour_slot.size.x


## Roll the flavour buttons out from under the infinite button, or back under
## it, pushing everything below them down as they come.
##
## The slot is what the layout sees, so growing its minimum height is what
## moves the rest of the page; the buttons themselves ride up inside it and
## are clipped, which is what makes them slide rather than simply appear. The
## height is asked of the contents rather than written down here, so it stays
## right if the wording or the font ever changes.
func _slide_flavour(open: bool) -> void:
	if _flavour_tween:
		_flavour_tween.kill()
	_fit_flavour()
	var height: float = _flavour_inner.get_combined_minimum_size().y
	if open:
		_flavour_slot.show()
		_flavour_slot.custom_minimum_size.y = 0.0
		_flavour_inner.position.y = -height
		_flavour_slot.modulate.a = 0.0

	_flavour_tween = create_tween()
	_flavour_tween.set_parallel(true)
	_flavour_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flavour_tween.tween_property(_flavour_slot, "custom_minimum_size:y",
		height if open else 0.0, slide_seconds)
	_flavour_tween.tween_property(_flavour_inner, "position:y",
		0.0 if open else -height, slide_seconds)
	_flavour_tween.tween_property(_flavour_slot, "modulate:a",
		1.0 if open else 0.0, slide_seconds)
	if not open:
		# Hidden rather than merely flat, or the gap the layout leaves either
		# side of the slot stays behind as a hole in the page.
		_flavour_tween.chain().tween_callback(_flavour_slot.hide)


## Shut the choice with no animation, for opening the page on it rather than
## closing it in front of the players.
func _shut_flavour() -> void:
	if _flavour_tween:
		_flavour_tween.kill()
	_flavour_slot.hide()
	_flavour_slot.custom_minimum_size.y = 0.0
	_flavour_slot.modulate.a = 0.0


func _close_mode_choice() -> void:
	_mode_choice.hide()
	_shut_flavour()
	_play.grab_focus()


## Escape backs out of the mode choice. The settings screen handles its own,
## and it lies over this one, so it gets first refusal on the key.
func _input(event: InputEvent) -> void:
	if not _mode_choice.visible or _settings_screen.visible:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	# One step at a time: off the flavour choice, then off the page.
	if _flavour_slot.visible:
		_slide_flavour(false)
		_infinite_button.grab_focus()
	else:
		_close_mode_choice()


## The settings lie over the title screen rather than replacing it, so the
## backdrop keeps turning and the title keeps rocking behind them.
func _on_settings_pressed() -> void:
	_settings_screen.open()


func _on_settings_closed() -> void:
	# Coming back to a screen with nothing focused would leave the keyboard
	# dead, so the button that opened the settings takes focus again.
	_settings_button.grab_focus()
