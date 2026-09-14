class_name GarageMenu
extends Control

## The garage: every car there is to drive, a tile each, over a paused race or
## over the title screen.
##
## Pressing a tile puts the player in that car immediately rather than on the
## way out, for the same reason the paint screen repaints immediately. The race
## is right there behind the panel with the cars parked on it, and seeing the
## car on the road is the only way to know it is the one you wanted.
##
## Each player has a row, split in two by where a car came from. OFFICIAL is
## the cars the game came with; UNOFFICIAL is everything anybody has added,
## whether it was picked off this disk or downloaded from someone else. The
## line is drawn where it can be trusted: what shipped is in the build, and
## everything else is in `user://`, and nothing a stranger can do moves a car
## from one side of it to the other.
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
##
## Where there is a server, a car can be shared and other people's cars
## browsed. Neither button exists without one: a build with no `backend.cfg`
## is a garage that works entirely on this machine, and a button that can only
## ever say "no server" is a button that should not be there.

## Emitted when the screen closes, so whoever opened it can take focus back.
signal closed

## One tile: the portrait over the name. Two rows of players have to fit a
## window 720 tall with BACK still on it, and this is the height that allows.
const TILE_SIZE := Vector2(200.0, 134.0)
## How many tiles go across the unofficial half before it wraps. The official
## half is one wide: it is one car today, and the day there is a second it goes
## underneath.
const UNOFFICIAL_COLUMNS := 2

## How wide a line on the page of shared cars is, always. A name is whatever
## somebody typed, and a line that grew to fit it would resize the whole page
## under the player's hands as a search narrowed down to it.
const ROW_WIDTH := 760.0

const QUIET := Color(0.72, 0.76, 0.86)
const WRONG := Color(0.98, 0.55, 0.5)
const RIGHT := Color(0.6, 0.9, 0.68)

@onready var _player_rows: Array[VBoxContainer] = [
	$Page/Panel/Margin/Box/Rows/P1, $Page/Panel/Margin/Box/Rows/P2,
]
@onready var _names: Array[Label] = [
	$Page/Panel/Margin/Box/Rows/P1/Name,
	$Page/Panel/Margin/Box/Rows/P2/Name,
]
@onready var _official_grids: Array[GridContainer] = [
	$Page/Panel/Margin/Box/Rows/P1/Halves/Official/Scroll/Centre/Grid,
	$Page/Panel/Margin/Box/Rows/P2/Halves/Official/Scroll/Centre/Grid,
]
@onready var _unofficial_scrolls: Array[ScrollContainer] = [
	$Page/Panel/Margin/Box/Rows/P1/Halves/Unofficial/Scroll,
	$Page/Panel/Margin/Box/Rows/P2/Halves/Unofficial/Scroll,
]
@onready var _unofficial_grids: Array[GridContainer] = [
	$Page/Panel/Margin/Box/Rows/P1/Halves/Unofficial/Scroll/List/Grid,
	$Page/Panel/Margin/Box/Rows/P2/Halves/Unofficial/Scroll/List/Grid,
]
@onready var _nothing_added: Array[Label] = [
	$Page/Panel/Margin/Box/Rows/P1/Halves/Unofficial/Scroll/List/Nothing,
	$Page/Panel/Margin/Box/Rows/P2/Halves/Unofficial/Scroll/List/Nothing,
]
@onready var _add_button: Button = $Page/Panel/Margin/Box/Actions/Add
@onready var _turn_button: Button = $Page/Panel/Margin/Box/Actions/Turn
@onready var _remove_button: Button = $Page/Panel/Margin/Box/Actions/Remove
@onready var _find_blender_button: Button = $Page/Panel/Margin/Box/Actions/FindBlender
@onready var _share_button: Button = $Page/Panel/Margin/Box/Actions/Share
@onready var _browse_button: Button = $Page/Panel/Margin/Box/Actions/Browse
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
## True while a car is going up or coming down. Only sharing waits on it: the
## rest of the garage is on this machine and has no reason to.
var _sending := false

