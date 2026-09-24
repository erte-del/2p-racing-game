extends SceneTree

# A design saved as a livery: what it is written as, what it is called by, and
# what the garage does with it.
#   Godot --path . --headless --script tools/checks/liveries.gd
#
# A livery is the one thing in this game that is meant to travel. A car does
# too, but a car travels as the bytes it arrived as and is checked by hashing
# them; a livery travels as a line of text this game wrote, which means the
# writing and the reading are code, and code that disagrees with itself is a
# design that arrives as a different design.
#
# So four things are held down here, and none of them shows up by looking at a
# garage:
#
#   - a design written down and read back is the same design. If it is not, a
#     player's own handwriting changes shape on the way to somebody else.
#   - the id is the design. Two machines that write the same marks differently
#     hold the same livery under two ids, and neither can ever get the other's;
#     a livery whose text no longer hashes to its own id is one that has been
#     edited under a name that is not its own.
#   - what comes in from outside obeys every rule a design drawn here obeys -
#     the cap, the count, the free twelve - because the door is the same one.
#   - a livery thrown away leaves the cars that wore it exactly as they are.
#     They hold their own marks; the livery was only ever a way of getting
#     them there.
#
# `Liveries`, `Decals`, `Garage` and `Purse` are reached off the tree rather
# than named - a `--script` run is compiled before the autoloads are
# registered, see the comment on `SETTINGS_PATH` in `screen_fit.gd`. `Livery`,
# `DecalArt`, `Shop` and `Paints` are named freely: they are plain tables that
# name no autoload.

var _faults := 0
var _liveries: Node
var _decals: Node
var _stock := ""


func _init() -> void:
	await process_frame
	_liveries = root.get_node_or_null(^"/root/Liveries")
	_decals = root.get_node_or_null(^"/root/Decals")
	var garage: Node = root.get_node_or_null(^"/root/Garage")
	var purse: Node = root.get_node_or_null(^"/root/Purse")
	if _liveries == null or _decals == null or garage == null or purse == null \
			or not _liveries.has_method("keep"):
		_fault("the autoloads are missing or came up without a script")
		print("%d faults" % _faults)
		quit(1)
		return
	if not Sandbox.on():
		print("  refusing to run: this check writes liveries and decoration, and "
			+ "would be doing it to a real garage")
		print("1 faults")
		quit(1)
		return
	_stock = garage.STOCK

	_check_writing_it_down()
	_check_the_id()
	_check_keeping()
	_check_a_word_as_it_is_drawn()
	_check_what_comes_from_outside()
	_check_throwing_one_away()
	await _check_the_garage(purse)

	_liveries.load_liveries()
	for one: Dictionary in _liveries.all():
		_liveries.remove(one.id)
	_decals.clear(_stock)
	purse.forget()
	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


## A design, written down and read back.
##
## Every kind, because they are not written the same: a stripe is seven
## numbers, and a hand-written word carries the whole path the pen took.
func _check_writing_it_down() -> void:
	var design := _a_design()
	var text := Livery.written(design)
	var back := Livery.read(text)
	if back.size() != design.size():
		_fault("a design of %d marks read back as %d"
			% [design.size(), back.size()])
		return
	for i in design.size():
		var was: Dictionary = DecalArt.tidy(design[i])
		var now: Dictionary = back[i]
		if str(was.kind) != str(now.kind) or int(was.shape) != int(now.shape) \
				or int(was.colour) != int(now.colour):
			_fault("mark %d came back as something else" % i)
		if not (was.at as Vector2).is_equal_approx(now.at):
			_fault("mark %d came back at %v instead of %v" % [i, now.at, was.at])
		if not _close(float(was.size), float(now.size)) \
				or not _close(float(was.turn), float(now.turn)):
			_fault("mark %d came back a different size or angle" % i)
		if not _same_strokes(was.get("strokes", []), now.get("strokes", [])):
			_fault("mark %d lost the shape of its handwriting" % i)
	# Nothing in a design may hold the characters that hold a design together,
	# or it comes apart somewhere other than where it was joined.
	for character in [";", "|", "/"]:
		if text.count(character) == 0 and character != "/":
			_fault("a design of three kinds has no %s in it at all" % character)
	print("a design of %d marks writes as %d characters and reads back the same"
		% [design.size(), text.length()])


