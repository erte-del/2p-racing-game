class_name DecalArt
extends RefCounted

## The shapes a car can be decorated with, and the pictures they are made of.
##
## Three kinds, and they are not drawn on the car the same way, because they do
## not want the same thing from it.
##
## **Stripes** are worn in the model's own texture space: one mask per shape,
## hung on the paint material as an extra pass. A stripe has to follow the
## body's curve to look like paint rather than like a sticker, and the only
## thing that knows where the body's curve is, is the model's own unwrap. The
## cost is that a model with no sensible unwrap gets a stripe somewhere
## arbitrary - which is the bargain the design took knowingly, because the
## stock car is the car nearly everyone will decorate and its unwrap is fine.
##
## **Stickers and hand-written words** are projected onto the car from beside
## it, as `Decal` nodes, and need no unwrap at all. They are the kinds a player
## places, and a placed thing has to land where it was put on any model at all,
## including one exported out of Blender by somebody who had never heard of a
## UV.
##
## Everything here is drawn white with an alpha shape and coloured elsewhere -
## by the pass's `albedo_color` for a stripe, by the decal's `modulate` for the
## rest. That is what makes the chaos cycle free: a colour that turns every
## frame is a property being set, not a picture being drawn again.
##
## The pictures are built the first time they are asked for and kept. There are
## eleven fixed ones in the whole game and they never change; a scrawl is the
## only picture drawn per car, and it is drawn when a player finishes drawing
## it rather than while they are.

## The three kinds of decoration. Kept here rather than on `Decals` so that
## nothing in this file names an autoload: it is a table of shapes, like
## `Paints` and `Shop`, and a table a `--script` check can read without having
## to stand the game up first.
const STRIPE := "stripe"
const STICKER := "sticker"
const SCRAWL := "scrawl"

## The stripe shapes, in the order they are offered.
const STRIPES: Array[String] = ["CENTRE", "TWIN", "FLASH", "BONNET"]
## The stickers the game ships. The three numbers are drawn as segments rather
## than set in the game's font on purpose: a racing number is a shape, and the
## menu font is the game talking.
const STICKERS: Array[String] = [
	"ONE", "TWO", "THREE", "FLAME", "STAR", "ARROW", "CHEQUER",
]

## How big each kind of picture is drawn. A stripe mask is stretched over a
## whole car's unwrap, so it is the biggest; a sticker is a shape a few inches
## across on a door and 128 is already more than a decal projection resolves.
const STRIPE_SIZE := 256
const STAMP_SIZE := 128
const SCRAWL_SIZE := 256

## How wide the pen draws, as a fraction of the word's own box, for a word
## that does not say. Every word written before the pen had a choice of widths
## says nothing, and is drawn with this - so it comes out exactly as it did.
##
## A word written now carries its own `pen`, worked out from the width the
## player picked and the size of the box the word ended up in. The width is
## picked as a fraction of the car and kept as a fraction of the box because
## the first is what a player chooses - a line as thick on the door as the one
## they were drawing - and the second is what a mark is: made bigger with the
## SIZE slider, its lines get thicker with it, the way a sticker's do.
const PEN := 0.035
## The thinnest and fattest a word's pen may be, as a fraction of its box. Wide
## enough apart for every width the page offers on every size of word, and
## there so that a pen read from a file somebody wrote by hand is still a line.
const PEN_LEAST := 0.004
const PEN_MOST := 0.45

## How much of a car may be covered, all three kinds added together.
##
## A third. Two cars in one model are told apart by their paint and by nothing
## else, and a sticker big enough to cover most of a body is a sticker that
## makes a split screen unreadable - which is exactly what the paint screen
## refuses to allow when it will not let both players take one colour
## ([scripts/paint_menu.gd](paint_menu.gd)). Decoration must not undo that from
## the other side. A third leaves two thirds of every car still wearing the
## colour that says whose it is.
const COVER_CAP := 0.34

