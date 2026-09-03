class_name SettingsMenu
extends Control

## The settings screen, and the controls sheet behind it.
##
## It lays over whatever screen opened it rather than replacing it, so the
## title screen carries on turning behind the panel and nothing has to be torn
## down and rebuilt to come back.
##
## The controls sheet is not a written list. It reads the keys straight out of
## the input map, so rebinding an action in the project settings changes what
## the players are shown - a list typed out here would be wrong the first time
## anyone moved a key.

## Emitted when the screen closes, so whoever opened it can take focus back.
signal closed

## What each half of the controls sheet shows, in the order it is shown, as
## the action's suffix and the name the players read.
const CONTROL_ROWS := [
	["accelerate", "Accelerate"],
	["brake", "Brake / reverse"],
	["steer_left", "Steer left"],
	["steer_right", "Steer right"],
	["reset", "Back to checkpoint"],
	["view", "Change view"],
]

@onready var _settings_page: Control = $SettingsPage
@onready var _controls_page: Control = $ControlsPage
@onready var _volume: HSlider = $SettingsPage/Panel/Margin/Box/Volume/Row/Slider
@onready var _volume_value: Label = $SettingsPage/Panel/Margin/Box/Volume/Row/Value
@onready var _sky_buttons: Array[Button] = [
	$SettingsPage/Panel/Margin/Box/Sky/Row/Normal,
	$SettingsPage/Panel/Margin/Box/Sky/Row/Day,
	$SettingsPage/Panel/Margin/Box/Sky/Row/Night,
]
@onready var _controls_button: Button = $SettingsPage/Panel/Margin/Box/Controls
@onready var _close_button: Button = $SettingsPage/Panel/Margin/Box/Close
@onready var _controls_back: Button = $ControlsPage/Panel/Margin/Box/Back

## The setting each sky button stands for, in the same order as the buttons.
var _sky_values: Array[int] = []


func _ready() -> void:
	_sky_values = [
		GameSettings.NORMAL, GameSettings.ALWAYS_DAY, GameSettings.ALWAYS_NIGHT,
	]
	_volume.value_changed.connect(_on_volume_changed)
	for i in _sky_buttons.size():
		_sky_buttons[i].pressed.connect(_on_sky_pressed.bind(i))
	_controls_button.pressed.connect(_show_controls)
	_close_button.pressed.connect(close)
	_controls_back.pressed.connect(_show_settings)

	_fill_controls($ControlsPage/Panel/Margin/Box/Columns/P1/Keys, "p1")
	_fill_controls($ControlsPage/Panel/Margin/Box/Columns/P2/Keys, "p2")
	hide()


## Show the screen from the top, with the current settings in it.
func open() -> void:
	_volume.set_value_no_signal(GameSettings.volume * 100.0)
	_show_volume_value()
	_show_sky_choice()
	show()
	_show_settings()


func close() -> void:
	# The settings are written here rather than on every change, so dragging
	# the volume slider is not a file write per frame.
	GameSettings.save_settings()
	hide()
	closed.emit()


## Escape backs out one step: off the controls sheet, or off the screen.
func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _controls_page.visible:
		_show_settings()
	else:
		close()


func _show_settings() -> void:
	_controls_page.hide()
	_settings_page.show()
	# Both players share one keyboard and neither has been asked to find the
	# mouse, so something on the new page always holds focus.
	_volume.grab_focus()


func _show_controls() -> void:
	_settings_page.hide()
	_controls_page.show()
	_controls_back.grab_focus()


func _on_volume_changed(value: float) -> void:
	GameSettings.volume = value / 100.0
	_show_volume_value()


func _on_sky_pressed(index: int) -> void:
	GameSettings.time_of_day = _sky_values[index]
	_show_sky_choice()


func _show_volume_value() -> void:
	_volume_value.text = "%d%%" % roundi(_volume.value)


## The chosen sky button is the one left held down. Setting this from the
## setting rather than from the click means the buttons are right even when
## the screen is opened on a choice made in a previous run.
func _show_sky_choice() -> void:
	for i in _sky_buttons.size():
		_sky_buttons[i].set_pressed_no_signal(
			_sky_values[i] == GameSettings.time_of_day)


## Lay out one player's half of the controls sheet: what the key does on the
## left of the column, the key itself on the right.
func _fill_controls(grid: GridContainer, prefix: String) -> void:
	for child in grid.get_children():
		child.queue_free()
	for row in CONTROL_ROWS:
		var action := "%s_%s" % [prefix, row[0]]
		var what := Label.new()
		what.text = row[1]
		what.add_theme_font_size_override("font_size", 22)
		what.add_theme_color_override("font_color", Color(0.78, 0.83, 0.93))
		var key := Label.new()
		key.text = _key_for(action)
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.custom_minimum_size = Vector2(96.0, 0.0)
		key.add_theme_font_size_override("font_size", 22)
		grid.add_child(what)
		grid.add_child(key)


## The key currently bound to an action, named the way it is printed on the
## keyboard in front of the player.
##
## The bindings are physical, which is what keeps WASD a square on a keyboard
## that is not laid out like this one - so the physical code has to be turned
## back into whatever this particular keyboard actually calls that key.
func _key_for(action: String) -> String:
	if not InputMap.has_action(action):
		return "–"
	for event in InputMap.action_get_events(action):
		var key := event as InputEventKey
		if key == null:
			continue
		var code := key.keycode
		if key.physical_keycode != 0:
			code = DisplayServer.keyboard_get_keycode_from_physical(
				key.physical_keycode)
		return OS.get_keycode_string(code)
	return "–"