## The id, which is the promise a shared livery makes.
func _check_the_id() -> void:
	var design := _a_design()
	var id := Livery.id_for(design)
	if not Livery.is_id(id):
		_fault("a design hashed to %s, which is not an id" % id)
	# Written, read and hashed again: that is the round trip a livery actually
	# makes on its way to somebody else, and the id has to survive it.
	if Livery.id_for(Livery.read(Livery.written(design))) != id:
		_fault("a design does not hash to the same id after a trip through text")
	# The same design reached a different way is the same livery. This is what
	# stops two players who drew the same thing being unable to get each
	# other's.
	var again := _a_design()
	again.reverse()
	again.reverse()
	if Livery.id_for(again) != id:
		_fault("the same design worked out twice came to two different ids")
	# And a design that is not the same is not the same livery.
	var moved := _a_design()
	(moved[1] as Dictionary).at = Vector2(0.8, 0.5)
	if Livery.id_for(moved) == id:
		_fault("moving a sticker did not change the design's id")
	# Numbers go in at four places, so a difference finer than that is not a
	# difference: two machines rounding the last digit differently must not be
	# two liveries.
	var hair := _a_design()
	(hair[1] as Dictionary).size = float((hair[1] as Dictionary).size) + 0.000001
	if Livery.id_for(hair) != id:
		_fault("a millionth of a car's length made it a different livery")
	# A design of things worn on the flanks - which is everything anybody drew
	# before there were other panels to draw on - has to hash to what it always
	# hashed to. Written out in full here, because this is the one promise in
	# the game that reaches other people's machines and older copies of this
	# one: a livery shared last year has to still be the livery it says it is.
	# See `Livery.written` for how a face stays out of the line until there is
	# one worth writing.
	var flanks: Array = [{"kind": DecalArt.STICKER, "shape": 4, "colour": 2,
		"at": Vector2(0.4, 0.45), "size": 0.2, "turn": 0.0}]
	var line := Livery.written(flanks)
	if line != "sticker|4|2|0.4|0.45|0.2|0.0":
		_fault("a design worn on the flanks is written as `%s` now" % line)
	if Livery.id_for(flanks) != "5c220050ec76844a":
		_fault("a design worn on the flanks hashes to %s, which is not the id it "
			% Livery.id_for(flanks) + "had before there were panels to choose")
	# And one worn somewhere else is a different livery, carrying the panel it
	# is on through the text and back.
	var roof := flanks.duplicate(true)
	(roof[0] as Dictionary).face = CarFaces.TOP
	if Livery.id_for(roof) == Livery.id_for(flanks):
		_fault("the same sticker on the roof and on the doors is one livery")
	var came_back: Array = Livery.read(Livery.written(roof))
	if came_back.size() != 1 or int((came_back[0] as Dictionary).face) != CarFaces.TOP:
		_fault("a sticker on the roof did not come back off the roof")
	# A word's pen is the same kind of promise. A word in the width every word
	# had before there was a choice writes no pen at all, and one in another
	# width carries it through the text and back - on a panel that is not the
	# flanks too, since the pen and the panel are the two lone numbers that
	# can follow the seven.
	var word: Dictionary = _a_design()[2]
	if Livery.written([word]).split("|").size() != 8:
		_fault("a word in the old width wrote a pen down: %s" % Livery.written([word]))
	var fine := word.duplicate(true)
	fine.pen = 0.012
	fine.face = CarFaces.NOSE
	var fine_back: Array = Livery.read(Livery.written([fine]))
	if fine_back.size() != 1 or not _close(float((fine_back[0] as Dictionary).pen), 0.012) \
			or int((fine_back[0] as Dictionary).face) != CarFaces.NOSE:
		_fault("a word in a fine pen on the nose came back as %s" % [fine_back])
	if Livery.id_for([fine]) == Livery.id_for([word]):
		_fault("the same word in two widths is one livery")
	# And a mark put on the body. It comes back where it was and facing the
	# way it faced, its id survives the trip - the spot and the aim are
	# written rounded, and what is worked out from them has to be worked out
	# from the rounded ones - and it still carries the face it is nearest, for
	# anything that draws a design in faces and for a copy of the game that
	# has never heard of a body.
	var bonnet: Dictionary = word.duplicate(true)
	bonnet.erase("face")
	bonnet.erase("at")
	bonnet.spot = Vector3(0.51234567, 0.6789123, 0.1987654)
	bonnet.aim = Vector3(0.03, 0.81, -0.58).normalized()
	bonnet.pen = 0.0213
	var line_on_it := Livery.written([bonnet])
	var bonnet_back: Array = Livery.read(line_on_it)
	if bonnet_back.size() != 1 or not CarFaces.on_the_body(bonnet_back[0]):
		_fault("a word on the bonnet came back off the body: %s" % line_on_it)
	else:
		var was_on: Dictionary = DecalArt.tidy(bonnet)
		var now_on: Dictionary = bonnet_back[0]
		if (now_on.spot as Vector3).distance_to(was_on.spot) > 0.001 \
				or (now_on.aim as Vector3).dot(was_on.aim) < 0.9999:
			_fault("a word on the bonnet came back somewhere else: %s" % line_on_it)
		if int(now_on.face) != CarFaces.TOP:
			_fault("a word on the bonnet is nearest %s, not the top"
				% CarFaces.name_of(int(now_on.face)))
		if Livery.id_for(bonnet_back) != Livery.id_for([bonnet]) \
				or Livery.written(bonnet_back) != line_on_it:
			_fault("a word on the bonnet changed id on a trip through text")
	# What a copy from before the body reads: the same line with the body
	# taken out of it, which is the top of the car at the place nearest the
	# bonnet, and never the doors.
	var fields := line_on_it.split("|")
	var older := PackedStringArray()
	for field in fields:
		if not field.contains(":"):
			older.append(field)
	var older_back: Array = Livery.read("|".join(older))
	if older_back.size() != 1 or CarFaces.on_the_body(older_back[0]) \
			or int((older_back[0] as Dictionary).face) != CarFaces.TOP:
		_fault("a word on the bonnet, read without its body, is not on the top")
	# A mark on one door only. One on both doors - every mark there was before
	# the mirror could be turned off - writes nothing for it and keeps the id it
	# had; one on one door carries it through the text and back, and is a
	# different livery; and a copy from before the mirror, which reads the word
	# as a face the way it reads any lone field, reads the doors.
	var door := {"kind": DecalArt.STICKER, "shape": 1, "colour": 2,
		"spot": Vector3(1.0, 0.5, 0.5), "aim": Vector3(1.0, 0.1, 0.0).normalized(),
		"size": 0.2, "turn": 0.0}
	var both_line := Livery.written([door])
	if both_line.contains(Livery.SINGLE):
		_fault("a sticker on both doors wrote the mirror down: %s" % both_line)
	var one_door := door.duplicate(true)
	one_door["mirror"] = false
	var one_line := Livery.written([one_door])
	var one_back: Array = Livery.read(one_line)
	if one_back.size() != 1 or CarFaces.mirrored(one_back[0]):
		_fault("a sticker on one door came back on both: %s" % one_line)
	elif Livery.written(one_back) != one_line:
		_fault("a sticker on one door changed on a trip through text: %s" % one_line)
	if Livery.id_for([one_door]) == Livery.id_for([door]):
		_fault("a sticker on one door and on both is one livery")
	var fields_one := one_line.split("|")
	if fields_one.size() != 9 or int(fields_one[8]) != CarFaces.FLANKS:
		_fault("a copy from before the mirror would read a sticker on one door "
			+ "off the doors: %s" % one_line)
	print("a design hashes to %s, and to %s after a trip through text"
		% [id, Livery.id_for(Livery.read(Livery.written(design)))])
	print("one worn on the flanks still hashes to %s, and the same one on the "
		% Livery.id_for(flanks) + "roof to %s" % Livery.id_for(roof))