## How many marks one decoration may carry. The cap above is the real limit;
## this is the one that stops a player putting four hundred tiny stickers on a
## car and making the game build four hundred decals to draw them.
const MARKS_LIMIT := 8

## Built once and kept: `ImageTexture`s by shape, and how much of what they are
## drawn on each one covers.
static var _stripe_masks := {}
static var _stripe_cover := {}
static var _stamps := {}
static var _stamp_cover := {}

## The hand-written words drawn so far, by the strokes they were drawn from.
##
## Kept for two reasons, and the second one is not an optimisation. A scrawl is
## drawn from its points every time it is asked for, so a page that redraws
## while a player drags a word about would rasterise it again per redraw. And
## an `ImageTexture` built inside a `_draw` and handed straight to
## `draw_texture_rect` is a texture nothing holds a reference to: it is freed
## before the frame it was drawn into reaches the screen, and what arrives is a
## flat rectangle of the modulate colour. Keeping it here is what keeps it
## alive long enough to be drawn.
static var _scrawls := {}
## How many words to keep. Two players carrying eight marks each is sixteen,
## and this is comfortably over that - so everything on the screen at once
## stays in hand, and a session of trying words out does not grow without
## bound.
const SCRAWLS_KEPT := 24


# --- what there is ------------------------------------------------------

static func stripe_name(shape: int) -> String:
	return STRIPES[clampi(shape, 0, STRIPES.size() - 1)]


static func sticker_name(shape: int) -> String:
	return STICKERS[clampi(shape, 0, STICKERS.size() - 1)]


# --- the pictures -------------------------------------------------------

## The mask for one stripe shape, in the model's texture space.
static func stripe_mask(shape: int) -> ImageTexture:
	shape = clampi(shape, 0, STRIPES.size() - 1)
	if not _stripe_masks.has(shape):
		var image := _blank(STRIPE_SIZE)
		_draw_stripe(image, shape)
		_stripe_masks[shape] = ImageTexture.create_from_image(image)
		_stripe_cover[shape] = _opaque_fraction(image)
	return _stripe_masks[shape]


## The picture for one sticker, white with an alpha shape.
static func sticker_stamp(shape: int) -> ImageTexture:
	shape = clampi(shape, 0, STICKERS.size() - 1)
	if not _stamps.has(shape):
		var image := _blank(STAMP_SIZE)
		_draw_sticker(image, shape)
		_stamps[shape] = ImageTexture.create_from_image(image)
		_stamp_cover[shape] = _opaque_fraction(image)
	return _stamps[shape]


## The picture for one hand-written word: the strokes as they were drawn,
## stamped out at whatever size the car wants them.
##
## Drawn from the points rather than stored as a picture, because that is how
## a scrawl is kept: a few hundred numbers that can be drawn again at whatever
## size the car wants. What is kept here is the drawing, against the points it
## came from and the width of the pen - see `_scrawls`.
static func scrawl_stamp(strokes: Array, pen: float = PEN) -> ImageTexture:
	pen = clampf(pen, PEN_LEAST, PEN_MOST)
	var key := var_to_str([strokes, pen])
	if _scrawls.has(key):
		return _scrawls[key]
	var image := _blank(SCRAWL_SIZE)
	# Never under a pixel across, which is a line the filtering loses.
	var radius := maxf(pen * float(SCRAWL_SIZE) * 0.5, 1.0)
	for stroke in strokes:
		var points: PackedVector2Array = stroke
		if points.size() == 1:
			_disc(image, points[0] * float(SCRAWL_SIZE), radius)
			continue
		for i in range(1, points.size()):
			_line(image, points[i - 1] * float(SCRAWL_SIZE),
				points[i] * float(SCRAWL_SIZE), radius)
	var drawn := ImageTexture.create_from_image(image)
	# Oldest out first. A dictionary keeps the order things were put in it, so
	# the first key is the word least recently drawn for the first time.
	if _scrawls.size() >= SCRAWLS_KEPT:
		_scrawls.erase(_scrawls.keys()[0])
	_scrawls[key] = drawn
	return drawn


