extends SceneTree

# Take the high road, and don't, and see where the car ends up.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/high_road.gd
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/high_road.gd -- res://tracks/acrobatic/a06_high_road_low_road.gd
#
# Given a track, it drives that track's high roads instead: straight off each
# kicker at tuned speed, from every quarter second of the cycle of whatever
# moves on the high road, and each has to be crossed from at least one of them.
#
# A split is two promises. A car that takes the kicker at an ordinary speed and
# drives straight gets onto the high road, across everything on it, and back
# down onto the course past where the low road comes back - on the course, not
# on the grass beside it. And a car that stays out of the kicker's lane goes
# the long way round without the kicker in its way. The first is driven here at
# three speeds; the second is a car in the middle lane, and the test course
# lapped by acrobatic_drive.gd, which never takes a kicker.

const COURSE := "res://tools/checks/high_road_course.gd"
const RUN_UP := 60.0


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	settings.damage = false
	var args := OS.get_cmdline_user_args()
	settings.track_file = args[0] if not args.is_empty() else COURSE
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	await process_frame
	solo.set("_countdown_run", int(solo.get("_countdown_run")) + 1)
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	var faults := 0
	for problem in track.branch_problems():
		print("  the test course: %s" % problem)
		faults += 1
	if track.branches().is_empty():
		print("  the test course has no high road")
		quit(1)
		return
	if not args.is_empty():
		faults += await _sweep_the_high_roads(solo, track, car)
		print("%d faults" % faults)
		quit(1 if faults > 0 else 0)
		return
	var branch: BranchDefinition = track.definition().branches[0]
	var kicker := branch.lip_offset - track.ramp_length
	var past := branch.rejoin_offset + 40.0

	var tuned := car.max_speed
	for fraction: float in [0.85, 1.0, 1.2]:
		car.max_speed = tuned * fraction
		var run: Dictionary = await _drive(solo, track, car, kicker - RUN_UP, branch.lane, past)
		print("  high road, %4.1f m/s: highest %.1f m, ended on %s, %.1f s from the kicker to %.0f m past the rejoin"
			% [car.max_speed, run["highest"], run["ended"], run["seconds"], past - branch.rejoin_offset])
		if run["ended"] != "the course" or run["highest"] < 9.0:
			print("    did not go over the high road and back onto the course")
			faults += 1
	car.max_speed = tuned

	var low: Dictionary = await _drive(solo, track, car, kicker - RUN_UP, 0.0, kicker + 40.0)
	print("  the middle lane past the kicker: highest %.1f m, ended on %s" % [low["highest"], low["ended"]])
	if low["highest"] > 1.5 or low["ended"] != "the course":
		print("    a car in the middle lane was thrown by the kicker")
		faults += 1

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Every high road on the track, from every quarter second of the cycle of the
## platform or lift on it. Each has to be crossed from one of them at least.
func _sweep_the_high_roads(solo: Node, track: Track, car: Car) -> int:
	var faults := 0
	for index in track.branches().size():
		var branch: BranchDefinition = track.definition().branches[index]
		var road: Track = track.branches()[index]
		var cycle := 4.0
		for moving in road.features().of_kind(TrackFeatures.PLATFORM):
			cycle = maxf(cycle, (moving.dwell + moving.travel) * 2.0)
		var kicker := branch.lip_offset - track.ramp_length
		var made := PackedStringArray()
		var tries := 0
		var clock := 0.0
		while clock < cycle - 0.01:
			solo.set("_running", false)
			track.set_race_time(clock)
			var run: Dictionary = await _drive(solo, track, car, kicker - RUN_UP, branch.lane,
				branch.rejoin_offset + 40.0, clock)
			tries += 1
			if run["ended"] == "the course" and run["highest"] > 9.0:
				made.append("%.2f" % clock)
			clock += 0.25
		print("the high road at %.0f m (%.0f m long, %s): crossed from %d of %d starts%s"
			% [branch.lip_offset, road.length(), road.features().summary(), made.size(), tries,
				(" (at %s s)" % ", ".join(made)) if not made.is_empty() else ""])
		if made.is_empty():
			print("  nobody gets across this high road")
			faults += 1
	return faults


## From `at` along the course, `lane` across it, straight ahead flat out until the
## car is on the ground past `until` along the course or has fallen.
func _drive(solo: Node, track: Track, car: Car, at: float, lane: float, until: float,
		clock := 0.0) -> Dictionary:
	solo.set("_running", false)
	solo.call("_place_on_the_line")
	var here := track.centre_at(at)
	var ahead := track.centre_at(at + 2.0)
	var right := ((ahead - here) * Vector3(1, 0, 1)).normalized().cross(Vector3.UP)
	car.frozen = true
	car.global_position = here + right * (lane * track.half_width_at(at)) + Vector3.UP * (car.wheel_radius + 0.6)
	car.look_at(car.global_position + (ahead - here) * Vector3(1, 0, 1), Vector3.UP)
	car.frozen = false
	car.reset_motion()
	car.reset_physics_interpolation()
	for i in 25:
		car._speed = 0.0
		await physics_frame
	car.reset_motion()
	solo.set("_time", clock)
	solo.set("_was", car.middle())
	solo.set("_running", true)
	var highest := 0.0
	var start_seconds := -1.0
	var seconds := 0.0
	var kicker_start := at + RUN_UP
	for i in 60 * 20:
		car._speed = car.max_speed
		await physics_frame
		highest = maxf(highest, car.global_position.y)
		var offset := track.offset_of(car.global_position)
		if start_seconds < 0.0 and (car.global_position - track.centre_at(kicker_start)).length() < 3.0 + absf(lane) * track.half_width_at(kicker_start):
			start_seconds = float(solo.get("_time"))
		if car.global_position.y < -2.0 or (car.is_on_floor() and _under(solo, track, car) == "the grass"):
			break
		if car.is_on_floor() and car.global_position.y < 1.0 and offset > until and highest > 1.5:
			break
		if car.is_on_floor() and offset > until and lane == 0.0:
			break
	seconds = float(solo.get("_time")) - maxf(start_seconds, clock)
	solo.set("_running", false)
	return {"highest": highest, "ended": _under(solo, track, car), "seconds": seconds}


func _under(solo: Node, track: Track, car: Car) -> String:
	var space: PhysicsDirectSpaceState3D = solo.get_world_3d().direct_space_state
	var from := car.global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0)
	query.exclude = [car.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return "nothing"
	var collider: Node = hit["collider"]
	if collider.get_parent() == track and collider.name == "RoadBody":
		return "the course"
	if collider.is_in_group(Car.ROAD_GROUP):
		return "the high road"
	return "the grass"
