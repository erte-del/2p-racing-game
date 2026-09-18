class_name TrackDefinition
extends RefCounted

## A track laid out by hand rather than rolled from a seed.
##
## A track file describes itself by building itself: it calls straight(),
## corner(), climb() and jump() in the order a car meets them, and drops pads
## and barriers wherever the road has got to. That is why there is no offset
## argument anywhere below - furniture goes down at the distance the road has
## reached, so a track file reads as a description of driving the track rather
## than as a table of numbers with distances in the first column.
##
## Splitting a piece to make room for furniture costs nothing. Two straights in
## a row sample exactly as one straight of their combined length, so
##
##     straight(40.0)
##     pad(-0.6)
##     straight(50.0)
##
## is the same road as a single ninety metre straight with a pad forty metres
## along it.
##
## What comes out is the same Piece chain the generator produces and the same
## Placement list the planner produces, so everything downstream - the road
## mesh, the curve, the offsets, the rails, the embankment, the checks - does
## not know or care that a track was written down instead of rolled.

## Shown on the track select screen and in the saved times.
var track_name := "Unnamed"
## A sentence about what the track is for, for the same places.
var blurb := ""

## What a lap of this track is worth: gold, silver and bronze, in seconds.
## Set by the track file with medals(), because what counts as a good lap is a
## fact about this road and not a number that could be worked out from one.
## Left at zero on a track that has none.
var targets := Vector3.ZERO

## The road, in the order it is driven.
var pieces: Array[TrackLayout.Piece] = []
## Everything standing on it.
var placements: Array[TrackFeatures.Placement] = []

## Sampling distance. Every piece is rounded to a whole number of these as it
## is added, so the distances furniture is placed at are the distances it ends
## up at rather than distances that drift a metre per piece.
##
## This and the three jump lengths below are set by Track before describe() is
## called, so a track file never names them and every jump in the game is the
## same jump: a player who has cleared one knows what the next one asks.
var step := 2.5
var ramp_length := 15.0
var ramp_rise := 5.0
var jump_gap := 17.0
var landing_length := 90.0
## How big a ring is and how high the one over a jump stands, set by Track for
## the same reason: a player who has flown through one ring knows what the next
## one asks.
var ring_radius := 3.5
var jump_ring_height := 6.8
## Where a platform stands in its hole, how long it is, the drop off its far
## end to the landing, and how high its top is above the road the jump was
## built from. Set by Track, for the reason the jump lengths are.
var platform_start := 18.0
var platform_length := 30.0
var platform_drop := 9.0
var platform_height := 4.0
## How long a lift is, and the step off its far end onto the landing - both set
## by Track.
var lift_length := 50.0
var lift_drop := 3.0
## The half-width the road is being built at. Changed with width().
var half_width := 8.0
## Whether the road being built now is floating. Changed with floating().
var _floating := false
## High roads, in the order they leave the course. See high_road().
var branches: Array = []
## The high road the course is going the long way round underneath, if any.
var _open_branch: BranchDefinition

## How far the road has got. This is what furniture is placed at.
var _built := 0.0


## Lay the track out. Overridden by every track file; this is what Track calls
## once it has told the definition how long a jump is and how finely the road
## is sampled.
func describe() -> void:
	push_error("TrackDefinition: %s describes no track" % track_name)


# --- the road -----------------------------------------------------------

## Level road.
func straight(length: float) -> void:
	_add(TrackLayout.STRAIGHT, length)


## A corner, in degrees and metres. Positive turns right, negative left - the
## same sign the generator uses.
##
## The length of a corner is not chosen: an arc of a given angle at a given
## radius is as long as it is. A 90 degree corner at 20 m is 31 m of road.
##
## `rise` climbs or falls across the corner, eased at both ends the way a climb
## is, which is what lets a course spiral: a corner that turns all the way round
## and comes back over the road it left on, ten metres above it.
func corner(degrees: float, radius: float, rise := 0.0) -> void:
	var piece := _add(TrackLayout.CORNER, absf(deg_to_rad(degrees)) * radius)
	piece.turn = deg_to_rad(degrees)
	piece.radius = radius
	piece.rise = rise


## Road that gains or loses height across its length, eased in and out so it
## meets the level road at either end without a crease.
func climb(length: float, rise: float) -> void:
	var piece := _add(TrackLayout.CLIMB, length)
	piece.rise = rise


