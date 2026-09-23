extends SceneTree

# Let the bot drive every normal track, and set its time against the gold.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_race.gd
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_race.gd -- 0.6
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/bot_race.gd -- 1.0 res://tracks/07_pinch.gd
#
# The first argument is the difficulty, 1 when left out; anything after it is
# the tracks to drive, all twenty normal ones when there are none.
#
# This is the number that says whether "hard to beat" is true. The bot race
# asks the player to beat a car that comes in around the track's gold, so a
# player with the golds to open the race can win it and one without cannot. A
# bot well over gold is a race nobody loses; one well under is a door nobody
# gets through. It wants running again every time the car is retuned, since
# the bot drives the car as it is and the golds do not move with it.
#
# The bot drives the solo scene exactly as a player would: its car is the
# player's car, told to take its pedals and wheel from BotDriver instead of the
# keyboard, and when the bot says it would press the reset key the race does
# what it does for the key. So a finish here is a run a player could have
# driven, and the clock on it is the race's own.
#
# A fault is a track the bot does not finish, or one it has to be put back on
# more than MAX_RESETS times: a bot that finishes only by being rescued is not
# a rival worth racing - or one whose line cost a frame more than MAX_FRAME_MS
# to work out.
#
# The plan is driven here the way a race drives it: BUDGET_MS at a time, once per
# would-be frame. The "plan" column is still the whole cost of it, which is the
# number that says how much of a countdown a road needs, and "worst" is the
# longest any single one of those calls took. Worst is the one that matters for
# whether a player sees a hitch, and it is printed so that a regression in it is
# visible rather than felt.

const MAX_RESETS := 2
const PATIENCE := 60 * 200
## What a frame is allowed to spend planning, and the point at which one call to
## plan_a_little counts as a fault.
##
## The ceiling is not the budget plus a little. A budget is honoured between
## units of work, so a call overshoots by at most the one unit it was in the
## middle of - about half a millisecond - and the steady figure is five. But this
## is wall-clock time on a machine doing other things, and the same call measured
## again comes out anywhere from 4.3 to 7.3 ms. So the ceiling is set where the
## number would actually start to matter: a frame at 60 Hz is 16.7 ms, and 12 is
## where planning alone is in danger of costing one. The printed number is the
## signal to watch - a regression shows up there long before it trips this.
const BUDGET_MS := 4.0
const MAX_FRAME_MS := 12.0


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var difficulty: float = float(args[0]) if not args.is_empty() else 1.0
	var files: Array = args.slice(1) if args.size() > 1 else TrackRoster.FILES

	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	settings.damage = false
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times != null:
		times.save_path = "user://times_bot_race.cfg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
		times.load_times()

	print("bot at difficulty %.2f, planning %.0f ms a frame" % [difficulty, BUDGET_MS])
	print("%-3s %-16s %8s %8s %7s %18s %9s %6s %s"
		% ["", "track", "bot", "gold", "vs", "plan", "worst", "resets", "hits"])
	var faults := 0
	var over := PackedFloat32Array()
	var worst_anywhere := 0.0
	for file: String in files:
		settings.track_file = file
		var solo: Node = load("res://scenes/solo.tscn").instantiate()
		root.add_child(solo)
		for i in 10:
			await physics_frame
		var track: Track = solo.get_node("Track")
		var car: Car = solo.get_node("Car")
		# Planned the way the race plans it: a frame's worth at a time, with the
		# longest of those calls kept. Driven in a tight loop rather than over
		# real frames because what is being measured is the cost of a call, not
		# the wall clock of a countdown.
		var started := Time.get_ticks_usec()
		var bot := BotDriver.new(track, car, difficulty)
		var worst := 0.0
		var frames := 0
		while not bot.is_planned():
			var at := Time.get_ticks_usec()
			bot.plan_a_little(BUDGET_MS)
			worst = maxf(worst, float(Time.get_ticks_usec() - at) / 1000.0)
			frames += 1
		var planned := float(Time.get_ticks_usec() - started) / 1000.0
		worst_anywhere = maxf(worst_anywhere, worst)
		car.driver = bot

		var waited := 0
		while not solo.get("_running") and waited < 600:
			await physics_frame
			waited += 1
		var hits := []
		var resets := await _drive(solo, bot, hits)
		var finished: bool = not solo.get("_running")
		var lap: float = solo.get("_time")
		var gold: float = TrackRoster.targets(TrackRoster.index_of(file)).x
		var versus := ""
		if finished and gold > 0.0:
			versus = "%+6.1f%%" % ((lap / gold - 1.0) * 100.0)
			over.append(lap / gold - 1.0)
		var where := PackedStringArray()
		for at: float in hits:
			where.append("%.0f" % at)
		print("%-3d %-16s %8s %8s %7s %6.0fms/%3df %d laps %7.2fms %6d %s"
			% [TrackRoster.index_of(file) + 1, track.definition().track_name,
				RaceClock.format(lap) if finished else "DNF",
				RaceClock.format(gold), versus, planned, frames, bot.laps_practised(),
				worst, resets,
				("%d at %s m" % [hits.size(), ", ".join(where)]) if not hits.is_empty() else "0"])
		if worst > MAX_FRAME_MS:
			faults += 1
			print("  one frame spent %.2f ms planning, over the %.0f ms ceiling"
				% [worst, MAX_FRAME_MS])
		if not finished:
			faults += 1
			print("  never finished, stuck around %.0f m" % bot.progress())
		elif resets > MAX_RESETS:
			faults += 1
			print("  had to be put back %d times" % resets)
		car.driver = null
		solo.queue_free()
		await process_frame

	if not over.is_empty():
		var total := 0.0
		for value in over:
			total += value
		print("on average %+.1f%% against gold" % (total / over.size() * 100.0))
	print("worst planning frame anywhere %.2f ms, against a %.0f ms ceiling"
		% [worst_anywhere, MAX_FRAME_MS])
	if times != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Drive until the flag, putting the car back when the bot asks. Returns how
## many times it asked.
func _drive(solo: Node, bot: BotDriver, hits: Array) -> int:
	var resets := 0
	var was_recovering := 0.0
	for step in PATIENCE:
		if not solo.get("_running"):
			return resets
		bot.race_time = solo.get("_time")
		await physics_frame
		# Just hit something: the car's recovery from a hit has gone up rather
		# than down since the last step.
		var car: Car = solo.get_node("Car")
		var recovering: float = car.get("_hit_recovery")
		if recovering > was_recovering:
			hits.append(bot.progress())
		was_recovering = recovering
		if bot.wants_reset() and solo.get("_running"):
			solo.call("_back_to_checkpoint")
			resets += 1
	return resets
