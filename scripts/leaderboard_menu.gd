class_name LeaderboardMenu
extends Control

## The boards: everyone's best on a track, quickest first.
##
## One page with the track picked inside it rather than a board hung off each
## of the twenty cells on the track screen. A player looking at a board is
## nearly always about to look at the next one, and a page they have to back
## out of and come back into twenty times is a page they look at once.
##
## Readable without an account. Somebody deciding whether it is worth making
## one should be able to see what they would be joining, and a board that
## demands a sign-in before it will show you anything is a board with nobody
## on it.
##
## A board is only ever the times set on this exact version of the track, by
## cars tuned the way these ones are - that is what `TrackTimes.signature`
## settles. Change a corner on track seven and the board for it empties,
## because the road everyone drove is not the road in front of you.

signal closed

const DIM := Color(0, 0, 0, 0.62)
const QUIET := Color(0.55, 0.58, 0.66)
const MINE := Color(1.0, 0.85, 0.4)

## How the player's own row is marked when it is too far down to be on the
## board at all.
const PLACE := "%d."

var _picker: OptionButton
var _rows: VBoxContainer
var _note: Label
var _close: Button

## Which slot the picker is showing, as an index into the roster.
var _showing := 0
## Bumped every time a board is asked for, so an answer to a question the
## player has already moved on from can be dropped rather than drawn.
var _asked := 0


func _ready() -> void:
	_build()
	Backend.signed_in.connect(_on_account_changed)
	Backend.signed_out.connect(_on_account_changed)
	hide()


## Show the boards, opening on a particular track where there is one worth
## opening on - the one the player was just looking at.
func open(track_file: String = "") -> void:
	var index := TrackRoster.index_of(track_file)
	if index >= 0:
		_showing = index
		_picker.selected = _picker.get_item_index(index)
	show()
	_close.grab_focus()
	# The sync is set going here rather than waited on. It is what puts a run
	# driven offline onto the board, and the board below is drawn from the
	# server either way.
	Leaderboard.sync()
	_fetch()


func close() -> void:
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	close()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = DIM
	add_child(dim)

	var page := CenterContainer.new()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(page)

	var panel := PanelContainer.new()
	page.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size = Vector2(560.0, 0.0)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = "LEADERBOARD"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 40)
	box.add_child(heading)

	_picker = OptionButton.new()
	# Only tracks that exist. An empty slot has no road, so it cannot have a
	# board, and offering one is offering a page that is always blank.
	for index in TrackRoster.COUNT:
		if TrackRoster.exists(index):
			_picker.add_item(TrackRoster.track_name(index).to_upper(), index)
	_picker.item_selected.connect(_on_picked)
	box.add_child(_picker)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, 400.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)

	_note = Label.new()
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_font_size_override("font_size", 20)
	_note.add_theme_color_override("font_color", QUIET)
	box.add_child(_note)

	_close = Button.new()
	_close.text = "BACK"
	_close.pressed.connect(close)
	box.add_child(_close)


func _on_picked(item: int) -> void:
	_showing = _picker.get_item_id(item)
	_fetch()


func _on_account_changed() -> void:
	if visible:
		_fetch()


## Go and get the board being shown, and draw it when it lands.
func _fetch() -> void:
	if not Leaderboard.available():
		_clear()
		_note.text = ("This copy of the game has no server set up, so there "
			+ "are no boards. Your own times are kept on this machine as "
			+ "they always were.")
		return

	_clear()
	_note.text = "Loading…"

	_asked += 1
	var asked := _asked
	var file: String = TrackRoster.file(_showing)
	var rows: Array = await Leaderboard.board(file)

	# The player has moved to another track, or shut the page, since this was
	# asked for. Drawing it now would put one track's times under another
	# track's name.
	if asked != _asked:
		return

	_show_board(rows)


## Put a board up. Not `_draw`: that name belongs to `CanvasItem`, which calls
## it with no arguments when the control repaints, and a function wearing it
## has to have that signature whatever it was written for.
func _show_board(rows: Array) -> void:
	_clear()
	if rows.is_empty():
		_note.text = ("Nobody has set a time on this version of the track "
			+ "yet. Go and be first.")
		return

	var found_me := false
	for place in rows.size():
		var row: Dictionary = rows[place]
		found_me = found_me or bool(row.get("mine", false))
		_rows.add_child(_line(place + 1, row))

	if not Backend.is_signed_in():
		_note.text = "Sign in to put your times up here."
	elif found_me:
		_note.text = ""
	else:
		# Being off the bottom of the board is not the same as not being on
		# the board, and a player who has driven the track should be told
		# which of the two they are.
		var mine := TrackTimes.best(TrackRoster.file(_showing))
		if mine >= 0.0:
			_note.text = ("Your %s is not in the top %d yet."
				% [RaceClock.format(mine), rows.size()])
		else:
			_note.text = "You have not set a time on this one yet."


## One place on the board.
func _line(place: int, row: Dictionary) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	var mine := bool(row.get("mine", false))

	var number := Label.new()
	number.text = PLACE % place
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.custom_minimum_size.x = 52.0
	line.add_child(number)

	var name := Label.new()
	name.text = str(row.get("name", "—"))
	# Clipped rather than allowed to push the time off the edge: a name is
	# chosen by the player who owns it, and somebody will choose a long one.
	name.clip_text = true
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)

	var time := Label.new()
	time.text = RaceClock.format(float(row.get("seconds", 0.0)))
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time.custom_minimum_size.x = 120.0
	line.add_child(time)

	# The player's own row is picked out, because the one thing anybody
	# actually looks for on a leaderboard is themselves.
	for label in [number, name, time]:
		(label as Label).add_theme_font_size_override("font_size", 24)
		if mine:
			(label as Label).add_theme_color_override("font_color", MINE)
	return line


func _clear() -> void:
	for row in _rows.get_children():
		row.queue_free()
		# Freed children are still children until the frame ends, and a list
		# that is about to be filled would otherwise show the old one under
		# the new one for that frame.
		_rows.remove_child(row)
	_note.text = ""
