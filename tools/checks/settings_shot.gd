extends SceneTree

# Walk the settings screen: open it, look at the controls sheet, pin the sky.
#   Godot --path . --script tools/checks/settings_shot.gd -- <out_dir>


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	change_scene_to_file("res://scenes/menu.tscn")
	await process_frame
	await process_frame
	var menu: Control = current_scene
	var settings: Control = menu.get_node("SettingsScreen")
	var day_night: Node = menu.get_node("World/DayNight")

	print("autoload found: ", root.get_node_or_null("GameSettings") != null)

	menu.get_node("Settings").emit_signal("pressed")
	await _settle()
	print("settings open: ", settings.visible,
		"  volume shown: ", settings.get_node(
			"SettingsPage/Panel/Margin/Box/Volume/Row/Value").text)
	_shot(out, "settings")

	settings.get_node("SettingsPage/Panel/Margin/Box/Pages/Controls").emit_signal("pressed")
	await _settle()
	for player in ["P1", "P2"]:
		var keys: GridContainer = settings.get_node(
			"ControlsPage/Panel/Margin/Box/Columns/%s/Keys" % player)
		var line := PackedStringArray()
		for i in range(0, keys.get_child_count(), 2):
			line.append("%s = %s" % [keys.get_child(i).text, keys.get_child(i + 1).text])
		print(player, ": ", ", ".join(line))
	_shot(out, "controls")

	settings.get_node("ControlsPage/Panel/Margin/Box/Back").emit_signal("pressed")
	await _settle()

	# The sky eases over a sunset, which the backdrop runs at 25 seconds. Cut
	# that down so the check can watch it arrive in a second of frames.
	day_night.transition_seconds = 0.5

	# Pin the sky to night, and let it run long enough to have got there.
	settings.get_node("SettingsPage/Panel/Margin/Box/Sky/Row/Night").emit_signal("pressed")
	for i in 90:
		await process_frame
	print("pinned night: nightness %.2f" % day_night.night_amount())
	_shot(out, "night_pinned")

	settings.get_node("SettingsPage/Panel/Margin/Box/Sky/Row/Day").emit_signal("pressed")
	for i in 90:
		await process_frame
	print("pinned day:   nightness %.2f" % day_night.night_amount())
	_shot(out, "day_pinned")

	settings.get_node("SettingsPage/Panel/Margin/Box/Close").emit_signal("pressed")
	await _settle()
	print("closed: ", not settings.visible,
		"  saved time_of_day: ", root.get_node("GameSettings").time_of_day)
	_shot(out, "closed")

	# The choice has to survive the menu being thrown away: a race started
	# with the sky pinned should open already there, with no dawn to sit out.
	root.get_node("GameSettings").time_of_day = root.get_node("GameSettings").ALWAYS_NIGHT
	# Play opens the mode page rather than a race, so the race is reached the
	# way a player reaches it: two playing, infinite, then a normal race. Each
	# press waits out the slide it starts, as a player would.
	var page := "ModeChoice/Page/Panel/Margin/Box/"
	for button in ["Play", page + "Players/Together", page + "ModeSlot/Inner/Infinite",
			page + "ModeSlot/Inner/FlavourSlot/Inner/Row/Normal"]:
		menu.get_node(button).emit_signal("pressed")
		for i in 30:
			await process_frame
	print("race scene: ", current_scene.name, "  nightness %.2f"
		% current_scene.get_node("DayNight").night_amount())
	for i in 40:
		await process_frame
	_shot(out, "race_pinned_night")
	quit()


func _settle() -> void:
	for i in 4:
		await process_frame


func _shot(out: String, name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
