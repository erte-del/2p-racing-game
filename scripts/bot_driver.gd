class_name BotDriver
extends RefCounted

## A computer driver: it plans a line round a track, and then drives the car
## down it with the pedals and the wheel.
##
## Handed to a car as its `driver`, which the car asks every step for throttle
## and steering the way it would otherwise read the keys. That is the whole of
## the bot's reach into the car. It cannot set the car's speed or turn its body;
## it can only ask for full throttle, or brake, or so much lock, and the car
## answers that with the same easing, grip and ceiling a player's keys get. A
## bot that is too slow has to find a better line, not a bigger engine.
##
## The line is worked out once, from the road, when the driver is made. Nothing
## about it is written down anywhere, so a track moved or a car retuned is a new
## line the next time a race starts rather than a stale one from a file:
##
## - The road is sampled every `Track.sample_step` metres: its middle, which way
##   is right, and how wide it is.
## - Every barrier that stands still narrows the road to the gap the bot means
##   to take past it, and every boost pad it means to take narrows the road to
##   the pad. Traps move, so they are left to the driving rather than the plan.
## - The line is relaxed inside those limits until it bends as little as it
##   can, which is what a racing line is: wide in, clip the inside, wide out.
## - What each bend in that line allows is read off the car itself -
##   `Car.turn_radius_at()` says what corner a speed can hold - and walked
##   backwards from every bend at the car's own braking, so it is slowing for a
##   corner before it gets there rather than in it.
##
## Driving it is chasing a point a little way down the line, with the steering
## that would put the car's path through it, and the throttle or brake that
## keeps it under what the line allows there.
##
## How good it is, is one number, `difficulty`, from 0 to 1. It sets how close
## to the kerb the line runs, how near the car's limit it takes a corner, how
## late it brakes, and whether it goes out of its way for a pad or a slipstream.
## One number rather than a table, so it can be turned up or down by feel.

## How far from the edge of the road the middle of the car is kept, in metres,
## at difficulty 0 and 1. The car is 2.06 m wide, so at 1 there is a hand's
## width between its side and the kerb.
const MARGIN := Vector2(1.9, 1.3)
## How much of the tightest corner a speed can hold the line is allowed to
## ask of it. Under one because the car does not arrive at a corner already
## turning: the slide it gathers on the way in costs some of the circle.
const CORNER := Vector2(0.45, 0.97)
## How much of the car's own braking it plans to use.
const DECEL := Vector2(0.4, 0.85)
## How quickly it closes on the line when it is off it, and how quickly it
## turns to the angle that does that, both in seconds.
const RETURN := 0.45
const TURN_IN := 0.18
## How far ahead in time it steers for, in seconds: about how long the car
## takes to answer the wheel.
const LAG := 0.15
## From what difficulty it goes out of its way for a pad, and for the other
## car's slipstream.
const PADS_FROM := 0.25
const SLIPSTREAM_FROM := 0.5
## How far ahead it starts reading a moving trap, in metres.
const TRAP_LOOK := 45.0
## How much room the car is given either side inside a gap, beyond its own
## half width, in metres.
const GAP_ROOM := 0.35
const CAR_HALF_WIDTH := 1.03
const CAR_HALF_LENGTH := 2.44
## How long with no progress before it asks to be put back, in seconds, the way
## a player would press the key.
## How many laps it may practise before it races, how much slower each one
## takes a stretch it could not hold, and how far back from the trouble that
## starts, in seconds at top speed.
const PRACTICE_LAPS := 8
const CAUTION_STEP := 0.96
## How much room the line is moved away from a side it went wide on, in
## metres a lap.
const TIGHTEN := 0.2
const CAUTION_BACK := 0.6
## The least of its speed practice may take away anywhere. A stretch that still
## cannot be held at half speed is not one more practice will fix.
const CAUTION_FLOOR := 0.5
## How far past the room the line had the copy may go before that counts as
## trouble, in metres, and the longest a practice lap may take, in steps.
const PRACTICE_SLACK := 0.3
const PRACTICE_GRACE := 0.4
## How close to a barrier the copy may come before that counts as hitting it,
## in metres.
const CLIP_MARGIN := 0.15
const PRACTICE_STEPS := 60 * 240
const STUCK_AFTER := 3.0
const LOST_AFTER := 2.0

## How good it is, from 0 to 1. Read when the line is planned, so changing it
## means planning again.
var difficulty := 1.0
## The race clock, set by the race every step. The traps run on it, and a bot
## that is to get past one has to know where it will be.
var race_time := 0.0
## The other car, if there is one: to be drafted behind, and not driven into.
var rival: Car

