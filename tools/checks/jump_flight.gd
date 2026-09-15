extends SceneTree

# Drive a car off a real ramp and see where it comes down.
#   Godot --path . --headless --script tools/checks/jump_flight.gd
#
# The question a jump has to answer is not how far a car flies but how slowly
# it can be taken and still be cleared. Falling in costs a respawn, so a gap
# that cannot be crossed at the slowest speed the game can roll is not a risk,
# it is a wall. Chaos rolls speed down to 0.78 of tuned and gravity up to 1.4
# of it, and both at once, so that is the corner this has to hold at.

const SPEEDS := {
	"chaos slowest": 0.78,
	"tuned": 1.0,
	"with a boost": 1.55,
	"chaos fastest": 1.7,
}
const GRAVITIES := {"light": 0.65, "tuned": 1.0, "heavy": 1.4}
## Metres of level run up the car is let go on before the ramp. The planner
## never lays a jump after less than 45.
const RUN_UP := 30.0
## Frames off the ground that are the car skipping over the join at the foot
## of the ramp rather than flying.
const SKIP := 5


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
	var tuned_speed := car.max_speed
	var tuned_gravity := car.gravity

	var tuned_gap: float = track.jump_gap
	print("tuned hole %.1f m, ramp %.0f m rising %.1f m, landing %.0f m"
		% [tuned_gap, track.ramp_length, track.ramp_rise, track.landing_length])
	print("")

	var faults := 0
	var shortest := INF
	var longest := 0.0
	var roof := 0.0
	for gravity in GRAVITIES:
		for speed in SPEEDS:
			car.max_speed = tuned_speed * SPEEDS[speed]
			car.gravity = tuned_gravity * GRAVITIES[gravity]
			# The hole this roll would actually be given. Chaos shortens it
			# for a world of slow or heavy cars, so testing every roll against
			# the tuned hole would be testing a course the game never builds.
			# A boost is not a roll - it is something a player picks up inside
			# one - so it does not shorten anything.
			var roll: float = minf(SPEEDS[speed], 1.7)
			track.jump_gap = tuned_gap * Chaos.jump_gap_scale(
				roll if speed != "with a boost" else 1.0, GRAVITIES[gravity])
			var course := _a_course_with_a_jump(track)
			if course < 0:
				print("  no course in the first 60 had a jump on it")
				faults += 1
				continue
			var jump := _the_jump(track)
			var hole := _measure_the_hole(track, jump)

			var flight: Array = await _fly(main, track, car, jump)
			var flown: float = flight[0]
			var landed_on: String = flight[1]
			var flew: bool = flight[2]
			shortest = minf(shortest, flown - hole)
			longest = maxf(longest, flown)
			roof = maxf(roof, hole + track.landing_length)
			var wrong := ""
			if not flew:
				wrong = "   NEVER LEFT THE GROUND"
			elif landed_on != "road":
				wrong = "   FELL IN"
			print("  %-14s %-14s %5.1f m/s over a %4.1f m hole, flew %5.1f m, down on the %s%s"
				% [gravity + " gravity", speed, car.max_speed, hole, flown,
					landed_on, wrong])
			if wrong != "":
				faults += 1
	track.jump_gap = tuned_gap
	var jump := _the_jump(track) if _a_course_with_a_jump(track) >= 0 else null
	var hole := _measure_the_hole(track, jump) if jump != null else tuned_gap

	# The two ends the landing has to cover. A car that comes up short falls
	# in; one that outflies the landing comes down on whatever the course does
	# next, which on the far side of a jump is a corner.
	print("")
	print("the tightest roll cleared its own hole by %.1f m" % shortest)
	print("longest flight %.1f m against %.1f m of road to come down on"
		% [longest, roof])
	if longest > roof:
		print("  a car flat out flies past the end of the landing")
		faults += 1

	# And the other way round. A jump every car clears whatever it does is
	# scenery, not a risk: carrying speed into one has to be the thing that
	# gets a car over it.
	car.gravity = tuned_gravity
	car.max_speed = tuned_speed * 0.35
	var crawl: Array = await _fly(main, track, car, jump)
	print("crawling at %5.1f m/s: %s, ended up on the %s"
		% [car.max_speed,
			"flew %.1f m" % crawl[0] if crawl[2] else "never left the ground",
			crawl[1]])
	if crawl[1] == "road":
		print("  a car crawling at a jump gets across it anyway")
		faults += 1
	print("%d faults" % faults)
	car.max_speed = tuned_speed
	car.gravity = tuned_gravity
	quit(1 if faults > 0 else 0)


