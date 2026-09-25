extends SceneTree

# Walk to the statistics page the way a player does, and photograph it empty and
# full.
#   Godot --path . --script tools/checks/stats_shot.gd -- <out_dir>
#
# Not headless: it takes pictures. Opens the track screen, presses STATISTICS,
# shoots the page on a profile that has driven nothing, puts some totals and a
# few best times behind it, shoots it again, and backs out with Escape - which
# has to close the page and leave the keyboard on the button that opened it.
# Then the same page the other way in, from the settings on the title.
#
# Both stores are pointed at scratch before the menu is built, so the empty
# shot is empty whatever the sandbox already had in it, and both are deleted on
# the way out. Fetched out of the tree rather than named, because a --script
# file is compiled before the autoloads have registered their names.

const STATS_SCRATCH := "user://stats_shot.cfg"
const TIMES_SCRATCH := "user://times_stats_shot.cfg"

var _faults := 0


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	var stats: Node = root.get_node(^"/root/Stats")
	var times: Node = root.get_node(^"/root/TrackTimes")
	var settings: Node = root.get_node(^"/root/GameSettings")
	stats.save_path = Sandbox.path(STATS_SCRATCH)
	times.save_path = Sandbox.path(TIMES_SCRATCH)
	_wipe(stats.save_path)
	_wipe(times.save_path)
	stats.load_stats()
	times.load_times()
	settings.track_file = ""
	settings.damage = false

	change_scene_to_file("res://scenes/menu.tscn")
	for i in 20:
		await process_frame
	var menu: Node = current_scene
	menu.call("_on_play_pressed")
	await _settle(10)
	menu.call("_open_track_grid")
	await _settle(10)
	var button: Button = menu.get_node("TrackChoice/Page/Panel/Margin/Box/Pages/Stats")
	var page: Control = menu.get_node("StatsScreen")
	if not button.is_visible_in_tree():
		_fault("the track screen has no STATISTICS button showing")
	_shot(out, "stats_track_screen")

	button.emit_signal("pressed")
	await _settle(6)
	if not page.visible:
		_fault("pressing STATISTICS did not open the page")
	_shot(out, "stats_empty")

	# Something to count: driving, a few races of each kind, and best times on
	# three tracks - one gold, one with no medal, and one acrobatic.
	stats.add_distance(48250.0, 5820.0)
	for i in 14:
		stats.race_finished(false, false)
	for i in 9:
		stats.race_finished(true, i % 3 != 0)
	stats.wrecked(2)
	for i in 23:
		stats.reset_taken()
	stats.coins_collected(137)
	for index in [0, 3, TrackRoster.first(TrackRoster.ACROBATIC)]:
		var targets: Vector3 = TrackRoster.targets(index)
		var seconds: float = targets.x - 0.5 if index != 3 else targets.z + 4.0
		times.record(TrackRoster.file(index), seconds)
	# The page follows Stats.changed, but a time is not a total, so it is
	# opened again the way a player coming back to it would.
	page.call("open")
	await _settle(6)
	_shot(out, "stats_full")
	print("full: %s" % _totals(page))

	settings.damage = true
	await _settle(4)
	_shot(out, "stats_full_damage_on")
	settings.damage = false

	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await _settle(4)
	if page.visible:
		_fault("Escape did not close the page")
	if root.gui_get_focus_owner() != button:
		_fault("closing the page left the keyboard on %s, not the button"
			% root.gui_get_focus_owner())
	_shot(out, "stats_closed")

	await _from_the_settings(menu, out)

	_wipe(stats.save_path)
	_wipe(times.save_path)
	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


## The other way in: Settings, then Statistics. Walked from the title, where
## a player looking for their totals by name will try first. Escape backs out
## of the page onto the button that opened it, and then off the settings.
func _from_the_settings(menu: Node, out: String) -> void:
	menu.call("_close_track_choice")
	await _settle(10)
	menu.call("_close_mode_choice")
	await _settle(10)
	menu.get_node("Settings").emit_signal("pressed")
	await _settle(6)
	var settings: Control = menu.get_node("SettingsScreen")
	var button: Button = settings.get_node("SettingsPage/Panel/Margin/Box/Pages/Stats")
	var page: Control = settings.get_node("StatsScreen")
	if not button.is_visible_in_tree():
		_fault("the settings have no STATISTICS button showing")
	_shot(out, "stats_settings")
	button.emit_signal("pressed")
	await _settle(6)
	if not page.visible:
		_fault("pressing STATISTICS in the settings did not open the page")
	if (settings.get_node("SettingsPage") as Control).visible:
		_fault("the settings panel is still showing under the statistics")
	_shot(out, "stats_from_settings")

	_press_escape()
	await _settle(4)
	if page.visible or not settings.visible:
		_fault("Escape did not take the statistics back to the settings")
	if root.gui_get_focus_owner() != button:
		_fault("closing the statistics left the keyboard on %s, not the button"
			% root.gui_get_focus_owner())
	_press_escape()
	await _settle(4)
	if settings.visible:
		_fault("a second Escape did not close the settings")


func _press_escape() -> void:
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	var up := InputEventAction.new()
	up.action = "ui_cancel"
	up.pressed = false
	Input.parse_input_event(up)


func _totals(page: Node) -> String:
	var parts := PackedStringArray()
	var names: Dictionary = page.get("_names")
	var values: Dictionary = page.get("_values")
	for key in names:
		parts.append("%s %s" % [(names[key] as Label).text, (values[key] as Label).text])
	return ", ".join(parts)


func _settle(frames: int) -> void:
	for i in frames:
		await process_frame


func _shot(out: String, name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _wipe(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fault(what: String) -> void:
	print("  " + what)
	_faults += 1
