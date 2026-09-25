extends SceneTree

# Drive real races and see what the lifetime totals make of them.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/stats_race.gd
#
# stats.gd checks the store on its own; this checks what the race scenes tell
# it, which is where a count goes wrong quietly - a win written down in the
# branch that was easiest to reach, a wreck forgotten on a draw, the bot's
# reset counted as the player's. Every case starts from a snapshot of the
# totals and says exactly what it expects to have moved, and anything else
# that moved is a fault.
#
# The one that matters most is the last: the title screen's backdrop is the
# two-player scene, and left running it must add nothing at all. Today that is
# true because its cars are parked, and the next change to the backdrop could
# undo that without anybody thinking of statistics. So it is driven, not just
# watched - its cars are let go with the throttle held - and it must still add
# no distance and no race.
#
# --fixed-fps matters, for the reason solo_run.gd gives: without it the drive
# down a whole track takes as long as driving it.
#
# Every store is pointed at scratch through Sandbox.path(), and fetched out of
# the tree rather than named, because a --script file is compiled before the
# autoloads have registered their names.

const FIRST := "res://tracks/01_first_light.gd"
const BOT_ROAD := "res://tracks/bot/b1_the_gate.gd"
const COUNTERS := [
	"distance_metres", "time_driven_seconds", "races_completed",
	"races_contested", "races_won", "cars_wrecked", "resets", "coins_earned",
]

var _faults := 0
var _stats: Node
var _settings: Node
var _purse: Node
var _scratch: Array[String] = []


func _init() -> void:
	await process_frame
	_stats = root.get_node_or_null(^"/root/Stats")
	_settings = root.get_node_or_null(^"/root/GameSettings")
	_purse = root.get_node_or_null(^"/root/Purse")
	if _stats == null or _settings == null or _purse == null:
		print("  a store is not loaded")
		quit(1)
		return
	# Everything a run writes, pointed somewhere that is nobody's.
	_point(_stats, "user://stats_race_check.cfg", "load_stats")
	_point(_purse, "user://purse_stats_check.cfg", "load_purse")
	_point(root.get_node(^"/root/TrackTimes"), "user://times_stats_check.cfg",
		"load_times")
	_point(root.get_node(^"/root/Progress"), "user://progress_stats_check.cfg",
		"load_progress")
	_stats.forget()
	_settings.chaos = false

	await _a_finished_run()
	await _a_broken_run()
	await _resets()
	await _a_quit_run()
	await _bot_races()
	await _two_players()
	await _the_title_screen()

	for path in _scratch:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


# --- solo -------------------------------------------------------------------

## A time trial driven to the flag: one completed race, some distance, no win -
## and every coin picked up on it counted, the same number the purse got.
func _a_finished_run() -> void:
	_settings.damage = false
	_settings.track_file = FIRST
	var solo := await _solo()
	if solo == null:
		return
	var before := _snapshot()
	var coins_before: int = _purse.coins()
	if not await _drive_to_the_flag(solo):
		_fault("the car never finished %s" % FIRST)
	var banked: int = _purse.coins() - coins_before
	_expect("a finished time trial", before, {
		"races_completed": 1, "coins_earned": banked,
	}, true)
	print("  %d coins on the way, %d counted"
		% [banked, _stats.coins_earned - int(before["coins_earned"])])
	await _gone(solo)


## Worn to nothing: completed, and a wreck.
func _a_broken_run() -> void:
	_settings.damage = true
	_settings.track_file = FIRST
	var solo := await _solo()
	if solo == null:
		return
	var before := _snapshot()
	(solo.get_node("Car") as Car)._condition = 0.0
	await _frames(3)
	_expect("a broken-down time trial", before,
		{"races_completed": 1, "cars_wrecked": 1}, true)
	await _gone(solo)
	_settings.damage = false


## The key is the player's reset; the bot's asking is not.
func _resets() -> void:
	_settings.track_file = FIRST
	var solo := await _solo()
	if solo == null:
		return
	await _frames(20)
	var before := _snapshot()
	Input.action_press("p1_reset")
	await physics_frame
	Input.action_release("p1_reset")
	await physics_frame
	_expect("the reset key", before, {"resets": 1}, true)
	await _gone(solo)

	_settings.track_file = BOT_ROAD
	var race := await _solo()
	if race == null:
		return
	await _frames(20)
	before = _snapshot()
	race.call("_back_to_checkpoint", race.get("_bot"))
	await physics_frame
	_expect("the bot going back to a checkpoint", before, {}, true)
	await _gone(race)


