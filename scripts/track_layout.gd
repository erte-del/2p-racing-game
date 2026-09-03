class_name TrackLayout
extends RefCounted

## Chains modular track pieces - straights, corners and climbs - into a
## point-to-point course, and hands back the centreline the mesh builder walks.
##
## Pieces join at sockets: each one starts exactly where the last ended, with
## the same heading and height, so a seam can never gap or kink. The course
## runs from a start apron to a finish apron and does not return to its start,
## which is what keeps generation simple: there is no closure constraint, so
## corner angles, directions and climbs can all be chosen freely.
##
## Two things can still go wrong and are checked for, with the caller retrying
## on another seed: the course can wander into itself, and it can wander off
## the ground.

const STRAIGHT := 0
const CORNER := 1
const CLIMB := 2
## A ramp, a hole in the road, and a long flat run to come down on. The piece
## is height neutral: it lifts the road to the lip and the landing puts it
## back where it started, so a jump never moves the course up or down.
const JUMP := 3


## One piece of track, described from its entry socket to its exit socket.
class Piece:
	var kind: int
	var length: float      ## metres along the centreline
	var turn: float        ## radians; positive turns right, zero for straights
	var radius: float      ## corner radius in metres, 0 for straights
	var rise: float        ## metres of height gained across the piece
	var half_width: float
	## Where the piece begins and ends, as a distance along the finished
	## course. Filled in by _sample(). These are what let anything placed on
	## the course - a boost pad, a hazard - go somewhere chosen rather than
	## somewhere random: they are measured in the same offsets as the curve,
	## the finish line and the checkpoints.
	var start_offset: float
	var end_offset: float

	func _init(p_kind: int, p_length: float, p_half_width: float) -> void:
		kind = p_kind
		length = p_length
		half_width = p_half_width
		turn = 0.0
		radius = 0.0
		rise = 0.0
		start_offset = 0.0
		end_offset = 0.0


# --- tunables, set by Track ---------------------------------------------

var step := 2.5                  ## sampling distance along the centreline
var min_length := 620.0          ## how long a course to build, in metres
var max_length := 1050.0
var apron := 55.0                ## straight run at the start and the finish
var min_corner_radius := 11.0    ## the car can hold ~6.5 m at a crawl
var max_corner_radius := 45.0
var min_corner := 22.0           ## degrees
var max_corner := 145.0
var min_straight := 28.0
var max_straight := 110.0
var narrow_half_width := 4.2
var wide_half_width := 8.0
## Corners at or below this radius get the narrowest road.
var narrow_radius := 22.0
## Corners at or above this radius get the full width.
var wide_radius := 55.0
var max_climb := 5.0             ## metres of rise on a single climb piece

# --- jumps --------------------------------------------------------------

## Metres of ramp, and how high it lifts the road. Between them these set the
## angle a car leaves at: 4 m over 10 m is about 22 degrees. Shallower reads
## better but does not work - a car is a single long box, and coming off a
## gentle ramp it settles onto its own back end and drops off the lip instead
## of being thrown from it.
var ramp_length := 14.0
var ramp_rise := 5.0
## How the rise is spread along the ramp. One is a straight wedge; above one
## curves the foot into the road and leaves the steepest part at the lip,
## which is where the angle actually does any work.
var ramp_curve := 1.5
## The hole. Two things pin this from either side. It has to be short enough
## that a car at the slowest speed the game can roll still sails over it,
## since falling in costs a respawn and a jump nobody can clear is not a risk
## but a wall. And it has to be a good deal longer than the car, which is
## 4.87 m: a hole a car can lie across is one it drives over without ever
## leaving the ground.
var jump_gap := 17.0
## Flat road to come down on. Long, because the range of a jump is decided by
## the speed it is taken at: the same ramp puts a car down 11 m past the lip
## at the slowest the game rolls and 61 m past it at the fastest, so the
## landing has to reach the far end of that.
var landing_length := 90.0
## The straight a jump needs in front of it, so a car arrives at the ramp with
## speed it chose rather than speed it happened to have.
var jump_run_up := 45.0
## The chance a long enough straight is followed by a jump.
var jump_chance := 0.45
## How many jumps a course may have.
var max_jumps := 3
## How far above or below its starting height the course may wander. The
## whole course is lifted so its lowest point rests on the ground, so this
## also sets how high the tallest embankment ends up.
var height_limit := 5.0
## Metres the course must keep from itself. The road is at most 18.2 m wide
## across both kerbs, so anything above that stops two passes touching; the
## margin above it is what decides how tightly the course may double back.
var clearance := 20.0
var extent := 480.0              ## the course must fit inside this half-size