## Put the car on the run up flat out, let it take the ramp, and report how
## far it flew and what it came down on.
##
## What it landed on is the whole question, and it is asked of the world
## rather than of the course: a car that cleared the hole has road under it
## and one that came up short has grass. Offsets along the curve are no use
## here - the curve climbs the ramp and crosses the hole in mid air, so the
## nearest point on it to a car lying in the hole is somewhere up the ramp.
func _fly(main: Node, track: Track, car: Car, jump: TrackLayout.Piece) -> Array:
	var curve := track.curve()
	var at: float = jump.start_offset - RUN_UP
	var here: Vector3 = curve.sample_baked(at)
	var ahead: Vector3 = track.global_transform * curve.sample_baked(at + 2.0)

	# Let down onto the run up at a standstill and left to settle before the
	# run starts, the way tilt_trace does it. A car let go flat out while it
	# is still falling reaches the ramp in the air on a fast roll, and a car
	# that meets a ramp in the air can catch its nose on it and stop dead.
	# That is a real hazard, but it is not one a player driving up a level
	# straight meets - arriving on the ground, no speed from 20 to 80 m/s does
	# it - and it is not what this is measuring.
	#
	# Put where it is going first and only then cleared: the car works out the
	# climb it is carrying from the height it was at last step, so clearing it
	# before the teleport hands the run the drop from wherever the last one
	# finished. Aimed level with itself, for the reason tilt_trace gives.
	car.frozen = true
	car.global_position = track.global_transform * (
		here + Vector3.UP * (car.wheel_radius + 0.6))
	car.look_at(Vector3(ahead.x, car.global_position.y, ahead.z), Vector3.UP)
	car.frozen = false
	car.reset_motion()
	for i in 25:
		car._speed = 0.0
		await physics_frame
	car.reset_motion()

	# On the ground, then airborne, then down. It can skip for a frame or two
	# over the join at the foot of the ramp; that is not the jump, which is the
	# first time it is off the ground for longer. The run stops the moment that
	# comes down, before the car can drive on into whatever the course does
	# next and fly off that instead.
	var airborne := 0
	var took_off := Vector3.ZERO
	for i in 600:
		# Held at the ceiling: nothing here is testing the engine, and a car
		# coasting up the ramp would be measuring a different speed each run.
		car._speed = car.max_speed
		await physics_frame
		if not car.is_on_floor():
			if airborne == 0:
				took_off = car.global_position
			airborne += 1
		elif airborne > SKIP:
			var landed := car.global_position
			var flown := Vector2(landed.x - took_off.x, landed.z - took_off.z).length()
			return [flown, _what_is_under(main, car, landed), true]
		else:
			airborne = 0
	if airborne > SKIP:
		# Still in the air when time ran out: a car that went off the edge of
		# the world rather than one that came down anywhere.
		return [0.0, "nothing at all", true]
	# It never left the ground. Where it ended up still matters: a car that
	# crept across the hole without flying is a different failure from one
	# that stopped dead on the ramp.
	return [0.0, _what_is_under(main, car, car.global_position), false]


## What a car is standing on, by name rather than by offset.
func _what_is_under(main: Node, car: Car, at: Vector3) -> String:
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 0.5, at + Vector3.DOWN * 4.0)
	query.exclude = [car.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return "nothing at all"
	return "road" if String(hit["collider"].name) == "RoadBody" else "grass"


## How much road is actually missing, from the cross-sections themselves.
func _measure_the_hole(track: Track, jump: TrackLayout.Piece) -> float:
	var layout := track.layout()
	var missing := 0
	var first := int(jump.start_offset / layout.step)
	var last := int(jump.end_offset / layout.step)
	for i in range(first, mini(last, layout.road_present.size())):
		if layout.road_present[i] == 0:
			missing += 1
	# One more than the samples missing: the hole runs from the last sample
	# with road to the next one that has it.
	return float(missing + 1) * layout.step


func _a_course_with_a_jump(track: Track) -> int:
	for course in range(1, 60):
		track.generate(course * 977)
		if _the_jump(track) != null:
			return course
	return -1


func _the_jump(track: Track) -> TrackLayout.Piece:
	for piece in track.layout().pieces:
		if piece.kind == TrackLayout.JUMP:
			return piece
	return null