## A stroke with the points taken out that the line would be drawn through
## anyway: none of what is left is further than `tolerance` from the line the
## pen actually took, and what goes is everything that only said "and on in
## the same direction".
##
## The pen is read once per movement of the mouse, so a word as it comes off
## the car is hundreds of points a hair apart, the same point twice when the
## mouse did not move, and a whole straight line spelled out a pixel at a time.
## Kept like that, one word is too long to be written down as a livery at all
## (`Livery.TEXT_LIMIT`). Thinned to a pixel of the picture it is drawn into
## (`SCRAWL_SIZE`), a curve keeps the points that bend it and a straight keeps
## its two ends: a word of five hundred points comes down to a few dozen, and
## the only pixels that change are the soft ones along the edge of the line.
##
## Thinning what is already thin takes nothing more out - every point it kept
## is still the furthest from the line between its neighbours - so a word can
## be put through here every time it is loaded without wearing away.
static func thinned(points: PackedVector2Array, tolerance: float) -> PackedVector2Array:
	if points.size() < 3:
		return points
	var keep := PackedByteArray()
	keep.resize(points.size())
	keep.fill(0)
	keep[0] = 1
	keep[points.size() - 1] = 1
	# Douglas-Peucker, with a list of spans still to look at rather than
	# recursion, since a long stroke is thousands of points deep.
	var spans: Array[Vector2i] = [Vector2i(0, points.size() - 1)]
	while not spans.is_empty():
		var span: Vector2i = spans.pop_back()
		var from := points[span.x]
		var to := points[span.y]
		var furthest := -1.0
		var at := -1
		for i in range(span.x + 1, span.y):
			var gap := _off_the_line(points[i], from, to)
			if gap > furthest:
				furthest = gap
				at = i
		if at >= 0 and furthest > tolerance:
			keep[at] = 1
			spans.append(Vector2i(span.x, at))
			spans.append(Vector2i(at, span.y))
	var out := PackedVector2Array()
	for i in points.size():
		if keep[i] == 1:
			out.append(points[i])
	# A dot is one point drawn as a disc, and a dot the mouse wobbled on is
	# two points on top of each other: kept as one.
	if out.size() == 2 and out[0].distance_to(out[1]) <= tolerance:
		out.resize(1)
	return out


## A mark with its word's strokes thinned to a pixel of `SCRAWL_SIZE`, and
## anything that is not a word handed back as it came.
static func thinned_word(mark: Dictionary) -> Dictionary:
	if str(mark.get("kind", "")) != SCRAWL:
		return mark
	var out := mark.duplicate()
	var strokes := []
	for stroke: PackedVector2Array in mark.get("strokes", []):
		strokes.append(thinned(stroke, 1.0 / float(SCRAWL_SIZE)))
	out["strokes"] = strokes
	return out


static func _off_the_line(point: Vector2, from: Vector2, to: Vector2) -> float:
	var along := to - from
	var length := along.length_squared()
	if length < 0.0000001:
		return point.distance_to(from)
	var t := clampf((point - from).dot(along) / length, 0.0, 1.0)
	return point.distance_to(from + along * t)


# --- how much of the car a thing covers ---------------------------------

## How much of the car one mark covers, 0 to 1.
##
## The three kinds are measured in spaces that are not the same space - a
## stripe covers a fraction of the model's unwrap and a sticker covers a
## fraction of the car's flank - and they are added together anyway. The number
## is a budget rather than a measurement: what it is for is stopping a car
## disappearing under decoration, and both fractions grow when that is
## happening. Pretending it is an area would be pretending the game knows the
## shape of a model it has never seen.
static func cover_of(mark: Dictionary) -> float:
	match str(mark.get("kind", "")):
		STRIPE:
			var shape := int(mark.get("shape", 0))
			stripe_mask(shape)
			return float(_stripe_cover.get(shape, 0.0))
		STICKER:
			var shape := int(mark.get("shape", 0))
			sticker_stamp(shape)
			var span := clampf(float(mark.get("size", 0.2)), 0.0, 1.0)
			return float(_stamp_cover.get(shape, 0.0)) * span * span
		SCRAWL:
			var span := clampf(float(mark.get("size", 0.3)), 0.0, 1.0)
			return _scrawl_cover(mark.get("strokes", []),
				float(mark.get("pen", PEN))) * span * span
	return 0.0