## A ramp, a hole with no road in it, and a long flat run to come down on.
##
## `rise` puts the landing that many metres higher than the road the jump was
## taken from - or lower, below zero - so a track can climb into the air a jump
## at a time. Up to 3.5 m, which anything that clears a level jump still
## reaches; down as far as a track likes.
##
## `landing` is how much road there is past the hole before whatever comes
## next, when a track wants less than the usual 90 m. Not less than 55: a car on
## a boost comes down 48 m past the hole.
func jump(rise := 0.0, landing := -1.0) -> void:
	var piece := _add(TrackLayout.JUMP,
		ramp_length + jump_gap + (landing if landing > 0.0 else landing_length))
	piece.rise = rise


## A jump with a ring over the middle of its hole, `lane` across the road.
##
## The ring's height is not the track's to choose. It stands where a car that
## took the ramp properly is flying - anything from a crawl that only just
## clears the hole to flat out on a boost passes the middle of the hole within
## a metre and a half of the same height - so what the ring asks is the one
## thing the jump did not already: be lined up with it before the lip.
func ring_jump(lane := 0.0, rise := 0.0, landing := -1.0) -> void:
	var start := _built
	jump(rise, landing)
	var at := start + ramp_length + jump_gap * 0.5
	# Heights are measured from the centreline, which across the hole is the
	# line the road would take if it were there: halfway from the lip to the
	# landing. The ring stands where the car flies, whatever the landing does.
	_ring_at(at, lane, jump_ring_height - lerpf(ramp_rise, rise, 0.5))


## A jump with a ring over its hole that slides across the road on the race
## clock, from `from` to `to` and back: it holds each end for `dwell` seconds and
## takes `travel` to cross. Where the ring will be when the car gets there is
## the question - taking off lined up with where it is now is too late.
func moving_ring_jump(
	from: float, to: float, dwell := 0.8, travel := 1.6, rise := 0.0,
	landing := -1.0
) -> void:
	var start := _built
	jump(rise, landing)
	var at := start + ramp_length + jump_gap * 0.5
	var placement := _ring_at(at, from, jump_ring_height - lerpf(ramp_rise, rise, 0.5))
	placement.phases = PackedFloat32Array([from, to])
	placement.dwell = dwell
	placement.travel = travel


## A jump with a much longer hole and a platform floating in it, sliding from
## `from` to `to` across the road and back on the race clock. `width` is how much
## of the road it covers, in lane units; `dwell` and `travel` as for a trap.
##
## Where the platform stands, how long it is and how high are the game's. A car
## off the ramp at anything from about 23 to 37 m/s comes down on it if it is
## there; flat out on a boost a car flies clean over the far end, so a pad in
## the run up to one of these is a pad to think about. Off the far end of the
## platform it is a drop onto the landing.
##
## `rise` lands the far side up to 3 m higher than the road the jump was taken
## from: off the end of the platform onto road standing in the air. `landing` is
## how much road that is, down to 35 m - short enough that one platform jump
## lands straight into the ramp of the next.
func platform_jump(
	from: float, to: float, width := 0.6, dwell := 0.6, travel := 1.8,
	rise := 0.0, landing := -1.0
) -> void:
	var start := _built
	var hole := platform_start + platform_length + platform_drop
	var piece := _add(TrackLayout.JUMP,
		ramp_length + hole + (landing if landing > 0.0 else landing_length))
	piece.gap = hole
	piece.rise = rise
	var placement := TrackFeatures.Placement.new(TrackFeatures.PLATFORM,
		start + ramp_length + platform_start, platform_length)
	placement.phases = PackedFloat32Array([from, to])
	placement.lateral = from
	placement.half_span = width * 0.5
	placement.dwell = dwell
	placement.travel = travel
	# Its top, measured from the centreline across the hole, which falls from
	# the lip to the landing: that is the line the height is read against.
	var along := platform_start + platform_length * 0.5
	placement.height = platform_height - lerpf(ramp_rise, rise, along / hole)
	placements.append(placement)