## Saving one, and saving the same one again.
func _check_keeping() -> void:
	_forget_everything()
	var kept: Dictionary = _liveries.keep(_a_design(), "a check's livery")
	if not kept.ok or not kept.new:
		_fault("a design would not save: %s" % kept.error)
		return
	if kept.name != "A CHECK'S LIVERY":
		_fault("a livery came out called %s" % kept.name)
	var again: Dictionary = _liveries.keep(_a_design(), "SOMETHING ELSE")
	if not again.ok or again.new:
		_fault("the same design saved twice was not the same livery")
	# The first name wins. A player who drew their way back to a design they
	# had already saved has not made a second one, and silently renaming the
	# one they had would lose the name they chose.
	if _liveries.name_of(String(kept.id)) != "A CHECK'S LIVERY":
		_fault("saving a design again renamed the one that was already there")

	# Nothing is a design, and neither is more than a car may wear.
	if (_liveries.keep([], "NOTHING") as Dictionary).ok:
		_fault("a livery with nothing on it was saved")
	var too_much := []
	for i in DecalArt.MARKS_LIMIT + 2:
		too_much.append(_a_sticker(0, 0.3))
	if (_liveries.keep(too_much, "TOO MUCH") as Dictionary).ok:
		_fault("a design past the cap was saved as a livery")

	_liveries.save_liveries()
	_liveries.load_liveries()
	if not _liveries.has(String(kept.id)):
		_fault("a livery did not survive a save and a load")
	elif _liveries.name_of(String(kept.id)) != "A CHECK'S LIVERY":
		_fault("a livery came back off the disk called something else")
	if _liveries.which(_a_design()) != kept.id:
		_fault("a design could not find the livery it is")
	print("saved as %s, %s, and the same design again is the same livery"
		% [kept.id, _liveries.name_of(String(kept.id))])


