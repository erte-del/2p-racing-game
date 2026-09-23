extends SceneTree

# The bot with another car on the road, and the choice a fork gives it.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_duel.gd
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_duel.gd -- res://tracks/bot/b2_the_toll.gd
#
# tools/checks/bot_race.gd is one car against the clock, over every track. This
# is the rest of BotDriver: three decisions a lap time on an empty road cannot
# see, all of which were written long before anything drove them.
#
# - **The tow.** The same car drives the same stretch from the same place
#   twice: once with another car ahead of it, once with the road empty. The
#   difference between the two is what the slipstream is worth. Two cars at
#   once, or one car against a lap driven on another line, would be comparing
#   two different drives.
# - **The pass.** In the towed run: where it got by, what it hit on the way,
#   and what it did to the car it passed. A bot that goes through the other car
#   has not overtaken it.
# - **The level race.** Both cars at difficulty 1, side by side on the grid, the
#   way a bot road actually starts. With clear road the two grid slots are worth
#   the same, so whatever margin comes out of this is what racing another car
#   costs - and it is the number that says whether the bot is being squeezed
#   onto the furniture by the car beside it.
# - **The fork.** Every road's fork, with the time the driver measured for each
#   of its two lanes and the one it kept. Driven here rather than raced, because
#   which lane is quicker is a thing the plan decides and the clock at the flag
#   only sums up.
#
# Two bots rather than a bot and a scripted player, because a check has no
# hands. The player's car is driven by a second BotDriver, through the same
# `Car.driver` hook the keyboard goes through, so a pass made here is a pass a
# player could have been on the wrong end of.

const ROAD := "res://tracks/bot/b1_the_gate.gd"
const PATIENCE := 60 * 300
## How far ahead of the chasing car the other one starts, in metres. Outside
## slipstream_range, so the two are nothing to each other off the line and the
## tow is something the chaser has to arrive in.
const STAGGER := 26.0
## How good the car in front is, for the tow and the pass. Under the chaser, or
## there is nothing to catch: two identical bots on one line stay the distance
## apart they started, and a tow nobody ever reaches is a tow nobody can
## measure. A notch down rather than a crawl, so the chaser arrives behind it at
## speed, the way it would arrive behind a player who is merely a little slower.
const LEADER_PACE := 0.55
## How much of what the car says a slipstream is worth the bot has to actually
## collect, as a fraction, before the rule is worth having. Half of it: the bot
## is behind a car that is moving, so it spends part of the tow building the
## effect up rather than sitting in the middle of it.
const TOW_WANTED := 0.5
## The most the two cars may touch before the racing is shoving, and the most
## either of them may be put back before it is being rescued rather than raced.
const MAX_CONTACTS := 8
const MAX_RESETS := 2
## How far apart the two can finish a level race before the second one is not
## racing, in metres. With clear road the two grid slots are worth the same, so
## all of this is what having to share the road costs the car that gives way.
const LEVEL_MARGIN := 30.0

var _faults := 0
var _settings: Node
var _times: Node


func _init() -> void:
	await process_frame
	_settings = root.get_node_or_null(^"/root/GameSettings")
	_settings.chaos = false
	_settings.damage = false
	_times = root.get_node_or_null(^"/root/TrackTimes")
	if _times != null:
		_times.save_path = "user://times_bot_duel.cfg"
		_wipe_the_times()

	var args := OS.get_cmdline_user_args()
	var road: String = args[0] if not args.is_empty() else ROAD

	var alone := await _chase(road, false)
	var towed := await _chase(road, true)
	_the_tow(road, alone, towed)
	_the_pass(towed)
	await _the_level_race(road)
	await _the_forks(args if not args.is_empty() else TrackRoster.FILES + TrackRoster.BOT_FILES)

	_wipe_the_times()
	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


# --- the tow and the pass ------------------------------------------------