## A jump with a lift in its hole: a long platform `lane` across the road that
## rises `lift` metres and comes back down on the race clock - holding the
## bottom for `dwell`, rising over `travel`, holding the top for `dwell`, and
## down again. The landing is on the far side at the top of the lift, just below
## it, so the only way across is to come down on the lift while it is low, ride
## it up, and drive off the end while it is high.
##
## It is long - fifty metres - so a car that came down on it early has room to
## brake and wait for it. `lift` may be up to 7 m: a landing eleven metres above
## the ramp's road, which no jump could reach.
func lift_jump(
	lane: float, lift: float, width := 0.6, dwell := 1.2, travel := 1.6,
	landing := -1.0
) -> void:
	var start := _built
	var hole := platform_start + lift_length + lift_drop
	var rise := platform_height + lift - 0.6
	var piece := _add(TrackLayout.JUMP,
		ramp_length + hole + (landing if landing > 0.0 else landing_length))
	piece.gap = hole
	piece.rise = rise
	piece.lift = true
	var placement := TrackFeatures.Placement.new(TrackFeatures.PLATFORM,
		start + ramp_length + platform_start, lift_length)
	placement.lateral = lane
	placement.half_span = width * 0.5
	placement.dwell = dwell
	placement.travel = travel
	placement.lift = lift
	var along := platform_start + lift_length * 0.5
	placement.height = platform_height - lerpf(ramp_rise, rise, along / hole)
	placements.append(placement)


## Split the road: a kicker in `lane` across it, and a high road off the top of
## it that runs straight ahead, floating `rise` metres up to start with, while
## the course goes the long way round underneath.
##
## What comes back is the high road, to be built the way the course is -
## straights, climbs, jumps, platforms, lifts, pads, traps; no corners and no
## rings. Then the course is built on as the low road until it has come back
## round to the line it left on, heading the same way, and high_road_end() says
## so. The high road is stretched with straight road to reach that point, and
## ends there in the air: a car on it drops off the end onto the course.
##
##     var high := high_road(0.55, 2.0)
##     high.platform_jump(-0.4, 0.4, 0.6, 0.8, 1.2, 3.0, 35.0)
##     corner(-90.0, 26.0)      # and the low road, round and back
##     ...
##     high_road_end()
##     straight(80.0)           # what the high road drops onto
##
## The kicker is a ramp in one lane rather than across the road, so taking the
## high road is a choice a car makes by where it is, and one it can decline.
func high_road(lane := 0.55, rise := 2.0) -> BranchDefinition:
	var kicker := _place(TrackFeatures.WEDGE, ramp_length)
	kicker.lateral = lane
	kicker.half_span = 0.3
	kicker.height = ramp_rise
	straight(ramp_length)

	var branch := BranchDefinition.new()
	branch.step = step
	branch.ramp_length = ramp_length
	branch.ramp_rise = ramp_rise
	branch.jump_gap = jump_gap
	branch.landing_length = landing_length
	branch.ring_radius = ring_radius
	branch.jump_ring_height = jump_ring_height
	branch.platform_start = platform_start
	branch.platform_length = platform_length
	branch.platform_drop = platform_drop
	branch.platform_height = platform_height
	branch.lift_length = lift_length
	branch.lift_drop = lift_drop
	branch.half_width = half_width
	branch.lane = lane
	branch.rise = rise
	branch.lip_offset = _built
	branch.floating()
	branches.append(branch)
	_open_branch = branch
	return branch


## The course is back on the line the high road left along. The high road drops
## onto it here.
func high_road_end() -> void:
	if _open_branch == null:
		push_error("TrackDefinition: high_road_end() with no high road open")
		return
	_open_branch.rejoin_offset = _built
	_open_branch = null


## A ring standing over the road where it has got to: `lane` across it, its
## middle `height` metres above the road. For a ring anywhere a car leaves the
## ground other than a jump - off a crest, or over a drop - where the track has
## to say how high the car will be.
##
## It has to stand clear of the road. A ring whose rim is in the asphalt is a
## wall with a hole in it, and the checks say so.
func ring(lane := 0.0, height := 4.5) -> void:
	_ring_at(_built, lane, height)


## What a lap has to beat for each medal, in seconds, fastest first.
func medals(gold: float, silver: float, bronze: float) -> void:
	targets = Vector3(gold, silver, bronze)


## The half-width of the road from here on, in metres. Widths are blended
## across the seams afterwards, so a change reads as the road opening out
## rather than as a step.
func width(metres: float) -> void:
	half_width = metres