## How much of the car a whole decoration covers.
static func cover_of_all(marks: Array) -> float:
	var total := 0.0
	for mark: Dictionary in marks:
		total += cover_of(mark)
	return total


## How much of its own box a scrawl fills, worked out from how far the pen
## travelled rather than by counting pixels.
##
## It over-counts a stroke drawn back over itself, and that is the right way to
## be wrong: the number is a cap, and a cap that guesses high refuses a
## decoration that would have been allowed, while one that guesses low lets a
## car vanish. Counting the pixels would mean reading a whole image back every
## time the player moved the mouse. A fatter pen covers more of the same path,
## so the width is in it too.
static func _scrawl_cover(strokes: Array, pen: float) -> float:
	var travelled := 0.0
	for stroke in strokes:
		var points: PackedVector2Array = stroke
		for i in range(1, points.size()):
			travelled += points[i - 1].distance_to(points[i])
	return minf(travelled * clampf(pen, PEN_LEAST, PEN_MOST), 1.0)


# --- drawing ------------------------------------------------------------

## A square of nothing to draw a shape into. White throughout, so a shape is
## made by giving pixels their alpha and the colour is somebody else's business
## entirely.
static func _blank(size: int) -> Image:
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))
	return image


## Every stripe is a band, and every band is a run of rows with a left and a
## right edge - which is what lets all four be drawn by filling whole rows
## rather than by asking a question per pixel.
static func _draw_stripe(image: Image, shape: int) -> void:
	var size := image.get_width()
	match shape:
		0:  # CENTRE: one band down the middle.
			_band(image, 0.455, 0.545)
		1:  # TWIN: a pair either side of it.
			_band(image, 0.355, 0.425)
			_band(image, 0.575, 0.645)
		2:  # FLASH: a band that leans, so it reads as a flash along a flank
			# rather than as a second centre stripe.
			for y in size:
				var along := float(y) / float(size - 1)
				var middle := 0.18 + 0.64 * along
				_row(image, y, middle - 0.055, middle + 0.055)
		3:  # BONNET: a band the other way round.
			for y in size:
				var along := float(y) / float(size - 1)
				if along >= 0.30 and along <= 0.40:
					_row(image, y, 0.0, 1.0)


static func _band(image: Image, from: float, to: float) -> void:
	for y in image.get_width():
		_row(image, y, from, to)


## One row of a shape, from one fraction across to another.
static func _row(image: Image, y: int, from: float, to: float) -> void:
	var size := image.get_width()
	var left := clampi(int(round(from * float(size))), 0, size)
	var right := clampi(int(round(to * float(size))), 0, size)
	if right <= left:
		return
	image.fill_rect(Rect2i(left, y, right - left, 1), Color(1.0, 1.0, 1.0, 1.0))


static func _draw_sticker(image: Image, shape: int) -> void:
	match shape:
		0:
			# A one is the right-hand pair and nothing else.
			_digit(image, [false, true, true, false, false, false, false])
		1:
			_digit(image, [true, true, false, true, true, false, true])
		2:
			_digit(image, [true, true, true, true, false, false, true])
		3:
			_polygon(image, PackedVector2Array([
				Vector2(0.50, 0.03), Vector2(0.65, 0.27), Vector2(0.71, 0.20),
				Vector2(0.79, 0.47), Vector2(0.73, 0.72), Vector2(0.58, 0.93),
				Vector2(0.39, 0.97), Vector2(0.23, 0.81), Vector2(0.21, 0.56),
				Vector2(0.33, 0.36), Vector2(0.37, 0.53), Vector2(0.43, 0.28),
			]))
		4:
			_polygon(image, _star())
		5:
			_polygon(image, PackedVector2Array([
				Vector2(0.04, 0.36), Vector2(0.54, 0.36), Vector2(0.54, 0.16),
				Vector2(0.96, 0.50), Vector2(0.54, 0.84), Vector2(0.54, 0.64),
				Vector2(0.04, 0.64),
			]))
		6:
			_chequer(image, 4)


