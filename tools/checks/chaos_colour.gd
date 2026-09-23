extends SceneTree

# Everything chaos changes about how a race looks.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/chaos_colour.gd
#
# Three things that are meant to move and two that are meant to hold still.
# The cars are painted once per course and then left alone; the streaks, the
# leaves and whatever is drawn on the cars never settle. And none of it may
# happen in a race that is not chaotic, or on the title screen behind the menu.
#
# The decoration is the one that is both at once, and it is the requirement
# worth spelling out: the stripes, the stickers and the writing stay exactly
# as they were drawn, and only their colour moves. A car whose body cycled
# would be a race in which telling your car from the other one was itself
# chaotic, which is the one thing chaos is not allowed to be.

## What the cars are decorated with while this runs: three marks, which is
## enough to watch two of them turn from different places and still be a car
## rather than a billboard.
const MARKS := 3


func _init() -> void:
	await process_frame
	var settings: Node = root.get_node_or_null(^"/root/GameSettings")
	settings.track_file = ""
	settings.chaos = true
	# Something to look at. The cars are bare out of the box, and a check that
	# watched an undecorated car turn colour would pass by having nothing to
	# watch. Sandboxed, like everything under `tools/`, so this is not somebody
	# else's drawing being written over.
	var decals: Node = root.get_node_or_null(^"/root/Decals")
	_decorate(decals, settings)

	var faults := 0
	var race: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(race)
	for i in 10:
		await physics_frame

	var one: Car = race.get_node("Car1")
	var two: Car = race.get_node("Car2")
	var trees: Trees = race.get_node("Trees")
	var lines: SpeedLines = race.get_node("Split/TopView/SubViewport/Lines")

	# What is drawn on the cars, before anything else is looked at: if it did
	# not go on, every test of it below would pass on an empty list.
	if one.decal_colours().size() != MARKS:
		print("  the car came up wearing %d of its %d marks"
			% [one.decal_colours().size(), MARKS])
		faults += 1

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

	# The decoration never settles, and every piece of it turns from its own
	# place in the cycle - so a car with three things on it shimmers rather
	# than flashing as one, which is what the wood does and for the same
	# reason.
	# Read after the new course above, since that repainted the bodies: the
	# question here is whether the body holds still while the decoration turns,
	# and the colour it is holding is the one it has now.
	var body_was := one.body_color
	faults += await _check_the_decoration_moves(one)
	var apart := _apart(one.decal_colours()[0], one.decal_colours()[1])
	if apart < 1.0:
		print("  two marks on one car are turning in step, %.0f degrees apart"
			% apart)
		faults += 1
	else:
		print("the marks on a car are %.0f degrees apart in the turn" % apart)
	# And the body under them is the thing that is holding still.
	if not one.body_color.is_equal_approx(body_was):
		print("  the body moved while the decoration was turning")
		faults += 1

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
	faults += await _check_the_decoration_holds(
		calm.get_node("Car1"), "a race that is not chaotic")
	print("without chaos the leaves stay %s and the cars keep their own paint"
		% _hue(green))
	calm.queue_free()
	await process_frame

	# And the title screen, which is this same scene in attract mode. It is a
	# race that is not being played, and a strobing sticker behind the menu is
	# not what the menu is for.
	var title: Node = load("res://scenes/main.tscn").instantiate()
	title.set("attract_mode", true)
	root.add_child(title)
	for i in 10:
		await physics_frame
	faults += await _check_the_decoration_holds(
		title.get_node("Car1"), "the title screen")
	title.queue_free()
	await process_frame

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Put something on both players' cars. Written to the store rather than to the
## cars, because that is the path the game uses: the race reads it out of
## `Decals` when it is built and again whenever it changes.
func _decorate(decals: Node, settings: Node) -> void:
	if decals == null or not decals.has_method("set_marks"):
		return
	var marks := [
		{"kind": DecalArt.STRIPE, "shape": 0, "colour": 10,
			"at": Vector2(0.5, 0.5), "size": 1.0, "turn": 0.0},
		{"kind": DecalArt.STICKER, "shape": 4, "colour": 2,
			"at": Vector2(0.4, 0.45), "size": 0.2, "turn": 0.0},
		{"kind": DecalArt.STICKER, "shape": 0, "colour": 6,
			"at": Vector2(0.7, 0.45), "size": 0.2, "turn": 0.0},
	]
	for player in 2:
		decals.set_marks(settings.car_id(player), marks)


## The decoration in a chaotic race, watched the way the leaves are: it has to
## be somewhere else a moment later, and somewhere else again after that.
func _check_the_decoration_moves(car: Car) -> int:
	return await _check_it_moves(car, "what is drawn on the car",
		func() -> Color: return car.decal_colours()[0])


## And the other way round, where it has to hold exactly still.
##
## Every mark is looked at rather than the first, because the cycle is per
## mark: one of them left turning while the others held would be the bug this
## is for, and watching only the first would miss it.
func _check_the_decoration_holds(car: Car, where: String) -> int:
	var was := car.decal_colours()
	if was.size() != MARKS:
		print("  a car on %s came up wearing %d of its %d marks"
			% [where, was.size(), MARKS])
		return 1
	for i in 60:
		await Engine.get_main_loop().physics_frame
	var now := car.decal_colours()
	for i in was.size():
		if not now[i].is_equal_approx(was[i]):
			print("  a mark is turning colour on %s" % where)
			return 1
	print("on %s the decoration holds the colours it was drawn in" % where)
	return 0


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