## The page of other people's cars, which lies over this one.
var _browse: Control
var _shared_rows: VBoxContainer
var _shared_note: Label
var _browse_back: Button
## Bumped every time the list is asked for, so an answer that arrives after the
## page was closed and opened again is dropped rather than drawn.
var _asked := 0
## The search over the shared cars, how many it is showing, and every row the
## list last brought - so a search is a filter over what is already in hand
## rather than a request per keystroke. The list is capped, so it is all here.
var _search: LineEdit
var _count: Label
var _all_shared: Array = []

## The panel SHARE opens first, and the car it is asking about.
var _naming: Control
var _name_edit: LineEdit
var _share_it: Button
var _cancel_naming: Button
var _naming_for := ""


func _ready() -> void:
	_back_button.pressed.connect(close)
	_add_button.pressed.connect(_on_add_pressed)
	_turn_button.pressed.connect(_on_turn_pressed)
	_remove_button.pressed.connect(_on_remove_pressed)
	_find_blender_button.pressed.connect(_on_find_blender_pressed)
	_share_button.pressed.connect(_on_share_pressed)
	_browse_button.pressed.connect(_open_the_shared_cars)
	for player in _player_rows.size():
		_official_grids[player].columns = 1
		_unofficial_grids[player].columns = UNOFFICIAL_COLUMNS
	# A car added, turned or removed from anywhere - this page, or a download
	# landing while it is open - is a page showing the old garage.
	Garage.changed.connect(_on_garage_changed)
	# Signing in or out changes whether SHARE can be pressed, and the list
	# arriving changes whether it says SHARE or UNSHARE.
	Backend.signed_in.connect(_update_actions)
	Backend.signed_out.connect(_update_actions)
	CarLibrary.catalogue_arrived.connect(_on_catalogue_arrived)
	_build_the_file_picker()
	_build_the_blender_picker()
	_build_the_shared_cars_page()
	_build_the_naming_panel()
	hide()


## Show the screen, with a row for each player.
func open(players: int) -> void:
	_players = clampi(players, 1, _player_rows.size())
	for player in _player_rows.size():
		_player_rows[player].visible = player < _players
	# Nobody is player one when they are the only car on the road.
	_names[0].text = "PLAYER 1" if _players > 1 else "YOUR CAR"
	# Only offered to a player who needs it. Asked every time the page opens
	# rather than once, since Blender may have been installed in the meantime.
	_find_blender_button.visible = not Blender.here()
	_browse.hide()
	_naming.hide()
	if not _busy:
		_say("", QUIET)
	# Set going rather than waited on. It is what tells this page which cars
	# the player has already shared, and the page is drawn either way.
	if CarLibrary.can_share():
		CarLibrary.catalogue()
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
## Not while a car is coming in, for the reason BACK is refused then too. The
## naming panel and the shared cars lie over the garage, so they are backed out
## of first, innermost first.
func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _naming.visible:
		_on_cancel_naming()
	elif _browse.visible:
		_close_the_shared_cars()
	elif not _busy:
		close()


# --- the tiles ----------------------------------------------------------

## The cars the game came with. One today; a second shipped car is a second
## entry here, and nothing else on the page has to know.
func _official_listing() -> Array:
	return [{"id": Garage.STOCK, "name": Garage.name_of(Garage.STOCK)}]


## Every car there is to drive, official first.
func _listing() -> Array:
	return _official_listing() + Garage.cars()


## Lay out a tile per car per player. Built here rather than in the scene
## because the garage is whatever the player has put in it.
##
## Rebuilt whole rather than patched, and the keyboard put back on the tile it
## was on: a car that has gone takes its tile with it, and one that arrived
## needs one, and working out which is which is more code than building a
## dozen buttons again.
func _fill() -> void:
	var focused := _focused_tile()
	var added := Garage.cars()
	for player in _player_rows.size():
		for grid in _grids_of(player):
			for tile in grid.get_children():
				grid.remove_child(tile)
				tile.queue_free()
		for car: Dictionary in _official_listing():
			_official_grids[player].add_child(_tile(player, car.id, car.name))
		for car: Dictionary in added:
			_unofficial_grids[player].add_child(_tile(player, car.id, car.name))
		# An empty half says so. Left blank, it reads as a half that failed to
		# draw rather than a garage nobody has put anything in yet.
		_nothing_added[player].visible = added.is_empty()
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
	for player in _player_rows.size():
		var driven := _driven(player)
		for tile in _tiles_of(player):
			(tile as Button).set_pressed_no_signal(tile.get_meta("car") == driven)
	_update_actions()


