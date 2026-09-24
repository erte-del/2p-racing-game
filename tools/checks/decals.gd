extends SceneTree

# What a car is decorated with: the store, the shapes, and the tab that draws
# them.
#   Godot --path . --headless --script tools/checks/decals.gd
#
# Four things about decoration go wrong quietly, and none of them shows up by
# looking at a car:
#
#   - a decoration that comes back different from the one that was saved, or
#     does not come back at all, which is a player's own handwriting lost;
#   - a decoration that outlives its car - a section kept against an id that
#     is not in the garage any more is a decoration handed straight to whoever
#     next adds the same file, and that is not their drawing;
#   - the stock car losing its own, which is the one car with no folder to
#     keep anything in and so the one most likely to be forgotten;
#   - a car covered past the cap, which is a split screen nobody can read -
#     see `Decals.COVER_CAP`.
#
# So this drives a real `Decals` through a real file, removes a real car out of
# a real garage, and opens the real tab to see the fifty coins actually gate
# it. It cannot touch a player's own decoration or their garage: every check
# under `tools/` is sandboxed, so what it writes goes somewhere of its own.
# See `Sandbox`.
#
# `Decals`, `Garage` and `Purse` are reached off the tree rather than named,
# constants and all. A `--script` run is compiled before the autoloads are
# registered, so none of them is an identifier here - see the comment on
# `SETTINGS_PATH` in `screen_fit.gd`. `DecalArt`, `Shop` and `Paints` are named
# freely: they are plain tables that name no autoload, which is most of why
# they are tables.

var _faults := 0
## The autoloads, off the tree, and what the stock car's id is. Kept as members
## rather than passed down the page: every check below wants at least one of
## them, and none of them changes while this runs.
var _decals: Node
var _garage: Node
var _purse: Node
var _stock := ""


func _init() -> void:
	await process_frame
	var decals: Node = root.get_node_or_null(^"/root/Decals")
	var garage: Node = root.get_node_or_null(^"/root/Garage")
	var purse: Node = root.get_node_or_null(^"/root/Purse")
	if decals == null or garage == null or purse == null \
			or not decals.has_method("set_marks") or not garage.has_method("adopt"):
		# An autoload whose script failed to compile is still in the tree, as a
		# bare node, and every call into it is an error that counts as no fault.
		_fault("the autoloads are missing or came up without a script")
		print("%d faults" % _faults)
		quit(1)
		return
	if not Sandbox.on():
		print("  refusing to run: this check adds and removes cars and writes "
			+ "decoration, and would be doing it to a real garage")
		print("1 faults")
		quit(1)
		return
	_decals = decals
	_garage = garage
	_purse = purse
	_stock = garage.STOCK

	_check_the_shapes()
	_check_the_faces()
	_check_what_a_mark_may_be()
	_check_the_cap()
	_check_saving()
	_check_a_car_going()
	_check_the_price()
	await _check_what_lands_on_the_car()
	await _check_the_tab()

	_decals.clear(_stock)
	_purse.forget()
	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


## Every shape the game ships, drawn once and looked at.
##
## A shape that draws nothing is a sticker a player pays fifty coins for and
## then cannot see, and one that draws everything is a car under a solid
## rectangle. Both come out as a coverage of nought or one, which is the one
## number that catches either without anybody having to look at a picture.
func _check_the_shapes() -> void:
	for shape in DecalArt.STRIPES.size():
		var mask := DecalArt.stripe_mask(shape)
		if mask == null or mask.get_width() != DecalArt.STRIPE_SIZE:
			_fault("the %s stripe has no picture" % DecalArt.stripe_name(shape))
			continue
		var covers := DecalArt.cover_of({"kind": DecalArt.STRIPE, "shape": shape})
		if covers <= 0.0 or covers >= 1.0:
			_fault("the %s stripe covers %.2f of the car, which is not a stripe"
				% [DecalArt.stripe_name(shape), covers])
	for shape in DecalArt.STICKERS.size():
		var stamp := DecalArt.sticker_stamp(shape)
		if stamp == null or stamp.get_width() != DecalArt.STAMP_SIZE:
			_fault("the %s sticker has no picture" % DecalArt.sticker_name(shape))
			continue
		var covers := DecalArt.cover_of(
			{"kind": DecalArt.STICKER, "shape": shape, "size": 1.0})
		if covers <= 0.0 or covers >= 1.0:
			_fault("the %s sticker fills %.2f of its own square"
				% [DecalArt.sticker_name(shape), covers])
	# A word drawn with the mouse, at the size one actually arrives.
	var scrawled := DecalArt.scrawl_stamp([_a_stroke()])
	if scrawled == null or scrawled.get_width() != DecalArt.SCRAWL_SIZE:
		_fault("a hand-written word has no picture")
	print("%d stripes and %d stickers, each of them a shape"
		% [DecalArt.STRIPES.size(), DecalArt.STICKERS.size()])