# --- results ------------------------------------------------------------

var points := PackedVector3Array()
var half_widths := PackedFloat32Array()
## Whether there is road at each sample. False across the hole in a jump,
## where the mesh, the kerbs and the rails all stop and a car that came up
## short has nothing under it.
var road_present := PackedByteArray()
var pieces: Array[Piece] = []


## Build a course. Returns null if this seed produced one that crosses itself
## or runs off the ground; the caller should try another.
static func build(track_seed: int, tuning: Dictionary = {}) -> TrackLayout:
	var layout := TrackLayout.new()
	for key in tuning:
		layout.set(key, tuning[key])

	# The ramp and the hole are snapped to the sampling grid before anything
	# is built from them. A hole of six and a half metres sampled every two
	# and a half comes out as ten metres of missing road, which is a very
	# different jump from the one the numbers describe.
	layout.ramp_length = round(layout.ramp_length / layout.step) * layout.step
	layout.jump_gap = round(layout.jump_gap / layout.step) * layout.step

	var rng := RandomNumberGenerator.new()
	rng.seed = track_seed
	layout._choose_pieces(rng)
	layout._sample()
	if layout._crosses_itself() or not layout._fits():
		return null
	layout._centre()
	layout._smooth_widths()
	return layout


## Distance from the start line to the finish line.
func length() -> float:
	return maxf(float(points.size() - 1), 0.0) * step


## Half-width of the road at a distance along the course.
func half_width_at(offset: float) -> float:
	if half_widths.is_empty():
		return wide_half_width
	var i := clampi(int(offset / step), 0, half_widths.size() - 1)
	return half_widths[i]


# --- choosing the pieces ------------------------------------------------

func _choose_pieces(rng: RandomNumberGenerator) -> void:
	var target := rng.randf_range(min_length, max_length)
	pieces = [_quantise(Piece.new(STRAIGHT, apron, wide_half_width))]
	var built := apron
	var height := 0.0
	var jumps := 0
	# Alternating most corners left and right keeps the course travelling
	# somewhere rather than spiralling in on itself, which is the main way a
	# free-form chain fails the self-crossing check.
	var direction := 1.0 if rng.randf() < 0.5 else -1.0

	while built < target - apron:
		var angle: float = deg_to_rad(rng.randf_range(min_corner, max_corner))
		var radius := rng.randf_range(min_corner_radius, max_corner_radius)
		# A hairpin wants to be tight; a long sweeper wants room.
		if angle > deg_to_rad(100.0):
			radius = minf(radius, max_corner_radius * 0.4)
		var corner := _make_corner(angle * direction, radius)
		pieces.append(corner)
		built += corner.length

		# Mostly alternate, but hold the same way now and then for a double
		# apex or a long multi-part curve.
		if rng.randf() < 0.72:
			direction = -direction

		var straight := _quantise(Piece.new(
			STRAIGHT, rng.randf_range(min_straight, max_straight), wide_half_width))
		# A climb, as long as it does not drift too far from the start height.
		if straight.length > min_straight * 1.5 and rng.randf() < 0.42:
			var rise := rng.randf_range(3.0, max_climb)
			# Fall as often as climb, and turn back if the course has drifted
			# too far from the height it started at.
			if rng.randf() < 0.5:
				rise = -rise
			if absf(height + rise) > height_limit:
				rise = -rise
			if absf(height + rise) <= height_limit:
				straight.kind = CLIMB
				straight.rise = rise
				height += rise
		pieces.append(straight)
		built += straight.length

		# A jump goes after a straight rather than in place of one, so the
		# straight is the run up: a car reaches the ramp with the speed it
		# chose to carry rather than whatever it happened to have coming out
		# of the corner behind it. A level straight only - taking off from a
		# grade would throw the car at an angle nothing else on the course
		# accounts for.
		if (jumps < max_jumps and straight.kind == STRAIGHT
				and straight.length >= jump_run_up
				and built < target - apron - _jump_length()
				and rng.randf() < jump_chance):
			pieces.append(_make_jump())
			built += _jump_length()
			jumps += 1

	pieces.append(_quantise(Piece.new(STRAIGHT, apron, wide_half_width)))