## Both halves of a player's row.
func _grids_of(player: int) -> Array[GridContainer]:
	return [_official_grids[player], _unofficial_grids[player]]


## Every tile in a player's row, official first.
func _tiles_of(player: int) -> Array:
	return _official_grids[player].get_children() + _unofficial_grids[player].get_children()


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
	for player in _player_rows.size():
		for tile in _tiles_of(player):
			(tile as Button).disabled = _busy
	var named := Garage.name_of(_subject)
	_turn_button.tooltip_text = ("Turn %s a quarter of the way round." % named
		if theirs else "The stock car already faces the right way.")
	_remove_button.tooltip_text = ("Take %s out of the garage." % named
		if theirs else "The stock car cannot be taken out.")

	var server := CarLibrary.available()
	_share_button.visible = server
	_browse_button.visible = server
	_browse_button.disabled = _busy
	if not server:
		return
	# UNSHARE only on a car this player put up. Somebody else sharing the same
	# file does not make it theirs to take down.
	_share_button.text = "UNSHARE" if CarLibrary.is_mine(_subject) else "SHARE"
	_share_button.disabled = _busy or _sending or not theirs or not CarLibrary.can_share()
	if not theirs:
		_share_button.tooltip_text = "The stock car is already everybody's."
	elif not CarLibrary.can_share():
		# Still there, and saying why it cannot be pressed, rather than gone -
		# a button that appears on signing in is one nobody knew to look for.
		_share_button.tooltip_text = "Sign in to share"
	elif CarLibrary.is_mine(_subject):
		_share_button.tooltip_text = "Stop sharing %s." % named
	else:
		_share_button.tooltip_text = "Put %s up for anybody to get." % named


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


## Share the car being talked about, or take it back down.
##
## Sharing asks what the car is called first. A file's name is whatever it was
## saved as on somebody's desktop, and it is about to be the name everyone else
## sees it under. Unsharing asks nothing: the player has already decided, and a
## question standing in the way of taking something down is a question standing
## in the way of changing your mind.
func _on_share_pressed() -> void:
	if _busy or _sending or not Garage.has(_subject) or not CarLibrary.can_share():
		return
	if CarLibrary.is_mine(_subject):
		_send(_subject, true)
	else:
		_ask_for_a_name(_subject)


## Put a car up or take it down, and say how it went.
##
## Only this waits on the server. The player goes on picking and turning cars
## while a car goes up, because nothing else on the page has anything to do
## with it.
func _send(id: String, taking_down: bool) -> void:
	var named := Garage.name_of(id)
	_sending = true
	_update_actions()
	_say(("Taking %s down…" if taking_down else "Sharing %s…") % named, QUIET)
	var answer: Dictionary
	if taking_down:
		answer = await CarLibrary.unpublish(id)
	else:
		answer = await CarLibrary.publish(id)
	_sending = false
	_update_actions()
	if not answer.ok:
		_say(str(answer.error), WRONG)
	elif taking_down:
		_say("%s is not shared any more." % named, QUIET)
	else:
		_say("Shared %s. Anybody can get it now." % named, RIGHT)


func _on_catalogue_arrived(_rows: Array) -> void:
	_update_actions()


# --- what a car is called -----------------------------------------------

