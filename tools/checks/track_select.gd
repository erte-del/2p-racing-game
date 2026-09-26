extends SceneTree

# Press the buttons and see where they go.
#   Godot --path . --headless --script tools/checks/track_select.gd
#
# A grid built in code, a setting carried across a scene change and a Track
# that has to divert from a seed to a file: three places for a track to be
# chosen and then quietly not raced. And a way of driving it, held down on the
# track's page, which is a fourth.

const VARIANTS := "TrackDetail/Page/Panel/Margin/Box/Body/Left/Variants/"


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times != null:
		# A time on the board, so the colour of one can be checked as well as
		# the shape of the grid. Scratch file: a check is not a lap.
		times.save_path = "user://times_select_check.cfg"
		_wipe(times.save_path)
		times.load_times()
		times.record("res://tracks/01_first_light.gd", 41.55)
	# And a profile that has won nothing, for the same reason and one more:
	# which cells are shut depends on it, so a check reading whoever ran it
	# last would pass or fail by accident.
	var progress: Node = root.get_node_or_null(^"/root/Progress")
	if progress != null:
		progress.save_path = Sandbox.path("user://progress_select_check.cfg")
		_wipe(progress.save_path)
		progress.load_progress()

	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	for i in 20:
		await process_frame

	var faults := 0
	var blocks: VBoxContainer = menu.get_node(
		"TrackChoice/Page/Panel/Margin/Box/Scroll/Blocks")
	faults += _check_the_shape(blocks, progress)
	var cells: Array = menu.call("_track_cells")

	var live := 0
	var named := 0
	for cell in cells:
		for child in cell.get_children():
			if child is Button and not (child as Button).disabled:
				live += 1
		# The first label in a cell is the name over the picture; the second
		# is the time under it.
		var labels: Array = cell.get_children().filter(func(c: Node) -> bool: return c is Label)
		if not labels.is_empty() and not (labels[0] as Label).text.is_empty():
			named += 1
	print("%d of them can be pressed, %d are named" % [live, named])
	faults += _check_the_times(cells)
	faults += _check_the_names(cells, menu)
	# Not every track that exists: on a fresh profile only the first block of
	# ten is open and the rest are built and shut. A name, on the other hand,
	# is on every slot - a shut cell still says which road it is.
	var should_be_live := TrackRoster.FILES.size()
	if progress != null:
		should_be_live = mini(should_be_live, progress.BLOCK)
	if live != should_be_live:
		print("  %d tracks can be pressed where %d should be"
			% [live, should_be_live])
		faults += 1
	if named != TrackRoster.COUNT:
		print("  a slot has no name over it")
		faults += 1
	faults += _check_the_three_states(menu, cells, progress)
	for index in TrackRoster.FILES.size():
		if TrackRoster.thumbnail(index) == null:
			print("  %s has no overhead shot; run tools/track_thumbnails.gd"
				% TrackRoster.file(index))
			faults += 1

	faults += await _check_the_gate(menu, times, progress, settings)

	# Press it, and see whether the race that starts is on that track.
	# In the way a player gets there: the page, then how many are playing,
	# then the modes that roll out under that.
	menu.call("_on_play_pressed")
	menu.call("_choose_players", true)
	for i in 20:
		await process_frame
	menu.get_node("ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/Tracks").pressed.emit()
	for i in 20:
		await process_frame
	menu.get_node(
		"ModeChoice/Page/Panel/Margin/Box/ModeSlot/Inner/KindSlot/Inner/Row/Normal").pressed.emit()
	await process_frame
	var first: Button = _first_live(menu.call("_track_cells"))
	if first == null:
		print("  no track could be pressed at all")
		quit(1)
		return
	first.pressed.emit()
	await process_frame
	# A track with a page of its own opens that first, and the race starts off
	# the page's PLAY - here with MIRROR held down, so what arrives in the race
	# is the way picked as well as the track.
	if menu.get_node("TrackDetail").visible:
		print("pressing %s opens its own page" % TrackRoster.track_name(0))
		var mirror: Button = menu.get_node(VARIANTS + "Mirror")
		mirror.button_pressed = true
		mirror.pressed.emit()
		menu.get_node("TrackDetail/Page/Panel/Margin/Box/Body/You/Play").pressed.emit()
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
		faults += _check_it_is_mirrored(track)

	faults += await _check_coming_back()

	if times != null:
		_wipe(times.save_path)
	if progress != null:
		_wipe(progress.save_path)
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## The page is blocks of ten with a door under each, and every track the game
## intends to have is still on it.
##
## Counted across the blocks rather than off one grid. The structure changed -
## a block of ten is its own five-column grid now, so a door can stand between
## one block and the next - but what has to be true did not: twenty cells, in
## two rows of five to a block, and a door at the end of each.
func _check_the_shape(blocks: VBoxContainer, progress: Node) -> int:
	var faults := 0
	var grids := 0
	var doors := 0
	var cells := 0
	var shape := PackedStringArray()
	var block: int = progress.BLOCK if progress != null else 10
	for child in blocks.get_children():
		var grid := child as GridContainer
		if grid != null:
			grids += 1
			cells += grid.get_child_count()
			shape.append("grid of %d" % grid.get_child_count())
			if grid.columns != 5:
				print("  a block is %d columns across, not 5" % grid.columns)
				faults += 1
			if grid.get_child_count() > block:
				print("  a block holds %d cells, more than the ten a door stands at the end of"
					% grid.get_child_count())
				faults += 1
			continue
		var door := child as Button
		if door != null:
			doors += 1
			shape.append("door '%s'" % door.text)
	print("the page is: %s" % ", ".join(shape))
	print("%d cells for %d tracks" % [cells, TrackRoster.COUNT])
	if cells != TrackRoster.COUNT:
		print("  the grid is not as long as the game intends to be")
		faults += 1
	var wanted := (TrackRoster.COUNT + block - 1) / block
	if grids != wanted or doors != wanted:
		print("  %d blocks of ten want %d grids and %d doors, not %d and %d"
			% [wanted, wanted, wanted, grids, doors])
		faults += 1
	return faults


