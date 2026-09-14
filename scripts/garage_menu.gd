class_name GarageMenu
extends Control

## The garage: every car there is to drive, a tile each, over a paused race.
##
## Pressing a tile puts the player in that car immediately rather than on the
## way out, for the same reason the paint screen repaints immediately. The race
## is right there behind the panel with the cars parked on it, and seeing the
## car on the road is the only way to know it is the one you wanted.
##
## Nothing here touches a car. Picking one writes the choice to `GameSettings`
## and the race dresses the car from that, which is the same path the choice
## takes when it is loaded off the disk at the start of a run.
##
## Everything else on the page - adding a car, turning one, removing one - acts
## on whichever tile the cursor or the keyboard is on. There is only ever one
## car being talked about, so a button never has to ask which car it means,
## and a player never has to wonder.
##
## A .blend can be added as well as a .glb, by handing it to Blender. That is
## the one thing here that takes long enough to notice, so the page says it is
## happening before it starts, and nothing on it can be pressed until it has
## finished.

## Emitted when the screen closes, so whoever opened it can take focus back.
signal closed

## One tile: the portrait over the name.
const TILE_SIZE := Vector2(208.0, 170.0)
const COLUMNS := 2

const QUIET := Color(0.72, 0.76, 0.86)
const WRONG := Color(0.98, 0.55, 0.5)
const RIGHT := Color(0.6, 0.9, 0.68)

@onready var _player_boxes: Array[VBoxContainer] = [
	$Page/Panel/Margin/Box/Columns/P1, $Page/Panel/Margin/Box/Columns/P2,
]
@onready var _names: Array[Label] = [
	$Page/Panel/Margin/Box/Columns/P1/Name,
	$Page/Panel/Margin/Box/Columns/P2/Name,
]
@onready var _scrolls: Array[ScrollContainer] = [
	$Page/Panel/Margin/Box/Columns/P1/Scroll,
	$Page/Panel/Margin/Box/Columns/P2/Scroll,
]
@onready var _grids: Array[GridContainer] = [
	$Page/Panel/Margin/Box/Columns/P1/Scroll/Grid,
	$Page/Panel/Margin/Box/Columns/P2/Scroll/Grid,
]
@onready var _add_button: Button = $Page/Panel/Margin/Box/Actions/Add
@onready var _turn_button: Button = $Page/Panel/Margin/Box/Actions/Turn
@onready var _remove_button: Button = $Page/Panel/Margin/Box/Actions/Remove
@onready var _find_blender_button: Button = $Page/Panel/Margin/Box/Actions/FindBlender
@onready var _status: Label = $Page/Panel/Margin/Box/Status
@onready var _back_button: Button = $Page/Panel/Margin/Box/Back

## How many cars are on the road: one column of tiles, or two.
var _players := 1
## The car the page is talking about: the tile the cursor or the keyboard was
## last on. Every action on the page means this car.
var _subject := Garage.STOCK
## True while a car is being brought in. Everything on the page is refused
## while it is, not just ADD: a second file would mean two Blenders writing over
## each other's output, and a car removed or a screen closed halfway through is
## a status line with nobody left to read it.
var _busy := false
## True while portraits are being drawn, and whether something asked for more
## to be drawn while they were.
var _drawing := false
var _draw_again := false
var _pick_file: FileDialog
var _pick_blender: FileDialog


func _ready() -> void:
	_back_button.pressed.connect(close)
	_add_button.pressed.connect(_on_add_pressed)
	_turn_button.pressed.connect(_on_turn_pressed)
	_remove_button.pressed.connect(_on_remove_pressed)
	_find_blender_button.pressed.connect(_on_find_blender_pressed)
	for grid in _grids:
		grid.columns = COLUMNS
	# A car added, turned or removed from anywhere - this page, or a download
	# landing while it is open - is a page showing the old garage.
	Garage.changed.connect(_on_garage_changed)
	_build_the_file_picker()
	_build_the_blender_picker()
	hide()