## The ramp, the hole and the landing, as one piece.
func _make_jump() -> Piece:
	var piece := Piece.new(JUMP, _jump_length(), wide_half_width)
	# Height neutral, so the course carries on at the height it arrived at and
	# the height budget a climb is checked against is untouched.
	piece.rise = 0.0
	return _quantise(piece)


func _jump_length() -> float:
	return ramp_length + jump_gap + landing_length


func _make_corner(turn: float, radius: float) -> Piece:
	var piece := Piece.new(CORNER, absf(turn) * radius, _width_for_radius(radius))
	piece.turn = turn
	piece.radius = radius
	return _quantise(piece)


## Round a piece to a whole number of samples, so every point on the finished
## centreline is exactly `step` from the next and offsets index it directly.
func _quantise(piece: Piece) -> Piece:
	var steps: int = maxi(1, int(round(piece.length / step)))
	piece.length = float(steps) * step
	return piece


## Tight corners get a narrow road, open sweepers the full width.
func _width_for_radius(radius: float) -> float:
	var openness := clampf(
		(radius - narrow_radius) / (wide_radius - narrow_radius), 0.0, 1.0)
	return lerpf(narrow_half_width, wide_half_width, openness)


# --- walking the pieces -------------------------------------------------

## Walk the chain, recording the centreline. Vertical movement is eased in and
## out across a climb so the grade starts and ends flat, which is what stops a
## visible crease where a climb meets a level piece.
func _sample() -> void:
	points = PackedVector3Array()
	half_widths = PackedFloat32Array()

	road_present = PackedByteArray()

	var position := Vector3.ZERO
	var yaw := 0.0
	## The height the road sits at either side of the piece being walked. Only
	## a climb moves it; a jump lifts the road and puts it back, so its own
	## shape is worked out against this rather than added to it.
	var base := 0.0

	var travelled := 0.0

	for piece in pieces:
		var steps: int = maxi(1, int(round(piece.length / step)))
		# Every piece is quantised to a whole number of samples, so walking
		# the steps and adding up the lengths give the same answer and these
		# offsets land exactly on a sample.
		piece.start_offset = travelled
		travelled += float(steps) * step
		piece.end_offset = travelled
		var turn_per_step := piece.turn / float(steps)
		for i in steps:
			var along := float(i) / float(steps)
			position.y = base + _profile(piece, along)
			points.append(position)
			half_widths.append(piece.half_width)
			road_present.append(1 if _road_at(piece, along) else 0)
			var heading := Vector3.FORWARD.rotated(Vector3.UP, yaw)
			position += heading * step
			# Positive turn is a right-hand turn, which is a negative rotation
			# about the up axis in Godot's right-handed space.
			yaw -= turn_per_step
		base += piece.rise
	# Close off the final piece so the road reaches the finish line.
	position.y = base
	points.append(position)
	half_widths.append(pieces[-1].half_width if not pieces.is_empty() else wide_half_width)
	road_present.append(1)


