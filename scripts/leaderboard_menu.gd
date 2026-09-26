class_name LeaderboardMenu
extends Control

## The boards: everyone's best on a track, quickest first.
##
## One page with the track picked inside it rather than a board hung off each
## of the twenty cells on the track screen. A player looking at a board is
## nearly always about to look at the next one, and a page they have to back
## out of and come back into twenty times is a page they look at once.
##
## Every way of driving a track has a board of its own, so the way is picked
## here too, off the same row of ways the track's own page has. It is held
## across tracks: somebody reading the Hard boards reads them one track after
## another, not NORMAL, then Hard, then NORMAL again.
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

## How tall the list of times would like to be, and the least it will settle
## for on a screen with no room for that. Everything else on the page is a
## fixed height, so the list is what gives way.
const LIST_HEIGHT := 400.0
const LIST_LEAST := 150.0
## Kept clear above and below the page, so it never sits flush to the edge.
const CLEARANCE := 24.0
## How wide the page is, and how big its row of ways: smaller than the track
## page's, where the ways are the main thing on it, and big enough to read.
const PAGE_WIDTH := 660.0
const WAYS_FONT := 22
const WAYS_HEIGHT := 50.0

var _panel: PanelContainer
var _picker: OptionButton
var _ways: WaysRow
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _note: Label
var _close: Button

## Which slot the picker is showing, as an index into the roster.
var _showing := 0
## Which way of driving it: whose board is up.
var _variant := TrackVariant.NORMAL
## Bumped every time a board is asked for, so an answer to a question the
## player has already moved on from can be dropped rather than drawn.
var _asked := 0


func _ready() -> void:
	_build()
	Backend.signed_in.connect(_on_account_changed)
	Backend.signed_out.connect(_on_account_changed)
	resized.connect(_fit_the_list)
	# The page's own height answers back: what is left for the list depends on
	# how tall the rest of it turned out, and the note under it grows and
	# shrinks with whatever it has to say.
	_panel.resized.connect(_fit_the_list)
	_fit_the_list()
	hide()


## Show the boards, opening on a particular track where there is one worth
## opening on - the one the player was just looking at - and on the way of
## driving it they last drove, where that is not NORMAL.
func open(track_file: String = "", variant := TrackVariant.NORMAL) -> void:
	var index := TrackRoster.index_of(track_file)
	if index >= 0:
		_showing = index
		_picker.selected = _picker.get_item_index(index)
	_variant = variant
	_set_out_the_ways()
	show()
	_fit_the_list()
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

	_panel = PanelContainer.new()
	page.add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 30)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	# Wide enough for all five ways of driving a track in a row, so the page
	# is the same width whichever track is picked - an acrobatic track shows
	# two of them, and a page that shrank to fit would jump on every pick.
	box.custom_minimum_size = Vector2(PAGE_WIDTH, 0.0)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = "LEADERBOARD"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 40)
	box.add_child(heading)

	_picker = OptionButton.new()
	# Only tracks that exist. An empty slot has no road, so it cannot have a
	# board, and offering one is offering a page that is always blank. A bot
	# road is left out for the same reason and not a weaker one: it exists, but
	# no time is ever written down on it, so its board would be blank forever.
	for index in TrackRoster.TOTAL:
		if TrackRoster.exists(index) and TrackRoster.kind_of(index) != TrackRoster.BOT:
			_picker.add_item(TrackRoster.track_name(index).to_upper(), index)
	_picker.item_selected.connect(_on_picked)
	box.add_child(_picker)

	_ways = WaysRow.new()
	_ways.font_size = WAYS_FONT
	_ways.button_height = WAYS_HEIGHT
	_ways.chosen.connect(_on_way_chosen)
	box.add_child(_ways)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0.0, LIST_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	_scroll.add_child(_rows)

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


## Twenty names is a tall page, and on a widescreen monitor a laid-out screen
## is only ever as high as the reference - 900, or 750 at the largest
## interface size a player can pick. Rather than let the top and the bottom of
## the page hang off the edges - taking the heading and the way out with them
## - the list of times takes whatever height is left over and scrolls the
## rest. It is measured off the space actually given rather than off any of
## those numbers, so the setting needs no say in it.
func _fit_the_list() -> void:
	if _panel == null or size.y < 1.0:
		return
	# What the page needs for everything that is not the list: measured off
	# the page where it has been laid out once, and off its minimums before
	# there is anything to measure.
	var rest := _panel.size.y - _scroll.size.y
	if rest <= 0.0:
		rest = _panel.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	var wanted := clampf(
		size.y - rest - CLEARANCE * 2.0, LIST_LEAST, LIST_HEIGHT)
	# Settling for what it already has is what stops this going round again:
	# the list's height is what moves the page that called it.
	if absf(wanted - _scroll.custom_minimum_size.y) < 0.5:
		return
	_scroll.custom_minimum_size.y = wanted


func _on_picked(item: int) -> void:
	_showing = _picker.get_item_id(item)
	_set_out_the_ways()
	_fetch()


func _on_way_chosen(variant: String) -> void:
	_variant = variant
	_fetch()


## The row of ways as the track being shown has them. A way the track does not
## even show - HARD on an acrobatic track - drops back to NORMAL; one it shows
## faded stays held, and its board says why it is empty.
func _set_out_the_ways() -> void:
	var file := TrackRoster.file(_showing)
	_ways.show_for(file)
	if not _ways.button(_variant).visible:
		_variant = TrackVariant.NORMAL
	_ways.hold(_variant)


## The row of ways on this page, for the menu to hand CHAOS its colour.
func ways() -> WaysRow:
	return _ways


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
	if _variant not in TrackVariant.offered(file):
		# Not driven this way, so nobody has a time on it or ever will. Saying
		# so beats a board that only ever says nobody has been first.
		_clear()
		_note.text = TrackVariant.why_not(file, _variant)
		return
	var rows: Array = await Leaderboard.board(file, false, _variant)

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
		_rows.add_child(line(place + 1, row))

	if not Backend.is_signed_in():
		_note.text = "Sign in to put your times up here."
	elif found_me:
		_note.text = ""
	else:
		# Being off the bottom of the board is not the same as not being on
		# the board, and a player who has driven the track should be told
		# which of the two they are.
		var mine := TrackTimes.best(TrackRoster.file(_showing), _variant)
		if mine >= 0.0:
			_note.text = ("Your %s is not in the top %d yet."
				% [RaceClock.format(mine), rows.size()])
		else:
			_note.text = "You have not set a time on this one yet."


## One place on the board. Static, because a track's own page puts the same
## rows up beside its picture, smaller, and two ways of drawing one row would
## drift apart.
static func line(place: int, row: Dictionary, font_size := 24) -> Control:
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
		(label as Label).add_theme_font_size_override("font_size", font_size)
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
