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
const REVERSE := "reverse"

## In the order the track page shows them.
const ALL := [NORMAL, HARD, TRACK_CHAOS, MIRROR, REVERSE]

## The ways that can be made. HARD and track chaos are made by
## `Track.plan_course` rather than `apply()`, since their rows are planned
## against the finished layout.
const BUILT := [NORMAL, MIRROR, REVERSE, HARD, TRACK_CHAOS]

## How much harder HARD is: this many rows for every one the track has, and
## this share of the rows added turned into traps - never fewer than one trap.
## Here, in one place, so they are tuned together. Every Hard fingerprint is
## taken over the plan these make, so moving either drops every Hard time;
## tune them before the targets are measured, not after.
const HARD_MORE_ROWS := 1.5
const HARD_TRAP_SHARE := 0.3

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
	"01_first_light": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"02_long_way_round": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"03_the_weave": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"04_cold_start": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"05_overpass": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"06_split_decision": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"07_pinch": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"08_switchback": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"09_the_gauntlet": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"10_long_haul": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"11_the_hook": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"12_leap_of_faith": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"13_needle": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"14_relentless": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"15_rattlesnake": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"16_grinder": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"17_whiplash": [MIRROR, HARD, TRACK_CHAOS],
	"18_bottleneck": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"19_the_wringer": [MIRROR, REVERSE, HARD, TRACK_CHAOS],
	"20_last_light": [MIRROR, HARD, TRACK_CHAOS],
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

## What a lap is worth on each way of driving that is a different road to
## drive, by file name: gold, silver and bronze, as a track's own `medals()`
## line has them.
##
## Measured, not guessed. `tools/lap_times.gd -- reverse` has the game's bot
## drive each track as written and then the other way round, and the ratio of
## the two laps stretches the track's own ladder, rounded to the second - the
## block it prints at the end is this one. Driven backwards, a track is a few
## per cent quicker or slower depending on which way its climbs and hairpins
## face (Cold Start is 4% quicker, Leap of Faith 3% slower), which is exactly
## what a target copied from the track as written would get wrong.
##
## Here and not in the track files, for the reason `OFFERED` is. MIRROR has no
## row: it shares the track's own, see `targets`. HARD and track chaos have
## none yet, so they have a time and a board and no medals. The bot dodges
## every row it can see and its Hard lap comes out within a few per cent of the
## track's, so a Hard target measured by it would be the track's target again;
## it waits on a person driving it. A track chaos target would be a target for
## one roll of the rows.
const TARGETS := {
	REVERSE: {
		"01_first_light": Vector3(33.0, 39.0, 43.0),
		"02_long_way_round": Vector3(37.0, 41.0, 45.0),
		"03_the_weave": Vector3(39.0, 43.0, 47.0),
		"04_cold_start": Vector3(36.0, 40.0, 46.0),
		"05_overpass": Vector3(42.0, 47.0, 52.0),
		"06_split_decision": Vector3(44.0, 49.0, 54.0),
		"07_pinch": Vector3(43.0, 48.0, 54.0),
		"08_switchback": Vector3(45.0, 50.0, 56.0),
		"09_the_gauntlet": Vector3(42.0, 48.0, 53.0),
		"10_long_haul": Vector3(55.0, 62.0, 69.0),
		"11_the_hook": Vector3(49.0, 54.0, 61.0),
		"12_leap_of_faith": Vector3(53.0, 59.0, 65.0),
		"13_needle": Vector3(56.0, 62.0, 69.0),
		"14_relentless": Vector3(54.0, 61.0, 69.0),
		"15_rattlesnake": Vector3(59.0, 66.0, 73.0),
		"16_grinder": Vector3(56.0, 62.0, 71.0),
		"18_bottleneck": Vector3(55.0, 63.0, 72.0),
		"19_the_wringer": Vector3(70.0, 79.0, 88.0),
	},
}

