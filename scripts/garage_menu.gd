class_name GarageMenu
extends Control

## The garage: a tile per car, a column per player, over a paused race.
##
## Pressing a tile puts that player in that car immediately rather than on the
## way out, for the reason the paint screen does the same - the race is right
## there behind the panel with the cars sitting on it, and a car you can see on
## the road is the only way to find out whether it is the one you wanted.
##
## Nothing here touches a car. It writes the choice to `GameSettings` and the
## race dresses from that, which is the same path the setting takes when it is
## loaded off disk at the start of a run. One way in means a player cannot end
## up driving something the save file disagrees with.
##
## The two players may drive the same car. Paint refuses that, because the
## arrow pointing at your rival is their colour and two identical cars is a
## race nobody can read - but the paint is still doing that job here, so two
## players in the same model wearing different colours is perfectly legible.
##
## Adding, turning and removing act on whichever tile the cursor is on, rather
## than on a car chosen a second time in some other list. There is exactly one
## thing on this screen that is "the car being talked about", and it is the one
## the player is looking at.

## Emitted when the screen closes, so whoever opened it can take focus back.
signal closed

const TILE := Vector2(212, 172)

@onready var _columns: HBoxContainer = $Page/Panel/Margin/Box/Columns
@onready var _player_boxes: Array[VBoxContainer] = [
	$Page/Panel/Margin/Box/Columns/P1, $Page/Panel/Margin/Box/Columns/P2,
]
@onready var _names: Array[Label] = [
	$Page/Panel/Margin/Box/Columns/P1/Name,
	$Page/Panel/Margin/Box/Columns/P2/Name,
]
@onready var _grids: Array[VBoxContainer] = [
	$Page/Panel/Margin/Box/Columns/P1/Scroll/Grid,
	$Page/Panel/Margin/Box/Columns/P2/Scroll/Grid,
]
@onready var _add_button: Button = $Page/Panel/Margin/Box/Actions/Add
@onready var _turn_button: Button = $Page/Panel/Margin/Box/Actions/Turn
@onready var _remove_button: Button = $Page/Panel/Margin/Box/Actions/Remove
@onready var _message: Label = $Page/Panel/Margin/Box/Message
@onready var _back_button: Button = $Page/Panel/Margin/Box/Back
@onready var _picker: FileDialog = $Picker

## How many cars are on the road: one column of tiles, or two.
var _players := 1
## Which car the cursor is sitting on, and which player's column it is in.
var _under_the_cursor := ""
## Pictures already loaded, so moving up and down the list is not a file read
## per keypress.
var _portraits := {}


func _ready() -> void:
	_back_button.pressed.connect(close)
	_add_button.pressed.connect(_on_add_pressed)
	_turn_button.pressed.connect(_on_turn_pressed)
	_remove_button.pressed.connect(_on_remove_pressed)

	_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.use_native_dialog = true
	_picker.title = "Pick a car"
	_picker.filters = PackedStringArray(["*.glb, *.gltf ; Models"])
	_picker.file_selected.connect(_on_file_picked)
	hide()


## Show the screen, with as many columns as there are players.
func open(players: int) -> void:
	_players = clampi(players, 1, _grids.size())
	for player in _player_boxes.size():
		_player_boxes[player].visible = player < _players
	# Nobody is player one when they are the only car on the road.
	_names[0].text = "PLAYER 1" if _players > 1 else "YOUR CAR"
	_say("")
	_rebuild()
	show()
	_focus_chosen(0)
	_draw_what_has_no_picture()


func close() -> void:
	# Written on the way out rather than on every tile, so a player trying
	# each car in turn is not a write to the disk per press.
	GameSettings.save_settings()
	hide()
	closed.emit()


## Escape backs out of the screen. The file picker is a window of its own and
## takes its own key, so there is only ever the one step here.
func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if _picker.visible:
		return
	get_viewport().set_input_as_handled()
	close()


## Lay out the tiles: the stock car first, then everything in the garage in
## the order it was added. Built here rather than in the scene because what
## goes in it is different on every machine.
func _rebuild() -> void:
	var listing := _listing()
	for player in _grids.size():
		for old in _grids[player].get_children():
			_grids[player].remove_child(old)
			old.queue_free()
		for car: Dictionary in listing:
			_grids[player].add_child(_tile(player, car))
	_show_the_choices()


## Every car that can be driven: the one the game came with, and the garage.
func _listing() -> Array:
	var listing: Array = [{"id": Garage.STOCK, "name": Garage.name_of(Garage.STOCK)}]
	listing.append_array(Garage.cars())
	return listing


func _tile(player: int, car: Dictionary) -> Button:
	var id := str(car["id"])
	var tile := Button.new()
	tile.custom_minimum_size = TILE
	tile.text = str(car["name"])
	tile.icon = _portrait(id)
	tile.expand_icon = true
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tile.clip_text = true
	tile.set_meta("car", id)
	tile.pressed.connect(_choose.bind(player, id))
	# The cursor is what "this car" means for turning and removing, so every
	# tile says so as it is arrived at, by keyboard or by mouse alike.
	tile.focus_entered.connect(_on_tile_focused.bind(id))
	tile.mouse_entered.connect(_on_tile_focused.bind(id))
	return tile


