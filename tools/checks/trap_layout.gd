extends SceneTree

# Check every trap on every track, and on a run of chaos courses, and drive
# into one.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/trap_layout.gd -- [courses]
#
# A trap is a barrier that is somewhere different every second, and the rules a
# barrier lives under - a way past, reachable from the way past the row before
# - have to hold wherever it has got to. A row that closes the road only for
# the moment it is halfway across is not a hard trap, it is a broken track,
# and nobody can tell the difference from inside the car.

const COURSES := 100

var _faults := 0


## A straight long enough to get up to speed, one trap, and a straight to leave
## by. Built here rather than borrowed from a track, so the runs below are at
## a trap with nothing else near it, whatever the tracks go on to become.
class Proving extends TrackDefinition:
	func describe() -> void:
		track_name = "Proving"
		straight(160.0)
		trap(-0.7, 0.7)
		straight(160.0)


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var courses := int(args[0]) if not args.is_empty() else COURSES

	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.chaos = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	# The race loop would otherwise start once its countdown ran out and set
	# the traps to its own clock over the top of the one being tested here.
	main.set_physics_process(false)
	var track: Track = main.get_node("Track")

	_check_the_clock()
	_check_the_tracks(track)
	_check_chaos(track, courses)
	_check_the_checker(track)
	await _check_the_drive(main, track)
	main.queue_free()
	await process_frame
	await _check_the_races()

	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


## Where a trap is is a function of the clock and nothing else.
func _check_the_clock() -> void:
	var trap := TrackFeatures.Placement.new(TrackFeatures.TRAP, 0.0, 2.4)
	trap.phases = PackedFloat32Array([-0.7, 0.7])
	trap.lateral = -0.7
	trap.dwell = 1.6
	trap.travel = 1.0
	for trial: Array in [
		[0.0, -0.7, "at GO"], [1.6, -0.7, "at the end of its first hold"],
		[2.1, 0.0, "halfway across"], [2.6, 0.7, "across"],
		[4.2, 0.7, "at the end of its second hold"], [5.2, -0.7, "back"],
		[5.2 + 2.1, 0.0, "halfway across a second time"],
	]:
		var at := trap.lateral_at(trial[0])
		if not is_equal_approx(at, trial[1]):
			print("  %s (%.1f s) it stands at %+.2f, not %+.2f"
				% [trial[2], trial[0], at, trial[1]])
			_faults += 1
	var sweep := trap.sweep(0.05)
	print("a kerb-to-kerb trap is at %+.2f at GO, %+.2f at 2.1 s, %+.2f at 2.6 s, "
		% [trap.lateral_at(0.0), trap.lateral_at(2.1), trap.lateral_at(2.6)]
		+ "back at %+.2f at 5.2 s; checked in %d places" % [
			trap.lateral_at(5.2), sweep.size()])


## Every trap the tracks have, held to the rules in every place it goes.
func _check_the_tracks(track: Track) -> void:
	var traps := 0
	var narrowest := INF
	for index in TrackRoster.FILES.size():
		var path := TrackRoster.file(index)
		var script: GDScript = load(path)
		track.lay_out(script.new())
		var layout := track.layout()
		var features := track.features()
		var here := features.of_kind(TrackFeatures.TRAP)
		traps += here.size()
		for why in features.faults(layout):
			print("  %s: %s" % [path.get_file(), why])
			_faults += 1
		for trap in here:
			narrowest = minf(narrowest, _narrowest_way_past(layout, features, trap))
			for lateral in trap.phases:
				if absf(lateral) + trap.half_span > 1.001:
					print("  %s: the trap at %.0f m hangs over the kerb at %+.2f"
						% [path.get_file(), trap.offset, lateral])
					_faults += 1
		if not here.is_empty():
			print("%s: %d traps" % [track.definition().track_name, here.size()])
	print("%d traps on %d tracks, narrowest way past any of them anywhere: %s"
		% [traps, TrackRoster.FILES.size(),
			"none" if narrowest == INF else "%.2f m" % narrowest])


