class_name Track
extends Node3D

## Builds the world for one course: the road mesh and its collision, laid on
## flat ground.
##
## The shape itself comes from TrackLayout, which chains modular pieces. This
## node turns that centreline into geometry. Nothing here wraps from the last
## sample back to the first: a course runs from a start line to a finish line
## and does not rejoin itself, so wrapping would draw a road from the finish
## straight back to the start.

signal regenerated

## Passed straight out of the furniture: a car drove through a coin, and the
## purse has already taken it. What a HUD listens to.
signal coin_taken

@export_group("Road")
## Distance between cross-sections. Smaller is smoother and heavier.
@export var sample_step := 2.5
@export var wide_half_width := 8.0
@export var narrow_half_width := 4.2
@export var kerb_width := 1.1
## Height of the start of the course above the ground plane.
@export var road_height := 0.06

@export_group("Start line")
## Where the start line is painted, as a distance along the course. The grid
## is placed just behind it, so the cars always sit where the line says.
@export var start_line_at := 14.0
@export var start_depth := 2.5        ## metres of paint along the course

@export_group("Finish line")
## How far before the very end of the course the finish line sits. The race
## and the painted line both read this, so what the players cross is exactly
## what ends the race.
@export var finish_setback := 6.0
@export var finish_depth := 4.0      ## metres of chequer along the course
@export var finish_columns := 10     ## chequers across the road
## Lifted clear of the asphalt so the two surfaces do not z-fight.
@export var finish_lift := 0.02
## How far out the foot of an embankment sits per metre of height. Sloping it
## reads as built-up ground; a vertical face reads as a cliff.
@export var embankment_batter := 1.8
## How deep the slab under floating road is, from the road surface to its
## underside. Enough to read as a thing with weight from the ground.
@export var floating_depth := 1.2

@export_group("Rails")
## Low barrier down each edge, enough to bounce a car back onto the road
## rather than let it slide off into the grass.
@export var rail_height := 0.75
@export var rail_thickness := 0.28
@export var rail_color := Color(0.72, 0.74, 0.78)

@export_group("Checkpoints")
## Respawn points spread along the course. They are what a stuck player is
## sent back to, so they are painted as well as counted.
@export var checkpoint_count := 4
@export var checkpoint_depth := 2.5
@export var checkpoint_color := Color(0.95, 0.72, 0.12)

@export_group("Rings")
## The hole in every ring, in metres. The car is 2.06 m wide and 1.45 m tall, so
## at 3.5 a car can be about a metre and a half off the middle either way and
## still go through clean.
@export var ring_radius := 3.5
## How high the middle of the ring over a jump stands above the road the jump
## was built from. Measured, not chosen: a car that takes the ramp at anything
## from 18 m/s to flat out on a boost passes the middle of the hole with its
## body between 6.2 and 7.4 m up, and this is the middle of that.
@export var jump_ring_height := 6.8
## How far past the hole a car that banked the ring over it is put back, so a
## reset lands it on the landing rather than in the air.
@export var ring_landing_room := 8.0
## The longest a car can move in one step and still be said to have gone
## through a ring. Flat out on a boost is under a metre a step; anything longer
## is a car being put somewhere, and a teleport past a ring is not a pass.
@export var ring_longest_step := 5.0

@export_group("Platforms")
## Where a platform stands in its hole, past the lip; how long it is; the drop
## off its far end to the landing; and how high its top is above the road.
## Measured off real flights off the standard ramp: a car's wheels come down
## through 4 m about 22 m past the lip at 23 m/s, 33 m at 30 m/s and 43 m at
## 37 m/s, so a platform from 18 to 48 m catches all of them, and at 46 m/s on
## a boost a car is still 5 m up at 50 m and overflies it. The drop is short
## enough that a car rolling off the end at 20 m/s reaches the landing.
@export var platform_start := 18.0
@export var platform_length := 30.0
@export var platform_drop := 9.0
@export var platform_height := 4.0
## A lift is longer than a platform, so a car that comes down on it early can
## brake and wait for it to rise; and the step off its top onto the landing is
## short, so a car pulling away from a standstill still reaches it.
@export var lift_length := 50.0
@export var lift_drop := 3.0

@export_group("High roads")
## How far past a kicker's lip its high road starts. Far enough that the course
## below has turned away from under it, and short enough that a car off the
## kicker at 23 m/s is still above the start of the high road when it gets
## there.
@export var kicker_gap := 26.0
## The shortest straight the course may carry past where a high road drops
## back onto it. A car off the end of a high road nine metres up flies about
## thirty metres before it lands.
@export var rejoin_straight := 60.0

@export_group("Boost pads")
## Pads are laid on the long straights, clear of the corners at either end and
## clear of the grid, the finish and the respawns.
@export var boost_pads_enabled := true
## The shortest straight that can hold a pad.
@export var min_pad_straight := 40.0
## The chance an eligible straight is used, and the metres between one pad and
## the next. Both are what keep a course from turning into a chain of pads.
@export_range(0.0, 1.0) var pad_chance := 0.72
@export var min_pad_spacing := 60.0
## How far a pad keeps from the grid, the finish line and every checkpoint -
## and, with it, everything else the planner scatters on the road.
@export var pad_keep_out := 20.0
## How far anything built on the road keeps from a jump, on top of the jump's
## own length.
@export var jump_keep_out := 12.0

@export_group("Coins")
## Coins scattered along the road, picked up by driving through them and spent
## in the shop. Every course carries a handful, laid out or rolled: a track
## file describes a road, and loose change on it is not part of what it
## describes.
@export var coins_enabled := true
## How many a course carries, rolled per course. The same range under chaos, so
## a chaos run is a different race rather than the quick way to a full purse.
@export var coin_count := Vector2i(5, 15)
## Metres between one coin and the next, so a handful of them reads as a
## scattering rather than as a pile. How far a coin keeps from the grid, the
## finish and every respawn is `pad_keep_out`, which is what everything on the
## road keeps from them - a coin picked up for being put back on the road is
## not a coin anybody earned.
@export var min_coin_spacing := 18.0

