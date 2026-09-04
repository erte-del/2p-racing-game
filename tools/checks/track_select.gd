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
		# The first label in a cell is the name over the picture; the second
		# is the time under it.
		var labels := cell.get_children().filter(func(c: Node) -> bool: return c is Label)
		if not labels.is_empty() and not (labels[0] as Label).text.is_empty():
			named += 1
	print("%d of them can be pressed, %d are named" % [live, named])
	faults += _check_the_times(grid)
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
		print("%s shows %s" % [TrackRoster.track_name(index), shown])
	return faults


func _first_live(grid: GridContainer) -> Button:
	for cell in grid.get_children():
		for child in cell.get_children():
			var button := child as Button
			if button != null and not button.disabled:
				return button
	return null
