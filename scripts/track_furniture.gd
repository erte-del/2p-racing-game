class_name TrackFurniture
extends Node3D

## Emitted when a car drives through a coin, once per coin, so a tally in the
## corner of a race can flash without having to watch the purse itself.
signal coin_taken

## Turns a TrackFeatures plan into things that exist in the world: the pad
## meshes and the areas that notice a car driving over one, and the barriers
## with the solid bodies that stop one.
##
## This is the only part of the track that builds nodes per course rather than
## rewriting a mesh in place, so it clears itself out on every build. The
## endless loop lays down a fresh course after every race, and pads left over
## from the last one would pile up on the new one.

## Cyan, and emissive, so a pad still reads as a pad at midnight. The course
## runs through a whole day and night cycle, and paint that only shows up in
## sunlight would leave half the races with invisible furniture.
@export var pad_color := Color(0.16, 0.85, 1.0)
@export var pad_glow := 1.6
## The slab the chevrons sit on. Dark, so the chevrons have something to read
## against, and a shade off the asphalt so the pad has an edge to it.
@export var pad_base_color := Color(0.06, 0.13, 0.16)
## Lifted clear of the asphalt so the two surfaces do not z-fight, and the
## chevrons lifted again clear of their own slab.
@export var pad_lift := 0.03
@export var pad_chevron_lift := 0.012
## How finely the pad is cut up, along and across. The chevrons are drawn by
## colouring cells of that grid, so this is what decides how clean their
## edges look; it is deliberately independent of the road's own sampling,
## which is far too coarse to draw an arrow with.
@export var pad_cell_length := 0.7
@export var pad_columns := 9
## Rows to a chevron. With the cell length above, this is about a 2.5 m arrow.
@export var pad_chevron_rows := 4
## How far up the trigger reaches. Enough to catch a car landing on the pad,
## not so much that one sailing over it on a jump collects the boost anyway.
@export var pad_trigger_height := 1.6

@export_group("Barriers")
## Two thirds the height of the car, which is 1.45 m tall: enough to read as a
## wall from a long way back, low enough to see the road past it and pick a
## line through.
@export var barrier_height := 0.95
## Striped like roadworks, because that is what a stripe like this means
## everywhere else. The pale band is faintly emissive so a barrier is still a
## barrier at midnight, the same way the pads are.
@export var barrier_color := Color(0.86, 0.16, 0.12)
@export var barrier_stripe_color := Color(0.94, 0.94, 0.9)
@export var barrier_glow := 0.35
## Roughly how wide one stripe is, in metres. The row is cut into whole
## stripes, so the real width lands near this rather than on it.
@export var barrier_stripe_width := 0.55
## How far the foot of a barrier sits above the road, so it does not z-fight
## with the surface it stands on.
@export var barrier_lift := 0.02

@export_group("Traps")
## A trap closing on the kerb with a car in the way has nowhere to push it:
## the rail is on the other side, and a body squeezed between two walls is
## sorted out by the physics lifting it over the lower of them, which puts the
## car on top of the rail. So a car in the lane a trap is closing is shoved
## along the road instead, out of the row, at this many m/s - forwards or back,
## whichever end of the row it is already heading for.
@export var trap_shove := 10.0
## When that starts: once the trap's leading edge is this many metres from the
## car, or this many seconds from reaching it at the speed it is crossing,
## whichever comes first. The distance leaves a car threading the gap alone
## until it plainly is not going to make it; the time is what gives a fast
## trap's shove long enough to clear the car before the trap arrives.
@export var trap_shove_reach := 3.0
@export var trap_shove_lead := 0.45
## How wide a car is, for how far the trap still has to come to reach one.
const CAR_WIDTH := 2.06

@export_group("Rings")
## How thick the rim is, as the radius of the tube it is made of. Thick enough
## to read from the run up at speed; the hole is what the car goes through, and
## that is the placement's radius, not this.
@export var ring_tube := 0.32
## Gold, like the painted checkpoints it stands in for, and lit so it is still
## there at midnight. A ring that has been banked goes dark, so a player looking
## down the course can see which ones are still owed.
@export var ring_color := Color(0.95, 0.72, 0.12)
@export var ring_glow := 1.1
@export var spent_ring_color := Color(0.32, 0.34, 0.38)
## Straight pieces of solid rim the collision is made from. The drawn ring is
## round; what stops a car is a chain of this many capsules, which is close
## enough at a third of a metre thick that nothing sees the corners.
@export var ring_segments := 20

@export_group("Coins")
## Gold, and lit hard, because a coin is a small thing a long way off that a
## player has to decide about while there is still time to move. Its own gold
## rather than the rings' - a ring is a checkpoint and has to be taken, a coin
## is an offer - and the two never stand on the same stretch of road anyway,
## because a ring is a checkpoint and nothing is built near one.
@export var coin_color := Color(1.0, 0.82, 0.24)
@export var coin_glow := 2.2
## How thick the disc is, in metres. Thin enough to read as a coin, thick
## enough that it does not disappear when it turns edge on.
@export var coin_thickness := 0.14
## Turns a second, on the race clock. Slow: a coin is spinning to catch the
## light, not to be a hazard.
@export var coin_spin := 0.45
## How far the disc leans out of upright, in degrees, so that the axis it turns
## about is a cone rather than the upright itself.
##
## Without this a coin turning past square is edge on to the driver, and edge
## on it is a line a tenth of a metre wide - invisible, for about a third of a
## second, which at thirty metres a second is ten metres of road. Leaned over,
## the worst it ever shows is an ellipse this far off the full face, and a coin
## is a thing that can always be seen and decided about.
@export var coin_lean := 26.0
## How far up the box that notices a car reaches, past the coin either way.
## Generous, because a coin is taken by driving through it and a car that
## clipped the edge of one and got nothing would read as a bug.
@export var coin_trigger_margin := 0.5
## What taking one looks like: the coin lifting this far and fading out over
## this long, with a small number going up with it. Short - it is a reward,
## not an event - but not so short that a player doing thirty metres a second
## has already looked away.
@export var coin_take_rise := 1.7
@export var coin_take_seconds := 0.5
## How tall the number over a taken coin is drawn, in metres, and where it sits
## beside the coin. Off to one side rather than over it, because a coin lifting
## and a number drawn through the middle of it are two things fighting for the
## same handful of pixels.
@export var coin_number_size := 0.9
@export var coin_number_at := Vector2(0.55, 0.6)

