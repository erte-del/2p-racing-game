class_name TrackFurniture
extends Node3D

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

var _pad_material: StandardMaterial3D
var _pad_base_material: StandardMaterial3D
var _barrier_material: StandardMaterial3D

## The pads, so a rebuild can clear exactly what it made.
var _built: Array[Node] = []


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


func _clear() -> void:
	for node in _built:
		if is_instance_valid(node):
			node.queue_free()
	_built.clear()


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

	_barrier_material = StandardMaterial3D.new()
	_barrier_material.vertex_color_use_as_albedo = true
	_barrier_material.roughness = 0.7
	# Lit from the vertex colour as well, so the pale stripe glows and the red
	# barely does, off one material and one mesh.
	_barrier_material.emission_enabled = true
	_barrier_material.emission = Color.WHITE
	_barrier_material.emission_energy_multiplier = barrier_glow
	_barrier_material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
