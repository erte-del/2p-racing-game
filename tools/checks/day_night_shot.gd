extends SceneTree

# Render the world at a few points in the day/night cycle.
#   Godot --path . --script tools/checks/day_night_shot.gd -- <out_dir>

const POINTS := {
	"01_day": 0.0,
	"02_sunset": 192.5,   # middle of the first fade
	"025_dusk": 198.75,
	"03_night": 260.0,
	"04_sunrise": 397.5,  # middle of the second fade
}


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("DayNight").start_offset = 0.0
	root.add_child(main)
	for i in 30:
		await process_frame

	var day_night: Node = main.get_node("DayNight")
	for name in POINTS:
		day_night.start_offset = POINTS[name]
		day_night._time = POINTS[name]
		day_night._apply(day_night._nightness_at(POINTS[name]))
		print("%-12s nightness %.2f  sun energy %.2f  elev %.1f"
			% [name, day_night.night_amount(),
				main.get_node("Sun").light_energy,
				-rad_to_deg(main.get_node("Sun").rotation.x)])
		for i in 8:
			await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		image.save_png("%s/%s.png" % [out, name])
	quit()
