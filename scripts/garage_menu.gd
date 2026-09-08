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
@onready var _share_button: Button = $Page/Panel/Margin/Box/Actions/Share
@onready var _browse_button: Button = $Page/Panel/Margin/Box/Actions/Browse
@onready var _find_button: Button = $Page/Panel/Margin/Box/Actions/Find
@onready var _picker: FileDialog = $Picker
@onready var _finder: FileDialog = $Finder
@onready var _shared_page: Control = $Shared
@onready var _shared_list: VBoxContainer = $Shared/Page/Panel/Margin/Box/Scroll/List
@onready var _shared_message: Label = $Shared/Page/Panel/Margin/Box/Message
@onready var _shared_back: Button = $Shared/Page/Panel/Margin/Box/Back

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
	# Said on the button rather than in the heading, where it would widen
	# the whole panel to carry a list only somebody about to press it needs.
	_add_button.tooltip_text = "A .glb, a .gltf, or a .blend if Blender is "\
			+ "on this machine."
	_turn_button.pressed.connect(_on_turn_pressed)
	_remove_button.pressed.connect(_on_remove_pressed)

	_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_picker.access = FileDialog.ACCESS_FILESYSTEM
	_picker.use_native_dialog = true
	_picker.title = "Pick a car"
	_picker.filters = PackedStringArray(["*.glb, *.gltf, *.blend ; Models"])
	_picker.file_selected.connect(_on_file_picked)

	_finder.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_finder.access = FileDialog.ACCESS_FILESYSTEM
	_finder.use_native_dialog = true
	_finder.title = "Where is Blender?"
	_finder.file_selected.connect(_on_blender_picked)
	_find_button.pressed.connect(_on_find_pressed)
	_share_button.pressed.connect(_on_share_pressed)
	_browse_button.pressed.connect(_on_browse_pressed)
	_shared_back.pressed.connect(_close_shared)
	# The list arrives whenever it arrives, and the Share button reads
	# differently once it has - so the screen follows it rather than
	# waiting on it.
	CarLibrary.catalogue_arrived.connect(_on_catalogue_arrived)
	hide()


## Show the screen, with as many columns as there are players.
func open(players: int) -> void:
	_players = clampi(players, 1, _grids.size())
	for player in _player_boxes.size():
		_player_boxes[player].visible = player < _players
	# Nobody is player one when they are the only car on the road.
	_names[0].text = "PLAYER 1" if _players > 1 else "YOUR CAR"
	_say("")
	# There is nothing to find until a player has tried to add a .blend
	# and been told there is no Blender, so the button is not standing
	# there on a machine where it would never be pressed.
	_find_button.visible = not Blender.here()
	# A build with no server in it does not grow buttons that cannot do
	# anything, the same as the Account and Leaderboard buttons.
	_share_button.visible = CarLibrary.available()
	_browse_button.visible = CarLibrary.available()
	_shared_page.hide()
	_rebuild()
	# Asked for in the background. Nothing on this screen waits on it;
	# what it changes is whether Share reads SHARE or UNSHARE, and that
	# is put right when the answer lands.
	if CarLibrary.available():
		CarLibrary.catalogue()
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
	if _picker.visible or _finder.visible:
		return
	get_viewport().set_input_as_handled()
	# One step at a time: off the shared cars, then off the garage.
	if _shared_page.visible:
		_close_shared()
		return
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
	if not _share_button.visible:
		return
	# Sharing is a thing done as somebody, and taking a car back down is
	# a thing only the person who put it up may do. The button says which
	# of the two it currently is rather than trying both and failing.
	var ours := mine and CarLibrary.is_mine(_under_the_cursor)
	_share_button.text = "UNSHARE" if ours else "SHARE"
	_share_button.disabled = not mine or not CarLibrary.can_share()
	_share_button.tooltip_text = ("" if CarLibrary.can_share()
			else "Sign in from the title screen to share a car.") if mine else why


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
	# Said before the wait rather than after it. A .blend goes out to
	# Blender, which is a second program starting up on a cold machine,
	# and a screen that sat there saying nothing for eight seconds is a
	# screen a player presses again.
	var blend := path.get_extension().to_lower() == Garage.BLEND
	_say(("Handing %s to Blender. This takes a few seconds…"
		if blend else "Reading %s…") % path.get_file())
	_working(true)
	var added: Dictionary = await Garage.add(path)
	_working(false)
	if not added.ok:
		_say(str(added.error))
		_find_button.visible = not Blender.here()
		return
	_rebuild()
	_say("Added %s." % Garage.name_of(str(added.id)))
	_draw_what_has_no_picture()


