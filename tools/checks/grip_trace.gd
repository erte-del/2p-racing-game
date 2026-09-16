extends SceneTree

# Trace the sideways grip: how far the way a car travels lags the way it is
# pointing, with no track and no player.
#   Godot --path . --headless --script tools/checks/grip_trace.gd
#
# Steering turns the nose at once, the way it always did. What the car is doing
# is the direction it was already going, dragged round after it, and grip is
# how fast that gap closes. Four things are read here, and the car is stepped
# by hand the way steer_trace steps the easing, so none of it is the keyboard
# or the road:
#
#   - the slide a car settles into holding a corner, against what the tuning
#     says it should be, which is the turn rate divided by grip;
#   - the corner it actually holds, which must still be turn_radius_at(): the
#     track planner lays its corners out to those radii, and a car that no
#     longer held them would need every one of them re-measured;
#   - a car given a very high grip, which must drive the line the car drove
#     before any of this existed;
#   - what it costs a dodge between two barrier rows, in the same currency the
#     Barriers section of the README already counts the steering easing in.
#
# What happens in the air needs a ramp to leave, so it is read on a real course
# at the end.

const STEP := 1.0 / 60.0
## A grip high enough to close the whole gap inside one step, which is the car
## as it drove before there was any such thing.
const NO_SLIP := 100000.0
## The shifts a dodge is measured across, in metres, and the speeds it is
## measured at: the tuned car, a chaos-fast car, and a chaos-fast car on a pad.
const SHIFTS := [2.0, 4.0, 8.0]
const DODGE_SPEEDS := [30.0, 51.0, 79.0]
## How close the settled slide has to be to the turn rate over grip, and how
## close the corner it is held through has to be to the one the planner lays
## out, in degrees and in metres. Neither is zero: the steering is still easing
## the last of the way over while the slide is settling, and a corner read off
## one step of a curved path is read to about a centimetre.
const SLIDE_TOLERANCE := 0.3
const CORNER_TOLERANCE := 0.2
## The most slide, in degrees, a car given NO_SLIP may show. A car with none at
## all puts every metre of its speed along its own heading, which is what the
## car did before grip existed.
const NO_SLIP_TOLERANCE := 0.01
## Metres of level road before the ramp, the same run up tilt_trace uses, and
## how far the way a car is flying may wander over a whole flight, in degrees.
## Not zero: the flight is read off the car's own velocity, and gravity is
## pulling on that the whole way down.
const RUN_UP := 24.0
const FLIGHT_TOLERANCE := 0.5