@export_group("Laid out")
## A track written down rather than rolled. When this is set, generate()
## builds it and ignores the seed it was given: everything about the shape of
## the course comes from the file instead.
@export_file("*.gd") var track_file := ""

@export_group("Jumps")
## A ramp, a hole where there is no road, and a long run to come down on.
## Jumps go after a level straight of at least `jump_run_up`, which is the run
## up, and there are at most `max_jumps` to a course.
@export var jumps_enabled := true
@export var jump_run_up := 45.0
@export var max_jumps := 3
## Metres of ramp and how high it lifts the road, and how the rise is spread
## along it - above one curves the foot into the road and leaves the steepest
## part at the lip, which is where the angle does the work.
##
## The curve is held at 1.2, and the ceiling on it is a fact about the car
## rather than about taste. The road is sampled every `TrackLayout.step` (2.5 m)
## and the car's collision box is level - it never pitches to follow the road -
## so climbing a ramp is a flat-bottomed box being pushed up a staircase of
## facets. Above about 22 degrees on a facet the box's front face is buried
## deep enough in the one ahead that the depenetration cancels the whole of the
## step's forward motion, and the car stops dead reading full speed: on the
## floor, one contact, nothing moving.
##
## At 1.5 the top facet was 25.6 degrees and the one below it 23.4, and both
## The Wringer and Long Haul jammed there - The Wringer never finished at all.
## At 1.2 no facet is over 21.3 degrees and both are clean. The foot still
## curves out of the road, which is what 1.0 would give up.
##
## This is the same staircase on every jump on every track, so the margin does
## not vary by track - but it is thin, and it is `ramp_rise / ramp_length` that
## sets it. Changing either wants the slopes worked out again.
@export var ramp_length := 15.0
@export var ramp_rise := 5.0
@export var ramp_curve := 1.2
## The hole, and the road to come down on after it. The hole has to be short
## enough that a car flat out clears it and longer than the car, which is
## 4.87 m: a hole a car can lie across is one it drives over without ever
## leaving the ground. Chaos shortens it for a world where the cars are slow
## or heavy, and the check drives a car at every roll to make sure.
@export var jump_gap := 17.0
@export var landing_length := 90.0

@export_group("Barriers")
## Rows of barriers stood across part of the road on the long straights. They
## never block all of it: a row is narrowed until the gap it leaves is wide
## enough to drive through, and the next row is set far enough on that a car
## can cross from one gap to the other.
@export var obstacles_enabled := true
## The shortest straight that can hold a row, and the chance an eligible one
## is used.
@export var min_obstacle_straight := 62.0
@export_range(0.0, 1.0) var obstacle_chance := 0.5
## Metres between rows on separate straights, and the most one straight may
## hold if it has the room.
@export var min_obstacle_spacing := 70.0
@export var max_obstacle_rows := 3
## The gap that must always be left open across the road, in metres, and the
## turning circle assumed when working out whether a row can be dodged. The
## car is 2.06 m wide and washes out to a 16 m circle at speed, so these are
## the car's own numbers; change the car and these follow.
@export var clear_lane := 3.4
@export var dodge_radius := 16.0
## The chance a row takes the same part of the road as the one before it.
## Rows holding the same side can follow closely; rows swapping sides need
## most of a straight between them, so this is most of what decides how many
## barriers a course carries.
@export_range(0.0, 1.0) var same_side_chance := 0.55

@export_group("Traps")
## Rows of barriers that sweep from one kerb to the other and back on the race
## clock. A laid-out track has whatever traps its file puts on it, whatever
## this says; this is whether a rolled course gets any, and it is chaos that
## turns it on. Off otherwise, so the endless course stays the course it was.
@export var traps_enabled := false
## The chance a row on a rolled course is a trap instead of one that stands.
@export_range(0.0, 1.0) var trap_chance := 0.35

@export_group("The fork")
## One stretch of every course where the road is split down the middle: a pad
## and a run of barriers on one side, nothing at all on the other. Take the
## boost and thread the barriers, or give up the boost and have clear road.
@export var fork_enabled := true
## The shortest straight that can hold one, and the shortest and longest the
## divider itself may be.
@export var fork_min_straight := 57.0
@export var fork_divider_min := 20.0
@export var fork_divider_max := 70.0

@export_group("Shape")
@export var min_course_length := 620.0
@export var max_course_length := 1050.0
@export var min_corner_radius := 11.0
## Lower for a twistier course. Corner radius and straight length are what
## actually decide how twisty a course is; the clearance below only rejects
## courses that fold too tightly, it never makes the generator fold them.
@export var max_corner_radius := 45.0
@export var min_straight := 28.0
@export var max_straight := 110.0
## How close the course may pass to another part of itself. Lower is twistier;
## below about 19 m the road starts overlapping itself.
@export var self_clearance := 20.0
## How many seeds to try before giving up on finding a valid course.
@export var max_attempts := 60

@onready var _path: Path3D = $Path3D
@onready var _road: MeshInstance3D = $Road
@onready var _road_shape: CollisionShape3D = $RoadBody/Shape
@onready var _embankment: MeshInstance3D = $Embankment
@onready var _finish: MeshInstance3D = $FinishLine
@onready var _start: MeshInstance3D = $StartLine
@onready var _checkpoints: MeshInstance3D = $Checkpoints
@onready var _rails: MeshInstance3D = $Rails
@onready var _rail_shape: CollisionShape3D = $RailBody/Shape
@onready var _furniture: TrackFurniture = $Furniture

var _layout: TrackLayout
var _features: TrackFeatures
## The track this was laid out from, if it was laid out rather than rolled.
var _definition: TrackDefinition
## Cross-sections of the finished road.
var _points: PackedVector3Array
var _rights: PackedVector3Array
var _half_widths: PackedFloat32Array
## Whether there is road at each cross-section. False across the hole in a
## jump, where the asphalt, the kerbs, the rails and the embankment all stop.
var _road_present: PackedByteArray
## Whether there is floating road at each cross-section, drawn as a slab in the
## air rather than on an embankment.
var _floating: PackedByteArray
## How far along the curve each cross-section is. See offset_of.
var _arc: PackedFloat32Array
## True for a high road: a road off the course rather than a course, with no
## start, no finish and no checkpoints of its own, and no ends to its rails.
var is_branch := false
## The high roads off this course, built as tracks of their own.
var _branches: Array[Track] = []
var _underside: MeshInstance3D
var _slab: StandardMaterial3D

