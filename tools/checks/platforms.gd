extends SceneTree

# Fly a car at floating platforms and moving rings, with the clock set so they
# are there when it arrives and so they are not.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/platforms.gd
#
# A platform is only a mechanic if its timing is the thing that decides it. So
# the same car, off the same run up, at the same speed, is sent at the same
# platform twice: once with the race clock set so the platform is under the car
# when it comes down, and once so it is off to the side. The first has to land
# on it, ride it and drop onto the landing; the second has to fall in. The same
# again for a ring that moves.
#
# And the two things a platform must not do: be out of reach of a car taking
# the ramp at an ordinary speed, or catch a car that took a boost into it, which
# the platform is placed to fly over on purpose.

const COURSE := "res://tools/checks/platform_course.gd"
const RUN_UP := 60.0


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	settings.damage = false
	settings.track_file = COURSE
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	await process_frame
	solo.set("_countdown_run", int(solo.get("_countdown_run")) + 1)
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	var faults := 0

	var jumps: Array[TrackLayout.Piece] = []
	for piece in track.layout().pieces:
		if piece.kind == TrackLayout.JUMP:
			jumps.append(piece)
	var platforms := track.features().of_kind(TrackFeatures.PLATFORM)
	var ring: TrackFeatures.Placement = track.features().of_kind(TrackFeatures.RING)[0]
	print(track.features().summary())
	for problem in track.features().faults(track.layout()):
		print("  the test course: %s" % problem)
		faults += 1

	# The platform that stands still, at the speeds a car takes a ramp at.
	var tuned := car.max_speed
	var arrival := 0.0
	for fraction: float in [0.8, 1.0, 1.2]:
		car.max_speed = tuned * fraction
		var run: Dictionary = await _drive(solo, track, car, jumps[0], 0.0, 0.0, -1)
		print("  still platform, %4.1f m/s: came down on the %s, ended on the %s"
			% [car.max_speed, run["landed"], run["ended"]])
		if run["landed"] != "platform" or run["ended"] != "road":
			print("    a car taking the ramp at %.0f m/s did not make it across the platform" % car.max_speed)
			faults += 1
		if fraction == 1.0:
			arrival = run["down_at"]
	car.max_speed = tuned * 1.55
	var boosted: Dictionary = await _drive(solo, track, car, jumps[0], 0.0, 0.0, -1)
	print("  still platform, on a boost: came down on the %s" % boosted["landed"])
	if boosted["landed"] == "platform":
		print("    a boosted car landed on the platform it is meant to overfly")
		faults += 1
	car.max_speed = tuned

	# The moving one, timed both ways. It holds the middle from 0 to 1.5 s and
	# the right from 2.7 to 4.2 s, so a car that comes down 0.75 s into the cycle
	# meets it and one that comes down at 3.45 s does not.
	var cycle := (platforms[1].dwell + platforms[1].travel) * 2.0
	var timed: Dictionary = await _drive(solo, track, car, jumps[1], 0.0,
		fposmod(0.75 - arrival, cycle), -1)
	var late: Dictionary = await _drive(solo, track, car, jumps[1], 0.0,
		fposmod(3.45 - arrival, cycle), -1)
	print("  moving platform, timed: came down on the %s, ended on the %s" % [timed["landed"], timed["ended"]])
	print("  moving platform, mistimed: came down on the %s" % late["landed"])
	if timed["landed"] != "platform" or timed["ended"] != "road":
		print("    a car that timed the moving platform did not make it across")
		faults += 1
	if late["landed"] == "platform" or late["ended"] == "road":
		print("    a car that mistimed the moving platform got across anyway")
		faults += 1

	# The moving ring, timed both ways, the same way round.
	var probe: Dictionary = await _drive(solo, track, car, jumps[2], 0.0, 0.0, 0)
	var ring_cycle := (ring.dwell + ring.travel) * 2.0
	var through: Dictionary = await _drive(solo, track, car, jumps[2], 0.0,
		fposmod(0.75 - probe["ring_at"], ring_cycle), 0)
	var missed: Dictionary = await _drive(solo, track, car, jumps[2], 0.0,
		fposmod(3.45 - probe["ring_at"], ring_cycle), 0)
	print("  moving ring, timed: %s; mistimed: %s"
		% ["banked" if through["banked"] else "not banked", "banked" if missed["banked"] else "not banked"])
	if not through["banked"]:
		print("    a car that timed the moving ring did not bank it")
		faults += 1
	if missed["banked"]:
		print("    a car that mistimed the moving ring banked it")
		faults += 1

	# A platform off the road, and one too narrow to land on, are caught.
	var wide := TrackFeatures.Placement.new(TrackFeatures.PLATFORM, 100.0, 30.0)
	wide.phases = PackedFloat32Array([-1.1, 1.1])
	wide.half_span = 0.3
	wide.travel = 1.0
	var plan := TrackFeatures.adopt([wide] as Array[TrackFeatures.Placement])
	var found := plan.faults(track.layout())
	print("a platform sliding past both kerbs: %s" % ("; ".join(found) if not found.is_empty() else "passed"))
	if found.is_empty():
		faults += 1

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Put the car on the run up to `jump`, `lane` across, with the race clock at
## `clock`, and send it flat out. Says what it first came down on past the lip,
## when that was, what it ended on, when it crossed ring `ring`, and whether
## that ring was banked.
func _drive(solo: Node, track: Track, car: Car, jump: TrackLayout.Piece,
		lane: float, clock: float, ring: int) -> Dictionary:
	solo.set("_running", false)
	solo.call("_place_on_the_line")
	var at := jump.start_offset - RUN_UP
	var here := track.centre_at(at)
	var ahead := track.centre_at(at + 2.0)
	var right := (ahead - here).cross(Vector3.UP).normalized()
	car.frozen = true
	car.global_position = here + right * (lane * track.half_width_at(at)) + Vector3.UP * (car.wheel_radius + 0.6)
	car.look_at(car.global_position + (ahead - here) * Vector3(1, 0, 1), Vector3.UP)
	car.frozen = false
	car.reset_motion()
	car.reset_physics_interpolation()
	track.set_race_time(clock)
	for i in 25:
		car._speed = 0.0
		await physics_frame
	car.reset_motion()
	solo.set("_time", clock)
	solo.set("_was", car.middle())
	solo.set("_running", true)

	var lip := jump.start_offset + track.ramp_length
	var ring_offset := jump.start_offset + track.ramp_length + track.jump_gap * 0.5
	var result := {"landed": "nothing", "down_at": 0.0, "ended": "nothing",
		"ring_at": 0.0, "banked": false}
	var airborne := 0
	for i in 60 * 6:
		car._speed = car.max_speed
		await physics_frame
		var offset := track.offset_of(car.global_position)
		var now: float = solo.get("_time")
		if result["ring_at"] == 0.0 and offset >= ring_offset:
			result["ring_at"] = now - clock
		if not car.is_on_floor():
			airborne += 1
		elif airborne > 10 and offset > lip and result["landed"] == "nothing":
			result["landed"] = _under(solo, car)
			result["down_at"] = now - clock
		else:
			airborne = 0 if car.is_on_floor() else airborne
		if car.is_on_floor() and airborne == 0 and offset > jump.end_offset - 30.0:
			break
		if car.global_position.y < -2.0:
			break
	solo.set("_running", false)
	result["ended"] = _under(solo, car)
	if ring >= 0:
		var banked: PackedByteArray = solo.get("_banked")
		result["banked"] = banked[ring] == 1
	return result


func _under(solo: Node, car: Car) -> String:
	var space: PhysicsDirectSpaceState3D = solo.get_world_3d().direct_space_state
	var from := car.global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0)
	query.exclude = [car.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return "nothing"
	var collider: Node = hit["collider"]
	# By what it is rather than what it is called: two platforms under one
	# parent cannot both be called Platform.
	if collider is AnimatableBody3D and collider.is_in_group(Car.ROAD_GROUP):
		return "platform"
	return "road" if collider.name == "RoadBody" else "grass"
