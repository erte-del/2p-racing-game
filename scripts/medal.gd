class_name Medal
extends RefCounted

## What a time on a track is worth.
##
## The three targets are the track's own, set in its file next to its corners,
## because what counts as a good lap is a fact about the road rather than a
## number that could be worked out from one. A wide open kilometre and a
## kilometre of hairpins are not the same forty seconds.
##
## Nothing about a medal is stored. It is worked out from the best time and
## the targets every time anything asks, so moving a target moves every medal
## that depends on it at once - which is what you want while a track is still
## being tuned, and costs nothing when it is not.

const NONE := 0
const BRONZE := 1
const SILVER := 2
const GOLD := 3

const NAMES := {
	NONE: "",
	BRONZE: "BRONZE",
	SILVER: "SILVER",
	GOLD: "GOLD",
}

## Read against the game rather than taken from metal. A true bronze
## disappears into the road; a true silver comes out the same white as the
## time printed above it, so it is pulled towards blue until the two are
## plainly different things.
const COLOURS := {
	NONE: Color(0.72, 0.76, 0.86),
	BRONZE: Color(0.85, 0.55, 0.32),
	SILVER: Color(0.70, 0.79, 0.90),
	GOLD: Color(1.0, 0.82, 0.25),
}


## What a time earns. `targets` is gold, silver, bronze in that order, and any
## of them at or below zero means the track does not offer that medal - a
## track with no targets set at all simply has no medals on it yet.
static func earned(seconds: float, targets: Vector3) -> int:
	if seconds < 0.0:
		return NONE
	if targets.x > 0.0 and seconds < targets.x:
		return GOLD
	if targets.y > 0.0 and seconds < targets.y:
		return SILVER
	if targets.z > 0.0 and seconds < targets.z:
		return BRONZE
	return NONE


## The next one up, and what it would take - for telling a player what they
## are driving at rather than only what they have. Returns the medal and the
## seconds still to find, or NONE and nothing for a lap that cannot be
## bettered. A track that skips a tier is walked past rather than stalling on
## the gap where it would have been.
static func next_up(seconds: float, targets: Vector3) -> Array:
	var has := earned(seconds, targets)
	for wanted in range(has + 1, GOLD + 1):
		var target := target_for(wanted, targets)
		if target > 0.0:
			return [wanted, seconds - target]
	return [NONE, 0.0]


## What a given medal asks for, in seconds, or zero if the track does not
## offer it.
static func target_for(medal: int, targets: Vector3) -> float:
	match medal:
		GOLD:
			return targets.x
		SILVER:
			return targets.y
		BRONZE:
			return targets.z
	return 0.0


static func label(medal: int) -> String:
	return NAMES.get(medal, "")


static func colour(medal: int) -> Color:
	return COLOURS.get(medal, COLOURS[NONE])
