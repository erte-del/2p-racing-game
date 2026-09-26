extends SceneTree

# Lay out a run of courses and check every barrier on them.
#   Godot --path . --headless --script tools/checks/barrier_layout.gd -- [courses]
#
# The rule that matters is the one no single course shows: a course has to
# stay driveable. A row that blocks the whole road, or a pair of rows set so
# close that no car could cross between their gaps, both look perfectly
# reasonable one at a time and are a dead end together.

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
	var narrowest := INF
	var sides := {-1: 0, 0: 0, 1: 0}
	var forks := 0
	var forkless := 0
	var fork_rows := 0

	for course in courses:
		track.generate(course * 977 + 1)
		var layout := track.layout()
		var features := track.features()
		var rows := features.of_kind(TrackFeatures.OBSTACLE)
		total += rows.size()
		if rows.is_empty():
			empty += 1

		# The planner's own account of whether this course can be driven.
		for why in features.faults(layout):
			print("  course %d: %s" % [course, why])
			faults += 1

		# Every course is meant to offer the choice at least once.
		var here := features.of_kind(TrackFeatures.FORK)
		forks += here.size()
		if here.is_empty():
			forkless += 1
			print("  course %d has no fork; longest straight %.0f m"
				% [course, _longest_straight(track)])
		for fork in here:
			for row in rows:
				if (not row.along and row.offset >= fork.offset
						and row.offset < fork.offset + fork.length):
					fork_rows += 1

		for row in rows:
			sides[signi(int(round(row.lateral * 2.0)))] += 1
			narrowest = minf(narrowest, _widest_gap(layout, features, row))
			faults += _check(track, row, course)

	print("%d courses, %d barriers, %.1f per course, %d with none"
		% [courses, total, float(total) / float(courses), empty])
	print("%.1f rows a course across the road, %d walls along it"
		% [float(total - forks) / float(courses), forks])
	print("blocking: %d from the left, %d down the middle, %d from the right"
		% [sides[-1], sides[0], sides[1]])
	print("narrowest way past any barrier: %.2f m (%.2f m is the rule)"
		% [narrowest, track.clear_lane])
	print("%d forks, %d courses with none, %.1f barriers in a fast lane"
		% [forks, forkless, float(fork_rows) / float(maxi(forks, 1))])
	print("%d faults" % faults)

	faults += _check_the_checker(track)
	faults += await _check_the_hit(main, track)
	quit(1 if faults > 0 else 0)


## Laying barriers out correctly is worth nothing if driving into one costs
## nothing. Run a car at one twice from the same speed with a boost up: once
## straight at the barrier, once through the gap the plan promises is there.
func _check_the_hit(main: Node, track: Track) -> int:
	var faults := 0
	var car: Car = main.get_node("Car1")
	main.get_node("Car2").frozen = true

	for course in range(1, 60):
		track.generate(course * 977)
		var row := _a_row_on_its_own(track)
		if row == null:
			continue
		var gaps := track.features().gaps_past(track.layout(), row)
		if gaps.is_empty():
			continue

		var into := await _run_at(main, track, row, row.lateral)
		var past := await _run_at(main, track, row, (gaps[0].x + gaps[0].y) * 0.5)
		print("into the barrier: %.1f -> %.1f m/s on the hit, boost %.2f -> %.2f"
			% [into[0], into[1], into[2], into[3]])
		print("through the gap:  %.1f -> %.1f m/s throughout, boost %.2f -> %.2f"
			% [past[0], past[1], past[2], past[3]])

		if into[1] > into[0] * 0.5:
			print("  driving into a barrier barely cost anything")
			faults += 1
		if into[3] > 0.01:
			print("  a car kept its boost through a barrier")
			faults += 1
		if past[1] < past[0] * 0.9:
			print("  a car lost speed going through the clear gap")
			faults += 1
		if past[3] < 0.2:
			print("  a car lost its boost going through the clear gap")
			faults += 1
		return faults

	print("  no course in the first 60 had a barrier to drive at")
	return faults + 1


## A row standing across open road: not a fork's divider, not one of the
## barriers inside a fork's fast lane, and with room to get up to speed before
## it. Driving at one of those instead would be measuring the fork.
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


## Aim a car at a row from `run_up` metres back, boosted and coasting, and let
## it arrive. Returns the speed and boost before and after.
func _run_at(
	main: Node, track: Track, row: TrackFeatures.Placement, lateral: float
) -> Array:
	var car: Car = main.get_node("Car1")
	var curve := track.curve()
	var at: float = maxf(row.centre() - 26.0, 1.0)
	var here: Vector3 = curve.sample_baked(at)
	var ahead: Vector3 = curve.sample_baked(row.centre())
	var forward := ahead - here
	forward.y = 0.0
	var right := forward.normalized().cross(Vector3.UP)

	car.frozen = false
	# Coasting normally sheds 6 m/s every second, which would swamp what the
	# barrier costs. With engine braking off, whatever speed goes missing over
	# the run went missing in the collision.
	car.engine_braking = 0.0
	car.reset_motion()
	car.global_position = track.global_transform * (
		here + right * (lateral * track.half_width_at(at))
		+ Vector3.UP * (car.wheel_radius + 0.1))
	# Pointed straight down the road, so the run is the same both times and
	# only where it is aimed across the road differs.
	car.look_at(track.global_transform * (
		ahead + right * (lateral * track.half_width_at(row.centre()))),
		Vector3.UP)
	car._speed = car.max_speed
	car.boost()
	var start := car.global_position
	# Only as far as it takes to arrive at this row and be past it. Left to
	# run on, the car - which is not steering - would reach the next barrier
	# down the straight, and what that measures is a car driving into a second
	# barrier rather than what this one cost.
	var run: float = 26.0 + row.length + 6.0
	var before := car._speed
	var boost_before := car.boost_amount()
	# What one hit costs, rather than what pressing on into the barrier for
	# two seconds does: the first is the price of the mistake, the second is
	# just the player refusing to steer out of it.
	var first_hit := before
	# Long enough to cover the 26 m run at 25 m/s and arrive at whatever is
	# waiting there.
	for i in 110:
		await physics_frame
		if first_hit == before and car._speed < before - 0.01:
			first_hit = car._speed
		if car.global_position.distance_to(start) > run:
			break
	return [before, first_hit, boost_before, car.boost_amount()]


