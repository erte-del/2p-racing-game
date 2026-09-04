extends SceneTree

# Look at solo mode: on the line, driving, and finished.
#   Godot --path . --fixed-fps 60 --script tools/checks/solo_shot.gd -- <out_dir>
#
# The numbers say the clock starts and stops. What they do not say is whether
# a screen with one car on it and no rival still reads as a race.


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.track_file = "res://tracks/01_first_light.gd"
		settings.chaos = false

	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	for i in 40:
		await physics_frame
	await _shoot(out, "01_countdown")

	# Away, and a little way down the road with some speed up.
	var car: Car = solo.get_node("Car")
	while not solo.get("_running"):
		await physics_frame
	for i in 200:
		car._speed = car.max_speed
		await physics_frame
	await _shoot(out, "02_running")

	# On a boost, which is where the clock and the streaks share a screen.
	car.boost()
	for i in 20:
		car._speed = car.max_speed
		await physics_frame
	await _shoot(out, "03_boosting")

	solo.call("_finish")
	for i in 10:
		await physics_frame
	await _shoot(out, "04_finished")
	print("solo drawn")
	quit()


func _shoot(out: String, name: String) -> void:
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