## The seven segments of a number, lit in the pattern asked for: top, top
## right, bottom right, bottom, bottom left, top left, middle.
static func _digit(image: Image, lit: Array) -> void:
	var left := 0.30
	var right := 0.70
	var top := 0.10
	var bottom := 0.90
	var middle := (top + bottom) * 0.5
	var thick := 0.10
	if lit[0]:
		_rect(image, left, top, right, top + thick)
	if lit[1]:
		_rect(image, right - thick, top, right, middle + thick * 0.5)
	if lit[2]:
		_rect(image, right - thick, middle - thick * 0.5, right, bottom)
	if lit[3]:
		_rect(image, left, bottom - thick, right, bottom)
	if lit[4]:
		_rect(image, left, middle - thick * 0.5, left + thick, bottom)
	if lit[5]:
		_rect(image, left, top, left + thick, middle + thick * 0.5)
	if lit[6]:
		_rect(image, left, middle - thick * 0.5, right, middle + thick * 0.5)


static func _rect(image: Image, left: float, top: float, right: float,
		bottom: float) -> void:
	var size := image.get_width()
	var from := clampi(int(round(top * float(size))), 0, size - 1)
	var to := clampi(int(round(bottom * float(size))), 0, size)
	for y in range(from, to):
		_row(image, y, left, right)


## A chequered flag: a grid of squares with every other one filled.
static func _chequer(image: Image, squares: int) -> void:
	var step := 1.0 / float(squares)
	for down in squares:
		for across in squares:
			if (down + across) % 2 == 1:
				continue
			_rect(image, float(across) * step, float(down) * step,
				float(across + 1) * step, float(down + 1) * step)


## Anything that is not a band or a box, asked a pixel at a time.
##
## Slow, and it does not matter: there are three of these in the game, each is
## drawn once ever, and the answer is kept for as long as the game is running.
static func _polygon(image: Image, points: PackedVector2Array) -> void:
	var size := image.get_width()
	for y in size:
		for x in size:
			var at := Vector2(
				(float(x) + 0.5) / float(size), (float(y) + 0.5) / float(size))
			if Geometry2D.is_point_in_polygon(at, points):
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))


static func _star() -> PackedVector2Array:
	var points := PackedVector2Array()
	for step in 10:
		var radius := 0.47 if step % 2 == 0 else 0.20
		var angle := -PI * 0.5 + float(step) * PI / 5.0
		points.append(Vector2(0.5, 0.5) + Vector2(cos(angle), sin(angle)) * radius)
	return points


## A round pen nib, stamped. Rows again: a circle is a left and a right edge
## per row like everything else here.
static func _disc(image: Image, at: Vector2, radius: float) -> void:
	var size := image.get_width()
	var top := clampi(int(at.y - radius), 0, size - 1)
	var bottom := clampi(int(ceil(at.y + radius)), 0, size - 1)
	for y in range(top, bottom + 1):
		var down := (float(y) + 0.5) - at.y
		var half := sqrt(maxf(radius * radius - down * down, 0.0))
		if half <= 0.0:
			continue
		var left := clampi(int(at.x - half), 0, size)
		var right := clampi(int(ceil(at.x + half)), 0, size)
		if right > left:
			image.fill_rect(Rect2i(left, y, right - left, 1),
				Color(1.0, 1.0, 1.0, 1.0))


