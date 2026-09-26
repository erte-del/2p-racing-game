extends SceneTree

# Every screen, on every shape of screen - and the column of buttons on the
# title, which is not on a panel and has to be measured on its own.
#   Godot --path . --headless --script tools/checks/screen_fit.gd
#
# The game is laid out once, in a 1600x900 space, and Godot scales that up to
# whatever window it is in. What this checks is that the laid-out space really
# is the same everywhere - a square screen is allowed to be taller, and a wide
# one wider, but neither may be smaller - and that no page runs off the edge
# of it once it is. A panel half off the screen is a page a player cannot
# press their way out of.
#
# Every page is checked at the largest interface size a player can choose,
# because that is the tightest the screen ever gets: the scale divides the
# laid-out space, so 1600x900 at 1.2 leaves a page 1333x750 to fit inside and
# anything smaller only ever hands it more room. One pass at the ceiling
# therefore covers the whole range of the setting.

## Windows worth trying: a laptop, the common desktop, a big desktop, an
## ultra-wide, and the squarest screen anybody still races on.
const WINDOWS: Array[Vector2i] = [
	Vector2i(1366, 768), Vector2i(1920, 1080), Vector2i(2560, 1440),
	Vector2i(2560, 1080), Vector2i(1024, 768),
]
## The space the game is laid out in, before the player's own scale.
const REFERENCE := Vector2(1600.0, 900.0)
## Where the ceiling on that scale is kept. Read from the file at run time
## rather than written down again here, and neither named as the autoload it
## usually is nor preloaded.
##
## A script run with `--script` replaces the main loop and is compiled before
## the autoloads are registered, so `GameSettings` is not an identifier here
## yet - it is by the time the menu is loaded, which is why every other script
## may still say it. Preloading the file instead is worse than useless: having
## the script loaded before the autoloads are set up leaves `GameSettings` and
## `Garage` as bare Nodes with no script on them, and the pages that lean on
## them - the garage above all - then fail to open rather than failing to fit,
## which a check that only looks at what is on the screen would call a pass.
const SETTINGS_PATH := "res://scripts/game_settings.gd"


func _init() -> void:
	await process_frame
	# The worst case, and the one the numbers below are measured against. Set
	# on the window rather than through the setting, for the same reason: this
	# is the property the setting writes, and it is reachable from here.
	var most: float = load(SETTINGS_PATH).UI_SCALE_MAX
	root.content_scale_factor = most
	var laid_out_least := REFERENCE / most
	print("at %d%% interface size a page has %d x %d to fit in"
		% [roundi(most * 100.0), laid_out_least.x, laid_out_least.y])
	var faults := 0
	for window in WINDOWS:
		faults += await _check(window, laid_out_least)
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


func _check(window: Vector2i, laid_out_least: Vector2) -> int:
	root.size = window
	await process_frame
	var laid_out := root.get_visible_rect().size
	print("%d x %d lays out as %d x %d" % [window.x, window.y, laid_out.x, laid_out.y])
	var faults := 0
	if laid_out.x < laid_out_least.x - 0.5 or laid_out.y < laid_out_least.y - 0.5:
		print("  less room than the game is laid out for")
		faults += 1

	change_scene_to_file("res://scenes/menu.tscn")
	for i in 20:
		await process_frame
	var menu: Node = current_scene

	# The title itself, then every page that opens over it, each one opened
	# the way a player opens it.
	faults += _fits("the title", menu, laid_out)
	faults += _column_fits(menu, laid_out)
	menu.call("_on_play_pressed")
	for i in 10:
		await process_frame
	faults += _fits("choosing a mode", menu.get_node("ModeChoice"), laid_out)
	menu.call("_open_track_grid")
	for i in 10:
		await process_frame
	faults += _fits("choosing a track", menu.get_node("TrackChoice"), laid_out)
	# Every track's own page: the picture, its board and the player's place,
	# three columns across, which makes it the widest page the menu has. All of
	# them rather than one, because the name and the line under it are each
	# track's own, and the longest is the one that decides.
	#
	# Each with HARD held down where the track shows it: a way the track does
	# not offer puts a line under PLAY saying why, which makes that column as
	# tall as it gets.
	var pages := 0
	var hard: Button = menu.get_node(
		"TrackDetail/Page/Panel/Margin/Box/Body/Left/Variants/Hard")
	for index in TrackRoster.TOTAL:
		if not menu.call("_has_a_page", index):
			continue
		menu.call("_open_track_detail", index)
		if hard.visible:
			hard.button_pressed = true
			menu.call("_choose_detail_variant", TrackVariant.HARD)
		for i in 4:
			await process_frame
		var fault := _fits("%s's page" % TrackRoster.track_name(index),
			menu.get_node("TrackDetail"), laid_out, false)
		faults += fault
		if fault == 0:
			pages += 1
		menu.call("_close_track_detail")
	print("  %d track pages fit" % pages)
	menu.call("_close_track_choice")
	for i in 5:
		await process_frame

	for named in ["SettingsScreen", "AccountScreen", "GarageScreen", "LeaderboardScreen",
			"ShopScreen", "StatsScreen"]:
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
		# The garage has two tabs and only one of them is up when it opens, so
		# the other one is a page this check would never look at. It is also
		# the taller of the two to build - a car standing in a viewport, a
		# board to drag stickers about on and three rows of tools - so it is
		# exactly the half most likely to run off the bottom.
		if named == "GarageScreen":
			screen.call("_show_tab", 1)
			for i in 10:
				await process_frame
			faults += _fits("the decoration tab", screen, laid_out)
			screen.call("_show_tab", 0)
			for i in 5:
				await process_frame
		# The statistics page is two pages in one: a line saying nothing has
		# been driven yet, and eight totals with a note under them. The second
		# is the taller, and a fresh sandbox only ever shows the first, so it is
		# given something to count - in a scratch file, thrown away after.
		if named == "StatsScreen":
			faults += await _stats_full_fits(screen, laid_out)
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
	# The paint screen only opens over a paused race, so this is the one place
	# it can be measured. It is here because it grew a row when the shop was
	# given paints to sell, and a page that grows is a page that can stop
	# fitting.
	var paint: Node = pause.get_node("PaintScreen")
	paint.call("open", 2)
	for i in 10:
		await process_frame
	faults += _fits("painting", paint, laid_out)
	paint.call("close")
	for i in 5:
		await process_frame
	pause.call("close")
	for i in 5:
		await process_frame
	return faults