## Show the screen, with as many columns as there are players.
func open(players: int) -> void:
	_players = clampi(players, 1, _grids.size())
	for player in _player_boxes.size():
		_player_boxes[player].visible = player < _players
	# Nobody is player one when they are the only car on the road.
	_names[0].text = "PLAYER 1" if _players > 1 else "YOUR CAR"
	# Only offered to a player who needs it. Asked every time the page opens
	# rather than once, since Blender may have been installed in the meantime.
	_find_blender_button.visible = not Blender.here()
	if not _busy:
		_say("", QUIET)
	_subject = _driven(0)
	_fill()
	show()
	# Both players share one keyboard and neither has been asked to find the
	# mouse, so the cursor starts on player one's current car - and every
	# player's grid is scrolled to show the car they are in.
	for player in _players:
		_scroll_to(player, _driven(player))
	_focus_car(0, _driven(0))
	_draw_missing_portraits()


func close() -> void:
	# Written on the way out rather than on every press, so trying every car in
	# the garage in turn is not a write to the disk per tile.
	GameSettings.save_settings()
	hide()
	closed.emit()


## Escape backs out of the screen. The file pickers are windows of their own and
## take their own Escape, so this only ever sees the ones meant for the page.
## Not while a car is coming in, for the reason BACK is refused then too.
func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if not _busy:
		close()


# --- the tiles ----------------------------------------------------------

## Every car there is to drive, stock car first.
func _listing() -> Array:
	return [{"id": Garage.STOCK, "name": Garage.name_of(Garage.STOCK)}] + Garage.cars()


## Lay out a tile per car per player. Built here rather than in the scene
## because the garage is whatever the player has put in it.
##
## Rebuilt whole rather than patched, and the keyboard put back on the tile it
## was on: a car that has gone takes its tile with it, and one that arrived
## needs one, and working out which is which is more code than building a
## dozen buttons again.
func _fill() -> void:
	var focused := _focused_tile()
	for player in _grids.size():
		var grid := _grids[player]
		for tile in grid.get_children():
			grid.remove_child(tile)
			tile.queue_free()
		for car: Dictionary in _listing():
			grid.add_child(_tile(player, car.id, car.name))
	if not Garage.known(_subject):
		_subject = Garage.STOCK
	_show_the_choices()
	if not focused.is_empty() and visible:
		_focus_car(focused[0], focused[1] if Garage.known(focused[1])
			else _driven(focused[0]))


func _tile(player: int, id: String, called: String) -> Button:
	var tile := Button.new()
	tile.custom_minimum_size = TILE_SIZE
	tile.toggle_mode = true
	tile.focus_mode = Control.FOCUS_ALL
	tile.text = called
	tile.tooltip_text = called
	# Clipped rather than allowed to widen the tile: a name is whatever the
	# file was called, and somebody's file will be called something long.
	tile.clip_text = true
	tile.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tile.icon = Garage.portrait(id)
	tile.expand_icon = true
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tile.add_theme_font_size_override("font_size", 18)
	tile.disabled = _busy
	for state in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		tile.add_theme_stylebox_override(state, _tight(state))
	tile.set_meta("car", id)
	tile.pressed.connect(_choose.bind(player, id))
	# The car being talked about follows the keyboard and the mouse both, so
	# whichever a player is using is what the buttons below act on.
	tile.focus_entered.connect(_talk_about.bind(id))
	tile.mouse_entered.connect(_talk_about.bind(id))
	return tile


## The theme's face for a button with most of its padding taken off. The theme
## pads a button for a word; a tile is mostly picture, and a picture inset by
## the width of a word is a picture with a frame of nothing round it.
##
## The car a player is in is marked the way the paint screen marks a paint:
## with a thick pale border, which reads the same round a bright portrait and a
## dark one. The keyboard's face is only an outline, because it is drawn over
## the top of the tile and a filled one would hide which tile is held down
## exactly when the cursor is sitting on it.
func _tight(state: String) -> StyleBox:
	var face := get_theme_stylebox(
		"pressed" if state == "hover_pressed" else state, "Button").duplicate() as StyleBox
	face.content_margin_left = 6.0
	face.content_margin_right = 6.0
	face.content_margin_top = 6.0
	face.content_margin_bottom = 4.0
	var flat := face as StyleBoxFlat
	if flat != null:
		if state == "pressed" or state == "hover_pressed":
			flat.set_border_width_all(5)
			flat.border_color = Color(0.98, 0.99, 1.0)
		elif state == "focus":
			flat.draw_center = false
	return face


