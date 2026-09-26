class_name StatsMenu
extends Control

## The page of lifetime totals, and under it the best time and medal on every
## track, one column for each way of driving it.
##
## The totals are `Stats`'. The times are not: they are read straight out of
## `TrackTimes` every time the page is drawn, the way `Progress.golds_in` reads
## them, and nothing on this page keeps a copy. A second copy of a best time is
## a second thing to disagree with the first.
##
## Opened from the track screen, beside the boards, rather than from the title.
## The title already stacks five buttons and a sixth there is a layout change;
## beside the boards is where the question is already being asked, since half
## of this page is a table of times per track.

signal closed

const DIM := Color(0, 0, 0, 0.62)
const QUIET := Color(0.55, 0.58, 0.66)

## What a number that does not exist yet reads as: a time never set, a rate
## over no races. A dash, never `-1.00` or `nan%`.
const NOTHING := "—"

## How tall the table would like to be, and the least it will settle for on a
## screen with no room for that. Everything above and below it is a fixed
## height, so the table is what gives way - as the boards' list does.
const TABLE_HEIGHT := 380.0
const TABLE_LEAST := 140.0
## Kept clear above and below the page, so it never sits flush to the edge.
const CLEARANCE := 24.0
## How far one press of up or down moves the table.
const SCROLL_STEP := 48.0
## How wide each way's column of times is, and how big the words in the table.
## Five columns of times is what the page is widest for; `screen_fit.gd` holds
## it to the screen at the largest interface size.
const TIME_WIDTH := 108.0
const TABLE_FONT := 20
## How thick the bar of a time's medal colour is, under the time.
const MEDAL_BAR := 3.0
## Room left on the right of the table for the scroll bar.
const SCROLL_GUTTER := 22

var _panel: PanelContainer
var _totals: GridContainer
var _empty: Control
var _damage_note: Label
var _scroll: ScrollContainer
var _rows: VBoxContainer
var _close: Button
## The value label for each total, by the key it is drawn from, and the name
## label beside it - kept so a redraw only changes what is written in them.
var _values := {}
var _names := {}


func _ready() -> void:
	_build()
	Stats.changed.connect(_on_something_changed)
	# The damage setting decides whether CARS WRECKED means anything, and it
	# can be changed with this page's parent screen still up behind it.
	GameSettings.changed.connect(_on_something_changed)
	resized.connect(_fit_the_table)
	_panel.resized.connect(_fit_the_table)
	_fit_the_table()
	hide()


func open() -> void:
	_fill()
	show()
	_scroll.scroll_vertical = 0
	_fit_the_table()
	_close.grab_focus()


func close() -> void:
	hide()
	closed.emit()


## Escape backs out, as on every other page. Up and down scroll the table,
## since the only thing on the page that takes the keyboard is the way out and
## a keyboard player should not need the mouse to read their own times.
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("ui_down", true):
		get_viewport().set_input_as_handled()
		_scroll.scroll_vertical += int(SCROLL_STEP)
	elif event.is_action_pressed("ui_up", true):
		get_viewport().set_input_as_handled()
		_scroll.scroll_vertical -= int(SCROLL_STEP)


func _on_something_changed() -> void:
	if visible:
		_fill()


# --- building ---------------------------------------------------------------

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
	box.custom_minimum_size = Vector2(900.0, 0.0)
	margin.add_child(box)

	var heading := Label.new()
	heading.text = "STATISTICS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 40)
	box.add_child(heading)

	# Two pairs a row rather than one, so eight totals take four lines and
	# leave the height to the table.
	_totals = GridContainer.new()
	_totals.columns = 4
	_totals.add_theme_constant_override("h_separation", 18)
	_totals.add_theme_constant_override("v_separation", 8)
	box.add_child(_totals)
	for total in [
		["distance", "DISTANCE RACED"], ["time", "TIME DRIVEN"],
		["completed", "RACES FINISHED"], ["won", "RACES WON"],
		["tracks", "TRACKS WITH A TIME"], ["coins", "COINS PICKED UP"],
		["wrecked", "CARS WRECKED"], ["resets", "RESETS"],
	]:
		_add_total(total[0], total[1])

	_damage_note = Label.new()
	_damage_note.text = "Damage is off, so no car can be wrecked. It is in the settings."
	_damage_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_damage_note.add_theme_font_size_override("font_size", 18)
	_damage_note.add_theme_color_override("font_color", QUIET)
	box.add_child(_damage_note)

	# A fresh profile is the first thing a new player sees here, so the place
	# the totals will be says so rather than showing a grid of zeros.
	_empty = VBoxContainer.new()
	box.add_child(_empty)
	var nothing := Label.new()
	nothing.text = "NOTHING DRIVEN YET"
	nothing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nothing.add_theme_font_size_override("font_size", 30)
	_empty.add_child(nothing)
	var why := Label.new()
	why.text = "Everything you drive from now on is counted here."
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.add_theme_font_size_override("font_size", 20)
	why.add_theme_color_override("font_color", QUIET)
	_empty.add_child(why)

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0.0, TABLE_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)

	# Kept clear of the scroll bar on the right, which otherwise stands over
	# the last column of times.
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", SCROLL_GUTTER)
	_scroll.add_child(gutter)

	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	gutter.add_child(_rows)

	_close = Button.new()
	_close.text = "BACK"
	_close.pressed.connect(close)
	box.add_child(_close)