var _track: Track
var _step := 2.5
var _count := 0
## Per sample of the road, in world space: its middle, which way is right,
## flat, and how far either side of the middle the car may go, in metres.
var _centre := PackedVector3Array()
var _right := PackedVector3Array()
var _half := PackedFloat32Array()
var _lo := PackedFloat32Array()
var _hi := PackedFloat32Array()
## The line: how far right of the middle it runs at each sample, in metres, and
## where that is in the world.
var _lateral := PackedFloat32Array()
var _line := PackedVector3Array()
## How fast the line turns at each sample, in radians a metre, left positive.
var _bend := PackedFloat32Array()
## The fastest the line can be taken at each sample, in m/s. INF where nothing
## ahead asks the car to slow down.
var _limit := PackedFloat32Array()
## What each bend allows on its own, before braking for the next one, and how
## much of that practice has decided to trust, as a fraction.
var _corner := PackedFloat32Array()
var _caution := PackedFloat32Array()
## Whether there is road under each sample, and how many laps practice took.
var _ground := PackedByteArray()
## Which sides of the road a barrier hems the line in on at each sample: 1 on
## the left, 2 on the right. Only a barrier is hit by the corner of a car
## swinging out; the kerb has the rails beyond it and room to spare.
var _hemmed := PackedByteArray()
## Every pad, for practice to be boosted by.
var _pads: Array[TrackFeatures.Placement] = []
## Every barrier that stands still, for practice to drive the copy past.
var _standing: Array[TrackFeatures.Placement] = []
var _laps_practised := 0
## Samples that are part of a jump. Nothing is braked for on one: a car short of
## its speed at the lip does not reach the far side.
var _airborne := PackedByteArray()
var _traps: Array[TrackFeatures.Placement] = []

## Which sample the car is at, and the furthest it has got.
var _at := 0
var _furthest := 0
var _since_progress := 0.0
var _off_road_for := 0.0
var _wants_reset := false
## The lock asked for on the last step, for working out where the car is
## about to be.
var _last_steer := 0.0


func _init(track: Track, car: Car, how_good := 1.0) -> void:
	_track = track
	difficulty = clampf(how_good, 0.0, 1.0)
	plan(car)


## Work the line out again, for the car as it is tuned now.
func plan(car: Car) -> void:
	_step = _track.sample_step
	_count = int(floor(_track.length() / _step)) + 1
	_sample_the_road()
	_mark_the_jumps()
	_lateral = PackedFloat32Array()
	_lateral.resize(_count)
	_relax(PackedInt32Array([16, 8, 4, 2, 1]), 120)
	_narrow_for_the_furniture()
	_relax(PackedInt32Array([8, 4, 2, 1]), 160)
	_build_line()
	_set_the_limits(car)
	_practise(car)
	reset_progress()


## Forget where the car was. For when it has been picked up and put down
## somewhere else - back on the line, or back at a checkpoint.
func reset_progress() -> void:
	_at = 0
	_furthest = 0
	_since_progress = 0.0
	_off_road_for = 0.0
	_wants_reset = false


## Whether the car is stuck or lost and wants putting back at its last
## checkpoint. The race decides what that means, the way it does for a player
## pressing the key; the bot only says it would press it.
func wants_reset() -> bool:
	return _wants_reset


## How far along the line the car is, in metres.
func progress() -> float:
	return float(_at) * _step


## How many laps of practice it took to get a lap it could drive.
func laps_practised() -> int:
	return _laps_practised


## The line, in world space, for anything that wants to draw or check it.
func line() -> PackedVector3Array:
	return _line


## The speed the line allows at a distance along it, in m/s.
func limit_at(offset: float) -> float:
	return _limit[clampi(int(offset / _step), 0, _count - 1)]


## Throttle and steering for this step, -1 to 1 each: what the car asks of
## whatever is driving it.
func controls(car: Car, delta: float) -> Vector2:
	if _count < 4:
		return Vector2.ZERO
	_follow(car.global_position, delta, car.frozen,
		car.is_on_floor() and not car.on_the_road(), car.is_on_floor())
	return _command(car, car.global_position, _travel(car.global_transform, car.drift()),
		car.speed(), car.is_on_floor())


## Which way a car is actually going across the ground: its nose, turned back
## by however far it is sliding.
func _travel(at: Transform3D, drift: float) -> Vector3:
	var travel := (-at.basis.z).rotated(Vector3.UP, drift)
	travel.y = 0.0
	return travel.normalized() if travel.length_squared() > 0.0001 else Vector3.FORWARD