func _build_the_naming_panel() -> void:
	_naming = Control.new()
	_naming.set_anchors_preset(Control.PRESET_FULL_RECT)
	_naming.hide()
	add_child(_naming)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	_naming.add_child(dim)

	var page := CenterContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_naming.add_child(page)
	var panel := PanelContainer.new()
	page.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 26)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", 0)
	box.add_child(title)
	var heading := Label.new()
	heading.text = "WHAT IS IT CALLED?"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 40)
	title.add_child(heading)
	var subline := Label.new()
	subline.text = ("the name everybody will see it under, and the name it keeps "
		+ "in your garage")
	subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subline.add_theme_font_size_override("font_size", 18)
	subline.add_theme_color_override("font_color", QUIET)
	title.add_child(subline)

	_name_edit = LineEdit.new()
	_name_edit.max_length = Garage.NAME_LIMIT
	_name_edit.custom_minimum_size = Vector2(460.0, 52.0)
	_name_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.text_changed.connect(_on_name_changed)
	# Enter accepts, so a player who is happy with the name, or has just typed
	# a better one, never has to leave the keyboard.
	_name_edit.text_submitted.connect(func(_text: String) -> void: _on_share_it_pressed())
	box.add_child(_name_edit)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	_share_it = Button.new()
	_share_it.text = "SHARE IT"
	_share_it.pressed.connect(_on_share_it_pressed)
	row.add_child(_share_it)
	_cancel_naming = Button.new()
	_cancel_naming.text = "CANCEL"
	_cancel_naming.pressed.connect(_on_cancel_naming)
	row.add_child(_cancel_naming)


## Ask what a car should be called, opening on what it is called now.
##
## All of it selected, so typing replaces it and Enter keeps it: the two things
## a player at this box most likely wants are both one key away.
func _ask_for_a_name(id: String) -> void:
	if not Garage.has(id):
		return
	_naming_for = id
	_name_edit.text = Garage.name_of(id)
	_on_name_changed(_name_edit.text)
	_naming.show()
	_name_edit.grab_focus()
	_name_edit.select_all()


## A name with nothing in it once it is tidied is not a name, and a car cannot
## go up under one.
func _on_name_changed(text: String) -> void:
	_share_it.disabled = Garage.clean_name(text).is_empty()


## Keep the name, then share the car under it. The name goes into the garage
## rather than straight into the request, because the garage's name is the only
## one there is - `CarLibrary.publish` reads it from there.
func _on_share_it_pressed() -> void:
	if _naming_for.is_empty() or _share_it.disabled:
		return
	var id := _naming_for
	var wanted := Garage.clean_name(_name_edit.text)
	_close_the_naming()
	if wanted != Garage.name_of(id):
		Garage.rename(id, wanted)
	await _send(id, false)


## Nothing typed is kept and nothing is sent.
func _on_cancel_naming() -> void:
	_close_the_naming()


func _close_the_naming() -> void:
	_naming.hide()
	_naming_for = ""
	if _share_button.is_visible_in_tree():
		_share_button.grab_focus()


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


# --- other people's cars ------------------------------------------------

