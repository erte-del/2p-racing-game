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
## line the next time a race starts rather than a stale one from a file. It costs
## half a second to a second and a half depending on the road, which is far too
## much to spend on one frame, so it is worked out a few milliseconds at a time:
## see plan_a_little.
##
## - The road is sampled every `Track.sample_step` metres: its middle, which way
##   is right, and how wide it is.
## - Every barrier that stands still narrows the road to the gap the bot means
##   to take past it, and every boost pad it means to take narrows the road to
##   the pad. Traps move, so they are left to the driving rather than the plan.
## - The line is relaxed inside those limits until it bends as little as it
##   can, which is what a racing line is: wide in, clip the inside, wide out.
## - Where the road forks, both lanes are planned and driven on a copy of the
##   car and the quicker of the two is kept: see _begin_the_lanes.
## - What each bend in that line allows is read off the car itself -
##   `Car.turn_radius_at()` says what corner a speed can hold - and walked
##   backwards from every bend at the car's own braking, so it is slowing for a
##   corner before it gets there rather than in it.
##
## Driving it is chasing a point a little way down the line, with the steering
## that would put the car's path through it, and the throttle or brake that
## keeps it under what the line allows there.
##
## Where there is another car on the road, it is three things at once: something
## to be towed by, something to go round, and something not to drive into. None
## of them is on the plan - the line is the line whoever else is out there - and
## all of them are _around_the_rival's.
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
## How much road either side of a fork a timed lane covers, in metres: the run
## in, where the line has to have crossed to the lane it is taking, and the run
## out, which is long enough that a pad taken in the lane has faded before the
## clock stops. A pad is held at full for a second and a half and bleeds away
## over three more, and carrying that out of the fork is most of what a fast
## lane is worth.
const LANE_BEFORE := 40.0
const LANE_AFTER := 200.0
## How far ahead of the fork the line is relaxed again for a lane, in metres:
## far enough back that the crossing to the lane is a line rather than a swerve
## at the divider.
const LANE_RELAX_IN := 60.0
const LANE_RELAX_OUT := 50.0
## The longest a timed lane may take, in steps, and how many times a lane may
## be given room and driven again before its time is taken as it stands.
##
## A lane is driven the way a lap is: where the copy could not hold the line the
## line is given room there, the stretch before it is taken slower where room
## has already been tried, and the lane is driven again. Without that the
## two lanes are not being compared - the clear one needs no mending and the
## one with the barriers in it does, so the fast lane would be charged for a
## line that the practice laps were going to mend anyway, and would lose every
## fork on every course. It did, before this was here.
##
## What a copy that still cannot hold the line loses is the car's own
## obstacle_scrub, the square hit it charges for a barrier, because what the
## copy has just done is drive into one. A lane that is still being charged
## that after every go is a lane this car cannot thread, which is exactly what
## the timing is for.
const LANE_STEPS := 60 * 20
const LANE_MENDS := 6
## How far ahead it starts reading a moving trap, in metres.
const TRAP_LOOK := 45.0
## How much room the car is given either side inside a gap, beyond its own
## half width, in metres.
const GAP_ROOM := 0.35
const CAR_HALF_WIDTH := 1.03
const CAR_HALF_LENGTH := 2.44
## How far ahead the road has to be straight and clear before the bot will sit
## on the other car's line to be towed down it, in metres.
const TOW_LOOK := 30.0
## How close behind the other car it settles when it cannot get past, measured
## between the two middles. A car length of that is the two cars themselves, so
## what is left is three metres of air - near enough for nearly the whole tow,
## far enough that a metre of overshoot is not a shunt.
const TUCK_IN := CAR_HALF_LENGTH * 2.0 + 3.0
## From how far back it starts going round the other car rather than sitting
## behind it, in metres, and how long it allows for the move: how far ahead the
## road has to keep its room for one to be worth starting at all.
const PASS_FROM := 11.0
const PASS_SECONDS := 2.5
## How far past it the bot has to be before it cuts back in, in metres. A car
## whose nose is level is not past anything, and one that took its own line
## again there would be taking it through the other car's front wing.
const CLEAR_BY := CAR_HALF_LENGTH * 2.0 + 1.5
## How much clear air it wants between the two cars side by side, on top of
## what their shapes need, in metres, and how little of it still counts as
## being in the other car's way.
##
## Two numbers rather than one, and they are not the same number on purpose. A
## hand's width is not enough room to go round in - both cars are steering, and
## two drivers each leaving the other the least they can are two drivers
## touching - but a bot that counted a car most of a lane away as being in its
## way would spend a whole race giving room to somebody who was never there.
const PASS_ROOM := 1.3
const OVERLAP_ROOM := 0.2
## How much further off a barrier than the line itself runs the bot is willing
## to be pushed by the other car, in metres. The line's own room is what the
## practice laps found it could take at speed and on its own; a line shoved
## against that limit by a car alongside is a line nobody rehearsed, and the
## corner of a car turning into a gap reaches further across it than its width.
const BARRIER_ROOM := 0.8
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
## The line as it stood when the road was first narrowed to the furniture, and
## which gap it chose is read off. Kept, because the narrowing is done again for
## every lane of a fork that is timed, and a narrowing that read a line which
## had moved since would choose different gaps somewhere else on the course -
## which is a different plan for a reason that has nothing to do with the fork.
var _narrow_line := PackedFloat32Array()
## The road's own room either side of the middle, before anything standing on
## it narrows that. Kept because the narrowing is done again for every lane of
## a fork that is timed, and a narrowing that started from an already narrowed
## road would narrow it twice.
var _road_lo := PackedFloat32Array()
var _road_hi := PackedFloat32Array()
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
## The fastest the other car lets the bot go this step, in m/s: INF whenever
## there is nothing in the way. Worked out with the steering, in _lateral_for,
## and read by the throttle a few lines later, because they are two halves of
## one decision - a car that has nowhere to go round has to lift, and a car
## that has somewhere does not.
var _hold_back := INF
## Whether it has given up on the stretch ahead having room for both cars and
## is dropping in behind the other one. Sticky, because two cars level with
## each other where only one fits will otherwise each wait for the other to
## yield, and the one that changes its mind every step is the one that does not.
var _giving_way := false
## Which side of the other car it is going round: -1 left, 1 right, 0 not.
## Held for as long as the pass lasts, because the side with more road changes
## as the bot moves into it, and a driver that reads it fresh every step would
## swap sides in front of a car it is overtaking.
var _passing := 0
## How hard the plan is willing to brake, in m/s per second: read off the car
## when the limits are worked out, and used again when the thing to slow for is
## the other car rather than a corner.
var _decel := 20.0
## Every fork on the road, and which side of each one the line takes: 1 for the
## right of the divider, -1 for the left. Empty until the lanes have been timed,
## and read by the narrowing, which otherwise picks the lane with the pad in it.
var _forks: Array[TrackFeatures.Placement] = []
var _lane_for := {}
## The lane trial in progress: which fork, which of its two lanes, what the
## stretch is in samples, and the clock on the copy driving it.
var _fork_at := 0
var _lane_try := 0
var _lane_seconds := Vector2.ZERO
## Whether each of the two lanes came out of its last drive without the copy
## leaving the room the line had, and what each of them left behind.
var _lane_clean := Vector2.ZERO
var _lane_room := [{}, {}]
var _lane_times := {}
var _lane_from := 0
var _lane_to := 0
var _lane_step := 0
var _lane_clock := 0.0
var _lane_here := Vector3.ZERO
var _lane_grace := 0.0
var _lane_trouble := 0
var _lane_marks := PackedInt32Array()
var _lane_mends := 0
var _lane_seen := {}
## How many times the copy left the room the line had on each lane's last
## drive, for lane_choices() to report: a lane that is still being charged for
## a barrier is a lane this car cannot thread.
var _lane_scrapes := {}
## The line as it stood before the lanes were timed, and, for each fork, the
## stretch of line and room the lane that won left behind. Kept rather than
## worked out again afterwards, because a lane is relaxed, mended and relaxed
## again, and one pass of that at the end would not come out where the lane
## that was timed came out.
var _before_the_lanes := PackedFloat32Array()
var _best_lane := {}
var _best_room := {}
## True while a practice lap is being driven. The other car is not on the plan:
## where it happens to be standing during the countdown is not a thing the line
## round the track should have been bent for.
var _rehearsing := false

