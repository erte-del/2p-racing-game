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
# a rival worth racing.

const MAX_RESETS := 2
const PATIENCE := 60 * 200


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

	print("bot at difficulty %.2f" % difficulty)
	print("%-3s %-16s %8s %8s %7s %13s %6s %s"
		% ["", "track", "bot", "gold", "vs", "plan", "resets", "hits"])
	var faults := 0
	var over := PackedFloat32Array()
	for file: String in files:
		settings.track_file = file
		var solo: Node = load("res://scenes/solo.tscn").instantiate()
		root.add_child(solo)
		for i in 10:
			await physics_frame
		var track: Track = solo.get_node("Track")
		var car: Car = solo.get_node("Car")
		var started := Time.get_ticks_msec()
		var bot := BotDriver.new(track, car, difficulty)
		var planned := Time.get_ticks_msec() - started
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
		print("%-3d %-16s %8s %8s %7s %5dms %d laps %6d %s"
			% [TrackRoster.index_of(file) + 1, track.definition().track_name,
				RaceClock.format(lap) if finished else "DNF",
				RaceClock.format(gold), versus, planned, bot.laps_practised(), resets,
				("%d at %s m" % [hits.size(), ", ".join(where)]) if not hits.is_empty() else "0"])
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