var _asphalt: StandardMaterial3D
var _kerb: StandardMaterial3D
var _earth: StandardMaterial3D
var _chequer: StandardMaterial3D
var _paint: StandardMaterial3D
var _marker: StandardMaterial3D
var _rail: StandardMaterial3D


func _ready() -> void:
	_build_materials()
	# The road and its rails are what a car counts as being on the road, which
	# is what banks a checkpoint and crosses the finish; see Car.ROAD_GROUP.
	$RoadBody.add_to_group(Car.ROAD_GROUP)
	$RailBody.add_to_group(Car.ROAD_GROUP)
	# Passed out rather than reached in for: whoever is running the race holds
	# a Track, not the furniture hanging off it, and the coins are rebuilt from
	# nothing on every course - a listener that had to find them again after
	# each one would miss the first coin of every race it forgot to.
	_furniture.coin_taken.connect(func() -> void: coin_taken.emit())


## The curve is the source of truth for progress along the course and for
## placing the cars on the grid.
func curve() -> Curve3D:
	return _path.curve


## Distance from the start line to the finish line.
func length() -> float:
	return _layout.length() if _layout else 0.0


## The pieces this course was chained from, and the furniture laid on it.
## Read by the checks in tools/, and by anything that wants to reason about
## the course rather than just drive on it.
func layout() -> TrackLayout:
	return _layout


func features() -> TrackFeatures:
	return _features


## The track this was laid out from, or null if it was rolled from a seed.
func definition() -> TrackDefinition:
	return _definition


## How far along the course the nearest point to a world position is.
##
## The curve's points are in this node's own space, so the position is brought
## into it first. That keeps the race and the grid right even if the track is
## moved or scaled, rather than silently assuming it sits at the origin.
##
## Distances along the course are the layout's: a cross-section every
## `sample_step` metres, measured across the ground. The curve measures its own
## length through the air, so every ramp, climb and drop makes it a little
## longer than the layout - on a track that climbs and falls ten metres at a
## time, most of a jump longer by the end. Everything placed on a course - a
## ring, a platform, a checkpoint, the finish - is placed in the layout's
## distances, so the curve's are turned into those before they are handed out.
func offset_of(world: Vector3) -> float:
	var along := curve().get_closest_offset(global_transform.affine_inverse() * world)
	return _layout_offset(along)


## The centreline at a distance along the course, in world space. Read off the
## cross-sections rather than the curve, for the reason offset_of gives.
func centre_at(offset: float) -> Vector3:
	if _points.size() < 2:
		return global_transform * curve().sample_baked(offset)
	var exact := clampf(offset / sample_step, 0.0, float(_points.size() - 1))
	var i := mini(int(exact), _points.size() - 2)
	return global_transform * _points[i].lerp(_points[i + 1], exact - float(i))


## A distance along the curve, as a distance along the layout.
func _layout_offset(along: float) -> float:
	if _arc.size() < 2:
		return along
	# The last cross-section at or before that far along the curve.
	var lo := 0
	var hi := _arc.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _arc[mid] <= along:
			lo = mid
		else:
			hi = mid
	var span := _arc[hi] - _arc[lo]
	var t := clampf((along - _arc[lo]) / span, 0.0, 1.0) if span > 0.0 else 0.0
	return (float(lo) + t) * sample_step


## Half-width of the road at a distance along the course.
func half_width_at(offset: float) -> float:
	if _half_widths.is_empty():
		return wide_half_width
	var i := clampi(int(offset / sample_step), 0, _half_widths.size() - 1)
	return _half_widths[i]


## Move the traps to where they stand at `seconds` on the race clock. The race
## calls this every step it is running, and with zero when it goes back to the
## line, so a trap is never anywhere the clock does not say.
func set_race_time(seconds: float) -> void:
	_furniture.run_traps(seconds)
	for road in _branches:
		if is_instance_valid(road):
			road.set_race_time(seconds)


## The pieces this course was built from, for debugging.
func piece_summary() -> String:
	if _layout == null:
		return "no course"
	var straights := 0
	var corners := 0
	var climbs := 0
	for piece in _layout.pieces:
		match piece.kind:
			TrackLayout.CORNER: corners += 1
			TrackLayout.CLIMB: climbs += 1
			_: straights += 1
	return "%d pieces (%d straights, %d corners, %d climbs), %.0f m, %s" % [
		_layout.pieces.size(), straights, corners, climbs, length(),
		_features.summary() if _features else "no furniture"]


## Build a track that was laid out by hand.
##
## The definition is handed the numbers it is not allowed to choose - how
## finely the road is sampled, and how long a jump is - and then asked to
## describe itself. What comes back is the same Piece chain and the same
## Placement list the generator and the planner produce, so everything below
## this point is the road being built, exactly as it is for a rolled course.
func lay_out(definition: TrackDefinition) -> void:
	if _asphalt == null:
		_build_materials()

	definition.step = sample_step
	definition.ramp_length = ramp_length
	definition.ramp_rise = ramp_rise
	definition.jump_gap = jump_gap
	definition.ring_radius = ring_radius
	definition.jump_ring_height = jump_ring_height
	definition.platform_start = platform_start
	definition.platform_length = platform_length
	definition.platform_drop = platform_drop
	definition.platform_height = platform_height
	definition.lift_length = lift_length
	definition.lift_drop = lift_drop
	definition.landing_length = landing_length
	definition.describe()
	_definition = definition

	_layout = TrackLayout.adopt(definition.pieces, _layout_tuning())
	_build_the_road()
	_features = TrackFeatures.adopt(definition.placements, {
		"clear_lane": clear_lane,
		"dodge_radius": dodge_radius,
		"keep_out": _keep_out(),
		"keep_out_radius": pad_keep_out,
		"reserved": jump_spans(),
	})
	# Seeded off the track's own name rather than off the file it came in -
	# a definition can be handed straight to this, with no file behind it at
	# all - so a track always has its coins in the same places. A player who
	# drove it yesterday and knows where they are is remembering the road,
	# which is the whole point of a road worth learning.
	_scatter_the_coins(hash(definition.track_name))
	_furniture.build(_points, _rights, _half_widths, sample_step, _features)
	_build_branches(definition)
	regenerated.emit()


