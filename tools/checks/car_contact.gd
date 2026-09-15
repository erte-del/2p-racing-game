extends SceneTree

# Run one car into the back of the other, and squeeze two side by side into a
# rail.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/car_contact.gd
#
# From behind, the car doing the hitting has to lose more than the car it hits
# gains, or ramming would pay; the car hit must not be pushed past its own top
# speed; and after a square hit neither should still be closing on the other.
# The same hit is run twice with the two cars swapped over, because the cars
# take their physics steps one after the other and how a contact comes out
# must not depend on which of them goes first.
#
# Side by side, the cars are pushed apart, and the push is added to where they
# are going rather than put on them outright, so a car pinned between the
# other and a rail slides down the rail instead of through it.
#
# In both, the two boxes are measured against each other on every step: a
# bump that let one car into the other would be a bump that let one through.

## The rear car's speed, the front car's, and the gap between them, in m/s and
## metres.
const REAR := 30.0
const FRONT := 20.0
const GAP := 6.0
## How fast the two cars run side by side, and how far the outer one is turned
## in towards the rail, in m/s and degrees.
const SQUEEZE_SPEED := 20.0
const SQUEEZE_TURN := 8.0
## The most the two boxes may ever be into each other, in metres. A little
## more than nothing, for the physics settling a contact.
const OVERLAP := 0.05
## Metres of straight with nothing built on them that both runs need.
const CLEAR := 80.0


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
	var car1: Car = main.get_node("Car1")
	var car2: Car = main.get_node("Car2")
	var faults := 0

	var at := _clear_stretch(track, CLEAR)
	if at < 0.0:
		print("  no course in the first 200 had %.0f m of straight with nothing on it"
			% CLEAR)
		quit(1)
		return
	print("%.0f m of straight with nothing on it, %.1f m wide"
		% [CLEAR, track.half_width_at(at) * 2.0])

	# Coasting costs nothing here, so any speed that goes missing or turns up
	# went missing or turned up in a contact.
	var braking := car1.engine_braking
	car1.engine_braking = 0.0
	car2.engine_braking = 0.0

	var first: Dictionary = await _from_behind(track, at, car1, car2)
	var second: Dictionary = await _from_behind(track, at, car2, car1)
	for run in [["Car1 behind", first], ["Car2 behind", second]]:
		var hit: Dictionary = run[1]
		if not hit["bumped"]:
			print("  %s: the rear car never touched the front one" % run[0])
			faults += 1
			continue
		print("%s: rear %.1f -> %.1f m/s, front %.1f -> %.1f m/s; lost %.2f, gave %.2f; pushed apart %.2f m/s; %d contacts; boxes at most %.3f m into each other"
			% [run[0], REAR, hit["rear"], FRONT, hit["front"], REAR - hit["rear"],
				hit["front"] - FRONT, hit["push"], hit["contacts"], hit["overlap"]])
		if REAR - hit["rear"] <= hit["front"] - FRONT:
			print("  the rear car lost no more than the front car gained, so ramming pays")
			faults += 1
		if hit["front"] > car1.max_speed + 0.01:
			print("  the front car was pushed past its own top speed")
			faults += 1
		if hit["rear"] > hit["front"] + 0.05:
			print("  after a square hit the rear car is still closing on the front one")
			faults += 1
		if hit["overlap"] > OVERLAP:
			print("  one car was let into the other")
			faults += 1
	if first["bumped"] and second["bumped"] and (
			absf(first["rear"] - second["rear"]) > 0.01
			or absf(first["front"] - second["front"]) > 0.01):
		print("  the same hit came out differently with the cars the other way round")
		faults += 1

	var squeeze: Dictionary = await _squeeze(track, at, car1, car2)
	print("side by side into the rail: pushed apart %d times; the pinned car's side came %.2f m from the rail's face and the other's %.2f m; boxes at most %.3f m into each other; both on the road: %s"
		% [squeeze["pushes"], squeeze["pinned_gap"], squeeze["other_gap"],
			squeeze["overlap"], squeeze["on_road"]])
	if squeeze["pushes"] == 0:
		print("  cars leant together side on were never pushed apart")
		faults += 1
	if squeeze["pinned_gap"] < -0.05 or squeeze["other_gap"] < -0.05:
		print("  a car went through the rail")
		faults += 1
	if not squeeze["on_road"]:
		print("  a car left the road")
		faults += 1
	if squeeze["overlap"] > OVERLAP:
		print("  one car was let into the other")
		faults += 1

	car1.engine_braking = braking
	car2.engine_braking = braking
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Put `rear` behind `front` in the middle of the lane, a gap apart, both going
## straight down the road, and let the rear one catch the front one.
func _from_behind(track: Track, at: float, rear: Car, front: Car) -> Dictionary:
	var length := _box(rear).z
	_place(track, rear, at, 0.0)
	_place(track, front, at + length + GAP, 0.0)
	await _settle(rear, front)
	var result := {"bumped": false, "rear": REAR, "front": FRONT, "push": 0.0,
		"contacts": 0, "overlap": 0.0}
	var rear_was := REAR
	var front_was := FRONT
	rear._speed = REAR
	front._speed = FRONT
	var after := -1
	for i in 150:
		rear.frozen = false
		front.frozen = false
		await physics_frame
		result["overlap"] = maxf(result["overlap"], _overlap(rear, front))
		if not is_equal_approx(rear.speed(), rear_was) \
				or not is_equal_approx(front.speed(), front_was):
			result["contacts"] += 1
			if not result["bumped"]:
				result["bumped"] = true
				result["rear"] = rear.speed()
				result["front"] = front.speed()
				result["push"] = maxf(rear._shove.length(), front._shove.length())
				after = i
		rear_was = rear.speed()
		front_was = front.speed()
		if after >= 0 and i - after > 60:
			break
	return result


