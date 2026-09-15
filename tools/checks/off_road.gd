extends SceneTree

# Put a car on the grass and see what it can get away with.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/off_road.gd
#
# The ground is one flat box, the embankment under a raised road has no
# collision, and the road is only solid from above, so a car that falls into
# the hole in a jump is out on the grass with the whole of it to drive on. It
# used to be at full speed there, and a checkpoint banked for any car within
# finish_corridor of the centreline, as did the finish, which did not ask for
# the checkpoints at all - so a car could drive across the grass from a jump
# hole to the flag. Now a car only counts on the road, needs every checkpoint
# to finish, and is slower off it. This drives cars on the grass to find out
# what they can still get away with, rather than working it out:
#
# - how much road stands level with the grass, at a bumper's height, and high
#   enough for a car to fit under;
# - what a car on the grass driving straight across the road finds at each;
# - whether a car driving along the grass beside the road banks a checkpoint,
#   and whether it finishes the race;
# - and, on every laid-out track with a jump, whether a car that has fallen into
#   the hole can drive across the grass to the flag, and what that skips.
#
# A car banking a checkpoint or finishing a race from the grass is a fault.

## Metres out beyond the rail a car on the grass is put.
const OUT := 6.0
## How fast a car on the grass is driven in the crossings, in m/s.
const CROSSING := 15.0
## Rolled courses whose road heights are counted.
const COURSES := 50


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	settings.track_file = ""
	# Pointed at a scratch file, so finishing a track from the grass does not
	# write itself into the player's own record of what they have driven.
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times != null:
		times.save_path = "user://times_off_road_check.cfg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
		times.load_times()

	var faults := 0
	faults += await _banking_from_the_grass()
	await _heights_and_crossings(settings)
	faults += await _out_of_the_hole(settings)

	if times != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


# --- a race, driven beside the road ---------------------------------------

## A real race, running: drive a car along the grass past the first checkpoint
## and then past the finish, outside the rail the whole way.
func _banking_from_the_grass() -> int:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var waited := 0
	while not main.get("_racing") and waited < 600:
		await physics_frame
		waited += 1
	var track: Track = main.get_node("Track")
	var car: Car = main.get_node("Car1")
	var other: Car = main.get_node("Car2")
	var faults := 0

	var mark: float = track.checkpoint_offsets()[0]
	var passed := await _along_the_grass(track, car, other, mark)
	var banked: int = (main.get("_banked")[0] as PackedByteArray).count(1)
	print("beside the road past the first checkpoint, %.1f m from the centreline at the closest: %s"
		% [passed, "banked it" if banked > 0 else "not banked"])
	if banked > 0:
		print("  a car on the grass banked a checkpoint")
		faults += 1

	var finish := track.finish_offset()
	passed = await _along_the_grass(track, car, other, finish)
	var over: bool = not main.get("_racing")
	var said: String = main.get_node("Result/Top/Label").text
	print("beside the road past the finish, %.1f m from the centreline at the closest: %s"
		% [passed, ("the race ended: %s" % said.replace("\n", " ")) if over else "the race went on"])
	if over:
		print("  a car on the grass finished the race")
		faults += 1

	main.queue_free()
	await process_frame
	return faults


## Put the car on the grass outside the right-hand rail 25 m short of `mark`,
## pointed down the road, and drive it straight on past. Returns how close to
## the centreline at `mark` it came.
func _along_the_grass(track: Track, car: Car, other: Car, mark: float) -> float:
	var from := maxf(mark - 25.0, 0.0)
	var centre := track.centre_at(from)
	var start := (Vector3(centre.x, 0.05, centre.z)
		+ _right(track, from) * (track.half_width_at(from) + track.kerb_width + OUT))
	_put(car, start, _heading(track, mark))
	await _settle(car, other)
	var closest := INF
	for i in 150:
		car.frozen = false
		other.frozen = true
		car._speed = 20.0
		await physics_frame
		closest = minf(closest, car.global_position.distance_to(track.centre_at(mark)))
	return closest


# --- the road from underneath -----------------------------------------------

