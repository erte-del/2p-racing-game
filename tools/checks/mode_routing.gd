extends SceneTree

# Walk in through the pages and see which scene comes out the far end.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/mode_routing.gd
#
# There are two questions asked before a race and two scenes it can run in,
# which is four ways in and four chances for one of them to land somewhere it
# should not. How many are playing is the only one that decides the scene;
# everything else is a setting the scene reads.
#
# The way a track is driven is one of those settings, and it has to survive
# both routes: a mirrored track picked for two players is a mirrored race. An
# infinite race after it has to have forgotten it.

const SOLO := "Solo"
const COOP := "Main"


## Every other button on the page says what it is in words. The chaos one also
## says it by never settling on a colour, so what is checked is that it is
## still moving a second later and that it has gone somewhere, rather than
## drifting a shade and stopping.
func _check_the_chaos_button(menu: Node) -> int:
	var chaos: Button = menu.get_node(
		"ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/FlavourSlot/Inner/Row/Chaos")
	var seen: Array[Color] = []
	for sample in 4:
		seen.append(chaos.modulate)
		for i in 30:
			await Engine.get_main_loop().process_frame

	var faults := 0
	for i in range(1, seen.size()):
		if seen[i].is_equal_approx(seen[i - 1]):
			print("  the chaos button held the same colour for half a second")
			faults += 1
	# And it goes somewhere rather than wobbling: half a turn of the colours
	# in a second and a half puts it a long way from where it started.
	if seen[0].is_equal_approx(seen[-1]):
		print("  the chaos button came back to where it started")
		faults += 1
	print("the chaos button went %s -> %s in a second and a half"
		% [_hue(seen[0]), _hue(seen[-1])])
	# The word on it still has to be readable through the tint.
	var faintest: float = 1.0
	for colour in seen:
		faintest = minf(faintest, colour.v)
	if faintest < 0.85:
		print("  the tint is dark enough to swallow the word on the button")
		faults += 1
	return faults