## The pedals and the wheel for a car at `here`, going `travel` at `speed`.
## The same whether the car is the real one or a copy being rehearsed on.
func _command(car: Car, here: Vector3, travel: Vector3, speed: float,
		grounded: bool) -> Vector2:
	# Steered from where the car will be once the wheel has answered, rather
	# than from where it is. The lock eases in over a tenth of a second and the
	# travel follows the nose a moment after that, so a driver steering for
	# where the car is now is steering for a car that has already moved on.
	# Where it will be is worked out from what it is doing: going the way it
	# travels, at the speed it is going, turning as hard as the lock the wheel
	# has actually reached turns it - not the lock last asked for, which it
	# may be a tenth of a second from reaching.
	var going := maxf(speed, 0.0)
	var turning := 0.0
	if going > 0.5:
		turning = car.steering() * going / car.turn_radius_at(speed)
	var soon := here + travel.rotated(Vector3.UP, turning * LAG * 0.5) * going * LAG
	var heading := travel.rotated(Vector3.UP, turning * LAG)

	# Where along the line that is, and what the line is doing there.
	var at := minf(float(_at) + going * LAG / _step, float(_count - 2))
	var i := int(at)
	var tangent := _line[i + 1] - _line[i]
	tangent.y = 0.0
	tangent = tangent.normalized() if tangent.length_squared() > 0.0001 else heading
	var right := tangent.cross(Vector3.UP)
	var wanted := _lateral_for(at + 1.0, here, travel, speed)
	var off := (soon - _point(at, wanted)).dot(right)

	# Followed rather than chased. A driver aiming at a point further down the
	# line cuts every bend by about as far ahead as it looks, and through a
	# gap a hand's width wider than the car that is a barrier. So the bend of
	# the line is steered for as it is, and on top of that the car is turned
	# back towards the line - at an angle that closes how far off it is in
	# RETURN seconds - and brought round to that angle in TURN_IN seconds.
	var steer := 0.0
	if going < 1.0:
		var to_line := _point(at + 4.0, wanted) - here
		to_line.y = 0.0
		if to_line.length_squared() > 0.01:
			steer = signf(travel.signed_angle_to(to_line, Vector3.UP))
	else:
		var back := atan2(off, going * RETURN)
		var pointing := tangent.signed_angle_to(heading, Vector3.UP)
		var turn_rate := going * _bend[i] + (back - pointing) / TURN_IN
		# Steering is a radius in this car, so the lock that makes a bend is
		# the car's radius over the bend's.
		steer = turn_rate / going * car.turn_radius_at(speed)
	_last_steer = clampf(steer, -1.0, 1.0)

	# Under what the line allows over the stretch the car will cover before
	# the brakes bite, with the throttle; over it, braking, harder the further
	# over it is.
	var reach := int(ceil(going * 0.2 / _step)) + 1
	var allowed := INF
	for k in range(_at, mini(_at + reach + 1, _count)):
		allowed = minf(allowed, _limit[k])
	var throttle := 1.0
	if not grounded:
		# Nothing to push against, and a car in the air keeps what it left
		# the ground with. The throttle held is the landing already driven.
		throttle = 1.0
	elif speed > allowed + 0.4:
		throttle = -clampf((speed - allowed) / 1.5, 0.3, 1.0)
	elif speed > allowed - 0.4:
		throttle = 0.0
	# Asking for more lock than there is means the corner is too fast for
	# the car as it is going, whatever the plan said.
	if absf(steer) > 1.2 and speed > 8.0 and grounded:
		throttle = minf(throttle, -0.6)
	return Vector2(throttle, _last_steer)


# --- where the car is ---------------------------------------------------

## Keep track of which sample the car is at, and notice when it is going
## nowhere.
func _follow(here: Vector3, delta: float, frozen: bool, off_road: bool,
		grounded := true) -> void:
	var best := _at
	var nearest := INF
	for i in range(maxi(_at - 4, 0), mini(_at + 24, _count)):
		var d := here.distance_squared_to(_centre[i])
		if d < nearest:
			nearest = d
			best = i
	# Nowhere near where it was: put back at a checkpoint, or on the line.
	# Searched the whole way round rather than near where it was, and in three
	# dimensions, so a car under an overpass is not found on the bridge.
	# Only with the car on the ground: in the air over a jump the road it took
	# off from falls away beneath it, and the nearest road to a car high in
	# the air can be some other part of the course altogether.
	if grounded and sqrt(nearest) > _half[best] + 8.0:
		for i in _count:
			var d := here.distance_squared_to(_centre[i])
			if d < nearest:
				nearest = d
				best = i
	_at = best

	if frozen:
		_since_progress = 0.0
		_off_road_for = 0.0
		return
	if _at > _furthest:
		_furthest = _at
		_since_progress = 0.0
	else:
		_since_progress += delta
	_off_road_for = _off_road_for + delta if off_road else 0.0
	_wants_reset = _since_progress > STUCK_AFTER or _off_road_for > LOST_AFTER
	if _wants_reset:
		# Asked once. The race will have put it somewhere else by the next step
		# it is asked, and the count starts again from there.
		_since_progress = 0.0
		_off_road_for = 0.0
		_furthest = 0