## Which part of the plan is being worked on. In the order they happen, which is
## also the order plan_a_little walks them in.
enum Stage {
	ROAD,           ## sample the road, and mark the jumps
	RELAX_WIDE,     ## the first, coarse relaxing of the line
	FURNITURE,      ## narrow the road to the gaps and the pads
	RELAX_FINE,     ## relax again inside those limits
	LIMITS,         ## build the line and read what it allows
	LANE_NEXT,      ## set up the next lane of the next fork to be timed
	LANE_RELAX,     ## relax the line into that lane
	LANE_DRIVE,     ## drive a copy of the car through the fork in it
	PRACTICE_LAP,   ## drive a lap of it on a copy of the car
	PRACTICE_MEND,  ## give the line room where the lap could not hold it
	PRACTICE_OVER,  ## a clean lap, or eight of them: put the copy away
	DONE,
}
var _stage := Stage.DONE
## The car the plan is being worked out for, held only while it is being worked
## out. What is read off it here is its tuning, which does not move under a plan;
## where it is standing and how fast it goes are taken once, in start_planning.
var _planning_car: Car

## The relaxing in progress: which spans, how many sweeps of each, over what
## stretch of the line, and how far through. Held here rather than in a loop
## because a relaxing is a thousand sweeps and a frame is worth about five.
var _relax_spans := PackedInt32Array()
var _relax_passes := 0
var _relax_from := 0
var _relax_to := 0
var _relax_span := 0
var _relax_sweep := 0

## The practice lap in progress: the copy of the car driving it, where it started
## and where it has got to, how long it is being left alone for after a mistake,
## which step it is on, where it has left the room the line had, and where it has
## been in trouble on an earlier lap. Same reason: a lap is thousands of steps.
var _copy: Car
var _practice_start := Transform3D.IDENTITY
var _practice_here := Vector3.ZERO
var _practice_grace := 0.0
var _practice_step := 0
var _practice_reach := 0
var _practice_trouble := PackedInt32Array()
var _practice_seen := {}


## A driver with its line begun but not finished. Whoever made it has to carry
## the plan through - a few milliseconds a frame with plan_a_little, which is
## what a race does, or all at once with finish_planning, which is what a check
## or a tool does - before the driver will drive.
func _init(track: Track, car: Car, how_good := 1.0) -> void:
	_track = track
	difficulty = clampf(how_good, 0.0, 1.0)
	start_planning(car)


## A copy of the car left over from a plan that was abandoned half way, which is
## what happens when a race is left during its countdown. Nothing else holds it,
## so nothing else would free it.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _copy != null:
		_copy.free()
		_copy = null


