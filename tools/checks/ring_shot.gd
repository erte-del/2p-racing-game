extends SceneTree

# Look at a ring from the run up, from the lip, through it and past it.
#   Godot --path . --fixed-fps 60 --script tools/checks/ring_shot.gd -- <out_dir> [track file] [ring]
#
# `ring` counts from 0 in the order they are met, and is the first when it is
# left out. A ring that moves is timed to be in the middle of the road as the
# car gets to it.

const RUN_UP := 45.0


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	settings.track_file = args[1] if args.size() > 1 else "res://tools/checks/ring_course.gd"
	var which: int = int(args[2]) if args.size() > 2 else 0
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	await process_frame
	solo.set("_countdown_run", int(solo.get("_countdown_run")) + 1)
	solo.get_node("Hud").hide()
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")

	var rings: Array[TrackFeatures.Placement] = []
	for placement in track.definition().placements:
		if placement.kind == TrackFeatures.RING:
			rings.append(placement)
	rings.sort_custom(func(a: TrackFeatures.Placement, b: TrackFeatures.Placement) -> bool:
		return a.centre() < b.centre())
	var ring := rings[which]
	var jump: TrackLayout.Piece
	for piece in track.layout().pieces:
		if piece.kind == TrackLayout.JUMP and piece.start_offset < ring.centre() and piece.end_offset > ring.centre():
			jump = piece
	var at := jump.start_offset - RUN_UP
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
	# Flat out from a standstill-ish settle: about this long to reach the ring.
	var arrive := (ring.centre() - at) / car.max_speed + 0.4
	var clock := 0.0
	for t in range(0, 800):
		var s := float(t) * 0.01
		if absf(ring.lateral_at(s + arrive)) < 0.03:
			clock = s
			break
	solo.set("_time", clock)
	track.set_race_time(clock)
	solo.set("_was", car.middle())
	solo.set("_running", true)

	var shots := {"approach": jump.start_offset - 20.0, "lip": jump.start_offset + track.ramp_length - 1.0,
		"through": ring.centre() - 1.0, "after": jump.start_offset + track.ramp_length + track.layout().gap_of(jump) + 25.0}
	for name in shots:
		var waited := 0
		while track.offset_of(car.global_position) < shots[name] and waited < 600:
			car._speed = car.max_speed
			waited += 1
			await physics_frame
		solo.set("_running", false)
		car.frozen = true
		for i in 4:
			await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("%s/ring_%s.png" % [out, name])
		car.frozen = false
		solo.set("_running", true)
	print("banked: ", solo.get("_banked"))
	quit()