## Where a mark put on a panel is, and where a click on that panel lands.
##
## The page a player decorates a car on is now the car itself: a sticker goes
## where the mouse was pointed, and a word is written on the paintwork. All of
## that is one piece of arithmetic - a ray against the box the model measures,
## in `CarFaces` - run forwards by the shell to place a decal and backwards by
## the garage to work out what was clicked on. If the two ever disagree, a
## sticker lands somewhere other than where it was put, and no assertion
## anywhere else in the game would say so: the car would simply look wrong to
## whoever drew on it.
##
## So every face is aimed at and picked up again, from straight on and from an
## angle, and the two answers have to be the same place. The box is the stock
## car's own measurements, because that is the car nearly everyone decorates.
func _check_the_faces() -> void:
	var box := AABB(Vector3(-1.03, 0.0, -2.435), Vector3(2.06, 1.45, 4.87))
	var spots: Array[Vector2] = [
		Vector2(0.5, 0.5), Vector2(0.38, 0.62), Vector2(0.64, 0.41),
	]
	var tried := 0
	# A mark saved on one of the old faces is drawn where it always was: on
	# that face of the box, at its place on it, thrown back along the way the
	# face looks - once per side for the flanks, once for everything else.
	for face in CarFaces.COUNT:
		for at in spots:
			tried += 1
			var mark := _a_sticker(4, 0.2, face)
			mark["at"] = at
			var placements := CarFaces.placements(box, mark)
			if placements.size() != CarFaces.sides(face).size():
				_fault("a sticker on %s is worn as %d decals"
					% [CarFaces.name_of(face), placements.size()])
				continue
			for i in placements.size():
				var side: int = CarFaces.sides(face)[i]
				var placement: Dictionary = placements[i]
				var point := CarFaces.point_of(box, face, side, at)
				if not (placement.point as Vector3).is_equal_approx(point) \
						or not (placement.out as Vector3).is_equal_approx(
							CarFaces.plane(box, face, side).out):
					_fault("a sticker on %s at %v is not where it was saved"
						% [CarFaces.name_of(face), at])
				if not box.grow(0.001).has_point(point):
					_fault("%s at %v is not on the car at all"
						% [CarFaces.name_of(face), at])
				if (CarFaces.at_of(box, face, side, point) as Vector2).distance_to(at) > 0.0001:
					_fault("a place on %s does not come back to itself"
						% CarFaces.name_of(face))
	# And a mark on the body is on the face its aim is nearest, never the
	# underside.
	var nearest := {
		Vector3.UP: CarFaces.TOP, Vector3(0.0, 0.8, -0.6): CarFaces.TOP,
		Vector3.FORWARD: CarFaces.NOSE, Vector3.BACK: CarFaces.TAIL,
		Vector3.LEFT: CarFaces.FLANKS, Vector3(0.9, 0.3, 0.1): CarFaces.FLANKS,
		Vector3(0.0, -0.9, -0.3): CarFaces.NOSE,
	}
	for aim: Vector3 in nearest:
		if CarFaces.face_of_aim(aim.normalized()) != int(nearest[aim]):
			_fault("a mark facing %v is nearest %s" % [aim,
				CarFaces.name_of(CarFaces.face_of_aim(aim.normalized()))])
	print("%d marks saved on %d faces stay where they were saved"
		% [tried, CarFaces.COUNT])


## What the store lets through, and what it turns away.
##
## Everything goes through `tidy` - what the screen sends and what the file
## holds - so it is the one place a decoration can be made of something the
## game cannot draw.
func _check_what_a_mark_may_be() -> void:
	if not DecalArt.tidy({"kind": "an anchor", "shape": 0}).is_empty():
		_fault("a kind of decoration that does not exist was allowed")
	if not DecalArt.tidy({}).is_empty():
		_fault("a mark with nothing in it was allowed")
	# A word with nothing written in it is a decal drawing nothing and one of
	# the eight slots spent on it.
	if not DecalArt.tidy({"kind": DecalArt.SCRAWL, "strokes": []}).is_empty():
		_fault("a hand-written word with nothing in it was allowed")

	# A shape number from a build with more stickers in it than this one.
	var wild: Dictionary = DecalArt.tidy({
		"kind": DecalArt.STICKER, "shape": 900, "colour": 900,
		"at": Vector2(9.0, -9.0), "size": 90.0, "turn": 90.0,
	})
	if wild.is_empty():
		_fault("a mark from an older build was thrown away rather than tidied")
		return
	if int(wild.shape) >= DecalArt.STICKERS.size():
		_fault("a sticker that is not in the list came back as shape %d" % wild.shape)
	# The six the shop sells are paint. A stripe in one would be a way of
	# wearing a bought colour without ever buying it.
	if int(wild.colour) >= Paints.FREE:
		_fault("a mark came back in %s, which is a paint that has to be bought"
			% Paints.name_of(int(wild.colour)))
	var at: Vector2 = wild.at
	if at.x < 0.0 or at.x > 1.0 or at.y < 0.0 or at.y > 1.0:
		_fault("a mark came back at %v, which is not on the car" % at)
	if float(wild.size) > 1.0:
		_fault("a mark came back %.1f times the size of the car" % float(wild.size))
	print("a mark out of an older build comes back as %s in %s, on the car"
		% [DecalArt.sticker_name(int(wild.shape)), Paints.name_of(int(wild.colour))])