## The high roads a track file split off the course, each a Track of its own
## standing where the course's kicker throws a car: straight ahead of the lip,
## `kicker_gap` on, across the road where the kicker is, and `rise` up.
##
## Each is stretched with straight road to reach the point where the course
## has come back underneath it, so a track file never has to add up how long
## the long way round is.
func _build_branches(definition: TrackDefinition) -> void:
	for old in _branches:
		if is_instance_valid(old):
			old.queue_free()
	_branches.clear()
	for branch: BranchDefinition in definition.branches:
		if branch.rejoin_offset < 0.0 or _points.size() < 2:
			continue
		var start := centre_at_local(branch.lip_offset)
		var forward := _forward_at(branch.lip_offset)
		var right := forward.cross(Vector3.UP)
		var reach := (centre_at_local(branch.rejoin_offset) - start).dot(forward)
		var wanted := reach - kicker_gap
		if branch.length() < wanted - sample_step * 0.5:
			var saved := branch._floating
			branch.straight(wanted - branch.length())
			branch._floating = saved
		var road: Track = load("res://scenes/track/track.tscn").instantiate()
		road.name = "HighRoad"
		road.is_branch = true
		for property in get_property_list():
			if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and property["usage"] & PROPERTY_USAGE_STORAGE:
				if property["name"] != "track_file":
					road.set(property["name"], get(property["name"]))
		add_child(road)
		road.transform = Transform3D(Basis.looking_at(forward, Vector3.UP),
			start + forward * kicker_gap + right * (branch.lane * half_width_at(branch.lip_offset))
			+ Vector3.UP * branch.rise)
		road.lay_out(branch)
		_branches.append(road)


## The high roads off this course.
func branches() -> Array[Track]:
	return _branches


## The centreline in this node's own space.
func centre_at_local(offset: float) -> Vector3:
	return global_transform.affine_inverse() * centre_at(offset)


## Which way the course is heading at a distance along it, level.
func _forward_at(offset: float) -> Vector3:
	var here := centre_at_local(offset)
	var ahead := centre_at_local(minf(offset + sample_step, length()))
	var forward := (ahead - here) * Vector3(1, 0, 1)
	return forward.normalized() if forward.length_squared() > 0.000001 else Vector3.FORWARD


## What is wrong with the high roads off this course: one that does not meet the
## course again on the line it left along, overshoots it, drops onto it from too
## low or onto anything but a straight, or passes too close to the course on the
## way. Empty for a course with none.
func branch_problems() -> PackedStringArray:
	var found := PackedStringArray()
	if _definition == null:
		return found
	var roads := 0
	for branch: BranchDefinition in _definition.branches:
		var at := "the high road at %.0f m" % branch.lip_offset
		if branch.rejoin_offset < 0.0:
			found.append("%s never ends: high_road_end() was not called" % at)
			continue
		if roads >= _branches.size():
			break
		var road := _branches[roads]
		roads += 1
		var start := centre_at_local(branch.lip_offset)
		var forward := _forward_at(branch.lip_offset)
		var back := centre_at_local(branch.rejoin_offset)
		var across := (back - start).dot(forward.cross(Vector3.UP))
		if absf(across) > 1.5:
			found.append("%s: the course comes back %.1f m to the side of the line it left on" % [at, across])
		var heading := rad_to_deg(forward.angle_to(_forward_at(branch.rejoin_offset)))
		if heading > 3.0:
			found.append("%s: the course comes back heading %.0f degrees off the way it left" % [at, heading])
		var reach := (back - start).dot(forward) - kicker_gap
		if branch.length() > reach + sample_step:
			found.append("%s is %.0f m long and the course comes back after %.0f"
				% [at, branch.length(), reach])
		var end_height := road.centre_at(road.length()).y - centre_at(branch.rejoin_offset).y
		if end_height < TrackLayout.new().overpass_clearance:
			found.append("%s ends %.1f m above the course; a car has to drop at least %.0f"
				% [at, end_height, TrackLayout.new().overpass_clearance])
		for piece in _layout.pieces:
			if (piece.start_offset <= branch.rejoin_offset + 0.01
					and piece.end_offset > branch.rejoin_offset + 0.01):
				if piece.kind != TrackLayout.STRAIGHT or piece.end_offset - branch.rejoin_offset < rejoin_straight:
					found.append("%s drops onto %s; it needs %.0f m of straight"
						% [at, "a corner" if piece.kind == TrackLayout.CORNER else "%.0f m of straight" % (piece.end_offset - branch.rejoin_offset), rejoin_straight])
		for placement in branch.placements:
			if placement.kind == TrackFeatures.RING:
				found.append("%s has a ring on it; a checkpoint on one road of a split cannot be banked from the other" % at)
				break
		found.append_array(_too_close(road, branch))
	return found


## Where a high road passes over or beside the course closer than two roads may.
func _too_close(road: Track, branch: BranchDefinition) -> PackedStringArray:
	var found := PackedStringArray()
	# Two roads side by side at the widest either can be, kerb to kerb.
	var room := wide_half_width * 2.0 + kerb_width * 2.0
	var overhead := TrackLayout.new().overpass_clearance
	var stride := maxi(1, int(5.0 / sample_step))
	for i in range(0, road._points.size(), stride):
		var high := road.global_transform * road._points[i]
		for j in range(0, _points.size(), stride):
			var along := float(j) * sample_step
			# The course where the high road leaves it and lands on it is meant
			# to be close.
			if along > branch.lip_offset - 30.0 and along < branch.lip_offset + kicker_gap:
				continue
			if along > branch.rejoin_offset - 60.0 and along < branch.rejoin_offset + rejoin_straight:
				continue
			var low := global_transform * _points[j]
			if (Vector2(high.x - low.x, high.z - low.z).length() < room
					and absf(high.y - low.y) < overhead):
				found.append("the high road at %.0f m passes %.0f m from the course at %.0f m, %.1f m above it"
					% [branch.lip_offset + kicker_gap + float(i) * sample_step,
						Vector2(high.x - low.x, high.z - low.z).length(), along, high.y - low.y])
				return found
	return found
