class_name GarageMenu
extends Control

## The garage: a tile per car, a row per player, over a paused race.
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
## Each player's row is split in two: on the left the cars the game came with,
## on the right the ones somebody added. A player who has never added anything
## sees an empty half saying so, rather than a list where the car they brought
## home sits indistinguishable from the one that shipped - which matters most
## for the half that is not ours, since a car off the network is the half a
## player should be able to see the edge of.
##
## Sharing asks what the car is called before it sends anything. A name that
## was fine on this machine - whatever the file happened to be called - is
## about to be the only thing anybody else has to go on, and the moment a
## player decides to put a car up is the one moment they are actually thinking
## about that. What they type is the car's name here as well as there: there is
## one name, and a garage that disagreed with the list would be a bug somebody
## had to hold in their head.
##
## Adding, turning and removing act on whichever tile the cursor is on, rather
## than on a car chosen a second time in some other list. There is exactly one
## thing on this screen that is "the car being talked about", and it is the one
## the player is looking at.

## Emitted when the screen closes, so whoever opened it can take focus back.
signal closed

const TILE := Vector2(236, 134)

@onready var _player_boxes: Array[VBoxContainer] = [
	$Page/Panel/Margin/Box/Rows/P1, $Page/Panel/Margin/Box/Rows/P2,
]
@onready var _names: Array[Label] = [
	$Page/Panel/Margin/Box/Rows/P1/Name,
	$Page/Panel/Margin/Box/Rows/P2/Name,
]
## The cars the game came with, per player.
@onready var _official_grids: Array[GridContainer] = [
	$Page/Panel/Margin/Box/Rows/P1/Sides/Official/Scroll/Grid,
	$Page/Panel/Margin/Box/Rows/P2/Sides/Official/Scroll/Grid,
]
## And the ones anybody added, per player.
@onready var _unofficial_grids: Array[GridContainer] = [
	$Page/Panel/Margin/Box/Rows/P1/Sides/Unofficial/Scroll/Grid,
	$Page/Panel/Margin/Box/Rows/P2/Sides/Unofficial/Scroll/Grid,
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
@onready var _naming_page: Control = $Naming
@onready var _naming_field: LineEdit = $Naming/Page/Panel/Margin/Box/Name
@onready var _naming_share: Button = $Naming/Page/Panel/Margin/Box/Row/Share
@onready var _naming_cancel: Button = $Naming/Page/Panel/Margin/Box/Row/Cancel
@onready var _shared_page: Control = $Shared
@onready var _shared_search: LineEdit = $Shared/Page/Panel/Margin/Box/Find/Search
@onready var _shared_count: Label = $Shared/Page/Panel/Margin/Box/Find/Count
@onready var _shared_list: VBoxContainer = $Shared/Page/Panel/Margin/Box/Scroll/List
@onready var _shared_message: Label = $Shared/Page/Panel/Margin/Box/Message
@onready var _shared_back: Button = $Shared/Page/Panel/Margin/Box/Back

## How many cars are on the road: one row of tiles, or two.
var _players := 1
## Which car the cursor is sitting on, and which player's row it is in.
var _under_the_cursor := ""
## The car the naming panel is open about, if it is open.
var _being_named := ""
## Pictures already loaded, so moving up and down the list is not a file read
## per keypress.
var _portraits := {}
## The shared cars as the server last described them, before any searching.
## Kept so that typing filters what is already in hand rather than asking the
## server again on every keystroke.
var _shared_rows: Array = []


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
	_shared_search.text_changed.connect(func(_text: String) -> void:
		_show_the_shared_list())
	_naming_field.max_length = Garage.NAME_LIMIT
	# Enter shares, because a player who has finished typing a name has
	# finished with this panel.
	_naming_field.text_submitted.connect(func(_text: String) -> void:
		_confirm_the_name())
	_naming_field.text_changed.connect(_on_name_typed)
	_naming_share.pressed.connect(_confirm_the_name)
	_naming_cancel.pressed.connect(_close_naming)
	# The list arrives whenever it arrives, and the Share button reads
	# differently once it has - so the screen follows it rather than
	# waiting on it.
	CarLibrary.catalogue_arrived.connect(_on_catalogue_arrived)
	hide()


## Show the screen, with as many rows as there are players.
func open(players: int) -> void:
	_players = clampi(players, 1, _player_boxes.size())
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
	_naming_page.hide()
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
	# One step at a time: off the naming panel, off the shared cars, then
	# off the garage.
	if _naming_page.visible:
		_close_naming()
		return
	if _shared_page.visible:
		_close_shared()
		return
	close()


## Lay out the tiles: each player's row gets the cars the game came with on
## the left and everything in the garage, in the order it was added, on the
## right. Built here rather than in the scene because what goes in the second
## half is different on every machine.
func _rebuild() -> void:
	var official := _official_listing()
	var unofficial := Garage.cars()
	for player in _player_boxes.size():
		_fill(_official_grids[player], player, official, "")
		_fill(_unofficial_grids[player], player, unofficial,
				"Nothing here yet. Press ADD A CAR.")
	_show_the_choices()


## Empty one half of a row and put this listing in it. An empty half says so
## rather than sitting there blank, because a player looking at nothing cannot
## tell an empty garage from a screen that failed to draw.
func _fill(grid: GridContainer, player: int, listing: Array,
		when_empty: String) -> void:
	for old in grid.get_children():
		grid.remove_child(old)
		old.queue_free()
	if listing.is_empty():
		if not when_empty.is_empty():
			grid.add_child(_nothing_here(when_empty))
		return
	for car: Dictionary in listing:
		grid.add_child(_tile(player, car))


func _nothing_here(what: String) -> Label:
	var label := Label.new()
	label.text = what
	label.custom_minimum_size = Vector2(TILE.x * 3, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
	label.add_theme_font_size_override("font_size", 16)
	return label


## Every car that can be driven: the ones the game came with, and the garage.
func _listing() -> Array:
	var listing := _official_listing()
	listing.append_array(Garage.cars())
	return listing


## The cars that came with the game. One, so far - but this is the one place
## that says so, and a second one shipped later belongs here rather than in
## whatever the garage screen happened to be doing with the first.
func _official_listing() -> Array:
	return [{"id": Garage.STOCK, "name": Garage.name_of(Garage.STOCK)}]


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


## Mark the tile each player is driving, in both halves of their row.
func _show_the_choices() -> void:
	for player in _players:
		var mine := GameSettings.car_id(player)
		for tile in _tiles_of(player):
			_dress(tile, str(tile.get_meta("car", "")) == mine)
	_show_what_can_be_done()


## Every tile in one player's row, official and not. A label standing in for
## an empty half is not one of them.
func _tiles_of(player: int) -> Array[Button]:
	var tiles: Array[Button] = []
	for grid: GridContainer in [_official_grids[player], _unofficial_grids[player]]:
		for child in grid.get_children():
			if child is Button:
				tiles.append(child as Button)
	return tiles


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
##
## Going up asks what it is called first. Coming down does not ask anything:
## taking a car back is a thing a player has already decided by the time they
## press the button, and a panel in the way of it would be a panel arguing.
func _on_share_pressed() -> void:
	var id := _under_the_cursor
	if not Garage.has(id):
		return
	if CarLibrary.is_mine(id):
		await _take_it_down(id)
		return
	_open_naming(id)


## Ask what the car is called, starting from what it is called now. The name
## is selected rather than merely shown, so typing replaces it and a player
## happy with it can press Enter without touching the text at all.
func _open_naming(id: String) -> void:
	_being_named = id
	_naming_field.text = Garage.name_of(id)
	_naming_page.show()
	_naming_field.grab_focus()
	_naming_field.select_all()
	_on_name_typed(_naming_field.text)


## A car has to be called something. The button goes quiet rather than the
## panel refusing after the fact, because an empty box is a thing a player can
## see is empty.
func _on_name_typed(text: String) -> void:
	_naming_share.disabled = text.strip_edges().is_empty()


func _close_naming() -> void:
	_being_named = ""
	_naming_page.hide()
	# Back to the button that opened it, unless there is not one - a build
	# with no server never shows Share, and cannot open this panel either.
	if _share_button.visible:
		_share_button.grab_focus()


## The name is written down before anything is sent, because `publish` reads
## the garage for it. One name rather than a name passed alongside the car:
## a garage that disagreed with the list is the bug this avoids having.
func _confirm_the_name() -> void:
	var id := _being_named
	var called := _naming_field.text.strip_edges()
	if not Garage.has(id) or called.is_empty():
		return
	_naming_page.hide()
	_being_named = ""
	if called != Garage.name_of(id):
		Garage.rename(id, called)
		_rebuild()
		_focus_on(id)
	await _put_it_up(id)


func _put_it_up(id: String) -> void:
	_say("Sharing %s…" % Garage.name_of(id))
	_working(true)
	var answer: Dictionary = await CarLibrary.publish(id)
	_working(false)
	if not answer.ok:
		_say(str(answer.error))
		return
	_say("%s is shared. Anybody can drive it now." % Garage.name_of(id))
	await _read_the_list_again()


func _take_it_down(id: String) -> void:
	_say("Taking %s down…" % Garage.name_of(id))
	_working(true)
	var answer: Dictionary = await CarLibrary.unpublish(id)
	_working(false)
	if not answer.ok:
		_say(str(answer.error))
		return
	_say("%s is no longer shared." % Garage.name_of(id))
	await _read_the_list_again()


## The list in hand is now the list as it was before this happened.
func _read_the_list_again() -> void:
	await CarLibrary.catalogue(true)
	_show_what_can_be_done()


func _on_browse_pressed() -> void:
	_shared_page.show()
	# Opened showing everything, whatever was typed last time. A page that
	# remembered a search would open on a list with things missing from it
	# and nothing on screen saying why.
	_shared_search.text = ""
	_say_on_the_list("Looking…")
	_shared_count.text = ""
	_shared_search.grab_focus()
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


## What the server last said, kept and then drawn. Everything that arrives
## comes through here, so there is one place that decides what is on the page.
func _fill_shared(rows: Array) -> void:
	_shared_rows = rows
	_show_the_shared_list()


## One row per shared car: what it is, who put it up, and how big it is -
## narrowed to what is being searched for.
##
## A car this machine already has is shown as had rather than hidden. Seeing
## your own car on the list is how a player knows sharing worked, and a list
## that quietly dropped everything you own would be a list that got shorter the
## more you used it.
func _show_the_shared_list() -> void:
	for old in _shared_list.get_children():
		_shared_list.remove_child(old)
		old.queue_free()

	var looking_for := _shared_search.text.strip_edges().to_lower()
	var shown := _matching(_shared_rows, looking_for)
	_count_them(shown.size(), looking_for)

	if _shared_rows.is_empty():
		if not CarLibrary.available():
			_say_on_the_list("This copy of the game has no server set up.")
		elif not CarLibrary.answered():
			_say_on_the_list("The server did not answer. The rest of the game "
				+ "carries on without it.")
		else:
			_say_on_the_list("Nobody has shared a car yet.")
		return
	if shown.is_empty():
		# The list is not empty, the search is. Said differently, because
		# "nobody has shared a car" would be a lie with a car on the server.
		_say_on_the_list("Nothing here is called \"%s\", and nobody by that "
			% _shared_search.text.strip_edges() + "name has shared one.")
		return
	_say_on_the_list("")

	for row: Dictionary in shown:
		var id := str(row["id"])
		var here: bool = bool(row["here"])
		var line := Button.new()
		line.custom_minimum_size = Vector2(720, 44)
		line.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# Clipped rather than allowed to set the width of the page: one long
		# name would otherwise widen the whole panel, and the panel would
		# change size as a search took that row out of the list.
		line.clip_text = true
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


## The rows a search matches: by what the car is called, or by who put it up.
## Both, because a player typing a name has one of the two in mind and the page
## cannot know which - and searching the one they did not mean would look
## broken rather than strict.
func _matching(rows: Array, looking_for: String) -> Array:
	if looking_for.is_empty():
		return rows
	var found: Array = []
	for row: Dictionary in rows:
		if (str(row["name"]).to_lower().contains(looking_for)
				or str(row["by"]).to_lower().contains(looking_for)):
			found.append(row)
	return found


## How many cars are up there, in the corner of the search box.
##
## What it counts is what came down, which is capped - so a full page says so
## with a + rather than claiming a number it cannot know. And while a search is
## on it says how many of how many, because a count that silently became the
## number of matches would read as cars disappearing off the server.
func _count_them(shown: int, looking_for: String) -> void:
	if _shared_rows.is_empty():
		_shared_count.text = ""
		return
	var all := _shared_rows.size()
	var how_many := ("%d+" % all if all >= CarLibrary.CATALOGUE_SIZE
			else str(all))
	_shared_count.text = ("%d of %s" % [shown, how_many]
			if not looking_for.is_empty() else "%s shared" % how_many)


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
	_naming_share.disabled = busy or _naming_field.text.strip_edges().is_empty()
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


## Hand the same picture to every tile showing that car, in every row.
func _put_the_picture_up(id: String) -> void:
	var picture := _portrait(id)
	for player in _player_boxes.size():
		for tile in _tiles_of(player):
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
	if player >= _player_boxes.size():
		return false
	for tile in _tiles_of(player):
		if str(tile.get_meta("car", "")) == id:
			tile.grab_focus()
			return true
	return false


func _say(what: String) -> void:
	_message.text = what
	_message.visible = not what.is_empty()
