class_name CarFaces
extends RefCounted

## Where a placed mark is on a car: on the body, or on one of the four faces of
## the box round it that marks were put on before there was a body to put them
## on.
##
## A sticker or a hand-written word is projected onto the car from outside it
## ([scripts/decal_art.gd](decal_art.gd)). It used to be projected at a face of
## the box the model measures, on the grounds that the box is the one thing
## every model has; a mark is now put where it lands on the bodywork itself and
## thrown back along the way the body faces there - see `on_the_body` at the
## bottom - because a bonnet is not a face of any box. The faces stay: they are
## what a mark saved before is on, what a design is drawn flat against, and
## the nearest thing to a mark on the body that a copy of the game from before
## the body can draw.
##
## Four faces, because the five sides of a car worth drawing on are the two
## flanks, the top and the two ends, and the two flanks are one face: a mark on
## a door is on both doors, the way a racing number is. The underside is not a
## face. Nobody looks at it, and a player who turned the car over to draw on it
## would be spending the cap on something no other player will ever see.
##
## Everything here is geometry and nothing here is a picture, which is why it
## is not in `DecalArt`: the shell puts decals where `placements` says, the
## garage rings a selected mark and works out what a press landed on from the
## same answer, and none of them should be holding its own idea of where a
## door is. It names no autoload, so a `--script` check can do the arithmetic
## without standing the game up.

## The faces, in the order they are offered.
const FLANKS := 0
const TOP := 1
const NOSE := 2
const TAIL := 3

## What each is called, for a status line to say out loud.
const NAMES: Array[String] = ["THE SIDES", "THE TOP", "THE NOSE", "THE TAIL"]
const COUNT := 4


static func name_of(face: int) -> String:
	return NAMES[clampi(face, 0, COUNT - 1)]


## Which sides of the car a face has: both flanks, or the one there is.
##
## The flanks are one face wearing two decals, because a decal throws its
## picture one way only and a number on a door is on both doors. They are
## mirror images in the world and the same picture to look at, so a word reads
## the right way round from whichever side of the car you are standing.
static func sides(face: int) -> Array[int]:
	var both: Array[int] = [-1, 1]
	var one: Array[int] = [1]
	return both if face == FLANKS else one


## Where a face is, in the shell's own space, as everything anyone needs to put
## something on it:
##
## - `origin`, `across`, `down`: a mark's `at` is a fraction along two of the
##   car's own axes, so the point it names is `origin + across * at.x +
##   down * at.y`. In the car's own space rather than in the picture's, which
##   is what makes `at.x = 0` the nose on both flanks instead of the nose on
##   one and the tail on the other.
## - `out`: which way the face looks. A decal is aimed back along it.
## - `right`: which way is right in the picture that lands there. Not `across`:
##   on the right-hand flank the two are opposite, which is the mirroring that
##   makes a word read the same way round from either side.
## - `depth`: how deep the decal's box is. Half of the car across the axis the
##   face looks along, so the box reaches a quarter of the way in - far enough
##   to follow the curve of a door, never far enough to come out of the far
##   side backwards.
##
## `right`, `out` and `right.cross(out)` are the picture's right, its normal
## and its down, in that order, and they are what the decal's basis is built
## from. Every face is arranged so that the third really is down the picture.
static func plane(bounds: AABB, face: int, side: int = 1) -> Dictionary:
	var least := bounds.position
	var most := bounds.end
	var span := bounds.size
	match face:
		TOP:
			return {
				"origin": Vector3(least.x, most.y, least.z),
				"across": Vector3(0.0, 0.0, span.z),
				"down": Vector3(span.x, 0.0, 0.0),
				"out": Vector3.UP,
				# Up the picture is the nose, so a number on the roof reads
				# right way up to somebody the car is driving away from.
				"right": Vector3.RIGHT,
				"depth": maxf(span.y * 0.5, 0.2),
			}
		NOSE:
			return {
				"origin": Vector3(least.x, most.y, least.z),
				"across": Vector3(span.x, 0.0, 0.0),
				"down": Vector3(0.0, -span.y, 0.0),
				"out": Vector3.FORWARD,
				# Stand in front of a car and its left is on your right.
				"right": Vector3.LEFT,
				"depth": maxf(span.z * 0.35, 0.2),
			}
		TAIL:
			return {
				"origin": Vector3(least.x, most.y, most.z),
				"across": Vector3(span.x, 0.0, 0.0),
				"down": Vector3(0.0, -span.y, 0.0),
				"out": Vector3.BACK,
				"right": Vector3.RIGHT,
				"depth": maxf(span.z * 0.35, 0.2),
			}
	var here := most.x if side > 0 else least.x
	return {
		"origin": Vector3(here, most.y, least.z),
		"across": Vector3(0.0, 0.0, span.z),
		"down": Vector3(0.0, -span.y, 0.0),
		"out": Vector3(1.0 if side > 0 else -1.0, 0.0, 0.0),
		"right": Vector3(0.0, 0.0, -1.0 if side > 0 else 1.0),
		"depth": maxf(span.x * 0.5, 0.2),
	}