func _layout_tuning() -> Dictionary:
	return {
		"step": sample_step,
		"min_length": min_course_length,
		"max_length": max_course_length,
		"min_corner_radius": min_corner_radius,
		"max_corner_radius": max_corner_radius,
		"min_straight": min_straight,
		"max_straight": max_straight,
		"clearance": self_clearance,
		"narrow_half_width": narrow_half_width,
		"wide_half_width": wide_half_width,
		"jump_chance": 0.45 if jumps_enabled else 0.0,
		"jump_run_up": jump_run_up,
		"max_jumps": max_jumps,
		"ramp_length": ramp_length,
		"ramp_rise": ramp_rise,
		"ramp_curve": ramp_curve,
		"jump_gap": jump_gap,
		"landing_length": landing_length,
		"centred": not is_branch,
	}


## Lay out a fresh course. The seed is advanced until one is found that neither
## crosses itself nor runs off the ground, so a bad roll costs a retry rather
## than producing a broken track.
func generate(track_seed: int) -> void:
	if not track_file.is_empty():
		var written := load(track_file) as GDScript
		if written == null:
			push_error("Track: %s is not a track" % track_file)
			return
		lay_out(written.new())
		return

	if _asphalt == null:
		_build_materials()

	var tuning := _layout_tuning()
	var layout: TrackLayout = null
	var used_seed := track_seed
	for attempt in max_attempts:
		used_seed = track_seed + attempt
		layout = TrackLayout.build(used_seed, tuning)
		if layout != null:
			break
	if layout == null:
		push_error("Track: no valid course after %d attempts" % max_attempts)
		return

	_layout = layout
	_definition = null
	_build_the_road()
	# Last, because the furniture is placed against the finished course: it
	# needs the length, and it keeps clear of the start, the finish and the
	# checkpoints, none of which are known until the road exists.
	_build_furniture(used_seed)
	regenerated.emit()


## Turn the layout into the road and everything painted on it. Shared by a
## laid-out track and a rolled one, so the two are built by the same steps.
func _build_the_road() -> void:
	_adopt(_layout)
	_build_curve()
	_build_road()
	_build_embankment()
	if is_branch:
		# A high road is part of someone else's course: nothing starts, ends or
		# is banked on it.
		_finish.mesh = null
		_start.mesh = null
		_checkpoints.mesh = null
	else:
		_build_finish_line()
		_build_start_line()
		_build_checkpoints()
	_build_rails()


## Where nothing is built: the grid, the finish and every respawn.
func _keep_out() -> PackedFloat32Array:
	var marks := PackedFloat32Array([start_offset(), finish_offset()])
	marks.append_array(checkpoint_offsets())
	return marks


## Scatter this course's coins, over whatever plan it ended up with.
##
## A pass of its own, after the plan rather than inside it, because it is the
## same pass for a rolled course and a laid-out one - and because a high road
## is not a course. Coins on one would be coins the course's own count knows
## nothing about, and a player who took the kicker would be paid for it twice
## over: once in the shortcut and once in the change.
func _scatter_the_coins(coins_seed: int) -> void:
	if _features == null or is_branch or not coins_enabled:
		return
	_features.coin_count = coin_count
	_features.min_coin_spacing = min_coin_spacing
	_features.scatter_coins(_layout, coins_seed)


## Plan the furniture for this course and put it on the road.
##
## The plan is seeded from the same seed the course was, so a given course
## always comes with the same pads on it - a seed describes a whole race,
## not just its shape.
func _build_furniture(features_seed: int) -> void:
	_features = TrackFeatures.build(_layout, features_seed, {
		"pads_enabled": boost_pads_enabled,
		"min_pad_straight": min_pad_straight,
		"pad_chance": pad_chance,
		"min_pad_spacing": min_pad_spacing,
		"keep_out": _keep_out(),
		"keep_out_radius": pad_keep_out,
		"obstacles_enabled": obstacles_enabled,
		"min_obstacle_straight": min_obstacle_straight,
		"obstacle_chance": obstacle_chance,
		"min_obstacle_spacing": min_obstacle_spacing,
		"max_obstacle_rows": max_obstacle_rows,
		"clear_lane": clear_lane,
		"dodge_radius": dodge_radius,
		"same_side_chance": same_side_chance,
		"traps_enabled": traps_enabled,
		"trap_chance": trap_chance,
		"fork_enabled": fork_enabled,
		"fork_min_straight": fork_min_straight,
		"fork_divider": Vector2(fork_divider_min, fork_divider_max),
		"reserved": jump_spans(),
	})
	_scatter_the_coins(features_seed)
	_furniture.build(_points, _rights, _half_widths, sample_step, _features)


# --- reading the layout -------------------------------------------------

func _adopt(layout: TrackLayout) -> void:
	_points = PackedVector3Array()
	for p in layout.points:
		_points.append(p + Vector3.UP * road_height)
	_half_widths = layout.half_widths
	_road_present = layout.road_present
	_floating = layout.floating

	var count := _points.size()
	_rights = PackedVector3Array()
	for i in count:
		# The last sample has no next point, so it borrows the previous
		# heading rather than wrapping round to the start.
		var a := _points[i if i < count - 1 else count - 2]
		var b := _points[i + 1 if i < count - 1 else count - 1]
		var forward := b - a
		forward.y = 0.0
		if forward.length_squared() < 0.000001:
			forward = Vector3.FORWARD
		_rights.append(forward.normalized().cross(Vector3.UP))


func _build_curve() -> void:
	var curve3d := Curve3D.new()
	# The centreline is dense and collinear along the straights, so baking up
	# vectors degenerates: consecutive tangents are identical and the cross
	# product used to carry the up vector along has no direction. Nothing here
	# uses curve tilt, so baking them is pure noise.
	curve3d.up_vector_enabled = false
	for p in _points:
		curve3d.add_point(p)
	_path.curve = curve3d
	# How far along the curve each cross-section is, through the air, which is
	# what turns the curve's distances into the layout's.
	_arc = PackedFloat32Array()
	var run := 0.0
	for i in _points.size():
		if i > 0:
			run += _points[i].distance_to(_points[i - 1])
		_arc.append(run)


