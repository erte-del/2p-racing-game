extends SceneTree

# Run a car square into a barrier with the throttle held, and time how long it
# takes to steer away.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/barrier_recovery.gd
#
# A square hit costs most of a car's speed, and that is the point of a barrier.
# What it should not do is leave the car pinned to the face. A car held against
# one with the throttle down is hit again every time obstacle_recovery runs
# out, is scrubbed down to a crawl, and - the turning circle being what it is
# at a crawl - takes seconds to turn away. The bounce throws it back off the
# face for long enough to get turned instead.
#
# The same run is made twice, once with the bounce taken away, which is how the
# car used to behave, so the two can be read side by side. The hit itself has
# to cost exactly the same both times: the bounce is where the car goes after
# the hit, not what the hit is worth.

## Metres back from the row the run starts.
const RUN_UP := 26.0
## How far round from straight down the road, in degrees, the car has to have
## turned to count as having turned away.
const TURNED := 45.0
## Seconds the car is held into the face with the throttle down and no
## steering, which is what a player who has not yet taken in what happened
## does, and then how long it is watched once the steering goes on.
const HOLD := 1.5
const WATCH := 4.0


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.chaos = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame

	var track: Track = main.get_node("Track")
	var car: Car = main.get_node("Car1")
	var other: Car = main.get_node("Car2")

	var row: TrackFeatures.Placement = null
	for course in range(1, 60):
		track.generate(course * 977)
		row = _a_row_on_its_own(track)
		if row != null and not track.features().gaps_past(track.layout(), row).is_empty():
			break
		row = null
	if row == null:
		print("  no course in the first 60 had a barrier to drive at")
		quit(1)
		return

	var bounce := car.obstacle_bounce
	var bounce_time := car.obstacle_bounce_time
	car.obstacle_bounce = 0.0
	car.obstacle_bounce_time = 0.0
	var pinned: Dictionary = await _hit_and_turn(track, car, other, row)
	car.obstacle_bounce = bounce
	car.obstacle_bounce_time = bounce_time
	var thrown: Dictionary = await _hit_and_turn(track, car, other, row)

	var faults := 0
	for run in [["without the bounce", pinned], ["with the bounce", thrown]]:
		var result: Dictionary = run[1]
		if result["first"] < 0.0:
			print("  %s the car never hit the barrier" % run[0])
			faults += 1
			continue
		print("%-18s %.1f -> %.1f m/s on the hit, %.2f m back off the face; held into it for %.1f s it is going %.1f m/s; steering away, %s; hit %d times in all"
			% [run[0], car.max_speed, result["first"], result["back"], HOLD,
				result["held"],
				("it has turned %.0f degrees in %.2f s, going %.1f m/s"
					% [TURNED, result["turned"], result["speed"]])
					if result["turned"] >= 0.0 else "it never turns away",
				result["hits"]])
	if faults == 0:
		if not is_equal_approx(pinned["first"], thrown["first"]):
			print("  the bounce changed what the hit itself costs")
			faults += 1
		if thrown["back"] < 0.5:
			print("  the car was not thrown back off the barrier")
			faults += 1
		if thrown["held"] <= pinned["held"]:
			print("  held into the barrier, the car kept no more speed with the bounce than without")
			faults += 1
		# Sooner, not some fraction as soon: how quickly a car turns at a few
		# metres a second is the turning circle's business, and a car that never
		# touched the face again would still take most of the time it takes.
		if thrown["turned"] < 0.0:
			print("  with the bounce the car still never turned away")
			faults += 1
		elif pinned["turned"] >= 0.0 and thrown["turned"] >= pinned["turned"]:
			print("  the bounce did not get the car turned away any sooner")
			faults += 1
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Aim the car square at the row with the throttle held, keep it held into the
## face for HOLD seconds after the hit, and then put the steering on towards
## the way past as well. Returns the speed the hit left it, how far back off
## the face it got in the moment after, how fast it was going when the
## steering went on, how long from then it took to turn away and how fast it
## was going when it had, and how many times it hit a barrier in all.
func _hit_and_turn(track: Track, car: Car, other: Car,
		row: TrackFeatures.Placement) -> Dictionary:
	var curve := track.curve()
	var at: float = maxf(row.centre() - RUN_UP, 1.0)
	var here: Vector3 = track.global_transform * curve.sample_baked(at)
	var ahead: Vector3 = track.global_transform * curve.sample_baked(row.centre())
	var forward := ahead - here
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var gap: Vector2 = track.features().gaps_past(track.layout(), row)[0]
	var towards := "p1_steer_right" if (gap.x + gap.y) * 0.5 > row.lateral else "p1_steer_left"

	car.frozen = true
	car.global_position = (here + right * (row.lateral * track.half_width_at(at))
		+ Vector3.UP * 0.05)
	car.look_at(car.global_position + forward, Vector3.UP)
	car.frozen = false
	car.reset_motion()
	for i in 15:
		other.frozen = true
		car._speed = 0.0
		await physics_frame
	car.reset_motion()
	car._speed = car.max_speed
	var road_yaw := car.rotation.y
	Input.action_press("p1_accelerate")

	var result := {"first": -1.0, "back": 0.0, "held": 0.0, "turned": -1.0,
		"speed": 0.0, "hits": 0}
	var was := car.speed()
	var hit_at := -1
	var steer_at := -1
	var face := 0.0
	for i in int((2.0 + HOLD + WATCH) * 60.0):
		# The race's own countdown freezes and frees the cars on its timers.
		other.frozen = true
		car.frozen = false
		await physics_frame
		var now := car.speed()
		# The throttle is held, so the car only ever slows by hitting something.
		if now < was - 0.5:
			result["hits"] += 1
			if hit_at < 0:
				hit_at = i
				result["first"] = now
				face = _along(track, car)
		was = now
		if hit_at < 0:
			continue
		var since := float(i - hit_at) / 60.0
		if since <= 0.6:
			result["back"] = maxf(result["back"], face - _along(track, car))
		if steer_at < 0:
			if since >= HOLD:
				steer_at = i
				result["held"] = now
				Input.action_press(towards)
			continue
		var steering := float(i - steer_at) / 60.0
		if result["turned"] < 0.0 and absf(rad_to_deg(
				angle_difference(road_yaw, car.rotation.y))) >= TURNED:
			result["turned"] = steering
			result["speed"] = now
		if steering >= WATCH:
			break
	Input.action_release("p1_accelerate")
	Input.action_release(towards)
	return result


## A row standing across open road, not a fork's divider or one of the
## barriers down its fast lane, with room before it to get up to speed. The
## same choice barrier_layout makes, for the same reason.
func _a_row_on_its_own(track: Track) -> TrackFeatures.Placement:
	var features := track.features()
	for row in features.rows():
		if row.offset < 40.0:
			continue
		var inside := false
		for fork in features.of_kind(TrackFeatures.FORK):
			if row.offset >= fork.offset and row.offset < fork.offset + fork.length:
				inside = true
		if not inside:
			return row
	return null


## How far along the course a car is.
func _along(track: Track, car: Car) -> float:
	return track.curve().get_closest_offset(
		track.global_transform.affine_inverse() * car.global_position)