## One stroke between two points, stamped nib by nib. Half a nib apart, so a
## fast flick of the mouse comes out as a line rather than as a row of dots.
static func _line(image: Image, from: Vector2, to: Vector2, radius: float) -> void:
	var span := from.distance_to(to)
	var steps := maxi(int(span / maxf(radius * 0.5, 0.5)), 1)
	for step in steps + 1:
		_disc(image, from.lerp(to, float(step) / float(steps)), radius)


## How much of a picture is actually drawn on. Counted once, when the picture
## is built, and kept beside it.
static func _opaque_fraction(image: Image) -> float:
	var drawn := 0
	var size := image.get_width()
	for y in size:
		for x in size:
			if image.get_pixel(x, y).a > 0.5:
				drawn += 1
	return float(drawn) / float(size * size)


# --- what a mark may be ------------------------------------------------

## Take a mark as it arrives and hand back one the game can draw, or nothing
## at all for something that is not a mark.
##
## Everything that comes in goes through here - from the screen, and from the
## file. The file is the player's own and there is nothing in it worth
## protecting, but it is also a file an older build wrote, and a shape number
## that has since been taken out of the list would otherwise be a car that
## cannot be drawn.
static func tidy(mark: Dictionary) -> Dictionary:
	var kind := str(mark.get("kind", ""))
	var shapes := 0
	match kind:
		STRIPE:
			shapes = DecalArt.STRIPES.size()
		STICKER:
			shapes = DecalArt.STICKERS.size()
		SCRAWL:
			shapes = 1
		_:
			return {}
	var clean := {
		"kind": kind,
		"shape": clampi(int(mark.get("shape", 0)), 0, shapes - 1),
		# The free twelve only. The six the shop sells are paint, and a stripe
		# in one would be a way of wearing a colour without buying it.
		"colour": clampi(int(mark.get("colour", 0)), 0, Paints.FREE - 1),
		# Which part of the car it is on. A stripe is not on a part of the car
		# at all - it is worn in the model's own texture space and goes
		# wherever the unwrap sends it - so it is always the flanks, which is
		# the nothing-in-particular value, and never writes a face down.
		"face": CarFaces.FLANKS if kind == STRIPE \
			else clampi(int(mark.get("face", CarFaces.FLANKS)), 0, CarFaces.COUNT - 1),
		"at": _inside(mark.get("at", Vector2(0.5, 0.5))),
		"size": clampf(float(mark.get("size", 0.28)), 0.08, 1.0),
		"turn": wrapf(float(mark.get("turn", 0.0)), -PI, PI),
	}
	# Put on the body rather than on a face (see `CarFaces.on_the_body`). The
	# face and the place on it are worked out from where it is, never taken
	# from the mark, so the two cannot disagree - and every drawing of a design
	# that still thinks in faces has one to draw it on.
	if kind != STRIPE and CarFaces.on_the_body(mark):
		var spot: Vector3 = mark.spot
		spot = Vector3(clampf(spot.x, 0.0, 1.0), clampf(spot.y, 0.0, 1.0),
			clampf(spot.z, 0.0, 1.0))
		var aim: Vector3 = mark.aim
		# Only put right when it is wrong. An aim read back off four decimals
		# is a hair off unit length, and making it exactly one would move its
		# last digit - which is a different livery id for the same design.
		if aim.length() < 0.001:
			aim = Vector3.RIGHT
		elif absf(aim.length() - 1.0) > 0.001:
			aim = aim.normalized()
		clean["spot"] = spot
		clean["aim"] = aim
		clean["face"] = CarFaces.face_of_aim(aim)
		clean["at"] = CarFaces.at_of_spot(spot, int(clean.face))
		# Kept only when it is off, so a mark on both doors - which is every
		# mark there was before the choice - is the same mark it always was.
		# Kept whatever face it is on, because the mirror is about the mark
		# and not the panel: a sticker put on the bonnet with the mirror off
		# and dragged onto a door is on that door alone. See
		# `CarFaces.mirrored`.
		if not bool(mark.get("mirror", true)):
			clean["mirror"] = false
	if kind == SCRAWL:
		var strokes := _tidy_strokes(mark.get("strokes", []))
		if strokes.is_empty():
			# A word with nothing written in it is not a word. Refused rather
			# than kept as an empty mark, which would be a decal drawing
			# nothing and a slot out of the eight spent on it.
			return {}
		clean["strokes"] = strokes
		clean["pen"] = clampf(float(mark.get("pen", PEN)), PEN_LEAST, PEN_MOST)
	return clean


