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
#
# Tipping the shell is only half of standing it on a ramp, so the other half is
# read as well: how far the shell is off the road directly under the middle of
# the car. The collision box does not tip, so on a slope it rests on one bottom
# edge and holds the shell clear of the surface the car is plainly driving on -
# over a metre of it at the lip of a ramp - and the car sinks the shell back
# down by as much. This reads what is left.
#
# And it reads the wheels apart from the body, because they are posed apart
# from it: they are held where a body sitting square on the road would carry
# them, so that they stay down through a lean the body takes on its springs.
# Square on the road has to include the sink - a wheel that skips it stands a
# metre over the ramp while the body it belongs to is down on it - and nothing
# read off the body can tell whether it did.

const RUN_UP := 24.0
## The most daylight there may be under the shell, in metres, and the furthest
## it may be buried in the road. A ramp that steepens under a rigid shell puts
## a centimetre or two either way whatever is done, so neither is zero.
const CLEARANCE := 0.1
## The same for a wheel, measured against the road under that wheel. Looser
## than the body's, which is read at the middle of the car where a rigid shell
## on a curving ramp is closest to right: the wheels are read at the ends of
## it, where a ramp that is still steepening leaves one axle a little proud,
## and at a lip the front pair are out over the hole while the shell holds
## where it was.
const WHEEL_CLEARANCE := 0.3
## Further under the shell than this, in metres, and what the ray found is not
## the road the car is on. The box is 4.87 m long and tips no further than 32
## degrees, so it can hold its middle 1.5 m clear at the very most; a reading
## past that is the car out over the hole with its box resting on the lip
## behind it, and the ray has gone straight down the hole to the landing.
const NO_ROAD := 2.0


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
	# The worst the shell sat off the road, and the worst it sat in it, over
	# every step the car had road under it.
	var highest := 0.0
	var deepest := 0.0
	var lifted := 0.0
	# And the worst any one wheel sat off the road under it, and in it.
	var wheels_highest := 0.0
	var wheels_deepest := 0.0
	var over_the_hole := 0
	var on_the_road := 0
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
		var clear := _clearance(car)
		var wheels := _wheel_clearance(car)
		if where != "in the air":
			lifted = maxf(lifted, car._sink)
			if clear > NO_ROAD:
				over_the_hole += 1
			else:
				on_the_road += 1
				highest = maxf(highest, clear)
				deepest = minf(deepest, clear)
				# A wheel out over the hole reads the landing the same way the
				# body does, so those steps are left out of the wheels too.
				#
				# So is the step the car lands on. The shell comes down still
				# carrying the pitch of the flight and eases out of it over the
				# next few steps, which puts the nose in the road and the tail
				# in the air at both ends of a car this long. That is the pitch
				# easing, which is deliberate, and it moves the body and the
				# wheels alike; reading it here would only be this check
				# complaining about a different part of the game.
				if where != "landed" and absf(wheels.x) < NO_ROAD \
						and absf(wheels.y) < NO_ROAD:
					wheels_highest = maxf(wheels_highest, wheels.x)
					wheels_deepest = minf(wheels_deepest, wheels.y)
		if i % 8 == 0 or where == "landed":
			print("%3d  y %5.2f  pitch %+6.1f deg  sunk %4.2f m  clear %+5.2f m   %s"
				% [i, car.global_position.y, pitch, car._sink, clear, where])
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
	print("the box lifted the shell by up to %.2f m; what was left of it was"
		% lifted
		+ " %+.2f m of daylight and %+.2f m of road" % [highest, deepest]
		+ ", over %d steps with road under the middle of the car and %d without"
		% [on_the_road, over_the_hole])
	if highest > CLEARANCE:
		print("  the shell hangs off the road it is standing on")
		faults += 1
	if deepest < -CLEARANCE:
		print("  the shell is buried in the road it is standing on")
		faults += 1
	print("the wheels were %+.2f m off the road at worst and %+.2f m into it"
		% [wheels_highest, wheels_deepest])
	if wheels_highest > WHEEL_CLEARANCE:
		print("  a wheel hangs off the road the car is standing on")
		faults += 1
	if wheels_deepest < -WHEEL_CLEARANCE:
		print("  a wheel is buried in the road the car is standing on")
		faults += 1
	faults += await _over_a_hill(main, track, car)
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## How far the shell sits above the road directly under the middle of the car,
## in metres. Negative is the shell in the road.
##
## Read off the shell's own node rather than off anything the car worked out,
## so what is measured is where the thing a player is looking at actually
## ended up.
func _clearance(car: Car) -> float:
	var shell: Node3D = car.get_node(^"Body")
	var from := car.global_position + Vector3.UP * 2.0
	var query := PhysicsRayQueryParameters3D.create(
		from, from + Vector3.DOWN * 8.0, car.collision_mask, [car.get_rid()])
	var hit := car.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return 0.0
	return shell.global_position.y - (hit["position"] as Vector3).y


## The worst any one wheel sits above the road beneath it, and the worst it
## sits in it, in metres - as [highest, deepest].
##
## Each wheel is read against the road under that wheel rather than under the
## middle of the car: on a ramp those are different heights, and the question
## is whether that wheel is on the road it is over.
func _wheel_clearance(car: Car) -> Vector2:
	var highest := -INF
	var deepest := INF
	var shell: Node3D = car.get_node(^"Body")
	for name in CarShell.FRONT_WHEELS + CarShell.REAR_WHEELS:
		var wheel := shell.find_child(name, true, false) as Node3D
		if wheel == null:
			continue
		var bottom := wheel.global_position - Vector3.UP * car.wheel_radius
		var from := wheel.global_position + Vector3.UP * 2.0
		var query := PhysicsRayQueryParameters3D.create(
			from, from + Vector3.DOWN * 8.0, car.collision_mask, [car.get_rid()])
		var hit := car.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue
		var clear := bottom.y - (hit["position"] as Vector3).y
		highest = maxf(highest, clear)
		deepest = minf(deepest, clear)
	if is_inf(highest):
		return Vector2.ZERO
	return Vector2(highest, deepest)


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