## The cap, which is the rule that keeps a split screen readable.
##
## Refused whole rather than trimmed, and the car left exactly as it was: a
## player who has just drawn one sticker too many should be told the car is
## full, not handed back a car with something else quietly missing off it.
func _check_the_cap() -> void:
	var id := _stock
	_decals.clear(id)
	var one := _a_sticker(0, 0.3)
	if not _decals.add_mark(id, one):
		_fault("a single sticker would not go on an empty car")
	var was: Array = _decals.marks_on(id)

	# A sticker the whole length of the car is well past a third of it.
	if _decals.add_mark(id, _a_sticker(6, 1.0)):
		_fault("a sticker covering the whole car went on")
	if not _same(_decals.marks_on(id), was):
		_fault("a refused sticker changed the car anyway")
	if _decals.cover_on(id) > DecalArt.COVER_CAP:
		_fault("the car is covered %.2f, past the cap of %.2f"
			% [_decals.cover_on(id), DecalArt.COVER_CAP])

	# And there is a limit on how many things there are, whatever they cover,
	# because each of them is decals to build and draw.
	_decals.clear(id)
	var tiny := 0
	for i in DecalArt.MARKS_LIMIT + 4:
		if _decals.add_mark(id, _a_sticker(0, 0.09)):
			tiny += 1
	if tiny > DecalArt.MARKS_LIMIT:
		_fault("%d things went on a car that may carry %d"
			% [tiny, DecalArt.MARKS_LIMIT])
	print("a car carries at most %d things, covering at most %d%% of it"
		% [DecalArt.MARKS_LIMIT, roundi(DecalArt.COVER_CAP * 100.0)])
	_decals.clear(id)


## Saved and read back, including a word drawn with a mouse - which is the one
## part of a decoration that is not a number off a list, and so the one part
## that a file could quietly lose.
func _check_saving() -> void:
	var made_up := "00112233445566aa"
	_decals.clear(_stock)
	_decals.clear(made_up)
	var wanted := [
		{"kind": DecalArt.STRIPE, "shape": 1, "colour": 6,
			"at": Vector2(0.5, 0.5), "size": 1.0, "turn": 0.0},
		_a_sticker(4, 0.2),
		{"kind": DecalArt.SCRAWL, "shape": 0, "colour": 9,
			"at": Vector2(0.4, 0.55), "size": 0.3, "turn": 0.4,
			"strokes": [_a_stroke()]},
	]
	if not _decals.set_marks(_stock, wanted):
		_fault("a decoration of one of each kind would not go on")
		return
	if not _decals.set_marks(made_up, [_a_sticker(2, 0.2)]):
		_fault("a car that is not the stock car could not be decorated")

	_decals.load_decals()
	var back: Array = _decals.marks_on(_stock)
	if not _same(back, wanted):
		_fault("the stock car came back wearing something else")
	elif back.size() == 3:
		var strokes: Array = back[2].strokes
		var points: PackedVector2Array = strokes[0]
		print("read back: %s, %s and %d points of somebody's handwriting"
			% [DecalArt.stripe_name(int(back[0].shape)),
				DecalArt.sticker_name(int(back[1].shape)), points.size()])
	if _decals.marks_on(made_up).size() != 1:
		_fault("a car that is not the stock car lost its decoration in the file")

	# The stock car is the one with no folder of its own to keep anything in,
	# so it gets a section called `_stock` - and nothing may mistake that for a
	# car somebody added.
	if _garage.is_id(_decals.STOCK_SECTION):
		_fault("the stock car's section could be taken for a car's id")
	_decals.clear(made_up)


## A car taken out of the garage takes its decoration with it, and nothing
## else's goes with it.
##
## The stock car's own bytes are used to make the car, so there is a real id,
## a real folder and a real removal - the thing being checked is that `Garage`
## actually tells `Decals` about it, and a made-up id would not go through
## `Garage.remove` at all.
func _check_a_car_going() -> void:
	var bytes := FileAccess.get_file_as_bytes(_garage.STOCK_MODEL)
	if bytes.is_empty():
		_fault("the stock model could not be read, so no car could be added")
		return
	var added: Dictionary = _garage.adopt(bytes, "A CHECK'S CAR")
	if not added.ok:
		_fault("a car could not be added: %s" % added.error)
		return
	var id := String(added.id)
	_decals.set_marks(_stock, [_a_sticker(0, 0.2)])
	_decals.set_marks(id, [_a_sticker(1, 0.2)])
	if not _decals.decorated(id):
		_fault("a car in the garage could not be decorated")

	_garage.remove(id)
	if _decals.decorated(id):
		_fault("a car was taken out of the garage and its decoration stayed behind")
	if not _decals.decorated(_stock):
		_fault("removing a car took the stock car's decoration with it")
	# And it is gone from the file too, not merely out of what is in hand.
	_decals.load_decals()
	if _decals.decorated(id):
		_fault("a removed car's decoration came back off the disk")
	if not _decals.decorated(_stock):
		_fault("the stock car's decoration did not survive a save and a load")
	print("a car removed from the garage takes its decoration with it, "
		+ "and leaves the stock car's alone")
	_decals.clear(_stock)


