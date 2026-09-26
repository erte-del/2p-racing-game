class_name TrackVariant
extends RefCounted

## The ways a laid-out track can be driven, and what each is called wherever a
## time is written down or sent.
##
## A variant is a different road to drive, so it keeps its own best time and
## has its own board. Nothing set on one may land on another: a time set on the
## mirrored First Light is not a time on First Light.
##
## Named constants rather than strings typed out at each call site, so a
## misspelt variant is a compile error and not a quiet fifth board nobody can
## find. NORMAL is the empty string on purpose: it is the track as written, and
## a key with nothing added to it is the key every time set before variants
## existed was already kept under. Not one of those moves.

const NORMAL := ""
const HARD := "hard"
## Track chaos: the track as written, in the tuned car, with its hazards rolled
## again every run. **Not chaos mode**, the endless course's `GameSettings.chaos`
## that re-rolls the car, the sky and the road itself, and which a laid-out
## track always turns off. The two share the word on their buttons and nothing
## else, so this one is called track chaos everywhere it is named - here, in
## the key its times are kept under, and in the notes.
const TRACK_CHAOS := "track_chaos"
const MIRROR := "mirror"

## In the order the track page shows them.
const ALL := [NORMAL, HARD, TRACK_CHAOS, MIRROR]

## The ways `apply()` knows how to make so far. HARD and track chaos have a key
## and a board already, but no transform yet: until they do, no track offers
## them, so nothing can drive the base track while calling it HARD.
const BUILT := [NORMAL, MIRROR]

## What each track offers besides NORMAL, by file name, in the order of
## `TrackRoster.FILES` and then `ACROBATIC_FILES`.
##
## Here and not in the track files. A time's fingerprint is taken over the
## whole of its track's file, so a line added to each of them would throw away
## every best time on every track, for a change that did not move a corner.
##
## `tools/checks/variants.gd` holds each row to what it claims: a way listed
## here has to build clean, and a way that would build clean but is not listed
## is reported, so a track does not quietly miss out on one. Bot roads are not
## here at all. The gate is one race against one road.
const OFFERED := {
	"01_first_light": [MIRROR],
	"02_long_way_round": [MIRROR],
	"03_the_weave": [MIRROR],
	"04_cold_start": [MIRROR],
	"05_overpass": [MIRROR],
	"06_split_decision": [MIRROR],
	"07_pinch": [MIRROR],
	"08_switchback": [MIRROR],
	"09_the_gauntlet": [MIRROR],
	"10_long_haul": [MIRROR],
	"11_the_hook": [MIRROR],
	"12_leap_of_faith": [MIRROR],
	"13_needle": [MIRROR],
	"14_relentless": [MIRROR],
	"15_rattlesnake": [MIRROR],
	"16_grinder": [MIRROR],
	"17_whiplash": [MIRROR],
	"18_bottleneck": [MIRROR],
	"19_the_wringer": [MIRROR],
	"20_last_light": [MIRROR],
	"a01_lift_off": [MIRROR],
	"a02_sky_stairs": [MIRROR],
	"a03_island_hopper": [MIRROR],
	"a04_tightrope": [MIRROR],
	"a05_elevator": [MIRROR],
	"a06_high_road_low_road": [MIRROR],
	"a07_freefall": [MIRROR],
	"a08_pinball": [MIRROR],
	"a09_knot": [MIRROR],
	"a10_last_leap": [MIRROR],
}


## The ways a track can be driven, NORMAL first. Empty for a road that is not a
## time trial - a bot road, or a file nobody has heard of - which has no ways
## to choose between. A lookup rather than a build, because the track page asks
## it for every way it shows.
static func offered(track_file: String) -> Array:
	var name := track_file.get_file().get_basename()
	if not OFFERED.has(name):
		return []
	return [NORMAL] + OFFERED[name]


## Turn a track as its file describes it into the way it is being driven.
## Called by `Track.lay_out()` straight after `describe()`, before anything is
## built, so everything downstream - the road, the rails, the checkpoints, the
## checks - sees an ordinary definition and never has to ask where it came from.
static func apply(definition: TrackDefinition, variant: String) -> void:
	match variant:
		MIRROR:
			mirror(definition)
	definition.targets = targets(definition.targets, variant)


## Left and right swapped: every corner turns the other way, and everything
## standing on the road stands on the other side of it. Climbs, jumps and
## lengths are untouched, so it is the same road in every way the car cares
## about - the car is the same on both sides.
##
## Its own inverse, which is what the check leans on: mirrored twice is the
## track as written, to the millimetre, or a sign was flipped twice or not at
## all.
static func mirror(definition: TrackDefinition) -> void:
	for piece in definition.pieces:
		piece.turn = -piece.turn
	for placement in definition.placements:
		placement.lateral = -placement.lateral
		var phases := PackedFloat32Array()
		for phase in placement.phases:
			phases.append(-phase)
		placement.phases = phases
	# A high road leaves off a kicker in one lane and runs over the other side
	# of the course, so it moves across with everything else, and whatever
	# stands on it does too.
	for branch: BranchDefinition in definition.branches:
		branch.lane = -branch.lane
		mirror(branch)


