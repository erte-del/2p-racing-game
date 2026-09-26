extends SceneTree

# Look at the pages between the title and a race.
#   Godot --path . --script tools/checks/track_select_shot.gd -- <out_dir>
#
# These are the sort of thing that is right in the numbers and wrong on the
# screen: a name too long for its column, a grid wider than the window, a
# greyed button that reads as broken rather than as coming, a line of text
# that appears out of nowhere when something is clicked.

func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 800)
	# A time on the board, so the picture shows a track that has been driven
	# next to nineteen that have not.
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times != null:
		times.save_path = "user://times_shot.cfg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
		times.load_times()
		times.record("res://tracks/01_first_light.gd", 41.55)
	# And a profile that has won nothing, so the pictures below start where a
	# player starts: the first ten open, the second ten shut, and the door at
	# the end of the first ten asking for golds that are not there yet.
	var progress: Node = root.get_node_or_null(^"/root/Progress")
	if progress != null:
		progress.save_path = "user://progress_shot.cfg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
		progress.load_progress()

	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	for i in 30:
		await process_frame

	var out: String = OS.get_cmdline_user_args()[0]
	# The page as it opens, with the question at the top and nothing answered.
	menu.call("_on_play_pressed")
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("%s/00_players.png" % out)

	# Answered, with the modes rolled out from the middle.
	menu.call("_choose_players", true)
	for i in 30:
		await process_frame
	root.get_texture().get_image().save_png("%s/01_modes.png" % out)

	# And the flavours out inside that, which the slot has to open further for.
	menu.call("_on_infinite_pressed")
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_png("%s/02_modes_open.png" % out)
	menu.call("_shut_flavour")

	menu.get_node("ModeChoice").hide()
	menu.get_node("TrackChoice").show()
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("%s/03_tracks.png" % out)

	# And the rest of the page: the door at the end of the first ten, and the
	# second ten shut behind it. This is the half of the grid the three states
	# are actually on, so it is the half worth looking at hardest.
	var scroll: ScrollContainer = menu.get_node("TrackChoice/Page/Panel/Margin/Box/Scroll")
	var blocks: VBoxContainer = scroll.get_node("Blocks")
	await _scroll_to_the_door(scroll, blocks)
	root.get_texture().get_image().save_png("%s/04_tracks_below.png" % out)

	# The same page with three golds in the first ten and then with five:
	# the count on the door has to move, and on the fifth the door has to
	# open. Three and five rather than none and five because the picture worth
	# checking is the one where a player is partway there and the page is
	# telling them how far.
	if times != null and progress != null:
		var golds: int = progress.GOLDS_NEEDED
		for index in golds:
			if index == golds - 2:
				await _look_at_the_gate(menu, scroll, blocks,
					"%s/05_gate_short.png" % out)
			times.record(TrackRoster.file(index),
				TrackRoster.targets(index).x - 0.5)
		await _look_at_the_gate(menu, scroll, blocks, "%s/06_gate_open.png" % out)
		# And once it has been beaten, with the ten behind it open.
		progress.win(0)
		await _look_at_the_gate(menu, scroll, blocks, "%s/07_gate_won.png" % out)
		print("the door reads '%s'" % menu.call("_doors")[0].text)

	# A track's own page, opened the way pressing its cell opens it: the wide
	# shot of the road and the ways it can be driven under it.
	menu.call("_open_track_detail", 0)
	# A made-up board, since a check runs with no server: enough rows to show
	# the column filling and scrolling, with the player's own row among them.
	# The player's row is their own best, so the page agrees with itself.
	var board := [{"name": "YOU", "mine": true,
		"seconds": times.best(TrackRoster.file(0)) if times != null else 36.0}]
	for place in 11:
		board.append({"name": ["ALEX", "SAMI", "JORDAN", "KAI", "RIO", "NOOR",
			"ELLIS", "MIKA", "QUINN", "ROBIN", "SKY"][place],
			"seconds": 30.4 + place * 1.37, "mine": false})
	board.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["seconds"] < b["seconds"])
	menu.call("_show_the_detail_board", board)
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("%s/08_track_page.png" % out)
	# HARD held down: its own board, which nobody is on yet, no time, and PLAY
	# off with the line under it saying why.
	var hard: Button = menu.get_node("TrackDetail/Page/Panel/Margin/Box/Variants/Hard")
	hard.button_pressed = true
	hard.pressed.emit()
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("%s/09_track_page_hard.png" % out)
	# The last normal track, and the first acrobatic one, which is driven only
	# NORMAL or MIRROR and so has two ways on its page rather than four.
	menu.call("_close_track_detail")
	menu.call("_open_track_detail", TrackRoster.COUNT - 1)
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("%s/10_track_page_last.png" % out)
	menu.call("_close_track_detail")
	menu.call("_open_track_detail", TrackRoster.first(TrackRoster.ACROBATIC))
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("%s/11_track_page_acrobatic.png" % out)
	menu.call("_close_track_detail")
	# And the first track again with MIRROR held down: the same overhead shot
	# turned round, rather than a second picture drawn and checked in, and
	# HARD and CHAOS faded beside it, since this track does not offer them.
	menu.call("_open_track_detail", 0)
	var mirror: Button = menu.get_node("TrackDetail/Page/Panel/Margin/Box/Variants/Mirror")
	mirror.button_pressed = true
	mirror.pressed.emit()
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("%s/12_track_page_mirror.png" % out)
	# REVERSE held on a track that offers it, and on one that does not, whose
	# line over PLAY is that track's own reason rather than a generic one.
	var reverse: Button = menu.get_node("TrackDetail/Page/Panel/Margin/Box/Variants/Reverse")
	reverse.button_pressed = true
	reverse.pressed.emit()
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("%s/13_track_page_reverse.png" % out)
	menu.call("_close_track_detail")
	menu.call("_open_track_detail", TrackRoster.FILES.find("res://tracks/17_whiplash.gd"))
	reverse.button_pressed = true
	reverse.pressed.emit()
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("%s/14_track_page_reverse_refused.png" % out)
	menu.call("_close_track_detail")

	# Said as well as drawn: a name cut off at one end of twenty is easy to
	# look straight past in a picture.
	var too_long := 0
	for cell in menu.call("_track_cells"):
		var label := cell.get_child(0) as Label
		var needs := label.get_theme_font("font").get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			label.get_theme_font_size("font_size")).x
		if needs > label.size.x - label.get_theme_stylebox("normal").get_minimum_size().x:
			print("  %s is too long for its column" % label.text)
			too_long += 1
	if times != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
	if progress != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(progress.save_path))
	print("mode page and track select drawn, %d names too long for their columns"
		% too_long)
	quit()


## Build the page again and look at the door at the end of the first ten, which
## is where all three states are on the screen at once: the open ten above it,
## the door itself, and the shut ten below.
func _look_at_the_gate(menu: Node, scroll: ScrollContainer, blocks: VBoxContainer,
		where: String) -> void:
	menu.call("_refresh_the_track_grid")
	for i in 12:
		await Engine.get_main_loop().process_frame
	await _scroll_to_the_door(scroll, blocks)
	Engine.get_main_loop().root.get_texture().get_image().save_png(where)


## Scroll down to the second row of the first block, which puts the door and
## the block under it on the screen.
func _scroll_to_the_door(scroll: ScrollContainer, blocks: VBoxContainer) -> void:
	var grid := blocks.get_child(0) as GridContainer
	scroll.scroll_vertical = int(grid.get_child(grid.columns).position.y)
	for i in 12:
		await Engine.get_main_loop().process_frame