## The pen's path, as points inside the box it was drawn in.
static func _tidy_strokes(strokes: Variant) -> Array:
	var out := []
	if not (strokes is Array):
		return out
	for stroke in strokes:
		var points := PackedVector2Array()
		if stroke is PackedVector2Array or stroke is Array:
			for point in stroke:
				if point is Vector2:
					points.append(_inside(point))
		if not points.is_empty():
			out.append(points)
	return out


static func _inside(at: Variant) -> Vector2:
	if not (at is Vector2):
		return Vector2(0.5, 0.5)
	var point: Vector2 = at
	return Vector2(clampf(point.x, 0.0, 1.0), clampf(point.y, 0.0, 1.0))


# --- a design, flat ------------------------------------------------------

## The silhouette a design is shown against, as fractions of whatever box it is
## drawn in. Nose to the left.
##
## A drawn outline rather than a picture of the model, because the model might
## be anything at all - the point of projecting stickers rather than painting
## them into a texture is that a car the game has never seen still wears them.
## A shape everybody reads as a car is enough to say "the front is this end and
## the roof is up there", which is the whole of what is being decided.
const BODY: Array[Vector2] = [
	Vector2(0.05, 0.70), Vector2(0.08, 0.50), Vector2(0.26, 0.44),
	Vector2(0.38, 0.22), Vector2(0.64, 0.20), Vector2(0.76, 0.44),
	Vector2(0.94, 0.50), Vector2(0.96, 0.70), Vector2(0.05, 0.70),
]
const WHEELS: Array[Vector2] = [Vector2(0.24, 0.72), Vector2(0.76, 0.72)]


## Draw a decoration on the flat side of a car, in a box of `span`.
##
## What a saved livery's row in the garage puts up, and the only picture of a
## design there is that is not the car itself. It used to be the page a design
## was made on as well; that page is the model now
## ([scripts/decoration_page.gd](decoration_page.gd)), which leaves this doing
## the one job it was always better at - being small, flat and recognisable in
## a list.
##
## It is a schematic and not a promise, and it was always one. A stripe is
## drawn as a band across the silhouette, where on the car it is worn in the
## model's own texture space and goes wherever the unwrap sends it; a mark on
## the roof, the nose or the tail is drawn at the edge of the silhouette those
## belong to, since a flat side has none of them. What this has to say is which
## design it is, and that is all that is ever asked of it: the car in the
## garage is the truth.
static func draw_side(into: CanvasItem, span: Vector2, paint: Color,
		marks: Array) -> void:
	# A control draws once before its container has given it a size, and a
	# polygon with no area in it is an engine complaint rather than a picture.
	if span.x < 1.0 or span.y < 1.0:
		return
	var shape := PackedVector2Array()
	for point in BODY:
		shape.append(point * span)
	into.draw_colored_polygon(shape, paint)
	for mark: Dictionary in marks:
		if str(mark.get("kind", "")) == STRIPE:
			_draw_stripe_over(into, span, mark)
	for wheel in WHEELS:
		into.draw_circle(wheel * span, span.y * 0.085, Color(0.1, 0.11, 0.14))
	for mark: Dictionary in marks:
		if str(mark.get("kind", "")) != STRIPE:
			draw_mark(into, span, mark)