## Put a player in a car. The setting is what the race is watching, so this is
## the whole of it: the car outside the panel changes on the next frame.
func _choose(player: int, id: String) -> void:
	GameSettings.set_car_id(player, id)
	_show_the_choices()


func _on_tile_focused(id: String) -> void:
	_under_the_cursor = id
	_show_what_can_be_done()


## Mark the tile each player is driving, in every column.
func _show_the_choices() -> void:
	for player in _players:
		var mine := GameSettings.car_id(player)
		for tile: Button in _grids[player].get_children():
			_dress(tile, str(tile.get_meta("car", "")) == mine)
	_show_what_can_be_done()


## Turning and removing are things done to a car, and the stock car is not
## one of ours to do them to. The buttons say so by going quiet rather than
## by disappearing, so the row does not change shape as the cursor moves.
func _show_what_can_be_done() -> void:
	var mine := Garage.has(_under_the_cursor)
	_turn_button.disabled = not mine
	_remove_button.disabled = not mine
	var why := "" if mine else "The car the game came with cannot be changed."
	_turn_button.tooltip_text = why
	_remove_button.tooltip_text = why


## The chosen tile is marked with a thick pale border rather than with a tick,
## for the reason the paint swatches are: a mark drawn on top of a picture is
## a mark that disappears into the pale cars and glares out of the dark ones.
func _dress(tile: Button, chosen: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.13, 0.15, 0.21)
		if state == "hover" or state == "focus":
			box.bg_color = box.bg_color.lightened(0.10)
		elif state == "pressed":
			box.bg_color = box.bg_color.darkened(0.12)
		box.set_corner_radius_all(8)
		box.content_margin_bottom = 8
		box.border_color = (Color(0.98, 0.99, 1.0) if chosen
				else Color(0.898, 0.929, 1.0, 0.22))
		box.set_border_width_all(4 if chosen else 2)
		tile.add_theme_stylebox_override(state, box)


func _on_add_pressed() -> void:
	_picker.popup_centered_ratio(0.6)


## What the player picked, read and checked before anything is written down.
## Whatever comes back is said on the screen: a car that would not load is the
## one moment on here where a person needs a sentence rather than a tile.
func _on_file_picked(path: String) -> void:
	var added := Garage.add(path)
	if not added.ok:
		_say(str(added.error))
		return
	_rebuild()
	_say("Added %s." % Garage.name_of(str(added.id)))
	_draw_what_has_no_picture()


## Nothing can work out which end of an arbitrary model is the front, so the
## game guesses and this is how a player says it guessed wrong.
func _on_turn_pressed() -> void:
	var id := _under_the_cursor
	if not Garage.has(id):
		return
	Garage.turn(id, Garage.quarter_turns(id) + 1)
	# The picture is of the old way round, so it goes and is drawn again.
	_portraits.erase(id)
	DirAccess.remove_absolute(Garage.portrait_path(id))
	_rebuild()
	_focus_on(id)
	_draw_what_has_no_picture()


## Take a car out of the garage. A player sitting in it is put back in the
## stock one by the race itself, which is where that belongs - this screen
## does not reach out and redress anybody.
func _on_remove_pressed() -> void:
	var id := _under_the_cursor
	if not Garage.has(id):
		return
	var gone := Garage.name_of(id)
	Garage.remove(id)
	_portraits.erase(id)
	_under_the_cursor = Garage.STOCK
	_rebuild()
	_focus_chosen(0)
	_say("Removed %s." % gone)


## Draw a picture for anything that has not got one yet, filling the tiles in
## as they come. Done after the screen is already up rather than before it,
## because a garage of a dozen cars is a dozen models to load and nobody
## should be looking at nothing while that happens.
func _draw_what_has_no_picture() -> void:
	for car: Dictionary in _listing():
		var id := str(car["id"])
		if _portraits.has(id) or FileAccess.file_exists(Garage.portrait_path(id)):
			continue
		var model := Garage.model_for(id)
		if model == null:
			continue
		var drawn: bool = await CarPortrait.keep(self, model, Garage.portrait_path(id))
		if not drawn:
			continue
		_portraits.erase(id)
		_put_the_picture_up(id)


## Hand the same picture to every tile showing that car, in both columns.
func _put_the_picture_up(id: String) -> void:
	var picture := _portrait(id)
	for player in _grids.size():
		for tile: Button in _grids[player].get_children():
			if str(tile.get_meta("car", "")) == id:
				tile.icon = picture


func _portrait(id: String) -> Texture2D:
	if _portraits.has(id):
		return _portraits[id]
	var where := Garage.portrait_path(id)
	if not FileAccess.file_exists(where):
		return null
	var image := Image.load_from_file(where)
	if image == null:
		return null
	var picture := ImageTexture.create_from_image(image)
	_portraits[id] = picture
	return picture


## Put the cursor on the car this player is already driving, so the screen
## opens on the answer it is asking about.
func _focus_chosen(player: int) -> void:
	if not _focus_on(GameSettings.car_id(player), player):
		_back_button.grab_focus()


func _focus_on(id: String, player := 0) -> bool:
	if player >= _grids.size():
		return false
	for tile: Button in _grids[player].get_children():
		if str(tile.get_meta("car", "")) == id:
			tile.grab_focus()
			return true
	return false


func _say(what: String) -> void:
	_message.text = what
	_message.visible = not what.is_empty()
