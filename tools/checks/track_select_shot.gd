extends SceneTree

# Look at the track select screen.
#   Godot --path . --script tools/checks/track_select_shot.gd -- <out_dir>
#
# Twenty cells built in code is the sort of thing that is right in the numbers
# and wrong on the screen: a name too long for its column, a grid wider than
# the window, a greyed button that reads as broken rather than as coming.

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
	menu.get_node("ModeChoice").show()
	for i in 8:
		await process_frame
	root.get_texture().get_image().save_png("%s/01_modes.png" % out)

	menu.get_node("ModeChoice").hide()
	menu.get_node("TrackChoice").show()
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png("%s/02_tracks.png" % out)
	if times != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
	print("track select drawn")
	quit()
