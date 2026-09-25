class_name SettingsMenu
extends Control

## The settings screen, and the controls sheet behind it.
##
## It lays over whatever screen opened it rather than replacing it, so the
## title screen carries on turning behind the panel and nothing has to be torn
## down and rebuilt to come back.
##
## Statistics open from here too, over the same screen, so the lifetime totals
## can be found from the title and from a paused race alike. The page is the
## one the track screen opens; it lives inside this scene so it goes wherever
## the settings go.
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
@onready var _ui_scale: HSlider = $SettingsPage/Panel/Margin/Box/Interface/Slider
@onready var _ui_scale_value: Label = $SettingsPage/Panel/Margin/Box/Interface/Value
@onready var _sky_buttons: Array[Button] = [
	$SettingsPage/Panel/Margin/Box/Sky/Row/Normal,
	$SettingsPage/Panel/Margin/Box/Sky/Row/Day,
	$SettingsPage/Panel/Margin/Box/Sky/Row/Night,
]
## Off first, then on, so the button a player lands on is the one the game
## starts with.
@onready var _damage_buttons: Array[Button] = [
	$SettingsPage/Panel/Margin/Box/Damage/Row/Off,
	$SettingsPage/Panel/Margin/Box/Damage/Row/On,
]
@onready var _controls_button: Button = $SettingsPage/Panel/Margin/Box/Pages/Controls
@onready var _stats_button: Button = $SettingsPage/Panel/Margin/Box/Pages/Stats
@onready var _stats_page: StatsMenu = $StatsScreen
@onready var _close_button: Button = $SettingsPage/Panel/Margin/Box/Close
@onready var _controls_back: Button = $ControlsPage/Panel/Margin/Box/Back
@onready var _player_names: Array[Label] = [
	$ControlsPage/Panel/Margin/Box/Columns/P1/Name,
	$ControlsPage/Panel/Margin/Box/Columns/P2/Name,
]

## The setting each sky button stands for, in the same order as the buttons.
var _sky_values: Array[int] = []


func _ready() -> void:
	_sky_values = [
		GameSettings.NORMAL, GameSettings.ALWAYS_DAY, GameSettings.ALWAYS_NIGHT,
	]
	_volume.value_changed.connect(_on_volume_changed)
	_ui_scale.min_value = GameSettings.UI_SCALE_MIN * 100.0
	_ui_scale.max_value = GameSettings.UI_SCALE_MAX * 100.0
	_ui_scale.value_changed.connect(_on_ui_scale_changed)
	for i in _sky_buttons.size():
		_sky_buttons[i].pressed.connect(_on_sky_pressed.bind(i))
	for i in _damage_buttons.size():
		_damage_buttons[i].pressed.connect(_on_damage_pressed.bind(i == 1))
	_controls_button.pressed.connect(_show_controls)
	_close_button.pressed.connect(close)
	_controls_back.pressed.connect(_show_settings)
	_stats_button.pressed.connect(_show_stats)
	_stats_page.closed.connect(_on_stats_closed)

	_fill_controls($ControlsPage/Panel/Margin/Box/Columns/P1/Keys, "p1")
	_fill_controls($ControlsPage/Panel/Margin/Box/Columns/P2/Keys, "p2")
	hide()


## Show the screen from the top, with the current settings in it.
func open() -> void:
	_volume.set_value_no_signal(GameSettings.volume * 100.0)
	_show_volume_value()
	_ui_scale.set_value_no_signal(GameSettings.ui_scale * 100.0)
	_show_ui_scale_value()
	_show_sky_choice()
	_show_damage_choice()
	show()
	_show_settings()


func close() -> void:
	# The settings are written here rather than on every change, so dragging
	# the volume slider is not a file write per frame.
	GameSettings.save_settings()
	hide()
	closed.emit()


## Escape backs out one step: off the controls sheet, or off the screen.
##
## The statistics page backs out of itself, so it is left the key.
func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if _stats_page.visible:
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


## The settings panel steps aside rather than lying under the statistics, as it
## does for the controls sheet: one panel showing through another reads as a
## bug however faint it is.
func _show_stats() -> void:
	_settings_page.hide()
	_stats_page.open()


func _on_stats_closed() -> void:
	_settings_page.show()
	_stats_button.grab_focus()


func _show_controls() -> void:
	_settings_page.hide()
	_controls_page.show()
	# Each player's half is headed in the colour of their own car, so the sheet
	# says whose keys these are without having to be read. Taken from the
	# setting each time it opens rather than written into the scene, because
	# the players can repaint their cars from the pause screen.
	for i in _player_names.size():
		_player_names[i].add_theme_color_override(
			"font_color", Paints.legible(GameSettings.car_colour(i)))
	_controls_back.grab_focus()


func _on_volume_changed(value: float) -> void:
	GameSettings.volume = value / 100.0
	_show_volume_value()


## Dragging this rescales the screen the slider is on, which is the point:
## the player sees the size they are choosing while they choose it, rather
## than having to close the page to find out. The slider keeps its grab
## through it because it is measured in the laid-out space like everything
## else, and that space is what moved.
func _on_ui_scale_changed(value: float) -> void:
	GameSettings.ui_scale = value / 100.0
	_show_ui_scale_value()


func _on_sky_pressed(index: int) -> void:
	GameSettings.time_of_day = _sky_values[index]
	_show_sky_choice()


func _on_damage_pressed(on: bool) -> void:
	GameSettings.damage = on
	_show_damage_choice()


func _show_volume_value() -> void:
	_volume_value.text = "%d%%" % roundi(_volume.value)


## Read back from the setting rather than from the slider, because the setting
## clamps and the slider does not: a value out of a hand-edited settings file
## should show as the size actually being used.
func _show_ui_scale_value() -> void:
	_ui_scale_value.text = "%d%%" % roundi(GameSettings.ui_scale * 100.0)


## The chosen sky button is the one left held down. Setting this from the
## setting rather than from the click means the buttons are right even when
## the screen is opened on a choice made in a previous run.
func _show_sky_choice() -> void:
	for i in _sky_buttons.size():
		_sky_buttons[i].set_pressed_no_signal(
			_sky_values[i] == GameSettings.time_of_day)


## The same for damage: the button left held down is the one that is true.
func _show_damage_choice() -> void:
	for i in _damage_buttons.size():
		_damage_buttons[i].set_pressed_no_signal((i == 1) == GameSettings.damage)


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
## keyboard in front of the player, and a dash where nothing is bound.
##
## Naming it is Controls' job rather than this screen's, because the line that
## comes up when a car is off the road names one of these same keys in the
## middle of a race, and a sheet that disagreed with it would be worse than
## either on its own.
func _key_for(action: String) -> String:
	var key := Controls.key_for(action)
	return key if not key.is_empty() else "–"
