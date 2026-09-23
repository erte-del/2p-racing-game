class_name Livery
extends RefCounted

## What a livery is, and what it is called by.
##
## A livery is a decoration with no car under it: the same stripes, stickers
## and handwriting a player draws on the decoration tab, kept as a design in
## its own right so it can be put on any car, kept beside the cars in the
## garage, and handed to somebody else.
##
## Kept as a plain table rather than folded into `Liveries` for the reason
## `Shop` and `DecalArt` are: the id is a pure function of the marks, and a
## check that wants to work one out should not have to stand the game up first.
##
## **The id is the design, hashed.** The same sixteen hex characters as a car
## uses, and for the same reasons: the same livery saved twice is one livery, a
## livery has the same id on every machine it is ever copied to, and a livery
## that arrives from a stranger can be checked against the id it was asked for
## before anything is done with it.
##
## That last one is why the hash is spelled out here rather than handed to
## `var_to_str`. Two machines have to agree on the string down to the last
## digit, and a float printed one way on one and another way on another is two
## machines that disagree about which livery they are holding. Every number
## goes in at four decimals, which is finer than any of them is ever read at -
## a mark's place on the car is a fraction of a car's length, and a ten
## thousandth of that is a tenth of a millimetre.

## How long a livery's name may be. The same as a car's, because they sit in
## the same row of the garage under the same size of tile, and a name that fits
## one has to fit the other. Tidying one is `Liveries.clean_name`, which is on
## the store rather than here: it is the garage's own rule, and the garage is
## an autoload that nothing in this file may name.
const NAME_LIMIT := 24

## How many characters the written-down form may run to.
##
## It is what goes to the server as a single column, so it needs a ceiling
## there whatever the game thinks. Eight marks of a dozen numbers is nothing;
## the whole of it is the handwriting, which is points. This is generous enough
## for eight scrawled words and far short of anything worth worrying about.
const TEXT_LIMIT := 8192

## How many places every number is written to, in the id and in the text that
## goes to the server. See above: this is the number two machines have to agree
## on, not a number anybody reads.
const PLACES := 4


## The id of a design: the first sixteen hex characters of the sha256 of it.
##
## Worked out from the tidied marks rather than from whatever was handed in, so
## two players who drew the same thing get the same id even if one of them
## arrived at it through a file an older build wrote.
static func id_for(marks: Array) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(written(marks).to_utf8_buffer())
	return hashing.finish().hex_encode().left(16)


## Whether a string could be a livery id at all. Checked before an id is used
## to build a request, because ids also arrive from other people.
static func is_id(id: String) -> bool:
	if id.length() != 16:
		return false
	for character in id:
		if not character in "0123456789abcdef":
			return false
	return true


## A design as one line of text: what is hashed, and what goes to the server.
##
## Fields separated by `|` and marks by `;`, with the strokes of a word run
## together inside their mark. Nothing in it can hold either character - every
## field is a number or one of three fixed words - so it comes apart again
## exactly the way it went together.
static func written(marks: Array) -> String:
	var lines := PackedStringArray()
	for mark in marks:
		if not (mark is Dictionary):
			continue
		var clean := DecalArt.tidy(mark)
		if clean.is_empty():
			continue
		var at: Vector2 = clean.at
		var fields := PackedStringArray([
			str(clean.kind), str(int(clean.shape)), str(int(clean.colour)),
			_number(at.x), _number(at.y),
			_number(float(clean.size)), _number(float(clean.turn)),
		])
		if str(clean.kind) == DecalArt.SCRAWL:
			var pen := PackedStringArray()
			for stroke in clean.get("strokes", []):
				var points := PackedStringArray()
				for point: Vector2 in stroke:
					points.append("%s,%s" % [_number(point.x), _number(point.y)])
				pen.append(" ".join(points))
			fields.append("/".join(pen))
		lines.append("|".join(fields))
	return ";".join(lines)


## And back again, into marks the game can draw.
##
## Everything that comes out of here goes through `DecalArt.tidy` like anything
## else, so a line a stranger wrote by hand cannot make a mark the game has no
## shape for. A line that will not read is skipped rather than failing the
## whole design: what arrives is then a livery missing a sticker, which a
## player can see, instead of nothing at all with no way to tell why.
static func read(text: String) -> Array:
	var marks := []
	if text.length() > TEXT_LIMIT:
		return marks
	for line in text.split(";", false):
		var fields := line.split("|", false)
		if fields.size() < 7:
			continue
		var mark := {
			"kind": fields[0],
			"shape": int(fields[1]),
			"colour": int(fields[2]),
			"at": Vector2(float(fields[3]), float(fields[4])),
			"size": float(fields[5]),
			"turn": float(fields[6]),
		}
		if fields.size() > 7:
			mark["strokes"] = _read_strokes(fields[7])
		var clean := DecalArt.tidy(mark)
		if not clean.is_empty():
			marks.append(clean)
	return marks


## Whether a set of marks is a design worth keeping at all.
##
## The same rules a car's decoration obeys, applied to a design with no car
## under it: something on it, not more than a car may carry, and not covering
## more of a car than a car may be covered. A livery that could not go on a car
## would be a tile in the garage that does nothing when it is pressed.
static func holds(marks: Array) -> bool:
	if marks.is_empty() or marks.size() > DecalArt.MARKS_LIMIT:
		return false
	if DecalArt.cover_of_all(marks) > DecalArt.COVER_CAP:
		return false
	return written(marks).length() <= TEXT_LIMIT



static func _number(value: float) -> String:
	# Snapped to the same grid on every machine, and `-0.0000` folded into
	# `0.0000` - two ways of writing nothing would be two ids for one livery.
	var snapped := snappedf(value, pow(10.0, -PLACES))
	if is_zero_approx(snapped):
		snapped = 0.0
	return String.num(snapped, PLACES)


static func _read_strokes(text: String) -> Array:
	var strokes := []
	for stroke in text.split("/", false):
		var points := PackedVector2Array()
		for pair in stroke.split(" ", false):
			var both := pair.split(",", false)
			if both.size() == 2:
				points.append(Vector2(float(both[0]), float(both[1])))
		if not points.is_empty():
			strokes.append(points)
	return strokes
