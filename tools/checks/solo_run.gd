extends SceneTree

# Run a track solo, from the line to the flag.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/solo_run.gd
#
# --fixed-fps matters. Without it the loop sleeps to hold sixty ticks a second
# of wall clock, and driving a kilometre of road takes as long as driving a
# kilometre of road; with it the same run takes about a second.
#
# The car is driven by the check rather than by a player: held flat out and
# steered back towards the centreline, which is enough to get round a track
# and nothing like a good lap. What is being asked is not whether it drives
# well but whether the mode works at all - whether the clock starts on GO and
# stops on the line, whether checkpoints bank, whether a reset costs time
# rather than ending the run, and whether a second run is timed afresh.

const LOOK_AHEAD := 14.0


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.track_file = "res://tracks/01_first_light.gd"
		settings.chaos = false
	# Pointed at a scratch file, so a check does not write itself into the
	# player's own record of what they have driven.
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times != null:
		times.save_path = "user://times_solo_check.cfg"
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(times.save_path))
		times.load_times()

	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	for i in 10:
		await physics_frame

	var faults := 0
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	print("%s, %.0f m, %d checkpoints"
		% [track.definition().track_name, track.length(),
			track.checkpoint_offsets().size()])

	if solo.get("_running"):
		print("  the clock was running before GO")
		faults += 1

	# The countdown is on real timers, so this waits it out.
	var waited := 0.0
	while not solo.get("_running") and waited < 8.0:
		await physics_frame
		waited += 1.0 / 60.0
	if not solo.get("_running"):
		print("  the countdown never let the car go")
		faults += 1
		quit(1)
		return
	print("away after %.1f s on the line" % waited)

	var finished := await _drive(solo, track, car)
	if not finished:
		print("  the car never finished the track")
		faults += 1
	var first: float = solo.get("_time")
	print("finished in %s, best now %s"
		% [_clock(first), _clock(solo.get("_best"))])
	print("result on screen: %s" % _result(solo))
	if solo.get("_running"):
		print("  the clock did not stop at the line")
		faults += 1
	if not is_equal_approx(float(solo.get("_best")), first):
		print("  the first run round did not become the best")
		faults += 1
	if solo.get("_next_checkpoint") != track.checkpoint_offsets().size():
		print("  not every checkpoint was banked: %d of %d"
			% [solo.get("_next_checkpoint"), track.checkpoint_offsets().size()])
		faults += 1
	if not solo.get_node("Hud/Result").visible:
		print("  finishing said nothing")
		faults += 1

	# A second run has to be timed from scratch rather than carrying on.
	solo.call("_restart")
	await physics_frame
	if solo.get("_time") > 0.01 or solo.get("_running"):
		print("  restarting did not put the clock back to nothing")
		faults += 1
	if solo.get_node("Hud/Result").visible:
		print("  the last run's result was still on the screen")
		faults += 1
	print("restart puts it back on the line with the clock at %s"
		% _clock(solo.get("_time")))

	# A second run, to see the two ends of what finishing can say. Whichever
	# way round it goes, the result has to measure itself against the first.
	var waited_again := 0.0
	while not solo.get("_running") and waited_again < 8.0:
		await physics_frame
		waited_again += 1.0 / 60.0
	await _drive(solo, track, car)
	var second: float = solo.get("_time")
	var said := _result(solo)
	print("second run %s against a %s best: %s"
		% [_clock(second), _clock(first), said])
	if not (said.contains("BEST BY") or said.contains("OFF THE BEST")):
		print("  the second run was not measured against the first")
		faults += 1
	if float(solo.get("_best")) > minf(first, second) + 0.01:
		print("  the better of the two runs was not kept")
		faults += 1

	# And the run has to have reached the record, not just the screen.
	if times != null:
		var written: float = times.best("res://tracks/01_first_light.gd")
		print("written down: %s" % _clock(written))
		if not is_equal_approx(written, minf(first, second)):
			print("  the best run was not written down")
			faults += 1
		times.load_times()
		if not is_equal_approx(
			times.best("res://tracks/01_first_light.gd"), minf(first, second)):
			print("  the best run did not survive being read back")
			faults += 1
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(times.save_path))

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Drive the car round by aiming it a little way further along the centreline,
## flat out where that aim point is straight ahead and slower where it is not.
##
## Speed is not optional. A car ambling at half throttle cannot clear the hole
## in a jump, falls in, is put back at the checkpoint before it, and ambles at
## the same hole again for as long as anything lets it - so a check that drove
## gently would sit in that loop reporting a broken mode.
func _drive(solo: Node, track: Track, car: Car) -> bool:
	var curve := track.curve()
	var world := track.global_transform
	var to_track := world.affine_inverse()
	var stuck := 0.0
	var resets := 0
	var was := -1.0
	for i in 60 * 150:
		if not solo.get("_running"):
			return true
		var offset: float = curve.get_closest_offset(to_track * car.global_position)
		var aim: float = minf(offset + LOOK_AHEAD, track.length())
		# Aimed through whatever the road leaves open there rather than down
		# the middle of it. Driving the centreline into a fork puts the car
		# nose first into the divider, which is not the track being broken -
		# it is a car refusing to pick a side.
		var target: Vector3 = _through_the_gap(track, aim, _across(track, offset, car))
		var forward := -car.global_transform.basis.z
		var wanted := target - car.global_position
		wanted.y = 0.0
		var turn := 0.0
		if wanted.length_squared() > 0.01:
			turn = forward.signed_angle_to(wanted.normalized(), Vector3.UP)
			# Steer by turning the body towards the aim point, which is what
			# the player's steering does to it without the reaction time.
			car.rotate_y(clampf(turn, -0.05, 0.05))
		# Flat out when the road ahead is straight, backing off as it bends.
		var pace: float = lerpf(1.0, 0.45, clampf(absf(turn) / 0.55, 0.0, 1.0))
		car._speed = maxf(car._speed, car.max_speed * pace)
		await physics_frame

		if offset - was < 0.5:
			stuck += 1.0 / 60.0
			if stuck > 3.0:
				solo.call("_back_to_checkpoint")
				stuck = 0.0
				resets += 1
				if resets > 12:
					print("  the car could not get past %.0f m in twelve tries"
						% offset)
					return false
		else:
			stuck = 0.0
			was = offset
	return false