## Two cars side by side at the right-hand rail, the outer one turned in
## towards it, held at speed for two seconds.
func _squeeze(track: Track, at: float, pinned: Car, other: Car) -> Dictionary:
	var width := _box(pinned).x
	var face := _rail_face(track, at)
	_place(track, pinned, at, face - width * 0.5 - 0.3)
	_place(track, other, at, face - width * 1.5 - 0.7, -deg_to_rad(SQUEEZE_TURN))
	await _settle(pinned, other)
	var result := {"pushes": 0, "pinned_gap": INF, "other_gap": INF,
		"overlap": 0.0, "on_road": true}
	var pushed_was := 0.0
	for i in 120:
		pinned.frozen = false
		other.frozen = false
		pinned._speed = SQUEEZE_SPEED
		other._speed = SQUEEZE_SPEED
		await physics_frame
		result["overlap"] = maxf(result["overlap"], _overlap(pinned, other))
		var here := _along(track, pinned)
		result["pinned_gap"] = minf(result["pinned_gap"],
			_rail_face(track, here) - (_across(track, pinned) + width * 0.5))
		result["other_gap"] = minf(result["other_gap"],
			_rail_face(track, _along(track, other)) - (_across(track, other) + width * 0.5))
		var pushed := pinned._shove.length()
		if pushed > pushed_was + 1.0:
			result["pushes"] += 1
		pushed_was = pushed
		for car in [pinned, other]:
			if not _on_road(track, car):
				result["on_road"] = false
	return result


## Where along a course there are `length` metres of straight with nothing
## built on them - no pad to lift a car's top speed, no barrier to stop it -
## or below zero when the first 200 courses have none. The course it found is
## left built.
func _clear_stretch(track: Track, length: float) -> float:
	for course in range(1, 200):
		track.generate(course * 977)
		for piece in track.layout().pieces:
			if piece.kind != TrackLayout.STRAIGHT:
				continue
			var start: float = piece.start_offset + 5.0
			var end: float = piece.end_offset - 5.0
			var taken: Array[Vector2] = []
			for placed in track.features().placements:
				if placed.offset < end and placed.offset + placed.length > start:
					taken.append(Vector2(placed.offset, placed.offset + placed.length))
			taken.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
			var free_from := start
			for span in taken:
				if span.x - free_from >= length:
					return free_from
				free_from = maxf(free_from, span.y + 5.0)
			if end - free_from >= length:
				return free_from
	return -1.0


