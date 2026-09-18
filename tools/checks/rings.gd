extends SceneTree

# Fly a car through rings, past them and under them, and see which count.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/rings.gd
#
# A ring is a checkpoint a car banks by going through it, so there are two ways
# for one to be wrong and both are quiet. A ring nobody can fly through is a
# track nobody can finish, and it looks exactly like a player who keeps
# missing. A ring that banks for a car that went round it, under it or
# backwards through it is a checkpoint that asks nothing. So a real car is
# driven at real rings, at the speeds the game can roll, and made to miss them
# on purpose as well as hit them.

const COURSE := "res://tools/checks/ring_course.gd"
## The speeds a ring over a jump has to catch, as fractions of tuned top speed:
## the slowest chaos rolls, tuned, a boost, and the fastest chaos rolls.
const SPEEDS := [0.78, 1.0, 1.55, 1.7]
## Metres of level run up the car is let go on before a ramp.
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
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	# The countdown is called off rather than waited out: this drives the car
	# itself, from wherever it puts it.
	solo.set("_countdown_run", int(solo.get("_countdown_run")) + 1)
	var faults := 0

	var marks := track.checkpoint_offsets()
	print("%d rings at %s m, painted checkpoints: %s" % [
		marks.size(), ", ".join(Array(marks).map(func(m: float) -> String: return "%.0f" % m)),
		"none" if (track.get_node("Checkpoints") as MeshInstance3D).mesh == null else "SOME"])
	if not track.has_rings() or marks.size() != 3:
		print("  the course did not come out with its three rings as checkpoints")
		faults += 1
	if (track.get_node("Checkpoints") as MeshInstance3D).mesh != null:
		print("  a track with rings still has checkpoints painted on the road")
		faults += 1

	var jumps: Array[TrackLayout.Piece] = []
	for piece in track.layout().pieces:
		if piece.kind == TrackLayout.JUMP:
			jumps.append(piece)

	# Through the middle one, at every speed.
	var tuned := car.max_speed
	for fraction: float in SPEEDS:
		car.max_speed = tuned * fraction
		var run: Array = await _drive(solo, track, car, jumps[0].start_offset - RUN_UP, 0.0, 0)
		print("  lined up, %4.1f m/s: %s" % [car.max_speed, _say(run)])
		if not run[0] or run[1] != "road":
			print("    a car lined up with the ring at %.0f m/s did not fly through it" % car.max_speed)
			faults += 1
	car.max_speed = tuned

	# Well off to the side of it: over the jump, but nowhere near the hole.
	var wide: Array = await _drive(solo, track, car, jumps[0].start_offset - RUN_UP, -0.7, 0)
	print("  off to the left: %s" % _say(wide))
	if wide[0]:
		print("    a car that went past the ring banked it")
		faults += 1

	# Clipping the rim: not lined up, not far enough off to miss it.
	var clip: Array = await _drive(solo, track, car, jumps[0].start_offset - RUN_UP, 0.42, 0)
	print("  into the rim: %s" % _say(clip))
	if clip[0]:
		print("    a car that hit the rim banked the ring")
		faults += 1

	# Under the ring standing over level road.
	var under: Array = await _drive(solo, track, car, marks[1] - RUN_UP, 0.0, 1)
	print("  under the one over the road: %s" % _say(under))
	if under[0]:
		print("    a car that drove underneath a ring banked it")
		faults += 1

	# Lined up with the one off to the side.
	var side: Array = await _drive(solo, track, car, jumps[1].start_offset - RUN_UP, 0.6, 2)
	print("  lined up with the one at lane 0.6: %s" % _say(side))
	if not side[0]:
		print("    a car lined up with a ring off the middle did not bank it")
		faults += 1

	# The rule itself, without a car: forwards through the middle counts, and
	# backwards, from outside the hole, or by being put there does not.
	var ring: Node3D = track.get_node("Furniture").rings()[0]
	var middle := ring.global_position
	var ahead := ring.global_basis.y.normalized()
	var up := Vector3.UP
	var cases := [
		["forwards through the middle", middle - ahead * 0.4, middle + ahead * 0.4, true],
		["backwards through the middle", middle + ahead * 0.4, middle - ahead * 0.4, false],
		["forwards, outside the hole", middle - ahead * 0.4 + up * 3.8, middle + ahead * 0.4 + up * 3.8, false],
		["put from one side to the other", middle - ahead * 10.0, middle + ahead * 10.0, false],
	]
	for case in cases:
		var got := track.through_ring(0, case[1], case[2])
		if got != case[3]:
			print("  %s %s, and should %s" % [case[0], "counted" if got else "did not count",
				"have" if case[3] else "not have"])
			faults += 1
	print("the rule: forwards through the hole counts, nothing else does")

	# Where a car that banked the ring over a jump is put back: on road.
	var back := track.respawn_offset(0)
	var ground := _what_is_under(solo, car, track.centre_at(back) + Vector3.UP * 0.5)
	print("banking the first ring puts a reset at %.0f m, on the %s" % [back, ground])
	if ground != "road":
		print("  a reset after the ring over a jump does not land on the road")
		faults += 1

	# And the checks that do not need a car: a ring with its rim in the road.
	var buried := TrackFeatures.Placement.new(TrackFeatures.RING, 50.0, 0.7)
	buried.height = 2.0
	buried.radius = 3.5
	var plan := TrackFeatures.adopt([buried] as Array[TrackFeatures.Placement])
	var found := plan.faults(track.layout())
	print("a ring 2 m up with a 3.5 m hole: %s" % ("; ".join(found) if not found.is_empty() else "passed"))
	if found.is_empty():
		print("  a ring with its rim in the road was not caught")
		faults += 1
	for problem in track.features().faults(track.layout()):
		print("  the test course: %s" % problem)
		faults += 1

	# The two-player race banks rings too, each car its own, and leaves them lit.
	solo.queue_free()
	await process_frame
	var race: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(race)
	await process_frame
	race.set("_countdown_run", int(race.get("_countdown_run")) + 1)
	var race_track: Track = race.get_node("Track")
	var car1: Car = race.get_node("Car1")
	race.get_node("Car2").frozen = true
	var grid_at: float = race_track.checkpoint_offsets()[0] - 24.0 - RUN_UP
	var there := race_track.centre_at(grid_at)
	var onward := race_track.centre_at(grid_at + 2.0)
	car1.frozen = true
	car1.global_position = there + Vector3.UP * (car1.wheel_radius + 0.6)
	car1.look_at(car1.global_position + (onward - there) * Vector3(1, 0, 1), Vector3.UP)
	car1.frozen = false
	car1.reset_motion()
	for i in 25:
		car1._speed = 0.0
		await physics_frame
	car1.reset_motion()
	var was: PackedVector3Array = race.get("_was")
	was[0] = car1.middle()
	race.set("_was", was)
	race.set("_racing", true)
	for i in 300:
		car1._speed = car1.max_speed
		await physics_frame
	race.set("_racing", false)
	var both: Array = race.get("_banked")
	var rim := race_track.get_node("Furniture").rings()[0].get_node("Rim") as MeshInstance3D
	print("two players: car 1 banked %s, car 2 banked %s, the ring is %s"
		% [both[0][0] == 1, both[1][0] == 1,
			"still lit" if rim.material_override.emission_enabled else "out"])
	if both[0][0] != 1 or both[1][0] != 0:
		print("  in a two-player race the ring was not banked for the car that went through it alone")
		faults += 1
	if not rim.material_override.emission_enabled:
		print("  a two-player race put a ring out, which tells the other player about it")
		faults += 1

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Put the car on the road `lane` across it, let it settle, run it flat out
## straight ahead, and say whether ring `mark` was banked and what the car
## ended up on.
func _drive(solo: Node, track: Track, car: Car, at: float, lane: float, mark: int) -> Array:
	solo.set("_running", false)
	solo.call("_place_on_the_line")
	var here := track.centre_at(at)
	var ahead := track.centre_at(at + 2.0)
	var right := (ahead - here).cross(Vector3.UP).normalized()
	var start := here + right * (lane * track.half_width_at(at))
	car.frozen = true
	car.global_position = start + Vector3.UP * (car.wheel_radius + 0.6)
	car.look_at(car.global_position + (ahead - here) * Vector3(1, 0, 1), Vector3.UP)
	car.frozen = false
	car.reset_motion()
	for i in 25:
		car._speed = 0.0
		await physics_frame
	car.reset_motion()
	solo.set("_was", car.middle())
	solo.set("_running", true)
	# Long enough to be well past the ring and down again.
	var steps := int((RUN_UP + 60.0) / maxf(car.max_speed, 1.0) * 60.0) + 90
	for i in steps:
		car._speed = car.max_speed
		await physics_frame
	solo.set("_running", false)
	var banked: PackedByteArray = solo.get("_banked")
	return [banked[mark] == 1, _what_is_under(solo, car, car.global_position + Vector3.UP * 0.5)]


func _say(run: Array) -> String:
	return "%s, ended on the %s" % ["banked" if run[0] else "not banked", run[1]]


func _what_is_under(solo: Node, car: Car, at: Vector3) -> String:
	var space: PhysicsDirectSpaceState3D = solo.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 12.0)
	query.exclude = [car.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return "nothing at all"
	return "road" if String(hit["collider"].name) == "RoadBody" else "grass"