## Words the way the pen hands them over: a point every time the mouse moved,
## most of them a hair from the last and some of them the same point twice.
##
## Kept like that, three words ran past what a livery can be written down in,
## and every design with handwriting on it was refused as "too much" whatever
## else was on it. So: a word as it comes off the pen does not fit, the same
## word thinned does, thinning it again changes nothing, and a word already on
## a car from before there was thinning is thinned when the car is loaded.
func _check_a_word_as_it_is_drawn() -> void:
	_forget_everything()
	var raw := []
	for word in 3:
		raw.append({"kind": DecalArt.SCRAWL, "shape": 0, "colour": 2,
			"at": Vector2(0.3 + 0.2 * word, 0.5), "size": 0.2, "turn": 0.0,
			"pen": 0.06, "strokes": [_a_scrawled_line(word)]})
	if Livery.holds(raw):
		_fault("the scrawled words are not long enough to test anything")
	var thin := raw.map(DecalArt.thinned_word)
	var before := 0
	var after := 0
	for i in raw.size():
		before += (raw[i].strokes[0] as PackedVector2Array).size()
		after += (thin[i].strokes[0] as PackedVector2Array).size()
	if not Livery.holds(thin):
		_fault("three words thinned are still too long for a livery: %d characters"
			% Livery.written(thin).length())
	var twice := thin.map(DecalArt.thinned_word)
	if not _same_strokes(twice[0].strokes, thin[0].strokes):
		_fault("thinning a word that was already thin took more out of it")

	# A word on a car from before: saved at every point, and loaded back thin.
	_decals.set_marks(_stock, raw)
	_decals.save_decals()
	_decals.load_decals()
	var loaded: Array = _decals.marks_on(_stock)
	if loaded.size() != raw.size():
		_fault("a car with three words on it came back with %d marks" % loaded.size())
	else:
		var kept: Dictionary = _liveries.keep(loaded, "THREE WORDS")
		if not kept.ok:
			_fault("words loaded off a car from before would not save as a "
				+ "livery: %s" % kept.error)
		elif _liveries.which(_decals.marks_on(_stock)) != kept.id:
			_fault("the car those words were saved off is not wearing the livery")
	_decals.clear(_stock)
	print("three words as the pen drew them: %d points, thinned to %d, "
		% [before, after] + "and %d characters written down"
		% Livery.written(thin).length())


