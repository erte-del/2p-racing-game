extends SceneTree

# Look at a jump: from the run up, and from the side in mid air.
#   Godot --path . --script tools/checks/jump_shot.gd -- <out_dir>
#
# The numbers say a car clears the hole. What they do not say is whether the
# ramp reads as a ramp from far enough back to commit to, and whether the hole
# reads as a hole rather than as a patch of missing road.

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
	var car1: Car = main.get_node("Car1")
	var car2: Car = main.get_node("Car2")
	var camera1: ChaseCamera = main.get_node("Split/TopView/SubViewport/Camera")
	var camera2: ChaseCamera = main.get_node("Split/BottomView/SubViewport/Camera")

	for course in range(1, 60):
		track.generate(course * 977)
		var jump := _the_jump(track)
		if jump == null or jump.start_offset < BACK_FROM + 10.0:
			continue
		var layout := track.layout()
		var lip: float = jump.start_offset + layout.ramp_length
		print("course %d: ramp %.0f-%.0f m rising %.1f m, hole %.1f m, landing %.0f m"
			% [course, jump.start_offset, lip, layout.ramp_rise,
				layout.jump_gap, layout.landing_length])

		# The top car sits back on the run up, where the choice to commit to
		# the ramp is made. The bottom one is held in the air over the hole,
		# which is the only way to see what is under a car in mid jump.
		_park(track, car1, jump.start_offset - BACK_FROM, 0.0)
		_park(track, car2, lip + layout.jump_gap * 0.5, 0.0)
		car2.global_position += Vector3.UP * 2.5
		camera1.follow(car1)
		camera2.follow(car2)

		for shot in [["01_day", 0.0], ["02_night", 260.0]]:
			var day_night: Node = main.get_node("DayNight")
			day_night.start_offset = shot[1]
			day_night._time = shot[1]
			day_night._apply(day_night._nightness_at(shot[1]))
			# Frozen before any physics runs, or the car over the hole falls
			# into it before the picture is taken.
			car1.frozen = true
			car2.frozen = true
			for i in 10:
				await physics_frame
			for i in 5:
				await process_frame
			root.get_texture().get_image().save_png("%s/%s.png" % [out, shot[0]])
		# quit() only asks; without the return the loop would run on and
		# overwrite these pictures with the next course's jump.
		quit()
		return

	print("  no course in the first 60 had a jump far enough in")
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


func _the_jump(track: Track) -> TrackLayout.Piece:
	for piece in track.layout().pieces:
		if piece.kind == TrackLayout.JUMP:
			return piece
	return null
