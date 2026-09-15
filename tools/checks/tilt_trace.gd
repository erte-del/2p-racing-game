extends SceneTree

# Watch the shell tip as a car takes a jump.
#   Godot --path . --headless --script tools/checks/tilt_trace.gd
#
# A jump has every case in it, in order: flat road, a ramp, the nose coming up
# off the lip, the nose dropping through the top of the flight, and the road
# again on landing. If the shell reads all five correctly it reads a climb
# correctly too, a climb being a gentle ramp that never runs out.
#
# What is read is the road pitch the car works out, not the shell's own angle.
# The shell also leans on its springs - nose down under braking, back under
# throttle - and that is the driver, not the road.

const RUN_UP := 24.0


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.chaos = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var track: Track = main.get_node("Track")
	var car: Car = main.get_node("Car1")
	main.get_node("Car2").frozen = true

	var jump: TrackLayout.Piece = null
	for course in range(1, 60):
		track.generate(course * 977)
		for piece in track.layout().pieces:
			if piece.kind == TrackLayout.JUMP:
				jump = piece
		if jump != null:
			break
	if jump == null:
		print("  no course in the first 60 had a jump on it")
		quit(1)
		return

	var curve := track.curve()
	var at: float = jump.start_offset - RUN_UP
	car.frozen = true
	car.global_position = track.global_transform * (
		curve.sample_baked(at) + Vector3.UP * (car.wheel_radius + 0.6))
	# Aimed level with itself, not at the road: look_at pitches whatever it
	# aims, and a car dropped above the road and pointed down at it starts the
	# run leaning over.
	var ahead: Vector3 = track.global_transform * curve.sample_baked(at + 2.0)
	car.look_at(Vector3(ahead.x, car.global_position.y, ahead.z), Vector3.UP)
	# Dropped and left to settle on the road under its own weight before the
	# run starts, so the fall onto it is not mistaken for the jump.
	car.frozen = false
	car.reset_motion()
	for i in 25:
		car._speed = 0.0
		await physics_frame
	car.reset_motion()

	var ground := car.global_position.y
	var flat := rad_to_deg(car._pitch)
	var up := 0.0
	var down := 0.0
	var landed := 0.0
	var was_airborne := false
	for i in 300:
		car._speed = car.max_speed
		await physics_frame
		var pitch := rad_to_deg(car._pitch)
		var where := ""
		if not car.is_on_floor():
			was_airborne = true
			where = "in the air"
		elif was_airborne:
			landed = pitch
			where = "landed"
		elif car.global_position.y > ground + 0.3:
			where = "on the ramp"
		else:
			where = "on the flat"
		if where != "on the flat":
			up = maxf(up, pitch)
			down = minf(down, pitch)
		if i % 8 == 0 or where == "landed":
			print("%3d  y %5.2f  pitch %+6.1f deg   %s"
				% [i, car.global_position.y, pitch, where])
		if where == "landed":
			break

	print("")
	print("level road %+.1f, steepest nose up %+.1f, steepest nose down %+.1f, on landing %+.1f"
		% [flat, up, down, landed])
	var faults := 0
	if absf(flat) > 1.0:
		print("  the shell is not level on level road")
		faults += 1
	if up < 8.0:
		print("  the nose never came up")
		faults += 1
	if down > -8.0:
		print("  the nose never came down")
		faults += 1
	if not was_airborne:
		print("  the car never left the ground, so nothing here was tested")
		faults += 1
	faults += await _over_a_hill(main, track, car)
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## And the case a jump does not cover: a plain climb, which is a gentle grade
## the car never leaves. It is the same floor normal doing the work, but the
## angles are small enough to be worth reading rather than assumed.
func _over_a_hill(main: Node, track: Track, car: Car) -> int:
	var climb: TrackLayout.Piece = null
	for course in range(1, 60):
		track.generate(course * 977 + 3)
		for piece in track.layout().pieces:
			if piece.kind == TrackLayout.CLIMB and piece.rise > 3.0:
				climb = piece
		if climb != null:
			break
	if climb == null:
		print("  no course in the first 60 had a climb to drive up")
		return 1

	var curve := track.curve()
	var at: float = climb.start_offset - 10.0
	car.frozen = false
	car.global_position = track.global_transform * (
		curve.sample_baked(at) + Vector3.UP * (car.wheel_radius + 0.6))
	var ahead: Vector3 = track.global_transform * curve.sample_baked(at + 2.0)
	car.look_at(Vector3(ahead.x, car.global_position.y, ahead.z), Vector3.UP)
	car.reset_motion()
	for i in 25:
		car._speed = 0.0
		await physics_frame
	car.reset_motion()

	var steepest := 0.0
	var frames: int = int((climb.length + 20.0) / car.max_speed * 60.0)
	for i in frames:
		car._speed = car.max_speed
		await physics_frame
		if absf(rad_to_deg(car._pitch)) > absf(steepest):
			steepest = rad_to_deg(car._pitch)

	var grade := rad_to_deg(atan2(climb.rise, climb.length))
	print("")
	print("a %.1f m climb over %.0f m is a %.1f degree grade; the shell read %+.1f"
		% [climb.rise, climb.length, grade, steepest])
	if absf(absf(steepest) - absf(grade)) > 2.0:
		print("  the shell does not follow a plain climb")
		return 1
	return 0
