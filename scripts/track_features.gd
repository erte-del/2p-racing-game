class_name TrackFeatures
extends RefCounted

## Decides what furniture goes on a course - boost pads and obstacles - and
## where.
##
## This is a planner, not a builder: it reads a finished TrackLayout and hands
## back a list of placements. Nothing here touches a node or a mesh, which is
## what lets a plan be checked before any geometry is paid for, the same way
## TrackLayout is checked before a road is built from it.
##
## Placements are described as an offset along the course and a lateral
## position across it. Lateral is normalised, -1 at the left edge of the road
## and +1 at the right, never metres: the road narrows through the corners and
## chaos mode rerolls both widths for every race, so a pad pinned at "2.4 m
## right" would sit on the kerb on a narrow roll and in the middle of the road
## on a wide one.

const BOOST_PAD := 0
const OBSTACLE := 1
## Not a thing that gets built. A marker covering the whole of one fork - the
## set piece where the road splits into a fast lane with a pad and hazards in
## it and a clear one with neither - so the rest of the planner can keep off
## it and a check can find it and ask whether it can be driven.
const FORK := 2
## A row of barriers that moves: it holds one place across the road, slides to
## the next, holds that, and loops, on the race clock. Everything a row has to
## obey it obeys in every place it passes through, not only where it rests.
const TRAP := 3
## A ring standing up in the air, square to the road, that a car has to pass
## through. On a track that has any, the rings are its checkpoints: nothing is
## painted on the road, and a car banks one by going through it rather than by
## driving over a line. They are not rows - a car goes through a ring, not past
## it - so nothing that asks whether a barrier can be dodged looks at them.
const RING := 4
## A slab of road floating in the hole of a jump, sliding from one side of the
## road to the other on the race clock. A car has to come down on it, ride it
## to its far end, and drop off onto the landing. It is road - a car on it is
## on the road - and it is not a row: nothing is dodged, it is landed on.
const PLATFORM := 5
## A kicker: a ramp in one lane of the road rather than across all of it, onto a
## high road. It is road - a car on it is on the road - and it is not a row:
## a car goes round it or up it, and the checks that ask whether a barrier can
## be dodged leave it alone.
const WEDGE := 6
## A coin standing a little above the road, taken by driving through it and
## spent in the shop. It is the one piece of furniture that has no opinion
## about how the course drives: it blocks nothing, it is landed on by nothing,
## and nothing that asks whether a barrier can be dodged looks at one. That is
## what lets it be planned last, on whatever road everything else left.
const COIN := 7


## One piece of furniture, in course coordinates.
class Placement:
	var kind: int
	var offset: float      ## metres along the course, to the near edge
	var length: float      ## metres along the course it covers
	var lateral: float     ## -1 at the left edge of the road, +1 at the right
	var half_span: float   ## how far it reaches either side of that, same units
	## True for a wall running along the road rather than a row standing
	## across it. A divider narrows what everything beside it leaves open, but
	## it is not itself something to be dodged, so the reachability rule steps
	## over it rather than treating it as one more row to get past.
	var along: bool
	## What it does, read by whatever builds it. For a pad, the extra top
	## speed as a fraction; negative means "whatever the car is tuned for".
	var strength: float
	## For a trap, the places across the road it moves between, as laterals, in
	## the order it visits them before going back to the first. `lateral` is
	## always the first of them, which is where it stands at GO. Empty for
	## anything that stands still.
	var phases := PackedFloat32Array()
	## Seconds a trap holds each of those places, and seconds it takes to get
	## from one to the next.
	var dwell := 0.0
	var travel := 0.0
	## For a ring, how high its middle stands above the middle of the road at
	## `centre()`, and the radius of the hole in it, both in metres. For a
	## platform, `height` is how high its top stands above that same point. For
	## a coin, the same two things about the disc: how high its middle floats
	## and how far across it is. Metres rather than lane units because a car's
	## height is not a fraction of anything.
	var height := 0.0
	var radius := 0.0
	## For a lift: how far it rises above `height` and back, in metres, on the
	## race clock - holding the bottom for `dwell`, rising over `travel`,
	## holding the top for `dwell` and coming back down over `travel`. Zero for
	## anything that does not go up and down.
	var lift := 0.0

	func _init(p_kind: int, p_offset: float, p_length: float) -> void:
		kind = p_kind
		offset = p_offset
		length = p_length
		lateral = 0.0
		half_span = 0.25
		strength = -1.0
		along = false

	## The middle of the placement, which is where it is anchored.
	func centre() -> float:
		return offset + length * 0.5

	func moves() -> bool:
		return phases.size() > 1

	## Where it stands across the road at a time on the race clock.
	##
	## A function of the clock and nothing else, so two cars on a split screen
	## meet the same trap in the same place, and a race put back on the line
	## puts its traps back where they were at GO.
	func lateral_at(seconds: float) -> float:
		if not moves():
			return lateral
		var leg := dwell + travel
		if leg <= 0.0:
			return phases[0]
		var into := fposmod(seconds, leg * phases.size())
		var i := mini(int(into / leg), phases.size() - 1)
		var moving := into - leg * i - dwell
		if moving <= 0.0:
			return phases[i]
		# Eased, so it sets off and arrives rather than starting and stopping
		# dead. Easing changes when it is where, never where it can be, so
		# none of the checks below have to know about it.
		var t := smoothstep(0.0, 1.0, moving / maxf(travel, 0.0001))
		return lerpf(phases[i], phases[(i + 1) % phases.size()], t)

	## How far above `height` a lift stands at a time on the race clock. Zero
	## at GO, and for anything that is not a lift.
	func lift_at(seconds: float) -> float:
		if lift <= 0.0:
			return 0.0
		var leg := dwell + travel
		if leg <= 0.0:
			return 0.0
		var into := fposmod(seconds, leg * 2.0)
		var i := mini(int(into / leg), 1)
		var moving := into - leg * i - dwell
		if moving <= 0.0:
			return 0.0 if i == 0 else lift
		var t := smoothstep(0.0, 1.0, moving / maxf(travel, 0.0001))
		return lerpf(0.0, lift, t) if i == 0 else lerpf(lift, 0.0, t)

	## Every place across the road it passes through, no two further apart
	## than `step`. What the checks hold a trap to, since its narrowest moment
	## is not always a place it rests: a row sliding from one kerb to the other
	## splits the road it leaves open in two on the way across.
	func sweep(step: float) -> PackedFloat32Array:
		if not moves():
			return PackedFloat32Array([lateral])
		var out := PackedFloat32Array()
		# Two places are one stretch of road driven there and back, so it is
		# only walked once.
		var legs := phases.size() if phases.size() > 2 else 1
		for i in legs:
			var from := phases[i]
			var to := phases[(i + 1) % phases.size()]
			var count: int = maxi(1, ceili(absf(to - from) / maxf(step, 0.0001)))
			for k in count:
				out.append(lerpf(from, to, float(k) / float(count)))
		if legs == 1:
			out.append(phases[1])
		return out


# --- tunables, set by Track ---------------------------------------------

var pads_enabled := true
## The shortest piece that can hold a pad. It has to cover the pad itself plus
## the margin at each end, with enough left over to be worth aiming at.
var min_pad_straight := 40.0
## Long enough to carry a few chevrons, and long enough that a car crossing
## it at an angle still lands on it.
var pad_length := 10.0
## How wide a pad is, as a fraction of the half-width. On the widest road that
## is about 4.5 m, comfortably more than a car, so taking one is a matter of
## picking your line rather than threading a needle.
var pad_half_span := 0.28
## How far a pad keeps from each end of its straight. A pad on a corner exit
## fires before the car is pointing anywhere useful, and one on the entry
## sends it in far too hot to have had a choice about it.
var pad_margin := 12.0
## The chance an eligible straight is used at all. Well under one, so the
## course has stretches with nothing on them to make the pads mean something.
var pad_chance := 0.72
## Metres between one pad and the next.
var min_pad_spacing := 60.0
## How far a pad stays from the middle of the road, at most. Plus the span
## above this has to stay under 1.0, or the pad hangs over the kerb.
var pad_lane_limit := 0.6

## Distances along the course that nothing may be placed near, and how close
## is too close. The start line, the finish and every checkpoint go in here:
## the grid and the respawns put cars on those spots facing forwards, and a
## free boost for being reset is not a reward anyone earned.
var keep_out := PackedFloat32Array()
var keep_out_radius := 20.0
## Stretches of the course that are spoken for before the planner starts - the
## jumps. Nothing is built on one.
var reserved: Array[Vector2] = []