## The slot is a thing the shop sells, and the shop is the only place it is
## priced. A price written down twice is a price that gets changed once.
func _check_the_price() -> void:
	var sold := Shop.entry(Shop.SLOT_ITEM)
	if sold.is_empty():
		_fault("the shop does not sell the customisation slot at all")
		return
	if int(sold.cost) != Shop.SLOT_COST:
		_fault("the slot costs %d in the table and %d in the constant"
			% [int(sold.cost), Shop.SLOT_COST])
	if String(sold.kind) != Shop.SLOT:
		_fault("the slot is for sale as a %s" % sold.kind)
	print("the customising slot is %d coins" % Shop.SLOT_COST)


## What a decorated car actually carries, and where it is allowed to land.
##
## The one failure this whole feature was most likely to ship with is a sticker
## printed on the tarmac under the car. A `Decal` projects onto every surface
## whose visual layer its cull mask lets through, and the cars share layer one
## with the road, the trees and everything else - so a decal left looking at
## the world is a decal on the world. A picture would show it, which is what
## `tools/checks/decorate_shot.gd` is for, but a number catches it on every run
## and at every angle: the mask must name the shell's own layer and must not
## name the world's.
func _check_what_lands_on_the_car() -> void:
	var car: Node3D = (load("res://scenes/car/car.tscn") as PackedScene).instantiate()
	root.add_child(car)
	await process_frame
	car.decorate([
		{"kind": DecalArt.STRIPE, "shape": 0, "colour": 1,
			"at": Vector2(0.5, 0.5), "size": 1.0, "turn": 0.0},
		{"kind": DecalArt.STRIPE, "shape": 3, "colour": 2,
			"at": Vector2(0.5, 0.5), "size": 1.0, "turn": 0.0},
		_a_sticker(4, 0.2),
		_a_sticker(1, 0.2, CarFaces.TOP),
	])
	await process_frame
	var shell: Node3D = car.get_node("Body")
	var passes: Array = shell.get("_stripe_passes")
	var stamps: Array = shell.get("_stamps")
	if passes.size() != 2:
		_fault("two stripes went on and the paint carries %d passes" % passes.size())
	# A sticker on the flanks is two decals, one per side: a decal throws its
	# picture one way, and a number on a door is on both doors. One on the
	# roof is one decal, because a car has one roof - and a car that built two
	# of those would be throwing the second at nothing.
	if stamps.size() != 3:
		_fault("a sticker on the flanks and one on the top went on, and the car "
			+ "carries %d decals rather than 3" % stamps.size())
	# The one on the roof looks down, and the two on the doors look out. A
	# decal aimed the wrong way is a decal printing on the inside of the far
	# panel, which nothing but a picture would otherwise catch.
	var downward := 0
	for stamp in stamps:
		if (stamp as Decal).global_transform.basis.y.dot(Vector3.UP) > 0.9:
			downward += 1
	if downward != 1:
		_fault("%d of the car's decals are aimed down at it, rather than 1"
			% downward)

	var world := 1
	for stamp in stamps:
		var mask: int = (stamp as Decal).cull_mask
		if mask & world != 0:
			_fault("a sticker is told to land on the world, which is the road")
		if mask == 0:
			_fault("a sticker is told to land on nothing at all")
	# And the model really is on the layer the decals are looking at, or the
	# sticker lands nowhere and the car is simply bare.
	#
	# The model's own meshes, and only those. The shell also carries headlights
	# and the smoke off a dying engine, and neither of those is a surface a
	# sticker could land on if it wanted to.
	var model: Node3D = shell.get_node_or_null(^"Model")
	var on_it := 0
	var seen := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		seen += 1
		for stamp in stamps:
			if (node as MeshInstance3D).layers & (stamp as Decal).cull_mask != 0:
				on_it += 1
				break
	if seen == 0:
		_fault("the car has no surfaces at all to decorate")
	elif on_it != seen:
		_fault("%d of the car's %d surfaces are not on the layer its stickers look at"
			% [seen - on_it, seen])
	# The world's layer is still on them, or the car would only be visible to
	# its own stickers.
	for node in model.find_children("*", "MeshInstance3D", true, false):
		if (node as MeshInstance3D).layers & world == 0:
			_fault("a surface of the car was taken off the world's layer")
			break

	# Taken off again, and nothing left behind: a rebuild that kept its old
	# decals would pile a car's worth of them up every time a sticker moved.
	car.decorate([])
	await process_frame
	if not (shell.get("_stamps") as Array).is_empty() \
			or not (shell.get("_stripe_passes") as Array).is_empty():
		_fault("a decoration taken off left its decals on the car")
	print("a car wearing 2 stripes, a sticker on the doors and one on the roof "
		+ "carries 2 passes and 3 decals, on %d surfaces the road is not one of"
		% seen)
	car.queue_free()
	await process_frame