## One car chasing another down the road, or the same car driving the same
## stretch with nothing in front of it.
##
## Both cars go on one line, the chasing one on the grid and the other one
## `STAGGER` up the road: the tow is a thing that happens to the car behind, and
## side by side is two cars on one line rather than one behind the other. The
## chaser takes the grid slot in both runs, so the two are the same drive.
##
## Without `together` the car in front is held frozen out of the way for the
## whole run and the chaser has never heard of it, so what comes back is the
## same car on the same line with an empty road.
func _chase(road: String, together: bool) -> Dictionary:
	var solo := await _open(road)
	var track: Track = solo.get_node("Track")
	var leader: Car = solo.get("_bot")
	var chaser: Car = solo.get_node("Car")
	if leader == null:
		_fault("%s built no second car, so there is nobody to race" % road)
		await _close(solo)
		return {}

	var grid := track.offset_of(leader.global_position)
	var lane := _lateral_of(track, leader.global_position, grid)
	_put(track, chaser, grid, lane)
	if together:
		_put(track, leader, grid + STAGGER, lane)
		# The car in front is turned down rather than held back by anything
		# outside its driver: the same car through the same hook, driven by a
		# worse driver. Planned again because it has been moved.
		var ahead: BotDriver = leader.driver
		ahead.difficulty = LEADER_PACE
		ahead.plan(leader)
	else:
		# Out of the world for the whole run. Frozen stops it driving and stops
		# CarContact settling anything against it, and up in the air stops it
		# being something to steer round. Held rather than set once, because GO
		# lets every car on the road go.
		leader.global_position += Vector3.UP * 200.0
		chaser.rival = null
		leader.rival = null

	# A check has a frame to spare; a countdown does not. See plan_a_little.
	var driver := BotDriver.new(track, chaser, 1.0)
	driver.finish_planning()
	if together:
		driver.rival = leader
	chaser.driver = driver
	await _to_the_flag(solo, leader, together)

	var metres := int(track.length()) + 2
	var speeds := PackedFloat32Array()
	speeds.resize(metres)
	speeds.fill(-1.0)
	var drafting := PackedByteArray()
	drafting.resize(metres)
	var gaps := PackedFloat32Array()
	gaps.resize(metres)
	gaps.fill(NAN)
	var contact := _contact(solo)
	var touches := 0
	var where := PackedStringArray()
	var settling := 0.0
	var hit := [0.0, 0.0]
	var hits := [0, 0]
	var resets := 0
	var passed := -1.0
	var shoved := 0.0
	for step in PATIENCE:
		if not solo.get("_running"):
			break
		driver.race_time = solo.get("_time")
		if not together:
			leader.frozen = true
		await physics_frame

		var at := track.offset_of(chaser.global_position)
		var row := clampi(int(at), 0, metres - 1)
		speeds[row] = maxf(speeds[row], chaser.speed())
		if chaser.is_drafting():
			drafting[row] = 1
		if together:
			var theirs := track.offset_of(leader.global_position)
			gaps[row] = theirs - at
			if passed < 0.0 and at > theirs + 2.0:
				passed = at
			if not leader.on_the_road():
				shoved += 1.0 / 60.0
		# The two cars touching is CarContact's to settle, and its recovery
		# going up is the one place a contact is recorded. Where each one
		# happened is printed as how far ahead and how far to the right of the
		# chaser the other car was, because the answer to "why did they touch"
		# is nearly always in those two numbers.
		var settled: float = contact.get("_recovery") if contact != null else 0.0
		if settled > settling:
			touches += 1
			if where.size() < 24:
				var to_them := leader.global_position - chaser.global_position
				var nose := -chaser.global_transform.basis.z
				nose.y = 0.0
				nose = nose.normalized()
				where.append("%.0f[%+.1f,%+.1f]" % [at, to_them.dot(nose),
					to_them.dot(nose.cross(Vector3.UP))])
		settling = settled
		for who in 2:
			var car: Car = [chaser, leader][who]
			var recovering: float = car.get("_hit_recovery")
			if recovering > hit[who]:
				hits[who] += 1
			hit[who] = recovering
		if driver.wants_reset() and solo.get("_running"):
			solo.call("_back_to_checkpoint")
			resets += 1

	var out := {
		"speeds": speeds, "drafting": drafting, "gaps": gaps,
		"touches": touches, "where": where, "hits": hits[0], "their_hits": hits[1],
		"resets": resets, "passed": passed, "shoved": shoved,
		"offered": chaser.max_speed * chaser.slipstream_bonus,
	}
	chaser.driver = null
	await _close(solo)
	return out