@export_group("Platforms")
## A slab of road hanging in the air, so dark like the road, with a lit trim
## round its top edge in a colour nothing else on the course uses. Violet: the
## pads are cyan, the rings gold and the barriers red and white, and a platform
## is none of those things.
@export var platform_color := Color(0.2, 0.21, 0.25)
@export var platform_trim_color := Color(0.72, 0.36, 1.0)
@export var platform_glow := 1.6
@export var platform_thickness := 0.6
@export var platform_trim_width := 0.35
## A platform sits lower than the lip of the ramp in front of it, so from the
## run up it is hidden behind the ramp - and a platform nobody can see cannot be
## timed. So it carries a gate: a lit post up each side of its near end and a bar
## across the top, standing high enough to show over the lip from the run up,
## exactly as wide as the platform and moving with it. Paint, not a wall: it has
## no collision.
@export var platform_gate_height := 6.0
@export var platform_gate_thickness := 0.22

var _pad_material: StandardMaterial3D
var _pad_base_material: StandardMaterial3D
var _barrier_material: StandardMaterial3D
var _ring_material: StandardMaterial3D
var _spent_ring_material: StandardMaterial3D
var _platform_material: StandardMaterial3D
var _platform_trim_material: StandardMaterial3D

## The pads, so a rebuild can clear exactly what it made.
var _built: Array[Node] = []
## Every trap, with the body that moves and where across the road it moves:
## the middle of the road under it, which way is across, and how far the
## kerb is from that middle.
var _traps: Array[Dictionary] = []
## Every ring, as the node standing it up, in the order they are met along the
## course. Its transform is the ring: its origin is the middle of the hole and
## its Y axis points down the road, the way a car has to go through it.
var _rings: Array[Node3D] = []
## Everything that moves across the road on the race clock that is not a trap:
## moving rings and platforms. Each with its body, the point it moves about -
## the middle of the road under it, lifted to its height - which way is across,
## and how far the kerb is.
var _movers: Array[Dictionary] = []
## Every coin: the area that notices a car, the node inside it that turns, the
## phase its turn starts at, and whether it has been taken. A taken coin stays
## in here with its flag set rather than being dropped, because dropping it
## would renumber the rest.
var _coins: Array[Dictionary] = []
## Where the coins go, found off the tree the first time one is taken. See
## `_the_purse`.
var _purse: Node


## Lay out the furniture for a course.
##
## Everything is passed in rather than read back off the road, because the
## road is a single committed mesh by this point: the cross-sections it was
## built from are the only description of where its surface actually is.
func build(
	points: PackedVector3Array, rights: PackedVector3Array,
	half_widths: PackedFloat32Array, step: float,
	features: TrackFeatures
) -> void:
	_clear()
	if _pad_material == null:
		_build_materials()
	if points.size() < 2 or features == null:
		return

	for pad in features.of_kind(TrackFeatures.BOOST_PAD):
		_build_pad(pad, points, rights, half_widths, step)
	for barrier in features.of_kind(TrackFeatures.OBSTACLE):
		_build_barrier(barrier, points, rights, half_widths, step)
	for trap in features.of_kind(TrackFeatures.TRAP):
		_build_trap(trap, points, rights, half_widths, step)
	var rings := features.of_kind(TrackFeatures.RING)
	rings.sort_custom(func(a: TrackFeatures.Placement, b: TrackFeatures.Placement) -> bool:
		return a.centre() < b.centre())
	for ring in rings:
		_build_ring(ring, points, rights, half_widths, step)
	for platform in features.of_kind(TrackFeatures.PLATFORM):
		_build_platform(platform, points, rights, half_widths, step)
	for kicker in features.of_kind(TrackFeatures.WEDGE):
		_build_kicker(kicker, points, rights, half_widths, step)
	# Last, because a coin is the one thing here that is laid on top of the
	# road rather than being part of it.
	for coin in features.of_kind(TrackFeatures.COIN):
		_build_coin(coin, points, rights, half_widths, step)


## The rings, in the order a car meets them. What a race reads to know whether
## a car went through one.
func rings() -> Array[Node3D]:
	return _rings


## Light a ring, or put it out once it has been banked.
func show_ring(index: int, spent: bool) -> void:
	if index < 0 or index >= _rings.size() or not is_instance_valid(_rings[index]):
		return
	var mesh := _rings[index].get_node("Rim") as MeshInstance3D
	mesh.material_override = _spent_ring_material if spent else _ring_material