# --- road --------------------------------------------------------------

func _build_road() -> void:
	var count := _points.size()
	var mesh := ArrayMesh.new()

	var asphalt := SurfaceTool.new()
	asphalt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kerbs := SurfaceTool.new()
	kerbs.begin(Mesh.PRIMITIVE_TRIANGLES)

	var run := 0.0
	for i in count - 1:
		var j := i + 1
		var run_next := run + sample_step
		# The run along the course still advances across a hole, so the road
		# on the far side of a jump carries on with the texture the road
		# before it ended on rather than starting again from nothing.
		if not _has_road(i, j):
			run = run_next
			continue

		var pi := _points[i]
		var pj := _points[j]
		var ri := _rights[i]
		var rj := _rights[j]
		var wi := _half_widths[i]
		var wj := _half_widths[j]

		_strip(asphalt, pi - ri * wi, pi + ri * wi, pj - rj * wj, pj + rj * wj, run, run_next)
		# A kerb strip either side, sitting just outside the asphalt.
		_strip(kerbs, pi - ri * (wi + kerb_width), pi - ri * wi,
				pj - rj * (wj + kerb_width), pj - rj * wj, run, run_next)
		_strip(kerbs, pi + ri * wi, pi + ri * (wi + kerb_width),
				pj + rj * wj, pj + rj * (wj + kerb_width), run, run_next)
		run = run_next

	asphalt.commit(mesh)
	kerbs.commit(mesh)
	_road.mesh = mesh
	_road.set_surface_override_material(0, _asphalt)
	_road.set_surface_override_material(1, _kerb)
	_road_shape.shape = mesh.create_trimesh_shape()


## One quad of road, given its two left and two right edge points.
func _strip(
	st: SurfaceTool, left_a: Vector3, right_a: Vector3,
	left_b: Vector3, right_b: Vector3, run_a: float, run_b: float
) -> void:
	var v := run_a / 8.0
	var v_next := run_b / 8.0
	st.set_normal(Vector3.UP)
	# Wound clockwise seen from above, which is Godot's front face. Getting
	# this backwards makes the road invisible from above and, because a
	# ConcavePolygonShape3D only collides with its front faces, drivable
	# straight through.
	for corner in [
		[left_a, 0.0, v], [right_b, 1.0, v_next], [right_a, 1.0, v],
		[left_a, 0.0, v], [left_b, 0.0, v_next], [right_b, 1.0, v_next],
	]:
		st.set_uv(Vector2(corner[1], corner[2]))
		st.add_vertex(corner[0])


## Whether there is road between two cross-sections. Both ends have to have
## it: a quad from the lip of a ramp to the first sample of thin air would
## bridge the hole the jump is made of.
func _has_road(i: int, j: int) -> bool:
	if _road_present.size() != _points.size():
		return true
	return _road_present[i] != 0 and _road_present[j] != 0


## Where the race ends, as a distance along the course.
func finish_offset() -> float:
	return maxf(length() - finish_setback, 0.0)


## Where the start line is painted. The grid sits just behind it.
func start_offset() -> float:
	return minf(start_line_at, length())


## Distances along the course where the checkpoints sit, evenly spread between
## the start and the finish - or, on a track with rings, where the rings are.
func checkpoint_offsets() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if has_rings():
		for ring in _ring_plan():
			out.append(ring.centre())
		return out
	var start := start_offset()
	var span := finish_offset() - start
	# Asked for once rather than once a checkpoint: the race reads these every
	# frame, and the spans are a walk over every piece of the course.
	var jumps := jump_spans()
	for i in checkpoint_count:
		var at := start + span * float(i + 1) / float(checkpoint_count + 1)
		out.append(_off_the_jumps(at, jumps))
	return out


## Whether this course's checkpoints are rings. A track has rings or painted
## checkpoints, never both: two kinds of checkpoint on one road is two rules for
## what finishing means.
##
## Read off the track file rather than the furniture plan, because the road is
## built before the plan is taken and the painted checkpoints are asked for then.
## A rolled course never has rings.
func has_rings() -> bool:
	return not _ring_plan().is_empty()


## The rings as they were planned, in the order a car meets them - the same
## order the furniture builds them in, so a checkpoint's index is its ring's.
func _ring_plan() -> Array[TrackFeatures.Placement]:
	var rings: Array[TrackFeatures.Placement] = []
	if _definition == null:
		return rings
	for placement in _definition.placements:
		if placement.kind == TrackFeatures.RING:
			rings.append(placement)
	rings.sort_custom(func(a: TrackFeatures.Placement, b: TrackFeatures.Placement) -> bool:
		return a.centre() < b.centre())
	return rings


## Where a car that banked a checkpoint is put back. A painted checkpoint is on
## the road, so it is where it is. A ring over a jump is over a hole, so a car
## that went through it is put down on the landing past it - it made the jump,
## and sending it back to try the ramp again would be charging it for a jump it
## already cleared.
func respawn_offset(mark: int) -> float:
	var marks := checkpoint_offsets()
	if mark < 0 or mark >= marks.size():
		return start_offset()
	var at := marks[mark]
	if not has_rings() or _layout == null:
		return at
	for piece in _layout.pieces:
		if (piece.kind == TrackLayout.JUMP
				and at > piece.start_offset and at < piece.end_offset):
			return minf(piece.start_offset + ramp_length + _layout.gap_of(piece) + ring_landing_room,
				piece.end_offset)
	return at


## Whether something moving from `from` to `to` in one step went through a
## ring, the right way, inside the hole. World positions; pass the middle of
## the car, not its origin, which sits at its wheels.
##
## Crossing the plane of the ring going forwards, and being inside the hole at
## the moment it crossed. Going through backwards does not count, and neither
## does being put on the far side of one.
func through_ring(mark: int, from: Vector3, to: Vector3) -> bool:
	var rings := _furniture.rings()
	if mark < 0 or mark >= rings.size() or not is_instance_valid(rings[mark]):
		return false
	if from.distance_to(to) > ring_longest_step:
		return false
	var ring := rings[mark].global_transform
	var middle := ring.origin
	var forward := ring.basis.y.normalized()
	var before := (from - middle).dot(forward)
	var after := (to - middle).dot(forward)
	if before >= 0.0 or after < 0.0:
		return false
	var crossed := from.lerp(to, before / (before - after))
	return crossed.distance_to(middle) < _ring_plan()[mark].radius