## Where to aim across the road at a sample, in metres right of the middle:
## the line, unless a trap or the other car is in the way of it.
func _lateral_for(at: float, here: Vector3, travel: Vector3, speed: float) -> float:
	var i := clampi(int(at), 0, _count - 1)
	var lateral := _lateral[i]
	var dodge := _dodge_the_traps(i, speed)
	if not is_nan(dodge):
		return dodge
	if rival != null:
		lateral = _around_the_rival(i, lateral, here, travel, speed)
	return clampf(lateral, _lo[i], _hi[i])


## If a trap ahead will be across the line when the car gets to it, the middle
## of the way past it that is nearest the line instead, in metres. NAN if not.
func _dodge_the_traps(i: int, speed: float) -> float:
	var offset := float(_at) * _step
	for trap in _traps:
		var to_go := trap.centre() - offset
		if to_go < -3.0 or to_go > TRAP_LOOK:
			continue
		# Only once the aim point has reached the run in to it: the line
		# before that is still the line.
		if float(i) * _step < trap.offset - 20.0:
			continue
		var row := clampi(int(trap.centre() / _step), 0, _count - 1)
		var half := maxf(_half[row] + _margin(), 0.001)
		var arrive := race_time + maxf(to_go, 0.0) / maxf(speed, 8.0)
		# Where it will be as the car arrives and as it leaves, since a car
		# is not a point and a trap does not wait.
		var open := _open_through(trap, row, [arrive - 0.25, arrive, arrive + 0.35])
		var mine := _lateral[row]
		var clear := _inside(open, mine, half)
		if clear:
			return NAN
		var nearest := NAN
		for gap in open:
			var middle := (gap.x + gap.y) * 0.5 * half
			if is_nan(nearest) or absf(middle - mine) < absf(nearest - mine):
				nearest = middle
		return nearest
	return NAN


## The ways past a trap that stay open across all of the given moments, as
## laterals, with nothing else on the road moved.
func _open_through(trap: TrackFeatures.Placement, row: int, moments: Array) -> Array[Vector2]:
	var open: Array[Vector2] = [Vector2(-1.0, 1.0)]
	var layout := _track.layout()
	for when: float in moments:
		var gaps := _track.features().gaps_at(
			layout, trap.centre(), null, {trap: trap.lateral_at(when)})
		var kept: Array[Vector2] = []
		for a in open:
			for b in gaps:
				var both := Vector2(maxf(a.x, b.x), minf(a.y, b.y))
				if both.y > both.x:
					kept.append(both)
		open = kept
	return open


## Whether a car centred `lateral` metres right of the middle fits inside one
## of the gaps, given the road's half width.
func _inside(gaps: Array[Vector2], lateral: float, half: float) -> bool:
	var room := (CAR_HALF_WIDTH + GAP_ROOM) / half
	var at := lateral / half
	for gap in gaps:
		if at - room >= gap.x and at + room <= gap.y:
			return true
	return false


## Tuck in behind the other car on a straight, and go round it rather than
## into it anywhere.
func _around_the_rival(i: int, lateral: float, here: Vector3, forward: Vector3,
		speed: float) -> float:
	var to_rival := rival.global_position - here
	var along := to_rival.dot(forward)
	if along <= 0.0 or along > rival.slipstream_range:
		return lateral
	var right := _right[i]
	var theirs := (rival.global_position - _centre[i]).dot(right)
	var closing := speed - rival.speed()
	if along < 10.0 and closing > 0.5 and absf(theirs - lateral) < 2.6:
		# About to run into it: out to whichever side of it has more road.
		var left_room := theirs - _lo[i]
		var right_room := _hi[i] - theirs
		return theirs + 2.8 if right_room > left_room else theirs - 2.8
	if difficulty >= SLIPSTREAM_FROM and along > 5.0 and _straight_ahead(i, 30.0):
		return theirs
	return lateral


func _straight_ahead(i: int, metres: float) -> bool:
	for k in range(i, mini(i + int(metres / _step) + 1, _count)):
		if not is_inf(_limit[k]):
			return false
	return true


# --- planning the line --------------------------------------------------

func _sample_the_road() -> void:
	_centre.resize(_count)
	_right.resize(_count)
	_half.resize(_count)
	_lo.resize(_count)
	_hi.resize(_count)
	for i in _count:
		_centre[i] = _track.centre_at(float(i) * _step)
	var margin := _margin()
	for i in _count:
		var ahead := _centre[mini(i + 1, _count - 1)] - _centre[maxi(i - 1, 0)]
		ahead.y = 0.0
		_right[i] = (ahead.normalized().cross(Vector3.UP)
			if ahead.length_squared() > 0.0001 else Vector3.RIGHT)
		_half[i] = _track.half_width_at(float(i) * _step)
		var room := maxf(_half[i] - margin, 0.0)
		_lo[i] = -room
		_hi[i] = room


func _margin() -> float:
	return lerpf(MARGIN.x, MARGIN.y, difficulty)