## Put every trap where it stands at `seconds` on the race clock.
##
## Told the time rather than keeping its own, so a trap is always where the race
## says it is: held at GO through the countdown, stopped when the race stops,
## and back at the start when the race goes back to the line.
func run_traps(seconds: float) -> void:
	# The coins turn on the same clock, for the same reason: two players on a
	# split screen should be looking at the same coin at the same angle, and a
	# race put back on the line should put them back where they were. Each one
	# starts at its own angle, taken from where it sits on the course, so a
	# course does not flash all over at once like a row of indicators.
	for coin in _coins:
		var spin: Node3D = coin["spin"]
		if is_instance_valid(spin):
			spin.rotation.y = seconds * TAU * coin_spin + float(coin["phase"])
	for mover in _movers:
		var moving: Node3D = mover["body"]
		if not is_instance_valid(moving):
			continue
		var placed: TrackFeatures.Placement = mover["placement"]
		moving.position = mover["centre"] + mover["right"] * (
				placed.lateral_at(seconds) * float(mover["half_width"])) + (
				Vector3.UP * placed.lift_at(seconds))
	for trap in _traps:
		var body: AnimatableBody3D = trap["body"]
		if not is_instance_valid(body):
			continue
		var placement: TrackFeatures.Placement = trap["placement"]
		var at := placement.lateral_at(seconds)
		var was: float = trap["at"]
		var then: float = trap["seconds"]
		trap["at"] = at
		trap["seconds"] = seconds
		body.position = trap["centre"] + trap["right"] * (
				at * float(trap["half_width"]))
		# Only when it has moved on from a step ago; a clock set back to GO
		# is the race starting again, not the trap crossing the road.
		if not is_equal_approx(at, was) and seconds > then:
			var closing := absf(at - was) * float(trap["half_width"]) / (seconds - then)
			_clear_the_way(trap, at, signf(at - was), closing)


## Shove any car out of the lane a trap is closing, along the road.
##
## Only the lane between the trap's leading edge and the kerb it is heading for
## is looked in, and only as deep as the row: a car anywhere else is either
## being pushed back towards the open road, which the physics does well on its
## own, or is not in the way at all.
func _clear_the_way(
	trap: Dictionary, at: float, heading: float, closing: float
) -> void:
	var placement: TrackFeatures.Placement = trap["placement"]
	var half_width: float = trap["half_width"]
	var right: Vector3 = trap["right"]
	var forward: Vector3 = trap["forward"]
	var edge := (at + heading * placement.half_span) * half_width
	var lane := absf(heading * half_width - edge)
	if lane < 0.01:
		return

	var box := BoxShape3D.new()
	box.size = Vector3(lane, barrier_height, placement.length)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.transform = global_transform * Transform3D(
		Basis(right, Vector3.UP, -forward),
		trap["centre"] + right * (edge + heading * lane * 0.5)
			+ Vector3.UP * (barrier_height * 0.5 + barrier_lift))
	for hit in get_world_3d().direct_space_state.intersect_shape(query):
		var car := hit["collider"] as Car
		if car == null:
			continue
		var local := global_transform.affine_inverse() * car.global_position
		var from_middle: Vector3 = local - trap["centre"]
		# How far the trap still has to come before it reaches the car.
		var near_side := from_middle.dot(right) - heading * CAR_WIDTH * 0.5
		var gap := (near_side - edge) * heading
		if gap > maxf(trap_shove_reach, closing * trap_shove_lead):
			continue
		# Whichever end of the row the car will be nearer in a moment, so a
		# car driving through is helped on through rather than sent back.
		var velocity := global_transform.basis.inverse() * car.velocity
		var ahead := from_middle.dot(forward) + velocity.dot(forward) * 0.25
		var way := 1.0 if ahead >= 0.0 else -1.0
		car.knock(0.0, global_transform.basis * forward * (way * trap_shove))


func _clear() -> void:
	for node in _built:
		if is_instance_valid(node):
			node.queue_free()
	_built.clear()
	_traps.clear()
	_rings.clear()
	_movers.clear()
	_coins.clear()


## One pad: a dark slab with glowing chevrons pointing the way, and a box over
## it that hands out the boost.
##
## The pad is cut into its own grid rather than drawn on the road's samples.
## The road is sampled every 2.5 m, which is coarser than a whole chevron, so
## anything drawn row by row on it would be a ladder rather than an arrow.
func _build_pad(
	pad: TrackFeatures.Placement, points: PackedVector3Array,
	rights: PackedVector3Array, half_widths: PackedFloat32Array, step: float
) -> void:
	var rows: int = maxi(pad_chevron_rows, int(round(pad.length / pad_cell_length)))
	# -1 at the left edge of the road and +1 at the right, which is the same
	# way the placement describes itself.
	var left := pad.lateral - pad.half_span
	var right := pad.lateral + pad.half_span

	var base := SurfaceTool.new()
	base.begin(Mesh.PRIMITIVE_TRIANGLES)
	base.set_color(pad_base_color)
	base.set_normal(Vector3.UP)
	var chevrons := SurfaceTool.new()
	chevrons.begin(Mesh.PRIMITIVE_TRIANGLES)
	chevrons.set_color(pad_color)
	chevrons.set_normal(Vector3.UP)

	var apex := (pad_columns - 1) / 2
	for r in rows:
		var a := _frame(points, rights, half_widths, step,
				pad.offset + pad.length * float(r) / float(rows))
		var b := _frame(points, rights, half_widths, step,
				pad.offset + pad.length * float(r + 1) / float(rows))
		_cell(base, a, b, left, right, pad_lift)
		# One arrowhead per chevron_rows, apex forward: the further back down
		# the pad a row is, the further out from the middle its lit cells sit.
		var out: int = pad_chevron_rows - 1 - (r % pad_chevron_rows)
		for c in pad_columns:
			if absi(c - apex) != out:
				continue
			var c0: float = lerpf(left, right, float(c) / float(pad_columns))
			var c1: float = lerpf(left, right, float(c + 1) / float(pad_columns))
			_cell(chevrons, a, b, c0, c1, pad_lift + pad_chevron_lift)

	var mesh := ArrayMesh.new()
	base.commit(mesh)
	chevrons.commit(mesh)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.set_surface_override_material(0, _pad_base_material)
	instance.set_surface_override_material(1, _pad_material)
	add_child(instance)
	_built.append(instance)

	var first := clampi(int(pad.offset / step), 0, points.size() - 2)
	var last: int = mini(
			first + maxi(1, int(round(pad.length / step))), points.size() - 1)
	_build_trigger(pad, points, rights, half_widths, first, last)