## Why a track that has a way built for it still does not offer it, in the line
## the track page shows over PLAY. Written when the check finds a way a track
## cannot be driven, so the reason is the check's and not a guess. Acrobatic
## tracks have no row here: their page does not show the ways they never offer.
const WHY_NOT := {
	"17_whiplash": {
		REVERSE: "Backwards, its jumps land on the pad and the rows before them.",
	},
	"20_last_light": {
		REVERSE: "Backwards, its second jump lands on the pad before it.",
	},
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


## What a race on a track calls the road: its name, and the way it is driven
## beside it wherever that is not NORMAL - `FIRST LIGHT · MIRROR`. On the pause
## screen, the finish screen and in the corner, so a time read off a
## screenshot says which road it was set on.
static func title(track_name: String, variant: String) -> String:
	var named := track_name.to_upper()
	return named if variant == NORMAL else "%s · %s" % [named, display_name(variant)]


## Why a track cannot be driven a way, in one line, or empty when it can. What
## the track page puts under PLAY when a way it cannot drive is held down: a
## dimmed button with no reason reads as a broken one.
static func why_not(track_file: String, variant: String) -> String:
	if variant in offered(track_file):
		return ""
	if variant not in BUILT:
		return "%s is still being built." % display_name(variant)
	var reasons: Dictionary = WHY_NOT.get(track_file.get_file().get_basename(), {})
	return reasons.get(variant, "This track is not offered %s." % display_name(variant))


## Turn a track as its file describes it into the way it is being driven.
## Called by `Track.lay_out()` straight after `describe()`, before anything is
## built, so everything downstream - the road, the rails, the checkpoints, the
## checks - sees an ordinary definition and never has to ask where it came from.
## `track_file` is only for finding the way's medal targets.
static func apply(definition: TrackDefinition, variant: String, track_file: String) -> void:
	match variant:
		MIRROR:
			mirror(definition)
		REVERSE:
			reverse(definition)
	definition.targets = targets(track_file, definition.targets, variant)


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


## Driven the other way: the grid goes where the finish was, and the road is
## driven back to where it started. The same road, every corner and climb and
## hazard met in the opposite order and from the other side - so a corner that
## turned right turns left, a climb falls, and everything standing on the road
## is on the other side of it.
##
## A jump cannot simply be read backwards. Backwards, a jump is a long run, a
## hole, and fifteen metres of road where the ramp was with no ramp facing the
## car. So each one is built again from the parts around it: the old landing,
## less a ramp's length, becomes level road, and the end of it the new ramp; the
## hole stays where it was; and the new landing is the old ramp and the level
## straight that was its run-up, as much of that as a landing of the usual
## length wants. A run-up too short to land on leaves a landing `problems()`
## refuses, and the track does not offer Reverse.
##
## Nothing may stand on a jump's landing, and a run-up is not held to that: a
## pad or a row sixty metres before a ramp is a pad on the approach. Turned
## round, it is sixty metres past the hole, beyond anywhere a car comes down,
## so the landing stops short of it rather than reaching over it - never
## shorter than the shortest landing a jump may have. Where even that would
## reach something, the track does not offer Reverse either.
##
## Only for a normal track. Rings, platforms, lifts and high roads are all
## timed or aimed around where a ramp throws a car, and none of them has a
## reverse that is the same kind of thing - see `why_not`.
static func reverse(definition: TrackDefinition) -> void:
	var total := definition.length()
	var step := definition.step
	var shortest := TrackLayout.new().min_jump_landing
	for placement in definition.placements:
		placement.offset = total - placement.offset - placement.length
		placement.lateral = -placement.lateral
		var phases := PackedFloat32Array()
		for phase in placement.phases:
			phases.append(-phase)
		placement.phases = phases

	var backwards: Array[TrackLayout.Piece] = []
	for i in range(definition.pieces.size() - 1, -1, -1):
		var piece: TrackLayout.Piece = definition.pieces[i]
		piece.turn = -piece.turn
		piece.rise = -piece.rise
		backwards.append(piece)

	var pieces: Array[TrackLayout.Piece] = []
	var built := 0
	var at := 0
	while at < backwards.size():
		var piece := backwards[at]
		at += 1
		if piece.kind != TrackLayout.JUMP:
			pieces.append(piece)
			built += _steps(piece.length, step)
			continue
		# Counted in samples rather than metres, the way the road is built, so
		# the course comes out exactly as long as it went in and every
		# placement lands back on the same stretch of road.
		var steps := _steps(piece.length, step)
		var hole := piece.gap if piece.gap > 0.0 else definition.jump_gap
		var level := _steps(piece.length - hole - 2.0 * definition.ramp_length, step)
		var lead := TrackLayout.Piece.new(TrackLayout.STRAIGHT, float(level) * step,
			piece.half_width)
		lead.floating = piece.floating
		pieces.append(lead)
		built += level
		# As much of the run-up as the landing wants, and no more than reaches
		# a jump's keep-out short of the first thing standing past the hole.
		# Where the two disagree, the landing wins: a landing too short is the
		# worse fault, and whatever it then reaches is reported by the check
		# as standing on a jump.
		var ramp_and_hole := definition.ramp_length + hole
		var wanted := level
		var clear := _first_past(definition.placements,
			float(built) * step + ramp_and_hole) - definition.jump_keep_out
		if clear < INF:
			wanted = mini(wanted, int(floor(clear / step)) - built - (steps - level))
		wanted = maxi(wanted,
			int(ceil((ramp_and_hole + shortest) / step)) - (steps - level))
		# The run-up, taken off the straights after it for as long as they are
		# the same road the jump is: level, as wide, and standing the same way.
		var taken := 0
		while taken < wanted and at < backwards.size():
			var next := backwards[at]
			if (next.kind != TrackLayout.STRAIGHT or next.half_width != piece.half_width
					or next.floating != piece.floating):
				break
			var has := _steps(next.length, step)
			var take := mini(has, wanted - taken)
			taken += take
			if take < has:
				next.length = float(has - take) * step
				break
			at += 1
		piece.length = float(steps - level + taken) * step
		pieces.append(piece)
		built += steps - level + taken
	definition.pieces = pieces

	# A fork's pad is a few metres into the lane from the entry, so the split
	# and the reward arrive together. Reversed, it would be at the far end of
	# the lane, a reward for a choice already made - so it is put back the
	# same distance in from the lane's new entry. A pad wholly inside the
	# lane, to the millimetre: one that starts where the lane ends, straight
	# out of the fork, is on the road after it and stays there.
	for fork in definition.placements:
		if fork.kind != TrackFeatures.FORK:
			continue
		var entry := fork.offset
		var exit := fork.offset + fork.length
		for pad in definition.placements:
			if (pad.kind == TrackFeatures.BOOST_PAD and pad.offset > entry - 0.001
					and pad.offset + pad.length < exit + 0.001):
				pad.offset = entry + exit - pad.offset - pad.length


## Where the first thing standing on the road at or past `from` begins, or
## infinitely far off when nothing does. Things that stand in the air or mark
## a stretch rather than stand on it are not counted, as `track_check.gd`
## does not count them.
static func _first_past(placements: Array[TrackFeatures.Placement], from: float) -> float:
	var first := INF
	for placement in placements:
		if placement.kind in [TrackFeatures.FORK, TrackFeatures.RING,
				TrackFeatures.PLATFORM, TrackFeatures.WEDGE, TrackFeatures.COIN]:
			continue
		if placement.offset + placement.length > from:
			first = minf(first, placement.offset)
	return first


static func _steps(length: float, step: float) -> int:
	return maxi(1, int(round(length / step)))


## What a lap of the track driven this way is worth, given what a lap of the
## track as written is worth.
##
## A mirrored lap is the same lap turned round - the same length, the same
## corners the other way, in a car that is the same on both sides - so it is
## worth the same. That was an argument until the bot drove all thirty: every
## mirror it finished cleanly came home within 0.7% of its track, and
## `tools/lap_times.gd -- mirror` is how to ask again. The other ways are
## different roads, and their targets are what `TARGETS` measured for them. A
## way with no row there has none, which is how a track with no `medals()` line
## already behaves: a time and a board, and no gold that was guessed.
static func targets(track_file: String, base: Vector3, variant: String) -> Vector3:
	if variant in [NORMAL, MIRROR]:
		return base
	var measured: Dictionary = TARGETS.get(variant, {})
	return measured.get(track_file.get_file().get_basename(), Vector3.ZERO)


## A track described and put through a variant, with no road built: the pieces
## and placements a race on it would be laid out from. Null for a file that is
## not a track.
##
## Planned by a `Track` that is never put in the world, through the same
## `plan_course` a race lays itself out with. Hard's rows depend on where the
## grid, the flag, the respawns and the jumps fall, and only a Track knows
## those - and a plan worked out anywhere else would be a second copy of the
## planner, free to drift from the one the race uses.
##
## For track chaos, `roll_seed` is the run's roll; left at zero it is the track
## with its loose rows taken up and none rolled, which is what a track chaos
## time is fingerprinted against, since the rows are different every run.
static func described(track_file: String, variant: String, roll_seed := 0) -> TrackDefinition:
	var written := load(track_file) as GDScript
	if written == null:
		return null
	var definition: TrackDefinition = written.new()
	var track: Track = load("res://scenes/track/track.tscn").instantiate()
	track.track_file = track_file
	track.variant = variant
	track.track_chaos_seed = roll_seed
	track.plan_course(definition)
	track.free()
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
