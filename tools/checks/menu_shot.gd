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

	var world: Node = menu.get_node("World")
	var camera: Camera3D = menu.get_node("Orbit")
	for view in menu.get_node("World/Split").get_children():
		print("split viewport update mode: ", view.get_child(0).render_target_update_mode)

	# Far enough apart that the camera has swung well round, and that the title
	# should be leaning the other way.
	# The backdrop's own clock, which in attract mode runs a 25 second phase.
	var day_night: Node = world.get_node("DayNight")
	for shot in [["a", 0.65, 0.0], ["b", 22.0, 0.0],
			["evening", 22.0, 37.5], ["night", 22.0, 60.0]]:
		day_night._time = shot[2]
		day_night._apply(day_night._nightness_at(shot[2]))
		menu._elapsed = shot[1]
		await process_frame
		await process_frame
		var to_centre: Vector3 = camera.global_position - world.grid_centre()
		print("t=%5.2f  nightness %.2f  tilt %+.2f deg  bob %+.2f px  camera %.1f m out, bearing %+.0f deg"
			% [shot[1], day_night.night_amount(),
				rad_to_deg(title.rotation), title.position.y,
				Vector2(to_centre.x, to_centre.z).length(),
				rad_to_deg(atan2(to_centre.x, to_centre.z))])
		root.get_texture().get_image().save_png("%s/menu_%s.png" % [out, shot[0]])

	menu.get_node("Play").emit_signal("pressed")
	await process_frame
	await process_frame
	await process_frame
	print("after Play: current scene is ", current_scene.name,
		", cars: ", current_scene.get_node_or_null("Car1") != null)
	quit()