## Rolled courses, rolled the way chaos rolls them, traps and all.
func _check_chaos(track: Track, courses: int) -> void:
	var chaos := Chaos.new([] as Array[Car], null, track)
	var rng := RandomNumberGenerator.new()
	var traps := 0
	var rows := 0
	var without := 0
	var narrowest := INF
	var faults := 0
	track.track_file = ""
	for course in courses:
		rng.seed = course * 7919 + 3
		chaos.reroll(rng)
		track.generate(course * 977 + 1)
		var layout := track.layout()
		var features := track.features()
		var here := features.of_kind(TrackFeatures.TRAP)
		traps += here.size()
		rows += features.rows().size()
		if here.is_empty():
			without += 1
		for why in features.faults(layout):
			print("  chaos course %d: %s" % [course, why])
			faults += 1
		for trap in here:
			narrowest = minf(narrowest, _narrowest_way_past(layout, features, trap))
			if not track.traps_enabled:
				print("  chaos course %d: traps were not turned on" % course)
				faults += 1
	print("%d chaos courses, %d traps among %d rows, %d courses with none"
		% [courses, traps, rows, without])
	print("narrowest way past a chaos trap anywhere: %s (%.2f m is the rule)"
		% ["none" if narrowest == INF else "%.2f m" % narrowest, track.clear_lane])
	if traps == 0:
		print("  chaos laid no traps at all")
		faults += 1
	_faults += faults

	# And off again without chaos: the endless course stays what it was.
	track.traps_enabled = false
	track.generate(977 + 1)
	if not track.features().of_kind(TrackFeatures.TRAP).is_empty():
		print("  a course rolled without chaos has traps on it")
		_faults += 1


## A validator that has never rejected anything is not obviously working.
## These plans are each fine wherever their traps rest - the part the rules
## cannot see without following a trap - and wrong somewhere in between.
func _check_the_checker(track: Track) -> void:
	track.traps_enabled = false
	track.generate(1)
	var layout := track.layout()
	var features := track.features()
	var half_width := layout.half_width_at(200.0)
	print("road is %.1f m wide at 200 m" % (half_width * 2.0))

	for trial: Array in [
		# Either end leaves 4.8 m open in one piece. Halfway it leaves the same
		# road in two halves of 2.4 m, and a car fits through neither.
		["a trap that closes the road halfway across",
			[[200.0, [-0.3, 0.3], 0.7]]],
		# At GO both rest on the left and the way past is a straight line.
		# Once the first has crossed and the second has not, the ways past are
		# on opposite sides of the middle, 1.6 m apart, with 5 m of road between
		# the rows to cross in.
		["two traps whose ways past only line up where they rest",
			[[200.0, [-0.45, 0.45], 0.55], [207.4, [-0.45, 0.45], 0.55]]],
		["two traps standing beside each other",
			[[200.0, [-0.7, 0.7], 0.3], [201.0, [0.7, -0.7], 0.3]]],
	]:
		features.placements.clear()
		for row: Array in trial[1]:
			var trap := TrackFeatures.Placement.new(TrackFeatures.TRAP, row[0], 2.4)
			trap.phases = PackedFloat32Array(row[1])
			trap.lateral = trap.phases[0]
			trap.half_span = row[2]
			trap.dwell = 1.6
			trap.travel = 1.0
			features.placements.append(trap)
		var caught := features.faults(layout)

		# The same plan with every trap frozen where it rests passes, or the
		# trial is not testing what it says it is.
		var resting: Array[TrackFeatures.Placement] = []
		for trap in features.placements:
			var row := TrackFeatures.Placement.new(TrackFeatures.OBSTACLE, trap.offset, trap.length)
			row.lateral = trap.lateral
			row.half_span = trap.half_span
			resting.append(row)
		var kept := features.placements
		features.placements = resting
		var at_rest := features.faults(layout)
		features.placements = kept

		if caught.is_empty():
			print("  %s went unnoticed" % trial[0])
			_faults += 1
		else:
			print("caught: %s -> %s" % [trial[0], caught[0]])
		if not at_rest.is_empty() and not trial[0].contains("beside"):
			print("  %s is already wrong at rest: %s" % [trial[0], at_rest[0]])
			_faults += 1


