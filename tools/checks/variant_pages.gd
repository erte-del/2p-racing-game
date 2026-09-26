extends SceneTree

# The pages that read times, each way a track is driven.
#   Godot --path . --headless --script tools/checks/variant_pages.gd
#
# Every way of driving a track keeps a best of its own, and the pages that show
# times have to show the right one in the right place. Statistics has a column
# for each way: a time set mirrored lands under MIRROR and nowhere else, a way
# a track is not driven is blank rather than a dash, each time is coloured by
# what it is worth that way, and TRACKS WITH A TIME still counts the tracks as
# written. The leaderboard has the track page's row of ways: it opens on the
# way the player last drove the track they came back from, keeps the way held
# from one track to the next, and drops back to NORMAL on a track that is not
# driven that way at all.
#
# Checks run with no backend, so no board is ever fetched here; what the
# leaderboard is checked for is which board it would ask for.
#
# TrackTimes is pointed at scratch before the menu is built and wiped on the way
# out. Autoloads are fetched out of the tree, since a --script file is compiled
# before they are registered - and for the same reason the pages are plain
# Nodes here and never named by their class: naming StatsMenu compiles it, and
# it names Stats. Each half says when it has got to the end, because a page
# that failed to open stops the half that was looking at it without a fault.

const TIMES_SCRATCH := "user://times_variant_pages.cfg"
const FIRST_LIGHT := "res://tracks/01_first_light.gd"
const WHIPLASH := "res://tracks/17_whiplash.gd"

## What an empty cell reads as: `NOTHING`, which cannot be named here.
const NOTHING := "—"

var _faults := 0
var _finished := 0


func _init() -> void:
	await process_frame
	var times: Node = root.get_node(^"/root/TrackTimes")
	var settings: Node = root.get_node(^"/root/GameSettings")
	times.save_path = Sandbox.path(TIMES_SCRATCH)
	_wipe(times.save_path)
	times.load_times()
	settings.track_file = ""
	settings.track_variant = TrackVariant.NORMAL

	# First Light: gold as written, a time worth nothing mirrored, silver
	# reversed - on Reverse's own targets, which are not the track's.
	var index := TrackRoster.index_of(FIRST_LIGHT)
	var reverse := TrackVariant.targets(FIRST_LIGHT, TrackRoster.targets(index),
		TrackVariant.REVERSE)
	times.record(FIRST_LIGHT, TrackRoster.targets(index).x - 0.5)
	times.record(FIRST_LIGHT, 999.0, TrackVariant.MIRROR)
	times.record(FIRST_LIGHT, reverse.y - 0.5, TrackVariant.REVERSE)
	# Whiplash: a time mirrored only, which is not a time on Whiplash.
	times.record(WHIPLASH, 80.0, TrackVariant.MIRROR)

	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	for i in 10:
		await process_frame
	_check_the_statistics(menu.get_node("StatsScreen"))
	await _check_the_boards(menu, settings)
	if _finished != 2:
		_fault("%d of the two pages were checked to the end" % _finished)

	menu.queue_free()
	await process_frame
	_wipe(times.save_path)
	settings.track_file = ""
	settings.track_variant = TrackVariant.NORMAL
	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


func _check_the_statistics(stats: Node) -> void:
	stats.call("open")
	var rows: VBoxContainer = stats.get("_rows")
	var first := _row(rows, "FIRST LIGHT")
	var whiplash := _row(rows, "WHIPLASH")
	var lift_off := _row(rows, "LIFT OFF")
	if first == null or whiplash == null or lift_off == null:
		_fault("a track is missing from the table")
		stats.call("close")
		return

	_expect_cell(first, TrackVariant.NORMAL, RaceClock.format(TrackRoster.targets(0).x - 0.5),
		Medal.GOLD)
	_expect_cell(first, TrackVariant.MIRROR, RaceClock.format(999.0), Medal.NONE)
	var reverse := TrackVariant.targets(FIRST_LIGHT, TrackRoster.targets(0), TrackVariant.REVERSE)
	_expect_cell(first, TrackVariant.REVERSE, RaceClock.format(reverse.y - 0.5), Medal.SILVER)
	_expect_cell(first, TrackVariant.HARD, NOTHING, Medal.NONE)
	_expect_cell(whiplash, TrackVariant.NORMAL, NOTHING, Medal.NONE)
	_expect_cell(whiplash, TrackVariant.MIRROR, RaceClock.format(80.0), Medal.NONE)
	# Whiplash is not driven backwards, and an acrobatic track only ever as
	# written or mirrored: blank, which is not a time still to set.
	_expect_blank(whiplash, TrackVariant.REVERSE)
	for variant in [TrackVariant.HARD, TrackVariant.TRACK_CHAOS, TrackVariant.REVERSE]:
		_expect_blank(lift_off, variant)
	_expect_cell(lift_off, TrackVariant.MIRROR, NOTHING, Medal.NONE)

	# The acrobatic group's heading names only the columns it fills.
	var heading := _row(rows, "ACROBATIC TRACKS")
	if heading != null:
		var named := PackedStringArray()
		for label in heading.get_children().slice(1):
			if not (label as Label).text.is_empty():
				named.append((label as Label).text)
		if named != PackedStringArray(["NORMAL", "MIRROR"]):
			_fault("the acrobatic tracks' heading names %s" % ", ".join(named))

	# Two tracks have times, but only First Light has one as written.
	var tracks: Label = (stats.get("_values") as Dictionary)["tracks"]
	var total := TrackRoster.count(TrackRoster.NORMAL) + TrackRoster.count(TrackRoster.ACROBATIC)
	if tracks.text != "1 of %d" % total:
		_fault("TRACKS WITH A TIME reads %s with one track driven as written" % tracks.text)
	if _faults == 0:
		print("statistics puts each way's time under its own way, worth what it is that way")
	stats.call("close")
	_finished += 1


