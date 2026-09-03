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

	var course := _a_course_with_a_jump(track)
	if course < 0:
		print("  no course in the first 60 had a jump on it")
		quit(1)
		return
	var jump := _the_jump(track)
	var lip: float = jump.start_offset + track.layout().ramp_length
	# Measured off the road itself rather than taken from the tunable: what a
	# car has to clear is the missing cross-sections, and those land on the
	# sampling grid whatever the number says.
	var hole := _measure_the_hole(track, jump)
	print("course %d: ramp %.0f-%.0f m rising %.1f m, %.1f m of hole, landing to %.0f m"
		% [course, jump.start_offset, lip, track.layout().ramp_rise,
			hole, jump.end_offset])

	var faults := 0
	var shortest := INF
	var longest := 0.0
	for gravity in GRAVITIES:
		for speed in SPEEDS:
			car.max_speed = tuned_speed * SPEEDS[speed]
			car.gravity = tuned_gravity * GRAVITIES[gravity]
			var flight: Array = await _fly(main, track, car, jump)
			var flown: float = flight[0]
			var landed_on: String = flight[1]
			var flew: bool = flight[2]
			shortest = minf(shortest, flown)
			longest = maxf(longest, flown)
			var wrong := ""
			if not flew:
				wrong = "   NEVER LEFT THE GROUND"
			elif landed_on != "road":
				wrong = "   FELL IN"
			print("  %-14s %-14s off at %5.1f m/s, flew %5.1f m, down on the %s%s"
				% [gravity + " gravity", speed, car.max_speed, flown, landed_on,
					wrong])
			if wrong != "":
				faults += 1

	# The two ends the landing has to cover. A car that comes up short falls
	# in; one that outflies the landing comes down on whatever the course does
	# next, which on the far side of a jump is a corner.
	var landing: float = hole + track.layout().landing_length
	print("shortest flight %.1f m against a %.1f m hole"
		% [shortest, hole])
	print("longest flight %.1f m against %.1f m of road to come down on"
		% [longest, landing])
	if longest > landing:
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
	var at: float = jump.start_offset - 18.0
	var here: Vector3 = curve.sample_baked(at)
	var ahead: Vector3 = curve.sample_baked(at + 2.0)

	# Put it where it is going first and only then clear its motion: the car
	# works out the climb it is carrying from the height it was at last step,
	# so clearing that before the teleport hands the next run the drop from
	# wherever the last one finished.
	# Parked, dropped onto the road and left to settle before the run starts.
	# Without that the car begins each run carrying whatever the last one left
	# it doing, and a run that starts half in the air measures that rather
	# than the jump.
	car.frozen = true
	car.global_position = track.global_transform * (
		here + Vector3.UP * (car.wheel_radius + 0.6))
	car.look_at(track.global_transform * ahead, Vector3.UP)
	car.reset_motion()
	for i in 12:
		await physics_frame
	car.frozen = false
	car.reset_motion()
	car._speed = car.max_speed

	# Settled, then airborne, then down. The car is dropped onto the road
	# rather than placed exactly on it, so it is off the ground for the first
	# frame or two, and it can skip once over the join at the foot of the
	# ramp; neither of those is the jump.
	# Settled, then airborne, then down. The car is dropped onto the road
	# rather than placed exactly on it, so it is off the ground for the first
	# frame or two, and it can skip once over the join at the foot of the
	# ramp. The longest time it spent in the air is the jump; the rest is
	# noise, and no time in the air at all is worth saying out loud.
	var settled := false
	var airborne := 0
	var from := Vector3.ZERO
	var best := 0
	var took_off := Vector3.ZERO
	var landed := Vector3.ZERO
	for i in 300:
		# Held at the ceiling: nothing here is testing the engine, and a car
		# coasting up the ramp would be measuring a different speed each run.
		car._speed = car.max_speed
		await physics_frame
		if car.is_on_floor():
			settled = true
			if airborne > best:
				best = airborne
				took_off = from
				landed = car.global_position
			airborne = 0
		elif settled:
			if airborne == 0:
				from = car.global_position
			airborne += 1
	if best == 0:
		# It never left the ground. Where it ended up still matters: a car
		# that crept across the hole without flying is a different failure
		# from one that stopped dead on the ramp.
		return [0.0, _what_is_under(main, car, car.global_position), false]

	var flown := Vector2(landed.x - took_off.x, landed.z - took_off.z).length()
	return [flown, _what_is_under(main, car, landed), true]


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