## A wavy line across the box read the way a mouse is read: a step a fraction
## of a pixel long, and every so often the same point again.
func _a_scrawled_line(seed: int) -> PackedVector2Array:
	var line := PackedVector2Array()
	for i in 700:
		var t := float(i) / 699.0
		var point := Vector2(0.05 + 0.9 * t,
			0.5 + 0.3 * sin(t * TAU * (2.0 + seed)) * cos(t * 3.0))
		line.append(point)
		if i % 5 == 0:
			line.append(point)
	return line


## A design from somebody else, which is a line of text this game did not
## write. It comes in through the same door and obeys the same rules.
func _check_what_comes_from_outside() -> void:
	_forget_everything()
	# A kind of mark the game has no shape for, alongside two it does. The
	# design arrives without that piece rather than not at all: a livery
	# missing a sticker is something a player can see, and nothing at all is
	# something they cannot work out the reason for.
	var text := "stripe|0|4|0.5|0.5|1.0|0.0;anchor|0|0|0.5|0.5|0.3|0.0" \
		+ ";sticker|4|2|0.4|0.45|0.2|0.0"
	var came: Dictionary = _liveries.adopt(text, "FROM SOMEBODY")
	if not came.ok:
		_fault("a design with one unknown mark in it arrived as nothing at all")
	elif _liveries.marks_of(String(came.id)).size() != 2:
		_fault("a design of two good marks and one bad kept %d"
			% _liveries.marks_of(String(came.id)).size())

	# A colour from the half of the paints the shop sells. Wearing one of those
	# on a stripe would be a way of having a bought colour without buying it,
	# so it is pulled back into the free twelve like anything else.
	var sold := "sticker|4|%d|0.4|0.45|0.2|0.0" % (Paints.COLOURS.size() - 1)
	var bought: Dictionary = _liveries.adopt(sold, "A SOLD COLOUR")
	if bought.ok:
		var marks: Array = _liveries.marks_of(String(bought.id))
		if not marks.is_empty() and int((marks[0] as Dictionary).colour) >= Paints.FREE:
			_fault("a livery arrived wearing a paint that has to be bought")

	# And a design too big to be one is not one, however it is written.
	var huge := PackedStringArray()
	for i in 40:
		huge.append("sticker|6|1|0.5|0.5|0.9|0.0")
	if (_liveries.adopt(";".join(huge), "ENORMOUS") as Dictionary).ok:
		_fault("a design of forty stickers arrived as a livery")
	print("a design from outside arrives through the same door, with only the "
		+ "marks this game has shapes for")


## Throwing a livery away is not throwing a decoration away.
##
## The whole reason the two stores are separate: a livery is *copied* onto a
## car, so a car holds its own marks and nothing it is wearing points at
## anything that can be removed out from under it.
func _check_throwing_one_away() -> void:
	_forget_everything()
	var kept: Dictionary = _liveries.keep(_a_design(), "GOING AWAY")
	var id := String(kept.id)
	_decals.set_marks(_stock, _liveries.marks_of(id))
	var worn: int = _decals.marks_on(_stock).size()
	if worn == 0:
		_fault("a livery would not go on a car")
		return
	_liveries.remove(id)
	if _liveries.has(id):
		_fault("a livery that was thrown away is still here")
	if _decals.marks_on(_stock).size() != worn:
		_fault("throwing a livery away took it off the car that was wearing it")
	else:
		print("a livery thrown away leaves the car wearing it exactly as it was")
	_decals.clear(_stock)


