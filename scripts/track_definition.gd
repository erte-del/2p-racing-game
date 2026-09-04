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
var jump_gap := 17.0
var landing_length := 90.0
## The half-width the road is being built at. Changed with width().
var half_width := 8.0

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
func corner(degrees: float, radius: float) -> void:
	var piece := _add(TrackLayout.CORNER, absf(deg_to_rad(degrees)) * radius)
	piece.turn = deg_to_rad(degrees)
	piece.radius = radius


## Road that gains or loses height across its length, eased in and out so it
## meets the level road at either end without a crease.
func climb(length: float, rise: float) -> void:
	var piece := _add(TrackLayout.CLIMB, length)
	piece.rise = rise


## A ramp, a hole with no road in it, and a long flat run to come down on.
func jump() -> void:
	_add(TrackLayout.JUMP, ramp_length + jump_gap + landing_length)


## What a lap has to beat for each medal, in seconds, fastest first.
func medals(gold: float, silver: float, bronze: float) -> void:
	targets = Vector3(gold, silver, bronze)


## The half-width of the road from here on, in metres. Widths are blended
## across the seams afterwards, so a change reads as the road opening out
## rather than as a step.
func width(metres: float) -> void:
	half_width = metres


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
	piece.start_offset = _built
	_built += piece.length
	piece.end_offset = _built
	pieces.append(piece)
	return piece


## Put something down where the road has got to. Furniture never moves the
## road on; only the pieces do that.
func _place(kind: int, length: float) -> TrackFeatures.Placement:
	var placement := TrackFeatures.Placement.new(kind, _built, length)
	placements.append(placement)
	return placement
