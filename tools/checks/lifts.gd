extends SceneTree

# Ride lifts at every moment of their cycle, two ways, and see which get across.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/lifts.gd
#
# A lift is a platform that rises and falls, with its landing up at the top, so
# the only way across is to come down on it low and leave it high. That is two
# promises: that there is a way across, and that it is a matter of timing. So a
# car is sent at a lift that rises six metres from every quarter second of its
# cycle, two ways - flat out the whole way over, and landing, braking to a stop
# on it, waiting for the top and pulling away - and it has to get across from
# some of those moments and not from others. A lift nobody can cross is a wall;
# one everybody crosses whenever they arrive is a floor.

const COURSE := "res://tools/checks/lift_course.gd"
const RUN_UP := 55.0


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
	var lifts := track.features().of_kind(TrackFeatures.PLATFORM)

	var lift: TrackFeatures.Placement = lifts[0]
	var cycle := (lift.dwell + lift.travel) * 2.0
	for waiting in [false, true]:
		var made := PackedStringArray()
		var tries := 0
		var clock := 0.0
		while clock < cycle - 0.01:
			var run: Dictionary = await _drive(solo, track, car, jumps[0], clock, waiting)
			tries += 1
			if run["made"]:
				made.append("%.2f" % clock)
			clock += 0.25
		print("%s: across from %d of %d starts%s" % [
			"land, stop and wait for the top" if waiting else "flat out",
			made.size(), tries, (" (at %s s)" % ", ".join(made)) if not made.is_empty() else ""])
		if waiting and made.is_empty():
			print("  nobody can get across a lift by waiting on it")
			faults += 1
		if made.size() == tries:
			print("  a lift is crossed whenever a car arrives; its timing asks nothing")
			faults += 1

	var too_high := TrackDefinition.new()
	too_high.straight(60.0)
	too_high.lift_jump(0.0, 9.0)
	too_high.straight(60.0)
	var found := TrackLayout.adopt(too_high.pieces).problems()
	print("a lift 9 m high: %s" % "; ".join(found))
	if not "; ".join(found).contains("lands"):
		faults += 1

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## From the run up to `jump` with the race clock at `clock`, flat out - and if
## `waiting`, braking to a stop once on the lift and pulling away once it is at
## the top. Says whether the car ended on the landing.
func _drive(solo: Node, track: Track, car: Car, jump: TrackLayout.Piece,
		clock: float, waiting: bool) -> Dictionary:
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
	track.set_race_time(clock)
	for i in 25:
		car._speed = 0.0
		await physics_frame
	car.reset_motion()
	solo.set("_time", clock)
	solo.set("_was", car.middle())
	solo.set("_running", true)

	var lift: TrackFeatures.Placement = null
	for placement in track.features().of_kind(TrackFeatures.PLATFORM):
		if placement.offset > jump.start_offset and placement.offset < jump.end_offset:
			lift = placement
	var top := track.centre_at(jump.end_offset - 10.0).y
	var stage := "going"
	for i in 60 * 14:
		var on_lift := car.is_on_floor() and _under(solo, car) == "platform"
		if waiting and stage == "going" and on_lift:
			stage = "braking"
		# The keys, not the speed, once it is on the lift: what a player gets
		# from braking and pulling away is the car's own braking, acceleration
		# and engine braking together, and setting the speed by hand gets
		# none of that right.
		_let_go()
		if stage == "braking":
			Input.action_press("solo_brake")
			if car.speed() < 0.5:
				stage = "waiting"
		elif stage == "waiting":
			var now: float = solo.get("_time")
			# Away once it has reached the top.
			if lift.lift_at(now) >= lift.lift - 0.05:
				stage = "away"
		elif stage == "away":
			Input.action_press("solo_accelerate")
		else:
			car._speed = car.max_speed
		await physics_frame
		if car.global_position.y < top - 12.0:
			break
		if car.is_on_floor() and track.offset_of(car.global_position) > jump.end_offset - 30.0:
			break
	_let_go()
	solo.set("_running", false)
	var ended := _under(solo, car)
	return {
		"made": ended == "road" and absf(car.global_position.y - top) < 1.5,
		"ended": ended, "height": car.global_position.y, "top": top,
	}


func _let_go() -> void:
	for action in ["solo_accelerate", "solo_brake", "solo_steer_left", "solo_steer_right"]:
		Input.action_release(action)


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
