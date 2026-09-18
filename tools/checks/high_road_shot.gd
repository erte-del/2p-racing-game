extends SceneTree

# Look at the first high road on a track: from the run up to its kicker, at the
# lip, on the high road, and dropping back onto the course.
#   Godot --path . --fixed-fps 60 --script tools/checks/high_road_shot.gd -- <out_dir> [track file]


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	settings.track_file = args[1] if args.size() > 1 else "res://tools/checks/high_road_course.gd"
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	await process_frame
	solo.set("_countdown_run", int(solo.get("_countdown_run")) + 1)
	solo.get_node("Hud").hide()
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	var branch: BranchDefinition = track.definition().branches[0]
	var road: Track = track.branches()[0]
	var kicker := branch.lip_offset - track.ramp_length
	var at := kicker - 55.0
	var here := track.centre_at(at)
	var ahead := track.centre_at(at + 2.0)
	var right := ((ahead - here) * Vector3(1, 0, 1)).normalized().cross(Vector3.UP)
	car.frozen = true
	car.global_position = here + right * (branch.lane * track.half_width_at(at)) + Vector3.UP * (car.wheel_radius + 0.6)
	car.look_at(car.global_position + (ahead - here) * Vector3(1, 0, 1), Vector3.UP)
	car.frozen = false
	car.reset_motion()
	car.reset_physics_interpolation()
	for i in 25:
		car._speed = 0.0
		await physics_frame
	solo.set("_was", car.middle())
	solo.set("_running", true)
	# Measured along the high road's own line, since the course has turned away.
	var start := road.centre_at(0.0)
	var forward := (road.global_transform.basis * Vector3.FORWARD).normalized()
	var shots := {
		"approach": [track, kicker - 25.0],
		"lip": [track, branch.lip_offset - 2.0],
		"high": [road, 40.0],
		"drop": [road, road.length() - 5.0],
	}
	for name in shots:
		var waited := 0
		while waited < 900:
			var reached := false
			if shots[name][0] == track:
				reached = track.offset_of(car.global_position) >= shots[name][1]
			else:
				reached = (car.global_position - start).dot(forward) >= shots[name][1]
			if reached:
				break
			car._speed = car.max_speed
			waited += 1
			await physics_frame
		solo.set("_running", false)
		car.frozen = true
		for i in 4:
			await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("%s/high_road_%s.png" % [out, name])
		car.frozen = false
		solo.set("_running", true)
	quit()
