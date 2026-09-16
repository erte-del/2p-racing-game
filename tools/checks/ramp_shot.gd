extends SceneTree

# Look at a car standing on a ramp, from the side, with the shell sunk onto the
# road and without.
#   Godot --path . --script tools/checks/ramp_shot.gd -- <out_dir>
#
# tilt_trace measures what is left of the lift in metres, which says the sums
# are right. It does not say what a player sees, and what a player saw before
# the sink was a car crossing every ramp in the game with its wheels hanging
# clear of it. Both pictures are of the same car in the same place on the same
# step; the only difference is whether the shell was put down on the road.

## How far up the ramp the car stands, as a fraction of its length. Near the
## top, where the ramp is steepest and the lift is worst.
const UP_THE_RAMP := 0.8
## Where the camera stands to watch it go past: out to the side of the road in
## metres, and up off it. Level with the car rather than down on the road, so
## the gap under the wheels is read against the ramp behind them rather than
## foreshortened into it.
const SIDE_ON := 18.0
const EYE_HEIGHT := 4.5


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
	for overlay in ["Hud", "Progress", "Countdown", "Result", "Split"]:
		main.get_node(overlay).hide()

	var track: Track = main.get_node("Track")
	var car: Car = main.get_node("Car1")
	main.get_node("Car2").frozen = true
	# Broad daylight, so what the pictures show is the car on the road and not
	# where the sun happened to be.
	var day_night: Node = main.get_node("DayNight")
	day_night.start_offset = 0.0
	day_night._time = 0.0
	day_night._apply(day_night._nightness_at(0.0))
	# One view of the whole window rather than the split, since both pictures
	# are of the same car and the point is to lay them side by side.
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()

	for course in range(1, 60):
		track.generate(course * 977)
		var jump := _the_jump(track)
		if jump == null:
			continue
		var layout := track.layout()
		var at: float = jump.start_offset + layout.ramp_length * UP_THE_RAMP
		print("course %d: ramp %.0f-%.0f m rising %.1f m; the car stands at %.0f m"
			% [course, jump.start_offset,
				jump.start_offset + layout.ramp_length, layout.ramp_rise, at])

		_park(track, car, at)
		# Left to settle onto the ramp under its own weight, so the box is
		# resting where it really rests and the floor normal is the ramp's.
		car.reset_motion()
		for i in 30:
			car._speed = 0.0
			await physics_frame
		print("standing there the box holds the shell %.2f m off the road, at %.1f degrees"
			% [car._sink, rad_to_deg(car._pitch)])
		# Aimed after the car has settled, so it is looking at where the car
		# ended up rather than where it was dropped.
		_stand(track, camera, car, at)

		# Frozen, so nothing moves between the two and the shell keeps whatever
		# it is last given. Both poses are put on by hand: the same pitch and
		# the same lean either way, with the sink and without it, so the only
		# thing that can differ between the pictures is the sink.
		car.frozen = true
		for shot in [["01_off_the_ramp", 0.0], ["02_on_the_ramp", car._sink]]:
			car._shell.pose(car._pitch, car._dive, car._roll,
				car._drop - (shot[1] as float))
			for i in 4:
				await process_frame
			root.get_texture().get_image().save_png("%s/%s.png" % [out, shot[0]])
		quit()
		return

	print("  no course in the first 60 had a jump to stand on")
	quit(1)


## Drop a car on the middle of the road facing the way it runs.
func _park(track: Track, car: Car, at: float) -> void:
	var curve := track.curve()
	var here: Vector3 = curve.sample_baked(at)
	var ahead: Vector3 = curve.sample_baked(at + 2.0)
	car.frozen = false
	car.global_position = track.global_transform * (here + Vector3.UP * 1.0)
	# Level with itself rather than aimed up the ramp: look_at pitches whatever
	# it aims, and the body is only ever yawed.
	var aim: Vector3 = track.global_transform * ahead
	car.look_at(Vector3(aim.x, car.global_position.y, aim.z), Vector3.UP)


## Stand the camera out to the side of the ramp, looking straight at the car.
func _stand(track: Track, camera: Camera3D, car: Car, at: float) -> void:
	var curve := track.curve()
	var here: Vector3 = curve.sample_baked(at)
	var ahead: Vector3 = curve.sample_baked(at + 2.0)
	var forward := ahead - here
	forward.y = 0.0
	var right := forward.normalized().cross(Vector3.UP)
	camera.global_position = (track.global_transform * here
		+ (track.global_transform.basis * right).normalized() * SIDE_ON
		+ Vector3.UP * EYE_HEIGHT)
	camera.look_at(car.global_position, Vector3.UP)


func _the_jump(track: Track) -> TrackLayout.Piece:
	for piece in track.layout().pieces:
		if piece.kind == TrackLayout.JUMP:
			return piece
	return null