func _check_the_boards(menu: Node, settings: Node) -> void:
	var boards: Node = menu.get_node("LeaderboardScreen")
	var ways: Node = boards.call("ways")
	var before := _faults

	# Back from a Hard run on Whiplash, with nothing on the grid under the
	# cursor: the boards open on the track just driven, the way it was driven.
	settings.track_file = WHIPLASH
	settings.track_variant = TrackVariant.HARD
	menu.call("_on_boards_pressed")
	await process_frame
	_expect_board(boards, WHIPLASH, TrackVariant.HARD, "opened after a Hard run")
	if not ways.call("button", TrackVariant.HARD).button_pressed:
		_fault("the boards opened on HARD without HARD held down")

	# The way held stays held from one track to the next.
	ways.call("button", TrackVariant.MIRROR).pressed.emit()
	_pick(boards, FIRST_LIGHT)
	_expect_board(boards, FIRST_LIGHT, TrackVariant.MIRROR, "moved to another track")

	# An acrobatic track is driven mirrored too, so MIRROR stays.
	_pick(boards, "res://tracks/acrobatic/a01_lift_off.gd")
	_expect_board(boards, "res://tracks/acrobatic/a01_lift_off.gd", TrackVariant.MIRROR,
		"moved to an acrobatic track")
	if ways.call("button", TrackVariant.HARD).visible:
		_fault("an acrobatic track's boards show HARD")

	# But not hard, so HARD drops back to NORMAL there.
	_pick(boards, FIRST_LIGHT)
	ways.call("button", TrackVariant.HARD).pressed.emit()
	_pick(boards, "res://tracks/acrobatic/a01_lift_off.gd")
	_expect_board(boards, "res://tracks/acrobatic/a01_lift_off.gd", TrackVariant.NORMAL,
		"moved to an acrobatic track with HARD held")
	if not ways.call("button", TrackVariant.NORMAL).button_pressed:
		_fault("HARD dropped back to NORMAL without NORMAL held down")

	# Whiplash is not driven backwards: REVERSE is faded, and can be held.
	_pick(boards, WHIPLASH)
	if ways.call("button", TrackVariant.REVERSE).modulate.a >= 1.0:
		_fault("Whiplash's boards do not fade REVERSE")

	# From the grid, with the cursor on a track other than the one just
	# driven, the boards open on it as written.
	boards.call("close")
	settings.track_file = FIRST_LIGHT
	settings.track_variant = TrackVariant.MIRROR
	menu.call("_open_track_grid", TrackRoster.NORMAL)
	await process_frame
	var cells: Array = menu.call("_track_cells")
	(menu.call("_button_in", cells[TrackRoster.index_of(WHIPLASH)]) as Control).grab_focus()
	menu.call("_on_boards_pressed")
	_expect_board(boards, WHIPLASH, TrackVariant.NORMAL, "opened from the grid")
	boards.call("close")
	if _faults == before:
		print("the boards open on the way last driven, and keep the way held across tracks")
	_finished += 1


func _pick(boards: Node, file: String) -> void:
	var picker: OptionButton = boards.get("_picker")
	var item := picker.get_item_index(TrackRoster.index_of(file))
	picker.select(item)
	picker.item_selected.emit(item)


func _expect_board(boards: Node, file: String, variant: String, when: String) -> void:
	var showing := TrackRoster.file(boards.get("_showing"))
	var held: String = boards.get("_variant")
	if showing != file or held != variant:
		_fault("%s, the boards show %s %s rather than %s %s" % [when,
			showing.get_file().get_basename(), TrackVariant.display_name(held),
			file.get_file().get_basename(), TrackVariant.display_name(variant)])


## A track's line in the table, found by its name.
func _row(rows: VBoxContainer, named: String) -> HBoxContainer:
	for line in rows.get_children():
		for label in line.get_children():
			if label is Label and (label as Label).text == named:
				return line as HBoxContainer
	return null


## The cell under a way's column: the columns after the number and the name,
## in the order `TrackVariant.ALL` has them.
func _cell(line: HBoxContainer, variant: String) -> Control:
	return line.get_child(2 + TrackVariant.ALL.find(variant))


func _expect_cell(line: HBoxContainer, variant: String, text: String, medal: int) -> void:
	var name := (line.get_child(1) as Label).text
	var time := _cell(line, variant).get_node_or_null("Time") as Label
	if time == null:
		_fault("%s has no time under %s" % [name, TrackVariant.display_name(variant)])
		return
	if time.text != text:
		_fault("%s reads %s under %s, not %s" % [name, time.text,
			TrackVariant.display_name(variant), text])
	var bar: ColorRect = _cell(line, variant).get_node("Medal")
	var shown := bar.modulate.a > 0.0
	if shown != (medal != Medal.NONE) or (shown and bar.color != Medal.colour(medal)):
		_fault("%s's %s bar is not %s" % [name, TrackVariant.display_name(variant),
			Medal.label(medal) if medal != Medal.NONE else "hidden"])


func _expect_blank(line: HBoxContainer, variant: String) -> void:
	if _cell(line, variant).get_child_count() > 0:
		_fault("%s has a time under %s, a way it is not driven"
			% [(line.get_child(1) as Label).text, TrackVariant.display_name(variant)])


func _wipe(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fault(what: String) -> void:
	print("  " + what)
	_faults += 1