## Work the line out again from the start, for the car as it is tuned now, and
## standing where it stands now. The work itself is plan_a_little's; this only
## says where to begin.
##
## Everything the plan takes off the world rather than off the road is taken
## here, on this one frame, and not as each stage reaches for it. The stages run
## over however many frames the budget spreads them across, and a plan whose
## practice laps started from wherever the car had got to by the time the
## practice stage came round would be a different plan depending on how fast the
## machine was. So a car retuned or moved part way through a plan wants
## start_planning called again; it is not picked up half way.
func start_planning(car: Car) -> void:
	if _copy != null:
		_copy.free()
		_copy = null
	_planning_car = car
	_step = _track.sample_step
	_count = int(floor(_track.length() / _step)) + 1
	# Where the practice laps set off from, and how far back from trouble the
	# caution reaches at this car's top speed.
	_practice_start = car.global_transform
	_practice_reach = int(ceil(car.max_speed * CAUTION_BACK / _step))
	_laps_practised = 0
	_stage = Stage.ROAD
	reset_progress()


## Whether the line is finished and the driver will drive.
func is_planned() -> bool:
	return _stage == Stage.DONE


## Carry the plan on for about `budget` milliseconds, and say whether there is
## more to do. Called once a frame by whatever is waiting for the driver.
##
## Why a budget rather than a thread. The whole of the plan is half a second on
## a short road and a second and a half on the longest, nearly all of it in the
## two relaxings, and on one frame that is a hitch the player sees at the exact
## moment they are watching a countdown. The countdown is three seconds of
## nothing happening, which is more time than the worst road needs, so the work
## goes there - a few milliseconds a frame, finished before GO is said. A thread
## would be quicker, but the practice laps drive a duplicate of the car, and
## duplicating and freeing a node is the main thread's to do; the plan is also
## read off a Curve3D whose baked cache is built the first time it is asked. So
## a thread would mean either proving all of that safe or taking the copy out of
## practice, for a saving nobody can see: the countdown is dead time either way.
##
## The budget is honoured between units of work rather than inside them, so a
## frame overshoots by at most one unit. The units are small on purpose: one
## relaxing sweep is under a millisecond on the longest road in the game, and
## one practice step is a few microseconds.
func plan_a_little(budget: float) -> bool:
	if _stage == Stage.DONE:
		return false
	# A budget of INF is finish_planning asking for no deadline at all, which is
	# worth saying outright: a deadline worked out from INF is whatever int()
	# makes of it rather than a time.
	var deadline := -1
	if is_finite(budget):
		deadline = Time.get_ticks_usec() + int(maxf(budget, 0.0) * 1000.0)
	while _stage != Stage.DONE:
		match _stage:
			Stage.ROAD:
				_sample_the_road()
				_mark_the_jumps()
				_lateral = PackedFloat32Array()
				_lateral.resize(_count)
				_start_relaxing(PackedInt32Array([16, 8, 4, 2, 1]), 120)
				_stage = Stage.RELAX_WIDE
			Stage.RELAX_WIDE:
				while _relax_a_sweep():
					if _out_of_time(deadline):
						return true
				_stage = Stage.FURNITURE
			Stage.FURNITURE:
				_narrow_line = _lateral.duplicate()
				_narrow_for_the_furniture()
				_start_relaxing(PackedInt32Array([8, 4, 2, 1]), 160)
				_stage = Stage.RELAX_FINE
			Stage.RELAX_FINE:
				while _relax_a_sweep():
					if _out_of_time(deadline):
						return true
				_stage = Stage.LIMITS
			Stage.LIMITS:
				_build_line()
				_set_the_limits(_planning_car)
				_begin_the_lanes()
			Stage.LANE_NEXT:
				_next_lane()
			Stage.LANE_RELAX:
				while _relax_a_sweep():
					if _out_of_time(deadline):
						return true
				_build_line()
				_read_the_bends(_planning_car)
				_brake_for_the_limits(_planning_car)
				_begin_a_lane()
				_stage = Stage.LANE_DRIVE
			Stage.LANE_DRIVE:
				while _drive_a_lane_step():
					if _out_of_time(deadline):
						return true
				_end_a_lane()
			Stage.PRACTICE_LAP:
				while _practise_a_step():
					if _out_of_time(deadline):
						return true
				_end_a_practice_lap()
			Stage.PRACTICE_MEND:
				while _relax_a_sweep():
					if _out_of_time(deadline):
						return true
				_build_line()
				_read_the_bends(_planning_car)
				_brake_for_the_limits(_planning_car)
				if _laps_practised >= PRACTICE_LAPS:
					_stage = Stage.PRACTICE_OVER
				else:
					_begin_a_practice_lap()
					_stage = Stage.PRACTICE_LAP
			Stage.PRACTICE_OVER:
				_put_the_copy_away()
				_stage = Stage.DONE
		if _out_of_time(deadline):
			return _stage != Stage.DONE
	return false


## Whether the frame's budget is spent. A deadline below zero is no deadline:
## whoever asked wants the whole of the plan, however long it takes.
func _out_of_time(deadline: int) -> bool:
	return deadline >= 0 and Time.get_ticks_usec() >= deadline


## Finish whatever is left of the plan on this frame, however long that takes.
## For a check or a tool, where a frame of work costs nothing.
func finish_planning() -> void:
	while plan_a_little(INF):
		pass


## Work the line out again, all of it, now.
func plan(car: Car) -> void:
	start_planning(car)
	finish_planning()


## Forget where the car was. For when it has been picked up and put down
## somewhere else - back on the line, or back at a checkpoint.
func reset_progress() -> void:
	_at = 0
	_furthest = 0
	_since_progress = 0.0
	_off_road_for = 0.0
	_wants_reset = false
	_hold_back = INF
	_passing = 0
	_giving_way = false


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
##
## A driver still working its line out asks for nothing, which leaves the car
## coasting. It is not the car's job to wait for its driver, and it is certainly
## not the car's job to finish the plan on the frame it first asks a question -
## that is the hitch this is all here to avoid. Whatever set the race up is what
## has to have the line ready by GO.
func controls(car: Car, delta: float) -> Vector2:
	if _count < 4 or _stage != Stage.DONE:
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
	# And under whatever the car in front leaves it, which _lateral_for has
	# just worked out: the road is not the only thing that can be in the way.
	allowed = minf(allowed, _hold_back)
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
	_hold_back = INF
	var i := clampi(int(at), 0, _count - 1)
	var lateral := _lateral[i]
	var dodge := _dodge_the_traps(i, speed)
	if not is_nan(dodge):
		return dodge
	if rival != null and not _rehearsing:
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