## One row of barriers: a striped wall standing on the road, and a solid body
## in the obstacle group so that hitting it costs the car its speed.
##
## It is cut into stripes across its width rather than painted, because the
## whole row is one mesh and one material; each stripe is built as its own
## little box, and the faces they share end up buried inside the wall where
## nobody sees them.
func _build_barrier(
	barrier: TrackFeatures.Placement, points: PackedVector3Array,
	rights: PackedVector3Array, half_widths: PackedFloat32Array, step: float
) -> void:
	var a := _frame(points, rights, half_widths, step, barrier.offset)
	var b := _frame(points, rights, half_widths, step,
			barrier.offset + barrier.length)
	var left := barrier.lateral - barrier.half_span
	var right := barrier.lateral + barrier.half_span
	var across: float = (right - left) * a[2]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if barrier.length > across:
		# A wall running along the road - a fork's divider - is striped down
		# its length. Striped across its width the way a row is, it would come
		# out as one red half and one white half running the whole way, which
		# reads as a painted line rather than as a barrier.
		var stripes: int = maxi(2, int(round(barrier.length / barrier_stripe_width)))
		for i in stripes:
			st.set_color(barrier_stripe_color if i % 2 else barrier_color)
			_stripe(st,
				_frame(points, rights, half_widths, step,
					barrier.offset + barrier.length * float(i) / float(stripes)),
				_frame(points, rights, half_widths, step,
					barrier.offset + barrier.length * float(i + 1) / float(stripes)),
				left, right)
	else:
		var stripes: int = maxi(2, int(round(across / barrier_stripe_width)))
		for i in stripes:
			st.set_color(barrier_stripe_color if i % 2 else barrier_color)
			_stripe(st, a, b,
				lerpf(left, right, float(i) / float(stripes)),
				lerpf(left, right, float(i + 1) / float(stripes)))

	var mesh := ArrayMesh.new()
	st.generate_normals()
	st.commit(mesh)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.set_surface_override_material(0, _barrier_material)
	add_child(instance)
	_built.append(instance)

	_build_wall(barrier, a, b, across)


## One trap: the same striped row a barrier is, built on a body that moves.
##
## A barrier is drawn straight onto the road in the course's own space, which is
## no use for something that has to slide across it. A trap is built once
## around its own middle - the stripes, and the box that stops a car - and the
## whole body is moved from there. That body is an AnimatableBody3D rather than
## a static one moved by hand, so the physics knows it is moving and a car it
## sweeps into is pushed along rather than found inside it. It is in the
## obstacle group, so hitting one costs what hitting a barrier costs.
func _build_trap(
	trap: TrackFeatures.Placement, points: PackedVector3Array,
	rights: PackedVector3Array, half_widths: PackedFloat32Array, step: float
) -> void:
	var a := _frame(points, rights, half_widths, step, trap.offset)
	var b := _frame(points, rights, half_widths, step, trap.offset + trap.length)
	var middle := _frame(points, rights, half_widths, step, trap.centre())
	var half_width: float = middle[2]
	var across := trap.half_span * 2.0 * half_width
	var forward: Vector3 = b[0] - a[0]
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		forward = Vector3.FORWARD
	var right: Vector3 = middle[1]

	# The body's own space: across is x, up is y, and the side a car arrives at
	# is +z, so the frames below are the road frames a barrier is drawn between
	# with the road taken out of them. A half-width of one makes the laterals
	# handed to _stripe read as metres.
	var near := [Vector3(0.0, 0.0, trap.length * 0.5), Vector3.RIGHT, 1.0]
	var far := [Vector3(0.0, 0.0, -trap.length * 0.5), Vector3.RIGHT, 1.0]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stripes: int = maxi(2, int(round(across / barrier_stripe_width)))
	for i in stripes:
		st.set_color(barrier_stripe_color if i % 2 else barrier_color)
		_stripe(st, near, far,
			lerpf(-across * 0.5, across * 0.5, float(i) / float(stripes)),
			lerpf(-across * 0.5, across * 0.5, float(i + 1) / float(stripes)))
	var mesh := ArrayMesh.new()
	st.generate_normals()
	st.commit(mesh)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.set_surface_override_material(0, _barrier_material)

	var body := AnimatableBody3D.new()
	body.add_to_group(Car.OBSTACLE_GROUP)
	body.add_child(instance)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(across, 0.4), barrier_height, maxf(trap.length, 0.4))
	shape.shape = box
	shape.position = Vector3.UP * (barrier_height * 0.5 + barrier_lift)
	body.add_child(shape)
	body.transform = Transform3D(
		Basis(right, Vector3.UP, -forward.normalized()),
		middle[0] + right * (trap.lateral * half_width))
	add_child(body)
	_built.append(body)
	_traps.append({
		"placement": trap, "body": body, "at": trap.lateral, "seconds": 0.0,
		"centre": middle[0], "right": right, "half_width": half_width,
		"forward": forward.normalized(),
	})


