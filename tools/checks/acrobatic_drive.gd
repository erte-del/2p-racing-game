extends SceneTree

# Drive every acrobatic track with the car's own controls, and count the falls.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/acrobatic_drive.gd
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/acrobatic_drive.gd -- res://tracks/acrobatic/a03_swing_out.gd
#
# tools/lap_times.gd is what sets the targets, and it is no use for this: it
# turns the car by rotating it, three radians a second whatever the grip, so it
# comes out of any corner pointing wherever it likes. An acrobatic track is
# mostly about arriving at a ramp straight and lined up, which is exactly what
# that driver gets for free.
#
# So this one presses the keys. Throttle, brake and steering, through the same
# input actions a player's keyboard drives, and through all of the car's own
# grip and drift. It is not a good driver - it looks a little way down the
# road, lines up with a ring when one is coming, and brakes for a bend it can
# see - but it cannot do anything a player cannot, so a ring it keeps falling
# short of is a ring worth looking at.
#
# A fall is the car off the road below the level it left. It is put back at
# its last ring, the way a player pressing R is, and tries again. A track fails
# if any ring takes more than MAX_TRIES, or the lap never finishes.

## How far ahead it aims, in metres, at a standstill and per m/s on top.
const LOOK_NEAR := 9.0
const LOOK_PER_SPEED := 0.45
## How far before a ring it starts lining up with it.
const RING_LINE_UP := 90.0
## How far ahead it starts lining up with the gap in a row of barriers.
const ROW_LOOK := 35.0
## Where it waits for a lift: this far before the foot of the ramp, stopped.
const LIFT_HOLD := 50.0
## How far past the lip a car flat out comes down on a lift, and how long the
## lift has to stay low after that for it to be worth going.
const LIFT_TOUCHDOWN := 15.0
const LIFT_LOW_FOR := 0.8
## How hard it steers for a given angle to its aim, before the input clamps.
const STEER_GAIN := 2.6
## How far down the road it looks for a bend to brake for, and the speed it
## wants through one that turns a radian over that distance.
const BEND_LOOK := 45.0
const BEND_SPEED := 17.0
## Tries at one ring before the track is called undrivable.
const MAX_TRIES := 4
const PATIENCE := 60 * 240


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	settings.damage = false
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times != null:
		times.save_path = "user://times_acrobatic_drive.cfg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
		times.load_times()

	var args := OS.get_cmdline_user_args()
	var files: Array = args if not args.is_empty() else TrackRoster.ACROBATIC_FILES
	var faults := 0
	for file: String in files:
		settings.track_file = file
		var solo: Node = load("res://scenes/solo.tscn").instantiate()
		root.add_child(solo)
		for i in 10:
			await physics_frame
		var waited := 0
		while not solo.get("_running") and waited < 600:
			await physics_frame
			waited += 1
		var result: Dictionary = await _drive(solo)
		_let_go()
		var track: Track = solo.get_node("Track")
		var tries: PackedInt32Array = result["tries"]
		print("%-14s %s in %s, tries per ring %s"
			% [track.definition().track_name,
				"finished" if result["finished"] else "DID NOT FINISH",
				RaceClock.format(solo.get("_time")), Array(tries)])
		if not result["finished"]:
			faults += 1
		for ring in tries.size():
			if tries[ring] > MAX_TRIES:
				print("  ring %d took %d tries" % [ring + 1, tries[ring]])
				faults += 1
		solo.queue_free()
		await process_frame
	if times != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


