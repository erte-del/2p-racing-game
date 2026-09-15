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
		times.load_times()
		times.record("res://tracks/01_first_light.gd", 41.55)

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

	# And the rows the page opens scrolled away from, whose names are no less
	# likely to be too long for their columns.
	var scroll: ScrollContainer = menu.get_node("TrackChoice/Page/Panel/Margin/Box/Scroll")
	var grid: GridContainer = scroll.get_node("Grid")
	scroll.scroll_vertical = int(grid.get_child(grid.columns * 2).position.y)
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("%s/04_tracks_below.png" % out)

	# Said as well as drawn: a name cut off at one end of twenty is easy to
	# look straight past in a picture.
	var too_long := 0
	for cell in grid.get_children():
		var label := cell.get_child(0) as Label
		var needs := label.get_theme_font("font").get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			label.get_theme_font_size("font_size")).x
		if needs > label.size.x - label.get_theme_stylebox("normal").get_minimum_size().x:
			print("  %s is too long for its column" % label.text)
			too_long += 1
	if times != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
	print("mode page and track select drawn, %d names too long for their columns"
		% too_long)
	quit()