## Tuck in behind the other car on a straight, go round it rather than into it,
## and lift rather than drive into the back of it when there is nowhere to go.
##
## Whether the other car is in the way is a question about where this car
## actually is, not about where its line says it should be. A bot sitting in
## someone's tow is by definition off its own line, and one that asked the line
## would decide the car ahead was three metres away and drive straight through
## it.
##
## Going round is the line moved rather than the line replaced: the bot keeps
## its own line wherever that is already clear of the other car, and is pushed
## off it only by as much as two cars side by side need. A driver that aimed at
## a fixed offset from the other car instead would be steering for wherever the
## other car went, which on a corner is not a racing line at all.
func _around_the_rival(i: int, lateral: float, here: Vector3, forward: Vector3,
		speed: float) -> float:
	var along := (rival.global_position - here).dot(forward)
	# Well clear of it: still out of its air behind, or far enough past it that
	# taking the line again takes it in front of nobody.
	if along > rival.slipstream_range or along < -CLEAR_BY:
		_passing = 0
		_giving_way = false
		return lateral
	var theirs := _rival_lateral()
	var mine := (here - _centre[_at]).dot(_right[_at])
	var apart := _apart_from(forward, PASS_ROOM)
	var room := _corridor(i, speed)
	# Whether the road ahead has room for two cars at all. Where it has not -
	# a fork, a row of barriers, a pinched corner - the car behind is in the
	# other one's way wherever it is across the road, because there is one way
	# through and they are both going to want it. Which of them gives way is
	# settled by which of them is behind: this asks nothing of the car in
	# front, and the driver in front asks nothing of this one.
	var abreast := not is_nan(room.x) and room.y - room.x >= apart
	if abreast:
		_giving_way = false
	elif along > 0.0:
		_giving_way = true
	var in_the_way := (_giving_way
		or absf(theirs - mine) < _apart_from(forward, OVERLAP_ROOM))

	# A move already begun is held to the end of it, out past the other car's
	# tail rather than only past its nose. Held, and not decided afresh every
	# step, because the room either side of a car changes as this one moves
	# into one of them: a driver that picked again each step would swap sides
	# halfway past, and one that stopped the moment it was no longer
	# overlapping would cut straight back into the car it was passing.
	var side := 0
	if abreast and along < PASS_FROM and (_passing != 0 or (along > 0.0 and in_the_way)):
		side = _which_side(room, theirs, mine, _lateral[i], apart, along)
	_passing = side
	if side != 0:
		var keep := (maxf(lateral, theirs + apart) if side > 0
			else minf(lateral, theirs - apart))
		return clampf(keep, room.x, room.y)

	# Behind it with nowhere to go round: sit in its tow rather than drive into
	# the back of it. The speed that leaves is the same sum the line's own
	# limits are walked back with - what the car can brake off in the road it
	# has - against the other car's speed instead of a corner's, so a bot that
	# cannot get by tucks in at its bumper rather than shoving it down the road.
	if in_the_way and (along > 0.0 or _giving_way):
		var spare := along - TUCK_IN
		# Over the room there is: what the car can brake off in it. Under it:
		# under the other car's speed, so the gap opens again rather than
		# staying wherever the shunt left it.
		var over := sqrt(2.0 * _decel * spare) if spare > 0.0 else spare
		_hold_back = maxf(rival.speed() + over, 2.0)

	if (along > TUCK_IN * 0.5 and difficulty >= SLIPSTREAM_FROM
			and _tow_is_clear(i, theirs)):
		return theirs
	return lateral


## Where the other car is across the road, in metres right of the middle,
## measured against the road where it actually is.
##
## Not against the sample this car is steering for. The two cars are up to a
## slipstream's length apart, and a distance across the road taken against a
## sample twenty metres back is a distance across some other part of the road.
func _rival_lateral() -> float:
	var best := _at
	var nearest := INF
	var reach := int(rival.slipstream_range / _step) + 3
	var back := int(CLEAR_BY / _step) + 3
	for k in range(maxi(_at - back, 0), mini(_at + reach, _count)):
		var d := rival.global_position.distance_squared_to(_centre[k])
		if d < nearest:
			nearest = d
			best = k
	return (rival.global_position - _centre[best]).dot(_right[best])


## How far apart two cars have to keep their middles to be side by side without
## touching, in metres.
##
## Their two half widths is only the answer on a straight. A car is twice as
## long as it is wide, so one turned even a little reaches further across the
## road than its width - which is the same thing the practice laps know about
## barriers - and both cars are turning through a corner. So the room asked for
## grows with how far each of them is pointed off the road's own heading.
func _apart_from(forward: Vector3, room: float) -> float:
	var road := Vector3.UP.cross(_right[_at])
	var ours := absf(sin(road.signed_angle_to(forward, Vector3.UP)))
	var nose := -rival.global_transform.basis.z
	nose.y = 0.0
	var theirs := 0.0
	if nose.length_squared() > 0.0001:
		theirs = absf(sin(road.signed_angle_to(nose.normalized(), Vector3.UP)))
	return CAR_HALF_WIDTH * 2.0 + CAR_HALF_LENGTH * (ours + theirs) + room


