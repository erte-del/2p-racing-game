extends SceneTree

# Drive every laid-out track and say how long a lap took.
#   Godot --path . --headless --fixed-fps 60 --script tools/lap_times.gd
#   Godot --path . --headless --fixed-fps 60 --script tools/lap_times.gd -- 0.8333
#   Godot --path . --headless --fixed-fps 60 --script tools/lap_times.gd -- 1.0 res://tracks/acrobatic/a01_lift_off.gd
#
# This is what the medal times are set from. A target has to be a fact about
# the road rather than a number somebody liked the look of, and the only way
# to get one is to drive it - so the same crude driver solo_run uses to prove
# the mode works is pointed at all twenty tracks in turn and timed.
#
# The lap it drives is a bad one. It is held flat out, it steers at a point
# fourteen metres ahead on the centreline rather than taking a line, and it
# gives back speed wherever that point is not straight in front of it. What
# makes it useful is not that it is fast but that it is the same on every
# track: the ratio between its lap and a good one is roughly constant, so one
# authored target - the forty seconds First Light was written around - sets
# the rest.
#
# The optional argument scales the cars' top speed, for asking what a lap
# would have been worth before or after a retune without editing the car.

const LOOK_AHEAD := 14.0
## How far before a ring the driver starts lining up with it. Far enough to
## cross the whole road on a straight, which is what a ring off to one side asks
## a player to do.
const RING_LINE_UP := 90.0
## Give up on a track after this long, so one road that cannot be driven does
## not stop the other nineteen being timed.
const PATIENCE := 60 * 260


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var scale: float = float(args[0]) if not args.is_empty() else 1.0

	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	# Pointed at a scratch file, so timing every track does not write itself
	# into the player's own record of what they have driven.
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times != null:
		times.save_path = "user://times_lap_tool.cfg"
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(times.save_path))
		times.load_times()

	print("driving at %.0f%% of tuned top speed" % (scale * 100.0))
	print("%-4s %-16s %7s %8s %8s" % ["", "track", "metres", "lap", "m/s"])
	var files: Array = TrackRoster.all_files()
	# Named on the command line after the scale, only those: timing all thirty
	# to set the targets of one is several minutes of watching nothing change.
	if args.size() > 1:
		files = args.slice(1)
	for file: String in files:
		settings.track_file = file
		var solo: Node = load("res://scenes/solo.tscn").instantiate()
		root.add_child(solo)
		for i in 10:
			await physics_frame
		var track: Track = solo.get_node("Track")
		var car: Car = solo.get_node("Car")
		car.max_speed *= scale

		var waited := 0.0
		while not solo.get("_running") and waited < 8.0:
			await physics_frame
			waited += 1.0 / 60.0
		var finished := await _drive(solo, track, car)
		var lap: float = solo.get("_time")
		print("%-4d %-16s %7.0f %8s %8.1f"
			% [TrackRoster.index_of(file) + 1, track.definition().track_name, track.length(),
				_clock(lap) if finished else "  -  ", track.length() / maxf(lap, 0.001)])
		solo.queue_free()
		await process_frame

	if times != null:
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(times.save_path))
	quit(0)


## Drive the car round by aiming it a little way further along the centreline,
## flat out where that aim point is straight ahead and slower where it is not.
## The same driver solo_run uses, for the same reason: it is not a good lap,
## but it is the same bad lap on every track.
func _drive(solo: Node, track: Track, car: Car) -> bool:
	var curve := track.curve()
	var to_track := track.global_transform.affine_inverse()
	var stuck := 0.0
	var resets := 0
	var was := -1.0
	for i in PATIENCE:
		if not solo.get("_running"):
			return true
		var offset: float = curve.get_closest_offset(to_track * car.global_position)
		var aim: float = minf(offset + LOOK_AHEAD, track.length())
		var target: Vector3 = _through_the_gap(track, aim, _across(track, offset, car))
		# A ring coming up is aimed at instead: through it is the only way on,
		# and the middle of the road is not through a ring off to one side.
		var ring_lane := _next_ring_lane(track, offset)
		if not is_nan(ring_lane):
			target = track.global_transform * (track.curve().sample_baked(aim)
				+ _right(track, aim) * (ring_lane * track.half_width_at(aim)))
		var forward := -car.global_transform.basis.z
		var wanted := target - car.global_position
		wanted.y = 0.0
		var turn := 0.0
		if wanted.length_squared() > 0.01:
			turn = forward.signed_angle_to(wanted.normalized(), Vector3.UP)
			car.rotate_y(clampf(turn, -0.05, 0.05))
		var pace: float = lerpf(1.0, 0.45, clampf(absf(turn) / 0.55, 0.0, 1.0))
		car._speed = maxf(car._speed, car.max_speed * pace)
		await physics_frame

		if offset - was < 0.5:
			stuck += 1.0 / 60.0
			if stuck > 3.0:
				solo.call("_back_to_checkpoint")
				stuck = 0.0
				resets += 1
				if resets > 20:
					return false
		else:
			stuck = 0.0
			was = offset
	return false


## The lane of the next ring within `RING_LINE_UP` metres ahead, or NAN if
## there is none that close.
func _next_ring_lane(track: Track, offset: float) -> float:
	if track.definition() == null:
		return NAN
	for placement in track.definition().placements:
		if placement.kind != TrackFeatures.RING:
			continue
		var ahead := placement.centre() - offset
		if ahead > 0.0 and ahead < RING_LINE_UP:
			return placement.lateral
	return NAN


## Where on the road to aim, in world space: the middle of whichever way past
## is nearest to where the car already is.
func _through_the_gap(track: Track, at: float, lateral: float) -> Vector3:
	var centre: Vector3 = track.curve().sample_baked(at)
	var lane := 0.0
	var nearest := INF
	for gap in track.features().gaps_at(track.layout(), at):
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


func _clock(seconds: float) -> String:
	return "%.2f" % seconds