func _init() -> void:
	var car: Car = load("res://scenes/car/car.tscn").instantiate()
	car.frozen = true
	root.add_child(car)
	await process_frame
	var top := car.max_speed
	var radius := car.turn_radius_at(top)
	print("grip %.1f /s, max_drift %.0f deg, top speed %.1f m/s, %.1f m corner"
		% [car.grip, car.max_drift, top, radius])

	var faults := 0
	var held := _hold_a_corner(car, top)
	var wanted := rad_to_deg(top / radius / car.grip)
	print("")
	print("holding full lock at %.1f m/s settles at %.1f degrees of slide, against the %.1f the tuning asks for, and gets there in %.2f s"
		% [top, held.x, wanted, held.z])
	print("the corner it holds settles at %.2f m, against the %.2f m the planner lays out"
		% [held.y, radius])
	if absf(held.x - wanted) > SLIDE_TOLERANCE:
		print("  the settled slide is not the turn rate divided by grip")
		faults += 1
	if absf(held.y - radius) > CORNER_TOLERANCE:
		print("  the corner a car holds is no longer the one the planner lays out")
		faults += 1

	faults += _the_same_car_as_before(car, top)
	faults += _what_a_dodge_costs(car)
	car.queue_free()
	faults += await _off_a_ramp()
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## And the half a car with no floor cannot be asked: what the slide does with
## no road under the car.
##
## A car is run off a ramp with the steering held over the whole way. In the
## air the nose comes round on air_steer and the travel must not follow it a
## degree - the car flies where it was thrown - and once it is down the grip
## has to work the whole of that angle off again.
func _off_a_ramp() -> int:
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
		print("")
		print("  no course in the first 60 had a jump to drive off")
		return 1

	var curve := track.curve()
	var at: float = jump.start_offset - RUN_UP
	car.frozen = true
	car.global_position = track.global_transform * (
		curve.sample_baked(at) + Vector3.UP * (car.wheel_radius + 0.6))
	var ahead: Vector3 = track.global_transform * curve.sample_baked(at + 2.0)
	# Level with itself rather than aimed at the road: look_at pitches whatever
	# it aims, and a car pointed down at the road starts the run leaning.
	car.look_at(Vector3(ahead.x, car.global_position.y, ahead.z), Vector3.UP)
	# Dropped and left to settle on the road under its own weight before the
	# run starts. A car still held for the countdown reads as off the floor,
	# and every step of that would count as flight.
	car.frozen = false
	car.reset_motion()
	for i in 25:
		car._speed = 0.0
		await physics_frame
	car.reset_motion()

	# Straight up the ramp, then full lock the moment the car is off the lip and
	# let go again the moment it is down. What is being read is what the slide
	# does with no road under it, not what a player does with the landing.
	var flight := PackedFloat64Array()
	var nose := PackedFloat64Array()
	var airborne := 0
	var landed := -1
	var settled := -1
	var steering := false
	for i in 400:
		car._speed = car.max_speed
		await physics_frame
		if not car.is_on_floor() and landed < 0:
			airborne += 1
			if not steering:
				Input.action_press(&"p1_steer_left")
				steering = true
			flight.append(atan2(car.velocity.x, car.velocity.z))
			nose.append(car.rotation.y)
		elif airborne > 0:
			if steering:
				Input.action_release(&"p1_steer_left")
				steering = false
			if landed < 0:
				landed = i
			if absf(rad_to_deg(car.drift())) < 1.0:
				settled = i
				break
	if steering:
		Input.action_release(&"p1_steer_left")

	print("")
	if airborne < 10 or landed < 0:
		print("  the car never took the jump, so nothing here was tested")
		return 1
	var wandered := 0.0
	for i in flight.size():
		wandered = maxf(wandered,
			absf(rad_to_deg(angle_difference(flight[0], flight[i]))))
	var turned := absf(rad_to_deg(angle_difference(nose[0], nose[nose.size() - 1])))
	print("over %d steps in the air the nose came round %.1f degrees and the flight wandered %.2f"
		% [airborne, turned, wandered])
	var faults := 0
	if turned < 5.0:
		print("  the nose never came round in the air, so nothing was held")
		faults += 1
	if wandered > FLIGHT_TOLERANCE:
		print("  the car did not fly where it was thrown")
		faults += 1
	if settled < 0:
		print("  the slide the car landed with was never worked off")
		faults += 1
	else:
		print("it landed sliding and was straight again %.2f s later"
			% [float(settled - landed) * STEP])
	return faults


## Hold full lock until the slide stops growing. Returns the slide it settles
## at in degrees, the radius the car's path settles at in metres, and how long
## it took to get there in seconds.
func _hold_a_corner(car: Car, speed: float) -> Vector3:
	_straighten(car)
	var settled := 0.0
	var at := Vector2.ZERO
	var was := 0.0
	var reached := 0.0
	for i in 600:
		var before := _bearing(car)
		at = _drive(car, 1.0, speed, true, at)
		var slide := absf(rad_to_deg(car.drift()))
		# Settled once a whole step moves it less than a hundredth of a degree.
		if reached <= 0.0 and i > 0 and absf(slide - was) < 0.01:
			reached = float(i) * STEP
			settled = slide
			# The path's own turn rate, which is what says what corner the car
			# is going round - not the rate the nose is turning at.
			var turned := absf(angle_difference(before, _bearing(car))) / STEP
			return Vector3(settled, speed / maxf(turned, 0.0001), reached)
		was = slide
	return Vector3(was, 0.0, -1.0)


## A car given a very high grip has to drive the line the car drove before
## grip existed, which is straight along its own heading at every step.
func _the_same_car_as_before(car: Car, speed: float) -> int:
	var tuned := car.grip
	car.grip = NO_SLIP
	_straighten(car)
	var at := Vector2.ZERO
	var worst := 0.0
	var run := 0.0
	for i in 400:
		at = _drive(car, 1.0, speed, true, at)
		run += speed * STEP
		# The old car put every metre of its speed along its own heading, which
		# is this car with nothing left of the gap between the two.
		worst = maxf(worst, absf(rad_to_deg(car.drift())))
	car.grip = tuned
	print("")
	print("at a grip of %.0f the same corner is driven with at most %.4f degrees of slide, over %.0f m"
		% [NO_SLIP, worst, run])
	if worst > NO_SLIP_TOLERANCE:
		print("  a very high grip does not reproduce the car as it drove before")
		return 1
	return 0