## Three states on a cell, and all three have to look different from each
## other. A built track a player may not drive yet is not the same thing as a
## track that does not exist, and showing them alike tells a player the game is
## unfinished when in fact they are.
##
## The faces are compared as well as the cells, because with every slot on the
## roster filled there is no empty frame on the page today to hold a shut one
## up against - the state exists in the code and will be on the screen the day
## the roster grows past the tracks that are built.
func _check_the_three_states(menu: Node, cells: Array, progress: Node) -> int:
	var faults := 0
	var empty: StyleBoxFlat = menu.call("_empty_slot")
	var shut_face: StyleBoxFlat = menu.call("_shut_slot")
	if empty.border_color.is_equal_approx(shut_face.border_color):
		print("  a shut track and a slot with nothing in it are framed the same")
		faults += 1
	if progress == null:
		return faults

	var open := 0
	var shut := 0
	var missing := 0
	for index in cells.size():
		var button: Button = menu.call("_button_in", cells[index])
		var should_be_open: bool = progress.open(index / progress.BLOCK)
		if not TrackRoster.exists(index):
			missing += 1
			continue
		if not button.disabled:
			open += 1
			if not should_be_open:
				print("  %s can be pressed but its block is shut"
					% TrackRoster.track_name(index))
				faults += 1
			continue
		shut += 1
		if should_be_open:
			print("  %s is in an open block but cannot be pressed"
				% TrackRoster.track_name(index))
			faults += 1
			continue
		# A shut cell keeps its picture, wears the shut frame rather than the
		# empty one, and carries a lock: those three together are what stop it
		# reading as a slot with nothing in it.
		if button.icon == null:
			print("  %s is shut and has lost its picture"
				% TrackRoster.track_name(index))
			faults += 1
		var box := button.get_theme_stylebox("disabled") as StyleBoxFlat
		if box == null or box.border_color.is_equal_approx(empty.border_color):
			print("  %s is shut but framed as a slot with nothing in it"
				% TrackRoster.track_name(index))
			faults += 1
		if button.get_child_count() == 0:
			print("  %s is shut with no lock on it" % TrackRoster.track_name(index))
			faults += 1
		# And it says what to go and do, rather than only that it is shut.
		if not button.tooltip_text.contains("GOLD IN"):
			print("  %s says '%s', which is not something a player can act on"
				% [TrackRoster.track_name(index), button.tooltip_text])
			faults += 1
	print("%d cells open, %d shut, %d not built yet" % [open, shut, missing])
	return faults


