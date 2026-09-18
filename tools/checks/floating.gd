extends SceneTree

# Climb a car into the air a jump at a time, and bring it back down.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/floating.gd
#
# A jump that lands higher than it took off is a jump a slow car hits the front
# of, and one that lands far below is a landing hard enough to stop a car dead. So every climbing jump on the test course is taken at the slowest speed a
# car is let loose at, tuned, fast and on a boost, and has to come down on the
# road above every time. The long drop back to the ground has to leave the car
# on the road and driving, not stuck or bounced off. And the layout has to
# refuse a jump that climbs further than a car can reach.

const COURSE := "res://tools/checks/floating_course.gd"
const RUN_UP := 55.0
const SPEEDS := [0.78, 1.0, 1.25, 1.55]


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
	for problem in track.layout().problems() + track.features().faults(track.layout()):
		print("  the test course: %s" % problem)
		faults += 1

	var jumps: Array[TrackLayout.Piece] = []
	for piece in track.layout().pieces:
		if piece.kind == TrackLayout.JUMP:
			jumps.append(piece)
	var tuned := car.max_speed
	var names := ["3.5 m up", "platform, 3 m up", "ring, 3.5 m up"]
	for j in 3:
		var top := track.centre_at(jumps[j].end_offset - 10.0).y
		for fraction: float in SPEEDS:
			# A boost is too fast for a platform on purpose; it is not asked.
			if j == 1 and fraction > 1.25:
				continue
			car.max_speed = tuned * fraction
			var run: Dictionary = await _drive(solo, track, car, jumps[j])
			var made: bool = run["ended"] == "road" and absf(run["height"] - top) < 1.5
			print("  %-17s %4.1f m/s: %s, %.1f m up (the road is %.1f)"
				% [names[j], car.max_speed, run["ended"], run["height"], top])
			if not made:
				print("    did not make it up")
				faults += 1
			if j == 2 and not run["banked"]:
				print("    flew through a climbing ring's jump without banking it")
				faults += 1
	car.max_speed = tuned

	var drop: Dictionary = await _drive(solo, track, car, jumps[3])
	print("  the 10 m drop: %s, still doing %.1f m/s" % [drop["ended"], drop["speed"]])
	if drop["ended"] != "road" or drop["speed"] < car.max_speed * 0.8:
		print("    the drop did not leave the car on the road and driving")
		faults += 1

	# Two platforms back to back: off the first, 35 m of island, and straight up
	# the ramp of the second. Driven from before the first, judged past the
	# second.
	var top := track.centre_at(jumps[5].end_offset - 10.0).y
	for fraction: float in [0.8, 1.0, 1.2]:
		car.max_speed = tuned * fraction
		var hops: Dictionary = await _drive(solo, track, car, jumps[4], jumps[5].end_offset - 25.0)
		print("  two hops, %4.1f m/s: %s, %.1f m up (the road is %.1f)"
			% [car.max_speed, hops["ended"], hops["height"], top])
		if hops["ended"] != "road" or absf(hops["height"] - top) > 1.5:
			print("    did not get across both platforms")
			faults += 1
	car.max_speed = tuned

	# The longest drop in the game: off twenty-eight metres, which Last Leap
	# ends with. It has to leave the car on the road and driving, not stopped
	# dead or thrown back into the air.
	var far: Dictionary = await _drive(solo, track, car, jumps[6])
	print("  the 28 m drop: %s, still doing %.1f m/s" % [far["ended"], far["speed"]])
	if far["ended"] != "road" or far["speed"] < car.max_speed * 0.8:
		print("    the long drop did not leave the car on the road and driving")
		faults += 1

	var short := TrackDefinition.new()
	short.straight(60.0)
	short.platform_jump(0.0, 0.0, 0.6, 1.0, 1.0, 0.0, 20.0)
	short.straight(60.0)
	var short_found := TrackLayout.adopt(short.pieces).problems()
	print("a platform jump with 20 m to land on: %s" % "; ".join(short_found))
	if not "; ".join(short_found).contains("to land on"):
		faults += 1

	var too_high := TrackDefinition.new()
	too_high.straight(60.0)
	too_high.jump(5.0)
	too_high.straight(60.0)
	var layout := TrackLayout.adopt(too_high.pieces)
	var found := layout.problems()
	print("a jump 5 m up: %s" % "; ".join(found))
	if not "; ".join(found).contains("lands 5.0 m up"):
		faults += 1

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Send the car flat out at `jump` from its run up, and say what it is on, how
## high, how fast, and whether the first ring was banked, once it is well past
## the hole.
func _drive(solo: Node, track: Track, car: Car, jump: TrackLayout.Piece,
		judged_past := -1.0) -> Dictionary:
	solo.set("_running", false)
	solo.call("_place_on_the_line")
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
	car.reset_motion()
	solo.set("_time", 0.0)
	solo.set("_was", car.middle())
	solo.set("_running", true)
	var past := judged_past if judged_past > 0.0 else jump.end_offset - 25.0
	for i in 60 * 10:
		car._speed = car.max_speed
		await physics_frame
		if car.is_on_floor() and track.offset_of(car.global_position) > past:
			break
		if car.global_position.y < -2.0:
			break
	for i in 30:
		car._speed = car.max_speed
		await physics_frame
	solo.set("_running", false)
	var banked: PackedByteArray = solo.get("_banked")
	return {
		"ended": _under(solo, car), "height": car.global_position.y,
		"speed": car.speed(), "banked": banked.size() > 0 and banked[0] == 1,
	}


func _under(solo: Node, car: Car) -> String:
	var space: PhysicsDirectSpaceState3D = solo.get_world_3d().direct_space_state
	var from := car.global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.0)
	query.exclude = [car.get_rid()]
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return "nothing"
	var collider: Node = hit["collider"]
	if collider is AnimatableBody3D and collider.is_in_group(Car.ROAD_GROUP):
		return "platform"
	return "road" if collider.name == "RoadBody" else "grass"
