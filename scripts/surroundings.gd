class_name Surroundings
extends Node3D

## Rings the play area with the low poly hills and lake.
##
## The source blend is an island diorama: hills rising out of a lake that
## covers its whole footprint, with no flat ground in it anywhere. Scaled up
## and laid under a course it would run the road through hillsides and under
## water, so it is used as the land *around* the circuit instead, standing off
## beyond the furthest a course can reach and giving the horizon its shape.
##
## The layout is fixed rather than drawn from the course seed: the horizon
## should sit still while courses come and go, not jump about between races.

const SCENERY := preload("res://assets/models/scenery.glb")

@export var island_count := 10
## Far enough out that no course can reach it. Courses are held inside a
## 480 m half-extent, and an island is about 290 m across at this scale.
@export var ring_radius := 900.0
@export var radius_jitter := 110.0
@export var island_scale := 245.0
@export var scale_jitter := 0.3
## How far to sink the islands into the ground plane.
##
## This has to clear two things. The lake is a single plate most of an
## island's width, about a sixteenth of the way up it; above ground level, ten
## of them ring the horizon and are seen edge-on from beneath as a dark band.
## And the island is a cut-out piece of ground, so wherever its surface crosses
## the ground plane there is a visible seam. Sunk shallowly that seam falls on
## the gentle outer slope and reads as a ring round the foot of each hill;
## deeper, it lands high up where the terrain is steep and disappears.
@export var sink := 52.0
@export var layout_seed := 20260902

var _meshes: Dictionary = {}


func _ready() -> void:
	build()


func build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	if _meshes.is_empty():
		var scene := SCENERY.instantiate()
		for node in scene.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			if mesh_instance.mesh:
				_meshes[mesh_instance.name] = mesh_instance.mesh
		scene.free()
	if _meshes.is_empty():
		push_warning("Surroundings: no meshes in the scenery model")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed

	var placements: Array[Transform3D] = []
	for i in island_count:
		# Even spacing round the ring, nudged, so the islands read as a range
		# rather than as a row of identical lumps.
		var angle := TAU * float(i) / float(island_count) + rng.randf_range(-0.12, 0.12)
		var radius := ring_radius + rng.randf_range(-radius_jitter, radius_jitter)
		var scale := island_scale * (1.0 + rng.randf_range(-scale_jitter, scale_jitter))
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale)
		placements.append(Transform3D(basis, Vector3(
				cos(angle) * radius, -sink, sin(angle) * radius)))

	# Plain instances rather than a MultiMesh. At ten islands the batching
	# saves nothing worth having, and MultiMesh instance transforms cannot be
	# read back under the headless renderer, so this stays testable.
	for i in placements.size():
		for name in _meshes:
			var instance := MeshInstance3D.new()
			instance.name = "%s_%d" % [name, i]
			instance.mesh = _meshes[name]
			instance.transform = placements[i]
			# Distant scenery: shadows from it cost more than they show.
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)