## Put a car on the road `across` metres right of the centreline, facing down
## the course, turned by `turn` radians, stopped.
func _place(track: Track, car: Car, at: float, across: float, turn := 0.0) -> void:
	var curve := track.curve()
	var here: Vector3 = track.global_transform * curve.sample_baked(at)
	var ahead: Vector3 = track.global_transform * curve.sample_baked(at + 2.0)
	var forward := ahead - here
	forward.y = 0.0
	forward = forward.normalized()
	car.frozen = true
	car.global_position = here + forward.cross(Vector3.UP) * across + Vector3.UP * 0.05
	car.look_at(car.global_position + forward.rotated(Vector3.UP, turn), Vector3.UP)
	car.reset_motion()


## Let both cars down onto the road at a standstill. The race's own countdown
## freezes and frees them on its timers, so they are put back every step.
func _settle(a: Car, b: Car) -> void:
	for i in 20:
		a.frozen = false
		b.frozen = false
		a._speed = 0.0
		b._speed = 0.0
		await physics_frame
	a.reset_motion()
	b.reset_motion()


## How far two cars' boxes are into each other, in metres, and nothing when
## they are apart. The boxes only ever turn about the vertical, so it is two
## rectangles on the ground, and a gap along any one of their four sides is
## a gap between them.
func _overlap(a: Car, b: Car) -> float:
	var shape: CollisionShape3D = a.get_node("Collision")
	var half := _box(a) * 0.5
	var centre_a := a.global_transform * shape.position
	var centre_b := b.global_transform * shape.position
	if absf(centre_a.y - centre_b.y) >= half.y * 2.0:
		return 0.0
	var between := Vector2(centre_b.x - centre_a.x, centre_b.z - centre_a.z)
	var least := INF
	for axis3 in [a.global_transform.basis.x, a.global_transform.basis.z,
			b.global_transform.basis.x, b.global_transform.basis.z]:
		var axis := Vector2(axis3.x, axis3.z).normalized()
		var into := _reach(a, axis, half) + _reach(b, axis, half) - absf(between.dot(axis))
		if into <= 0.0:
			return 0.0
		least = minf(least, into)
	return least


## Half a car's box measured along a direction on the ground.
func _reach(car: Car, axis: Vector2, half: Vector3) -> float:
	var side := Vector2(car.global_transform.basis.x.x, car.global_transform.basis.x.z).normalized()
	var length := Vector2(car.global_transform.basis.z.x, car.global_transform.basis.z.z).normalized()
	return half.x * absf(side.dot(axis)) + half.z * absf(length.dot(axis))


## The collision box's size.
func _box(car: Car) -> Vector3:
	var shape: CollisionShape3D = car.get_node("Collision")
	return (shape.shape as BoxShape3D).size


## How far along the course a car is.
func _along(track: Track, car: Car) -> float:
	return track.curve().get_closest_offset(
		track.global_transform.affine_inverse() * car.global_position)


## How far right of the centreline a car is, in metres.
func _across(track: Track, car: Car) -> float:
	var curve := track.curve()
	var at := _along(track, car)
	var here: Vector3 = track.global_transform * curve.sample_baked(at)
	var ahead: Vector3 = track.global_transform * curve.sample_baked(at + 2.0)
	var forward := ahead - here
	forward.y = 0.0
	return (car.global_position - here).dot(forward.normalized().cross(Vector3.UP))


## How far right of the centreline the inside face of the right-hand rail is.
func _rail_face(track: Track, at: float) -> float:
	return track.half_width_at(at) + track.kerb_width - track.rail_thickness


func _on_road(track: Track, car: Car) -> bool:
	var space := car.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		car.global_position + Vector3.UP * 0.5, car.global_position + Vector3.DOWN * 3.0)
	query.exclude = [car.get_rid()]
	var hit := space.intersect_ray(query)
	return not hit.is_empty() and String(hit["collider"].name) == "RoadBody"
