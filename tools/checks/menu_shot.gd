extends SceneTree

# Look at the title screen, and check that Play actually starts the race.
#   Godot --path . --script tools/checks/menu_shot.gd -- <out_dir>


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/menu.tscn")
	await process_frame
	await process_frame
	var menu: Control = current_scene
	var title: Label = menu.get_node("TitleSlot/Title")

	# Two points a little over half a rock apart, so the two shots should lean
	# opposite ways.
	for shot in [["a", 0.65], ["b", 2.0]]:
		menu._elapsed = shot[1]
		await process_frame
		await process_frame
		print("t=%.2f  tilt %+.2f deg  bob %+.2f px"
			% [shot[1], rad_to_deg(title.rotation), title.position.y])
		root.get_texture().get_image().save_png("%s/menu_%s.png" % [out, shot[0]])

	menu.get_node("Play").emit_signal("pressed")
	await process_frame
	await process_frame
	await process_frame
	print("after Play: current scene is ", current_scene.name,
		", cars: ", current_scene.get_node_or_null("Car1") != null)
	quit()
