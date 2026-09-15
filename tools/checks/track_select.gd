extends SceneTree

# Press the buttons and see where they go.
#   Godot --path . --headless --script tools/checks/track_select.gd
#
# A grid built in code, a setting carried across a scene change and a Track
# that has to divert from a seed to a file: three places for a track to be
# chosen and then quietly not raced.


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times != null:
		# A time on the board, so the colour of one can be checked as well as
		# the shape of the grid. Scratch file: a check is not a lap.
		times.save_path = "user://times_select_check.cfg"
		times.load_times()
		times.record("res://tracks/01_first_light.gd", 41.55)

	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	for i in 20:
		await process_frame

	var faults := 0
	var grid: GridContainer = menu.get_node(
		"TrackChoice/Page/Panel/Margin/Box/Scroll/Grid")
	print("%d slots for %d tracks" % [grid.get_child_count(), TrackRoster.COUNT])
	if grid.get_child_count() != TrackRoster.COUNT:
		print("  the grid is not as long as the game intends to be")
		faults += 1

	var live := 0
	var named := 0
	for cell in grid.get_children():
		for child in cell.get_children():
			if child is Button and not (child as Button).disabled:
				live += 1
		# The first label in a cell is the name over the picture; the second
		# is the time under it.
		var labels := cell.get_children().filter(func(c: Node) -> bool: return c is Label)
		if not labels.is_empty() and not (labels[0] as Label).text.is_empty():
			named += 1
	print("%d of them can be pressed, %d are named" % [live, named])
	faults += _check_the_times(grid)
	faults += _check_the_names(grid, menu)
	if live != TrackRoster.FILES.size():
		print("  the tracks that exist are not the ones that can be pressed")
		faults += 1
	if named != TrackRoster.COUNT:
		print("  a slot has no name over it")
		faults += 1
	for index in TrackRoster.FILES.size():
		if TrackRoster.thumbnail(index) == null:
			print("  %s has no overhead shot; run tools/track_thumbnails.gd"
				% TrackRoster.file(index))
			faults += 1

	# Press it, and see whether the race that starts is on that track.
	# In the way a player gets there: the page, then how many are playing,
	# then the modes that roll out under that.
	menu.call("_on_play_pressed")
	menu.call("_choose_players", true)
	for i in 20:
		await process_frame
	menu.get_node("ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/Tracks").pressed.emit()
	await process_frame
	var first: Button = _first_live(grid)
	if first == null:
		print("  no track could be pressed at all")
		quit(1)
		return
	first.pressed.emit()
	for i in 40:
		await process_frame

	var race := root.get_child(root.get_child_count() - 1)
	var track: Track = race.get_node_or_null("Track")
	if track == null:
		print("  pressing a track did not start a race")
		faults += 1
	elif track.definition() == null:
		print("  the race that started is not on a laid-out track")
		faults += 1
	else:
		print("pressing it starts a race on %s, %.0f m, %s"
			% [track.definition().track_name, track.length(),
				track.features().summary()])
		if settings != null and settings.chaos:
			print("  a timed track is being run under chaos rules")
			faults += 1

	faults += await _check_coming_back()

	if times != null:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(times.save_path))
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Leaving a track should put a player back on the grid of tracks, with the
## cursor on the one they were driving - not back at the title, three presses
## away from the thing they were about to do again.
func _check_coming_back() -> int:
	var faults := 0
	var settings: Node = Engine.get_main_loop().root.get_node_or_null(
		^"/root/GameSettings")
	if settings == null:
		return 0

	# As it is on the way out of a track: one is still picked.
	settings.track_file = TrackRoster.file(0)
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	Engine.get_main_loop().root.add_child(menu)
	for i in 20:
		await Engine.get_main_loop().process_frame

	if not menu.get_node("TrackChoice").visible:
		print("  coming back from a track did not open on the tracks")
		faults += 1
	var focused := menu.get_viewport().gui_get_focus_owner()
	var wanted: Button = _first_live(menu.get_node(
		"TrackChoice/Page/Panel/Margin/Box/Scroll/Grid"))
	if focused != wanted:
		print("  the cursor did not come back to the track that was driven")
		faults += 1
	else:
		print("coming back opens on the grid, on %s"
			% TrackRoster.track_name(0))
	menu.queue_free()
	await Engine.get_main_loop().process_frame

	# And a fresh start, with nothing picked, still opens on the title.
	settings.track_file = ""
	var fresh: Node = load("res://scenes/menu.tscn").instantiate()
	Engine.get_main_loop().root.add_child(fresh)
	for i in 20:
		await Engine.get_main_loop().process_frame
	if fresh.get_node("TrackChoice").visible or fresh.get_node("ModeChoice").visible:
		print("  opening the game fresh did not open on the title")
		faults += 1
	else:
		print("opening fresh still opens on the title")
	fresh.queue_free()
	return faults