## --- obstacles ---
##
## Barriers stood across part of the road. A row never blocks the whole road:
## the one thing that must always be true is that there is a way past, and
## that the way past can be reached from the way past the row before it.
var obstacles_enabled := true
## The shortest straight that can hold a row. Longer than a pad wants, because
## a barrier has to be seen from far enough back to be driven around rather
## than merely discovered.
var min_obstacle_straight := 44.0
## How far a row keeps from each end of its straight. Generous at the entry
## end: that is where the car arrives from a corner, and a barrier that close
## to the exit is a wall to be driven into, not an obstacle to be avoided.
var obstacle_margin := 20.0
## Metres along the course a row of barriers covers.
var obstacle_length := 2.4
## How much of the road a row blocks, as a fraction of the half-width, before
## the clear lane below is taken into account.
var obstacle_block := Vector2(0.5, 0.95)
## The chance an eligible straight is used at all.
var obstacle_chance := 1.0
## The chance a row takes the same part of the road as the one before it.
## Rows that hold the same side can follow closely, since the way past both is
## the same way past; rows that swap sides need most of the length of a
## straight between them. Holding more often than not is what lets a straight
## carry a run of barriers rather than two.
var same_side_chance := 0.55
## Metres between one row and the next when they are on separate straights,
## and the least road there may ever be between two rows on the same one -
## which is what keeps a pair that block the same side from reading as one
## long wall rather than as two barriers.
var min_obstacle_spacing := 26.0
var min_row_gap := 10.0
## How long a straight a jump wants before it, and how far past the end of a
## corner a row Hard adds has to stand, so it is seen before it is reached.
## Only `harden` reads them: the tracks' own rows and a rolled course's are
## placed by their own rules. Set by Track.
var jump_run_up := 45.0
var hard_sight := 35.0
## How many rows a single straight may hold, if it has the room for them.
var max_obstacle_rows := 6
## Metres a row keeps clear of a boost pad. Small: a hazard is meant to sit
## downstream of a pad, and this only stops one being built on top of it.
var pad_clearance := 9.0

## The gap that must always be left open across the road, in metres. The car
## is 2.06 m wide, so this is it plus room either side to aim with.
var clear_lane := 3.4
## How wide the car is, in metres - the box it collides with. What crosses
## from one row's way past to the next is the car, not a point, so this is
## what the move between them is measured for; see `_shift_between`.
var car_width := CarImport.CAR_SIZE.x
## How much more than that the planner actually leaves. The rule above is what
## the finished plan is checked against; building right up to it produces
## courses that are passable only if driven perfectly, and any rounding in the
## check then reads them as impossible. Planning wide and checking narrow is
## what keeps the two from arguing.
var plan_clearance := 1.3
## The turning circle to assume when working out whether a row can be dodged,
## in metres. The car's widest, since that is what it is doing at the speed a
## straight is taken at.
var dodge_radius := 16.0
## How much further apart rows are set than the bare minimum that arithmetic
## says is reachable. The player has to see the row, decide, and then turn;
## only the last of those three is what the reachable distance describes.
var dodge_margin := 1.4

## --- traps ---
##
## Rows that sweep from one kerb to the other and back on the race clock.
## Laid-out tracks put them wherever their files say; this is whether a rolled
## course gets any, and it is chaos that asks for them.
var traps_enabled := false
## The chance a row on a rolled course is a trap rather than a row that stands.
var trap_chance := 0.35
## Seconds a rolled trap holds each kerb, and seconds it takes to cross.
var trap_dwell := Vector2(1.2, 2.2)
var trap_travel := Vector2(0.8, 1.4)
## How finely a trap is followed across the road, in metres: no edge of it
## moves further than this between one place it is checked at and the next.
## Fine for whether there is a way past, which is a hard rule; coarser for how
## far apart the ways past two rows are, which is every place of one against
## every place of the other and costs the square of it.
var sweep_step := 0.05
var dodge_step := 0.25

## --- the fork ---
##
## One stretch of every course where the road is split down the middle: a pad
## and a run of hazards on one side, nothing at all on the other. Take the
## boost and thread the barriers, or give up the boost and have clear road.
## That choice is the point of the pads and the barriers both, so a course
## that happened not to offer one would be missing the feature rather than
## simply being quiet.
var fork_enabled := true
## The shortest straight that can hold one, and what of it goes where. The
## divider is as long as whatever is left over, within its own limits.
var fork_min_straight := 57.0
var fork_entry := 18.0
var fork_exit := 19.0
## How far into the fast lane the pad sits. The pad is inside the fork rather
## than in front of it: the split and the reward then arrive together, so a
## player sees what is on offer and what it costs in the same moment - and a
## fork needs only as much road as its divider, instead of a pad's length and
## a gap on top, which is what lets one fit on a course that has no really
## long straight anywhere on it.
var fork_pad_at := 4.0
var fork_divider := Vector2(20.0, 70.0)
## How much road the divider itself takes up. Thin: it is there to separate
## the two lanes, and every metre of it is a metre neither lane has.
var fork_divider_half_span := 0.07
## Where the pad sits in the fast lane, and how much of that lane a hazard row
## may take before the clear lane rule cuts it back.
var fork_lane := 0.55
var fork_block := Vector2(0.3, 0.6)

## --- coins ---
##
## Coins scattered along the road, driven through and spent in the shop. They
## go down after everything else and take no part in any of the rules above: a
## coin blocks nothing, so nothing has to be checked against one. What it has
## instead is a rule of its own - it may not be anywhere a car cannot get to,
## or anywhere a car cannot help getting to.
var coins_enabled := true
## How many a course carries, rolled per course.
##
## The same roll under chaos as without it. Chaos rerolls where the coins are,
## because it rerolls the road they are on; a chaos run that also paid better
## would make it the efficient way to farm rather than a different race, and
## the shop would end up priced against a mode rather than against a game.
var coin_count := Vector2i(5, 15)
## The disc: how far across it is and how high its middle floats above the
## road, in metres. The car is 1.45 m tall and 2.06 m wide, so a coin at this
## height is taken through the middle of the windscreen rather than run over.
var coin_radius := 0.55
var coin_height := 1.05
## Metres along the course a coin takes up. Barely any: it is a disc standing
## square across the road, and this is only what the box that notices a car is
## built from.
var coin_length := 1.2
## Metres between one coin and the next. Far enough apart that a handful of
## them reads as a scattering rather than as a pile.
var min_coin_spacing := 18.0
## How far a coin keeps from anything solid: across the road, and along it.
## Enough that a coin is never inside a barrier or a kicker, and never so close
## alongside one that taking it means scraping down it.
var coin_clearance := 1.1
var coin_room := 3.5
## How much road a car needs after a coin before it meets the next row of
## barriers, in metres. A coin lined up with a wall a few metres past it is not
## an offer, it is bait: a car that went for it has already committed to the
## line it is going to hit. So a coin has to sit somewhere a car could hold all
## the way through whatever is standing just past it.
var coin_run_up := 14.0
## How far from the middle of the road a coin may be put when nothing more
## interesting is deciding for it. Plus its own width this has to stay under
## 1.0, or the coin hangs over the kerb.
var coin_lane_limit := 0.66
## Where the interesting road is, as weights on the draw.
##
## A coin in the middle of an empty straight is not a decision - it is a pickup
## on the line the car was already on. A coin in the fast lane of the fork, on
## the outside line of a corner, or in the gap just past a row of barriers is
## worth something, because taking it costs a line. So the interesting places
## are drawn from far more often than the quiet ones. Weights rather than
## rules: the open road keeps a small share, so a course is not a dotted line
## down the one racing line either.
var coin_fork_weight := 5.0
var coin_dodge_weight := 4.0
var coin_corner_weight := 2.5
var coin_open_weight := 0.6
## How far past a row of barriers still counts as just past it, in metres. The
## near end is far enough on that the coin is not part of the row to be dodged;
## the far end is close enough that the car is still on the line the row put it.
var coin_dodge_run := Vector2(5.0, 16.0)
## How finely the course is walked looking for somewhere to put one.
var coin_step := 4.0


# --- results ------------------------------------------------------------

## How far a ring's rim reaches past its hole, for the check that it stands
## clear of the road: the tube it is drawn with, both sides of it.
var ring_rim := 0.7

var placements: Array[Placement] = []
## Stretches of course the fork has taken, which nothing else may build on.
var _claimed: Array[Vector2] = []


## Plan the furniture for a course. Always succeeds: a course with nowhere to
## put a pad simply gets none, which is a quiet course rather than a broken
## one, so there is nothing here for the caller to retry.
static func build(
	layout: TrackLayout, features_seed: int, tuning: Dictionary = {}
) -> TrackFeatures:
	var features := TrackFeatures.new()
	for key in tuning:
		features.set(key, tuning[key])

	var rng := RandomNumberGenerator.new()
	rng.seed = features_seed
	# The fork goes down first and claims the best straight on the course.
	# Left until last it would be fitting itself around whatever the loose
	# pads and barriers had already taken, and the one part of a course that
	# is promised should not be the part that goes wherever there is room.
	if features.fork_enabled:
		features._place_the_fork(layout, rng)
	if features.pads_enabled:
		features._place_pads(layout, rng)
	if features.obstacles_enabled:
		features._place_obstacles(layout, rng)
		if features.traps_enabled:
			features._make_sure_of_a_trap(layout, rng)
	return features


