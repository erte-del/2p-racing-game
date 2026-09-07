class_name PaintMenu
extends Control

## The paint screen: one row of swatches per player, over a paused race.
##
## Pressing a swatch repaints the car immediately rather than on the way out.
## The race is right there behind the panel with the cars sitting on it, and a
## colour you can see on the car is the only way to find out whether it is the
## one you wanted - a paint chosen from a square and confirmed two presses
## later is a guess.
##
## Nothing here touches a car. It writes the choice to `GameSettings` and the
## race repaints from that, which is the same path the setting takes when it
## is loaded off disk at the start of a run. One way in means the car cannot
## end up wearing a colour the saved setting does not agree with.
##
## The two players cannot both be one colour. A split screen where the arrow
## pointing at your rival is your own paint is a race nobody can read, so a
## swatch the other player is already on is shown as taken rather than being
## quietly allowed to make that race.

## Emitted when the screen closes, so whoever opened it can take focus back.
signal closed

## How big one swatch is, and how many go across before the row wraps.
const SWATCH_SIZE := 54.0
const SWATCH_COLUMNS := 6

@onready var _columns: HBoxContainer = $Page/Panel/Margin/Box/Columns
@onready var _player_boxes: Array[VBoxContainer] = [
	$Page/Panel/Margin/Box/Columns/P1, $Page/Panel/Margin/Box/Columns/P2,
]
@onready var _names: Array[Label] = [
	$Page/Panel/Margin/Box/Columns/P1/Name,
	$Page/Panel/Margin/Box/Columns/P2/Name,
]
@onready var _grids: Array[GridContainer] = [
	$Page/Panel/Margin/Box/Columns/P1/Grid,
	$Page/Panel/Margin/Box/Columns/P2/Grid,
]
@onready var _back_button: Button = $Page/Panel/Margin/Box/Back

## How many cars are on the road: one column of swatches, or two.
var _players := 1


func _ready() -> void:
	_back_button.pressed.connect(close)
	for player in _grids.size():
		_grids[player].columns = SWATCH_COLUMNS
		_fill(player)
	hide()


## Show the screen, with as many columns as there are players.
func open(players: int) -> void:
	_players = clampi(players, 1, _grids.size())
	for player in _player_boxes.size():
		_player_boxes[player].visible = player < _players
	# Nobody is player one when they are the only car on the road.
	_names[0].text = "PLAYER 1" if _players > 1 else "YOUR CAR"
	_show_the_choices()
	show()
	# Both players share one keyboard and neither has been asked to find the
	# mouse, so the cursor starts on player one's current paint.
	_focus_chosen(0)


func close() -> void:
	# Written on the way out rather than on every swatch, so a player trying
	# each of the twelve in turn is not twelve writes to the disk.
	GameSettings.save_settings()
	hide()
	closed.emit()


## Escape backs out of the screen. Nothing inside it opens anything, so there
## is only ever the one step.
func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close()


## Lay out one player's twelve. Built here rather than in the scene because
## twenty-four buttons is a great deal of scene to write down, and every one
## of them would have to be edited again the day a colour was added.
func _fill(player: int) -> void:
	for index in Paints.COLOURS.size():
		var swatch := Button.new()
		swatch.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)
		swatch.focus_mode = Control.FOCUS_ALL
		swatch.pressed.connect(_choose.bind(player, index))
		_grids[player].add_child(swatch)


## Repaint the car, and say so where the choice is shown.
##
## The setting is what the race is watching, so this is the whole of it: the
## car outside the panel changes colour on the same frame the swatch does.
func _choose(player: int, index: int) -> void:
	GameSettings.set_car_colour(player, Paints.colour(index))
	_show_the_choices()


## Dress every swatch for what it currently is: the paint this player is
## wearing, a paint they could have, or one the other player has taken.
func _show_the_choices() -> void:
	for player in _players:
		var mine := GameSettings.car_colour(player)
		var theirs := GameSettings.car_colour(1 - player) if _players > 1 else Color.TRANSPARENT
		_names[player].add_theme_color_override("font_color", _legible(mine))
		var swatches := _grids[player].get_children()
		for index in swatches.size():
			var swatch := swatches[index] as Button
			var colour := Paints.colour(index)
			var taken := _players > 1 and colour.is_equal_approx(theirs)
			var chosen := colour.is_equal_approx(mine)
			swatch.disabled = taken
			swatch.tooltip_text = ("%s - taken by the other player" %
				Paints.name_of(index)) if taken else Paints.name_of(index)
			_dress(swatch, colour, chosen, taken)


## Give a swatch its faces. Every state is overridden, because a button that
## goes back to the theme's dark grey the moment it is hovered is not a
## swatch - the colour *is* the control here, and it has to survive being
## pointed at, pressed, focused and refused.
func _dress(swatch: Button, colour: Color, chosen: bool, taken: bool) -> void:
	var shown := colour
	if taken:
		# Faded rather than crossed out. It is still legibly that colour, so a
		# player can see where their rival is sitting on the same twelve.
		shown = colour.lerp(Color(0.09, 0.11, 0.16), 0.62)
	swatch.add_theme_stylebox_override("normal", _face(shown, chosen, 0.0))
	swatch.add_theme_stylebox_override("disabled", _face(shown, false, 0.0))
	swatch.add_theme_stylebox_override("hover", _face(shown, chosen, 0.18))
	swatch.add_theme_stylebox_override("pressed", _face(shown, chosen, -0.12))
	swatch.add_theme_stylebox_override("focus", _face(shown, chosen, 0.18))


## One face of a swatch. `lift` brightens it for hover and darkens it for a
## press, so a swatch answers to the mouse the way every other button does.
##
## The chosen one is marked with a thick pale border rather than with a tick:
## a mark drawn on top of the colour is a mark that disappears into the pale
## paints and glares out of the dark ones, while the border sits outside it
## and reads the same against all twelve.
func _face(colour: Color, chosen: bool, lift: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour.lightened(lift) if lift > 0.0 else colour.darkened(-lift)
	box.set_corner_radius_all(6)
	box.border_color = (Color(0.98, 0.99, 1.0) if chosen
			else Color(0.898, 0.929, 1.0, 0.22))
	box.set_border_width_all(4 if chosen else 2)
	return box


## Put the cursor on the paint this player is already wearing, so the screen
## opens on the answer it is asking about.
func _focus_chosen(player: int) -> void:
	var index := Paints.index_of(GameSettings.car_colour(player))
	var swatches := _grids[player].get_children()
	if index >= 0 and index < swatches.size():
		var wanted := swatches[index] as Button
		if wanted != null and not wanted.disabled:
			wanted.grab_focus()
			return
	_back_button.grab_focus()


## A paint as a colour to write words in. A car can be painted black, and a
## heading in it would be a heading nobody can read, so anything too dark to
## sit on the panel is lifted until it can be.
func _legible(colour: Color) -> Color:
	if colour.v < 0.55:
		colour.v = 0.55
	return colour
