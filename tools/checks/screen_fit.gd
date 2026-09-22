extends SceneTree

# Every screen, on every shape of screen.
#   Godot --path . --headless --script tools/checks/screen_fit.gd
#
# The game is laid out once, in a 1280x720 space, and Godot scales that up to
# whatever window it is in. What this checks is that the laid-out space really
# is the same everywhere - a square screen is allowed to be taller than 720,
# and a wide one wider than 1280, but neither may be smaller - and that no
# page runs off the edge of it once it is. A panel half off the screen is a
# page a player cannot press their way out of.

## Windows worth trying: a laptop, the common desktop, a big desktop, an
## ultra-wide, and the squarest screen anybody still races on.
const WINDOWS: Array[Vector2i] = [
	Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(2560, 1440),
	Vector2i(2560, 1080), Vector2i(1024, 768),
]
const LAID_OUT := Vector2(1280.0, 720.0)


func _init() -> void:
	await process_frame
	var faults := 0
	for window in WINDOWS:
		faults += await _check(window)
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


func _check(window: Vector2i) -> int:
	root.size = window
	await process_frame
	var laid_out := root.get_visible_rect().size
	print("%d x %d lays out as %d x %d" % [window.x, window.y, laid_out.x, laid_out.y])
	var faults := 0
	if laid_out.x < LAID_OUT.x - 0.5 or laid_out.y < LAID_OUT.y - 0.5:
		print("  less room than the game is laid out for")
		faults += 1

	change_scene_to_file("res://scenes/menu.tscn")
	for i in 20:
		await process_frame
	var menu: Node = current_scene

	# The title itself, then every page that opens over it, each one opened
	# the way a player opens it.
	faults += _fits("the title", menu, laid_out)
	menu.call("_on_play_pressed")
	for i in 10:
		await process_frame
	faults += _fits("choosing a mode", menu.get_node("ModeChoice"), laid_out)
	menu.call("_open_track_grid")
	for i in 10:
		await process_frame
	faults += _fits("choosing a track", menu.get_node("TrackChoice"), laid_out)
	menu.call("_close_track_choice")
	for i in 5:
		await process_frame

	for named in ["SettingsScreen", "AccountScreen", "GarageScreen", "LeaderboardScreen"]:
		var screen: Node = menu.get_node(named)
		if named == "GarageScreen":
			screen.call("open", 2)
		elif named == "LeaderboardScreen":
			screen.call("open", TrackRoster.file(0))
		else:
			screen.call("open")
		for i in 10:
			await process_frame
		faults += _fits(named, screen, laid_out)
		screen.call("close")
		for i in 5:
			await process_frame

	# And the one page that opens over a race rather than over the title.
	change_scene_to_file("res://scenes/main.tscn")
	for i in 20:
		await process_frame
	var race: Node = current_scene
	var pause: Node = race.get_node("Pause")
	pause.call("open", "FIRST LIGHT", "ANOTHER GO")
	for i in 10:
		await process_frame
	faults += _fits("paused", pause, laid_out)
	pause.call("close")
	for i in 5:
		await process_frame
	return faults


## Everything with a frame round it, inside the room there is. Panels are what
## the pages are made of, and a panel that fits took its contents with it.
func _fits(what: String, where: Node, laid_out: Vector2) -> int:
	var faults := 0
	var seen := 0
	for node in where.find_children("*", "PanelContainer", true, false):
		var panel := node as PanelContainer
		if not panel.is_visible_in_tree():
			continue
		seen += 1
		var corner := panel.get_global_rect()
		if corner.position.x < -0.5 or corner.position.y < -0.5 \
				or corner.end.x > laid_out.x + 0.5 or corner.end.y > laid_out.y + 0.5:
			print("  %s runs off the screen: %.0f,%.0f to %.0f,%.0f in %.0f x %.0f"
				% [what, corner.position.x, corner.position.y, corner.end.x,
					corner.end.y, laid_out.x, laid_out.y])
			faults += 1
	if seen > 0 and faults == 0:
		print("  %s fits" % what)
	return faults
