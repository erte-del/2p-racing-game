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
			if child is Label and not (child as Label).text.is_empty():
				named += 1
	print("%d of them can be pressed, %d are named" % [live, named])
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
	menu.get_node("ModeChoice/Page/Panel/Margin/Box/Tracks").pressed.emit()
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

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


func _first_live(grid: GridContainer) -> Button:
	for cell in grid.get_children():
		for child in cell.get_children():
			var button := child as Button
			if button != null and not button.disabled:
				return button
	return null