## Which side of the other car to go down, or 0 for neither: 1 for the right of
## it, -1 for the left.
##
## In order of what it would rather do: the side it is already going down, the
## side of them it is already on, the side its own line is on, and whichever of
## the two has the room. A side it has picked is kept only while the car is
## still on that side of them: a driver that held the side it chose whatever
## happened afterwards would, if the other car crossed in front of it, set off
## for a gap on the far side of that car and steer through it to get there.
func _which_side(room: Vector2, theirs: float, mine: float, line: float,
		apart: float, along: float) -> int:
	var open_left := theirs - room.x >= apart
	var open_right := room.y - theirs >= apart
	# Room on the far side of the other car is not room this car can have.
	# From behind it, either side will do: it crosses behind their tail. Level
	# with them, the only side to be had is the one it is already on, and a
	# driver that went for the other would be steering through them to get
	# there - which is how a bot with nowhere to go on its own side ends up
	# leaning on the car it meant to pass for the length of a straight.
	if along <= CAR_HALF_LENGTH * 2.0:
		if mine > theirs:
			open_left = false
		elif mine < theirs:
			open_right = false
	if _passing > 0 and open_right and mine > theirs - CAR_HALF_WIDTH:
		return 1
	if _passing < 0 and open_left and mine < theirs + CAR_HALF_WIDTH:
		return -1
	for wants: float in [mine - theirs, line - theirs]:
		if wants > 0.0 and open_right:
			return 1
		if wants < 0.0 and open_left:
			return -1
	if open_right:
		return 1
	if open_left:
		return -1
	return 0


## The room the line has over the stretch the two cars will be alongside for,
## as a lowest and a highest lateral, or NAN either side if it closes up.
##
## The narrowest of it, not the room at this one sample: a way past that shuts
## half a car length later is a way into whatever shut it.
func _corridor(i: int, speed: float) -> Vector2:
	var lo := -INF
	var hi := INF
	var look := maxf(PASS_FROM + CAR_HALF_LENGTH * 2.0, speed * PASS_SECONDS)
	var reach := i + int(ceil(look / _step))
	for k in range(i, mini(reach + 1, _count)):
		lo = maxf(lo, _lo[k] + (BARRIER_ROOM if (_hemmed[k] & 1) != 0 else 0.0))
		hi = minf(hi, _hi[k] - (BARRIER_ROOM if (_hemmed[k] & 2) != 0 else 0.0))
	return Vector2(lo, hi) if lo <= hi else Vector2(NAN, NAN)


## Whether the road ahead is worth leaving the line for a tow down: straight
## for TOW_LOOK metres, with no barrier hemming the line in over any of it, and
## with the other car's line inside the room the plan left itself all the way.
##
## The last two are the ones that were missing. A bot that only asked whether
## the road was straight would tuck in behind a car heading for a gap it had
## not chosen, and arrive at the barrier row off its own line with no time left
## to cross back - which on The Gate cost it the race rather than won it one.
func _tow_is_clear(i: int, theirs: float) -> bool:
	for k in range(i, mini(i + int(TOW_LOOK / _step) + 1, _count)):
		if not is_inf(_limit[k]):
			return false
		if _hemmed[k] != 0:
			return false
		if theirs < _lo[k] or theirs > _hi[k]:
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
	_road_lo = _lo.duplicate()
	_road_hi = _hi.duplicate()


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
	_forks.clear()
	for placement in features.placements:
		if placement.kind == TrackFeatures.TRAP:
			_traps.append(placement)
		elif placement.kind == TrackFeatures.OBSTACLE:
			standing.append(placement)
		elif placement.kind == TrackFeatures.FORK:
			_forks.append(placement)
	_pads = features.of_kind(TrackFeatures.BOOST_PAD)
	var pads: Array = _pads if difficulty >= PADS_FROM else []

	var lo := _road_lo.duplicate()
	var hi := _road_hi.duplicate()
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
		var mine := _narrow_line[i] / half
		var lane := _lane_at(float(i) * _step)
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
				# A fork whose two lanes have been timed is not a choice any
				# more. Worth more than the pad and more than the line, because
				# the timing already counted both of those.
				if lane != 0 and signf((gap.x + gap.y) * 0.5) == float(lane):
					score += 10.0
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
##
## Set a relaxing going: `passes` sweeps at each span in turn, over the stretch
## from `from` to `to`. Carried out by _relax_a_sweep, one sweep at a time,
## because the whole of a relaxing is over a thousand sweeps and no frame can
## afford them all.
func _start_relaxing(spans: PackedInt32Array, passes: int, from := 2, to := -1) -> void:
	_relax_spans = spans
	_relax_passes = passes
	_relax_from = maxi(from, 2)
	_relax_to = _count - 2 if to < 0 else mini(to, _count - 2)
	_relax_span = 0
	_relax_sweep = 0


## One sweep of the relaxing in progress, and whether any are left after it.
func _relax_a_sweep() -> bool:
	if _relax_passes <= 0 or _relax_span >= _relax_spans.size():
		return false
	var span := _relax_spans[_relax_span]
	for i in range(_relax_from, _relax_to):
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
	_relax_sweep += 1
	if _relax_sweep >= _relax_passes:
		_relax_sweep = 0
		_relax_span += 1
	return _relax_span < _relax_spans.size()


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
	_decel = decel
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


## Which side of the divider the line takes through whatever fork covers an
## offset: 1 for the right of it, -1 for the left, 0 where nothing has been
## settled - which is every fork until its two lanes have been timed, and every
## other stretch of road for ever.
func _lane_at(offset: float) -> int:
	for f in _forks.size():
		if not _lane_for.has(f):
			continue
		var fork: TrackFeatures.Placement = _forks[f]
		if offset >= fork.offset and offset <= fork.offset + fork.length:
			return int(_lane_for[f])
	return 0