## What grip costs a dodge between two rows of barriers: the extra road a car
## needs to shift sideways by a given amount and finish square, over what the
## same car needs with the slide taken out of it.
##
## The dodge is the one the Barriers section counts: full lock one way until
## the nose has come round far enough, then full lock back until it is square
## again. How far round is found by halving, since the shift only grows with it.
func _what_a_dodge_costs(car: Car) -> int:
	var faults := 0
	print("")
	for speed in DODGE_SPEEDS:
		var costs := PackedStringArray()
		for shift in SHIFTS:
			var tuned := _road_for(car, speed as float, shift as float, car.grip)
			var instant := _road_for(car, speed as float, shift as float, NO_SLIP)
			if tuned < 0.0 or instant < 0.0:
				costs.append("%.0f m: not reached" % shift)
				continue
			costs.append("%.0f m shift %.1f m more (%.1f against %.1f)"
				% [shift, tuned - instant, tuned, instant])
			if tuned < instant:
				print("  grip made a dodge shorter, which it cannot")
				faults += 1
		print("at %.0f m/s: %s" % [speed, ", ".join(costs)])
	return faults


## The road a dodge across `shift` metres takes at `speed`, with the car given
## `grip`, or -1 if the car cannot shift that far at that speed at all.
func _road_for(car: Car, speed: float, shift: float, grip: float) -> float:
	var tuned := car.grip
	car.grip = grip
	var low := 0.0
	var high := PI * 0.5
	var road := -1.0
	# The widest swing first: if even that will not shift the car far enough,
	# there is no dodge to measure.
	if _dodge(car, speed, high).y < shift:
		car.grip = tuned
		return -1.0
	for i in 24:
		var middle := (low + high) * 0.5
		var run := _dodge(car, speed, middle)
		if run.y < shift:
			low = middle
		else:
			high = middle
			road = run.x
	car.grip = tuned
	return road


## One dodge: full lock until the car is travelling `swing` radians off the way
## it set out, then full lock back until it is travelling square again.
## Returns the road it took along the way it started out, and how far sideways
## it ended up.
##
## Travelling rather than pointing, at both ends. What a row of barriers asks
## for is a car across in the next lane and going straight down it, and a car
## still sliding is not there yet however square its nose is. For a car with no
## slide at all the two are the same thing, so the comparison is still like for
## like.
func _dodge(car: Car, speed: float, swing: float) -> Vector2:
	_straighten(car)
	var at := Vector2.ZERO
	var start := _bearing(car)
	var out := true
	for i in 3000:
		var turned := angle_difference(start, _bearing(car))
		if out and turned >= swing:
			out = false
		elif not out and turned <= 0.0:
			break
		at = _drive(car, 1.0 if out else -1.0, speed, true, at)
	# The road is along the way the car set off, the sideways shift across it.
	var ahead := Vector2(sin(start), cos(start))
	return Vector2(at.dot(-ahead), absf(at.dot(Vector2(-ahead.y, ahead.x))))


## Square the car up: straight ahead, travelling where it points, facing north.
func _straighten(car: Car) -> void:
	car.rotation.y = 0.0
	car._steer = 0.0
	car._drift = 0.0


## The way the car is actually travelling, as a yaw in radians.
func _bearing(car: Car) -> float:
	return car.rotation.y + car.drift()


## One step of the car's own steering, grip and travel, moving `at` along the
## way the car is going. The car does the sums; this only holds the clock.
func _drive(car: Car, wanted: float, speed: float, grounded: bool,
		at: Vector2) -> Vector2:
	car._speed = speed
	car._ease_steering(wanted, STEP)
	car._apply_steering(car._steer * (1.0 if grounded else car.air_steer), STEP)
	car._slide(car.grip if grounded else 0.0, STEP)
	var travel := (-car.global_transform.basis.z).rotated(Vector3.UP, car.drift())
	return at + Vector2(travel.x, travel.z) * speed * STEP