## Every sample on a jump, ramp to landing, so the plan neither steers across
## one nor brakes on one.
func _mark_the_jumps() -> void:
	_airborne = PackedByteArray()
	_airborne.resize(_count)
	_ground = PackedByteArray()
	_ground.resize(_count)
	_ground.fill(1)
	var layout := _track.layout()
	if layout == null:
		return
	for i in _count:
		var k := clampi(int(float(i) * _step / layout.step), 0, layout.road_present.size() - 1)
		if not layout.road_present.is_empty():
			_ground[i] = layout.road_present[k]
	for piece in layout.pieces:
		if piece.kind != TrackLayout.JUMP:
			continue
		for i in range(int(piece.start_offset / _step), mini(int(piece.end_offset / _step) + 1, _count)):
			_airborne[i] = 1


## Narrow the road to the gap the car will take past every barrier that stands
## still, and to every pad worth taking.
##
## A gap is chosen where a run of blocked road begins, nearest the line as it
## is, and then held for as long as the road stays blocked: a fork's divider is
## seventy metres long, and a car that picked the other lane halfway down it
## would pick the divider.
func _narrow_for_the_furniture() -> void:
	var features := _track.features()
	var layout := _track.layout()
	if features == null or layout == null:
		return
	# Traps are left out of the plan. Where one will be is a question of when
	# the car gets there, which the plan does not know.
	var standing: Array[TrackFeatures.Placement] = []
	_standing = standing
	_traps.clear()
	for placement in features.placements:
		if placement.kind == TrackFeatures.TRAP:
			_traps.append(placement)
		elif placement.kind == TrackFeatures.OBSTACLE:
			standing.append(placement)
	_pads = features.of_kind(TrackFeatures.BOOST_PAD)
	var pads: Array = _pads if difficulty >= PADS_FROM else []

	var lo := _lo.duplicate()
	var hi := _hi.duplicate()
	_hemmed = PackedByteArray()
	_hemmed.resize(_count)
	var held := Vector2.ZERO
	var holding := false
	var room := CAR_HALF_WIDTH + GAP_ROOM
	for i in _count:
		var gaps := _gaps_for_the_car(standing, float(i) * _step)
		if gaps.size() == 1 and gaps[0].x <= -1.0 and gaps[0].y >= 1.0:
			holding = false
			continue
		var half := maxf(_half[i], 0.001)
		var mine := _lateral[i] / half
		var chosen := Vector2.ZERO
		var best := -INF
		for gap in gaps:
			var score := 0.0
			if holding:
				# Most in common with the gap already being driven through.
				score = minf(gap.y, held.y) - maxf(gap.x, held.x)
			else:
				score = -absf(clampf(mine, gap.x, gap.y) - mine)
				if _pad_in(pads, gap, float(i) * _step):
					score += 1.0
			if score > best:
				best = score
				chosen = gap
		held = chosen
		holding = true
		if chosen.x > -1.0:
			lo[i] = maxf(lo[i], chosen.x * half + room)
			_hemmed[i] |= 1
		if chosen.y < 1.0:
			hi[i] = minf(hi[i], chosen.y * half - room)
			_hemmed[i] |= 2

	for pad: TrackFeatures.Placement in pads:
		for k in range(int(pad.offset / _step), mini(int((pad.offset + pad.length) / _step) + 1, _count)):
			var from := (pad.lateral - pad.half_span * 0.6) * _half[k]
			var to := (pad.lateral + pad.half_span * 0.6) * _half[k]
			# Only where the pad sits inside what the barriers leave: a pad
			# behind a barrier is not worth the barrier.
			if maxf(lo[k], from) <= minf(hi[k], to):
				lo[k] = maxf(lo[k], from)
				hi[k] = minf(hi[k], to)

	for k in _count:
		if lo[k] > hi[k]:
			var middle := (lo[k] + hi[k]) * 0.5
			lo[k] = middle
			hi[k] = middle
	_lo = lo
	_hi = hi


## The ways past everything standing on the road at an offset, as laterals,
## for a car whose middle is there. A car is not a point: it is alongside a
## barrier from half its length before the barrier to half its length after,
## and all of that time it has to be in the gap. Asked of the placements
## rather than of TrackFeatures.gaps_at, which is about the road at one
## offset - and a barrier shorter than the step between samples can sit
## between two of them and never be asked about at all.
func _gaps_for_the_car(standing: Array[TrackFeatures.Placement], offset: float) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	for placement in standing:
		if (offset < placement.offset - CAR_HALF_LENGTH
				or offset > placement.offset + placement.length + CAR_HALF_LENGTH):
			continue
		spans.append(Vector2(placement.lateral - placement.half_span,
			placement.lateral + placement.half_span))
	var open: Array[Vector2] = []
	if spans.is_empty():
		open.append(Vector2(-1.0, 1.0))
		return open
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var edge := -1.0
	for span in spans:
		if span.x > edge:
			open.append(Vector2(edge, span.x))
		edge = maxf(edge, span.y)
	if edge < 1.0:
		open.append(Vector2(edge, 1.0))
	return open


