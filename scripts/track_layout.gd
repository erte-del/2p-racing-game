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


## One piece of track, described from its entry socket to its exit socket.
class Piece:
	var kind: int
	var length: float      ## metres along the centreline
	var turn: float        ## radians; positive turns right, zero for straights
	var radius: float      ## corner radius in metres, 0 for straights
	var rise: float        ## metres of height gained across the piece
	var half_width: float

	func _init(p_kind: int, p_length: float, p_half_width: float) -> void:
		kind = p_kind
		length = p_length
		half_width = p_half_width
		turn = 0.0
		radius = 0.0
		rise = 0.0


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
var pieces: Array[Piece] = []


## Build a course. Returns null if this seed produced one that crosses itself
## or runs off the ground; the caller should try another.
static func build(track_seed: int, tuning: Dictionary = {}) -> TrackLayout:
	var layout := TrackLayout.new()
	for key in tuning:
		layout.set(key, tuning[key])

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

	pieces.append(_quantise(Piece.new(STRAIGHT, apron, wide_half_width)))


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

	var position := Vector3.ZERO
	var yaw := 0.0

	for piece in pieces:
		var steps: int = maxi(1, int(round(piece.length / step)))
		var turn_per_step := piece.turn / float(steps)
		for i in steps:
			points.append(position)
			half_widths.append(piece.half_width)
			var from := smoothstep(0.0, 1.0, float(i) / float(steps))
			var to := smoothstep(0.0, 1.0, float(i + 1) / float(steps))
			var heading := Vector3.FORWARD.rotated(Vector3.UP, yaw)
			position += heading * step + Vector3.UP * (piece.rise * (to - from))
			# Positive turn is a right-hand turn, which is a negative rotation
			# about the up axis in Godot's right-handed space.
			yaw -= turn_per_step
	# Close off the final piece so the road reaches the finish line.
	points.append(position)
	half_widths.append(pieces[-1].half_width if not pieces.is_empty() else wide_half_width)


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