## One coin: a gold disc standing square across the road, turning slowly, with
## a box round it that notices a car.
##
## The disc faces the way a car arrives from rather than lying flat on the
## road, because a coin is picked up by driving through it, and a thing to be
## driven through has to be seen from the run up. It turns about the upright,
## so it flashes from a full face to an edge and back - which is what makes a
## small still thing at the side of the road catch the eye at all.
##
## An Area3D rather than a body: a coin is taken, not hit. Nothing about
## driving through one may cost the car anything, and the one way to be sure of
## that is for there to be nothing solid there.
func _build_coin(
	coin: TrackFeatures.Placement, points: PackedVector3Array,
	rights: PackedVector3Array, half_widths: PackedFloat32Array, step: float
) -> void:
	var a := _frame(points, rights, half_widths, step, coin.offset)
	var b := _frame(points, rights, half_widths, step, coin.offset + coin.length)
	var middle := _frame(points, rights, half_widths, step, coin.centre())
	var right: Vector3 = middle[1]
	var forward: Vector3 = b[0] - a[0]
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		forward = Vector3.FORWARD
	var radius: float = maxf(coin.radius, 0.1)

	var area := Area3D.new()
	area.name = "Coin"
	area.monitoring = true
	area.transform = Transform3D(
		Basis(right, Vector3.UP, -forward.normalized()),
		middle[0] + right * (coin.lateral * float(middle[2]))
			+ Vector3.UP * coin.height)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	# Across and up by the coin itself plus a margin; along the road by
	# whatever the placement takes, which is enough that a car doing thirty
	# metres a second cannot step over it between two physics frames.
	box.size = Vector3(
		radius * 2.0 + coin_trigger_margin * 2.0,
		radius * 2.0 + coin_trigger_margin * 2.0,
		maxf(coin.length, 1.0))
	shape.shape = box
	area.add_child(shape)

	# Two nodes rather than one: the outer turns about the upright, and the
	# inner stands the cylinder on its side so its axis points down the road.
	# Written as one node's rotation the two would be read back in Godot's own
	# order and come out as a wobble.
	var spin := Node3D.new()
	spin.name = "Spin"
	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = coin_thickness
	cylinder.radial_segments = 24
	cylinder.rings = 1
	disc.mesh = cylinder
	# A material of its own, not the shared one: taking a coin fades that coin,
	# and a shared material would fade every coin on the course with it.
	disc.material_override = _a_coin_material()
	# One axis, written on its own, so there is no question of what order
	# Godot reads a pair of angles back in: the disc is stood on its side, and
	# leaned back out of that by however much `coin_lean` asks for.
	disc.rotation.x = PI * 0.5 - deg_to_rad(coin_lean)
	spin.add_child(disc)
	area.add_child(spin)

	add_child(area)
	_built.append(area)
	var index := _coins.size()
	_coins.append({
		"area": area, "spin": spin, "disc": disc, "taken": false,
		# Its own starting angle, off where it sits on the course, so no two
		# coins near each other turn in step. Taken from the offset rather than
		# rolled, so a course always looks the same way it did.
		"phase": fmod(coin.centre(), 4.0) * TAU * 0.25,
	})
	area.body_entered.connect(func(body: Node3D) -> void:
		_on_coin_entered(body, index))


## Take a coin: bank it, say so, and play the pickup.
##
## Banked here, at the moment a car drives through it, rather than handed to
## whichever scene is running the race. Two scenes run races today and there
## will be more, and a coin that paid in one of them and quietly did not in
## another is the kind of bug nobody reports because nobody can see it. It also
## settles what happens to a run that is given up halfway: the coins are
## already in the purse, because there was never anywhere else for them to be.
##
## Once per coin, for both players. It is one coin: whoever reaches it first
## has it, and what the other one sees is an empty piece of road, which is
## exactly what it is.
func _on_coin_entered(body: Node3D, index: int) -> void:
	var car := body as Car
	if car == null:
		return
	if index < 0 or index >= _coins.size():
		return
	var coin := _coins[index]
	if bool(coin["taken"]):
		return
	coin["taken"] = true
	var purse := _the_purse()
	if purse != null:
		purse.bank()
	coin_taken.emit()
	_play_the_pickup(coin)


## The purse, found off the tree rather than named.
##
## `Purse` is an autoload and this is a `class_name` script, and the two do not
## mix: every check under `tools/` is a `--script` run, which compiles this file
## and everything it depends on before the autoloads exist, and a bare `Purse`
## in here fails to compile every one of them. Looked up once and kept, because
## it is asked for in the middle of a physics callback.
func _the_purse() -> Node:
	if not is_instance_valid(_purse):
		_purse = get_tree().root.get_node_or_null(^"/root/Purse")
	return _purse


## The coin lifting and fading, with a small number going up with it.
##
## A pickup with no feedback reads as a bug - a thing that was there is
## suddenly not there - so something has to happen where the coin was, in the
## world, as well as in the corner of the screen where the purse is.
func _play_the_pickup(coin: Dictionary) -> void:
	var area: Area3D = coin["area"]
	if not is_instance_valid(area):
		return
	# Nothing may take it twice. The flag above is what actually settles that;
	# this is the area itself going quiet, deferred because a body is inside
	# one of its own callbacks at this moment and Godot will not have the
	# physics rewritten from in there.
	area.set_deferred("monitoring", false)

	var number := Label3D.new()
	number.text = "+1"
	number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	number.no_depth_test = true
	number.pixel_size = coin_number_size / 64.0
	number.modulate = coin_color
	number.outline_modulate = Color(0.0, 0.0, 0.0, 0.7)
	number.outline_size = 10
	number.position = Vector3(coin_number_at.x, coin_number_at.y, 0.0)
	area.add_child(number)

	var disc: MeshInstance3D = coin["disc"]
	var material := disc.material_override as StandardMaterial3D
	# Bound to the coin itself, so a course rebuilt mid-fade takes its tweens
	# with it rather than leaving them running on freed nodes.
	var lift := area.create_tween()
	lift.set_parallel(true)
	lift.tween_property(area, "position:y",
		area.position.y + coin_take_rise, coin_take_seconds)
	lift.tween_property(material, "albedo_color:a", 0.0, coin_take_seconds)
	lift.tween_property(material, "emission_energy_multiplier", 0.0,
		coin_take_seconds)
	lift.tween_property(number, "modulate:a", 0.0, coin_take_seconds)
	lift.chain().tween_callback(area.hide)