## Whether a pad lies inside a gap, near an offset.
func _pad_in(pads: Array, gap: Vector2, offset: float) -> bool:
	for pad: TrackFeatures.Placement in pads:
		if absf(pad.centre() - offset) < 80.0 and pad.lateral >= gap.x and pad.lateral <= gap.y:
			return true
	return false


## Bend the line as little as the road allows.
##
## Each point is pulled towards where a smooth curve through its neighbours
## would put it - the fourth-order stencil, which is what straightens the
## bending rather than the length - and clamped back inside the road. Done over
## wide neighbours first and near ones last, because a point only moves as far
## as its neighbours tell it to, and a sweep over the nearest ones alone would
## take thousands of passes to carry a corner's line out to where the corner
## begins.
func _relax(spans: PackedInt32Array, passes: int, from := 2, to := -1) -> void:
	from = maxi(from, 2)
	to = _count - 2 if to < 0 else mini(to, _count - 2)
	for span in spans:
		for _sweep in passes:
			for i in range(from, to):
				if _airborne[i] != 0:
					continue
				var a := maxi(i - 2 * span, 0)
				var b := maxi(i - span, 0)
				var c := mini(i + span, _count - 1)
				var d := mini(i + 2 * span, _count - 1)
				var smooth := (-_flat(a) + 4.0 * _flat(b) + 4.0 * _flat(c) - _flat(d)) / 6.0
				var want := (smooth - _flat_centre(i)).dot(_right[i])
				_lateral[i] = clampf(lerpf(_lateral[i], want, 0.6), _lo[i], _hi[i])
			# Over a jump the line stays where it was at the lip: there is
			# no steering in the air worth planning on.
			_hold_over_the_jumps()


func _hold_over_the_jumps() -> void:
	var lip := 0.0
	for i in _count:
		if _airborne[i] == 0:
			lip = _lateral[i]
		else:
			_lateral[i] = clampf(lip, _lo[i], _hi[i])


func _flat(i: int) -> Vector3:
	return _flat_centre(i) + _right[i] * _lateral[i]


func _flat_centre(i: int) -> Vector3:
	var c := _centre[i]
	return Vector3(c.x, 0.0, c.z)


func _build_line() -> void:
	_line.resize(_count)
	for i in _count:
		_line[i] = _centre[i] + _right[i] * _lateral[i]
	# Over two samples either side, which is about a car length: the turn
	# between neighbouring samples alone is too small a number to be anything
	# but noise.
	_bend.resize(_count)
	for i in _count:
		var a := _line[maxi(i - 2, 0)]
		var b := _line[i]
		var c := _line[mini(i + 2, _count - 1)]
		var into := b - a
		var out := c - b
		into.y = 0.0
		out.y = 0.0
		var run := (into.length() + out.length()) * 0.5
		if run < 0.001 or into.length_squared() < 0.0001 or out.length_squared() < 0.0001:
			_bend[i] = 0.0
		else:
			_bend[i] = into.signed_angle_to(out, Vector3.UP) / run


## A point on the line between samples, with the lateral given instead of the
## line's own.
func _point(at: float, lateral: float) -> Vector3:
	var i := clampi(int(at), 0, _count - 2)
	var t := clampf(at - float(i), 0.0, 1.0)
	var centre := _centre[i].lerp(_centre[i + 1], t)
	var right := _right[i].lerp(_right[i + 1], t).normalized()
	return centre + right * lateral


## What speed the line can be taken at, everywhere along it.
##
## The corner a speed can hold is the car's own answer, turned round: for a
## bend of radius r, the speed at which turn_radius_at() comes out at r. Past
## fast_turn_radius the car holds the bend at any speed - its circle stops
## growing at top speed, boosted or not - so a gentle bend is no limit at all,
## and a car carrying a pad through one keeps it.
func _set_the_limits(car: Car) -> void:
	_caution = PackedFloat32Array()
	_caution.resize(_count)
	_caution.fill(1.0)
	_read_the_bends(car)
	_brake_for_the_limits(car)


## What every bend in the line allows on its own.
func _read_the_bends(car: Car) -> void:
	_corner = PackedFloat32Array()
	_corner.resize(_count)
	var corner := lerpf(CORNER.x, CORNER.y, difficulty)
	var tight := car.tight_turn_radius
	var fast := car.fast_turn_radius
	for i in _count:
		var r := _radius(i) * corner
		if r >= fast:
			_corner[i] = INF
		else:
			var share := clampf((r - tight) / maxf(fast - tight, 0.001), 0.0, 1.0)
			_corner[i] = maxf(car.max_speed * sqrt(share), 5.0)