## Whether the road from here on stands in the air on nothing, or on an
## embankment down to the ground the way raised road does. Floating road is
## drawn as a slab with an underside, and a car that goes over its rail falls
## all the way down.
func floating(on := true) -> void:
	_floating = on


## How far the road has got, in metres. Worth reading while authoring, to put
## a checkpoint or a finish line somewhere in particular.
func length() -> float:
	return _built


# --- what stands on it --------------------------------------------------

## A boost pad, in a lane from -1 at the left edge of the road to +1 at the
## right. Strength is a fraction of top speed; below zero means the pad has no
## opinion and the car falls back to its own tuning.
func pad(lane: float, length := 10.0, strength := -1.0) -> void:
	var placement := _place(TrackFeatures.BOOST_PAD, length)
	placement.lateral = lane
	placement.half_span = 0.28
	placement.strength = strength


## A row of barriers standing across part of the road, from `from` to `to` in
## the same lane units. A row never wants to block all of it: everything that
## checks a course asks whether there is still a way past.
func barrier(from: float, to: float, length := 2.4) -> void:
	var placement := _place(TrackFeatures.OBSTACLE, length)
	placement.lateral = (from + to) * 0.5
	placement.half_span = absf(to - from) * 0.5


## A row of barriers that moves: it stands centred on `from`, slides across to
## stand centred on `to`, and back, for as long as the race runs. `width` is how
## much of the road it covers, in the same lane units, so the default reaches
## the kerb from either end of `trap(-0.7, 0.7)`. It holds each end for `dwell`
## seconds and takes `travel` seconds to cross, starting from `from` at GO.
##
##     trap(-0.7, 0.7)                  # kerb to kerb and back
##     trap(-0.6, 0.6, 0.8, 2.0, 1.2)   # wider, holding 2 s, crossing in 1.2
##
## It is checked in every place it passes through rather than only at either
## end: a row sliding across the road splits what it leaves open in two on
## the way, and halfway is usually its narrowest moment.
func trap(
	from: float, to: float, width := 0.6, dwell := 1.6, travel := 1.0,
	length := 2.4
) -> void:
	var placement := _place(TrackFeatures.TRAP, length)
	placement.phases = PackedFloat32Array([from, to])
	placement.lateral = from
	placement.half_span = width * 0.5
	placement.dwell = dwell
	placement.travel = travel


## A wall running down the middle of the road for `length` metres, splitting it
## into two lanes, with a pad in the lane on `side` and a marker so the checks
## know to ask whether that lane can be driven.
##
## The barriers that make the fast lane worth thinking about are not laid here.
## They are placed after it with barrier(), inside the lane, so a track file
## says where each of them goes rather than being handed a slalom it did not
## choose.
func fork(side: float, length: float, pad_at := 4.0, thickness := 0.07) -> void:
	var divider := _place(TrackFeatures.OBSTACLE, length)
	divider.lateral = 0.0
	divider.half_span = thickness
	divider.along = true

	var boost := _place(TrackFeatures.BOOST_PAD, 10.0)
	boost.offset = _built + pad_at
	boost.lateral = signf(side) * 0.55
	boost.half_span = 0.28

	var marker := _place(TrackFeatures.FORK, length)
	marker.lateral = signf(side)
	marker.half_span = thickness


# --- building -----------------------------------------------------------

## Add a piece and move the road on by its length.
func _add(kind: int, length: float) -> TrackLayout.Piece:
	# Rounded to a whole number of samples the way the generator rounds its
	# own pieces, so every offset this hands out lands exactly on a sample.
	var steps: int = maxi(1, int(round(length / step)))
	var piece := TrackLayout.Piece.new(kind, float(steps) * step, half_width)
	piece.floating = _floating
	piece.start_offset = _built
	_built += piece.length
	piece.end_offset = _built
	pieces.append(piece)
	return piece


func _ring_at(at: float, lane: float, height: float) -> TrackFeatures.Placement:
	var placement := TrackFeatures.Placement.new(TrackFeatures.RING, at - 0.35, 0.7)
	placement.lateral = lane
	placement.half_span = 0.0
	placement.height = height
	placement.radius = ring_radius
	placements.append(placement)
	return placement


## Put something down where the road has got to. Furniture never moves the
## road on; only the pieces do that.
func _place(kind: int, length: float) -> TrackFeatures.Placement:
	var placement := TrackFeatures.Placement.new(kind, _built, length)
	placements.append(placement)
	return placement