## Take a plan that was written down rather than planned.
##
## The generator passes are skipped entirely; what a track file says is on the
## road is what is on it. `faults()` still applies, so an authored course is
## checked for a way past every barrier and for that way being reachable from
## the last, exactly as a generated one is - the difference is that a
## generated course would have been rejected and rerolled, and an authored one
## is told what is wrong with it.
static func adopt(
	written: Array[Placement], tuning: Dictionary = {}
) -> TrackFeatures:
	var features := TrackFeatures.new()
	for key in tuning:
		features.set(key, tuning[key])
	features.placements = written
	return features


## Every placement of one kind, for building and for debugging.
func of_kind(kind: int) -> Array[Placement]:
	var out: Array[Placement] = []
	for placement in placements:
		if placement.kind == kind:
			out.append(placement)
	return out


func summary() -> String:
	return "%d boost pads, %d barriers, %d traps, %d forks, %d rings, %d coins" % [
		of_kind(BOOST_PAD).size(), of_kind(OBSTACLE).size(),
		of_kind(TRAP).size(), of_kind(FORK).size(), of_kind(RING).size(),
		of_kind(COIN).size()] + (
			", %d platforms" % of_kind(PLATFORM).size() if not of_kind(PLATFORM).is_empty() else "")


# --- boost pads ---------------------------------------------------------

## Walk the pieces and drop pads on the long straights.
##
## Straights only, and only long ones. A pad is a decision about where to
## spend speed, and the only place a player has room to make one is somewhere
## they can see far enough ahead to pick a line.
func _place_pads(layout: TrackLayout, rng: RandomNumberGenerator) -> void:
	for piece in layout.pieces:
		if piece.kind == TrackLayout.CORNER:
			continue
		if piece.length < min_pad_straight:
			continue
		if rng.randf() > pad_chance:
			continue

		var first := piece.start_offset + pad_margin
		var last := piece.end_offset - pad_margin - pad_length
		if last <= first:
			continue
		var at := rng.randf_range(first, last)
		# Measured against every pad already down rather than against the last
		# one laid, because the fork goes down before these do and its pad is
		# somewhere in the middle of the course, not behind them.
		if _too_near_a_pad(at):
			continue
		if _too_close_to_keep_out(at + pad_length * 0.5):
			continue
		if _is_claimed(at, at + pad_length):
			continue

		var pad := Placement.new(BOOST_PAD, at, pad_length)
		# Left, middle or right. Nothing is being avoided yet, so which lane a
		# pad sits in only decides how far off the racing line it is - but
		# pads are lane furniture from the start, because what eventually
		# hangs off them is a hazard in one lane and clear road in the other.
		pad.lateral = float(rng.randi_range(-1, 1)) * pad_lane_limit
		pad.half_span = pad_half_span
		placements.append(pad)


## True if another pad is close enough that the two would read as one long
## run of boost rather than as two chances at one.
func _too_near_a_pad(at: float) -> bool:
	for pad in of_kind(BOOST_PAD):
		if absf(at - pad.offset) < min_pad_spacing:
			return true
	return false


func _too_close_to_keep_out(at: float) -> bool:
	for mark in keep_out:
		if absf(at - mark) < keep_out_radius:
			return true
	return false


## The gap the planner leaves at an offset, in lateral units - wider than the
## rule the finished plan is checked against.
func _planned_clear(layout: TrackLayout, at: float) -> float:
	return clear_lane * plan_clearance / maxf(layout.half_width_at(at), 0.001)


## True if this stretch of course is spoken for - by a fork, or by a jump.
func _is_claimed(from: float, to: float) -> bool:
	for span in _claimed + reserved:
		if from < span.y and span.x < to:
			return true
	return false


# --- obstacles ----------------------------------------------------------

## Stand rows of barriers across the long straights.
##
## Rows are built to be passable rather than rolled and rejected: each one is
## cut back until the gap it leaves is wide enough to drive through, and the
## next one is set far enough downstream that the car can get from this row's
## gap to that one. `faults()` then checks the finished plan against the
## same rules, so a mistake in the construction shows up as a fault rather
## than as a course nobody can finish.
func _place_obstacles(layout: TrackLayout, rng: RandomNumberGenerator) -> void:
	var pads := of_kind(BOOST_PAD)
	var last_at := -INF

	for piece in layout.pieces:
		if piece.kind == TrackLayout.CORNER:
			continue
		if piece.length < min_obstacle_straight:
			continue
		if rng.randf() > obstacle_chance:
			continue

		var at := piece.start_offset + obstacle_margin
		var limit := piece.end_offset - obstacle_margin
		if at - last_at < min_obstacle_spacing:
			at = last_at + min_obstacle_spacing
		var previous: Placement = null
		var previous_sets: Array = []
		var placed := 0

		# Stepping past a pad or a fork is not a row, so it does not count
		# against the straight's allowance. Counting it would leave a long
		# straight with one pad on it holding a single barrier, when what it
		# has room for is several.
		while placed < max_obstacle_rows:
			if at + obstacle_length > limit:
				break
			var barrier := _row_at(layout, at, rng, previous)
			if barrier == null:
				break
			# Where this row can stand is not known until it is known what it
			# blocks: a row taking the same side as the one before it can
			# follow closely, and one taking the opposite side needs the whole
			# width of the road to be crossed before it. Against a trap that
			# is wherever the two of them are furthest apart.
			if previous != null:
				var sets := gap_sets(layout, barrier, Vector2(-1.0, 1.0), barrier)
				var half_width := maxf(layout.half_width_at(barrier.centre()), 0.001)
				var shift := (_worst_shift(previous_sets, sets, car_width / half_width)
						* half_width)
				barrier.offset = maxf(barrier.offset,
					previous.centre() + _run_for(shift, rng) - barrier.length * 0.5)
				if barrier.offset + barrier.length > limit:
					break
				# The road may have narrowed since the provisional offset, so
				# the row is trimmed again where it has actually ended up.
				_fit(layout, barrier)
			if (_too_close_to_keep_out(barrier.centre())
					or _on_a_pad(barrier, pads)
					or _is_claimed(barrier.offset, barrier.offset + barrier.length)):
				# Step past whatever is in the way and try again further on.
				at = barrier.offset + obstacle_length + pad_clearance
				continue
			placements.append(barrier)
			placed += 1
			last_at = barrier.offset
			previous = barrier
			previous_sets = gap_sets(layout, barrier)
			at = barrier.offset + obstacle_length + min_row_gap


## Metres from the middle of one row to the middle of the next to leave for a
## car to move `shift` metres across the road between them.
##
## A car crossing from one gap to the next turns in and then back out again,
## which over a run of L metres at radius R shifts it about L squared over 4R
## sideways. Turned around, the run needed for a shift of d is the root of
## 4Rd - and then some, because a player also has to see the row and decide.
## See `_road_to_cross` for why the run is counted from the rows' middles. Never
## less than `min_row_gap` of road between them either.
func _run_for(shift: float, rng: RandomNumberGenerator) -> float:
	var needed := _road_to_cross(shift) * dodge_margin
	return maxf(needed, min_row_gap + obstacle_length) * rng.randf_range(1.0, 1.25)


## Narrow a row until the way past it is wide enough to drive through, for
## wherever it has ended up on the road.
func _fit(layout: TrackLayout, barrier: Placement) -> void:
	var clear := _planned_clear(layout, barrier.centre())
	if barrier.moves():
		# A sweeper is narrowest halfway across, where the road it leaves is
		# split either side of it, so that is the moment it is fitted to.
		barrier.half_span = minf(barrier.half_span, maxf(1.0 - clear, 0.0))
		var kerbs := PackedFloat32Array()
		for phase in barrier.phases:
			kerbs.append(signf(phase) * (1.0 - barrier.half_span))
		barrier.phases = kerbs
		barrier.lateral = kerbs[0]
		return
	if is_zero_approx(barrier.lateral):
		barrier.half_span = minf(barrier.half_span, maxf(1.0 - clear, 0.0))
		return
	var side := signf(barrier.lateral)
	barrier.half_span = minf(barrier.half_span, maxf((2.0 - clear) * 0.5, 0.0))
	barrier.lateral = side * (1.0 - barrier.half_span)