## Light or put out a ring, for a race to show which ones a car still owes.
func show_ring(mark: int, spent: bool) -> void:
	_furniture.show_ring(mark, spent)


## The stretches of course a jump takes up, with room either side, as spans of
## offset. Nothing else is built on one: a pad in mid air pays nobody, and a
## barrier standing on a ramp is a wall at the one place a car has to be flat
## out.
func jump_spans() -> Array[Vector2]:
	var spans: Array[Vector2] = []
	if _layout == null:
		return spans
	for piece in _layout.pieces:
		if piece.kind == TrackLayout.JUMP:
			spans.append(Vector2(
				piece.start_offset - jump_keep_out,
				piece.end_offset + jump_keep_out))
	return spans


## Move an offset clear of any jump, to whichever end of it is nearer.
##
## A respawn is the one thing that cannot simply be left off a jump: they are
## spread evenly along the course by count, so where they land is not a
## choice. Putting a car back on the road at a ramp would send it over the
## edge with no run up, and putting one back in the hole would drop it
## straight through.
func _off_the_jumps(at: float, spans: Array[Vector2]) -> float:
	for span in spans:
		if at > span.x and at < span.y:
			return span.x if at - span.x < span.y - at else span.y
	return at


## Paint a chequered band across the road at the finish, so the players can
## see where the race ends rather than having to guess from the road running
## out. It is drawn at finish_offset(), the same place the race checks.
func _build_finish_line() -> void:
	_paint_band(_finish, finish_offset(), finish_depth, _chequer, true)


## A plain band at the start. Kept visually distinct from the chequered
## finish so the two are never mistaken for each other on a new course.
func _build_start_line() -> void:
	_paint_band(_start, start_offset(), start_depth, _paint, false)


## All the checkpoint markers in one mesh, since they never differ from each
## other and there is nothing to gain from a node apiece.
func _build_checkpoints() -> void:
	# The rings are the checkpoints, and they are built with the furniture.
	# Nothing is painted on the road for them.
	if has_rings():
		_checkpoints.mesh = null
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for offset in checkpoint_offsets():
		any = _append_band(st, offset, checkpoint_depth, false, checkpoint_color) or any
	if not any:
		_checkpoints.mesh = null
		return
	_checkpoints.mesh = st.commit()
	_checkpoints.set_surface_override_material(0, _marker)


## Lay a band of paint across the full width of the road, following its
## curvature, lifted clear of the asphalt so the two do not z-fight.
func _paint_band(
	target: MeshInstance3D, offset: float, depth: float,
	material: StandardMaterial3D, chequered: bool, colour := Color.WHITE
) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if not _append_band(st, offset, depth, chequered, colour):
		target.mesh = null
		return
	target.mesh = st.commit()
	target.set_surface_override_material(0, material)


## Add one band to a surface being built, so several can share a mesh.
## Returns false if the course is too short to place it.
func _append_band(
	st: SurfaceTool, offset: float, depth: float, chequered: bool, colour: Color
) -> bool:
	var count := _points.size()
	if count < 2:
		return false

	var first := clampi(int(offset / sample_step), 0, count - 2)
	var rows: int = maxi(1, int(round(depth / sample_step)))
	var last: int = mini(first + rows, count - 1)
	if last <= first:
		return false

	var columns := finish_columns if chequered else 1
	for i in range(first, last):
		var j := i + 1
		var pa := _points[i] + Vector3.UP * finish_lift
		var pb := _points[j] + Vector3.UP * finish_lift
		var ra := _rights[i] * (_half_widths[i] + kerb_width)
		var rb := _rights[j] * (_half_widths[j] + kerb_width)
		for c in columns:
			# -1 at the left edge of the road, +1 at the right.
			var t0 := float(c) / float(columns) * 2.0 - 1.0
			var t1 := float(c + 1) / float(columns) * 2.0 - 1.0
			if chequered:
				var dark := ((i - first) + c) % 2 == 0
				st.set_color(Color(0.05, 0.05, 0.06) if dark else Color(0.95, 0.95, 0.95))
			else:
				st.set_color(colour)
			st.set_normal(Vector3.UP)
			# Same clockwise-from-above winding as the road itself.
			for v in [pa + ra * t0, pb + rb * t1, pa + ra * t1,
					pa + ra * t0, pb + rb * t0, pb + rb * t1]:
				st.add_vertex(v)
	return true


## A low barrier down each edge of the road.
##
## It stands on the outer part of the kerb rather than just beyond it, so that
## on a raised section it rests on solid road instead of hanging over the
## embankment's slope.
func _build_rails() -> void:
	var count := _points.size()
	if count < 2:
		_rails.mesh = null
		_rail_shape.shape = null
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		for i in count - 1:
			var j := i + 1
			if not _has_road(i, j):
				continue
			var outer_i := _half_widths[i] + kerb_width
			var outer_j := _half_widths[j] + kerb_width
			var ri := _rights[i] * side
			var rj := _rights[j] * side

			var in_a := _points[i] + ri * (outer_i - rail_thickness)
			var out_a := _points[i] + ri * outer_i
			var in_b := _points[j] + rj * (outer_j - rail_thickness)
			var out_b := _points[j] + rj * outer_j
			var up := Vector3.UP * rail_height

			# Inner face, top, then outer face. The material is two-sided and
			# the collision takes backfaces, so the winding of a thin barrier
			# cannot leave it invisible or drivable from one side.
			_rail_quad(st, in_a, in_b, in_a + up, in_b + up)
			_rail_quad(st, in_a + up, in_b + up, out_a + up, out_b + up)
			_rail_quad(st, out_a + up, out_b + up, out_a, out_b)

	# Cap both ends. The sides alone leave the course open behind the start
	# line and past the finish, and a car that turns round simply drives out
	# of the open end and off the raised road.
	# Not on a high road, which a car lands on at one end and drops off the
	# other.
	for i in ([] if is_branch else [0, count - 1]):
		var edge := _half_widths[i] + kerb_width
		var left := _points[i] - _rights[i] * edge
		var right := _points[i] + _rights[i] * edge
		var up := Vector3.UP * rail_height
		_rail_quad(st, left, right, left + up, right + up)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_rails.mesh = mesh
	_rails.set_surface_override_material(0, _rail)

	var shape := mesh.create_trimesh_shape()
	# A rail is a thin sheet and cars arrive at it from the inside; without
	# this they would drive through whichever way the faces happen to point.
	shape.backface_collision = true
	_rail_shape.shape = shape