# --- timing the lanes of a fork -----------------------------------------

## Take the quicker lane of every fork, by driving both of them.
##
## A fork is the one place on a road where the line has a choice rather than a
## best: a fast lane with a pad in it and a row or two of barriers to thread,
## and a clear lane with neither. Which of those is quicker is not something to
## read off the shape of them. The pad is worth more than the barriers cost on
## a wide road and less on a narrow one, it is worth more into a long straight
## than into a corner the car has to brake for anyway, and what the barriers
## cost depends on whether this car can thread them at the speed it arrives -
## which is a question about the car, not about the road.
##
## So it is driven. For each lane in turn: the road is narrowed to that lane,
## the line is relaxed into it over the fork and its run in, and a copy of the
## car is driven from before the split to well after it - far enough after that
## a pad taken in the fast lane has faded before the clock stops, because a
## boost carried out of a fork is most of what a fast lane is for. The lane
## with the lower time is the one the plan keeps.
##
## It is the same copy, the same `Car.rehearse()` and the same room the
## practice laps use, for the same reason: a lane timed through anything but
## the car's own easing, grip and ceiling is a lane timed for some other car.
func _begin_the_lanes() -> void:
	_before_the_lanes = _lateral.duplicate()
	_lane_for.clear()
	_best_lane.clear()
	_best_room.clear()
	_lane_times.clear()
	_fork_at = 0
	_lane_try = 0
	_lane_seconds = Vector2(INF, INF)
	_lane_clean = Vector2.ZERO
	if _copy == null and _planning_car != null:
		_copy = _planning_car.duplicate() as Car
	_stage = Stage.LANE_NEXT


## Set the next lane going, or settle the fork and move on to the next one -
## and when there are none left, put the best lanes back and get on with the
## practice.
func _next_lane() -> void:
	if _fork_at >= _forks.size():
		_settle_the_lanes()
		return
	if _lane_try >= 2:
		# Both lanes of this fork driven. A lane the copy still could not hold
		# after every go at mending it is not a lane, whatever the clock said:
		# the time it came back with is a time with a barrier in it, and the
		# practice laps that follow would be spending themselves on a stretch
		# of road the car was never going to thread. So a clean lane beats a
		# scraping one, and between two of a kind the quicker one wins.
		var take_the_right := (_lane_clean.x > _lane_clean.y
			if _lane_clean.x != _lane_clean.y
			else _lane_seconds.x <= _lane_seconds.y)
		_lane_for[_fork_at] = 1 if take_the_right else -1
		_best_lane[_fork_at] = _lane_for[_fork_at]
		_best_room[_fork_at] = _lane_room[0 if take_the_right else 1]
		_lane_times[_fork_at] = _lane_seconds
		_fork_at += 1
		_lane_try = 0
		_lane_seconds = Vector2(INF, INF)
		_lane_clean = Vector2.ZERO
		return
	var fork: TrackFeatures.Placement = _forks[_fork_at]
	_lane_for[_fork_at] = 1 if _lane_try == 0 else -1
	_lateral = _before_the_lanes.duplicate()
	_narrow_for_the_furniture()
	_lane_from = clampi(
		int((fork.offset - LANE_BEFORE) / _step), 0, _count - 2)
	_lane_to = clampi(
		int((fork.offset + fork.length + LANE_AFTER) / _step), 0, _count - 1)
	_lane_mends = 0
	_lane_seen = {}
	# The caution the other lane's mending laid down is not this lane's, and it
	# reaches as far as that lane was driven rather than as far as it was
	# relaxed - so a lane that was taken slower on its way out of the fork
	# would hand the next one the same slowing and be timed against it.
	for k in range(maxi(_lane_from - _practice_reach, 0),
			mini(_lane_to + 4, _count)):
		_caution[k] = 1.0
	_relax_a_lane(fork)
	_stage = Stage.LANE_RELAX


## Put the copy at the start of the stretch, going as fast as the line there
## allows, and start the clock.
##
## At the speed the line allows and not at top speed: a fork at the end of a
## straight is arrived at flat out and one after a hairpin is not, and a lane
## timed from a speed the car could not have been doing is a lane timed on a
## road that is not there.
func _begin_a_lane() -> void:
	_at = _lane_from
	_furthest = _lane_from
	var down := _line[_lane_from + 1] - _line[_lane_from]
	down.y = 0.0
	_lane_here = _line[_lane_from]
	_copy.rehearse_from(
		Transform3D(Basis.looking_at(down.normalized(), Vector3.UP), _lane_here),
		minf(_limit[_lane_from], _planning_car.max_speed))
	_lane_clock = 0.0
	_lane_step = 0
	_lane_grace = 0.0
	_lane_trouble = 0
	_lane_marks = PackedInt32Array()
	race_time = 0.0
	_last_steer = 0.0