## How high the road stands over the grass on every laid-out track and a run
## of rolled courses, and what a car on the grass finds driving straight across
## it at each height.
func _heights_and_crossings(settings: Node) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame
	# Only the road is wanted here, not a race: nothing should be finishing or
	# being put back at a checkpoint while the course is rebuilt under it.
	main.set_physics_process(false)
	var track: Track = main.get_node("Track")
	var car: Car = main.get_node("Car1")
	var other: Car = main.get_node("Car2")
	var tall := _box(car).y

	var laid := [0.0, 0.0, 0.0, 0]
	for index in TrackRoster.FILES.size():
		track.track_file = TrackRoster.file(index)
		track.generate(0)
		_count_heights(track, tall, laid)
	track.track_file = ""
	var rolled := [0.0, 0.0, 0.0, 0]
	for course in COURSES:
		track.generate(course * 977 + 5)
		_count_heights(track, tall, rolled)
	for tally in [["the laid-out tracks", laid], ["%d rolled courses" % COURSES, rolled]]:
		var counts: Array = tally[1]
		var total: float = counts[0] + counts[1] + counts[2]
		print("%s: %.1f km of road, %.0f%% level with the grass, %.0f%% at bumper height, %.0f%% high enough to drive under; %d jump holes"
			% [tally[0], total / 1000.0, 100.0 * counts[0] / total,
				100.0 * counts[1] / total, 100.0 * counts[2] / total, counts[3]])

	for height in [["level with the grass", 0.0, 0.15],
			["at bumper height", 0.4, 1.2],
			["high enough to drive under", tall + 0.6, 100.0]]:
		var at := _a_stretch_at(track, height[1], height[2])
		if at < 0.0:
			print("across road %s: no straight stretch of it found" % height[0])
			continue
		var crossed: Array = await _drive_across(track, car, other, at)
		var half: float = crossed[4]
		var outcome := ""
		if crossed[2]:
			outcome = "climbed up onto the road"
		elif crossed[0] < -half:
			outcome = "went straight across and out the far side, never more than %.2f m up" % crossed[1]
		else:
			outcome = "was stopped %.1f m from the centreline" % crossed[0]
		print("across road %s (%.2f m up): %s" % [height[0], track.centre_at(at).y, outcome])

	# And how fast the grass lets a car go, flat out with the throttle held,
	# well away from the road. The car has to know it is off the road for the
	# race to refuse it anything, so that is asked too.
	var far := track.centre_at(track.length() * 0.5) + _right(track, track.length() * 0.5) * 60.0
	far.y = 0.05
	_put(car, far, _heading(track, track.length() * 0.5))
	await _settle(car, other)
	car._speed = car.max_speed
	Input.action_press("p1_accelerate")
	for i in 180:
		car.frozen = false
		other.frozen = true
		await physics_frame
	Input.action_release("p1_accelerate")
	print("flat out on the grass for three seconds from %.1f m/s: going %.1f m/s, off_road_speed %.2f, on the road: %s"
		% [car.max_speed, car.speed(), car.off_road_speed, car.on_the_road()])

	main.queue_free()
	await process_frame


## Add up, in metres, road level with the grass, at bumper height and high
## enough to fit under, and count the holes.
func _count_heights(track: Track, tall: float, counts: Array) -> void:
	var layout := track.layout()
	var hole := false
	for i in layout.road_present.size():
		if layout.road_present[i] == 0:
			if not hole:
				counts[3] += 1
			hole = true
			continue
		hole = false
		var height := track.centre_at(float(i) * layout.step).y
		if height <= 0.15:
			counts[0] += layout.step
		elif height < tall:
			counts[1] += layout.step
		else:
			counts[2] += layout.step


## Somewhere on a rolled course where the road stands between `low` and `high`
## over the grass, runs straight, has road for 20 m either way and nothing built
## on it. The course is left built; below zero when none of 80 has one.
func _a_stretch_at(track: Track, low: float, high: float) -> float:
	for course in range(1, 80):
		track.generate(course * 977 + 5)
		var layout := track.layout()
		var reach := int(20.0 / layout.step)
		for i in range(reach, layout.road_present.size() - reach):
			var at := float(i) * layout.step
			if at < track.length() * 0.2 or at > track.length() * 0.8:
				continue
			var height := track.centre_at(at).y
			if height < low or height > high:
				continue
			var whole := true
			for k in range(i - reach, i + reach + 1):
				if layout.road_present[k] == 0:
					whole = false
			if not whole:
				continue
			if rad_to_deg(_heading(track, at - 10.0).angle_to(_heading(track, at + 10.0))) > 8.0:
				continue
			var empty := true
			for placed in track.features().placements:
				if absf(placed.centre() - at) < 25.0:
					empty = false
			if empty:
				return at
	return -1.0


## Put the car on the grass beyond the right-hand rail and drive it straight
## across the road for three seconds. Returns where it ended up across the
## road, the highest it got, whether it ended up on the road, whether it had
## stopped, and how far out the rail stands.
func _drive_across(track: Track, car: Car, other: Car, at: float) -> Array:
	var half := track.half_width_at(at) + track.kerb_width
	var right := _right(track, at)
	var centre := track.centre_at(at)
	var start := Vector3(centre.x, 0.05, centre.z) + right * (half + OUT)
	_put(car, start, -right)
	await _settle(car, other)
	var top := 0.0
	for i in 180:
		car.frozen = false
		other.frozen = true
		car._speed = CROSSING
		await physics_frame
		top = maxf(top, car.global_position.y)
	var flat := car.global_position - centre
	flat.y = 0.0
	return [flat.dot(right), top, _on_road(car),
		car.get_real_velocity().length() < 1.0, half]