## One row of barriers across the road at `at`, or null if the road there is
## too narrow to block any of it and still leave a way through.
##
## Which part of the road it blocks is rolled - the left edge, the right edge
## or the middle - and how much of it is then cut back to whatever leaves the
## clear lane open. A row is never dropped for being too wide; it is narrowed,
## because a narrower barrier in an interesting place beats no barrier.
func _row_at(
	layout: TrackLayout, at: float, rng: RandomNumberGenerator,
	previous: Placement = null
) -> Placement:
	var half_width := layout.half_width_at(at + obstacle_length * 0.5)
	if half_width <= 0.0:
		return null
	var clear := _planned_clear(layout, at + obstacle_length * 0.5)
	var block: float = rng.randf_range(obstacle_block.x, obstacle_block.y)

	# Which part of the road this one takes: the same as the row before it, as
	# often as not, and otherwise rolled afresh.
	var hold: float = INF
	if previous != null and rng.randf() < same_side_chance:
		hold = signf(previous.lateral) if not is_zero_approx(previous.lateral) else 0.0

	# Checked first and only when asked for, so a course rolled with traps off
	# draws exactly the numbers it always did and comes out the same course.
	if traps_enabled and rng.randf() < trap_chance:
		var trap := _trap_at(at, clear, block, hold, rng)
		if trap != null:
			return trap

	var barrier := Placement.new(OBSTACLE, at, obstacle_length)
	if hold == 0.0 or (hold == INF and rng.randf() < 0.3):
		# Down the middle, with a way past on either side. Both sides have to
		# stay open, so this is the most it can ever block.
		var most: float = 1.0 - clear
		if most <= 0.05:
			return null
		barrier.lateral = 0.0
		barrier.half_span = minf(block * 0.5, most)
	else:
		# In from one edge. The way past is the rest of the road, so this can
		# take rather more of it.
		var side: float = hold if hold != INF else (-1.0 if rng.randf() < 0.5 else 1.0)
		var most: float = 2.0 - clear
		if most <= 0.1:
			return null
		var width: float = minf(block, most)
		barrier.half_span = width * 0.5
		barrier.lateral = side * (1.0 - barrier.half_span)
	return barrier


## Turn one row into a trap, if the rolls left a course that asked for traps
## without any.
##
## A course asking for traps is a promise the same way the fork is: a chaos
## race with nothing moving on it would be missing the feature rather than
## simply being quiet, and with only two or three rows to a chaos course a roll
## of the dice leaves most of them that way. The rows are tried in the order
## they are met, each narrowed to fit a sweep and kept only if the whole plan
## still passes every rule; one that would not - too close to the row either
## side of it to be reached from wherever the trap has got to - is put back as
## it was. Rows in a fork's fast lane are left alone: that lane has its own
## slalom to be.
func _make_sure_of_a_trap(layout: TrackLayout, rng: RandomNumberGenerator) -> void:
	if not of_kind(TRAP).is_empty():
		return
	var standing := faults(layout).size()
	for row in rows():
		if _in_a_fork(row):
			continue
		var i := placements.find(row)
		var clear := _planned_clear(layout, row.centre())
		var hold := signf(row.lateral) if not is_zero_approx(row.lateral) else INF
		var trap := _trap_at(row.offset, clear, row.half_span * 2.0, hold, rng)
		if trap == null:
			continue
		placements[i] = trap
		if faults(layout).size() <= standing:
			return
		placements[i] = row

	# A chaos course is often too short in the straight to have rolled any
	# loose rows at all - half of them had none, or only the fork's. A trap
	# asks less of a straight than a run of rows does: room to be seen coming,
	# and itself. So one is stood in the middle of the longest straight that
	# has that, and kept on the same terms as a converted row.
	var straights: Array[TrackLayout.Piece] = []
	for piece in layout.pieces:
		if (piece.kind != TrackLayout.CORNER
				and piece.length >= obstacle_margin * 2.0 + obstacle_length):
			straights.append(piece)
	straights.sort_custom(func(a: TrackLayout.Piece, b: TrackLayout.Piece) -> bool:
		return a.length > b.length)
	for piece in straights:
		var at := (piece.start_offset + piece.end_offset - obstacle_length) * 0.5
		var clear := _planned_clear(layout, at + obstacle_length * 0.5)
		var trap := _trap_at(at, clear,
			rng.randf_range(obstacle_block.x, obstacle_block.y), INF, rng)
		if (trap == null
				or _too_close_to_keep_out(trap.centre())
				or _on_a_pad(trap, of_kind(BOOST_PAD))
				or _is_claimed(trap.offset, trap.offset + trap.length)):
			continue
		placements.append(trap)
		if faults(layout).size() <= standing:
			return
		placements.pop_back()