func _hue(colour: Color) -> String:
	return "%.0f degrees" % (colour.h * 360.0)


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
		[true, "mirror", SOLO], [false, "mirror", COOP],
		[true, "chaos", SOLO], [false, "chaos", COOP],
		[true, "infinite", SOLO],
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
		if not menu.get_node("ModeChoice").visible:
			print("  play did not open the page")
			faults += 1
		if menu.get("_modes_open"):
			print("  the modes were out before anyone said how many")
			faults += 1
		menu.call("_choose_players", solo)
		for i in 20:
			await process_frame
		if not menu.get("_modes_open"):
			print("  answering how many did not roll the modes out")
			faults += 1
		# The answer stays showing on the two at the top.
		var alone: Button = menu.get_node("ModeChoice/Page/Panel/Margin/Box/Players/Alone")
		var together: Button = menu.get_node("ModeChoice/Page/Panel/Margin/Box/Players/Together")
		if alone.button_pressed != solo or together.button_pressed == solo:
			print("  the page is not showing which way it is being played")
			faults += 1

		if mode == "infinite":
			menu.call("_start_infinite", false)
		elif mode == "mirror":
			menu.call("_start_track", TrackRoster.file(0), TrackVariant.MIRROR)
		elif mode == "chaos":
			menu.call("_start_track", TrackRoster.file(0), TrackVariant.TRACK_CHAOS)
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
		if laid_out != (mode != "infinite"):
			print("  %s + %s is running %s"
				% ["solo" if solo else "co-op", mode,
					"a laid-out track" if laid_out else "a rolled course"])
			faults += 1
		var wanted_way: String = {"mirror": TrackVariant.MIRROR,
			"chaos": TrackVariant.TRACK_CHAOS}.get(mode, TrackVariant.NORMAL)
		if settings.track_variant != wanted_way or (laid_out and track.variant != wanted_way):
			print("  %s + %s is driven %s"
				% ["solo" if solo else "co-op", mode, TrackVariant.display_name(
					track.variant if laid_out else settings.track_variant)])
			faults += 1
		# Track chaos rolls its rows on the way in, in either scene. One track
		# is shared by both halves of a split screen, so two players always meet
		# the one roll; what has to be true is that there was a roll at all.
		if mode == "chaos" and laid_out and track.track_chaos_seed == 0:
			print("  %s + track chaos rolled no rows" % ("solo" if solo else "co-op"))
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
	for i in 20:
		await process_frame
	menu2.call("_on_tracks_pressed")
	for i in 20:
		await process_frame
	# Tracks opens onto normal and acrobatic rather than onto the grid, and
	# each of those opens its own grid.
	var kinds := "ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/KindSlot"
	if not menu2.get_node(kinds).visible or menu2.get_node("TrackChoice").visible:
		print("  tracks did not open onto the kinds of track")
		faults += 1
	menu2.get_node(kinds + "/Inner/Row/Acrobatic").pressed.emit()
	await process_frame
	# Counted across the blocks the page is built of rather than off one grid:
	# the normal tracks are two blocks of ten with a door under each now, and
	# the acrobatic ones are one block with nothing at the end of it.
	var acrobatic_slots: int = menu2.call("_track_cells").size()
	var first_button: Button = _button_in(menu2.call("_track_cells")[0])
	var first_live := first_button != null and not first_button.disabled
	menu2.call("_close_track_choice")
	var back_on: Control = menu2.get_viewport().gui_get_focus_owner()
	menu2.get_node(kinds + "/Inner/Row/Normal").pressed.emit()
	await process_frame
	var normal_slots: int = menu2.call("_track_cells").size()
	print("acrobatic opens %d slots, normal opens %d" % [acrobatic_slots, normal_slots])
	if acrobatic_slots != TrackRoster.ACROBATIC_COUNT or normal_slots != TrackRoster.COUNT:
		print("  the two kinds of track did not open their own grids")
		faults += 1
	if not first_live:
		print("  the first acrobatic track cannot be pressed")
		faults += 1
	if back_on != menu2.get_node(kinds + "/Inner/Row/Acrobatic"):
		print("  backing out of the acrobatic grid did not put the cursor back on acrobatic")
		faults += 1
	await process_frame
	var ladder := PackedStringArray()
	for step in 4:
		if menu2.get_node("TrackChoice").visible:
			ladder.append("tracks")
			menu2.call("_close_track_choice")
		elif menu2.get_node(kinds).visible:
			ladder.append("kinds")
			menu2.call("_slide_kinds", false)
			# Hidden when the slide ends, which is time rather than frames.
			await create_timer(menu2.get("slide_seconds") + 0.1).timeout
		elif menu2.get("_modes_open"):
			ladder.append("modes")
			menu2.call("_slide_modes", false)
		elif menu2.get_node("ModeChoice").visible:
			ladder.append("the page")
			menu2.call("_close_mode_choice")
		for i in 20:
			await process_frame
	print("backing out goes %s, then the title" % " -> ".join(ladder))
	if ladder != PackedStringArray(["tracks", "kinds", "modes", "the page"]):
		print("  backing out did not walk the way in, in reverse")
		faults += 1

	# And the slide inside the slide: opening the flavour buttons has to open
	# the slot holding them further rather than being clipped by it.
	menu2.call("_open_mode_choice")
	menu2.call("_choose_players", true)
	for i in 25:
		await process_frame
	var closed: float = menu2.get_node(
		"ModeChoice/Page/Panel/Margin/Box/ModeSlot").custom_minimum_size.y
	menu2.call("_on_infinite_pressed")
	for i in 30:
		await process_frame
	var opened: float = menu2.get_node(
		"ModeChoice/Page/Panel/Margin/Box/ModeSlot").custom_minimum_size.y
	print("the modes are %.0f px, and %.0f with the flavours out"
		% [closed, opened])
	if opened <= closed + 10.0:
		print("  the flavour buttons did not push the modes open further")
		faults += 1
	faults += await _check_the_chaos_button(menu2)
	menu2.queue_free()

	if times != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


func _button_in(cell: Node) -> Button:
	for child in cell.get_children():
		if child is Button:
			return child
	return null
