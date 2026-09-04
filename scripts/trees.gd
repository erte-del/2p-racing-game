class_name Trees
extends Node3D

## Scatters the low poly trees over the grass around the course.
##
## The five trees come from the pack as one model each, and are planted at
## random: a point anywhere in the field, thrown away if it lands on the road,
## on the embankment carrying a raised section, or too close to a tree that is
## already standing. What survives is a wood that thins out near the track and
## never blocks it.
##
## They are decoration, not obstacles: there is no collision on them, and a
## car that leaves the road is turned back by the rails long before it reaches
## one. Giving four hundred trees collision shapes would cost far more than
## the corner case is worth.
##
## The scatter is redrawn for every course, because the road it has to keep
## clear of moves. It is deterministic all the same: the seed comes from the
## shape of the course itself, so the same course is always planted the same
## way.

const TREES := preload("res://assets/models/trees.glb")

## How many trees to aim for. Rejection sampling means the field can come out
## slightly short of this where the course leaves little room.
@export var tree_count := 900
## How far out to plant. The hills ring the horizon from about 645 m, so the
## wood has to stop short of them or trees grow out of the hillsides.
@export var field_radius := 600.0
## Metres of grass to leave between the road edge and the nearest trunk.
@export var road_margin := 7.0
## Closest two trees may stand to each other.
@export var min_spacing := 8.0
@export var min_scale := 0.8
@export var max_scale := 1.5
## Pushed a little into the ground, so the flat underside of a trunk cannot
## z-fight with the ground plane it is sitting on.
@export var sink := 0.15
## How far the foot of an embankment reaches per metre of height. It matches
## the track's own batter, so trees keep off the built-up ground under a
## raised section instead of standing part way up its slope.
@export var embankment_batter := 1.8
@export_group("Chaos")
## Under chaos the leaves will not hold still. The wood turns through the
## colours over this many seconds, each kind of tree from a different place in
## them, so what happens across the field is a shimmer rather than the whole
## horizon pulsing as one.
@export var leaf_cycle_seconds := 9.0
@export_range(0.0, 1.0) var leaf_saturation := 0.62
@export_range(0.0, 1.0) var leaf_value := 0.66

## Whether this is a chaotic race. Set by whatever built the race, not read
## off the settings: the title screen backdrop is a race scene too, and a
## rainbow wood behind the menu is not what the menu is for.
var wild := false

@export_group("")
@export var layout_seed := 20260902
@export var track_path := NodePath("../Track")

## Where every tree ended up, as one array per mesh, in the order the meshes
## come out of the model. Kept because a MultiMesh cannot be read back under
## the headless renderer, and this is what makes the scatter inspectable.
var placements: Array[Array] = []

var _meshes: Array[Mesh] = []
## The leaf material of every tree, this node's own copies, so they can be
## recoloured without every other wood in the game turning with them.
var _leaves: Array[StandardMaterial3D] = []
var _elapsed := 0.0
var _track: Track


func _ready() -> void:
	_track = get_node_or_null(track_path) as Track
	if _track == null:
		push_warning("Trees: no track at %s" % track_path)
		return
	_track.regenerated.connect(build)
	if _track.length() > 0.0:
		build()


## Plant a fresh wood around the course as it stands now.
func build() -> void:
	if _meshes.is_empty():
		_load_meshes()
	if _meshes.is_empty() or _track == null:
		return

	var curve := _track.curve()
	if curve == null or curve.point_count < 2:
		return

	_scatter(curve)
	_rebuild_instances()


## Take a copy of each tree, with a copy of its leaves.
##
## The meshes come out of an imported model that the whole game shares, so
## they are duplicated before anything is done to them - and a MultiMesh has
## no per-surface override to reach for instead, only one material for the
## whole thing, which would paint the trunks as well.
func _load_meshes() -> void:
	var scene := TREES.instantiate()
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var mesh: Mesh = mesh_instance.mesh.duplicate()
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null or not _is_foliage(material.albedo_color):
				continue
			var leaves: StandardMaterial3D = material.duplicate()
			mesh.surface_set_material(surface, leaves)
			_leaves.append(leaves)
		_meshes.append(mesh)
	scene.free()
	if _meshes.is_empty():
		push_warning("Trees: no meshes in the tree model")


