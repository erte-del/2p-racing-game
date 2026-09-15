extends SceneTree

# Lay out a run of courses and check every boost pad on them.
#   Godot --path . --headless --script tools/checks/pad_layout.gd -- [courses]
#
# The rules a pad is meant to keep are all things a player would notice going
# wrong: pads on the kerb, pads on a corner, pads on the grid or on a
# respawn, pads stacked on top of each other. None of them are visible from
# one course, so this checks a hundred.

const COURSES := 100


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var courses := int(args[0]) if not args.is_empty() else COURSES

	# Chaos rerolls the shape of the course from a random seed the moment the
	# scene loads, which would make every one of these runs a different set of
	# courses and the counts below meaningless to compare.
	# Fetched off the tree rather than named: the autoload is there when a
	# check runs, but a bare `GameSettings` will not compile in a script run
	# outside the main scene.
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.chaos = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var track: Track = main.get_node("Track")
	var total := 0
	var empty := 0
	var faults := 0
	var lanes := {-1: 0, 0: 0, 1: 0}

	for course in courses:
		track.generate(course * 977 + 1)
		var pads := track.features().of_kind(TrackFeatures.BOOST_PAD)
		total += pads.size()
		if pads.is_empty():
			empty += 1

		# In the order a player meets them, which is not the order they were
		# planned in: the fork is laid down before the loose pads are, and its
		# pad can be anywhere on the course.
		pads.sort_custom(func(a: TrackFeatures.Placement, b: TrackFeatures.Placement) -> bool:
			return a.offset < b.offset)
		var last := -INF
		for pad in pads:
			lanes[signi(int(round(pad.lateral * 2.0)))] += 1
			faults += _check(track, pad, last, course)
			last = pad.offset

	print("%d courses, %d pads, %.1f per course, %d with none"
		% [courses, total, float(total) / float(courses), empty])
	print("lanes: %d left, %d middle, %d right"
		% [lanes[-1], lanes[0], lanes[1]])
	print("%d faults" % faults)

	faults += await _check_pickup(main, track)
	quit(1 if faults > 0 else 0)


## Laying pads out correctly is worth nothing if driving over one does not pay.
## Park a car on a pad and see whether it comes away with a boost - and park
## one just off the pad, in the next lane over, to make sure it does not.
func _check_pickup(main: Node, track: Track) -> int:
	var faults := 0
	var car: Car = main.get_node("Car1")
	car.frozen = true

	for course in range(1, 40):
		track.generate(course * 977)
		var pads := track.features().of_kind(TrackFeatures.BOOST_PAD)
		if pads.is_empty():
			continue
		var pad: TrackFeatures.Placement = pads[0]

		car.reset_motion()
		await _park_at(main, track, pad, pad.lateral)
		if not car.is_boosting():
			print("  a car sitting on a pad picked up nothing")
			faults += 1
		else:
			print("pad pays %.0f%% extra top speed, %.1f m/s in all"
				% [car.boost_amount() * 100.0, car.top_speed()])

		car.reset_motion()
		# A lane and a half over: off the pad, still on the road.
		var beside: float = pad.lateral + (1.5 if pad.lateral <= 0.0 else -1.5) * pad.half_span * 2.0
		await _park_at(main, track, pad, beside)
		if car.is_boosting():
			print("  a car alongside a pad picked one up anyway")
			faults += 1
		return faults

	print("  no course in the first 40 had a pad to drive over")
	return faults + 1


## Drop the car onto the road at a pad, across the road by `lateral`, and let
## the physics run long enough for the trigger to notice it.
func _park_at(
	main: Node, track: Track, pad: TrackFeatures.Placement, lateral: float
) -> void:
	var curve := track.curve()
	var at := pad.centre()
	var centre: Vector3 = curve.sample_baked(at)
	var ahead: Vector3 = curve.sample_baked(minf(at + 2.0, track.length()))
	var forward := (ahead - centre)
	forward.y = 0.0
	var right := forward.normalized().cross(Vector3.UP)
	var car: Car = main.get_node("Car1")
	car.global_position = track.global_transform * (
		centre + right * (lateral * track.half_width_at(at)) + Vector3.UP * 0.5)
	for i in 6:
		await physics_frame


## Everything one pad has to satisfy. Returns the number of rules it broke.
func _check(track: Track, pad: TrackFeatures.Placement, last: float, course: int) -> int:
	var faults := 0

	# On the road, not over the kerb.
	if absf(pad.lateral) + pad.half_span > 1.0:
		faults += _fault(course, pad, "hangs over the kerb")

	# The fork's own pad sits inside its fast lane, which is a set piece with
	# its own rules; the ones below are for the pads scattered on open road.
	for fork in track.features().of_kind(TrackFeatures.FORK):
		if pad.offset >= fork.offset and pad.offset < fork.offset + fork.length:
			return faults

	# On a straight, and clear of the corners at either end.
	var piece := _piece_at(track, pad.centre())
	if piece == null:
		faults += _fault(course, pad, "is not on any piece")
	elif piece.kind == TrackLayout.CORNER:
		faults += _fault(course, pad, "is on a corner")
	elif (pad.offset - piece.start_offset < 10.0
			or piece.end_offset - (pad.offset + pad.length) < 10.0):
		faults += _fault(course, pad, "is too near the end of its straight")

	# Clear of the grid, the finish and every respawn.
	var marks := PackedFloat32Array([track.start_offset(), track.finish_offset()])
	marks.append_array(track.checkpoint_offsets())
	for mark in marks:
		if absf(pad.centre() - mark) < 18.0:
			faults += _fault(course, pad, "is on top of a line at %.0f m" % mark)

	# Clear of the pad before it.
	if pad.offset - last < 55.0:
		faults += _fault(course, pad, "is %.0f m behind the last one" % (pad.offset - last))

	# On the course at all.
	if pad.offset < 0.0 or pad.offset + pad.length > track.length():
		faults += _fault(course, pad, "runs off the end of the course")

	return faults


func _fault(course: int, pad: TrackFeatures.Placement, why: String) -> int:
	print("  course %d: pad at %.0f m, lane %+.2f, %s"
		% [course, pad.offset, pad.lateral, why])
	return 1


func _piece_at(track: Track, offset: float) -> TrackLayout.Piece:
	for piece in track.layout().pieces:
		if offset >= piece.start_offset and offset < piece.end_offset:
			return piece
	return null
