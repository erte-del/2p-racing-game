extends SceneTree

# Look at a fork from where the players meet one - the top car in the fast
# lane, the bottom car in the clear one.
#   Godot --path . --script tools/checks/barrier_shot.gd -- <out_dir>
#
# Two things are worth seeing that no number says: whether the choice reads
# from far enough back to be made, and whether a barrier is still a barrier
# once the sun goes down.

const BACK_FROM := 26.0


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.chaos = false

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	for overlay in ["Hud", "Progress", "Countdown", "Result"]:
		main.get_node(overlay).hide()

	var track: Track = main.get_node("Track")
	var day_night: Node = main.get_node("DayNight")
	var car1: Car = main.get_node("Car1")
	var car2: Car = main.get_node("Car2")

	for course in range(1, 60):
		track.generate(course * 977)
		var forks := track.features().of_kind(TrackFeatures.FORK)
		if forks.is_empty() or forks[0].offset < BACK_FROM + 10.0:
			continue
		var fork: TrackFeatures.Placement = forks[0]
		var inside := 0
		for row in track.features().rows():
			if row.offset >= fork.offset and row.offset < fork.offset + fork.length:
				inside += 1
		print("course %d: fork at %.0f m, %.0f m long, fast lane on the %s, %d barriers in it"
			% [course, fork.offset, fork.length,
				"left" if fork.lateral < 0.0 else "right", inside])

		# One car in the fast lane and one in the clear one, so the two halves
		# of the picture are the two ways through the same stretch of road.
		var side: float = signf(fork.lateral)
		_park(track, car1, fork.offset - BACK_FROM, side * 0.55)
		_park(track, car2, fork.offset - BACK_FROM, -side * 0.55)
		main.get_node("Split/TopView/SubViewport/Camera").follow(car1)
		main.get_node("Split/BottomView/SubViewport/Camera").follow(car2)

		for shot in [["01_day", 0.0], ["02_night", 260.0]]:
			day_night.start_offset = shot[1]
			day_night._time = shot[1]
			day_night._apply(day_night._nightness_at(shot[1]))
			for i in 10:
				car1.frozen = true
				car2.frozen = true
				await physics_frame
			for i in 5:
				await process_frame
			root.get_texture().get_image().save_png("%s/%s.png" % [out, shot[0]])
		# quit() only asks; without the return the loop would run on and
		# overwrite these pictures with the next course's fork.
		quit()
		return

	print("  no course in the first 60 had a fork far enough in")
	quit(1)


## Drop a car on the road facing the way it runs, across it by `lateral`.
func _park(track: Track, car: Car, at: float, lateral: float) -> void:
	var curve := track.curve()
	var here: Vector3 = curve.sample_baked(at)
	var ahead: Vector3 = curve.sample_baked(at + 2.0)
	var forward := ahead - here
	forward.y = 0.0
	var right := forward.normalized().cross(Vector3.UP)
	car.global_position = track.global_transform * (
		here + right * (lateral * track.half_width_at(at))
		+ Vector3.UP * car.wheel_radius)
	car.look_at(track.global_transform * ahead, Vector3.UP)