## A track that has been driven shows its time; one that has not says so; and
## a slot with no track in it says nothing at all. The three are different
## things and a player should be able to tell them apart at a glance.
func _check_the_times(grid: GridContainer) -> int:
	var faults := 0
	var times: Node = Engine.get_main_loop().root.get_node_or_null(^"/root/TrackTimes")
	for index in grid.get_child_count():
		var labels := grid.get_child(index).get_children().filter(
			func(c: Node) -> bool: return c is Label)
		if labels.size() < 2:
			print("  slot %d has no time under it" % (index + 1))
			faults += 1
			continue
		var shown: String = (labels[1] as Label).text
		# The bar under the picture has to agree with the time under that.
		var rules := grid.get_child(index).get_children().filter(
			func(c: Node) -> bool: return c is ColorRect)
		if rules.is_empty():
			print("  slot %d has no medal bar" % (index + 1))
			faults += 1
		if not TrackRoster.exists(index):
			if not shown.is_empty():
				print("  slot %d has no track in it but says '%s'"
					% [index + 1, shown])
				faults += 1
			continue
		var best: float = times.best(TrackRoster.file(index)) if times != null else -1.0
		var wanted := "NO TIME" if best < 0.0 else "a time"
		if best < 0.0 and shown != "NO TIME":
			print("  %s has no time but says '%s'"
				% [TrackRoster.track_name(index), shown])
			faults += 1
		if best >= 0.0 and shown == "NO TIME":
			print("  %s has a time of %.2f but says it has none"
				% [TrackRoster.track_name(index), best])
			faults += 1
		# And the colour has to agree with the number: a gold time shown in
		# the same grey as a bronze one is a medal nobody can see.
		if best >= 0.0:
			var earned := Medal.earned(best, TrackRoster.targets(index))
			var expected := Medal.colour(earned)
			var used: Color = (labels[1] as Label).get_theme_color("font_color")
			if not used.is_equal_approx(expected):
				print("  %s is worth %s but is not shown in its colour"
					% [TrackRoster.track_name(index), Medal.label(earned)])
				faults += 1
			if not rules.is_empty():
				var bar := rules[0] as ColorRect
				if bar.visible != (earned != Medal.NONE):
					print("  %s is worth %s but its bar is %s"
						% [TrackRoster.track_name(index), Medal.label(earned),
							"showing" if bar.visible else "hidden"])
					faults += 1
				elif bar.visible and not bar.color.is_equal_approx(expected):
					print("  %s has a bar in the wrong colour"
						% TrackRoster.track_name(index))
					faults += 1
		print("%s shows %s" % [TrackRoster.track_name(index), shown])
	return faults


## Every name reads whole over its picture. A name wider than its label is cut
## off at both ends and reads as another word, which a count of names cannot
## see. Measured in the font and size the label is drawn in, against the width
## it was given, so a name the menu shrank is judged at the size it shrank to.
func _check_the_names(grid: GridContainer, menu: Node) -> int:
	var faults := 0
	var usual: int = menu.get("track_name_font_size")
	var height := -1.0
	for cell in grid.get_children():
		var labels := cell.get_children().filter(
			func(c: Node) -> bool: return c is Label)
		if labels.is_empty():
			continue
		var label := labels[0] as Label
		var points := label.get_theme_font_size("font_size")
		var needs := label.get_theme_font("font").get_string_size(
			label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, points).x
		var room := label.size.x - label.get_theme_stylebox("normal").get_minimum_size().x
		if needs > room:
			print("  %s is %.0f px wide in a column with room for %.0f"
				% [label.text, needs, room])
			faults += 1
		elif points < usual:
			print("%s is set at %d to fit its column" % [label.text, points])
		# And as tall as every other name, whatever size it is set at. The
		# picture hangs under the name, so a shorter name is a picture sitting
		# out of line with the rest of its row.
		var tall := label.get_combined_minimum_size().y
		if height < 0.0:
			height = tall
		elif not is_equal_approx(tall, height):
			print("  %s is %.0f px tall where the other names are %.0f"
				% [label.text, tall, height])
			faults += 1
	return faults


func _first_live(grid: GridContainer) -> Button:
	for cell in grid.get_children():
		for child in cell.get_children():
			var button := child as Button
			if button != null and not button.disabled:
				return button
	return null