## The statistics page with every total showing and the damage note under
## them, which is as tall as it gets.
func _stats_full_fits(screen: Node, laid_out: Vector2) -> int:
	var stats: Node = root.get_node(^"/root/Stats")
	var settings: Node = root.get_node(^"/root/GameSettings")
	var kept: String = stats.save_path
	var damage: bool = settings.damage
	stats.save_path = Sandbox.path("user://stats_fit_check.cfg")
	settings.damage = false
	stats.add_distance(12345.0, 600.0)
	stats.race_finished(true, true)
	for i in 10:
		await process_frame
	var faults := _fits("StatsScreen, with totals", screen, laid_out)
	stats.forget()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stats.save_path))
	stats.save_path = kept
	stats.load_stats()
	settings.damage = damage
	return faults


## The column of buttons down the middle of the title, which is the one part
## of the game that is not inside a panel and so is not caught by `_fits`.
##
## It is measured because it is the part most likely to run off the bottom:
## every button added to it makes it taller, it is anchored part of the way
## down a screen whose height the player can change, and nothing else about
## the game would notice.
##
## Hidden buttons are measured too, and that is the point rather than an
## oversight. ACCOUNT is the lowest of them and is the one that falls off, and
## it is also the one that is not there in a build with no server in it - so
## skipping what cannot be seen would be skipping the failure, in exactly the
## build a developer is most likely to run this in. A hidden Control is still
## laid out, so its corner is the corner it would have if the build had a
## server.
func _column_fits(menu: Node, laid_out: Vector2) -> int:
	var faults := 0
	var lowest := 0.0
	var named := ""
	for what in ["Play", "Garage", "Shop", "Settings", "Account", "Purse"]:
		var control := menu.get_node_or_null(NodePath(what)) as Control
		if control == null:
			print("  the title has no %s on it" % what)
			faults += 1
			continue
		var corner := control.get_global_rect()
		if corner.position.y < -0.5 or corner.end.y > laid_out.y + 0.5 \
				or corner.position.x < -0.5 or corner.end.x > laid_out.x + 0.5:
			print("  %s runs off the screen: %.0f,%.0f to %.0f,%.0f in %.0f x %.0f"
				% [what, corner.position.x, corner.position.y, corner.end.x,
					corner.end.y, laid_out.x, laid_out.y])
			faults += 1
		if corner.end.y > lowest:
			lowest = corner.end.y
			named = what
	if faults == 0:
		print("  the title column fits, %s lowest at %.0f of %.0f"
			% [named, lowest, laid_out.y])
	return faults


## Everything with a frame round it, inside the room there is. Panels are what
## the pages are made of, and a panel that fits took its contents with it.
## `say` is false for a page tried many times over, which reports a count of
## its own rather than a line for every one that fits.
func _fits(what: String, where: Node, laid_out: Vector2, say := true) -> int:
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
	if say and seen > 0 and faults == 0:
		print("  %s fits" % what)
	return faults