## Drive at a trap, on the proving straight, at two moments: while it holds the
## left of the road and while it holds the right. Aimed at the side it is on
## the car hits it and pays for it; aimed at the other it goes by for nothing.
## That both answers swap when only the clock does is what shows the body is
## where the clock says, rather than where it was built.
func _check_the_drive(main: Node, track: Track) -> void:
	track.lay_out(Proving.new())
	var trap: TrackFeatures.Placement = track.features().of_kind(TrackFeatures.TRAP)[0]
	var car: Car = main.get_node("Car1")
	main.get_node("Car2").frozen = true
	# Held on each side from the start of its hold, not its end, so it does not
	# set off across the road while the car is still on its way to it.
	var holds := {"left": 0.0, "right": trap.dwell + trap.travel}

	for side: String in holds:
		var seconds: float = holds[side]
		var at := trap.lateral_at(seconds)
		track.set_race_time(seconds)
		await physics_frame
		var into := await _run_at(car, track, trap, at)
		var past := await _run_at(car, track, trap, -at)
		print("held %s (%+.2f): into it %.1f -> %.1f m/s, boost %.2f -> %.2f; "
			% [side, at, into[0], into[1], into[2], into[3]]
			+ "past it %.1f -> %.1f m/s, boost %.2f -> %.2f"
			% [past[0], past[1], past[2], past[3]])
		if into[1] > into[0] * 0.5:
			print("  driving into a trap on the %s barely cost anything" % side)
			_faults += 1
		if into[3] > 0.01:
			print("  a car kept its boost through a trap on the %s" % side)
			_faults += 1
		if past[1] < past[0] * 0.9:
			print("  a car lost speed going past a trap on the %s" % side)
			_faults += 1
		if past[3] < 0.2:
			print("  a car lost its boost going past a trap on the %s" % side)
			_faults += 1

	await _swept_into(car, track, trap)
	car.frozen = true


## The race scenes are what tell the traps the time, so a trap is only ever as
## right as they are about it. Both of them, on the first track with a trap:
## held where it starts through the countdown, where the clock says once the
## race is running, and back where it started when the race goes back to the
## line.
func _check_the_races() -> void:
	var settings: Node = root.get_node(^"/root/GameSettings")
	settings.chaos = false
	settings.damage = false
	var file := ""
	for index in TrackRoster.FILES.size():
		var definition: TrackDefinition = load(TrackRoster.file(index)).new()
		definition.describe()
		for placement in definition.placements:
			if placement.kind == TrackFeatures.TRAP and file.is_empty():
				file = TrackRoster.file(index)
	if file.is_empty():
		print("  no track has a trap to race past")
		_faults += 1
		return
	settings.track_file = file

	for scene: Array in [
		["solo", "res://scenes/solo.tscn", "_running", "_time"],
		["two players", "res://scenes/main.tscn", "_racing", "_race_time"],
	]:
		var race: Node = load(scene[1]).instantiate()
		root.add_child(race)
		await physics_frame
		var furniture: TrackFurniture = race.get_node("Track/Furniture")
		var trap: Dictionary = furniture._traps[0]
		var placement: TrackFeatures.Placement = trap["placement"]
		var held := _where(trap)
		for i in 60:
			await physics_frame
		var counting := _where(trap)
		if race.get(scene[2]):
			print("  %s: the race started before the countdown could be looked at" % scene[0])
			_faults += 1

		for i in 600:
			if race.get(scene[2]) and float(race.get(scene[3])) > placement.dwell + placement.travel * 0.5:
				break
			await physics_frame
		var clock: float = race.get(scene[3])
		var running := _where(trap)
		var expected := placement.lateral_at(clock)

		race._restart()
		await physics_frame
		var restarted := _where(trap)
		print("%s: %+.2f at GO, %+.2f counting down, %+.2f at %.2f s racing (the clock says %+.2f), %+.2f after a restart"
			% [scene[0], placement.lateral, counting, running, clock, expected, restarted])
		if not is_equal_approx(held, placement.lateral) or not is_equal_approx(counting, placement.lateral):
			print("  %s: a trap moved before GO" % scene[0])
			_faults += 1
		if absf(running - expected) > 0.02 or is_equal_approx(running, placement.lateral):
			print("  %s: a trap is not where the race clock says" % scene[0])
			_faults += 1
		if not is_equal_approx(restarted, placement.lateral):
			print("  %s: a restart left a trap where the last race had it" % scene[0])
			_faults += 1
		race.queue_free()
		await process_frame
	settings.track_file = ""


## Where a built trap's body is across the road, as a lateral.
func _where(trap: Dictionary) -> float:
	var body: AnimatableBody3D = trap["body"]
	return ((body.position - trap["centre"]).dot(trap["right"])
		/ float(trap["half_width"]))