func _add_total(key: String, named: String) -> void:
	var name := Label.new()
	name.text = named
	name.add_theme_font_size_override("font_size", 20)
	name.add_theme_color_override("font_color", QUIET)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_totals.add_child(name)
	var value := Label.new()
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 24)
	value.custom_minimum_size.x = 130.0
	_totals.add_child(value)
	_names[key] = name
	_values[key] = value


# --- filling ----------------------------------------------------------------

func _fill() -> void:
	var empty: bool = Stats.is_empty()
	_totals.visible = not empty
	_empty.visible = empty
	_damage_note.visible = not empty and not GameSettings.damage

	_show_total("distance", _distance(Stats.distance_metres))
	_show_total("time", _duration(Stats.time_driven_seconds))
	_show_total("completed", str(Stats.races_completed))
	_show_total("won", _wins(Stats.races_won, Stats.races_contested))
	_show_total("coins", str(Stats.coins_earned))
	_show_total("resets", str(Stats.resets))
	_show_total("tracks", _tracks_with_a_time())
	# Greyed rather than a bare zero while damage is off - which is the default,
	# so most players will look at this row for good and deserve the reason.
	_show_total("wrecked", str(Stats.cars_wrecked))
	var faded := 1.0 if GameSettings.damage else 0.45
	(_names["wrecked"] as Label).modulate.a = faded
	(_values["wrecked"] as Label).modulate.a = faded

	_fill_the_table()


func _show_total(key: String, text: String) -> void:
	(_values[key] as Label).text = text


## The table: every track slot of the two grids, in their own groups. Locked
## tracks keep their row and their name - a table that grew as a player
## unlocked things would change shape under them - and a slot still to come
## has no row, because it has no road.
##
## A column for each way of driving a track, in the order the track's page
## has them, since each is a road of its own with a best of its own. All five
## at once rather than a row of ways to pick one from: the page is there to be
## read at a glance, and five columns fit. Each group's heading names the
## columns it fills, so the acrobatic tracks' heading says NORMAL and MIRROR
## and nothing else.
func _fill_the_table() -> void:
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()
	for kind in [TrackRoster.NORMAL, TrackRoster.ACROBATIC]:
		_rows.add_child(_heading(kind))
		var first := TrackRoster.first(kind)
		for index in range(first, first + TrackRoster.count(kind)):
			if TrackRoster.exists(index):
				_rows.add_child(_line(index, index - first + 1))


## A group's heading, with the name of each way over its column - where the
## group has any track that is driven that way.
func _heading(kind: int) -> Control:
	var line := _row()
	var heading := Label.new()
	heading.text = "TRACKS" if kind == TrackRoster.NORMAL else "ACROBATIC TRACKS"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(heading)
	var first := TrackRoster.first(kind)
	for variant: String in TrackVariant.ALL:
		var driven := false
		for index in range(first, first + TrackRoster.count(kind)):
			driven = driven or variant in TrackVariant.offered(TrackRoster.file(index))
		var way := Label.new()
		way.text = TrackVariant.display_name(variant) if driven else ""
		way.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		way.custom_minimum_size.x = TIME_WIDTH
		line.add_child(way)
	for label in line.get_children():
		(label as Label).add_theme_font_size_override("font_size", TABLE_FONT)
		(label as Label).add_theme_color_override("font_color", QUIET)
	return line