## Where on the road to aim, in world space: the middle of whichever way past
## is nearest to where the car already is.
func _through_the_gap(track: Track, at: float, lateral: float) -> Vector3:
	var centre: Vector3 = track.curve().sample_baked(at)
	var gaps := track.features().gaps_at(track.layout(), at)
	var lane := 0.0
	var nearest := INF
	for gap in gaps:
		var middle := (gap.x + gap.y) * 0.5
		if absf(middle - lateral) < nearest:
			nearest = absf(middle - lateral)
			lane = middle
	return track.global_transform * (
		centre + _right(track, at) * (lane * track.half_width_at(at)))


## How far across the road the car is, from -1 at the left edge to +1 at the
## right, which is the same way everything on the road is described.
func _across(track: Track, at: float, car: Car) -> float:
	var centre: Vector3 = track.global_transform * track.curve().sample_baked(at)
	var right: Vector3 = track.global_transform.basis * _right(track, at)
	var half: float = maxf(track.half_width_at(at), 0.001)
	return clampf((car.global_position - centre).dot(right.normalized()) / half,
		-1.0, 1.0)


## Which way is right, at a distance along the course, in the track's own space.
func _right(track: Track, at: float) -> Vector3:
	var curve := track.curve()
	var here: Vector3 = curve.sample_baked(at)
	var ahead: Vector3 = curve.sample_baked(minf(at + 2.0, track.length()))
	var forward := ahead - here
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		return Vector3.RIGHT
	return forward.normalized().cross(Vector3.UP)


## The whole of what the finish screen is saying, on one line.
func _result(solo: Node) -> String:
	var parts := PackedStringArray()
	for name in ["Time", "Medal", "Note"]:
		var text: String = solo.get_node("Hud/Result/Box/%s" % name).text
		if not text.is_empty():
			parts.append(text)
	return " / ".join(parts)


func _clock(seconds: float) -> String:
	return "%.2f s" % seconds
