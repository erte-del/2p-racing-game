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
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times != null:
		times.save_path = "user://times_shot.cfg"
		times.load_times()
		times.record("res://tracks/01_first_light.gd", 43.10)

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

	# A time worth a medal, so the picture shows one.
	solo.set("_time", 41.55)
	solo.call("_finish")
	for i in 10:
		await physics_frame
	await _shoot(out, "04_finished")

	# The same track mirrored: the corner and the finish screen both name the
	# road with the way it was driven beside it, so a screenshot of a time says
	# which road it was set on.
	solo.queue_free()
	await process_frame
	if settings != null:
		settings.track_variant = TrackVariant.MIRROR
	solo = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	for i in 40:
		await physics_frame
	await _shoot(out, "05_countdown_mirror")
	while not solo.get("_running"):
		await physics_frame
	solo.set("_time", 41.55)
	solo.call("_finish")
	for i in 10:
		await physics_frame
	await _shoot(out, "06_finished_mirror")
	if settings != null:
		settings.track_variant = TrackVariant.NORMAL
	if times != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
	print("solo drawn")
	quit()


func _shoot(out: String, name: String) -> void:
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