## A validator that has never rejected anything is not obviously working. The
## planner builds rows that pass by construction, so the only way to see the
## rule bite is to hand it a plan that breaks it on purpose.
func _check_the_checker(track: Track) -> int:
	var faults := 0
	track.generate(1)
	var layout := track.layout()
	var features := track.features()
	var half_width := layout.half_width_at(200.0)

	for trial in [
		["a row blocking the whole road", [[200.0, 0.0, 1.0]]],
		# Each of these leaves a comfortable way past on its own. Together, at
		# 5 m apart, the gaps do not line up and no car can cross between them.
		["two rows whose gaps do not line up, 5 m apart",
			[[200.0, -0.4, 0.6], [207.4, 0.4, 0.6]]],
		# One takes the left half of the road and the next the right half, so
		# the gaps meet exactly in the middle. Measured between the gaps that
		# is no move at all; the car has its own width to get across, which
		# wants 11.5 m and has 7.4.
		["two rows whose gaps only touch, 5 m apart",
			[[200.0, -0.5, 0.5], [207.4, 0.5, 0.5]]],
	]:
		features.placements.clear()
		for row in trial[1]:
			var barrier := TrackFeatures.Placement.new(
					TrackFeatures.OBSTACLE, row[0], 2.4)
			barrier.lateral = row[1]
			barrier.half_span = row[2]
			features.placements.append(barrier)
		var caught := features.faults(layout)
		if caught.is_empty():
			print("  %s went unnoticed" % trial[0])
			faults += 1
		else:
			print("caught: %s -> %s" % [trial[0], caught[0]])

	print("road is %.1f m wide there" % (half_width * 2.0))
	return faults


## The widest single gap past a row, in metres.
func _widest_gap(
	layout: TrackLayout, features: TrackFeatures, row: TrackFeatures.Placement
) -> float:
	var half_width := layout.half_width_at(row.centre())
	var widest := 0.0
	for gap in features.gaps_past(layout, row):
		widest = maxf(widest, (gap.y - gap.x) * half_width)
	return widest


## Everything one row has to satisfy on its own.
func _check(track: Track, row: TrackFeatures.Placement, course: int) -> int:
	var faults := 0

	# Standing on the road, not out over the kerb.
	if absf(row.lateral) + row.half_span > 1.001:
		faults += _fault(course, row, "hangs over the kerb")

	# On a straight, where it can be seen from far enough back.
	var piece := _piece_at(track, row.centre())
	if piece == null:
		faults += _fault(course, row, "is not on any piece")
	elif piece.kind == TrackLayout.CORNER:
		faults += _fault(course, row, "is on a corner")
	elif (row.offset - piece.start_offset < 18.0
			or piece.end_offset - (row.offset + row.length) < 18.0):
		faults += _fault(course, row, "is too near the end of its straight")

	# Clear of the grid, the finish and every respawn: a car put back on the
	# road facing a barrier has been given a crash, not a second chance.
	var marks := PackedFloat32Array([track.start_offset(), track.finish_offset()])
	marks.append_array(track.checkpoint_offsets())
	for mark in marks:
		if absf(row.centre() - mark) < 18.0:
			faults += _fault(course, row, "is on top of a line at %.0f m" % mark)

	# Not built on a pad. A fork's divider is exempt: it runs the length of the
	# fast lane and the pad it is offering sits inside that lane, so the two
	# overlapping is the set piece working rather than a collision.
	for pad in (
		[] if row.along else track.features().of_kind(TrackFeatures.BOOST_PAD)
	):
		if (row.offset < pad.offset + pad.length
				and pad.offset < row.offset + row.length):
			faults += _fault(course, row, "is standing on a pad")

	if row.offset < 0.0 or row.offset + row.length > track.length():
		faults += _fault(course, row, "runs off the end of the course")

	return faults


func _fault(course: int, row: TrackFeatures.Placement, why: String) -> int:
	print("  course %d: barrier at %.0f m, lane %+.2f wide %.2f, %s"
		% [course, row.offset, row.lateral, row.half_span * 2.0, why])
	return 1


func _longest_straight(track: Track) -> float:
	var most := 0.0
	for piece in track.layout().pieces:
		if piece.kind != TrackLayout.CORNER:
			most = maxf(most, piece.length)
	return most


func _piece_at(track: Track, offset: float) -> TrackLayout.Piece:
	for piece in track.layout().pieces:
		if offset >= piece.start_offset and offset < piece.end_offset:
			return piece
	return null