## The door at the end of a block: shut until the golds are there, open then,
## and won once it has been beaten - and the ten behind it opening with it.
func _check_the_gate(menu: Node, times: Node, progress: Node, settings: Node) -> int:
	if progress == null or times == null:
		return 0
	var faults := 0
	var needed: int = progress.GOLDS_NEEDED
	var block: int = progress.BLOCK
	# Open, not merely built: focus does not resolve on a page that is hidden,
	# and half of what is being checked here is where the keyboard goes.
	menu.call("_open_track_grid", TrackRoster.NORMAL)
	for i in 3:
		await Engine.get_main_loop().process_frame
	for index in block:
		times.forget(TrackRoster.file(index))
	progress.forget()

	# One short of what it asks for is still shut, and says so with the count.
	for index in needed - 1:
		times.record(TrackRoster.file(index), TrackRoster.targets(index).x - 0.5)
	faults += await _rebuild(menu)
	var door: Button = menu.call("_doors")[0]
	print("with %d golds the door says '%s'" % [progress.golds_in(0), door.text])
	if not door.disabled:
		print("  the door opened on %d golds, one short of %d" % [needed - 1, needed])
		faults += 1
	if not door.text.contains("you have %d" % (needed - 1)):
		print("  the door does not say how many golds the player actually has")
		faults += 1

	# And the one that makes it up opens it.
	times.record(TrackRoster.file(needed - 1),
		TrackRoster.targets(needed - 1).x - 0.5)
	faults += await _rebuild(menu)
	door = menu.call("_doors")[0]
	print("with %d golds the door says '%s'" % [progress.golds_in(0), door.text])
	if door.disabled:
		print("  the door is still shut on %d golds" % needed)
		faults += 1
	# The golds buy the race, not the ten behind it.
	var beyond: Button = menu.call("_button_in", menu.call("_track_cells")[block])
	if not beyond.disabled:
		print("  the next ten opened on golds alone, without the race being won")
		faults += 1

	# And the keyboard can get to it. Godot works focus out from where things
	# are on the screen, which walks straight past a door in a container of its
	# own and off the page: down off the last row of the first ten used to land
	# on the title screen behind it. The seams are wired by hand, so they are
	# worth a check.
	var cells: Array = menu.call("_track_cells")
	var above: Button = menu.call("_button_in", cells[block - 1])
	above.grab_focus()
	await Engine.get_main_loop().process_frame
	var down := above.find_valid_focus_neighbor(SIDE_BOTTOM)
	var up := door.find_valid_focus_neighbor(SIDE_TOP)
	print("down off the last of the ten reaches the door: %s, and up comes back: %s"
		% [down == door, up != null and up != door])
	if down != door:
		print("  the keyboard cannot get down to the door")
		faults += 1
	if up == null or up == door:
		print("  the keyboard cannot get back up off the door")
		faults += 1

	# Winning it opens them, and the door says so rather than asking again.
	progress.win(0)
	faults += await _rebuild(menu)
	door = menu.call("_doors")[0]
	beyond = menu.call("_button_in", menu.call("_track_cells")[block])
	print("after winning, the door says '%s' and %s can be pressed: %s"
		% [door.text, TrackRoster.track_name(block), not beyond.disabled])
	if not door.text.contains("WON"):
		print("  a door that has been beaten does not say so")
		faults += 1
	if beyond.disabled:
		print("  winning the race did not open the next ten")
		faults += 1

	# A bot race is one player whatever the top of the page was answered with.
	if settings != null:
		var was: bool = settings.solo
		var picked: String = settings.track_file
		settings.solo = false
		settings.track_file = TrackRoster.bot_road(0)
		var scene: String = menu.call("_scene_for_the_players")
		print("with two players chosen, a bot road runs in %s" % scene.get_file())
		if scene != menu.get("solo_scene"):
			print("  a bot road was sent to the two-player scene")
			faults += 1
		settings.solo = was
		settings.track_file = picked
	return faults


