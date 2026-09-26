extends SceneTree

# Drive every way every normal track is offered, from the grid to the flag.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/variant_drive.gd
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/variant_drive.gd -- res://tracks/17_whiplash.gd
#
# variants.gd builds each variant and holds it to the rules a track is laid
# out under. This is what turns "builds clean" into "can be driven": the bot
# drives each one in Solo, through the pedals and the wheel, and a variant it
# cannot get to the flag is a road a player cannot either. The track as
# written is driven too, so the bot's time on each variant can be read beside
# its time on the road it came from - a mirror that comes out much slower or
# faster than its track is worth looking at before its medal targets are
# trusted to be the track's (see `TrackVariant.targets`).
#
# The acrobatic tracks are not driven here. The bot drives roads, not rings and
# lifts; tools/checks/acrobatic_drive.gd drives those, and takes `-- mirror`.
#
# Every jump on a normal track is level, so no reversed jump drops and none
# needs a boosted car sent off it to see where it comes down. The day a track
# with a jump that climbs offers Reverse, this is where that run goes.

## Resets allowed before a run is called undrivable. The bot is not a perfect
## driver; one stuck in the same place a dozen times is not the bot's fault.
const MAX_RESETS := 12
const PATIENCE := 60 * 240


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	settings.damage = false
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	times.save_path = "user://times_variant_drive.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
	times.load_times()

	var args := OS.get_cmdline_user_args()
	var files: Array = args if not args.is_empty() else TrackRoster.FILES
	var faults := 0
	var runs := 0
	for file: String in files:
		var line := PackedStringArray()
		var as_written := -1.0
		for variant: String in TrackVariant.offered(file):
			settings.track_file = file
			settings.track_variant = variant
			var result: Dictionary = await _run(settings)
			runs += 1
			if not result["finished"]:
				faults += 1
				print("  %s %s: did not reach the flag, stuck at %.0f m"
					% [file.get_file().get_basename(), TrackVariant.display_name(variant),
						result["progress"]])
				line.append("%s DID NOT FINISH" % TrackVariant.display_name(variant))
				continue
			var seconds: float = result["seconds"]
			if variant == TrackVariant.NORMAL:
				as_written = seconds
				line.append("NORMAL %s" % RaceClock.format(seconds))
			else:
				line.append("%s %s (%+.1f%%)" % [TrackVariant.display_name(variant),
					RaceClock.format(seconds),
					100.0 * (seconds / as_written - 1.0) if as_written > 0.0 else 0.0])
		print("%-20s %s" % [file.get_file().get_basename(), "   ".join(line)])

	settings.track_file = ""
	settings.track_variant = TrackVariant.NORMAL
	DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
	print("%d runs, %d faults" % [runs, faults])
	quit(1 if faults > 0 else 0)


## One run, the way a player gets one: the scene reads the track and the way
## off the settings, counts down, and the bot drives from GO to the flag.
func _run(settings: Node) -> Dictionary:
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	for i in 10:
		await physics_frame
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	var result := {"finished": false, "seconds": 0.0, "progress": 0.0}
	if track.variant != settings.track_variant:
		print("  the race was built %s, not %s" % [
			TrackVariant.display_name(track.variant),
			TrackVariant.display_name(settings.track_variant)])
		solo.queue_free()
		await process_frame
		return result
	var waited := 0
	while not solo.get("_running") and waited < 600:
		await physics_frame
		waited += 1

	var bot := BotDriver.new(track, car)
	bot.finish_planning()
	car.driver = bot
	var resets := 0
	for i in PATIENCE:
		if not solo.get("_running"):
			result["finished"] = true
			result["seconds"] = solo.get("_time")
			break
		bot.race_time = solo.get("_time")
		await physics_frame
		if bot.wants_reset() and solo.get("_running"):
			solo.call("_back_to_checkpoint")
			resets += 1
			if resets > MAX_RESETS:
				break
	result["progress"] = bot.progress()
	car.driver = null
	solo.queue_free()
	await process_frame
	return result