## The tab itself, opened the way a player opens it.
##
## What is being checked is the gate, and the gate only: that pressing a stripe
## with nothing in the purse puts nothing on the car and says why, and that the
## same press after fifty coins have been spent does put it on. Everything
## further in is the same `Decals` the rest of this file has already driven.
func _check_the_tab() -> void:
	var garage_page: Control = (load("res://scenes/garage.tscn") as PackedScene).instantiate()
	root.add_child(garage_page)
	for i in 10:
		await process_frame
	garage_page.call("open", 2)
	for i in 10:
		await process_frame
	garage_page.call("_show_tab", 1)
	for i in 10:
		await process_frame

	var page: Node = garage_page.get("_decoration")
	if page == null:
		_fault("the garage has no decoration tab on it")
		garage_page.queue_free()
		return
	if not page.is_visible_in_tree():
		_fault("the decoration tab was asked for and did not come up")

	_purse.forget()
	_decals.clear(_stock)
	page.call("_toggle_stripe", 0)
	if _decals.decorated(_stock):
		_fault("a stripe went on a car without the slot being paid for")

	# Everything on the page stays pressable without the slot, for the reason
	# the shop keeps BUY pressable on an empty purse: a disabled button cannot
	# take the keyboard, and both players are on one.
	for named in ["_draw_button", "_off_button", "_all_off_button"]:
		var button: Button = page.get(named)
		if button == null or button.disabled:
			_fault("%s cannot be pressed before the slot is bought" % named)

	_purse.bank(Shop.SLOT_COST)
	if not _purse.buy(Shop.SLOT_ITEM, Shop.SLOT_COST):
		_fault("the slot could not be bought with exactly enough coins")
	page.call("_toggle_stripe", 0)
	if not _decals.decorated(_stock):
		_fault("a stripe would not go on after the slot was bought")
	else:
		print("the tab puts nothing on a car until the slot is paid for, "
			+ "and a stripe goes on the moment it is")
	# Pressed again, the same stripe in the same colour comes off.
	page.call("_toggle_stripe", 0)
	if _decals.decorated(_stock):
		_fault("a stripe pressed twice stayed on")

	await _check_the_pen(page)
	await _check_the_body(page)
	await _check_pressing_the_car(garage_page, page)
	await _check_the_manual_camera(page)
	garage_page.call("close")
	garage_page.queue_free()
	await process_frame


## A word comes out in the line it was drawn in.
##
## The pen's width is picked as a share of the car's length, and a finished
## word keeps it as a share of its own box, whose size is itself a share of the
## car's length - so the two multiplied are the width that was picked, however
## short or long the word. That is the whole promise: it used to be a fixed
## share of the box, and a short word came out thinner than the stroke the
## player had just watched themselves draw.
func _check_the_pen(page: Node) -> void:
	var nibs: Array = page.get("NIBS")
	var stage: Control = page.get("_stage")
	var middle: Vector2 = stage.size * 0.5
	# Side on, so a long stroke across the middle of the view is all door.
	stage.set("_yaw", PI * 0.5)
	stage.set("_pitch", 0.0)
	stage.call("_stand_the_camera")
	# The camera answers where a point on the screen is from where it stood at
	# the last frame, not from where it was put a line ago.
	await process_frame
	for nib in [0, nibs.size() - 1]:
		for reach in [16.0, 160.0]:
			_decals.clear(_stock)
			page.call("_choose_nib", nib)
			page.call("_press_the_pen")
			_write(page, [middle - Vector2(reach, 0.0), middle + Vector2(reach, 0.0)])
			page.call("_press_the_pen")
			var marks: Array = _decals.marks_on(_stock)
			if marks.size() != 1:
				_fault("a word written with the pen did not go on the car")
				continue
			var mark: Dictionary = marks[0]
			var width := float(mark.get("pen", 0.0)) * float(mark.size)
			if absf(width - float(nibs[nib])) > 0.0005:
				_fault("a word %d pixels long drawn %.3f thick came out %.3f thick"
					% [reach * 2.0, nibs[nib], width])
	# Changed with a word on the go, the whole of the word is drawn again in
	# the new width - one mark, one pen, the way it has one colour.
	_decals.clear(_stock)
	page.call("_choose_nib", 0)
	page.call("_press_the_pen")
	_write(page, [middle - Vector2(60.0, 0.0), middle + Vector2(60.0, 0.0)])
	page.call("_choose_nib", 2)
	page.call("_press_the_pen")
	var redrawn: Array = _decals.marks_on(_stock)
	if redrawn.size() != 1 or absf(float((redrawn[0] as Dictionary).pen)
			* float((redrawn[0] as Dictionary).size) - float(nibs[2])) > 0.0005:
		_fault("a word on the go kept its old width when a new one was picked")
	_decals.clear(_stock)
	page.call("_choose_nib", 1)
	stage.call("reset_view")
	await process_frame
	print("a word comes out as thick as it was drawn, short or long, "
		+ "at every width the pen offers")