## One placed mark - a sticker or a hand-written word - where it sits, turned
## the way it was turned and in the colour it was drawn in.
##
## Turned the other way round from the number in the mark, because this picture
## is the car's left flank - the nose is at the left, which is the end the nose
## is at from over there - and on a flank the car turns a mark the opposite way
## round from a page with its y pointing down. The turn a player set is a turn
## of the thing on the car; this is the drawing agreeing with it.
static func draw_mark(into: CanvasItem, span: Vector2, mark: Dictionary) -> void:
	var picture := picture_of(mark)
	if picture == null:
		return
	var wide := mark_span(mark, span)
	into.draw_set_transform(where_on_the_side(mark) * span,
		-float(mark.get("turn", 0.0)), Vector2.ONE)
	into.draw_texture_rect(picture,
		Rect2(-Vector2(wide, wide) * 0.5, Vector2(wide, wide)), false,
		Paints.colour(int(mark.get("colour", 0))))
	into.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where on the flat side of the car a mark is drawn, as fractions of the box.
##
## A mark on the flanks is where it says it is: this picture is a flank. The
## other three faces are not in this picture at all, and they are drawn at the
## edge of the silhouette they belong to - along the roof, off the nose, off
## the tail - so a design made of them is still a design somebody can pick out
## of a row of them. It is a schematic, the way the stripes here are: the car
## in the garage is the truth, and what this has to say is only which design
## this is.
static func where_on_the_side(mark: Dictionary) -> Vector2:
	var at: Vector2 = mark.get("at", Vector2(0.5, 0.5))
	match int(mark.get("face", CarFaces.FLANKS)):
		CarFaces.TOP:
			return Vector2(at.x, ROOF)
		CarFaces.NOSE:
			return Vector2(0.09, lerpf(0.46, 0.66, at.y))
		CarFaces.TAIL:
			return Vector2(0.92, lerpf(0.46, 0.66, at.y))
	return at


## Where the roofline of the silhouette is, for a mark worn on top of the car.
const ROOF := 0.26


## How wide a mark is drawn. Its size is a fraction of the car's length, and
## the box is the car's length across, so one is the other.
static func mark_span(mark: Dictionary, span: Vector2) -> float:
	return clampf(float(mark.get("size", 0.28)), 0.08, 1.0) * span.x


## The picture a placed mark wears.
static func picture_of(mark: Dictionary) -> Texture2D:
	if str(mark.get("kind", "")) == SCRAWL:
		return scrawl_stamp(mark.get("strokes", []), float(mark.get("pen", PEN)))
	return sticker_stamp(int(mark.get("shape", 0)))


## A stripe, laid over the silhouette rather than over the whole box, so it
## reads as paint on the car instead of as a line ruled across the page.
static func _draw_stripe_over(into: CanvasItem, span: Vector2,
		mark: Dictionary) -> void:
	var colour := Paints.colour(int(mark.get("colour", 0)))
	var top := 0.20 * span.y
	var bottom := 0.70 * span.y
	match int(mark.get("shape", 0)):
		0:
			_band_over(into, span, 0.44, 0.56, top, bottom, colour)
		1:
			_band_over(into, span, 0.34, 0.41, top, bottom, colour)
			_band_over(into, span, 0.59, 0.66, top, bottom, colour)
		2:
			# The flash leans, which is the whole of what makes it a flash.
			var flash := PackedVector2Array([
				Vector2(0.09, 0.68), Vector2(0.34, 0.45), Vector2(0.45, 0.45),
				Vector2(0.20, 0.68),
			])
			var points := PackedVector2Array()
			for point in flash:
				points.append(point * span)
			into.draw_colored_polygon(points, colour)
		3:
			# A band the other way round. Kept inside the waist of the
			# silhouette, where the body is at its full height at both ends.
			_band_over(into, span, 0.08, 0.94, 0.56 * span.y, 0.64 * span.y, colour)


static func _band_over(into: CanvasItem, span: Vector2, from: float, to: float,
		top: float, bottom: float, colour: Color) -> void:
	into.draw_rect(Rect2(from * span.x, top, (to - from) * span.x, bottom - top),
		colour)