## One coin's own material. Transparent from the start rather than switched
## over when it fades: a material that changes how it is drawn halfway through
## a fade pops as it crosses over.
func _a_coin_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = coin_color
	material.metallic = 0.8
	material.roughness = 0.25
	material.emission_enabled = true
	material.emission = coin_color
	material.emission_energy_multiplier = coin_glow
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

## One stripe of a barrier: a box between two road frames, open at the bottom
## where it meets the road.
func _stripe(
	st: SurfaceTool, a: Array, b: Array, from: float, to: float
) -> void:
	var up := Vector3.UP * barrier_height
	var foot := Vector3.UP * barrier_lift
	# The four uprights of the box, near and far, left and right.
	var nl: Vector3 = a[0] + a[1] * (a[2] * from) + foot
	var nr: Vector3 = a[0] + a[1] * (a[2] * to) + foot
	var fl: Vector3 = b[0] + b[1] * (b[2] * from) + foot
	var fr: Vector3 = b[0] + b[1] * (b[2] * to) + foot

	for face in [
		[nl, nr, nr + up, nl + up],           # the side the car arrives at
		[fr, fl, fl + up, fr + up],           # and the side it leaves by
		[nr, fr, fr + up, nr + up],           # the two ends
		[fl, nl, nl + up, fl + up],
		[nl + up, nr + up, fr + up, fl + up], # the top
	]:
		# Wound the way the road is - what Godot takes as the front of a face
		# is the opposite of the right hand rule on its corners - so the face
		# a car arrives at is the one turned towards it. Wound the other way
		# every panel shows the player its back, which lights as though the
		# sun were behind it and reads as a barrier facing the wrong way.
		for v in [face[0], face[2], face[1], face[0], face[3], face[2]]:
			st.add_vertex(v)


## The solid part. One box for the whole row rather than one per stripe: the
## stripes are paint, and a car should feel a barrier as a single wall.
func _build_wall(
	barrier: TrackFeatures.Placement, a: Array, b: Array, across: float
) -> void:
	var body := StaticBody3D.new()
	# What tells the car this is worth losing speed over. The rails are not in
	# this group, so scraping down the edge of the road still costs nothing.
	body.add_to_group(Car.OBSTACLE_GROUP)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(
		maxf(across, 0.4), barrier_height, maxf(barrier.length, 0.4))
	shape.shape = box
	body.add_child(shape)

	var centre: Vector3 = (a[0] + b[0]) * 0.5 + a[1] * (
			a[2] * barrier.lateral)
	var forward: Vector3 = b[0] - a[0]
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		forward = Vector3.FORWARD
	body.transform = Transform3D(
		Basis(a[1], Vector3.UP, -forward.normalized()),
		centre + Vector3.UP * (barrier_height * 0.5 + barrier_lift))
	add_child(body)
	_built.append(body)


## One ring: a lit torus standing square to the road, with a solid rim.
##
## Solid, because a ring a car can clip straight through is a hoop painted on
## the sky, and a player learns nothing from missing one except that they did.
## The rim is not in the obstacle group, though: clipping it costs what the
## physics costs - the car is knocked off its line, often into the hole - and
## no speed penalty or damage on top of that. Missing the ring is already the
## price.
func _build_ring(
	ring: TrackFeatures.Placement, points: PackedVector3Array,
	rights: PackedVector3Array, half_widths: PackedFloat32Array, step: float
) -> void:
	var frame := _frame(points, rights, half_widths, step, ring.centre())
	var right: Vector3 = frame[1]
	right.y = 0.0
	right = right.normalized()
	var forward := Vector3.UP.cross(right)
	var middle: Vector3 = (frame[0] + right * (ring.lateral * float(frame[2]))
			+ Vector3.UP * ring.height)

	# A body that can be moved, whether or not this one ever is: a moving ring
	# carries its rim with it, and the physics has to know the rim is moving
	# or a car it slides into is found inside it rather than pushed.
	var stand := AnimatableBody3D.new()
	stand.name = "Ring"
	# Right across, forward along the axis of the torus, up up. A TorusMesh lies
	# flat around its own Y, so this is what stands it up facing the car.
	stand.transform = Transform3D(Basis(right, forward, Vector3.UP), middle)

	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var torus := TorusMesh.new()
	torus.inner_radius = ring.radius
	torus.outer_radius = ring.radius + ring_tube * 2.0
	torus.rings = 48
	torus.ring_segments = 12
	rim.mesh = torus
	rim.material_override = _ring_material
	stand.add_child(rim)

	var around := ring.radius + ring_tube
	var chord := 2.0 * around * sin(PI / float(ring_segments))
	for i in ring_segments:
		var angle := TAU * (float(i) + 0.5) / float(ring_segments)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var along := Vector3(-sin(angle), 0.0, cos(angle))
		var capsule := CapsuleShape3D.new()
		capsule.radius = ring_tube
		capsule.height = chord + ring_tube * 2.0
		var shape := CollisionShape3D.new()
		shape.shape = capsule
		shape.transform = Transform3D(
			Basis(out, along, out.cross(along)), out * around)
		stand.add_child(shape)

	add_child(stand)
	_built.append(stand)
	_rings.append(stand)
	if ring.moves():
		_movers.append({
			"placement": ring, "body": stand,
			"centre": frame[0] + Vector3.UP * ring.height, "right": right,
			"half_width": float(frame[2]),
		})
		stand.position = frame[0] + Vector3.UP * ring.height + right * (
			ring.lateral_at(0.0) * float(frame[2]))