## How high above the road either side of it a piece stands, a fraction of the
## way along it.
##
## A climb is eased in and out so the grade starts and ends flat, which is what
## stops a visible crease where it meets a level piece. A jump is the opposite
## and is deliberately not eased: the lip is meant to be an edge, and easing it
## would round off the one part of it that does the work.
func _profile(piece: Piece, along: float) -> float:
	if piece.kind == JUMP:
		var at := along * piece.length
		if at < ramp_length:
			# Eased at the foot and steepest at the lip. A ramp that meets the
			# road at its full angle is a crease, and a car driving at one is
			# a long flat box catching its front edge on it: it climbs a
			# little way and then jams there and stops dead. Coming up out of
			# the road instead gives it nothing to catch on, and putting the
			# steepest part at the top is what a ramp should be doing anyway.
			return ramp_rise * pow(at / ramp_length, ramp_curve)
		if at < ramp_length + jump_gap:
			# The line the road would take if it were there, which is roughly
			# what a car crossing the hole is doing anyway.
			return ramp_rise * (1.0 - (at - ramp_length) / jump_gap)
		return 0.0
	return piece.rise * smoothstep(0.0, 1.0, along)


## Whether there is road at a fraction of the way along a piece.
func _road_at(piece: Piece, along: float) -> bool:
	if piece.kind != JUMP:
		return true
	var at := along * piece.length
	# The lip itself is road: it is the last cross-section the car has under
	# it, and without it the road stops a whole sample short of the top of the
	# ramp and the jump is taken from partway up.
	return at <= ramp_length + 0.001 or at >= ramp_length + jump_gap - 0.001


## Shift the whole course so it sits centred on the world origin and never
## dips below the ground.
##
## The ground is one flat plane, so a descending section does not cut into a
## hillside, it is simply buried: the road disappears under the grass and the
## cars drive over the top of it. Lifting the lowest point of the course to
## ground level keeps every part of it visible.
func _centre() -> void:
	if points.is_empty():
		return
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	var shift := Vector3((lo.x + hi.x) * -0.5, -lo.y, (lo.z + hi.z) * -0.5)
	for i in points.size():
		points[i] = points[i] + shift


# --- validation ---------------------------------------------------------

## True if the course passes too close to another part of itself.
func _crosses_itself() -> bool:
	var stride: int = maxi(1, int(6.0 / step))
	var coarse := PackedVector3Array()
	for i in range(0, points.size(), stride):
		coarse.append(points[i])

	# Points near each other along the course are meant to be close; only
	# compare parts that are far apart in distance travelled.
	var skip: int = maxi(3, int(clearance * 2.0 / (step * float(stride))))
	for i in coarse.size():
		for j in range(i + skip, coarse.size()):
			var a := coarse[i]
			var b := coarse[j]
			if Vector2(a.x - b.x, a.z - b.z).length() < clearance:
				return true
	return false


## True if the course stays within the ground plane once centred.
func _fits() -> bool:
	if points.is_empty():
		return false
	var lo := points[0]
	var hi := points[0]
	for p in points:
		lo = Vector3(minf(lo.x, p.x), 0.0, minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), 0.0, maxf(hi.z, p.z))
	return (hi.x - lo.x) * 0.5 < extent and (hi.z - lo.z) * 0.5 < extent


## Blend the width across piece seams, so a narrow hairpin opens out into the
## straight instead of stepping to full width at the join. The ends are held
## rather than wrapped, because this course does not join back to itself.
func _smooth_widths() -> void:
	var count := half_widths.size()
	if count < 3:
		return
	var window: int = maxi(1, int(8.0 / step))
	for _pass in 3:
		var next := half_widths.duplicate()
		for i in count:
			var total := 0.0
			for k in range(-window, window + 1):
				total += half_widths[clampi(i + k, 0, count - 1)]
			next[i] = total / float(window * 2 + 1)
		half_widths = next
