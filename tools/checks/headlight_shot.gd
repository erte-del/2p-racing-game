extends SceneTree

# Look at a car head on, to check the headlights. Four shots: day, night from
# a way back, night from close up, and night with the lights forced off.
#
# That last one is not redundant. The road by the grid carries a painted white
# start band, which at night looks exactly like a headlight pool; the only way
# to tell what the lamps are actually throwing is to turn them off and compare.
#
#   Godot --path . --script tools/checks/headlight_shot.gd -- <out_dir>

const DAY := 0.0
const NIGHT := 260.0


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame

	var day_night: Node = main.get_node("DayNight")
	var car: Node3D = main.get_node("Car1")
	var camera: Camera3D = main.get_node("Split/TopView/SubViewport/Camera")
	# The chase camera would drag it straight back behind the car.
	camera.set_physics_process(false)

	for shot in [["day", DAY], ["night", NIGHT], ["close", NIGHT], ["off", NIGHT]]:
		day_night._time = shot[1]
		day_night._apply(day_night._nightness_at(shot[1]))
		for i in 8:
			await process_frame
		# Ahead of the car and off to one side, looking back at its face.
		var forward: Vector3 = -car.global_transform.basis.z
		var across: Vector3 = car.global_transform.basis.x
		if shot[0] == "off":
			main.set_process(false)
			for c in [main.get_node("Car1"), main.get_node("Car2")]:
				c.set_headlights(0.0)
			await process_frame
		var back: float = 5.5 if shot[0] != "night" else 11.0
		camera.global_position = (car.global_position + forward * back
				+ across * (1.6 if shot[0] != "night" else 3.0)
				+ Vector3.UP * (1.1 if shot[0] != "night" else 1.6))
		camera.look_at(car.global_position + Vector3.UP * 0.7, Vector3.UP)
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		image.save_png("%s/front_%s.png" % [out, shot[0]])
		print("front_%s: level from nightness %.2f" % [shot[0], day_night.night_amount()])
	quit()