## The page of shared cars. Built here rather than in the scene, the way the
## boards are, because every line on it is whatever the server sent.
func _build_the_shared_cars_page() -> void:
	_browse = Control.new()
	_browse.set_anchors_preset(Control.PRESET_FULL_RECT)
	_browse.hide()
	add_child(_browse)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	_browse.add_child(dim)

	var page := CenterContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_browse.add_child(page)

	var panel := PanelContainer.new()
	page.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", 0)
	box.add_child(title)
	var heading := Label.new()
	heading.text = "SHARED CARS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 40)
	title.add_child(heading)
	var subline := Label.new()
	subline.text = "what other people have put up"
	subline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subline.add_theme_font_size_override("font_size", 18)
	subline.add_theme_color_override("font_color", QUIET)
	title.add_child(subline)

	var looking := HBoxContainer.new()
	looking.add_theme_constant_override("separation", 12)
	box.add_child(looking)
	_search = LineEdit.new()
	_search.placeholder_text = "search by name or who shared it"
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.custom_minimum_size.y = 44.0
	_search.clear_button_enabled = true
	_search.add_theme_font_size_override("font_size", 20)
	_search.text_changed.connect(func(_text: String) -> void: _filter())
	looking.add_child(_search)
	_count = Label.new()
	_count.custom_minimum_size.x = 110.0
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.add_theme_font_size_override("font_size", 18)
	_count.add_theme_color_override("font_color", QUIET)
	looking.add_child(_count)

	var scroll := ScrollContainer.new()
	# The lines are a fixed 760, and the scroll bar gets room of its own beside
	# them rather than eating into them the moment the list is long enough to
	# need one.
	scroll.custom_minimum_size = Vector2(ROW_WIDTH + 16.0, 350.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_shared_rows = VBoxContainer.new()
	_shared_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shared_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_shared_rows)

	_shared_note = Label.new()
	_shared_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shared_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shared_note.custom_minimum_size = Vector2(ROW_WIDTH, 26.0)
	_shared_note.add_theme_font_size_override("font_size", 18)
	_shared_note.add_theme_color_override("font_color", QUIET)
	box.add_child(_shared_note)

	_browse_back = Button.new()
	_browse_back.text = "BACK"
	_browse_back.pressed.connect(_close_the_shared_cars)
	box.add_child(_browse_back)


func _open_the_shared_cars() -> void:
	if _busy:
		return
	_search.text = ""
	_browse.show()
	# On the search box, so a player looking for something types it straight
	# in. Down from there is the list, and Escape still backs out.
	_search.grab_focus()
	_fetch_the_shared_cars(false)


func _close_the_shared_cars() -> void:
	_browse.hide()
	# Anything still on its way is for a page that is not there any more.
	_asked += 1
	_browse_button.grab_focus()


## Ask for the list and put it up when it lands.
func _fetch_the_shared_cars(force: bool) -> void:
	_asked += 1
	var asked := _asked
	_clear_the_shared_cars()
	if not CarLibrary.available():
		_show_the_shared_cars([])
		return
	_shared_note.text = "Loading…"
	var rows: Array = await CarLibrary.catalogue(force)
	if asked != _asked or not _browse.visible:
		return
	_show_the_shared_cars(rows)


## Put the list up, or say which kind of empty it is. An empty page means three
## different things - there is no server, the server did not answer, nobody has
## shared anything - and a player told the wrong one goes and does the wrong
## thing about it.
func _show_the_shared_cars(rows: Array) -> void:
	_all_shared = []
	_clear_the_shared_cars()
	_count.text = ""
	if not CarLibrary.available():
		_shared_note.text = ("This copy of the game has no server set up, so there "
			+ "are no shared cars. Your own garage works as it always did.")
		return
	if rows.is_empty() and not CarLibrary.answered():
		_shared_note.text = ("The server did not answer, so the shared cars cannot "
			+ "be shown. Every car in your garage is still here.")
		return
	_list_the_shared_cars(rows)


## Take a list of shared cars as the list in hand, and show as much of it as
## the search lets through.
func _list_the_shared_cars(rows: Array) -> void:
	_all_shared = rows
	_filter()


## Narrow the list to what the search asks for, on the name or on who shared
## it, whichever way round it was typed.
##
## The count says how many of how many while a search is on, so a list getting
## shorter reads as a search narrowing rather than as cars vanishing off the
## server. And it never claims a number it cannot know: a list as long as the
## list is allowed to be is the newest sixty of however many there are.
func _filter() -> void:
	_clear_the_shared_cars()
	var query := _search.text.strip_edges().to_lower()
	var shown := []
	for row: Dictionary in _all_shared:
		if query.is_empty() or str(row.name).to_lower().contains(query) \
				or str(row.by).to_lower().contains(query):
			shown.append(row)
	for row: Dictionary in shown:
		_shared_rows.add_child(_shared_line(row))

	if _all_shared.is_empty():
		_count.text = ""
		_shared_note.text = "Nobody has shared a car yet."
		return
	var total := str(_all_shared.size())
	if _all_shared.size() >= CarLibrary.CATALOGUE_SIZE:
		total = "%d+" % CarLibrary.CATALOGUE_SIZE
	_count.text = total if query.is_empty() else "%d of %s" % [shown.size(), total]
	if shown.is_empty():
		# Its own sentence. "Nobody has shared a car yet" would be a lie about
		# the server, told because of something the player typed.
		_shared_note.text = "Nothing matches that."
	elif CarLibrary.available() and not CarLibrary.answered():
		_shared_note.text = "The server did not answer. This is the list as it was."