## Walk the limits back from every bend at the car's braking, with whatever
## practice has taught about where to be careful laid over them.
##
## A limit practice has put on a straight is a limit at the car's top speed
## scaled down, since there is no corner speed there to scale.
func _brake_for_the_limits(car: Car) -> void:
	_limit = PackedFloat32Array()
	_limit.resize(_count)
	for i in _count:
		var base := _corner[i]
		if _caution[i] < 1.0:
			base = minf(base, car.max_speed) * _caution[i]
		_limit[i] = base
	var decel := car.braking * lerpf(DECEL.x, DECEL.y, difficulty)
	for i in range(_count - 2, -1, -1):
		if _airborne[i] != 0:
			continue
		var after := _limit[i + 1]
		if is_inf(after):
			continue
		var gap := _line[i].distance_to(_line[i + 1])
		_limit[i] = minf(_limit[i], sqrt(after * after + 2.0 * decel * gap))
	# Never below flat out on a jump: short at the lip is short at the landing.
	for i in _count:
		if _airborne[i] != 0:
			_limit[i] = INF


# --- practice -----------------------------------------------------------

## Drive the line on a copy of the car until it can be driven.
##
## A line that bends no tighter than the car can hold is not yet a line the car
## can follow: the lock takes a moment to come on and the grip a moment more to
## take the travel round with it, so a line that swings from one side of the
## road to the other past a row of barriers asks for a car that has already
## turned. What that costs is not something to work out from the shape of the
## line. So the bot finds out the way a player does, by driving it: a lap on a
## copy of the car, through the car's own sums, and wherever the copy leaves the
## room the line had, the stretch before it is taken a little slower on the
## next lap. It stops at a clean lap, or when it has run out of laps.
##
## The copy is never in the world. It has no road under it and nothing to hit,
## which is exactly what makes a practice lap cost a fraction of a second: it
## is the car's steering and speed and nothing else. So what it learns is where
## the car cannot follow the line, and not where it would bounce off a barrier
## - which a line it can follow never meets.
func _practise(car: Car) -> void:
	var copy := car.duplicate() as Car
	var start := car.global_transform
	var reach := int(ceil(car.max_speed * CAUTION_BACK / _step))
	# Where it has been in trouble before, in stretches of four samples.
	var seen := {}
	for lap in PRACTICE_LAPS:
		var trouble := _practice_lap(copy, start)
		_laps_practised = lap + 1
		if trouble.is_empty():
			break
		var first := _count
		var last := 0
		for mark in trouble:
			var i := mark >> 1
			var right := (mark & 1) == 1
			first = mini(first, i)
			last = maxi(last, i)
			# Given more room on the side it went wide on. Slowing down alone
			# cannot fix a line that crosses a gap at an angle: the corner of
			# the car swings out just as far at any speed. From a little
			# before to a little more after, since it is leaving a barrier
			# that the back of a car turning away catches.
			for k in range(maxi(i - 4, 0), mini(i + 7, _count)):
				if right and _hi[k] - TIGHTEN >= _lo[k]:
					_hi[k] -= TIGHTEN
				elif not right and _lo[k] + TIGHTEN <= _hi[k]:
					_lo[k] += TIGHTEN
			# Taken slower only where moving the line has already been tried:
			# a car that could have got through by being put somewhere else
			# should not also pay for it on every lap after.
			if seen.has(i >> 2):
				for k in range(maxi(i - reach, 0), mini(i + 3, _count)):
					_caution[k] = maxf(_caution[k] * CAUTION_STEP, CAUTION_FLOOR)
			seen[i >> 2] = true
			seen[(i >> 2) - 1] = true
			seen[(i >> 2) + 1] = true
		_relax(PackedInt32Array([4, 2, 1]), 40, first - 40, last + 40)
		_build_line()
		_read_the_bends(car)
		_brake_for_the_limits(car)
	copy.free()
	race_time = 0.0
	_last_steer = 0.0


## Whether a car with its middle `along` the course and `across` it, turned
## `angle` from the road's heading, overlaps any barrier near sample `i`.
## Negative for a barrier on its left, positive on its right, zero for none.
##
## In the road's own terms - metres along it and metres across - which treats
## the road as straight for the length of a car. That is near enough: the
## barriers stand on straights, and a car is short next to any bend.
func _clipped(along: float, across: float, angle: float, i: int) -> int:
	var forward := Vector2(cos(angle), -sin(angle)) * CAR_HALF_LENGTH
	var side := Vector2(sin(angle), cos(angle)) * CAR_HALF_WIDTH
	var middle := Vector2(along, across)
	var corners := [middle + forward + side, middle + forward - side,
		middle - forward + side, middle - forward - side]
	var half := _half[i]
	for barrier in _standing:
		if absf(barrier.centre() - along) > barrier.length * 0.5 + CAR_HALF_LENGTH + 1.0:
			continue
		var box := Rect2(
			Vector2(barrier.offset, (barrier.lateral - barrier.half_span) * half),
			Vector2(barrier.length, barrier.half_span * 2.0 * half)).grow(CLIP_MARGIN)
		if _boxes_meet(corners, box):
			return 1 if barrier.lateral * half > across else -1
	return 0