## The two cameras over the car.
##
## The automatic one is where the page opens. Ticking MANUAL CAMERA changes
## nothing on the screen until the camera is moved; then the wheel goes towards
## whatever is under the cursor and keeps it under the cursor, it goes nearer
## the paint than the automatic one ever may, and a drag with it slides the car
## across the view. Ticking AUTOMATIC CAMERA again puts back the view there was.
## Ticked through the boxes themselves, because a box that ticks without
## reaching the camera is the failure a player would actually meet.
func _check_the_manual_camera(page: Node) -> void:
	var stage: Control = page.get("_stage")
	var camera: Camera3D = stage.get("_camera")
	var automatic: CheckBox = page.get("_automatic_box")
	var manual: CheckBox = page.get("_manual_box")
	stage.call("reset_view")
	await process_frame
	if not automatic.button_pressed or manual.button_pressed \
			or stage.call("is_manual"):
		_fault("the page does not open on the automatic camera")
	var was := camera.global_transform
	manual.button_pressed = true
	await process_frame
	if not stage.call("is_manual") or automatic.button_pressed:
		_fault("ticking MANUAL CAMERA did not hand the camera over")
	if not camera.global_transform.is_equal_approx(was):
		_fault("ticking MANUAL CAMERA moved the camera before it was moved")

	# The wheel, over a point on the car off the middle of the view. That
	# point is still under the cursor afterwards, and the camera is nearer it.
	var cursor := Vector2(stage.size.x * 0.62, stage.size.y * 0.55)
	var under: Dictionary = stage.call("surface_at", cursor)
	if under.is_empty():
		_fault("there is no car at %v to zoom towards" % cursor)
		return
	var point: Vector3 = under.point
	var far := camera.global_position.distance_to(point)
	stage.call("zoom_by", 4.0, cursor)
	await process_frame
	var now: Dictionary = stage.call("flat", point)
	if now.is_empty() or (now.at as Vector2).distance_to(cursor) > 2.0:
		_fault("zooming towards %v took the car out from under the cursor, to %s"
			% [cursor, now])
	if camera.global_position.distance_to(point) > far * 0.6:
		_fault("four notches of the wheel only went from %.2f m to %.2f m"
			% [far, camera.global_position.distance_to(point)])
	# And nearer than the automatic camera may: it stops half a metre outside
	# the car's box, and this goes to a hand's width from the paint.
	stage.call("zoom_by", 40.0, cursor)
	await process_frame
	var close := camera.global_position.distance_to(point)
	if close > 0.3:
		_fault("the manual camera will not go nearer the paint than %.2f m" % close)

	# A drag with Shift down slides the car across the view with the cursor:
	# the point the camera turns about goes exactly as far as the drag, and
	# anything nearer the camera than that a little further, as it should.
	# The point is in the world, where the camera is, rather than in the car's
	# own space, so it is put on the screen by the camera itself.
	stage.call("reset_view")
	await process_frame
	var about: Vector3 = stage.get("_focus")
	var before := camera.unproject_position(about)
	page.call("_stage_motion", _shift_drag(page, Vector2(40.0, -25.0)))
	page.call("_let_go")
	await process_frame
	var after := camera.unproject_position(about)
	if (after - before).distance_to(Vector2(40.0, -25.0)) > 1.0:
		_fault("sliding the manual camera 40, -25 moved the car from %s to %s"
			% [before, after])

	# Back to the automatic camera: the view it had.
	automatic.button_pressed = true
	await process_frame
	if stage.call("is_manual") or manual.button_pressed:
		_fault("ticking AUTOMATIC CAMERA did not take the camera back")
	if not camera.global_transform.is_equal_approx(was):
		_fault("the automatic camera did not come back to where it was")
	print("the manual camera zooms towards the cursor to %.2f m off the paint, "
		% close + "slides with a drag, and hands back the view it took")


## A press with Shift on the car's view and the drag it starts, as the motion
## to hand the page.
func _shift_drag(page: Node, by: Vector2) -> InputEventMouseMotion:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.shift_pressed = true
	page.call("_stage_button", press)
	var moved := InputEventMouseMotion.new()
	moved.relative = by
	return moved


