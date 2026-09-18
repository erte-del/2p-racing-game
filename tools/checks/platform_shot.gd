extends SceneTree

# Look at the first platform on a track from the run up, in the air, on it, and
# on the road past it.
#   Godot --path . --fixed-fps 60 --script tools/checks/platform_shot.gd -- <out_dir> [track file]


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	settings.track_file = args[1] if args.size() > 1 else "res://tools/checks/platform_course.gd"
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	await process_frame
	solo.set("_countdown_run", int(solo.get("_countdown_run")) + 1)
	solo.get_node("Hud").hide()
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	var platform: TrackFeatures.Placement = track.features().of_kind(TrackFeatures.PLATFORM)[0]
	var jump: TrackLayout.Piece
	for piece in track.layout().pieces:
		if piece.kind == TrackLayout.JUMP and piece.start_offset < platform.offset and piece.end_offset > platform.offset:
			jump = piece
	var at := jump.start_offset - 50.0
	var here := track.centre_at(at)
	var ahead := track.centre_at(at + 2.0)
	car.frozen = true
	car.global_position = here + Vector3.UP * (car.wheel_radius + 0.6)
	car.look_at(car.global_position + (ahead - here) * Vector3(1, 0, 1), Vector3.UP)
	car.frozen = false
	car.reset_motion()
	car.reset_physics_interpolation()
	for i in 25:
		car._speed = 0.0
		await physics_frame
	# Timed so the platform is in the middle of the road as the car comes down:
	# a run from 50 m back takes about 2.8 s to reach it.
	var clock := 0.0
	for t in range(0, 600):
		var s := float(t) * 0.01
		if absf(platform.lateral_at(s + 2.8)) < 0.03 and platform.lift_at(s + 2.8) < 0.01:
			clock = s
			break
	solo.set("_time", clock)
	solo.set("_was", car.middle())
	solo.set("_running", true)
	var lip := jump.start_offset + track.ramp_length
	var shots := {"approach": jump.start_offset - 25.0, "air": lip + 8.0, "on": platform.centre(),
		"beyond": jump.end_offset - 20.0}
	for name in shots:
		# Given up on after ten seconds, so a car that went off the road
		# somewhere does not leave this waiting for ever.
		var waited := 0
		while track.offset_of(car.global_position) < shots[name] and waited < 600:
			car._speed = car.max_speed
			waited += 1
			await physics_frame
		# Held for a few drawn frames, with the car and the clock frozen where
		# they are, so the picture is of this moment and not of one the window
		# drew a while ago.
		solo.set("_running", false)
		car.frozen = true
		for i in 4:
			await process_frame
		# Drawn on demand: a window left in the background is not always drawn
		# on its own, and a stale frame is the wrong picture.
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("%s/platform_%s.png" % [out, name])
		car.frozen = false
		solo.set("_running", true)
	quit()