# --- out of a jump hole -----------------------------------------------------

## On every laid-out track with a jump: a car in the first hole, once the clock
## is running, aimed straight across the grass at the flag.
func _out_of_the_hole(settings: Node) -> int:
	var faults := 0
	for index in TrackRoster.FILES.size():
		settings.track_file = TrackRoster.file(index)
		var solo: Node = load("res://scenes/solo.tscn").instantiate()
		root.add_child(solo)
		for i in 10:
			await physics_frame
		var track: Track = solo.get_node("Track")
		var car: Car = solo.get_node("Car")
		var jump: TrackLayout.Piece = null
		for piece in track.layout().pieces:
			if piece.kind == TrackLayout.JUMP:
				jump = piece
				break
		if jump == null:
			solo.queue_free()
			await process_frame
			continue
		var waited := 0
		while not solo.get("_running") and waited < 600:
			await physics_frame
			waited += 1

		var layout := track.layout()
		var hole: float = jump.start_offset + layout.ramp_length + layout.jump_gap * 0.5
		var finish := track.finish_offset()
		var flag := track.centre_at(minf(finish + 4.0, track.length()))
		flag.y = 0.0
		var start := track.centre_at(hole)
		start.y = 0.05
		_put(car, start, (flag - start).normalized())
		for i in 15:
			car.frozen = false
			car._speed = 0.0
			await physics_frame

		var clock: float = solo.get("_time")
		var driven := 0.0
		var last := car.global_position
		var checked := last
		var outcome := "ran out of time"
		for i in 60 * 120:
			if not solo.get("_running"):
				outcome = "finished"
				break
			var wanted := flag - car.global_position
			wanted.y = 0.0
			if wanted.length() < 3.0:
				outcome = "reached the flag without the race noticing"
				break
			car.rotate_y(clampf((-car.global_transform.basis.z).signed_angle_to(
				wanted.normalized(), Vector3.UP), -0.05, 0.05))
			car.frozen = false
			car._speed = car.max_speed
			await physics_frame
			var moved := car.global_position - last
			moved.y = 0.0
			driven += moved.length()
			last = car.global_position
			if i % 180 == 179:
				var progress := car.global_position - checked
				progress.y = 0.0
				if progress.length() < 2.0:
					var left := flag - car.global_position
					left.y = 0.0
					outcome = "stuck %.0f m short of the flag" % left.length()
					break
				checked = car.global_position
		var took: float = float(solo.get("_time")) - clock
		print("%-16s out of the hole at %.0f m: %s, %.0f m across the grass in %.1f s, where the road from there to the flag is %.0f m"
			% [track.definition().track_name, hole, outcome, driven, took, finish - hole])
		if outcome == "finished":
			faults += 1
		solo.queue_free()
		await process_frame
	if faults > 0:
		print("  %d tracks can be finished across the grass from a jump hole" % faults)
	return faults


# --- shared -----------------------------------------------------------------

func _put(car: Car, at: Vector3, facing: Vector3) -> void:
	car.frozen = true
	car.global_position = at
	car.look_at(at + Vector3(facing.x, 0.0, facing.z), Vector3.UP)
	car.reset_motion()
	car.reset_physics_interpolation()


## Let the car down onto whatever is under it at a standstill. Races freeze and
## free their cars on their own timers, so it is put back every step.
func _settle(car: Car, other: Car) -> void:
	for i in 15:
		car.frozen = false
		other.frozen = true
		car._speed = 0.0
		await physics_frame
	car.reset_motion()


## Which way the course runs at an offset, flat on the ground.
func _heading(track: Track, at: float) -> Vector3:
	var here := track.centre_at(clampf(at, 0.0, track.length()))
	var ahead := track.centre_at(clampf(at + 2.0, 0.0, track.length()))
	var forward := ahead - here
	forward.y = 0.0
	return forward.normalized()


func _right(track: Track, at: float) -> Vector3:
	return _heading(track, at).cross(Vector3.UP)


func _box(car: Car) -> Vector3:
	var shape: CollisionShape3D = car.get_node("Collision")
	return (shape.shape as BoxShape3D).size


func _on_road(car: Car) -> bool:
	var space := car.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		car.global_position + Vector3.UP * 0.5, car.global_position + Vector3.DOWN * 3.0)
	query.exclude = [car.get_rid()]
	var hit := space.intersect_ray(query)
	return not hit.is_empty() and String(hit["collider"].name) == "RoadBody"