## Put a player in a car.
##
## The setting is what the race is watching, so this is the whole of it: the
## car outside the panel changes on the same frame the tile goes down.
func _choose(player: int, id: String) -> void:
	GameSettings.set_car_id(player, id)
	_talk_about(id)
	_show_the_choices()
	if _players > 1:
		_say("%s is in %s." % [_names[player].text.capitalize(), Garage.name_of(id)],
			QUIET)
	else:
		_say("You are in %s." % Garage.name_of(id), QUIET)


## Hold down the tile each player is sitting in, and let every other one up.
func _show_the_choices() -> void:
	for player in _grids.size():
		var driven := _driven(player)
		for tile in _grids[player].get_children():
			(tile as Button).set_pressed_no_signal(tile.get_meta("car") == driven)
	_update_actions()


## The car a player is actually driving: the one they picked, or the stock car
## if that is not in the garage any more.
func _driven(player: int) -> String:
	var id := GameSettings.car_id(player)
	return id if Garage.known(id) else Garage.STOCK


func _talk_about(id: String) -> void:
	_subject = id
	_update_actions()


## Turning and removing are about a car somebody brought. The stock car ships
## with the game and faces the right way already, and taking it out of the
## garage would leave the fallback for every other car with nothing to fall
## back on.
func _update_actions() -> void:
	var theirs := Garage.has(_subject)
	_add_button.disabled = _busy
	_find_blender_button.disabled = _busy
	_back_button.disabled = _busy
	_turn_button.disabled = _busy or not theirs
	_remove_button.disabled = _busy or not theirs
	for grid in _grids:
		for tile in grid.get_children():
			(tile as Button).disabled = _busy
	var named := Garage.name_of(_subject)
	_turn_button.tooltip_text = ("Turn %s a quarter of the way round." % named
		if theirs else "The stock car already faces the right way.")
	_remove_button.tooltip_text = ("Take %s out of the garage." % named
		if theirs else "The stock car cannot be taken out.")


# --- the actions --------------------------------------------------------

func _build_the_file_picker() -> void:
	_pick_file = FileDialog.new()
	_pick_file.title = "Bring in a car"
	_pick_file.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	# The whole disk, not the game's own folders: the car is wherever the
	# player saved it.
	_pick_file.access = FileDialog.ACCESS_FILESYSTEM
	_pick_file.filters = PackedStringArray(["*.glb, *.gltf, *.blend ; Car models"])
	_pick_file.use_native_dialog = true
	_pick_file.file_selected.connect(_on_file_picked)
	add_child(_pick_file)


func _build_the_blender_picker() -> void:
	_pick_blender = FileDialog.new()
	_pick_blender.title = "Where is Blender?"
	_pick_blender.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_pick_blender.access = FileDialog.ACCESS_FILESYSTEM
	_pick_blender.use_native_dialog = true
	_pick_blender.file_selected.connect(_on_blender_picked)
	add_child(_pick_blender)


func _on_add_pressed() -> void:
	if _busy:
		return
	_pick_file.popup_centered(Vector2i(900, 560))


func _on_file_picked(path: String) -> void:
	if _busy:
		return
	# Said before the wait rather than after it. A page that goes quiet for five
	# seconds with every button greyed out reads as a page that has hung.
	if path.get_extension().to_lower() == Garage.BLEND and Blender.here():
		_say("Handing %s to Blender. This takes a few seconds…" % path.get_file(), QUIET)
	_busy = true
	_update_actions()
	var answer: Dictionary = await Garage.add(path)
	_busy = false
	_update_actions()
	if not answer.ok:
		_say(str(answer.error), WRONG)
		return
	_subject = answer.id
	_fill()
	_focus_car(0, answer.id)
	if answer.new:
		_say("Added %s." % answer.name, RIGHT)
	else:
		_say("%s is already in the garage." % answer.name, QUIET)
	_draw_missing_portraits()


