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
##
## Where there is a server, a car can be shared and other people's cars
## browsed. Neither button exists without one: a build with no `backend.cfg`
## is a garage that works entirely on this machine, and a button that can only
## ever say "no server" is a button that should not be there.

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


func _ready() -> void:
	_back_button.pressed.connect(close)
	_add_button.pressed.connect(_on_add_pressed)
	_turn_button.pressed.connect(_on_turn_pressed)
	_remove_button.pressed.connect(_on_remove_pressed)
	_find_blender_button.pressed.connect(_on_find_blender_pressed)
	_share_button.pressed.connect(_on_share_pressed)
	_browse_button.pressed.connect(_open_the_shared_cars)
	for grid in _grids:
		grid.columns = COLUMNS
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
	_browse.hide()
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
## shared cars lie over the garage, so they are backed out of first.
func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _browse.visible:
		_close_the_shared_cars()
	elif not _busy:
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
## Only this button waits on the server. The player goes on picking and turning
## cars while a car goes up, because nothing else on the page has anything to
## do with it.
func _on_share_pressed() -> void:
	if _busy or _sending or not Garage.has(_subject) or not CarLibrary.can_share():
		return
	var id := _subject
	var named := Garage.name_of(id)
	var taking_down := CarLibrary.is_mine(id)
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

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(760.0, 400.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_shared_rows = VBoxContainer.new()
	_shared_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shared_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(_shared_rows)

	_shared_note = Label.new()
	_shared_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shared_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shared_note.custom_minimum_size = Vector2(760.0, 26.0)
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
	_browse.show()
	_browse_back.grab_focus()
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
	_clear_the_shared_cars()
	if not CarLibrary.available():
		_shared_note.text = ("This copy of the game has no server set up, so there "
			+ "are no shared cars. Your own garage works as it always did.")
		return
	if rows.is_empty():
		_shared_note.text = ("The server did not answer, so the shared cars cannot "
			+ "be shown. Every car in your garage is still here."
			if not CarLibrary.answered() else "Nobody has shared a car yet.")
		return
	for row: Dictionary in rows:
		_shared_rows.add_child(_shared_line(row))
	_shared_note.text = ("" if CarLibrary.answered()
		else "The server did not answer. This is the list as it was.")


## One shared car: its name, who put it up, and GET - or a word saying it is
## already here, rather than a button that would fetch a car the player has.
func _shared_line(row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
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