## What the slipstream is worth: the chaser's speed wherever it was drafting,
## against its own speed at the same metre of road with the road empty.
##
## The best of it rather than the average of it. A car queued behind a slower
## one is slower than it was alone whatever the tow is doing for it, and that is
## the queue rather than the tow. What says the tow works is that somewhere in
## it the car reached a speed it could not reach on the same road with nobody
## in front of it.
func _the_tow(road: String, alone: Dictionary, towed: Dictionary) -> void:
	print("the tow, on %s, 1.00 chasing %.2f:" % [road, LEADER_PACE])
	if alone.is_empty() or towed.is_empty():
		return
	var empty: PackedFloat32Array = alone["speeds"]
	var tow: PackedFloat32Array = towed["speeds"]
	var drafting: PackedByteArray = towed["drafting"]
	var metres := 0
	var quicker := 0
	var best := 0.0
	var best_at := -1
	for i in mini(empty.size(), tow.size()):
		if drafting[i] == 0 or empty[i] < 0.0 or tow[i] < 0.0:
			continue
		metres += 1
		if tow[i] > empty[i]:
			quicker += 1
		if tow[i] - empty[i] > best:
			best = tow[i] - empty[i]
			best_at = i
	if metres == 0:
		print("  never in the tow at all")
		_fault("the chaser never got into the tow, so the rule is decoration")
		return
	var offered: float = towed["offered"]
	print("  in the tow over %d m, quicker than its own pace on %d of them"
		% [metres, quicker])
	print("  most it gained %+.2f m/s at %d m, of the %.2f m/s the car offers"
		% [best, best_at, offered])
	_gap_trace(towed)
	if best < offered * TOW_WANTED:
		_fault("the most the tow was ever worth is %+.2f m/s of the %.2f on offer"
			% [best, offered])


## Where the two cars were, and where the chaser was drafting, in bands down
## the road: a tow that never happened and a tow that happened and paid nothing
## are different faults.
func _gap_trace(towed: Dictionary) -> void:
	var gaps: PackedFloat32Array = towed["gaps"]
	var drafting: PackedByteArray = towed["drafting"]
	var band := 100
	var row := PackedStringArray()
	for start in range(0, gaps.size() - 1, band):
		var sum := 0.0
		var seen := 0
		var drafted := 0
		for i in range(start, mini(start + band, gaps.size())):
			if not is_nan(gaps[i]):
				sum += gaps[i]
				seen += 1
			drafted += drafting[i]
		if seen > 0:
			row.append("%d:%+.0f/%d" % [start, sum / float(seen), drafted])
	print("  how far ahead the other car was, and metres drafted, every %d m:" % band)
	print("    %s" % " ".join(row))


## Whether it got by, and what that cost the two of them.
func _the_pass(towed: Dictionary) -> void:
	if towed.is_empty():
		return
	print("the pass:")
	print("  got by at %s"
		% ["%.0f m" % towed["passed"] if towed["passed"] >= 0.0 else "never"])
	print("  contacts %d, its own hits %d, the other car's %d, off the road %.1f s, resets %d"
		% [towed["touches"], towed["hits"], towed["their_hits"],
			towed["shoved"], towed["resets"]])
	if towed["touches"] > 0:
		print("  touched at m[ahead,right]: %s" % " ".join(towed["where"]))
	if towed["passed"] < 0.0:
		_fault("it never got by, so it sits behind for ever")
	if towed["touches"] > MAX_CONTACTS:
		_fault("%d contacts: it is shoving its way past rather than going round"
			% towed["touches"])
	if towed["their_hits"] > 0:
		_fault("it put the other car into a barrier %d times" % towed["their_hits"])
	if towed["shoved"] > 1.0:
		_fault("it put the other car off the road for %.1f s" % towed["shoved"])
	if towed["resets"] > MAX_RESETS:
		_fault("it had to be put back %d times" % towed["resets"])


# --- the level race ------------------------------------------------------