## Put a car in the lane a trap is closing and let the trap come across.
##
## The one thing a trap does that a barrier cannot: arrive. Pushed towards open
## road the physics does the right thing by itself, but pinned against the kerb
## a car has nowhere to go but up, and comes down on top of the rail, where it
## can drive along the top of it. So the furniture shoves a car out of the row
## along the road before that happens, and what is checked here is that it
## does: parked in the middle, parked against the kerb, rolling slowly into the
## row, and half in it - at the tuned speed and at a crossing faster than chaos
## ever rolls.
func _swept_into(car: Car, track: Track, trap: TrackFeatures.Placement) -> void:
	var curve := track.curve()
	var centre := trap.centre()
	var here: Vector3 = curve.sample_baked(centre)
	var forward: Vector3 = curve.sample_baked(centre + 10.0) - here
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var half_width := track.half_width_at(centre)
	var tuned := trap.travel

	for travel: float in [tuned, 0.5]:
		trap.travel = travel
		for trial: Array in [
			# lateral, metres back from the middle of the row, speed
			["parked in the middle", 0.0, 0.0, 0.0],
			["parked against the kerb", 0.8, 0.0, 0.0],
			["rolling into the row", 0.2, 6.0, 5.0],
			["half in the row", 0.5, 3.0, 0.0],
		]:
			track.set_race_time(0.0)
			await physics_frame
			car.frozen = false
			car.engine_braking = 6.0
			car.reset_motion()
			car.global_position = track.global_transform * (
				here - forward * float(trial[2])
				+ right * (float(trial[1]) * half_width) + Vector3.UP * 0.5)
			car.look_at(car.global_position + track.global_transform.basis * forward,
				Vector3.UP)
			for i in 20:
				await physics_frame

			# From just before it sets off until well after it has arrived.
			var seconds := trap.dwell - 0.3
			var highest := 0.0
			var inside := 0
			var off_road := 0
			for i in int((trap.travel + 1.3) * 60.0):
				seconds += 1.0 / 60.0
				track.set_race_time(seconds)
				if float(trial[3]) > 0.0:
					car._speed = float(trial[3])
				await physics_frame
				var local := track.global_transform.affine_inverse() * car.global_position
				var from_middle := local - here
				highest = maxf(highest, from_middle.y)
				if not car.on_the_road():
					off_road += 1
				# The car's middle within the barrier, across and along.
				if (absf(from_middle.dot(right) / half_width - trap.lateral_at(seconds))
						< trap.half_span and absf(from_middle.dot(forward)) < trap.length * 0.5):
					inside += 1
			var local := track.global_transform.affine_inverse() * car.global_position
			print("crossing in %.1f s, %s: ends %.1f m along and %+.2f across, "
				% [travel, trial[0], (local - here).dot(forward),
					(local - here).dot(right) / half_width]
				+ "highest %.2f m off the road, %d steps off it, %d inside the barrier"
				% [highest, off_road, inside])
			if highest > 0.3:
				print("  a car %s was lifted off the road" % trial[0])
				_faults += 1
			if off_road > 0:
				print("  a car %s was put somewhere that is not the road" % trial[0])
				_faults += 1
			if inside > 0:
				print("  the trap passed into a car %s" % trial[0])
				_faults += 1
	trap.travel = tuned


## Aim a car at a trap from 26 m back, boosted and coasting, and let it arrive.
## Returns the speed and boost before and after, as barrier_layout does.
func _run_at(
	car: Car, track: Track, row: TrackFeatures.Placement, lateral: float
) -> Array:
	var curve := track.curve()
	var at: float = maxf(row.centre() - 26.0, 1.0)
	var here: Vector3 = curve.sample_baked(at)
	var ahead: Vector3 = curve.sample_baked(row.centre())
	var forward := ahead - here
	forward.y = 0.0
	var right := forward.normalized().cross(Vector3.UP)

	car.frozen = false
	car.engine_braking = 0.0
	car.reset_motion()
	car.global_position = track.global_transform * (
		here + right * (lateral * track.half_width_at(at))
		+ Vector3.UP * (car.wheel_radius + 0.1))
	car.look_at(track.global_transform * (
		ahead + right * (lateral * track.half_width_at(row.centre()))),
		Vector3.UP)
	car._speed = car.max_speed
	car.boost()
	var start := car.global_position
	var run: float = 26.0 + row.length + 6.0
	var before := car._speed
	var boost_before := car.boost_amount()
	var first_hit := before
	for i in 110:
		await physics_frame
		if first_hit == before and car._speed < before - 0.01:
			first_hit = car._speed
		if car.global_position.distance_to(start) > run:
			break
	return [before, first_hit, boost_before, car.boost_amount()]


## The narrowest the widest way past a trap gets, anywhere it goes, in metres.
func _narrowest_way_past(
	layout: TrackLayout, features: TrackFeatures, trap: TrackFeatures.Placement
) -> float:
	var half_width := layout.half_width_at(trap.centre())
	var narrowest := INF
	for at in trap.sweep(features.sweep_step / half_width):
		var widest := 0.0
		for gap in features.gaps_at(layout, trap.centre(), null, {trap: at}):
			widest = maxf(widest, (gap.y - gap.x) * half_width)
		narrowest = minf(narrowest, widest)
	return narrowest
