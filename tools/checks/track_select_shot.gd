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
	# The mode page as it opens, and again with the flavour buttons rolled
	# out - the second is where the line under Infinite has to have moved down
	# rather than appeared.
	menu.call("_on_play_pressed")
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png("%s/01_modes.png" % out)
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
	if times != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
	print("mode page and track select drawn")
	quit()