## Build the grid again, the way coming back to the page does, and let it lay
## itself out.
func _rebuild(menu: Node) -> int:
	menu.call("_refresh_the_track_grid")
	for i in 3:
		await Engine.get_main_loop().process_frame
	return 0


## Leaving a track should put a player back on the grid of tracks, with the
## cursor on the one they were driving - not back at the title, three presses
## away from the thing they were about to do again.
func _check_coming_back() -> int:
	var faults := 0
	var settings: Node = Engine.get_main_loop().root.get_node_or_null(
		^"/root/GameSettings")
	if settings == null:
		return 0

	# As it is on the way out of a track: one is still picked. Off any track
	# it is that track's own page that opens, with the cursor on PLAY, and
	# backing out of the page puts the cursor on the track in its grid. Tried
	# off a track partway into the normal grid and off an acrobatic one,
	# since those two are counted from different ends of the roster.
	for index in [6, TrackRoster.first(TrackRoster.ACROBATIC)]:
		faults += await _check_coming_back_to(settings, index)
	faults += await _check_the_ways(settings)

	# Every track in both grids opens its own page when pressed, named for
	# itself and showing its own wide shot rather than falling back to the
	# square one on its button.
	faults += await _check_every_page(settings)

	# And a fresh start, with nothing picked, still opens on the title.
	settings.track_file = ""
	settings.track_variant = TrackVariant.NORMAL
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
func _check_the_times(cells: Array) -> int:
	var faults := 0
	var times: Node = Engine.get_main_loop().root.get_node_or_null(^"/root/TrackTimes")
	for index in cells.size():
		var labels: Array = cells[index].get_children().filter(
			func(c: Node) -> bool: return c is Label)
		if labels.size() < 2:
			print("  slot %d has no time under it" % (index + 1))
			faults += 1
			continue
		var shown: String = (labels[1] as Label).text
		# The bar under the picture has to agree with the time under that.
		var rules: Array = cells[index].get_children().filter(
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
func _check_the_names(cells: Array, menu: Node) -> int:
	var faults := 0
	var usual: int = menu.get("track_name_font_size")
	var height := -1.0
	for cell in cells:
		var labels: Array = cell.get_children().filter(
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


func _first_live(cells: Array) -> Button:
	for cell in cells:
		for child in cell.get_children():
			var button := child as Button
			if button != null and not button.disabled:
				return button
	return null


func _wipe(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _check_coming_back_to(settings: Node, index: int) -> int:
	var faults := 0
	var called := TrackRoster.track_name(index)
	var kind := TrackRoster.kind_of(index)
	settings.track_file = TrackRoster.file(index)
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	Engine.get_main_loop().root.add_child(menu)
	for i in 20:
		await Engine.get_main_loop().process_frame
	var play: Button = menu.get_node("TrackDetail/Page/Panel/Margin/Box/Body/You/Play")
	if not menu.get_node("TrackDetail").visible:
		print("  coming back from %s did not open its page" % called)
		faults += 1
	elif menu.get_viewport().gui_get_focus_owner() != play:
		print("  coming back to %s's page left the cursor off PLAY" % called)
		faults += 1
	else:
		menu.call("_close_track_detail")
		await Engine.get_main_loop().process_frame
		var cell: Node = menu.call("_track_cells")[index - TrackRoster.first(kind)]
		if (not menu.get_node("TrackChoice").visible
				or menu.get_viewport().gui_get_focus_owner() != menu.call("_button_in", cell)):
			print("  backing out of %s's page did not land on it" % called)
			faults += 1
		else:
			print("coming back opens %s's page, and backing out lands on it" % called)
	menu.queue_free()
	await Engine.get_main_loop().process_frame
	return faults


func _check_every_page(settings: Node) -> int:
	var faults := 0
	settings.track_file = ""
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	Engine.get_main_loop().root.add_child(menu)
	for i in 20:
		await Engine.get_main_loop().process_frame
	var variants := "TrackDetail/Page/Panel/Margin/Box/Body/Left/Variants/"
	var picture: TextureRect = menu.get_node(
		"TrackDetail/Page/Panel/Margin/Box/Body/Left/Picture")
	var opened := 0
	for kind in [TrackRoster.NORMAL, TrackRoster.ACROBATIC]:
		menu.call("_open_track_grid", kind)
		await Engine.get_main_loop().process_frame
		var cells: Array = menu.call("_track_cells")
		for at in cells.size():
			var index: int = TrackRoster.first(kind) + at
			var button: Button = menu.call("_button_in", cells[at])
			if button == null or not TrackRoster.exists(index):
				continue
			var called := TrackRoster.track_name(index)
			# A shut track cannot be pressed, and its page is only ever opened
			# once it is open; asked for directly here, since what is on the
			# page does not depend on the gate.
			if button.disabled:
				menu.call("_open_track_detail", index)
			else:
				button.pressed.emit()
			await Engine.get_main_loop().process_frame
			var heading: Label = menu.get_node("TrackDetail/Page/Panel/Margin/Box/Heading")
			if not menu.get_node("TrackDetail").visible:
				print("  pressing %s did not open its page" % called)
				faults += 1
			elif heading.text != called.to_upper():
				print("  %s's page is headed %s" % [called, heading.text])
				faults += 1
			elif picture.texture == null or not picture.texture.resource_path.contains("/wide/"):
				print("  %s's page has no wide shot of its own" % called)
				faults += 1
			else:
				opened += 1
			# HARD, track chaos and REVERSE are for the normal tracks only.
			for way in ["Hard", "TrackChaos", "Reverse"]:
				if menu.get_node(variants + way).visible != (kind == TrackRoster.NORMAL):
					print("  %s's page %s %s" % [called,
						"hides" if kind == TrackRoster.NORMAL else "shows", way])
					faults += 1
			menu.call("_close_track_detail")
		menu.call("_close_track_choice")
	print("%d pages open, each with its own name and wide shot" % opened)
	menu.queue_free()
	await Engine.get_main_loop().process_frame
	return faults


## The race that started off the page with MIRROR held is on the mirrored
## road: the way picked arrived, and every corner turns the other way.
func _check_it_is_mirrored(track: Track) -> int:
	var settings: Node = Engine.get_main_loop().root.get_node_or_null(^"/root/GameSettings")
	if settings != null and settings.track_variant != TrackVariant.MIRROR:
		print("  PLAY with MIRROR held set the way to drive to %s" % settings.track_variant)
		return 1
	if track.variant != TrackVariant.MIRROR:
		print("  PLAY with MIRROR held raced the track %s" % TrackVariant.display_name(track.variant))
		return 1
	var written := TrackVariant.described(track.track_file, TrackVariant.NORMAL)
	for i in written.pieces.size():
		if not is_equal_approx(track.definition().pieces[i].turn, -written.pieces[i].turn):
			print("  the race with MIRROR held is not on the mirrored road")
			return 1
	print("and with MIRROR held, on the mirrored road")
	return 0


## Each way on the page: a way the track offers can be played and says
## nothing, a way it does not is faded, cannot be played, and says why in a
## line. MIRROR turns the picture round. And coming back from a race holds the
## way it was driven, unless the track does not offer that way, when it holds
## NORMAL.
func _check_the_ways(settings: Node) -> int:
	var faults := 0
	var file: String = TrackRoster.FILES[0]
	settings.track_file = ""
	settings.track_variant = TrackVariant.NORMAL
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	Engine.get_main_loop().root.add_child(menu)
	for i in 20:
		await Engine.get_main_loop().process_frame
	menu.call("_open_track_grid", TrackRoster.NORMAL)
	menu.call("_open_track_detail", 0)
	await Engine.get_main_loop().process_frame
	var box := "TrackDetail/Page/Panel/Margin/Box/"
	var play: Button = menu.get_node(box + "Body/You/Play")
	var why: Label = menu.get_node(box + "Body/You/Why")
	var picture: TextureRect = menu.get_node(box + "Body/Left/Picture")
	var buttons := {
		TrackVariant.NORMAL: menu.get_node(VARIANTS + "Normal"),
		TrackVariant.HARD: menu.get_node(VARIANTS + "Hard"),
		TrackVariant.TRACK_CHAOS: menu.get_node(VARIANTS + "TrackChaos"),
		TrackVariant.MIRROR: menu.get_node(VARIANTS + "Mirror"),
		TrackVariant.REVERSE: menu.get_node(VARIANTS + "Reverse"),
	}
	var offered := TrackVariant.offered(file)
	for variant: String in TrackVariant.ALL:
		var button: Button = buttons[variant]
		button.button_pressed = true
		button.pressed.emit()
		await Engine.get_main_loop().process_frame
		var named := TrackVariant.display_name(variant)
		var can := variant in offered
		if play.disabled == can:
			print("  PLAY is %s with %s held" % ["off" if can else "on", named])
			faults += 1
		if why.text.is_empty() == not can:
			print("  %s held %s" % [named, "says why not" if can else "does not say why not"])
			faults += 1
		if (button.modulate.a < 1.0) == can:
			print("  %s is %s" % [named, "faded" if can else "not faded"])
			faults += 1
		if picture.flip_h != (variant == TrackVariant.MIRROR):
			print("  the picture is %s with %s held" % [
				"turned round" if picture.flip_h else "the right way round", named])
			faults += 1
		if not can:
			# And pressed anyway, it starts nothing.
			menu.call("_start_detail_track")
			if not settings.track_file.is_empty():
				print("  PLAY with %s held started a race it does not offer" % named)
				faults += 1
				settings.track_file = ""
	menu.queue_free()
	await Engine.get_main_loop().process_frame
	if faults == 0:
		print("each way on the page plays or says why not, and MIRROR turns the picture round")

	# Back from a race: the way it was driven is held again, and one the track
	# does not offer comes back as NORMAL rather than as a way PLAY refuses.
	for pair in [[TrackVariant.MIRROR, TrackVariant.MIRROR],
			[TrackVariant.HARD, TrackVariant.NORMAL]]:
		settings.track_file = file
		settings.track_variant = pair[0]
		var back: Node = load("res://scenes/menu.tscn").instantiate()
		Engine.get_main_loop().root.add_child(back)
		for i in 20:
			await Engine.get_main_loop().process_frame
		var held: String = back.get("_detail_variant")
		var pressed: Button = back.get_node(VARIANTS + (
			"Mirror" if pair[1] == TrackVariant.MIRROR else "Normal"))
		if not back.get_node("TrackDetail").visible:
			print("  coming back from %s did not open its page" % pair[0])
			faults += 1
		elif held != pair[1] or not pressed.button_pressed:
			print("  coming back from %s holds %s" % [pair[0], TrackVariant.display_name(held)])
			faults += 1
		elif back.get_viewport().gui_get_focus_owner() != back.get_node(box + "Body/You/Play"):
			print("  coming back from %s left the cursor off PLAY" % pair[0])
			faults += 1
		else:
			print("coming back from %s holds %s" % [
				TrackVariant.display_name(pair[0]), TrackVariant.display_name(pair[1])])
		back.queue_free()
		await Engine.get_main_loop().process_frame
	settings.track_variant = TrackVariant.NORMAL
	return faults
