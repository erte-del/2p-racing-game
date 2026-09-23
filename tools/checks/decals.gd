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
	])
	await process_frame
	var shell: Node3D = car.get_node("Body")
	var passes: Array = shell.get("_stripe_passes")
	var stamps: Array = shell.get("_stamps")
	if passes.size() != 2:
		_fault("two stripes went on and the paint carries %d passes" % passes.size())
	# One sticker is two decals, one per flank: a decal throws its picture one
	# way, and a number on a door is on both doors.
	if stamps.size() != 2:
		_fault("one sticker went on and the car carries %d decals" % stamps.size())

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
	print("a car wearing 2 stripes and a sticker carries 2 passes and 2 decals, "
		+ "on %d surfaces the road is not one of" % seen)
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

	garage_page.call("close")
	garage_page.queue_free()
	await process_frame


# --- the little things --------------------------------------------------

func _a_sticker(shape: int, size: float) -> Dictionary:
	return {
		"kind": DecalArt.STICKER, "shape": shape, "colour": 3,
		"at": Vector2(0.5, 0.45), "size": size, "turn": 0.0,
	}


## A few points, the way a mouse drags them out.
func _a_stroke() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0.2, 0.6), Vector2(0.3, 0.3), Vector2(0.4, 0.62),
		Vector2(0.55, 0.28), Vector2(0.7, 0.6),
	])


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