## One stroke of the pen through points on the car's view, the way the mouse
## would draw it: down on the first, dragged through the rest, let go.
func _write(page: Node, points: Array) -> void:
	page.call("_start_a_stroke", points[0])
	for i in range(1, points.size()):
		page.call("_draw_to", points[i])
	page.call("_finish_a_stroke")


## Things go on the bodywork where they are put, not on a panel of the box
## round it.
##
## The bonnet is the case that made this necessary. It slopes, so it is neither
## the top of the box nor the front of it, and it sits well below the roofline
## - a decal thrown down from the top of the box reached a quarter of the way
## into the car and stopped short of it, so nothing could be put on a bonnet at
## all. Here a sticker is dragged onto one and a word written on one, the way
## the mouse would, and each has to end up lying on the bonnet itself: its
## middle on the bodywork under the cursor, facing the way the bodywork faces
## there, and inside the reach of the decal that draws it.
func _check_the_body(page: Node) -> void:
	var stage: Control = page.get("_stage")
	var shell: Node3D = stage.get("_shell")
	var box: AABB = stage.call("bounds")
	# Looked at from in front and above, the way a player turns the car to
	# write on the bonnet.
	stage.set("_yaw", 0.0)
	stage.set("_pitch", 0.7)
	stage.call("_stand_the_camera")
	await process_frame
	# The bonnet: straight down onto the car a fifth of the way back from the
	# nose, on the middle line.
	var above := Vector3(box.get_center().x, box.end.y + 1.0,
		box.position.z + box.size.z * 0.2)
	var bonnet: Dictionary = shell.call("surface", above, Vector3.DOWN)
	if bonnet.is_empty():
		_fault("a ray straight down onto the bonnet missed the car")
		return
	var bonnet_point: Vector3 = bonnet.point
	var bonnet_normal: Vector3 = bonnet.normal
	if bonnet_point.y > box.end.y - box.size.y * 0.2:
		_fault("the bonnet was found at the roofline, which is not a bonnet")
	var on_screen: Dictionary = stage.call("flat", bonnet_point)
	if on_screen.is_empty():
		_fault("the bonnet is not in front of the camera looking at it")
		return
	var there: Vector2 = on_screen.at

	# A sticker, put on and dragged there.
	_decals.clear(_stock)
	page.call("_add_sticker", 4)
	page.set("_grab_copy", 0)
	page.call("_drag_to", there)
	var marks: Array = _decals.marks_on(_stock)
	if marks.size() != 1 or not CarFaces.on_the_body(marks[0]):
		_fault("a sticker dragged onto the bonnet is not on the body")
	else:
		_lies_on(marks[0], bonnet_point, bonnet_normal, box, "a sticker")

	# A word, written there.
	_decals.clear(_stock)
	page.call("_press_the_pen")
	_write(page, [there - Vector2(30.0, 6.0), there + Vector2(30.0, 6.0)])
	_write(page, [there - Vector2(0.0, 10.0), there + Vector2(0.0, 10.0)])
	page.call("_press_the_pen")
	marks = _decals.marks_on(_stock)
	if marks.size() != 1 or not CarFaces.on_the_body(marks[0]):
		_fault("a word written on the bonnet is not on the body")
	else:
		_lies_on(marks[0], bonnet_point, bonnet_normal, box, "a word")

	# One put on a door is worn on both doors, as it always was, and one on
	# the bonnet only on the bonnet.
	var door := {"kind": DecalArt.STICKER, "shape": 1, "colour": 2,
		"spot": Vector3(1.0, 0.5, 0.5), "aim": Vector3(1.0, 0.1, 0.0).normalized(),
		"size": 0.2, "turn": 0.0}
	if CarFaces.placements(box, DecalArt.tidy(door)).size() != 2:
		_fault("a sticker on the body facing out of a door is not on both doors")
	if CarFaces.placements(box, marks[0]).size() != 1:
		_fault("a word on the bonnet is worn more than once")

	# MIRROR, unticked with the far copy of a door sticker in hand, leaves it on
	# that door alone - the one taken hold of - and ticked again puts it back
	# on both, where it was.
	_decals.clear(_stock)
	_decals.add_mark(_stock, door)
	var both: Array = CarFaces.placements(box, _decals.marks_on(_stock)[0])
	page.set("_chosen", 0)
	page.set("_grab_copy", 1)
	page.call("_toggle_the_mirror", false)
	var alone: Array = CarFaces.placements(box, _decals.marks_on(_stock)[0])
	if alone.size() != 1:
		_fault("a sticker with the mirror off is worn %d times" % alone.size())
	elif (alone[0].point as Vector3).distance_to(both[1].point) > 0.01 \
			or (alone[0].out as Vector3).dot(both[1].out) < 0.999:
		_fault("the mirror turned off kept the door that was not taken hold of")
	page.call("_toggle_the_mirror", true)
	if CarFaces.placements(box, _decals.marks_on(_stock)[0]).size() != 2:
		_fault("a sticker with the mirror on again is not on both doors")
	# And what is put on with it off goes on once.
	page.call("_choose_nothing")
	page.call("_toggle_the_mirror", false)
	_decals.clear(_stock)
	page.call("_add_sticker", 2)
	page.call("_press_the_pen")
	_write(page, [there - Vector2(30.0, 0.0), there + Vector2(30.0, 0.0)])
	page.call("_press_the_pen")
	for mark: Dictionary in _decals.marks_on(_stock):
		if CarFaces.mirrored(mark):
			_fault("a %s put on with the mirror off is mirrored" % mark.kind)
	page.call("_toggle_the_mirror", true)
	_decals.clear(_stock)
	stage.call("reset_view")
	await process_frame
	print("a sticker dragged onto the bonnet and a word written on it both lie "
		+ "on the bonnet, %.2f m under the roofline" % (box.end.y - bonnet_point.y))