## The race a bot road actually starts: two cars of the same difficulty, side by
## side on the grid. What comes out is what racing another car costs, since with
## clear road the two grid slots are worth the same.
func _the_level_race(road: String) -> void:
	var solo := await _open(road)
	var track: Track = solo.get_node("Track")
	var theirs: Car = solo.get("_bot")
	var ours: Car = solo.get_node("Car")
	if theirs == null:
		await _close(solo)
		return
	var driver := BotDriver.new(track, ours, 1.0)
	driver.finish_planning()
	driver.rival = theirs
	ours.driver = driver
	await _to_the_flag(solo, theirs, true)

	var contact := _contact(solo)
	var touches := 0
	var settling := 0.0
	var hit := [0.0, 0.0]
	var hits := [0, 0]
	var resets := 0
	var off := [0.0, 0.0]
	var knocks := PackedStringArray()
	var gaps := PackedFloat32Array()
	gaps.resize(int(track.length()) + 2)
	gaps.fill(NAN)
	for step in PATIENCE:
		if not solo.get("_running"):
			break
		driver.race_time = solo.get("_time")
		await physics_frame
		var us := track.offset_of(ours.global_position)
		gaps[clampi(int(us), 0, gaps.size() - 1)] = us - track.offset_of(
			theirs.global_position)
		var settled: float = contact.get("_recovery") if contact != null else 0.0
		if settled > settling:
			touches += 1
		settling = settled
		for who in 2:
			var car: Car = [ours, theirs][who]
			var recovering: float = car.get("_hit_recovery")
			if recovering > hit[who]:
				hits[who] += 1
				knocks.append("%s at %.0f m" % [
					"left" if who == 0 else "right",
					track.offset_of(car.global_position)])
			hit[who] = recovering
			if not car.on_the_road():
				off[who] += 1.0 / 60.0
		if driver.wants_reset() and solo.get("_running"):
			solo.call("_back_to_checkpoint")
			resets += 1
	var margin := track.offset_of(ours.global_position) - track.offset_of(
		theirs.global_position)
	print("the level race, both at 1.00 from the grid:")
	print("  %.2f s, %s by %.0f m" % [solo.get("_time"),
		"the grid's left car" if margin > 0.0 else "the grid's right car",
		absf(margin)])
	print("  contacts %d, hits %d and %d, off the road %.1f s and %.1f s, resets %d"
		% [touches, hits[0], hits[1], off[0], off[1], resets])
	var row := PackedStringArray()
	for start in range(0, gaps.size() - 1, 100):
		var sum := 0.0
		var seen := 0
		for k in range(start, mini(start + 100, gaps.size())):
			if not is_nan(gaps[k]):
				sum += gaps[k]
				seen += 1
		if seen > 0:
			row.append("%d:%+.0f" % [start, sum / seen])
	if not knocks.is_empty():
		print("  into a barrier: %s" % ", ".join(knocks))
	print("  the left car's lead, every 100 m:")
	print("    %s" % " ".join(row))
	if absf(margin) > LEVEL_MARGIN:
		_fault("%.0f m apart at the flag on a road where the two slots are level"
			% absf(margin))
	if touches > MAX_CONTACTS:
		_fault("%d contacts in a level race" % touches)
	# One brush is the road doing its job: The Gate's first row stands on the
	# outside of a corner exit so that the car which ran wide meets it and the
	# car which did not does not, and in a level race one of them has to be the
	# one that ran wide. Meeting it again and again is the squeeze.
	if hits[0] > 1 or hits[1] > 1:
		_fault("racing each other put a car into a barrier %d and %d times"
			% [hits[0], hits[1]])
	if resets > MAX_RESETS:
		_fault("a car had to be put back %d times" % resets)
	await _close(solo)


# --- the fork ------------------------------------------------------------