## A run given up keeps its driving and counts nothing else - both ways a run
## is given up in the scene itself: restarted, and left.
func _a_quit_run() -> void:
	_settings.track_file = FIRST
	var solo := await _solo()
	if solo == null:
		return
	var before := _snapshot()
	var on_disk := _distance_on_disk()
	Input.action_press("p1_accelerate")
	await _frames(90)
	solo.call("_restart")
	Input.action_release("p1_accelerate")
	_expect("a restarted run", before, {}, true)
	if _distance_on_disk() <= on_disk:
		_fault("restarting did not write the run's driving down")

	if not await _until(func() -> bool: return solo.get("_running"), 600):
		_fault("the second go never started")
	before = _snapshot()
	on_disk = _distance_on_disk()
	Input.action_press("p1_accelerate")
	await _frames(90)
	Input.action_release("p1_accelerate")
	await _gone(solo)
	_expect("a run left halfway", before, {}, true)
	if _distance_on_disk() <= on_disk:
		_fault("leaving the scene did not write the run's driving down")


func _bot_races() -> void:
	_settings.damage = true
	_settings.track_file = BOT_ROAD
	# Beaten to the flag, and beating it there. Called rather than driven: the
	# bot is a fair rival, and a check that has to win the race to get to the
	# result would be a check of the bot. How the result is reached is what
	# bot_duel.gd is for; what it is worth is what is asked here.
	for case in [["_won_the_race", {"races_won": 1}], ["_lost_the_race", {}]]:
		var race := await _solo()
		if race == null:
			return
		var before := _snapshot()
		race.call(case[0])
		var wanted: Dictionary = {"races_completed": 1, "races_contested": 1}
		wanted.merge(case[1])
		_expect("a bot race, %s" % case[0].trim_prefix("_"), before, wanted, false)
		await _gone(race)

	# And the three ways of breaking down, which go through the real path: a
	# car worn to nothing, and the race noticing on the next step.
	var endings := [
		["the bot broke down", false, true,
			{"races_completed": 1, "races_contested": 1, "races_won": 1}],
		["the player broke down", true, false,
			{"races_completed": 1, "races_contested": 1, "cars_wrecked": 1}],
		["both broke down", true, true,
			{"races_completed": 1, "races_contested": 1, "cars_wrecked": 1}],
	]
	for ending in endings:
		var race := await _solo()
		if race == null:
			return
		await _frames(5)
		var before := _snapshot()
		if ending[1]:
			(race.get_node("Car") as Car)._condition = 0.0
		if ending[2]:
			(race.get("_bot") as Car)._condition = 0.0
		await _frames(3)
		_expect("a bot race, %s" % ending[0], before, ending[3], true)
		await _gone(race)
	_settings.damage = false


# --- two players ------------------------------------------------------------

func _two_players() -> void:
	_settings.damage = true
	_settings.track_file = ""
	var race: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(race)
	if not await _until(func() -> bool: return race.get("_racing"), 600):
		_fault("the two-player race never started")
		race.queue_free()
		return
	await _frames(20)
	var before := _snapshot()
	Input.action_press("p2_reset")
	await physics_frame
	Input.action_release("p2_reset")
	await physics_frame
	_expect("player two's reset key", before, {"resets": 1}, true)

	before = _snapshot()
	(race.get_node("Car2") as Car)._condition = 0.0
	await _frames(3)
	_expect("two players, one broken", before, {
		"races_completed": 1, "races_contested": 1, "races_won": 1,
		"cars_wrecked": 1,
	}, true)

	if not await _until(func() -> bool: return race.get("_racing"), 900):
		_fault("the next two-player race never started")
		race.queue_free()
		return
	await _frames(5)
	before = _snapshot()
	(race.get_node("Car1") as Car)._condition = 0.0
	(race.get_node("Car2") as Car)._condition = 0.0
	await _frames(3)
	_expect("two players, both broken", before, {
		"races_completed": 1, "races_contested": 1, "cars_wrecked": 2,
	}, true)

	if not await _until(func() -> bool: return race.get("_racing"), 900):
		_fault("the third two-player race never started")
		race.queue_free()
		return
	before = _snapshot()
	race.call("_finish_course", 1)
	_expect("two players, a course finished", before, {
		"races_completed": 1, "races_contested": 1, "races_won": 1,
	}, false)
	await _gone(race)
	_settings.damage = false