func _rail_quad(st: SurfaceTool, a0: Vector3, b0: Vector3, a1: Vector3, b1: Vector3) -> void:
	for v in [a0, b0, b1, a0, b1, a1]:
		st.add_vertex(v)


## Skirt the raised parts of the road down to the ground, so a climb reads as
## an embankment instead of a ribbon floating over the grass.
##
## This carries no collision on purpose: driving off the edge of a raised
## section should drop the car onto the grass, not run it into a wall.
func _build_embankment() -> void:
	var count := _points.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false

	for i in count - 1:
		var j := i + 1
		if not _has_road(i, j):
			continue
		# Only where the road actually stands above the ground, and not where
		# it floats: that is drawn by _build_underside instead.
		if _points[i].y < 0.15 and _points[j].y < 0.15:
			continue
		if _is_floating(i) or _is_floating(j):
			continue
		any = true
		var edge_i := _half_widths[i] + kerb_width
		var edge_j := _half_widths[j] + kerb_width
		for side: float in [-1.0, 1.0]:
			var out_i := _rights[i] * side
			var out_j := _rights[j] * side
			var top_a := _points[i] + out_i * edge_i
			var top_b := _points[j] + out_j * edge_j
			# Splay the foot outwards in proportion to the height.
			var foot_a := (top_a + out_i * top_a.y * embankment_batter)
			var foot_b := (top_b + out_j * top_b.y * embankment_batter)
			foot_a.y = 0.0
			foot_b.y = 0.0
			for v in [top_a, foot_a, top_b, foot_a, foot_b, top_b]:
				st.add_vertex(v)

	if not any:
		_embankment.mesh = null
	else:
		st.generate_normals()
		_embankment.mesh = st.commit()
		_embankment.set_surface_override_material(0, _earth)
	_build_underside()


func _is_floating(i: int) -> bool:
	return i < _floating.size() and _floating[i] != 0


## The slab under floating road: a side down each edge and a face underneath,
## so road in the air reads as a thing standing there rather than a ribbon that
## vanishes when it is looked at from below. No collision - the road on top is
## what a car drives on - and none of it where there is no road.
func _build_underside() -> void:
	if _underside == null:
		_underside = MeshInstance3D.new()
		_underside.name = "Underside"
		add_child(_underside)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	var down := Vector3.DOWN * floating_depth
	for i in _points.size() - 1:
		var j := i + 1
		if not _has_road(i, j) or not (_is_floating(i) and _is_floating(j)):
			continue
		any = true
		var edge_i := _half_widths[i] + kerb_width
		var edge_j := _half_widths[j] + kerb_width
		var li := _points[i] - _rights[i] * edge_i
		var ri := _points[i] + _rights[i] * edge_i
		var lj := _points[j] - _rights[j] * edge_j
		var rj := _points[j] + _rights[j] * edge_j
		for quad in [
			[li, lj, lj + down, li + down],
			[ri, ri + down, rj + down, rj],
			[li + down, lj + down, rj + down, ri + down],
		]:
			for v in [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]:
				st.add_vertex(v)
	# Capped wherever the slab starts or stops, so its ends are not open boxes.
	for i in _points.size():
		if not _is_floating(i) or not _road_present[i]:
			continue
		var before := i > 0 and _is_floating(i - 1) and _road_present[i - 1]
		var after := i < _points.size() - 1 and _is_floating(i + 1) and _road_present[i + 1]
		if before and after:
			continue
		any = true
		var edge := _half_widths[i] + kerb_width
		var l := _points[i] - _rights[i] * edge
		var r := _points[i] + _rights[i] * edge
		for v in [l, r, r + down, l, r + down, l + down]:
			st.add_vertex(v)
	if not any:
		_underside.mesh = null
		return
	st.generate_normals()
	_underside.mesh = st.commit()
	_underside.set_surface_override_material(0, _slab)


# --- materials ---------------------------------------------------------

func _build_materials() -> void:
	_asphalt = StandardMaterial3D.new()
	_asphalt.albedo_color = Color(0.176, 0.18, 0.196)
	_asphalt.roughness = 0.92

	_kerb = StandardMaterial3D.new()
	_kerb.albedo_color = Color(0.85, 0.85, 0.87)
	_kerb.roughness = 0.8

	_earth = StandardMaterial3D.new()
	_earth.albedo_color = Color(0.28, 0.33, 0.20)
	_earth.roughness = 1.0
	# Two-sided: the skirt is a single sheet, and which way each quad faces
	# depends on the side of the road and the direction of travel.
	_earth.cull_mode = BaseMaterial3D.CULL_DISABLED

	_chequer = StandardMaterial3D.new()
	_chequer.vertex_color_use_as_albedo = true
	_chequer.roughness = 0.7

	_paint = StandardMaterial3D.new()
	_paint.vertex_color_use_as_albedo = true
	_paint.roughness = 0.7

	_marker = StandardMaterial3D.new()
	_marker.vertex_color_use_as_albedo = true
	_marker.roughness = 0.7

	_slab = StandardMaterial3D.new()
	_slab.albedo_color = Color(0.34, 0.35, 0.4)
	_slab.roughness = 0.8
	_slab.cull_mode = BaseMaterial3D.CULL_DISABLED

	_rail = StandardMaterial3D.new()
	_rail.albedo_color = rail_color
	_rail.roughness = 0.55
	_rail.metallic = 0.3
	_rail.cull_mode = BaseMaterial3D.CULL_DISABLED