## The garage's own half: a livery is beside the cars, pressing one puts it on,
## and the fifty coins gate it the way they gate the decoration tab.
func _check_the_garage(purse: Node) -> void:
	_forget_everything()
	purse.forget()
	var kept: Dictionary = _liveries.keep(_a_design(), "ON THE PAGE")
	var id := String(kept.id)

	var garage: Control = (load("res://scenes/garage.tscn") as PackedScene).instantiate()
	root.add_child(garage)
	for i in 10:
		await process_frame
	garage.call("open", 2)
	for i in 10:
		await process_frame

	var tiles: Array = (garage.get("_livery_grids")[0] as Node).get_children()
	if tiles.size() != 1:
		_fault("one livery is saved and the garage shows %d" % tiles.size())
		garage.queue_free()
		return
	if str((tiles[0] as Button).get_meta("livery")) != id:
		_fault("the garage is showing a livery that is not the one saved")

	# Pressed with nothing in the purse: nothing goes on, and the page says why.
	(tiles[0] as Button).emit_signal("pressed")
	for i in 4:
		await process_frame
	if _decals.decorated(_stock):
		_fault("a livery went on a car without the slot being paid for")

	purse.bank(Shop.SLOT_COST)
	purse.buy(Shop.SLOT_ITEM, Shop.SLOT_COST)
	(tiles[0] as Button).emit_signal("pressed")
	for i in 4:
		await process_frame
	if _liveries.which(_decals.marks_on(_stock)) != id:
		_fault("a livery would not go on the car after the slot was bought")
	elif not (tiles[0] as Button).button_pressed:
		_fault("the car is wearing the livery and its tile is not held down")
	else:
		print("a livery sits beside the cars, goes on when it is pressed, and is "
			+ "held down while the car is wearing it")

	garage.call("close")
	garage.queue_free()
	await process_frame


# --- the little things --------------------------------------------------

## One of each kind, which is what makes this a design rather than a stripe.
func _a_design() -> Array:
	return [
		{"kind": DecalArt.STRIPE, "shape": 1, "colour": 10,
			"at": Vector2(0.5, 0.5), "size": 1.0, "turn": 0.0},
		_a_sticker(4, 0.2),
		{"kind": DecalArt.SCRAWL, "shape": 0, "colour": 9,
			"at": Vector2(0.38, 0.5), "size": 0.26, "turn": -0.25,
			"strokes": [
				PackedVector2Array([Vector2(0.2, 0.6), Vector2(0.31, 0.29),
					Vector2(0.4, 0.62)]),
				PackedVector2Array([Vector2(0.55, 0.3), Vector2(0.55, 0.64)]),
			]},
	]


func _a_sticker(shape: int, size: float) -> Dictionary:
	return {
		"kind": DecalArt.STICKER, "shape": shape, "colour": 3,
		"at": Vector2(0.62, 0.42), "size": size, "turn": 0.0,
	}


func _forget_everything() -> void:
	for one: Dictionary in _liveries.all():
		_liveries.remove(one.id)


## Two numbers that went through four decimal places and came back.
func _close(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


func _same_strokes(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		var one: PackedVector2Array = a[i]
		var two: PackedVector2Array = b[i]
		if one.size() != two.size():
			return false
		for point in one.size():
			if not _close(one[point].x, two[point].x) \
					or not _close(one[point].y, two[point].y):
				return false
	return true


func _fault(why: String) -> void:
	print("  %s" % why)
	_faults += 1