func _drive(solo: Node) -> Dictionary:
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	var rings := _rings(track)
	var tries := PackedInt32Array()
	tries.resize(rings.size())
	var took_off_at := 0.0
	var airborne := 0
	var stuck := 0
	var was := 0.0
	## The furthest along it has got, and when: a car pinned against a barrier
	## rocks a metre back and forth for ever without getting any further.
	var furthest := 0.0
	var furthest_at := 0
	## The lifts it has set off for, so it does not stop again in front of one
	## it is already on its way to.
	var committed := {}
	## The lift it has set off from the top of, so a lift starting back down
	## under a car already on its way off it does not make it stop again.
	var leaving: TrackFeatures.Placement = null
	for step in PATIENCE:
		if not solo.get("_running"):
			return {"finished": true, "tries": tries}
		var offset := track.offset_of(car.global_position)
		var banked: PackedByteArray = solo.get("_banked")
		var next := banked.find(0)

		# Where to aim: down the road through whatever gap the barriers leave,
		# and across to the next ring or platform when one is close enough to
		# line up for - where it will be when the car gets there, not where it
		# is, since some of them move.
		var speed := car.speed()
		var aim := minf(offset + LOOK_NEAR + speed * LOOK_PER_SPEED, track.length())
		var lane := _gap_lane(track, offset, _across(track, offset, car),
			float(solo.get("_time")), speed)
		var target_ahead := _next_target(track, rings, banked, offset)
		# A row of barriers in the way before the ring or platform comes first:
		# a car lined up with a ring on the far side of a barrier is lined up
		# with the barrier.
		var row_first := false
		for row in track.features().rows():
			if row.offset + row.length > offset and row.offset - offset < ROW_LOOK:
				row_first = target_ahead == null or row.offset < target_ahead.centre()
				break
		if target_ahead != null and not row_first:
			var arrive: float = float(solo.get("_time")) + (target_ahead.centre() - offset) / maxf(speed, 10.0)
			lane = target_ahead.lateral_at(arrive)
		var target := _on_road(track, aim, lane)
		var forward := -car.global_transform.basis.z
		var wanted := target - car.global_position
		wanted.y = 0.0
		var angle := 0.0
		if wanted.length_squared() > 0.01:
			angle = forward.signed_angle_to(wanted.normalized(), Vector3.UP)

		# How much the road bends over the stretch ahead, and how fast that
		# allows. No bend is flat out; a radian over BEND_LOOK is BEND_SPEED.
		var bend := _bend(track, offset, BEND_LOOK)
		var allowed := lerpf(car.max_speed, BEND_SPEED, clampf(bend, 0.0, 1.0))

		# Lifts: wait before the ramp until setting off lands it on the lift
		# while the lift is low, and once on it, stop and wait for the top.
		var now: float = solo.get("_time")
		var hold := false
		var riding := _lift_at(track, offset) if car.is_on_floor() else null
		if riding != null:
			if riding.lift_at(now) >= riding.lift - 0.05:
				leaving = riding
			hold = riding != leaving
		else:
			leaving = null
			var lift := _lift_ahead(track, offset, committed)
			if lift != null:
				hold = true
				var ramp := lift.offset - track.platform_start - track.ramp_length
				var arrive := _seconds_to_cover(ramp - offset + track.ramp_length + LIFT_TOUCHDOWN, car)
				if (speed < 0.5 and lift.lift_at(now + arrive) < 0.01
						and lift.lift_at(now + arrive + LIFT_LOW_FOR) < 0.01):
					committed[lift] = true
					hold = false
		if hold:
			# Waiting is not being stuck.
			furthest_at = step

		_let_go()
		if hold and car.is_on_floor():
			if angle > 0.02:
				Input.action_press("p1_steer_left", clampf(angle * STEER_GAIN, 0.0, 1.0))
			elif angle < -0.02:
				Input.action_press("p1_steer_right", clampf(-angle * STEER_GAIN, 0.0, 1.0))
			if speed > 0.3:
				Input.action_press("p1_brake")
		elif car.is_on_floor():
			if angle > 0.02:
				Input.action_press("p1_steer_left", clampf(angle * STEER_GAIN, 0.0, 1.0))
			elif angle < -0.02:
				Input.action_press("p1_steer_right", clampf(-angle * STEER_GAIN, 0.0, 1.0))
			if speed > allowed + 1.5:
				Input.action_press("p1_brake")
			else:
				Input.action_press("p1_accelerate")
		else:
			Input.action_press("p1_accelerate")
		await physics_frame

		# A fall: off the ground long enough to be flying, and come down lower
		# than it went up, on something that is not road.
		if not car.is_on_floor():
			if airborne == 0:
				took_off_at = car.global_position.y
			airborne += 1
		else:
			if airborne > 20 and not car.on_the_road() and car.global_position.y < took_off_at - 2.0:
				committed.clear()
				_fell(solo, tries, banked.find(0))
				furthest = track.offset_of(car.global_position)
				furthest_at = step
			airborne = 0
		# Stranded on the grass, or no further along in three seconds: put back,
		# the way a player would.
		if car.is_on_floor() and not car.on_the_road():
			stuck += 1
		else:
			stuck = 0
		if offset > furthest + 3.0:
			furthest = offset
			furthest_at = step
		if stuck > 120 or step - furthest_at > 180:
			committed.clear()
			_fell(solo, tries, banked.find(0))
			stuck = 0
			furthest = track.offset_of(car.global_position)
			furthest_at = step
		was = offset
	return {"finished": false, "tries": tries}


## Seconds to cover `metres` from a standstill, flat out on the level.
func _seconds_to_cover(metres: float, car: Car) -> float:
	var reach := car.max_speed * car.max_speed / (2.0 * car.acceleration)
	if metres <= reach:
		return sqrt(2.0 * metres / car.acceleration)
	return car.max_speed / car.acceleration + (metres - reach) / car.max_speed