## The point a mark's `at` names, in the shell's own space.
static func point_of(bounds: AABB, face: int, side: int, at: Vector2) -> Vector3:
	var where := plane(bounds, face, side)
	return (where.origin as Vector3) + (where.across as Vector3) * at.x \
		+ (where.down as Vector3) * at.y


## And back again: which `at` a point on a face is, whether or not it is on it.
##
## Not clamped. A pen dragged off the edge of a door is a stroke that carries
## on past the edge, and clamping every point of it to the edge would pile the
## whole of the rest of the stroke up in a line along the door handle. Whoever
## asked decides what to do with a point that is off the face.
static func at_of(bounds: AABB, face: int, side: int, point: Vector3) -> Vector2:
	var where := plane(bounds, face, side)
	var along := point - (where.origin as Vector3)
	return Vector2(_fraction(along, where.across), _fraction(along, where.down))


static func _fraction(along: Vector3, axis: Vector3) -> float:
	var length := axis.length_squared()
	return 0.5 if length < 0.000001 else along.dot(axis) / length


## How big a mark is on the car, in metres. Always a fraction of the car's
## length, on every face, so a size means one thing wherever it is worn - a
## sticker moved from a door to the boot is the same sticker.
static func span_of(bounds: AABB, size: float) -> float:
	return maxf(bounds.size.z, 1.0) * clampf(size, 0.08, 1.0)


## Which face of a car somebody looking along `along` is looking at, as
## `{face, side}`.
##
## Where a sticker goes when it is pressed with nothing of the car in the
## middle of the view to put it on, so the question it has to answer is the
## player's: which panel am I looking at? Not which one
## is most squarely on, which is a different question with a worse answer. A
## car seen from off the front corner has its nose more squarely on than its
## flank and a quarter as much of it on the screen, and a sticker pressed there
## belongs on the door.
##
## So it is how much of each panel can be seen - how big it is, times how much
## of it the angle leaves - and a door beats a bumper until the car has very
## nearly been turned nose-on.
static func facing(bounds: AABB, along: Vector3) -> Dictionary:
	var best := {"face": FLANKS, "side": 1}
	var most := -INF
	for face in COUNT:
		for side in sides(face):
			var where := plane(bounds, face, side)
			var seen := (where.across as Vector3).cross(where.down as Vector3).length() \
				* maxf((where.out as Vector3).dot(-along), 0.0)
			if seen > most:
				most = seen
				best = {"face": face, "side": side}
	return best


# --- on the body itself -------------------------------------------------

## A mark put on the body rather than on a face: a point on the bodywork and
## the way the bodywork faces there.
##
## Faces were how everything was put on until a player tried to write on a
## bonnet. A bonnet is not the top of the box and not the front of it, and a
## decal thrown down from the roofline reached a quarter of the way into the
## car and stopped well short of it. So a mark is now put where the cursor
## actually meets the model - `spot`, as fractions of the box so it means the
## same place on a car of any size - and thrown back along the way the body
## faces there, `aim`. A word written across a bonnet is flat on the bonnet.
##
## The faces are still what a mark saved before this is on, and they are still
## how a design is drawn flat on a livery's tile and written for a copy of the
## game that has never heard of a body: every mark on the body is also given
## the face its `aim` is nearest (`face_of_aim`) and the place on that face it
## would be (`at`). A mark put on the body is worn on both sides of the car when
## that face is the flanks, the way a number on a door always was - unless it
## was put on with the mirror off (`mirrored`).
static func on_the_body(mark: Dictionary) -> bool:
	return mark.get("spot") is Vector3 and mark.get("aim") is Vector3


## Whether a mark on a door is on the other door as well.
##
## It is unless it says otherwise, so every mark made before there was a choice
## is on both doors, the way it always was. Only a mark on the body can say
## otherwise: a mark on one of the old faces has no side of its own to be on,
## so it is put on the body before it is told (`as_copy`).
static func mirrored(mark: Dictionary) -> bool:
	return not on_the_body(mark) or bool(mark.get("mirror", true))


## A mark as a mark on the body worn where its copy number `copy` is worn now,
## so that copy is the one it keeps if it is taken off the other door - the
## door a player took hold of rather than the one round the far side. A mark on
## one of the old faces is put on the body by it, because a face is both doors
## or neither. The first copy of a mark already on the body is the mark itself.
static func as_copy(bounds: AABB, mark: Dictionary, copy: int) -> Dictionary:
	if on_the_body(mark) and copy <= 0:
		return mark
	var found := placements(bounds, mark)
	var placement: Dictionary = found[clampi(copy, 0, found.size() - 1)]
	var moved := mark.duplicate(true)
	moved["spot"] = spot_of(bounds, placement.point)
	moved["aim"] = placement.out
	moved["turn"] = turn_for(placement.out, placement.right)
	return moved


