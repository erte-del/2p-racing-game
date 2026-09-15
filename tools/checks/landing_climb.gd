extends SceneTree

# Land a car off a real jump, then run it straight off a ledge.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/landing_climb.gd
#
# A car leaves a ramp with the climb the ramp was giving it. What it must not
# do is come down still holding that climb: a car that did would throw itself
# back into the air off the first thing it ran out of floor on after landing -
# the other car's roof, the edge of the landing, a crest just past touchdown -
# long after the ramp that gave it the climb was behind it.
#
# So the car is flown once to find where it comes down, and then again with a
# flat-topped ledge built over that spot, short enough that it runs off the
# end of it well inside a second of landing. A flat ledge has nothing to climb,
# so whatever the car goes up with off the end of it came from somewhere else.

## Metres of level road before the ramp, the same run up tilt_trace uses.
const RUN_UP := 24.0
## How high the ledge stands above the landing, in metres. It has to be taller
## than the car's 0.6 m floor snap, or the car would simply be held down onto
## the road below and never leave the floor at all.
const LEDGE_HEIGHT := 1.2
## How far the ledge reaches back under the flight from where the car came
## down without it, and on past that, in metres. Back far enough that the car
## comes down on top of it rather than into its end; on only far enough that
## the car is off the other end of it well within a second.
const LEDGE_BEHIND := 8.0
const LEDGE_AHEAD := 12.0
## The most a car may go up with off the end of a flat ledge, in m/s. A flat
## ledge gives it nothing, so this is only room for the physics to settle.
const ALLOWED_LAUNCH := 0.5


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

	var jump: TrackLayout.Piece = null
	for course in range(1, 60):
		track.generate(course * 977)
		for piece in track.layout().pieces:
			if piece.kind == TrackLayout.JUMP:
				jump = piece
		if jump != null:
			break
	if jump == null:
		print("  no course in the first 60 had a jump on it")
		quit(1)
		return

	var faults := 0
	var open: Dictionary = await _run(track, car, jump)
	if not open["landed"]:
		print("  the car never flew the jump, so nothing here was tested")
		quit(1)
		return
	print("off the jump onto the open road: down %.1f m past the lip, holding %+.1f m/s of climb"
		% [_flat_distance(open["took_off"], open["down"]), open["climb"]])

	var ledge := _build_ledge(main, open["took_off"], open["down"])
	var run: Dictionary = await _run(track, car, jump)
	ledge.queue_free()

	if not run["landed"]:
		print("  with the ledge there the car never came down from the jump")
		quit(1)
		return
	var top: float = open["down"].y + LEDGE_HEIGHT
	print("onto a %.1f m ledge: down %.1f m past the lip, holding %+.1f m/s of climb"
		% [LEDGE_HEIGHT, _flat_distance(run["took_off"], run["down"]), run["climb"]])
	if absf(run["down"].y - top) > 0.2:
		print("  it came down at %.2f m, not on the ledge's top at %.2f m"
			% [run["down"].y, top])
		faults += 1
	if not run["left"]:
		print("  it never ran off the end of the ledge")
		faults += 1
	else:
		print("ran off the end %.2f s after landing, going up at %+.1f m/s, and rose %.2f m above it"
			% [run["after"], run["launch"], run["rise"]])
		if run["after"] > 1.0:
			print("  that was not within the second after landing this is about")
			faults += 1
		if run["launch"] > ALLOWED_LAUNCH:
			print("  a car that had already landed was thrown up off a flat ledge")
			faults += 1
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Settle the car on the run up, hold it flat out through the jump, and report
## where it came down, the climb it was still carrying when it did, and - if it
## ran out of floor again afterwards - how soon, how fast it went up and how
## far it rose.
func _run(track: Track, car: Car, jump: TrackLayout.Piece) -> Dictionary:
	var curve := track.curve()
	var at: float = jump.start_offset - RUN_UP
	car.frozen = true
	car.global_position = track.global_transform * (
		curve.sample_baked(at) + Vector3.UP * (car.wheel_radius + 0.6))
	# Aimed level with itself, for the reason tilt_trace gives.
	var ahead: Vector3 = track.global_transform * curve.sample_baked(at + 2.0)
	car.look_at(Vector3(ahead.x, car.global_position.y, ahead.z), Vector3.UP)
	car.frozen = false
	car.reset_motion()
	for i in 25:
		car._speed = 0.0
		await physics_frame
	car.reset_motion()

	var result := {"landed": false, "left": false}
	var airborne := 0
	var took_off := Vector3.ZERO
	var down_frame := 0
	var left_y := 0.0
	var peak := -INF
	for i in 400:
		car._speed = car.max_speed
		await physics_frame
		var on_floor := car.is_on_floor()
		if not result["landed"]:
			if not on_floor:
				if airborne == 0:
					took_off = car.global_position
				airborne += 1
			elif airborne > 0:
				# A frame or two off the ground is the car skipping over the
				# join at the foot of the ramp. The jump is a flight.
				if airborne >= 20:
					result["landed"] = true
					result["took_off"] = took_off
					result["down"] = car.global_position
					result["climb"] = car._climb
					down_frame = i
				airborne = 0
		elif not result["left"]:
			if not on_floor:
				result["left"] = true
				result["after"] = float(i - down_frame) / 60.0
				# Read on the first step off the floor, which is the step the
				# car was handed whatever it goes up with.
				result["launch"] = car.velocity.y
				left_y = car.global_position.y
				peak = left_y
			elif i - down_frame > 90:
				break
		else:
			peak = maxf(peak, car.global_position.y)
			if i - down_frame > 150:
				break
	if result["left"]:
		result["rise"] = peak - left_y
	return result


## A flat-topped block standing LEDGE_HEIGHT above the landing, laid along the
## line the car flew, from a little way back under its flight to a little way
## past where it came down without it.
func _build_ledge(main: Node, from: Vector3, down: Vector3) -> StaticBody3D:
	var along := Vector3(down.x - from.x, 0.0, down.z - from.z).normalized()
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, LEDGE_HEIGHT, LEDGE_BEHIND + LEDGE_AHEAD)
	shape.shape = box
	body.add_child(shape)
	main.add_child(body)
	var middle := (down + along * ((LEDGE_AHEAD - LEDGE_BEHIND) * 0.5)
		+ Vector3.UP * (LEDGE_HEIGHT * 0.5))
	body.global_transform = Transform3D(Basis.looking_at(along, Vector3.UP), middle)
	return body


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(b.x - a.x, b.z - a.z).length()