## One track: its number in its own grid, its name, and its best each way it
## is driven, over a bar in the colour of what that is worth. A way it is not
## driven is left blank, which is not the same as a dash: a dash is a time
## still to set.
##
## Below zero means no time, and a dash. A time dropped because its track was
## edited comes back below zero too, silently, from the same call - which is
## right: it was set on a road that no longer exists. Do not "fix" it.
func _line(index: int, number: int) -> Control:
	var file := TrackRoster.file(index)
	var line := _row()

	var place := Label.new()
	place.text = "%02d" % number
	place.custom_minimum_size.x = 40.0
	place.add_theme_color_override("font_color", QUIET)
	place.add_theme_font_size_override("font_size", TABLE_FONT)
	line.add_child(place)

	var name := Label.new()
	name.text = TrackRoster.track_name(index).to_upper()
	name.clip_text = true
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.add_theme_font_size_override("font_size", TABLE_FONT)
	line.add_child(name)

	var offered := TrackVariant.offered(file)
	for variant: String in TrackVariant.ALL:
		line.add_child(_best(file, index, variant) if variant in offered else _blank())
	return line


## A best time over its medal's bar. The bar and not only the colour of the
## time, for the reason the grid has one under every picture: against a dark
## panel a silver time and a time worth nothing are two shades of pale.
func _best(file: String, index: int, variant: String) -> Control:
	var best := TrackTimes.best(file, variant)
	var medal := Medal.earned(best,
		TrackVariant.targets(file, TrackRoster.targets(index), variant))
	var cell := _blank()
	var time := Label.new()
	time.name = "Time"
	time.text = RaceClock.format(best) if best >= 0.0 else NOTHING
	time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	time.add_theme_font_size_override("font_size", TABLE_FONT)
	time.add_theme_color_override("font_color", Medal.colour(medal))
	cell.add_child(time)
	var bar := ColorRect.new()
	bar.name = "Medal"
	bar.custom_minimum_size = Vector2(0.0, MEDAL_BAR)
	bar.color = Medal.colour(medal)
	bar.modulate.a = 1.0 if medal != Medal.NONE else 0.0
	cell.add_child(bar)
	return cell


## A column's width with nothing in it.
func _blank() -> VBoxContainer:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size.x = TIME_WIDTH
	cell.add_theme_constant_override("separation", 0)
	return cell


func _row() -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	return line


# --- how each number reads ------------------------------------------------------

## Metres under a kilometre, kilometres to one decimal after. No miles: the game
## has no units setting to follow.
static func _distance(metres: float) -> String:
	if metres < 1000.0:
		return "%d m" % int(metres)
	return "%.1f km" % (metres / 1000.0)


## Hours and minutes, and seconds only while there is not yet a minute to show.
static func _duration(seconds: float) -> String:
	var minutes := int(seconds) / 60
	if minutes < 1:
		return "%d s" % int(seconds)
	if minutes < 60:
		return "%d min" % minutes
	return "%d h %02d min" % [minutes / 60, minutes % 60]


## Wins, and the rate over the races that could have been won. Not over every
## race finished: that includes solo runs nobody can win, and a player who
## mostly races the clock would read as somebody who mostly loses. Worked out
## here and never stored.
static func _wins(won: int, contested: int) -> String:
	if contested <= 0:
		return "%d  \u00b7  %s" % [won, NOTHING]
	return "%d  \u00b7  %d%%" % [won, roundi(100.0 * won / contested)]


## How many of the tracks have a best time on them. Not a counter in `Stats`:
## `TrackTimes` already knows.
##
## As written only, never any other way. With every way counted it could reach
## over a hundred, and a number that big hides the one it is there to say:
## whether the tracks themselves have all been driven.
func _tracks_with_a_time() -> String:
	var timed := 0
	var total := 0
	for kind in [TrackRoster.NORMAL, TrackRoster.ACROBATIC]:
		var first := TrackRoster.first(kind)
		for index in range(first, first + TrackRoster.count(kind)):
			if not TrackRoster.exists(index):
				continue
			total += 1
			if TrackTimes.best(TrackRoster.file(index)) >= 0.0:
				timed += 1
	return "%d of %d" % [timed, total]


## The table takes whatever height the rest of the page leaves it, as the
## boards' list does - see `LeaderboardMenu._fit_the_list`, which this is.
func _fit_the_table() -> void:
	if _panel == null or size.y < 1.0:
		return
	var rest := _panel.size.y - _scroll.size.y
	if rest <= 0.0:
		rest = _panel.get_combined_minimum_size().y - _scroll.custom_minimum_size.y
	var wanted := clampf(
		size.y - rest - CLEARANCE * 2.0, TABLE_LEAST, TABLE_HEIGHT)
	if absf(wanted - _scroll.custom_minimum_size.y) < 0.5:
		return
	_scroll.custom_minimum_size.y = wanted