## Which lane of each road's fork the driver kept, and what it timed the two of
## them at. Only the plan is wanted here, so the roads are opened, planned and
## closed without anything being driven for real.
##
## The one thing this is really watching for is a timing that always comes out
## the same way. Both lanes taking the same side of every fork on every road in
## the game is not a choice being made, it is a choice being got wrong the same
## way twenty times - which is exactly what happened the first time this was
## written, because the lane with the barriers in it was being charged for a
## line that had not been mended yet and so lost every fork there was.
func _the_forks(files: Array) -> void:
	print("the fork, on %d roads:" % files.size())
	var fast := 0
	var clear := 0
	for file: String in files:
		_settings.track_file = file
		var solo := await _open(file)
		var track: Track = solo.get_node("Track")
		var driver := BotDriver.new(track, solo.get_node("Car") as Car, 1.0)
		driver.finish_planning()
		for choice: Dictionary in driver.lane_choices():
			var scrapes: Vector2 = choice["scrapes"]
			var took_the_fast: bool = choice["taken"] == choice["fast_lane"]
			if took_the_fast:
				fast += 1
			else:
				clear += 1
			var kept: float = choice["right_lane"] if choice["taken"] > 0 else choice["left_lane"]
			var dropped: float = choice["left_lane"] if choice["taken"] > 0 else choice["right_lane"]
			var left: float = scrapes.y if choice["taken"] > 0 else scrapes.x
			print("  %-16s at %5.0f m: %s lane, %.2f s against %.2f s%s"
				% [track.definition().track_name, choice["at"],
					"the pad's" if took_the_fast else "the clear",
					kept, dropped,
					"" if left <= 0.0 else
						" (the other one still clipped something %d times)" % int(left)])
			if choice["taken"] == 0:
				_fault("%s left its fork at %.0f m unchosen"
					% [track.definition().track_name, choice["at"]])
			var kept_scrapes: float = scrapes.x if choice["taken"] > 0 else scrapes.y
			if kept_scrapes > 0.0 and left <= 0.0:
				_fault("%s kept a lane it could not thread over one it could"
					% track.definition().track_name)
			if kept > dropped and kept_scrapes <= 0.0 and left <= 0.0:
				_fault("%s kept the slower of two lanes it could both drive"
					% track.definition().track_name)
		await _close(solo)
	print("  %d forks taken down the pad's lane, %d down the clear one" % [fast, clear])
	if fast + clear >= 8 and (fast == 0 or clear == 0):
		_fault("every fork in the game went the same way, which is not a choice")


# --- the scene -----------------------------------------------------------

## Build the scene on a road and wait for it to settle, with the countdown
## still to come: whatever the cars are moved to before GO is where they start.
func _open(road: String) -> Node:
	_settings.track_file = road
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	for i in 10:
		await physics_frame
	return solo


## Wait out the countdown, holding the frozen car frozen through it.
func _to_the_flag(solo: Node, leader: Car, together: bool) -> void:
	var waited := 0
	while not solo.get("_running") and waited < 900:
		if not together:
			leader.frozen = true
		await physics_frame
		waited += 1
	if not solo.get("_running"):
		_fault("the countdown never finished")


func _close(solo: Node) -> void:
	solo.queue_free()
	await process_frame


func _contact(solo: Node) -> CarContact:
	for child in solo.get_children():
		if child is CarContact:
			return child
	return null


## Set a car down `at` metres along the course and `lateral` metres right of
## the middle, pointing down it and stopped.
func _put(track: Track, car: Car, at: float, lateral: float) -> void:
	var here := track.centre_at(at)
	var forward := _forward(track, at)
	car.global_position = here + forward.cross(Vector3.UP) * lateral + Vector3.UP * 0.6
	car.look_at(car.global_position + forward, Vector3.UP)
	car.rotation.x = 0.0
	car.rotation.z = 0.0
	car.reset_motion()


func _lateral_of(track: Track, where: Vector3, at: float) -> float:
	return (where - track.centre_at(at)).dot(_forward(track, at).cross(Vector3.UP))


func _forward(track: Track, at: float) -> Vector3:
	var ahead := track.centre_at(at + 1.0) - track.centre_at(at)
	ahead.y = 0.0
	return ahead.normalized() if ahead.length_squared() > 0.000001 else Vector3.FORWARD


func _wipe_the_times() -> void:
	if _times == null:
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_times.save_path))
	_times.load_times()


func _fault(what: String) -> void:
	print("  %s" % what)
	_faults += 1