## A lift whose ramp starts within LIFT_HOLD ahead and that it has not set off
## for yet, or null.
func _lift_ahead(track: Track, offset: float, committed: Dictionary) -> TrackFeatures.Placement:
	for placement in track.features().of_kind(TrackFeatures.PLATFORM):
		if placement.lift <= 0.0 or committed.has(placement):
			continue
		var ramp := placement.offset - track.platform_start - track.ramp_length
		if ramp - offset > 0.0 and ramp - offset <= LIFT_HOLD:
			return placement
	return null


## The lift the car is standing on, or null: there is no road in a lift's hole,
## so a car on the ground along one is on it.
func _lift_at(track: Track, offset: float) -> TrackFeatures.Placement:
	for placement in track.features().of_kind(TrackFeatures.PLATFORM):
		if placement.lift > 0.0 and offset >= placement.offset and offset <= placement.offset + placement.length:
			return placement
	return null


func _fell(solo: Node, tries: PackedInt32Array, ring: int) -> void:
	if ring >= 0 and ring < tries.size():
		tries[ring] += 1
	_let_go()
	solo.call("_back_to_checkpoint")


func _let_go() -> void:
	for action in ["p1_accelerate", "p1_brake", "p1_steer_left", "p1_steer_right"]:
		Input.action_release(action)


## The next unbanked ring or any platform within RING_LINE_UP ahead, nearest
## first, or null.
func _next_target(track: Track, rings: Array[TrackFeatures.Placement],
		banked: PackedByteArray, offset: float) -> TrackFeatures.Placement:
	var best: TrackFeatures.Placement = null
	var candidates: Array[TrackFeatures.Placement] = []
	for i in rings.size():
		if i < banked.size() and banked[i] == 0:
			candidates.append(rings[i])
	candidates.append_array(track.features().of_kind(TrackFeatures.PLATFORM))
	for placement in candidates:
		var ahead := placement.centre() - offset
		if ahead > 0.0 and ahead < RING_LINE_UP and (best == null or placement.centre() < best.centre()):
			best = placement
	return best


## The middle of whichever way past the next row of barriers is nearest the car,
## for the next row within ROW_LOOK ahead - with a trap where it will be when the
## car gets to it - or the middle of the road when there is none.
func _gap_lane(track: Track, offset: float, lateral: float, now: float, speed: float) -> float:
	var row: TrackFeatures.Placement = null
	for candidate in track.features().rows():
		if candidate.offset + candidate.length > offset and candidate.offset - offset < ROW_LOOK:
			row = candidate
			break
	if row == null:
		return 0.0
	var poses := {}
	if row.moves():
		poses[row] = row.lateral_at(now + maxf(row.offset - offset, 0.0) / maxf(speed, 10.0))
	var lane := 0.0
	var nearest := INF
	for gap in track.features().gaps_at(track.layout(), row.centre(), null, poses):
		var middle := (gap.x + gap.y) * 0.5
		if absf(middle - lateral) < nearest:
			nearest = absf(middle - lateral)
			lane = middle
	return lane


## How far across the road the car is, -1 at the left edge to +1 at the right.
func _across(track: Track, at: float, car: Car) -> float:
	var here := track.centre_at(at)
	var ahead := track.centre_at(minf(at + 2.0, track.length()))
	var right := ((ahead - here) * Vector3(1, 0, 1)).normalized().cross(Vector3.UP)
	return clampf((car.global_position - here).dot(right) / maxf(track.half_width_at(at), 0.001), -1.0, 1.0)


func _rings(track: Track) -> Array[TrackFeatures.Placement]:
	var out: Array[TrackFeatures.Placement] = []
	for placement in track.definition().placements:
		if placement.kind == TrackFeatures.RING:
			out.append(placement)
	out.sort_custom(func(a: TrackFeatures.Placement, b: TrackFeatures.Placement) -> bool:
		return a.centre() < b.centre())
	return out


func _on_road(track: Track, at: float, lane: float) -> Vector3:
	var here := track.centre_at(at)
	var ahead := track.centre_at(minf(at + 2.0, track.length()))
	var right := (ahead - here) * Vector3(1, 0, 1)
	right = right.normalized().cross(Vector3.UP) if right.length_squared() > 0.0001 else Vector3.RIGHT
	return here + right * (lane * track.half_width_at(at))


## How far the road turns between here and `over` metres on, in radians.
func _bend(track: Track, offset: float, over: float) -> float:
	var most := 0.0
	var a := _heading(track, offset)
	for step in range(5, int(over), 5):
		var b := _heading(track, minf(offset + float(step), track.length() - 2.0))
		most = maxf(most, absf(angle_difference(a, b)))
	return most


func _heading(track: Track, at: float) -> float:
	var d := track.centre_at(at + 2.0) - track.centre_at(at)
	return atan2(d.x, d.z)