func _lies_on(mark: Dictionary, point: Vector3, normal: Vector3, box: AABB,
		what: String) -> void:
	var placement: Dictionary = CarFaces.placements(box, mark)[0]
	var middle: Vector3 = placement.point
	if middle.distance_to(point) > 0.12:
		_fault("%s put on the bonnet at %v is %.2f m away from it, at %v"
			% [what, point, middle.distance_to(point), middle])
	if (placement.out as Vector3).dot(normal) < 0.9:
		_fault("%s on the bonnet faces %v, and the bonnet faces %v"
			% [what, placement.out, normal])
	if not CarFaces.holds(placement, point):
		_fault("%s on the bonnet does not reach the bonnet" % what)


# --- the little things --------------------------------------------------

func _a_sticker(shape: int, size: float, face: int = CarFaces.FLANKS) -> Dictionary:
	return {
		"kind": DecalArt.STICKER, "shape": shape, "colour": 3, "face": face,
		"at": Vector2(0.5, 0.45), "size": size, "turn": 0.0,
	}


## A few points, the way a mouse drags them out.
func _a_stroke() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.2, 0.6), Vector2(0.3, 0.3), Vector2(0.4, 0.62),
		Vector2(0.55, 0.28), Vector2(0.7, 0.6),
	])


## A press on the car picks up what is under it.
##
## The page is the car now, so this is the one gesture the whole tab is built
## on: everything a player places, moves or writes starts with the garage
## working out what a click landed on. `_check_the_faces` holds the arithmetic;
## this holds the wiring, which is the other half and the half that fails
## quietly - a view that never sees a press is a page where nothing at all
## happens and no number anywhere says why.
##
## A real event pushed at the window, not a call into the page. What is being
## asked is whether the press reaches the car, and calling the thing that
## handles presses would be asking a question with the answer in it.
func _check_pressing_the_car(garage_page: Control, page: Node) -> void:
	var stage: Control = page.get("_stage")
	if stage == null or stage.size.x < 1.0:
		_fault("the decoration tab has no car on it to press")
		return
	# A sticker put on the way a player puts one on, which lands on the body
	# in the middle of the view - so the press that follows is aimed at it.
	if (stage.call("surface_at", stage.size * 0.5) as Dictionary).is_empty():
		_fault("the middle of the car's own view is not on the car")
		return
	_decals.clear(_stock)
	page.call("_add_sticker", 4)
	page.set("_chosen", -1)
	await process_frame

	var middle: Vector2 = stage.get_global_rect().get_center()
	for down in [true, false]:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = down
		press.position = root.get_final_transform() * middle
		root.push_input(press)
		await process_frame
	if int(page.get("_chosen")) != 0:
		_fault("a press in the middle of the car picked up nothing")
	else:
		print("a press on the car picks up the %s under it"
			% DecalArt.sticker_name(4))
	_decals.clear(_stock)
	page.set("_chosen", -1)


## Two decorations, compared the way they are actually used: field by field,
## with the floats allowed to be a hair apart. A decoration goes through a
## text file and back, and a stroke that refused to match itself after a save
## would be this check failing on the file format rather than on the game.
func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var one: Dictionary = a[i]
		var two: Dictionary = DecalArt.tidy(b[i])
		if str(one.kind) != str(two.kind) or int(one.shape) != int(two.shape) \
				or int(one.colour) != int(two.colour):
			return false
		if not (one.at as Vector2).is_equal_approx(two.at):
			return false
		if not is_equal_approx(float(one.size), float(two.size)) \
				or not is_equal_approx(float(one.turn), float(two.turn)):
			return false
		if not _same_strokes(one.get("strokes", []), two.get("strokes", [])):
			return false
	return true


func _same_strokes(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var one: PackedVector2Array = a[i]
		var two: PackedVector2Array = b[i]
		if one.size() != two.size():
			return false
		for point in one.size():
			if not one[point].is_equal_approx(two[point]):
				return false
	return true


func _fault(why: String) -> void:
	print("  %s" % why)
	_faults += 1