## Which surfaces of a tree are its leaves.
##
## Asked of the colour rather than the name, because the model names its
## materials Material.001 through Material.007 and nothing in that says which
## is bark and which is a canopy. Every green surface in the pack is foliage
## and nothing else in it is green, so green is what the question is.
func _is_foliage(albedo: Color) -> bool:
	return albedo.g > albedo.r and albedo.g > albedo.b


## Turn the wood through the colours, if this is a chaotic race.
func _process(delta: float) -> void:
	if not wild or _leaves.is_empty():
		return
	_elapsed += delta
	for i in _leaves.size():
		# Each kind of leaf from its own place in the turn, so the field
		# shimmers instead of flashing all at once.
		_leaves[i].albedo_color = Color.from_hsv(
			fmod(_elapsed / leaf_cycle_seconds + float(i) / float(_leaves.size()),
				1.0),
			leaf_saturation, leaf_value)


# --- choosing the spots -------------------------------------------------

func _scatter(curve: Curve3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _course_seed(curve)

	placements = []
	for _mesh in _meshes:
		placements.append([] as Array[Transform3D])

	# Trees already planted, bucketed by a grid one spacing across, so a
	# candidate only has to be measured against its own cell and the eight
	# around it rather than against the whole wood.
	var buckets: Dictionary = {}

	# Give up long before an impossible target can hang the build: a course
	# that fills the field simply gets a thinner wood.
	var attempts: int = tree_count * 8
	var planted := 0
	for _attempt in attempts:
		if planted >= tree_count:
			break
		# Sampling the radius with a square root spreads the trees evenly
		# over the disc; taking it straight would crowd them into the middle.
		var angle := rng.randf() * TAU
		var radius := field_radius * sqrt(rng.randf())
		var spot := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

		if _on_the_course(curve, spot):
			continue
		if _crowded(buckets, spot):
			continue

		var cell := _cell(spot)
		if not buckets.has(cell):
			buckets[cell] = [] as Array[Vector3]
		buckets[cell].append(spot)

		var kind := rng.randi_range(0, _meshes.size() - 1)
		var scale := rng.randf_range(min_scale, max_scale)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
		placements[kind].append(
				Transform3D(basis, spot - Vector3.UP * sink))
		planted += 1


## True if a spot is on the road, on its shoulder, or on the built-up ground
## holding up a raised section.
func _on_the_course(curve: Curve3D, spot: Vector3) -> bool:
	var local: Vector3 = _track.global_transform.affine_inverse() * spot
	var offset := curve.get_closest_offset(local)
	var centre := curve.sample_baked(offset)
	var gap := Vector2(local.x - centre.x, local.z - centre.z).length()
	var clearance := _track.half_width_at(offset) + road_margin
	# A section running above the ground stands on a slope that reaches out
	# further the higher it is, so it needs a wider berth than a flat one.
	clearance += embankment_batter * maxf(centre.y, 0.0)
	return gap < clearance


func _crowded(buckets: Dictionary, spot: Vector3) -> bool:
	var cell := _cell(spot)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var near: Variant = buckets.get(Vector2i(cell.x + dx, cell.y + dz))
			if near == null:
				continue
			for other in near:
				if Vector2(spot.x - other.x, spot.z - other.z).length() < min_spacing:
					return true
	return false


func _cell(spot: Vector3) -> Vector2i:
	return Vector2i(int(floor(spot.x / min_spacing)), int(floor(spot.z / min_spacing)))


## A seed taken from the course itself, so a course is always planted the same
## way without the scatter having to be told which seed built it.
func _course_seed(curve: Curve3D) -> int:
	var key := layout_seed
	for i in range(0, curve.point_count, 11):
		key = hash([key, curve.get_point_position(i)])
	return key


# --- putting them in the world ------------------------------------------

func _rebuild_instances() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	for kind in _meshes.size():
		var spots: Array = placements[kind]
		if spots.is_empty():
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _meshes[kind]
		multi.instance_count = spots.size()
		for i in spots.size():
			multi.set_instance_transform(i, spots[i])

		# One draw call per kind of tree rather than one per tree, which is
		# what makes a wood this size affordable in two split-screen views.
		var instance := MultiMeshInstance3D.new()
		instance.name = "Tree%d" % (kind + 1)
		instance.multimesh = multi
		add_child(instance)