## One kicker: a ramp in one lane, rising `height` over its length on the same
## curve the course's ramps rise on, with lit sides so it reads as the way up
## rather than as a barrier. Its top is road, so it is in the road group, and its
## collision is its own surfaces - top and sides - so a car beside it is beside a
## wall and a car on it is on a ramp.
func _build_kicker(
	kicker: TrackFeatures.Placement, points: PackedVector3Array,
	rights: PackedVector3Array, half_widths: PackedFloat32Array, step: float
) -> void:
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := SurfaceTool.new()
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	var slices := 16
	var left := kicker.lateral - kicker.half_span
	var right := kicker.lateral + kicker.half_span
	var last: Array = []
	for k in slices + 1:
		var t := float(k) / float(slices)
		var frame := _frame(points, rights, half_widths, step, kicker.offset + kicker.length * t)
		# Rising out of the road rather than sitting on it. The car is one long
		# flat box, and a foot even two centimetres proud of the asphalt is a
		# step its front edge catches on and stops dead against - the thing the
		# course's own ramps ease their feet into the road to avoid.
		var lift := Vector3.UP * (kicker.height * pow(t, 1.5) - 0.08 * (1.0 - t))
		var l: Vector3 = frame[0] + frame[1] * (left * float(frame[2])) + lift
		var r: Vector3 = frame[0] + frame[1] * (right * float(frame[2])) + lift
		var l_foot := Vector3(l.x, frame[0].y + 0.02, l.z)
		var r_foot := Vector3(r.x, frame[0].y + 0.02, r.z)
		if not last.is_empty():
			var pl: Vector3 = last[0]
			var pr: Vector3 = last[1]
			var plf: Vector3 = last[2]
			var prf: Vector3 = last[3]
			# Wound the way the road is, so the top faces up.
			for v in [pl, r, pr, pl, l, r]:
				top.add_vertex(v)
			for quad in [[plf, l_foot, l, pl], [prf, pr, r, r_foot]]:
				for v in [quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]]:
					sides.add_vertex(v)
		last = [l, r, l_foot, r_foot]
	# The face at the lip, down to the road.
	for v in [last[2], last[0], last[1], last[2], last[1], last[3]]:
		sides.add_vertex(v)
	top.generate_normals()
	sides.generate_normals()
	var mesh := ArrayMesh.new()
	top.commit(mesh)
	sides.commit(mesh)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.set_surface_override_material(0, _platform_material)
	instance.set_surface_override_material(1, _platform_trim_material)
	var body := StaticBody3D.new()
	body.name = "Kicker"
	body.add_to_group(Car.ROAD_GROUP)
	var shape := CollisionShape3D.new()
	var trimesh := mesh.create_trimesh_shape()
	trimesh.backface_collision = true
	shape.shape = trimesh
	body.add_child(shape)
	body.add_child(instance)
	add_child(body)
	_built.append(body)


## One platform: a level slab of road standing in the hole of a jump, with a lit
## trim round its top, on a body that slides across the road.
##
## Its origin is the middle of its top face, so where it is put is where a car
## lands. It is in the road group, because a car on it is on the road: it can
## bank a ring from it and it is not slowed as though it were on the grass.
func _build_platform(
	platform: TrackFeatures.Placement, points: PackedVector3Array,
	rights: PackedVector3Array, half_widths: PackedFloat32Array, step: float
) -> void:
	var frame := _frame(points, rights, half_widths, step, platform.centre())
	var right: Vector3 = frame[1]
	right.y = 0.0
	right = right.normalized()
	var forward := Vector3.UP.cross(right)
	var half_width: float = frame[2]
	var across := platform.half_span * 2.0 * half_width
	var centre: Vector3 = frame[0] + Vector3.UP * platform.height

	var body := AnimatableBody3D.new()
	body.name = "Platform"
	body.add_to_group(Car.ROAD_GROUP)
	var slab := BoxMesh.new()
	slab.size = Vector3(across, platform_thickness, platform.length)
	var mesh := MeshInstance3D.new()
	mesh.mesh = slab
	mesh.material_override = _platform_material
	mesh.position = Vector3.DOWN * (platform_thickness * 0.5)
	body.add_child(mesh)
	# The trim: a lit strip down each long edge and across each end, standing a
	# hair proud of the top so it reads from a car coming off the ramp below it.
	for trim in [
		[Vector3(platform_trim_width, 0.08, platform.length), Vector3((across - platform_trim_width) * 0.5, 0.02, 0.0)],
		[Vector3(platform_trim_width, 0.08, platform.length), Vector3(-(across - platform_trim_width) * 0.5, 0.02, 0.0)],
		[Vector3(across, 0.08, platform_trim_width), Vector3(0.0, 0.02, (platform.length - platform_trim_width) * 0.5)],
		[Vector3(across, 0.08, platform_trim_width), Vector3(0.0, 0.02, -(platform.length - platform_trim_width) * 0.5)],
	]:
		var strip := BoxMesh.new()
		strip.size = trim[0]
		var lit := MeshInstance3D.new()
		lit.mesh = strip
		lit.material_override = _platform_trim_material
		lit.position = trim[1]
		body.add_child(lit)
	var near_end := platform.length * 0.5 - platform_trim_width
	var post_height := platform_gate_height
	for gate in [
		[Vector3(platform_gate_thickness, post_height, platform_gate_thickness),
			Vector3((across - platform_gate_thickness) * 0.5, post_height * 0.5, near_end)],
		[Vector3(platform_gate_thickness, post_height, platform_gate_thickness),
			Vector3(-(across - platform_gate_thickness) * 0.5, post_height * 0.5, near_end)],
		[Vector3(across, platform_gate_thickness, platform_gate_thickness),
			Vector3(0.0, post_height, near_end)],
	]:
		var bar := BoxMesh.new()
		bar.size = gate[0]
		var lit := MeshInstance3D.new()
		lit.mesh = bar
		lit.material_override = _platform_trim_material
		lit.position = gate[1]
		body.add_child(lit)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = slab.size
	shape.shape = box
	shape.position = mesh.position
	body.add_child(shape)
	# Across is x, up is up, and the end a car arrives at is +z, the way a trap
	# is built.
	body.transform = Transform3D(Basis(right, Vector3.UP, -forward),
		centre + right * (platform.lateral_at(0.0) * half_width))
	add_child(body)
	_built.append(body)
	_movers.append({
		"placement": platform, "body": body, "centre": centre, "right": right,
		"half_width": half_width,
	})