## One shared car: its name, who put it up, and GET - or a word saying it is
## already here, rather than a button that would fetch a car the player has.
func _shared_line(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.custom_minimum_size.x = ROW_WIDTH
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	line.clip_contents = true
	line.set_meta("car", row.id)

	var name := Label.new()
	name.text = str(row.name)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", 24)
	line.add_child(name)

	var by := Label.new()
	by.text = "by %s" % row.by
	by.clip_text = true
	by.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	by.custom_minimum_size.x = 210.0
	by.add_theme_font_size_override("font_size", 18)
	by.add_theme_color_override("font_color", QUIET)
	line.add_child(by)

	if bool(row.get("here", false)):
		var here := Label.new()
		here.text = "IN YOUR GARAGE"
		here.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		here.custom_minimum_size.x = 170.0
		here.add_theme_font_size_override("font_size", 16)
		here.add_theme_color_override("font_color", RIGHT)
		line.add_child(here)
	else:
		var get_it := Button.new()
		get_it.text = "GET"
		get_it.custom_minimum_size.x = 170.0
		get_it.add_theme_font_size_override("font_size", 20)
		get_it.pressed.connect(_on_get_pressed.bind(str(row.id), get_it))
		line.add_child(get_it)
	return line


func _on_get_pressed(id: String, button: Button) -> void:
	button.disabled = true
	button.text = "GETTING…"
	var answer: Dictionary = await CarLibrary.fetch(id)
	if not is_instance_valid(button) or not _browse.visible:
		return
	if not answer.ok:
		button.disabled = false
		button.text = "GET"
		_shared_note.add_theme_color_override("font_color", WRONG)
		_shared_note.text = str(answer.error)
		return
	_shared_note.add_theme_color_override("font_color", RIGHT)
	_shared_note.text = "Got %s. It is in your garage now." % Garage.name_of(id)
	# The line swaps GET for IN YOUR GARAGE without asking the server again:
	# nothing about the list has changed but what is on this machine.
	_show_the_shared_cars(await CarLibrary.catalogue())
	_draw_missing_portraits()


func _clear_the_shared_cars() -> void:
	for line in _shared_rows.get_children():
		_shared_rows.remove_child(line)
		line.queue_free()
	_shared_note.text = ""
	_shared_note.add_theme_color_override("font_color", QUIET)


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
	for player in _player_rows.size():
		for tile in _tiles_of(player):
			if tile.get_meta("car") == id:
				(tile as Button).icon = picture


# --- focus --------------------------------------------------------------

## Which player's tile, and which car, the keyboard is on - or nothing.
func _focused_tile() -> Array:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return []
	# Compared with each grid rather than looked up in the typed list of them,
	# which refuses to be asked about anything that is not a grid - and the
	# keyboard is on a button in an ordinary row most of the time.
	var parent := focused.get_parent()
	for player in _player_rows.size():
		if parent == _official_grids[player] or parent == _unofficial_grids[player]:
			return [player, str(focused.get_meta("car"))]
	return []


func _tile_for(player: int, id: String) -> Button:
	for tile in _tiles_of(player):
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


## Only the unofficial half ever has more than fits; the official one is a
## single car.
func _scroll_to(player: int, id: String) -> void:
	var tile := _tile_for(player, id)
	if tile != null and tile.get_parent() == _unofficial_grids[player]:
		_unofficial_scrolls[player].ensure_control_visible(tile)


func _say(what: String, colour: Color) -> void:
	_status.text = what
	_status.add_theme_color_override("font_color", colour)