## Which face a direction is nearest, never the underside - a mark on the lip
## under a bumper is on the nose, not on a fifth face nobody sees.
static func face_of_aim(aim: Vector3) -> int:
	var across := absf(aim.x)
	var along := absf(aim.z)
	if aim.y > 0.0 and aim.y >= across and aim.y >= along:
		return TOP
	if across >= along:
		return FLANKS
	return NOSE if aim.z < 0.0 else TAIL


## A point in the shell's own space as a `spot`, and back.
static func spot_of(bounds: AABB, point: Vector3) -> Vector3:
	var size := bounds.size
	var gap := point - bounds.position
	return Vector3(
		clampf(gap.x / size.x, 0.0, 1.0) if size.x > 0.000001 else 0.5,
		clampf(gap.y / size.y, 0.0, 1.0) if size.y > 0.000001 else 0.5,
		clampf(gap.z / size.z, 0.0, 1.0) if size.z > 0.000001 else 0.5)


static func point_at(bounds: AABB, spot: Vector3) -> Vector3:
	return bounds.position + spot * bounds.size


## Where on its nearest face a mark on the body would be, for everything that
## still thinks in faces. Worked out on a box one unit each way, because a
## `spot` is already fractions of the box.
static func at_of_spot(spot: Vector3, face: int) -> Vector2:
	var at := at_of(AABB(Vector3.ZERO, Vector3.ONE), face, 1, spot)
	return Vector2(clampf(at.x, 0.0, 1.0), clampf(at.y, 0.0, 1.0))


## Which way is right in a picture thrown along `aim`, before it is turned.
##
## The same as the face it is nearest wherever the two meet - out of the side
## of the car, right is towards the tail on one flank and the nose on the
## other, and looking down, right is the car's right - so a mark saved on a
## face and one put on the body agree about what a turn of nought is. There is
## no way of doing that without a seam somewhere between the nose and the roof,
## and nobody sees it, because a mark put on the body is turned to stand the
## way up the car was being looked at (`turn_for`).
static func reference_right(aim: Vector3) -> Vector3:
	var right := Vector3.UP.cross(aim) if absf(aim.y) < 0.9 \
		else Vector3.FORWARD.cross(aim)
	return right.normalized() if right.length_squared() > 0.000001 else Vector3.RIGHT


## The turn that points a picture thrown along `aim` with its right towards
## `right`, as near as the surface allows.
static func turn_for(aim: Vector3, right: Vector3) -> float:
	var zero := reference_right(aim)
	return atan2(right.dot(aim.cross(zero)), right.dot(zero))


## Where a mark actually is on the car, as one entry per decal it is worn as:
## `point` in the middle of it, `out` the way it is thrown back along, `right`
## the way its picture's right points once it is turned, `half` of how wide it
## is and `depth` how deep its box reaches.
##
## The one answer to where a mark is, for the shell that puts the decals on,
## for the ring drawn round a selected one and for a press working out whether
## it landed on one - so none of them can have its own idea of it.
static func placements(bounds: AABB, mark: Dictionary) -> Array:
	var turn := float(mark.get("turn", 0.0))
	var half := span_of(bounds, float(mark.get("size", 0.28))) * 0.5
	var found := []
	if not on_the_body(mark):
		var face := int(mark.get("face", FLANKS))
		var at: Vector2 = mark.get("at", Vector2(0.5, 0.5))
		for side in sides(face):
			var where := plane(bounds, face, side)
			var out: Vector3 = where.out
			found.append({
				"point": point_of(bounds, face, side, at), "out": out,
				"right": (where.right as Vector3).rotated(out, turn),
				"half": half, "depth": float(where.depth),
			})
		return found
	var aim: Vector3 = (mark.aim as Vector3).normalized()
	var point := point_at(bounds, mark.spot as Vector3)
	var face := face_of_aim(aim)
	# Centred on the bodywork rather than on the box, so it reaches as far in
	# as out: as deep as the mark is wide, to follow the curve under it, and
	# never deeper than the face's own box - which is what keeps a word on one
	# door from coming out backwards on the other.
	var depth := minf(float(plane(bounds, face).depth), maxf(half * 2.0, 0.3))
	var aims := [aim]
	var points := [point]
	if face == FLANKS and mirrored(mark):
		aims.append(Vector3(-aim.x, aim.y, aim.z))
		points.append(Vector3(bounds.position.x * 2.0 + bounds.size.x - point.x,
			point.y, point.z))
	for i in aims.size():
		var out: Vector3 = aims[i]
		found.append({
			"point": points[i], "out": out,
			"right": reference_right(out).rotated(out, turn),
			"half": half, "depth": depth,
		})
	return found


## Whether a point on the car is inside one placement of a mark, measured in
## the mark's own square - so a turned sticker is picked up by where it looks
## like it is - and within the reach of its box.
static func holds(placement: Dictionary, point: Vector3) -> bool:
	var out: Vector3 = placement.out
	var right: Vector3 = placement.right
	var down := right.cross(out)
	var gap := point - (placement.point as Vector3)
	var half := float(placement.half)
	return absf(gap.dot(right)) <= half and absf(gap.dot(down)) <= half \
		and absf(gap.dot(out)) <= float(placement.depth) * 0.5
