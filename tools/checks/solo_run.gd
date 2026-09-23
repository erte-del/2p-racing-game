extends SceneTree

# Run a track solo, from the line to the flag.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/solo_run.gd
#
# --fixed-fps matters. Without it the loop sleeps to hold sixty ticks a second
# of wall clock, and driving a kilometre of road takes as long as driving a
# kilometre of road; with it the same run takes about a second.
#
# The car is driven by BotDriver, the same driver the bot race puts in the
# other car, through the pedals and the wheel the way a player drives it. What
# is being asked is not whether it drives well - bot_race.gd asks that - but
# whether the mode works at all: whether the clock starts on GO and stops on
# the line, whether checkpoints bank, whether a reset costs time rather than
# ending the run, and whether a second run is timed afresh.


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
	var banked: int = (solo.get("_banked") as PackedByteArray).count(1)
	if banked != track.checkpoint_offsets().size():
		print("  not every checkpoint was banked: %d of %d"
			% [banked, track.checkpoint_offsets().size()])
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

	faults += await _check_the_endless_course(solo)

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## The same scene with nothing picked is the endless course: a rolled road
## every time, no time to beat and nothing to write down.
func _check_the_endless_course(previous: Node) -> int:
	var faults := 0
	previous.queue_free()
	await Engine.get_main_loop().process_frame

	var settings: Node = Engine.get_main_loop().root.get_node_or_null(
		^"/root/GameSettings")
	settings.track_file = ""
	settings.chaos = false

	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	Engine.get_main_loop().root.add_child(solo)
	for i in 10:
		await Engine.get_main_loop().physics_frame
	var track: Track = solo.get_node("Track")

	if track.definition() != null:
		print("  the endless course came out as a laid-out track")
		faults += 1
	if not String(solo.get_node("Hud/Best").text).is_empty():
		print("  the endless course is offering a time to beat")
		faults += 1
	print("endless rolls %.0f m of road, with %s"
		% [track.length(), track.features().summary()])

	# Another go is another road, not the same one again.
	var was := track.length()
	var was_here: Vector3 = track.curve().sample_baked(20.0)
	solo.call("_restart")
	await Engine.get_main_loop().process_frame
	var now_here: Vector3 = track.curve().sample_baked(20.0)
	if is_equal_approx(was, track.length()) and was_here.is_equal_approx(now_here):
		print("  asking for another go on the endless course gave the same road")
		faults += 1
	else:
		print("another go rolls another road, %.0f m of it" % track.length())
	if solo.get("_time") > 0.01:
		print("  the new course did not start the clock afresh")
		faults += 1
	solo.queue_free()
	await Engine.get_main_loop().process_frame

	# And chaos on top of it has to survive being built with one car.
	settings.chaos = true
	var wild: Node = load("res://scenes/solo.tscn").instantiate()
	Engine.get_main_loop().root.add_child(wild)
	for i in 10:
		await Engine.get_main_loop().physics_frame
	var car: Car = wild.get_node("Car")
	# What the car is tuned to, read off the scene rather than written down
	# here. A number in a check is a number that goes stale the first time the
	# car is retuned, and this one would go stale quietly: it would stop
	# meaning "chaos changed something" and start meaning nothing at all.
	var stock: Car = load("res://scenes/car/car.tscn").instantiate()
	var tuned_speed: float = stock.max_speed
	stock.queue_free()
	print("under chaos the one car tops out at %.1f m/s against %.1f tuned"
		% [car.max_speed, tuned_speed])
	if is_equal_approx(car.max_speed, tuned_speed):
		print("  chaos rolled nothing at all")
		faults += 1
	settings.chaos = false
	wild.queue_free()
	return faults


## Drive the car to the flag with the bot, putting it back at its last
## checkpoint whenever the bot says it would press the key.
##
## A driver of its own here would be a second copy of the bot, and two copies
## of a driver drift: this one used to turn the car by rotating its body and
## set its speed outright, which drives nothing like the car a player has.
func _drive(solo: Node, track: Track, car: Car) -> bool:
	var bot := BotDriver.new(track, car)
	bot.finish_planning()
	car.driver = bot
	var resets := 0
	for i in 60 * 150:
		if not solo.get("_running"):
			car.driver = null
			return true
		bot.race_time = solo.get("_time")
		await physics_frame
		if bot.wants_reset() and solo.get("_running"):
			solo.call("_back_to_checkpoint")
			resets += 1
			if resets > 12:
				print("  the car could not get past %.0f m in twelve tries"
					% bot.progress())
				break
	car.driver = null
	return false


## The whole of what the finish screen is saying, on one line.
##
## The words are a long way down from Result. Result itself is only the layer
## that is shown and hidden - which is why the checks above still ask it, and
## not the panel, whether finishing said anything - and it holds the badge as
## well as the panel. The labels are in the box inside the panel's margin,
## centred on the screen. They are asked for by that whole path rather than
## found by name, so that the next time the finish screen is rearranged this
## stops on the node that went missing instead of quietly reading whichever
## label further down happens to be called Time.
func _result(solo: Node) -> String:
	var parts := PackedStringArray()
	for name in ["Time", "Medal", "Note"]:
		var text: String = solo.get_node(
			"Hud/Result/Centre/Panel/Margin/Box/%s" % name).text
		if not text.is_empty():
			parts.append(text)
	return " / ".join(parts)


func _clock(seconds: float) -> String:
	return "%.2f s" % seconds