## One step of a timed lane, and whether the stretch goes on after it. The same
## shape as a practice step, and for the same reason it is a step at a time.
func _drive_a_lane_step() -> bool:
	if _lane_step >= LANE_STEPS or _at >= _lane_to:
		return false
	_lane_step += 1
	var delta := 1.0 / 60.0
	var here := _lane_here
	_follow(here, delta, false, false)
	if _at >= _count - 2 or _at >= _lane_to:
		return false
	var i := _at
	var grounded := _ground[i] != 0
	_rehearsing = true
	var wanted := _command(_copy, here, _travel(_copy.transform, _copy.drift()),
		_copy.speed(), grounded)
	_rehearsing = false
	var going := _copy.rehearse(wanted.x, wanted.y, grounded, delta)
	here += going * delta
	here.y = _centre[_at].y
	_copy.transform.origin = here
	_lane_clock += delta
	race_time += delta
	_lane_here = here

	if _lane_grace > 0.0:
		_lane_grace -= delta
		return true
	var across := (here - _centre[i]).dot(_right[i])
	var road := Vector3.UP.cross(_right[i])
	var along := float(i) * _step + (here - _centre[i]).dot(road)
	var angle := road.signed_angle_to(_travel(_copy.transform, 0.0), Vector3.UP)
	var hit := _clipped(along, across, angle, i)
	for pad in _pads:
		if (along >= pad.offset and along <= pad.offset + pad.length
				and absf(across - pad.lateral * _half[i]) <= pad.half_span * _half[i]):
			_copy.boost(pad.strength)
	var edge := maxf(_half[i] - _margin(), 0.0) + PRACTICE_SLACK
	if hit != 0 or absf(across) > edge:
		# Charged for it, which is the whole point of timing a lane that has
		# barriers in it: put back on the line for nothing, a lane the car
		# cannot thread would come out of this as quick as one it can.
		var on := mini(i + 2, _count - 2)
		var down := _line[on + 1] - _line[on]
		down.y = 0.0
		_lane_here = _line[on]
		_copy.rehearse_from(Transform3D(
			Basis.looking_at(down.normalized(), Vector3.UP), _lane_here),
			_copy.speed() * (1.0 - _planning_car.obstacle_scrub))
		_lane_grace = PRACTICE_GRACE
		_lane_trouble += 1
		_lane_marks.append(i * 2 + (1 if (hit > 0 or across > edge) else 0))
	return true


## The lane is driven. Give it room where the copy could not hold it and drive
## it again, or, when there is nothing left to mend or no goes left, keep its
## time and go round for the next one.
func _end_a_lane() -> void:
	if not _lane_marks.is_empty() and _lane_mends < LANE_MENDS:
		_mend_a_lane()
		_lane_mends += 1
		_relax_a_lane(_forks[_fork_at])
		_stage = Stage.LANE_RELAX
		return
	# A lane the copy never got to the end of is not a lane: whatever stopped
	# it would have stopped the car as well.
	var seconds := _lane_clock if _at >= _lane_to else INF
	# The room and the line this lane ended up with, so that the lane that wins
	# is taken as it was driven rather than planned again from the start.
	var fork: TrackFeatures.Placement = _forks[_fork_at]
	var from := maxi(int((fork.offset - LANE_RELAX_IN) / _step), 0)
	var to := mini(int((fork.offset + fork.length + LANE_RELAX_OUT) / _step) + 1, _count)
	_lane_room[_lane_try] = {
		"from": from, "to": to,
		"lo": _lo.slice(from, to), "hi": _hi.slice(from, to),
		"lateral": _lateral.slice(from, to),
		"caution": _caution.slice(from, to),
	}
	var scrapes: Vector2 = _lane_scrapes.get(_fork_at, Vector2.ZERO)
	if _lane_try == 0:
		_lane_seconds.x = seconds
		_lane_clean.x = 1.0 if _lane_marks.is_empty() else 0.0
		_lane_scrapes[_fork_at] = Vector2(float(_lane_trouble), scrapes.y)
	else:
		_lane_seconds.y = seconds
		_lane_clean.y = 1.0 if _lane_marks.is_empty() else 0.0
		_lane_scrapes[_fork_at] = Vector2(scrapes.x, float(_lane_trouble))
	_lane_try += 1
	_stage = Stage.LANE_NEXT


## Set a relaxing going over one fork and the road either side of it: the only
## stretch a lane can have moved. The rest of the line is the one the fine
## relaxing already settled, and doing the longest piece of work in the plan
## again for it would be doing it twice for nothing.
func _relax_a_lane(fork: TrackFeatures.Placement) -> void:
	_start_relaxing(PackedInt32Array([8, 4, 2, 1]), 60,
		int((fork.offset - LANE_RELAX_IN) / _step),
		int((fork.offset + fork.length + LANE_RELAX_OUT) / _step))


## Give the line room where the copy could not hold it, the way a practice lap
## does: more room on the side it went wide on, a little before and a little
## more after, since it is leaving something the back of a turning car catches.
func _mend_a_lane() -> void:
	for mark in _lane_marks:
		var i := mark >> 1
		var right := (mark & 1) == 1
		for k in range(maxi(i - 4, 0), mini(i + 7, _count)):
			if right and _hi[k] - TIGHTEN >= _lo[k]:
				_hi[k] -= TIGHTEN
			elif not right and _lo[k] + TIGHTEN <= _hi[k]:
				_lo[k] += TIGHTEN
		# And slower into it where moving the line has already been tried,
		# which is the other half of what a practice lap does with a mistake.
		if _lane_seen.has(i >> 2):
			for k in range(maxi(i - _practice_reach, 0), mini(i + 3, _count)):
				_caution[k] = maxf(_caution[k] * CAUTION_STEP, CAUTION_FLOOR)
		_lane_seen[i >> 2] = true
		_lane_seen[(i >> 2) - 1] = true
		_lane_seen[(i >> 2) + 1] = true


## Every lane driven. Put the road and the line back the way the lanes that won
## left them.
func _settle_the_lanes() -> void:
	_lane_for = _best_lane.duplicate()
	_lateral = _before_the_lanes.duplicate()
	_narrow_for_the_furniture()
	_caution = PackedFloat32Array()
	_caution.resize(_count)
	_caution.fill(1.0)
	for f in _forks.size():
		if not _best_room.has(f):
			continue
		var kept: Dictionary = _best_room[f]
		var from: int = kept["from"]
		for k in (kept["lo"] as PackedFloat32Array).size():
			_lo[from + k] = kept["lo"][k]
			_hi[from + k] = kept["hi"][k]
			_lateral[from + k] = kept["lateral"][k]
			_caution[from + k] = kept["caution"][k]
	# _set_the_limits' work, with the caution the lanes learned left standing
	# rather than wiped: a stretch the timed lane could only hold by taking it
	# slower is a stretch the race has to take slower too.
	_build_line()
	_read_the_bends(_planning_car)
	_brake_for_the_limits(_planning_car)
	reset_progress()
	_begin_practice()
	_stage = Stage.PRACTICE_LAP