## Where the road surface is at an arbitrary distance along the course, as its
## centre, its right and its half-width, read between the samples either side.
func _frame(
	points: PackedVector3Array, rights: PackedVector3Array,
	half_widths: PackedFloat32Array, step: float, offset: float
) -> Array:
	var count := points.size()
	var exact := offset / step
	var i := clampi(int(exact), 0, count - 2)
	var t := clampf(exact - float(i), 0.0, 1.0)
	return [
		points[i].lerp(points[i + 1], t),
		rights[i].lerp(rights[i + 1], t).normalized(),
		lerpf(half_widths[i], half_widths[i + 1], t),
	]


## One quad of pad, between two road frames and two lateral positions.
func _cell(
	st: SurfaceTool, a: Array, b: Array, from: float, to: float, lift: float
) -> void:
	var pa: Vector3 = a[0] + Vector3.UP * lift
	var pb: Vector3 = b[0] + Vector3.UP * lift
	var ra: Vector3 = a[1] * a[2]
	var rb: Vector3 = b[1] * b[2]
	# Same clockwise-from-above winding as the road itself.
	for v in [pa + ra * from, pb + rb * to, pa + ra * to,
			pa + ra * from, pb + rb * from, pb + rb * to]:
		st.add_vertex(v)


## The box that notices a car. It is built from the pad's own middle and
## heading rather than from the mesh, so a pad on a curve gets a trigger
## squarely over it instead of one boxing in the whole arc.
func _build_trigger(
	pad: TrackFeatures.Placement, points: PackedVector3Array,
	rights: PackedVector3Array, half_widths: PackedFloat32Array,
	first: int, last: int
) -> void:
	var middle := (first + last) / 2
	var right := rights[middle]
	var half_width := half_widths[middle]
	var centre := points[middle] + right * (pad.lateral * half_width)

	var area := Area3D.new()
	# The road and the rails are static bodies on the same layer as the cars,
	# so the area sees those too; what it does about that is check.
	area.monitoring = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(
		maxf(pad.half_span * 2.0 * half_width, 1.0),
		pad_trigger_height,
		maxf(pad.length, 1.0))
	shape.shape = box
	area.add_child(shape)

	var forward := points[last] - points[first]
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		forward = Vector3.FORWARD
	area.transform = Transform3D(
		Basis(right, Vector3.UP, -forward.normalized()),
		centre + Vector3.UP * (pad_trigger_height * 0.5))

	var strength := pad.strength
	area.body_entered.connect(func(body: Node3D) -> void:
		_on_pad_entered(body, strength))
	add_child(area)
	_built.append(area)


## Hand out the boost. The strength is passed through as the placement wrote
## it, and a negative one means the pad has no opinion, so the car falls back
## to its own tuning.
func _on_pad_entered(body: Node3D, strength: float) -> void:
	var car := body as Car
	if car == null:
		return
	if strength < 0.0:
		car.boost()
	else:
		car.boost(strength)


func _build_materials() -> void:
	_pad_base_material = StandardMaterial3D.new()
	_pad_base_material.vertex_color_use_as_albedo = true
	_pad_base_material.roughness = 0.75

	_pad_material = StandardMaterial3D.new()
	_pad_material.vertex_color_use_as_albedo = true
	_pad_material.roughness = 0.4
	_pad_material.emission_enabled = true
	_pad_material.emission = pad_color
	_pad_material.emission_energy_multiplier = pad_glow

	_ring_material = StandardMaterial3D.new()
	_ring_material.albedo_color = ring_color
	_ring_material.roughness = 0.35
	_ring_material.metallic = 0.4
	_ring_material.emission_enabled = true
	_ring_material.emission = ring_color
	_ring_material.emission_energy_multiplier = ring_glow

	_platform_material = StandardMaterial3D.new()
	_platform_material.albedo_color = platform_color
	_platform_material.roughness = 0.9

	_platform_trim_material = StandardMaterial3D.new()
	_platform_trim_material.albedo_color = platform_trim_color
	_platform_trim_material.emission_enabled = true
	_platform_trim_material.emission = platform_trim_color
	_platform_trim_material.emission_energy_multiplier = platform_glow

	_spent_ring_material = StandardMaterial3D.new()
	_spent_ring_material.albedo_color = spent_ring_color
	_spent_ring_material.roughness = 0.6
	_spent_ring_material.metallic = 0.3

	_barrier_material = StandardMaterial3D.new()
	_barrier_material.vertex_color_use_as_albedo = true
	_barrier_material.roughness = 0.7
	# Lit from the vertex colour as well, so the pale stripe glows and the red
	# barely does, off one material and one mesh.
	_barrier_material.emission_enabled = true
	_barrier_material.emission = Color.WHITE
	_barrier_material.emission_energy_multiplier = barrier_glow
	_barrier_material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