## What a lap of the track driven this way is worth, given what a lap of the
## track as written is worth.
##
## A mirrored lap is the same lap turned round - the same length, the same
## corners the other way, in a car that is the same on both sides - so it is
## worth the same. The other ways are different roads and get targets of
## their own once somebody has measured them. Until then they have none,
## which is how a track with no `medals()` line already behaves: a time and a
## board, and no gold that was guessed.
static func targets(base: Vector3, variant: String) -> Vector3:
	return base if variant in [NORMAL, MIRROR] else Vector3.ZERO


## A track described and put through a variant, with no road built: the pieces
## and placements a race on it would be laid out from. Null for a file that is
## not a track.
##
## Described with the definition's own jump lengths and sampling step rather
## than a `Track`'s, since there is no `Track` here. They are the same numbers,
## and a change to either is what `TrackTimes.GEOMETRY` is bumped for.
static func described(track_file: String, variant: String) -> TrackDefinition:
	var written := load(track_file) as GDScript
	if written == null:
		return null
	var definition: TrackDefinition = written.new()
	definition.describe()
	apply(definition, variant)
	return definition


## A definition written out as text, every number in it to three places - a
## millimetre, for a length: what a variant's fingerprint is taken over, and
## what the check compares.
##
## Rounded because a signature has to be the same number on a Mac
## and on a Windows machine, and the last bits of a float worked out two ways
## need not be. Names, medal targets and coins are left out: none of them is
## road. Coins are scattered by the `Track` once the plan is built - into the
## same list, which is why they have to be stepped over here.
static func plan(definition: TrackDefinition) -> String:
	var out := PackedStringArray()
	_write_road(definition, out)
	for branch: BranchDefinition in definition.branches:
		out.append("high road %s %s %s %s" % [_mm(branch.lane), _mm(branch.rise),
			_mm(branch.lip_offset), _mm(branch.rejoin_offset)])
		_write_road(branch, out)
	return "\n".join(out)


static func _write_road(definition: TrackDefinition, out: PackedStringArray) -> void:
	for piece in definition.pieces:
		out.append("piece %d %s %s %s %s %s %s %d %d" % [piece.kind,
			_mm(piece.length), _mm(piece.turn), _mm(piece.radius), _mm(piece.rise),
			_mm(piece.half_width), _mm(piece.gap), int(piece.floating), int(piece.lift)])
	for placement in definition.placements:
		if placement.kind == TrackFeatures.COIN:
			continue
		var phases := PackedStringArray()
		for phase in placement.phases:
			phases.append(_mm(phase))
		out.append("placement %d %s %s %s %s %d %s [%s] %s %s %s %s %s" % [
			placement.kind, _mm(placement.offset), _mm(placement.length),
			_mm(placement.lateral), _mm(placement.half_span), int(placement.along),
			_mm(placement.strength), " ".join(phases), _mm(placement.dwell),
			_mm(placement.travel), _mm(placement.height), _mm(placement.radius),
			_mm(placement.lift)])


## A number to three places, with no minus sign on a zero: a lane of 0 turned
## round is -0, and it is the same lane.
static func _mm(value: float) -> String:
	var text := "%.3f" % value
	return "0.000" if text == "-0.000" else text


## What a track's time is kept and sent under: the file's name, and for any
## way but NORMAL, a hyphen and the variant. Hyphen because every track file
## is named with underscores, so the two halves can never be confused.
static func key(track_file: String, variant := NORMAL) -> String:
	var base := track_file.get_file().get_basename()
	return base if variant == NORMAL else "%s-%s" % [base, variant]


## A key taken apart again: the file name it was made from, and the variant.
## A key with no variant on the end is NORMAL, which is every key written down
## before variants existed.
static func split(track_key: String) -> Array:
	for variant: String in ALL:
		if variant != NORMAL and track_key.ends_with("-" + variant):
			return [track_key.trim_suffix("-" + variant), variant]
	return [track_key, NORMAL]


## What the page calls it. Track chaos is CHAOS on the page, since it is on a
## track's own page and the word has nothing to be confused with there.
static func display_name(variant: String) -> String:
	match variant:
		NORMAL:
			return "NORMAL"
		TRACK_CHAOS:
			return "CHAOS"
	return variant.to_upper()
