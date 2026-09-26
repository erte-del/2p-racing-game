extends SceneTree

# Photograph the leaderboard page with its row of ways.
#   Godot --path . --script tools/checks/leaderboard_shot.gd -- <out_dir>
#
# Not headless: it takes pictures. Opens the page three ways - on Whiplash
# driven Hard, the way a player back from a Hard run finds it; on Whiplash with
# REVERSE held, which Whiplash is not driven, so REVERSE is faded; and on an
# acrobatic track, whose row has NORMAL and MIRROR and nothing else.
#
# Opened straight rather than off the track screen's button. A check has no
# backend (see `Sandbox`), and with no backend there are no boards and the
# button is not shown - so every shot says there is no server, which is what
# this page says on a copy built without one. The row of ways is what is being
# looked at. variant_pages.gd checks what the row does.

var _faults := 0


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	var settings: Node = root.get_node(^"/root/GameSettings")
	settings.track_file = ""
	settings.track_variant = TrackVariant.NORMAL

	change_scene_to_file("res://scenes/menu.tscn")
	for i in 20:
		await process_frame
	var menu: Node = current_scene
	menu.call("_on_play_pressed")
	await _settle(10)
	menu.call("_open_track_grid")
	await _settle(10)
	var page: Control = menu.get_node("LeaderboardScreen")
	var ways: Node = page.call("ways")

	page.call("open", "res://tracks/17_whiplash.gd", TrackVariant.HARD)
	await _settle(6)
	if not page.visible:
		_fault("the page did not open")
	if not (ways.call("button", TrackVariant.HARD) as Button).button_pressed:
		_fault("opened on HARD without HARD held down")
	_shot(out, "board_hard")

	var reverse: Button = ways.call("button", TrackVariant.REVERSE)
	reverse.button_pressed = true
	reverse.pressed.emit()
	await _settle(6)
	_shot(out, "board_reverse_refused")

	page.call("close")
	page.call("open", TrackRoster.file(TrackRoster.first(TrackRoster.ACROBATIC)),
		TrackVariant.MIRROR)
	await _settle(6)
	for variant in [TrackVariant.HARD, TrackVariant.TRACK_CHAOS, TrackVariant.REVERSE]:
		if (ways.call("button", variant) as Button).visible:
			_fault("an acrobatic track's row shows %s" % TrackVariant.display_name(variant))
	_shot(out, "board_acrobatic_mirror")
	page.call("close")

	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


func _settle(frames: int) -> void:
	for i in frames:
		await process_frame


func _shot(out: String, name: String) -> void:
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


func _fault(what: String) -> void:
	print("  " + what)
	_faults += 1