## Make a laid-out track harder: more rows of barriers, and some of them moving.
##
## Put down by the planner a rolled course is built with, under the same rules,
## over the track's own furniture: only how many rows there are goes up. Each
## new row is rolled by `_row_at` somewhere on a straight clear of the grid, the
## flag, the respawns, the jumps, the pads, the fork and the rows already there,
## and is kept only if the whole plan still passes every rule `faults()` holds
## it to - a way past everywhere, reachable from the row before - and if a car
## can get to it and on from it; see `hard_row_holds`. Then rows are turned
## into traps on the same terms, the way `_make_sure_of_a_trap` turns one for
## chaos. A row that would break a rule is not put down, so a Hard track is
## harder to read and never one that cannot be finished.
##
## `more` is how many rows there are to be for each one there was, and `share`
## how many of the rows added become traps, never fewer than one. Seeded, with
## a generator of its own, so a Hard track is the same on every run and every
## machine, and drawing from it moves nothing else's rolls. Rows in a fork's
## fast lane are its own slalom and are left as the track wrote them.
func harden(layout: TrackLayout, hard_seed: int, more: float, share: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hard_seed
	var standing := faults(layout).size()
	_claim_what_new_rows_keep_off(layout)

	# Every spot a row could stand, a few metres apart on every straight and
	# climb long enough to hold one, tried in an order rolled from the seed so
	# the new rows are spread down the whole track rather than piled at its
	# start.
	var spots: Array[float] = []
	for piece in layout.pieces:
		if piece.kind != TrackLayout.STRAIGHT and piece.kind != TrackLayout.CLIMB:
			continue
		var at := piece.start_offset + obstacle_margin
		while at + obstacle_length <= piece.end_offset - obstacle_margin:
			spots.append(at)
			at += layout.step * 2.0
	_shuffle(spots, rng)

	var wanted := maxi(1, roundi(float(rows().size()) * (more - 1.0)))
	var added: Array[Placement] = []
	var pads := of_kind(BOOST_PAD)
	var was_trapping := traps_enabled
	# Rows are put down standing still; which of them move is decided after,
	# so a trap is only ever made where the rows either side of it allow one.
	traps_enabled = false
	for at in spots:
		if added.size() >= wanted:
			break
		if (_too_close_to_keep_out(at + obstacle_length * 0.5)
				or _is_claimed(at, at + obstacle_length)
				or _row_near(at, min_row_gap)):
			continue
		var row := _row_at(layout, at, rng, _row_just_behind(at))
		if row == null or _on_a_pad(row, pads):
			continue
		placements.append(row)
		if not hard_row_holds(layout, row, standing):
			placements.pop_back()
			continue
		added.append(row)
	traps_enabled = was_trapping

	# The rows added first, then the track's own loose ones, each tried as a
	# trap starting from the side it held.
	var trapped := 0
	var traps_wanted := maxi(1, roundi(float(added.size()) * share))
	var others: Array[Placement] = []
	for row in rows():
		if row.kind == OBSTACLE and row not in added and not _in_a_fork(row):
			others.append(row)
	_shuffle(added, rng)
	_shuffle(others, rng)
	for row: Placement in added + others:
		if trapped >= traps_wanted:
			break
		if _in_a_fork(row):
			continue
		var i := placements.find(row)
		var hold := signf(row.lateral) if not is_zero_approx(row.lateral) else INF
		var trap := _trap_at(row.offset, _planned_clear(layout, row.centre()),
			row.half_span * 2.0, hold, rng)
		if trap == null:
			continue
		placements[i] = trap
		if not hard_row_holds(layout, trap, standing):
			placements[i] = row
			continue
		trapped += 1
	_claimed.clear()


## Stake out what a row added to a laid-out track keeps off, for `harden` and
## `roll_track_chaos`: the fork and room either side of it, as a rolled course
## keeps its own fork; every jump's run-up, which the tracks all leave long,
## level and empty, since lining up with a ramp is the whole of what it asks;
## and the road straight out of every corner, where a row would not be seen
## until it was too late to do anything but hit it.
func _claim_what_new_rows_keep_off(layout: TrackLayout) -> void:
	_claimed.clear()
	for fork in of_kind(FORK):
		_claimed.append(Vector2(fork.offset - fork_entry,
			fork.offset + fork.length + fork_exit))
	for piece in layout.pieces:
		if piece.kind == TrackLayout.JUMP:
			_claimed.append(Vector2(piece.start_offset - jump_run_up, piece.start_offset))
		elif piece.kind == TrackLayout.CORNER:
			_claimed.append(Vector2(piece.end_offset, piece.end_offset + hard_sight))


## Take up every loose row and trap, leaving the fork - its divider, its pad
## and the slalom in its fast lane - and every pad where the track put them.
## What track chaos keeps of a track, before it rolls the rest; see
## `roll_track_chaos`. Coins go too, since they are scattered around the rows
## and a new set of rows wants a new scattering.
func strip_loose_rows() -> void:
	for i in range(placements.size() - 1, -1, -1):
		var placement := placements[i]
		var loose := (placement.kind == TRAP
				or (placement.kind == OBSTACLE and not placement.along))
		if (loose and not _in_a_fork(placement)) or placement.kind == COIN:
			placements.remove_at(i)


## Roll a laid-out track's loose rows and traps afresh: track chaos.
##
## Called on a plan `strip_loose_rows` has already cleared. The rows are put
## down by `_place_obstacles`, the pass that lays them on a rolled course, with
## traps rolled at `chance` - a chance drawn from that range, the one chaos mode
## rolls its traps at. They keep off what Hard's rows keep off, and every one
## has to hold to what Hard's are held to (`hard_row_holds`); a row that does
## not is taken back up. The same seed makes the same rows, which is what lets
## two players on a split screen meet the same road, and a check see a roll
## again.
func roll_track_chaos(layout: TrackLayout, roll_seed: int, chance: Vector2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = roll_seed
	var standing := faults(layout).size()
	_claim_what_new_rows_keep_off(layout)
	var was_trapping := traps_enabled
	var was_chance := trap_chance
	traps_enabled = true
	trap_chance = rng.randf_range(chance.x, chance.y)
	var before := placements.size()
	_place_obstacles(layout, rng)
	traps_enabled = was_trapping
	trap_chance = was_chance
	_claimed.clear()

	# The planner builds each row to be reached from the one before it on the
	# same straight, by the rule `faults()` holds; Hard's rule is stricter, and
	# a row that fails it is lifted, the plan asked again, until none do.
	# The whole plan is asked once a pass rather than once a row: while it has
	# no more faults than it started with, each row only has to be reachable
	# by a car, which is cheap to ask. A retry rolls this, and a retry is meant
	# to be instant.
	var rolled := placements.slice(before)
	var lifted := true
	while lifted:
		lifted = false
		var clean := faults(layout).size() <= standing
		for row in rolled:
			if row not in placements:
				continue
			if not (_car_reaches(layout, row) if clean
					else hard_row_holds(layout, row, standing)):
				placements.erase(row)
				lifted = true
				break


## Whether a row Hard has put down, already in the plan, can stay: the plan has
## no more faults than `standing`, and a car can get from the row before it to
## this one's way past, and from this one's to the row after.
##
## The second is the rule `faults()` holds every row to, asked for something a
## clear lane wide rather than for the car. The tracks' own rows were placed by
## hand and driven; a row Hard adds is rolled from a seed and kept without
## anyone having driven it, so it is held to the room a player is promised
## through a single row - the car and some to aim with - on the way from one
## row to the next as well.
func hard_row_holds(layout: TrackLayout, row: Placement, standing: int) -> bool:
	return faults(layout).size() <= standing and _car_reaches(layout, row)


## The second half of `hard_row_holds`: whether a car a clear lane wide can
## get from the row before this one into its way past, and from its way past
## into the next's.
func _car_reaches(layout: TrackLayout, row: Placement) -> bool:
	var all := rows()
	var at := all.find(row)
	for pair in [[at - 1, at], [at, at + 1]]:
		if pair[0] < 0 or pair[1] >= all.size():
			continue
		var from: Placement = all[pair[0]]
		var to: Placement = all[pair[1]]
		var half_width := maxf(layout.half_width_at(to.centre()), 0.001)
		var shift := _worst_shift(gap_sets(layout, from), gap_sets(layout, to),
			clear_lane / half_width) * half_width
		if to.centre() - from.centre() < _road_to_cross(shift):
			return false
	return true


## Whether a row already stands within `gap` metres of one put down at `at`.
func _row_near(at: float, gap: float) -> bool:
	for row in rows():
		if at < row.offset + row.length + gap and row.offset < at + obstacle_length + gap:
			return true
	return false


## Shuffled from `rng`, so the order is the seed's and the same every time.
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var held: Variant = items[i]
		items[i] = items[j]
		items[j] = held


func _in_a_fork(row: Placement) -> bool:
	for fork in of_kind(FORK):
		if row.offset >= fork.offset and row.offset < fork.offset + fork.length:
			return true
	return false


## A row that sweeps from one kerb to the other and back, or null if the road
## is too narrow for one.
##
## It may take only as much of the road as leaves a clear lane either side of
## it halfway across. Either end of the sweep leaves all of the rest of the
## road open in one piece; the middle leaves the same road in two halves, and
## that is the moment the width has to be good for.
func _trap_at(
	at: float, clear: float, block: float, hold: float,
	rng: RandomNumberGenerator
) -> Placement:
	var most: float = 1.0 - clear
	if most <= 0.1:
		return null
	# Starting from the side the last row held, if it held one, so the way
	# past that row is still the way past this one at GO.
	var side: float = hold if hold != INF and hold != 0.0 else (
			-1.0 if rng.randf() < 0.5 else 1.0)
	var trap := Placement.new(TRAP, at, obstacle_length)
	trap.half_span = minf(block * 0.5, most)
	var edge := 1.0 - trap.half_span
	trap.phases = PackedFloat32Array([side * edge, -side * edge])
	trap.lateral = trap.phases[0]
	trap.dwell = rng.randf_range(trap_dwell.x, trap_dwell.y)
	trap.travel = rng.randf_range(trap_travel.x, trap_travel.y)
	return trap


## True if a row would be built on top of a pad, or close enough in front of
## one that there was never a choice to make.
func _on_a_pad(barrier: Placement, pads: Array[Placement]) -> bool:
	for pad in pads:
		if (barrier.offset < pad.offset + pad.length + pad_clearance
				and pad.offset < barrier.offset + barrier.length + pad_clearance):
			return true
	return false


# --- the fork -----------------------------------------------------------

## Split the best straight on the course down the middle: a pad and a run of
## barriers on one side of the divider, clear road on the other.
##
## The divider is what makes this a choice rather than a scattering. Without
## it a player who took the pad could simply drift across to the empty part of
## the road and keep the boost for nothing; with it, taking the pad commits
## the car to the lane the hazards are in for as long as the divider runs.
func _place_the_fork(layout: TrackLayout, rng: RandomNumberGenerator) -> void:
	# Every course is meant to offer the choice, so if nothing on this one has
	# room to hold a fork at a respectful distance from the respawns, it is
	# built closer to one rather than not at all.
	var radius := keep_out_radius
	var piece := _best_straight(layout, radius)
	if piece == null:
		radius *= 0.5
		piece = _best_straight(layout, radius)
	if piece == null:
		return
	var window := _fork_room(piece, radius)
	var divider_length: float = clampf(window.y, fork_divider.x, fork_divider.y)
	if window.y < fork_divider.x:
		return

	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var at := window.x

	var divider := Placement.new(OBSTACLE, at, divider_length)
	divider.lateral = 0.0
	divider.half_span = fork_divider_half_span
	divider.along = true
	placements.append(divider)

	var pad := Placement.new(BOOST_PAD, at + fork_pad_at, pad_length)
	pad.lateral = side * fork_lane
	pad.half_span = pad_half_span
	placements.append(pad)

	# The barriers start once the pad is behind the car, so taking the boost
	# and meeting the first of them are two separate moments.
	_fill_the_fast_lane(layout, rng, side,
		pad.offset + pad.length, at + divider_length - (pad.offset + pad.length))

	var marker := Placement.new(FORK, at, divider_length)
	marker.lateral = side
	marker.half_span = fork_divider_half_span
	placements.append(marker)
	# Only what the fork itself covers, plus room either side. Claiming the
	# whole straight would leave the longest stretch of road on the course
	# carrying nothing but the fork.
	_claimed.append(Vector2(
		at - obstacle_margin, at + divider_length + obstacle_margin))


## The longest straight with room for a fork, clear of the grid, the finish
## and the respawns. The longest rather than any of them, because the fork is
## the one thing on a course worth giving the best stretch of road to.
func _best_straight(layout: TrackLayout, radius: float) -> TrackLayout.Piece:
	var best: TrackLayout.Piece = null
	var most := 0.0
	for piece in layout.pieces:
		if piece.kind == TrackLayout.CORNER:
			continue
		if piece.length < fork_min_straight:
			continue
		var room := _fork_room(piece, radius)
		# Only a stretch actually long enough to hold one. Returning the
		# roomiest straight regardless would hand back a piece with nowhere to
		# build on it, and the caller would give up rather than try again with
		# a shorter distance kept from the respawns.
		if room.y >= fork_divider.x and room.y > most:
			best = piece
			most = room.y
	return best


## The longest clear stretch inside a straight that a fork could sit in, as a
## start and a length.
##
## A straight is not thrown away for having a checkpoint somewhere on it, the
## way it once was: a fork is a good deal shorter than the straights it goes
## on, so it is fitted into whichever part of one is clear of the grid, the
## finish and the respawns. Rejecting the whole straight instead left two
## courses in five with no fork at all.
func _fork_room(piece: TrackLayout.Piece, radius: float) -> Vector2:
	var from := piece.start_offset + fork_entry
	var to := piece.end_offset - fork_exit
	if to <= from:
		return Vector2.ZERO

	var bands: Array[Vector2] = []
	for mark in keep_out:
		var band := Vector2(mark - radius, mark + radius)
		if band.y > from and band.x < to:
			bands.append(band)
	bands.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	for span in reserved:
		if span.y > from and span.x < to:
			bands.append(span)
	bands.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	var best := Vector2.ZERO
	var edge := from
	for band in bands:
		if band.x - edge > best.y:
			best = Vector2(edge, band.x - edge)
		edge = maxf(edge, band.y)
	if to - edge > best.y:
		best = Vector2(edge, to - edge)
	return best


## Barriers down the fast lane, between the divider and the outer kerb.
##
## They alternate between the two, so the lane is a slalom rather than a
## corridor, and each one is set as far past the last as the car needs to
## cross between the ways through them - the same arithmetic the loose rows
## use, applied inside a lane instead of across the whole road.
func _fill_the_fast_lane(
	layout: TrackLayout, rng: RandomNumberGenerator,
	side: float, from: float, length: float
) -> void:
	var limit := from + length - obstacle_length
	var at := from + min_row_gap
	if at >= limit:
		return
	var lane := Vector2(-1.0, 0.0) if side < 0.0 else Vector2(0.0, 1.0)
	var against_the_divider := rng.randf() < 0.5
	var previous: Placement = null
	var previous_gaps: Array[Vector2] = []

	while at < limit:
		var half_width := layout.half_width_at(at)
		var clear := _planned_clear(layout, at)
		# What is left of the fast lane once the divider has taken its share.
		var room: float = 1.0 - fork_divider_half_span - clear
		if room <= 0.05:
			return
		var width: float = minf(rng.randf_range(fork_block.x, fork_block.y), room)

		var barrier := Placement.new(OBSTACLE, at, obstacle_length)
		barrier.half_span = width * 0.5
		if against_the_divider:
			barrier.lateral = side * (fork_divider_half_span + barrier.half_span)
		else:
			barrier.lateral = side * (1.0 - barrier.half_span)

		# How far on this one has to stand is what crossing to it actually
		# asks for, rather than the width of the lane: two barriers narrow
		# enough that the ways past them overlap can follow one another
		# closely, and that is what makes the lane a run of barriers rather
		# than a pair of them.
		if previous != null:
			var gaps := _gaps_within(layout, barrier.centre(), lane, barrier)
			if gaps.is_empty():
				return
			var shift := (_shift_between(previous_gaps, gaps,
					car_width / maxf(half_width, 0.001)) * half_width)
			barrier.offset = maxf(barrier.offset,
				previous.centre() + _run_for(shift, rng) - barrier.length * 0.5)
			if barrier.offset + barrier.length > limit:
				return
		placements.append(barrier)
		previous = barrier
		previous_gaps = _gaps_within(layout, barrier.centre(), lane)
		against_the_divider = not against_the_divider
		at = barrier.offset + obstacle_length + min_row_gap


# --- coins --------------------------------------------------------------

## Scatter the coins over a course that has already been planned.
##
## Asked for separately rather than done inside `build`, because a laid-out
## track wants them too. What a track file says is on the road is what is on
## it - that is what `adopt` is for - but a coin is not part of what a track
## file describes: it is not a corner to be driven or a barrier to be got past,
## it is loose change on somebody else's road. So both kinds of course get the
## same pass over the same finished plan.
##
## Seeded separately from the course for the same reason it runs last: rolling
## the coins out of the course's own generator would move every roll after it,
## and every course in the game would come out different the day coins were
## turned on.
func scatter_coins(layout: TrackLayout, coins_seed: int) -> void:
	if not coins_enabled or layout == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = coins_seed
	var wanted := rng.randi_range(coin_count.x, coin_count.y)
	# A course is asked for a handful of coins and has to produce them, so the
	# spacing that keeps them apart is a preference rather than a rule: if a
	# short course, or one that is mostly jump and checkpoint, cannot hold them
	# that far apart, they are packed closer rather than left off. A course
	# with four coins on it is a course the shop is quietly slower to reach,
	# and nobody would ever know why.
	var spacing := min_coin_spacing
	while of_kind(COIN).size() < wanted and spacing >= 0.5:
		_draw_coins(layout, rng, wanted, spacing)
		spacing *= 0.5


## Draw coins from the spots this course has, by weight, until it has as many
## as it was asked for or has run out of anywhere to put them.
func _draw_coins(
	layout: TrackLayout, rng: RandomNumberGenerator, wanted: int, spacing: float
) -> void:
	var spots := _coin_spots(layout, rng, spacing)
	while of_kind(COIN).size() < wanted and not spots.is_empty():
		var total := 0.0
		for spot in spots:
			total += float(spot["weight"])
		if total <= 0.0:
			return
		# Walk the weights until the roll runs out, which picks a spot with a
		# probability that is its share of them.
		var roll := rng.randf() * total
		var picked := spots.size() - 1
		for i in spots.size():
			roll -= float(spots[i]["weight"])
			if roll <= 0.0:
				picked = i
				break
		var spot: Dictionary = spots[picked]
		var at := float(spot["at"])
		placements.append(_a_coin(layout, at, float(spot["lateral"])))
		# Everything too close to what was just taken goes with it, so the
		# spacing holds between the coins actually laid rather than between the
		# spots they were drawn from.
		var kept: Array[Dictionary] = []
		for other in spots:
			if absf(float(other["at"]) - at) >= spacing:
				kept.append(other)
		spots = kept


func _a_coin(layout: TrackLayout, at: float, lateral: float) -> Placement:
	var coin := Placement.new(COIN, at - coin_length * 0.5, coin_length)
	coin.lateral = lateral
	coin.half_span = coin_radius / maxf(layout.half_width_at(at), 0.001)
	coin.radius = coin_radius
	coin.height = coin_height
	return coin


## Every place on the course a coin could go, each with a weight saying how
## much it is worth going there.
func _coin_spots(
	layout: TrackLayout, rng: RandomNumberGenerator, spacing: float
) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	var at := coin_step
	var last := layout.length() - coin_step
	while at <= last:
		spots.append_array(_coin_spots_at(layout, rng, at, spacing))
		at += coin_step
	return spots


## What one offset along the course offers, which is at most one spot: the most
## interesting lane there, or the open road if nothing there is interesting.
##
## One rather than several so the draw is over offsets rather than over lanes -
## an offset that happened to be interesting in two ways would otherwise be
## twice as likely to be used as one that is interesting in one.
func _coin_spots_at(
	layout: TrackLayout, rng: RandomNumberGenerator, at: float, spacing: float
) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	if _too_close_to_keep_out(at):
		return none
	if _too_near_a_coin(at, spacing):
		return none

	# The fast lane of a fork, and only the fast lane. A coin on the clear side
	# would pay a player for giving the fork's choice a miss, which is the one
	# thing the set piece is there to make cost something.
	for fork in of_kind(FORK):
		if at < fork.offset or at >= fork.offset + fork.length:
			continue
		var lane := fork.lateral * fork_lane
		if _coin_fits(layout, at, lane):
			return _one_spot(at, lane, coin_fork_weight)
		return none

	# The gap just past a row of barriers: the line a car that has got past the
	# row is already on, a moment after it stopped having to think about it.
	# Only rows that stand still - the way past a trap is somewhere else a
	# second later, so a coin left in one is a coin in the middle of the road.
	var row := _row_just_behind(at)
	if row != null:
		var lane := _widest_gap(layout, row)
		if lane != INF and _coin_fits(layout, at, lane):
			return _one_spot(at, lane, coin_dodge_weight)

	# The outside line of a corner. Turn is positive to the right, so the
	# outside of a right-hander is the left of the road: the long way round,
	# which is the line nobody takes unless they are paid to.
	var piece := _piece_at(layout, at)
	if (piece != null and piece.kind == TrackLayout.CORNER
			and not is_zero_approx(piece.turn)):
		var lane := -signf(piece.turn) * coin_lane_limit
		if _coin_fits(layout, at, lane):
			return _one_spot(at, lane, coin_corner_weight)

	# Open road, somewhere across it. Worth little, but not nothing: a course
	# whose coins were only ever in the three places above would be a course
	# where a player stops looking at the road and starts looking for the set
	# pieces.
	var lateral := rng.randf_range(-coin_lane_limit, coin_lane_limit)
	if _coin_fits(layout, at, lateral):
		return _one_spot(at, lateral, coin_open_weight)
	return none


func _one_spot(at: float, lateral: float, weight: float) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	spots.append({"at": at, "lateral": lateral, "weight": weight})
	return spots


## Whether a coin at this place on the road would be somewhere a car can get
## to, and nowhere it cannot help going.
##
## Three things, and all three are about the car rather than about the plan.
## It has to be over road - not hanging in the hole of a jump, and not over the
## kerb. It has to be clear of everything solid, in every place that thing
## passes through, so a coin is never buried in a barrier and never swept
## through by a trap. And it has to sit inside one of the ways past whatever
## stands at that offset, or it is a coin behind a wall.
func _coin_fits(layout: TrackLayout, at: float, lateral: float) -> bool:
	var half_width := maxf(layout.half_width_at(at), 0.001)
	var span := coin_radius / half_width
	if absf(lateral) + span > 1.0:
		return false
	if not _over_road(layout, at):
		return false

	var clear := coin_clearance / half_width
	for placement in placements:
		# Pads and forks are paint and bookkeeping; a coin over either is a
		# coin on the road. Rings are kept off by the keep-out rule instead -
		# a ring is a checkpoint, and every checkpoint is already in it - which
		# is the only rule here that knows about how high a thing stands.
		if (placement.kind != OBSTACLE and placement.kind != TRAP
				and placement.kind != WEDGE and placement.kind != PLATFORM):
			continue
		if (at + coin_room < placement.offset
				or at - coin_room > placement.offset + placement.length):
			continue
		for pose in placement.sweep(sweep_step / half_width):
			if absf(lateral - pose) < span + clear + placement.half_span:
				return false

	# And a car that lined itself up for the coin has to be able to hold that
	# line through whatever is standing a moment further on. Rows that stand
	# still only: a trap is somewhere else by the time the car gets there, and
	# a coin is already kept out of everywhere one passes through.
	for row in rows():
		if row.moves():
			continue
		var run := row.centre() - at
		if run <= 0.0 or run > coin_run_up:
			continue
		if not _inside_a_gap(gaps_at(layout, row.centre()), lateral, span):
			return false

	return _inside_a_gap(gaps_at(layout, at), lateral, span)


## Whether a coin at `lateral`, reaching `span` either side of it, sits wholly
## inside one of these ways past.
func _inside_a_gap(gaps: Array[Vector2], lateral: float, span: float) -> bool:
	for gap in gaps:
		if lateral - span >= gap.x and lateral + span <= gap.y:
			return true
	return false


## Whether there is road under an offset at all: past the end of a course, or
## over the hole in a jump, there is not.
func _over_road(layout: TrackLayout, at: float) -> bool:
	if at < 0.0 or at > layout.length():
		return false
	for span in reserved:
		if at > span.x and at < span.y:
			return false
	if layout.road_present.is_empty():
		return true
	var sample := clampi(
		int(round(at / layout.step)), 0, layout.road_present.size() - 1)
	return layout.road_present[sample] != 0


func _too_near_a_coin(at: float, spacing: float) -> bool:
	for coin in of_kind(COIN):
		if absf(at - coin.centre()) < spacing:
			return true
	return false


## The row of barriers a car at this offset has just got past, if it got past
## one recently enough to still be on the line it took.
func _row_just_behind(at: float) -> Placement:
	var nearest: Placement = null
	var least := INF
	for row in rows():
		if row.moves():
			continue
		var behind := at - (row.offset + row.length)
		if behind < coin_dodge_run.x or behind > coin_dodge_run.y:
			continue
		if behind < least:
			least = behind
			nearest = row
	return nearest


## The middle of the widest way past a row, or INF if it leaves none.
func _widest_gap(layout: TrackLayout, row: Placement) -> float:
	var widest := INF
	var most := 0.0
	for gap in gaps_past(layout, row):
		if gap.y - gap.x > most:
			most = gap.y - gap.x
			widest = (gap.x + gap.y) * 0.5
	return widest


func _piece_at(layout: TrackLayout, at: float) -> TrackLayout.Piece:
	for piece in layout.pieces:
		if at >= piece.start_offset and at < piece.end_offset:
			return piece
	return null


# --- checking the plan --------------------------------------------------

## The stretches of road left open across the course at one offset, after
## everything standing there has been taken out of it. Spans too narrow for a
## car to fit through are not gaps and are not returned.
## `extra` is a placement being considered but not yet part of the plan, which
## is what lets the planner ask what a row it is about to lay down would leave
## open. Without it the answer comes back as the road with everything on it
## except the one thing being asked about.
## `poses` says where a trap is standing for the question, as placement ->
## lateral. A trap left out of it is asked about where it stands at GO.
func gaps_at(
	layout: TrackLayout, offset: float, extra: Placement = null,
	poses := {}
) -> Array[Vector2]:
	var clear := clear_lane / maxf(layout.half_width_at(offset), 0.001)
	var open: Array[Vector2] = []
	var edge := -1.0
	for span in _blocked_at(offset, extra, poses):
		if span.x - edge >= clear:
			open.append(Vector2(edge, span.x))
		edge = maxf(edge, span.y)
	if 1.0 - edge >= clear:
		open.append(Vector2(edge, 1.0))
	return open


## The ways past one row, for whatever wants to talk about a single barrier.
func gaps_past(layout: TrackLayout, barrier: Placement) -> Array[Vector2]:
	return gaps_at(layout, barrier.centre())


## The ways past a row in every place it passes through, one set of gaps per
## place - a single set for a row that stands still. `extra` is as for gaps_at,
## and is usually the row itself, before it has been laid down.
func gap_sets(
	layout: TrackLayout, row: Placement, side := Vector2(-1.0, 1.0),
	extra: Placement = null
) -> Array:
	var half_width := maxf(layout.half_width_at(row.centre()), 0.001)
	var sets: Array = []
	for at in row.sweep(dodge_step / half_width):
		sets.append(_gaps_within(layout, row.centre(), side, extra, {row: at}))
	return sets


## Everything standing across the road at one offset, merged, so two barriers
## that overlap - a row inside a lane and the divider beside it - count as the
## one obstruction they look like rather than as two.
func _blocked_at(
	offset: float, extra: Placement = null, poses := {}
) -> Array[Vector2]:
	var spans: Array[Vector2] = []
	var standing := placements.duplicate()
	if extra != null:
		standing.append(extra)
	for placement in standing:
		if placement.kind != OBSTACLE and placement.kind != TRAP:
			continue
		if offset < placement.offset or offset > placement.offset + placement.length:
			continue
		var at: float = poses.get(placement, placement.lateral)
		spans.append(Vector2(at - placement.half_span, at + placement.half_span))
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)

	var merged: Array[Vector2] = []
	for span in spans:
		if not merged.is_empty() and span.x <= merged[-1].y:
			merged[-1] = Vector2(merged[-1].x, maxf(merged[-1].y, span.y))
		else:
			merged.append(span)
	return merged


## Why the plan cannot be driven, or an empty array if it can be.
##
## Two things have to hold, and neither is visible from looking at one row.
## Every row has to leave a way past - counting whatever else is standing
## beside it, which is why the gaps are read off the whole road rather than
## off the row on its own. And the way past one row has to be reachable from
## the way past the row before it: two rows blocking opposite sides are each
## perfectly passable alone and are a dead end together, if they sit close
## enough that no car could cross between them.
##
## A trap has to satisfy both in every place it passes through, not only the
## places it rests, and against every place the row beside it can be. That is
## the worst case rather than what the clock actually lines up, on purpose: a
## player who is slower or faster than the course expects meets a different
## pair of places, and a road that is only driveable at the right speed is a
## road some players cannot get down.
##
## Walls running along the road are stepped over rather than checked as rows.
## A divider is not something to be dodged; it is something that narrows what
## the rows either side of it leave open, and it does that by being merged
## into their gaps.
func faults(layout: TrackLayout) -> PackedStringArray:
	var found := PackedStringArray()
	found.append_array(_check_the_traps())
	found.append_array(_check_the_way_past(
		layout, of_kind(OBSTACLE) + of_kind(TRAP), ""))
	found.append_array(_check_the_dodges(layout, rows(), ""))

	# And the fast lane of every fork on its own. The divider means a car in
	# one cannot cross out of it, so a lane that closes up is a dead end even
	# though the course around it is perfectly driveable.
	for fork in of_kind(FORK):
		var side := Vector2(-1.0, 0.0) if fork.lateral < 0.0 else Vector2(0.0, 1.0)
		var inside: Array[Placement] = []
		for row in rows():
			if row.offset >= fork.offset and row.offset < fork.offset + fork.length:
				inside.append(row)
		found.append_array(_check_the_way_past(layout, inside, "the fast lane of ", side))
		found.append_array(_check_the_dodges(layout, inside, "the fast lane of ", side))
	found.append_array(_check_the_rings(layout))
	found.append_array(_check_the_coins(layout))
	return found


## What a coin can get wrong where it stands.
##
## The same question `_coin_fits` asks when one is being placed, asked again of
## the finished plan - which is how a coin written into a track file by hand is
## held to what a rolled one is held to, and how a coin the planner put down
## before something else moved is caught.
##
## How many coins a course carries is not asked here. A course with none is not
## a course that cannot be driven, which is what this function is for; it is a
## course that pays nothing, and `tools/checks/coins.gd` is where that is
## counted, over a hundred of them at a time.
func _check_the_coins(layout: TrackLayout) -> PackedStringArray:
	var found := PackedStringArray()
	for coin in of_kind(COIN):
		var at := "coin at %.0f m, lane %+.2f" % [coin.centre(), coin.lateral]
		if _too_close_to_keep_out(coin.centre()):
			found.append("%s: it is on the grid, the finish or a respawn" % at)
		if not _over_road(layout, coin.centre()):
			found.append("%s: there is no road under it" % at)
		elif absf(coin.lateral) + coin.half_span > 1.0:
			found.append("%s: it hangs over the kerb" % at)
		elif not _coin_fits(layout, coin.centre(), coin.lateral):
			found.append("%s: it is inside something, or behind it" % at)
	return found


## What a ring can get wrong where it stands. Whether a car can actually fly
## through one is a question for a car, and tools/checks/rings.gd asks it.
func _check_the_rings(layout: TrackLayout) -> PackedStringArray:
	var found := PackedStringArray()
	for ring in of_kind(RING):
		var at := "ring at %.0f m" % ring.centre()
		for lateral in ring.sweep(0.05):
			if absf(lateral) > 1.0:
				found.append("%s: it moves off the road, to %+.2f" % [at, lateral])
				break
		# Its rim clear of the road under it, with room for the tube. A ring
		# with its foot in the asphalt is a wall with a hole in it. Over the
		# hole in a jump there is no road under it to be in.
		var sample := clampi(int(round(ring.centre() / layout.step)), 0, layout.road_present.size() - 1)
		var over_road := layout.road_present.is_empty() or layout.road_present[sample] != 0
		if over_road and ring.height < ring.radius + ring_rim:
			found.append("%s: its rim is in the road (%.1f m up, %.1f m across)"
				% [at, ring.height, ring.radius])
		# Its middle over the road rather than over the grass, so a car
		# lined up with it is a car on the road.
		if absf(ring.lateral) > 1.0:
			found.append("%s: its middle is off the road" % at)
		if ring.centre() < 0.0 or ring.centre() > layout.length():
			found.append("%s: it is not on the course" % at)
	for kicker in of_kind(WEDGE):
		if absf(kicker.lateral) + kicker.half_span > 1.0:
			found.append("kicker at %.0f m: it hangs off the road" % kicker.offset)
	for platform in of_kind(PLATFORM):
		var at := "platform at %.0f m" % platform.offset
		# It may hang a little past where the kerb would be - there is no kerb
		# in a hole - but not so far that a car lined up with the road below
		# it could never reach it.
		for lateral in platform.sweep(0.05):
			if absf(lateral) + platform.half_span > 1.25:
				found.append("%s: it moves off the road, to %+.2f" % [at, lateral])
				break
		if platform.half_span * 2.0 < 0.3:
			found.append("%s: it is too narrow to land a car on" % at)
		if platform.moves() and platform.travel <= 0.0:
			found.append("%s: it jumps from place to place instead of moving" % at)
	return found


## Every row that stands across the road, in the order they are met - traps
## included. Walls running along it - a fork's divider - are not rows and are
## left out.
func rows() -> Array[Placement]:
	var rows: Array[Placement] = []
	for placement in placements:
		if (placement.kind == TRAP
				or (placement.kind == OBSTACLE and not placement.along)):
			rows.append(placement)
	rows.sort_custom(func(a: Placement, b: Placement) -> bool:
		return a.offset < b.offset)
	return rows


## What a trap can get wrong on its own, before the road is asked about.
##
## Two traps may not stand beside each other along the road: the checks below
## follow one trap through its places with everything else where it stands at
## GO, and two moving together have combinations that would never be looked
## at. And a trap has to take time to get anywhere, or it is a barrier that
## appears on top of whoever was in its gap.
func _check_the_traps() -> PackedStringArray:
	var found := PackedStringArray()
	var traps := of_kind(TRAP)
	for i in traps.size():
		var trap := traps[i]
		if trap.phases.size() < 2:
			found.append("the trap at %.0f m has nowhere to move to" % trap.offset)
		if trap.travel <= 0.0:
			found.append("the trap at %.0f m jumps across the road instead of moving"
				% trap.offset)
		if trap.dwell < 0.0:
			found.append("the trap at %.0f m holds for less than no time" % trap.offset)
		for other in traps.slice(i + 1):
			if (trap.offset < other.offset + other.length
					and other.offset < trap.offset + trap.length):
				found.append("the traps at %.0f m and %.0f m stand beside each other"
					% [trap.offset, other.offset])
	return found


## Nothing may close the road, or the part of it named by `side` - wherever a
## trap has got to.
func _check_the_way_past(
	layout: TrackLayout, rows: Array[Placement], what: String,
	side := Vector2(-1.0, 1.0)
) -> PackedStringArray:
	var found := PackedStringArray()
	for row in rows:
		var half_width := maxf(layout.half_width_at(row.centre()), 0.001)
		for at in row.sweep(sweep_step / half_width):
			if not _gaps_within(layout, row.centre(), side, null, {row: at}).is_empty():
				continue
			if row.moves():
				found.append("%sthe trap at %.0f m closes the road on its way through %+.2f"
					% [what, row.offset, at])
			else:
				found.append("%sthe road at %.0f m has no way past" % [what, row.offset])
			break
	return found


## Every row has to be reachable from the one before it, from wherever either
## of them has got to.
func _check_the_dodges(
	layout: TrackLayout, rows: Array[Placement], what: String,
	side := Vector2(-1.0, 1.0)
) -> PackedStringArray:
	var found := PackedStringArray()
	var previous: Placement = null
	var previous_sets: Array = []
	for row in rows:
		var sets := gap_sets(layout, row, side)
		if previous != null:
			var half_width := maxf(layout.half_width_at(row.centre()), 0.001)
			var shift := _worst_shift(previous_sets, sets, car_width / half_width) * half_width
			var run := row.centre() - previous.centre()
			var needed := _road_to_cross(shift)
			if run < needed:
				found.append(
					"%sthe row at %.0f m needs %.1f m from the middle of the one before, has %.1f m%s"
					% [what, row.offset, needed, run,
						" at worst" if row.moves() or previous.moves() else ""])
		previous = row
		previous_sets = sets
	return found


## The ways past at an offset, kept to one side of the road.
func _gaps_within(
	layout: TrackLayout, offset: float, side: Vector2, extra: Placement = null,
	poses := {}
) -> Array[Vector2]:
	var kept: Array[Vector2] = []
	var clear := clear_lane / maxf(layout.half_width_at(offset), 0.001)
	for gap in gaps_at(layout, offset, extra, poses):
		var cut := Vector2(maxf(gap.x, side.x), minf(gap.y, side.y))
		if cut.y - cut.x >= clear:
			kept.append(cut)
	return kept


## How far a car `width` wide has to move across the road to get from any one
## of these spans to any one of those, in lateral units: how far its middle
## moves, from the nearest place it fits through one to the nearest place it
## fits through the other.
##
## That is the room between the two spans plus the car's own width - or, where
## they overlap, the car's width less the overlap. Two spans that only touch
## still ask for a whole car's width of crossing, since a car does not fit
## through a point, and only spans overlapping by at least the car's width are
## the case where it can drive straight through both. Every span is at least a
## clear lane wide, so the car fits through each of them on its own.
func _shift_between(from: Array[Vector2], to: Array[Vector2], width: float) -> float:
	var least := INF
	for a in from:
		for b in to:
			least = minf(least, maxf(0.0, maxf(b.x - a.y, a.x - b.y) + width))
	return 0.0 if least == INF else least


## The furthest apart the ways past two rows can be, for a car `width` wide,
## over every place each of them can be in. A set with no gaps in it is
## skipped: that is a road with no way past, which is its own fault and not a
## distance.
func _worst_shift(from_sets: Array, to_sets: Array, width: float) -> float:
	var worst := 0.0
	for from: Array[Vector2] in from_sets:
		if from.is_empty():
			continue
		for to: Array[Vector2] in to_sets:
			if to.is_empty():
				continue
			worst = maxf(worst, _shift_between(from, to, width))
	return worst


## The least road a car moving `shift` metres across it needs, in metres from
## the middle of one row to the middle of the next: the root of 4Rd, for the
## turn in and back out that `_run_for` describes.
##
## From the middles rather than from where one row ends to where the next
## begins, because the car does not have to be square all the way through a
## row. Weaving from one gap to the next it is square at the top of each
## swing, and a row is short enough to put that in the middle of it: over half
## of one, 1.2 m, a car turning at a 16 m radius comes back across the road by
## less than 5 cm. Counting from the ends instead leaves a row's length of
## turning out of the sum, and on rows 20 m apart that is 1.4 m of crossing
## the car does have.
func _road_to_cross(shift: float) -> float:
	return sqrt(4.0 * dodge_radius * maxf(shift, 0.0))