## Put this car up for everybody, or take it back down.
##
## Which of the two it is comes from the list rather than from a flag kept
## here: the server is the one that knows what is shared, and a button reading
## off anything else would be wrong the moment somebody unshared a car on
## another machine.
func _on_share_pressed() -> void:
	var id := _under_the_cursor
	if not Garage.has(id):
		return
	var taking_down := CarLibrary.is_mine(id)
	_say("Taking %s down…" % Garage.name_of(id) if taking_down
		else "Sharing %s…" % Garage.name_of(id))
	_working(true)
	# Written out rather than as one awaited ternary: the branches of a
	# ternary are called before the await ever sees them.
	var answer: Dictionary
	if taking_down:
		answer = await CarLibrary.unpublish(id)
	else:
		answer = await CarLibrary.publish(id)
	_working(false)
	if not answer.ok:
		_say(str(answer.error))
		return
	_say("%s is no longer shared." % Garage.name_of(id) if taking_down
		else "%s is shared. Anybody can drive it now." % Garage.name_of(id))
	# The list in hand is now the list as it was before this happened.
	await CarLibrary.catalogue(true)
	_show_what_can_be_done()


func _on_browse_pressed() -> void:
	_shared_page.show()
	_say_on_the_list("Looking…")
	_shared_back.grab_focus()
	_fill_shared(await CarLibrary.catalogue(true))


func _close_shared() -> void:
	_shared_page.hide()
	_browse_button.grab_focus()


## Anything that arrives while the page is up goes onto it. Nothing on the page
## waits for this; it draws whatever it has and is redrawn when there is more.
func _on_catalogue_arrived(rows: Array) -> void:
	if _shared_page.visible:
		_fill_shared(rows)
	_show_what_can_be_done()


## One row per shared car: what it is, who put it up, and how big it is.
##
## A car this machine already has is shown as had rather than hidden. Seeing
## your own car on the list is how a player knows sharing worked, and a list
## that quietly dropped everything you own would be a list that got shorter the
## more you used it.
func _fill_shared(rows: Array) -> void:
	for old in _shared_list.get_children():
		_shared_list.remove_child(old)
		old.queue_free()

	if rows.is_empty():
		if not CarLibrary.available():
			_say_on_the_list("This copy of the game has no server set up.")
		elif not CarLibrary.answered():
			_say_on_the_list("The server did not answer. The rest of the game "
				+ "carries on without it.")
		else:
			_say_on_the_list("Nobody has shared a car yet.")
		return
	_say_on_the_list("")

	for row: Dictionary in rows:
		var id := str(row["id"])
		var here: bool = bool(row["here"])
		var line := Button.new()
		line.custom_minimum_size = Vector2(580, 44)
		line.alignment = HORIZONTAL_ALIGNMENT_LEFT
		line.text = "%s      by %s      %s      %s" % [
			str(row["name"]), str(row["by"]), _thousands(int(row["vertices"])),
			"IN YOUR GARAGE" if here else "GET",
		]
		line.disabled = here
		line.tooltip_text = ("You already have this one."
			if here else "Bring it down into your garage.")
		if not here:
			line.pressed.connect(_on_get_pressed.bind(id))
		_shared_list.add_child(line)


## Bring somebody else's car down. It arrives as bytes and goes through the
## same reader a file off the disk goes through, because a model that came over
## the network is the last thing that should be trusted further than one the
## player picked themselves.
func _on_get_pressed(id: String) -> void:
	_say_on_the_list("Fetching…")
	var answer: Dictionary = await CarLibrary.fetch(id)
	if not answer.ok:
		_say_on_the_list(str(answer.error))
		return
	_say_on_the_list("It is in your garage.")
	_rebuild()
	_fill_shared(await CarLibrary.catalogue())
	_draw_what_has_no_picture()


## Vertex counts read better round than exact - nobody is comparing them, they
## are deciding whether a car is going to cost them a frame rate.
func _thousands(count: int) -> String:
	if count < 1000:
		return "%d verts" % count
	return "%dk verts" % roundi(count / 1000.0)


func _say_on_the_list(what: String) -> void:
	_shared_message.text = what
	_shared_message.visible = not what.is_empty()


## A player who has Blender somewhere the game did not think to look can say
## where it is. Checked by name before it is written down: running an arbitrary
## file somebody pointed at to find out what it is would be the whole problem.
func _on_find_pressed() -> void:
	_finder.popup_centered_ratio(0.6)


func _on_blender_picked(path: String) -> void:
	if not Blender.looks_right(path):
		_say("That does not look like Blender. It is the program itself that "
			+ "is wanted, not a .blend file.")
		return
	Blender.remember(path)
	_find_button.visible = false
	_say("Blender found. Add your .blend again.")


## While Blender is working, nothing else on the screen should be pressable -
## a second file handed in on top of the first would be two Blenders running
## and one of them writing over the other's answer.
func _working(busy: bool) -> void:
	_add_button.disabled = busy
	_find_button.disabled = busy
	_browse_button.disabled = busy
	_back_button.disabled = busy
	if busy:
		_share_button.disabled = true
	if busy:
		_turn_button.disabled = true
		_remove_button.disabled = true
	else:
		_show_what_can_be_done()


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
