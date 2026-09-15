extends SceneTree

# Everything chaos changes about how a race looks.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/chaos_colour.gd
#
# Three things that are meant to move and one that is meant to hold still.
# The cars are painted once per course and then left alone; the streaks and
# the leaves never settle. And none of it may happen in a race that is not
# chaotic, or on the title screen behind the menu.


func _init() -> void:
	await process_frame
	var settings: Node = root.get_node_or_null(^"/root/GameSettings")
	settings.track_file = ""
	settings.chaos = true

	var faults := 0
	var race: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(race)
	for i in 10:
		await physics_frame

	var one: Car = race.get_node("Car1")
	var two: Car = race.get_node("Car2")
	var trees: Trees = race.get_node("Trees")
	var lines: SpeedLines = race.get_node("Split/TopView/SubViewport/Lines")

	# The two cars have to be tellable apart, whatever the roll was.
	print("the cars came out %s and %s, %.0f degrees apart"
		% [_hue(one.body_color), _hue(two.body_color),
			_apart(one.body_color, two.body_color)])
	if _apart(one.body_color, two.body_color) < 60.0:
		print("  the two cars are near enough the same colour")
		faults += 1
	if one.body_color.v < 0.5 or two.body_color.v < 0.5:
		print("  a car was painted too dark to pick out of a hedge")
		faults += 1

	# And then hold that colour for the course.
	var was := one.body_color
	for i in 60:
		await physics_frame
	if not one.body_color.is_equal_approx(was):
		print("  a car changed colour part way through a course")
		faults += 1
	else:
		print("and hold it while the course is being driven")

	# A new course repaints them, and the arrows follow.
	race.call("_new_course", 4242)
	await physics_frame
	print("a new course repaints them %s and %s"
		% [_hue(one.body_color), _hue(two.body_color)])
	if one.body_color.is_equal_approx(was):
		print("  a new course did not repaint the cars")
		faults += 1
	var arrow: MeshInstance3D = race.get_node("ArrowP1")
	var shown: Color = (arrow.material_override as StandardMaterial3D).albedo_color
	if not shown.is_equal_approx(two.body_color):
		print("  the arrow is still in the colour the rival used to be")
		faults += 1
	else:
		print("and the arrow follows the car it points at")

	# The leaves never settle.
	if not trees.wild:
		print("  the wood was not told this is a chaotic race")
		faults += 1
	faults += await _check_it_moves(trees, "the leaves",
		func() -> Color: return trees._leaves[0].albedo_color)
	if lines.wild != true:
		print("  the streaks were not told this is a chaotic race")
		faults += 1
	race.queue_free()
	await process_frame

	# And a race that is not chaotic keeps its own colours.
	settings.chaos = false
	var calm: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(calm)
	for i in 10:
		await physics_frame
	var calm_trees: Trees = calm.get_node("Trees")
	var green: Color = calm_trees._leaves[0].albedo_color
	for i in 60:
		await physics_frame
	if calm_trees.wild or not calm_trees._leaves[0].albedo_color.is_equal_approx(green):
		print("  the wood is shimmering in a race that is not chaotic")
		faults += 1
	if calm.get_node("Car1").body_color.is_equal_approx(
			calm.get_node("Car2").body_color):
		print("  the two cars are the same colour without chaos to blame")
		faults += 1
	print("without chaos the leaves stay %s and the cars keep their own paint"
		% _hue(green))
	calm.queue_free()

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Something that is meant never to settle has to be somewhere else a moment
## later, and somewhere else again after that.
func _check_it_moves(node: Node, what: String, read: Callable) -> int:
	var seen: Array[Color] = []
	for sample in 3:
		seen.append(read.call())
		for i in 40:
			await Engine.get_main_loop().physics_frame
	for i in range(1, seen.size()):
		if seen[i].is_equal_approx(seen[i - 1]):
			print("  %s held the same colour" % what)
			return 1
	print("%s went %s -> %s -> %s"
		% [what, _hue(seen[0]), _hue(seen[1]), _hue(seen[2])])
	return 0


func _hue(colour: Color) -> String:
	return "%.0f deg" % (colour.h * 360.0)


## How far apart two colours are round the wheel, in degrees, the short way.
func _apart(a: Color, b: Color) -> float:
	var gap: float = absf(a.h - b.h)
	return minf(gap, 1.0 - gap) * 360.0