## Whether a turned box, given by its corners, and a square one overlap: the
## separating axis test, over the two axes of each.
func _boxes_meet(corners: Array, box: Rect2) -> bool:
	var square := [box.position, box.position + Vector2(box.size.x, 0.0),
		box.end, box.position + Vector2(0.0, box.size.y)]
	var axes := [Vector2.RIGHT, Vector2.DOWN,
		(corners[0] - corners[2]).normalized(), (corners[0] - corners[1]).normalized()]
	for axis: Vector2 in axes:
		var a := _span(corners, axis)
		var b := _span(square, axis)
		if a.y < b.x or b.y < a.x:
			return false
	return true


func _span(points: Array, axis: Vector2) -> Vector2:
	var lowest := INF
	var highest := -INF
	for point: Vector2 in points:
		var along := point.dot(axis)
		lowest = minf(lowest, along)
		highest = maxf(highest, along)
	return Vector2(lowest, highest)


## One lap on the copy. Returns where it left the room the line had, one for
## each time it did: the sample, doubled, plus one if it went out to the right.
func _practice_lap(copy: Car, start: Transform3D) -> PackedInt32Array:
	var trouble := PackedInt32Array()
	reset_progress()
	race_time = 0.0
	_last_steer = 0.0
	copy.rehearse_from(start)
	var here := start.origin
	var delta := 1.0 / 60.0
	var grace := 0.0
	for step in PRACTICE_STEPS:
		_follow(here, delta, false, false)
		if _at >= _count - 2:
			break
		var i := _at
		var grounded := _ground[i] != 0
		var wanted := _command(copy, here, _travel(copy.transform, copy.drift()),
			copy.speed(), grounded)
		var going := copy.rehearse(wanted.x, wanted.y, grounded, delta)
		here += going * delta
		here.y = _centre[_at].y
		copy.transform.origin = here
		race_time += delta

		if grace > 0.0:
			grace -= delta
			continue
		var across := (here - _centre[i]).dot(_right[i])
		var road := Vector3.UP.cross(_right[i])
		var along := float(i) * _step + (here - _centre[i]).dot(road)
		var angle := road.signed_angle_to(_travel(copy.transform, 0.0), Vector3.UP)
		# Into a barrier, by the car's own shape: a box nearly five metres
		# long at an angle to the road reaches further across it than its
		# width, and a nose clipping a barrier is a barrier hit.
		var hit := _clipped(along, across, angle, i)
		# Over a pad, boosted, the way the car would be: practice that never
		# took a pad would arrive at whatever follows one slower than the
		# race does.
		for pad in _pads:
			if (along >= pad.offset and along <= pad.offset + pad.length
					and absf(across - pad.lateral * _half[i]) <= pad.half_span * _half[i]):
				copy.boost(pad.strength)
		# Off the side of the road, by the middle of the car. The rails are
		# beyond the kerb, and a corner over the kerb is not a mistake.
		var edge := maxf(_half[i] - _margin(), 0.0) + PRACTICE_SLACK
		var left_out := hit < 0 or across < -edge
		var right_out := hit > 0 or across > edge
		if left_out or right_out:
			trouble.append(i * 2 + (1 if right_out else 0))
			# Put back on the line a little further on, pointing down it, at
			# the speed it had, and let alone for a moment to settle. A copy
			# left wide would spend the rest of the lap finding its way back,
			# and one checked again at once would be caught on the same
			# mistake it has just been charged for.
			var on := mini(i + 2, _count - 2)
			var down := _line[on + 1] - _line[on]
			down.y = 0.0
			here = _line[on]
			copy.rehearse_from(Transform3D(
				Basis.looking_at(down.normalized(), Vector3.UP), here), copy.speed())
			grace = PRACTICE_GRACE
	return trouble


## The radius the line bends at, at a sample, across the ground: the tightest
## of the circles through it and its neighbours one, two and three samples
## away. The widest alone reads a quick flick past a barrier as the straight it
## is on, and the nearest alone reads a long corner no better than the wide one.
func _radius(i: int) -> float:
	var tightest := INF
	for span in [1, 2, 3]:
		tightest = minf(tightest, _circle(
			_line[maxi(i - span, 0)], _line[i], _line[mini(i + span, _count - 1)]))
	return tightest


func _circle(a: Vector3, b: Vector3, c: Vector3) -> float:
	a.y = 0.0
	b.y = 0.0
	c.y = 0.0
	var twice_area := absf((b - a).cross(c - a).y)
	if twice_area < 0.0001:
		return INF
	return a.distance_to(b) * b.distance_to(c) * c.distance_to(a) / (2.0 * twice_area)