## The backdrop behind the title, left running, adds nothing at all - not as
## the title leaves it, and not with its cars let go and the throttles held.
func _the_title_screen() -> void:
	_settings.track_file = ""
	var backdrop: Node = load("res://scenes/main.tscn").instantiate()
	backdrop.set("attract_mode", true)
	root.add_child(backdrop)
	await _frames(5)
	var before := _snapshot()
	var on_disk := _distance_on_disk()
	await _frames(60 * 4)
	_expect("the title screen, left for four seconds", before, {}, false)

	# Now pushed. Coins are not asked about here: like the purse, they are kept
	# off the title only by its cars being parked, which is what the first half
	# proves. Distance and races are gated on the mode itself.
	before = _snapshot()
	var cars: Array[Car] = [backdrop.get_node("Car1"), backdrop.get_node("Car2")]
	var parked := cars[0].global_position
	for car in cars:
		car.frozen = false
	Input.action_press("p1_accelerate")
	Input.action_press("p2_accelerate")
	await _frames(60 * 3)
	Input.action_release("p1_accelerate")
	Input.action_release("p2_accelerate")
	# Nothing counted is only worth saying about cars that went somewhere.
	var moved := cars[0].global_position.distance_to(parked)
	if moved < 5.0:
		_fault("the title screen's cars could not be let go - moved %.1f m" % moved)
	var after := _snapshot()
	after["coins_earned"] = before["coins_earned"]
	for key in COUNTERS:
		if not is_equal_approx(float(after[key]), float(before[key])):
			_fault("the title screen, driven: %s moved from %s to %s"
				% [key, before[key], after[key]])
	print("the title screen, driven %.0f m: nothing counted" % moved)
	await _gone(backdrop)
	if not is_equal_approx(_distance_on_disk(), on_disk):
		_fault("leaving the title screen wrote driving down")


# --- helpers ----------------------------------------------------------------

func _solo() -> Node:
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	if not await _until(func() -> bool: return solo.get("_running"), 900):
		_fault("the run on %s never started" % _settings.track_file)
		solo.queue_free()
		await process_frame
		return null
	return solo


## To the flag with BotDriver in the player's seat, the way solo_run.gd drives
## it - the bot's resets go straight to the checkpoint, not through the key.
func _drive_to_the_flag(solo: Node) -> bool:
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	var bot := BotDriver.new(track, car)
	bot.finish_planning()
	car.driver = bot
	for i in 60 * 150:
		if not solo.get("_running"):
			car.driver = null
			return true
		bot.race_time = solo.get("_time")
		await physics_frame
		if bot.wants_reset() and solo.get("_running"):
			solo.call("_back_to_checkpoint")
	car.driver = null
	return false


## What moved since `before` against what was expected to. Distance and time
## are asked only whether they moved, since how far a car gets in a number of
## steps is the car's business; `driven` says whether they should have.
func _expect(what: String, before: Dictionary, wanted: Dictionary, driven: bool) -> void:
	var after := _snapshot()
	var said := PackedStringArray()
	for key in COUNTERS:
		var moved := float(after[key]) - float(before[key])
		if key == "distance_metres" or key == "time_driven_seconds":
			if not driven and moved != 0.0:
				_fault("%s: %s moved by %.2f" % [what, key, moved])
			if key == "distance_metres":
				said.append("%.0f m" % moved)
			continue
		var should := float(wanted.get(key, 0))
		if not is_equal_approx(moved, should):
			_fault("%s: %s moved by %s, not %s" % [what, key, moved, should])
		elif moved != 0.0:
			said.append("%s +%d" % [key, moved])
	print("%s: %s" % [what, ", ".join(said)])


func _snapshot() -> Dictionary:
	var out := {}
	for key in COUNTERS:
		out[key] = _stats.get(key)
	return out


func _distance_on_disk() -> float:
	var file := ConfigFile.new()
	if file.load(_stats.save_path) != OK:
		return 0.0
	return float(file.get_value("totals", "distance_metres", 0.0))


func _point(store: Node, scratch: String, reload: String) -> void:
	store.save_path = Sandbox.path(scratch)
	_scratch.append(store.save_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.save_path))
	store.call(reload)


func _gone(node: Node) -> void:
	node.queue_free()
	await process_frame
	await physics_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _until(done: Callable, frames: int) -> bool:
	for i in frames:
		if done.call():
			return true
		await physics_frame
	return done.call()


func _fault(what: String) -> void:
	print("  " + what)
	_faults += 1