## Which lane of each fork the timing settled on, and what the two of them
## took, for a check or a tool to print.
func lane_choices() -> Array:
	var out := []
	for f in _forks.size():
		var seconds: Vector2 = _lane_times.get(f, Vector2(INF, INF))
		out.append({
			"at": _forks[f].offset,
			"length": _forks[f].length,
			"fast_lane": int(signf(_forks[f].lateral)),
			"taken": int(_lane_for.get(f, 0)),
			"right_lane": seconds.x,
			"left_lane": seconds.y,
			"scrapes": _lane_scrapes.get(f, Vector2.ZERO),
		})
	return out


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
##
## Take the copy out and get the first lap ready. The laps themselves are
## _practise_a_step's, and what is done between them _end_a_practice_lap's,
## because a lap is thousands of steps and no frame can afford one.
func _begin_practice() -> void:
	if _copy == null:
		_copy = _planning_car.duplicate() as Car
	# Where it has been in trouble before, in stretches of four samples.
	_practice_seen = {}
	_begin_a_practice_lap()


## The lap is over. If it was clean there is nothing left to learn; otherwise the
## line is given room where the copy left it, and relaxed again through that
## stretch - which is PRACTICE_MEND's to carry out.
##
## The mending happens after the last lap as well as after the ones before it.
## What the copy found on lap eight is as true as what it found on lap one, and a
## race driven on a line that was told about a mistake and not moved for it would
## be driving into that mistake knowingly.
func _end_a_practice_lap() -> void:
	if _practice_trouble.is_empty():
		_stage = Stage.PRACTICE_OVER
		return
	var first := _count
	var last := 0
	for mark in _practice_trouble:
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
		if _practice_seen.has(i >> 2):
			for k in range(maxi(i - _practice_reach, 0), mini(i + 3, _count)):
				_caution[k] = maxf(_caution[k] * CAUTION_STEP, CAUTION_FLOOR)
		_practice_seen[i >> 2] = true
		_practice_seen[(i >> 2) - 1] = true
		_practice_seen[(i >> 2) + 1] = true
	_start_relaxing(PackedInt32Array([4, 2, 1]), 40, first - 40, last + 40)
	_stage = Stage.PRACTICE_MEND


func _put_the_copy_away() -> void:
	_copy.free()
	_copy = null
	_planning_car = null
	race_time = 0.0
	_last_steer = 0.0
	reset_progress()


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


## Put the copy back on the line and start it on a lap. Where it leaves the room
## the line had is collected in _practice_trouble, one entry for each time it
## did: the sample, doubled, plus one if it went out to the right.
func _begin_a_practice_lap() -> void:
	_practice_trouble = PackedInt32Array()
	reset_progress()
	race_time = 0.0
	_last_steer = 0.0
	_copy.rehearse_from(_practice_start)
	_practice_here = _practice_start.origin
	_practice_grace = 0.0
	_practice_step = 0
	_laps_practised += 1


## One step of the lap, and whether the lap goes on after it. A few microseconds,
## which is what makes the budget in plan_a_little worth anything: a unit of work
## this small cannot overshoot a frame.
func _practise_a_step() -> bool:
	if _practice_step >= PRACTICE_STEPS:
		return false
	_practice_step += 1
	var delta := 1.0 / 60.0
	var here := _practice_here
	_follow(here, delta, false, false)
	if _at >= _count - 2:
		return false
	var i := _at
	var grounded := _ground[i] != 0
	_rehearsing = true
	var wanted := _command(_copy, here, _travel(_copy.transform, _copy.drift()),
		_copy.speed(), grounded)
	_rehearsing = false
	var going := _copy.rehearse(wanted.x, wanted.y, grounded, delta)
	here += going * delta
	here.y = _centre[_at].y
	_copy.transform.origin = here
	race_time += delta
	_practice_here = here

	if _practice_grace > 0.0:
		_practice_grace -= delta
		return true
	var across := (here - _centre[i]).dot(_right[i])
	var road := Vector3.UP.cross(_right[i])
	var along := float(i) * _step + (here - _centre[i]).dot(road)
	var angle := road.signed_angle_to(_travel(_copy.transform, 0.0), Vector3.UP)
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
			_copy.boost(pad.strength)
	# Off the side of the road, by the middle of the car. The rails are
	# beyond the kerb, and a corner over the kerb is not a mistake.
	var edge := maxf(_half[i] - _margin(), 0.0) + PRACTICE_SLACK
	var left_out := hit < 0 or across < -edge
	var right_out := hit > 0 or across > edge
	if left_out or right_out:
		_practice_trouble.append(i * 2 + (1 if right_out else 0))
		# Put back on the line a little further on, pointing down it, at
		# the speed it had, and let alone for a moment to settle. A copy
		# left wide would spend the rest of the lap finding its way back,
		# and one checked again at once would be caught on the same
		# mistake it has just been charged for.
		var on := mini(i + 2, _count - 2)
		var down := _line[on + 1] - _line[on]
		down.y = 0.0
		_practice_here = _line[on]
		_copy.rehearse_from(Transform3D(
			Basis.looking_at(down.normalized(), Vector3.UP), _practice_here),
			_copy.speed())
		_practice_grace = PRACTICE_GRACE
	return true


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