## One more quarter turn. The garage throws the old portrait away, and a new
## one is drawn the right way round.
func _on_turn_pressed() -> void:
	if _busy or not Garage.has(_subject):
		return
	var id := _subject
	Garage.turn(id, Garage.quarter_turns(id) + 1)
	_say("Turned %s a quarter of the way round." % Garage.name_of(id), QUIET)
	_draw_missing_portraits()


func _on_remove_pressed() -> void:
	if _busy or not Garage.has(_subject):
		return
	var named := Garage.name_of(_subject)
	Garage.remove(_subject)
	_subject = _driven(0)
	# The button that was pressed is about to be refused, and the keyboard
	# would be left on a button that cannot do anything.
	_focus_car(0, _driven(0))
	_say("Removed %s." % named, QUIET)


func _on_garage_changed() -> void:
	if visible:
		_fill()


## For a player whose Blender is somewhere this game did not think to look.
func _on_find_blender_pressed() -> void:
	if _busy:
		return
	_pick_blender.popup_centered(Vector2i(900, 560))


## Judged by its name before anything is remembered, and long before anything
## is run: what the player picked might be anything at all.
func _on_blender_picked(path: String) -> void:
	if not Blender.looks_right(path):
		_say("That does not look like Blender. Look for the program called Blender.",
			WRONG)
		return
	if not Blender.remember(path):
		_say("Blender is not there.", WRONG)
		return
	_find_blender_button.visible = not Blender.here()
	_say("Found Blender. A .blend can be added now.", RIGHT)
	_add_button.grab_focus()


# --- portraits ----------------------------------------------------------

## Draw the portrait of every car that has not got one yet, one at a time, and
## put each on its tiles as it lands.
##
## One at a time because each is a model loaded and a frame rendered, and a
## screen opening on a dozen of them at once is a screen that stutters open.
## A car that has been drawn before costs nothing: its picture is on the disk.
func _draw_missing_portraits() -> void:
	if _drawing:
		_draw_again = true
		return
	_drawing = true
	var more := true
	while more:
		_draw_again = false
		for car: Dictionary in _listing():
			if not visible:
				break
			if FileAccess.file_exists(Garage.portrait_path(car.id)):
				continue
			var drawn: bool = await Garage.draw_portrait(self, car.id)
			if drawn:
				_show_portrait(car.id)
		more = _draw_again and visible
	_drawing = false


func _show_portrait(id: String) -> void:
	var picture := Garage.portrait(id)
	for grid in _grids:
		for tile in grid.get_children():
			if tile.get_meta("car") == id:
				(tile as Button).icon = picture


# --- focus --------------------------------------------------------------

## Which player's tile, and which car, the keyboard is on - or nothing.
func _focused_tile() -> Array:
	var focused := get_viewport().gui_get_focus_owner()
	for player in _grids.size():
		if focused != null and focused.get_parent() == _grids[player]:
			return [player, str(focused.get_meta("car"))]
	return []


func _tile_for(player: int, id: String) -> Button:
	for tile in _grids[player].get_children():
		if tile.get_meta("car") == id:
			return tile as Button
	return null


func _focus_car(player: int, id: String) -> void:
	var tile := _tile_for(player, id)
	if tile == null:
		tile = _tile_for(player, Garage.STOCK)
	if tile != null and tile.is_visible_in_tree():
		tile.grab_focus()
		_talk_about(id)
		return
	_back_button.grab_focus()


func _scroll_to(player: int, id: String) -> void:
	var tile := _tile_for(player, id)
	if tile != null:
		_scrolls[player].ensure_control_visible(tile)


func _say(what: String, colour: Color) -> void:
	_status.text = what
	_status.add_theme_color_override("font_color", colour)
