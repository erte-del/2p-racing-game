extends SceneTree

# Walk in through the pages and see which scene comes out the far end.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/mode_routing.gd
#
# There are two questions asked before a race and two scenes it can run in,
# which is four ways in and four chances for one of them to land somewhere it
# should not. How many are playing is the only one that decides the scene;
# everything else is a setting the scene reads.

const SOLO := "Solo"
const COOP := "Main"


func _init() -> void:
	await process_frame
	var settings: Node = root.get_node_or_null(^"/root/GameSettings")
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times != null:
		times.save_path = "user://times_routing_check.cfg"
		times.load_times()

	var faults := 0
	for trial: Array in [
		[true, "infinite", SOLO], [false, "infinite", COOP],
		[true, "track", SOLO], [false, "track", COOP],
	]:
		var solo: bool = trial[0]
		var mode: String = trial[1]
		var wanted: String = trial[2]
		settings.track_file = ""

		var menu: Node = load("res://scenes/menu.tscn").instantiate()
		root.add_child(menu)
		for i in 15:
			await process_frame

		menu.call("_on_play_pressed")
		await process_frame
		if not menu.get_node("PlayerChoice").visible:
			print("  play did not ask how many are playing")
			faults += 1
		menu.call("_choose_players", solo)
		await process_frame
		if menu.get_node("PlayerChoice").visible or not menu.get_node("ModeChoice").visible:
			print("  answering how many did not open the modes")
			faults += 1

		if mode == "infinite":
			menu.call("_start_infinite", false)
		else:
			menu.call("_start_track", TrackRoster.file(0))
		for i in 30:
			await process_frame

		var race := root.get_child(root.get_child_count() - 1)
		var got: String = race.name
		var right := got.begins_with(wanted)
		print("%-5s + %-8s -> %s%s"
			% ["solo" if solo else "co-op", mode, got, "" if right else "   WRONG"])
		if not right:
			faults += 1
			race.queue_free()
			await process_frame
			continue

		# And the scene has to be running what was asked for, not merely be
		# the right kind of scene.
		var track: Track = race.get_node_or_null("Track")
		var laid_out: bool = track != null and track.definition() != null
		if laid_out != (mode == "track"):
			print("  %s + %s is running %s"
				% ["solo" if solo else "co-op", mode,
					"a laid-out track" if laid_out else "a rolled course"])
			faults += 1
		race.queue_free()
		await process_frame

	# Backing out walks the same way in reverse.
	settings.track_file = ""
	var menu2: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu2)
	for i in 15:
		await process_frame
	menu2.call("_on_play_pressed")
	menu2.call("_choose_players", true)
	menu2.call("_on_tracks_pressed")
	await process_frame
	var ladder := PackedStringArray()
	for step in 3:
		if menu2.get_node("TrackChoice").visible:
			ladder.append("tracks")
			menu2.call("_close_track_choice")
		elif menu2.get_node("ModeChoice").visible:
			ladder.append("modes")
			menu2.call("_close_mode_choice")
		elif menu2.get_node("PlayerChoice").visible:
			ladder.append("how many")
			menu2.call("_close_player_choice")
		await process_frame
	print("backing out goes %s, then the title" % " -> ".join(ladder))
	if ladder != PackedStringArray(["tracks", "modes", "how many"]):
		print("  backing out did not walk the way in, in reverse")
		faults += 1
	menu2.queue_free()

	if times != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)
