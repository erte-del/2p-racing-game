class_name RivalArrow
extends MeshInstance3D

## A small arrow that orbits one car at a fixed radius, always pointing along
## the ground towards the other car, and painted in the rival's colour.
##
## It lives in the shared world rather than inside a SubViewport, so it is kept
## out of the other player's half of the screen with a visual layer that the
## rival's camera culls. See main.gd for how the two are paired up.

@export var radius := 3.6          ## metres from the car it orbits
@export var hover_height := 1.55   ## metres, clears the car roof (1.39 m)
@export var arrow_length := 1.3    ## metres, nose to tail
@export var arrow_width := 1.0     ## metres across the barbs
## How fast the arrow swings round to a new bearing. Smoothing stops it
## snapping about while the cars jostle at close range.
@export var smoothing := 12.0

@export_group("Auto hide")
## Hide the arrow while the rival is already on screen, since it is only
## useful for finding a car you cannot see.
@export var hide_when_rival_on_screen := true
## The two margins are deliberately different, which gives the arrow
## hysteresis: the rival must come well inside the view before the arrow
## hides, but only just leave it before the arrow comes back. A single
## threshold would make the arrow flicker while the rival sat on the edge.
## Fraction of the view the rival must be inside before the arrow hides.
@export_range(0.0, 0.45) var hide_margin := 0.12
## Fraction of the view the rival must leave before the arrow returns.
@export_range(0.0, 0.45) var show_margin := 0.02
## Aim the on-screen test at the car's body rather than its floor.
@export var rival_centre_height := 0.7

var _owner_car: Node3D
var _rival_car: Node3D
## The one camera that renders this arrow, used to keep its face readable.
var _camera: Camera3D
## Current bearing to the rival, flattened onto the ground plane.
var _bearing := Vector3.FORWARD


## Point this arrow from one car towards another.
## `layer` is the 1-based visual layer only the owner's camera renders.
func setup(
	owner_car: Node3D, rival_car: Node3D, colour: Color, layer: int, camera: Camera3D
) -> void:
	_owner_car = owner_car
	_rival_car = rival_car
	_camera = camera

	mesh = _build_arrow()
	material_override = _build_material(colour)
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	layers = 1 << (layer - 1)

	_bearing = _target_bearing()
	_place()
	_update_visibility()


## Follow the rival into a new colour. The arrow is the only thing telling one
## player which car is the other one, so a car that changes colour and an arrow
## that does not would be worse than no arrow.
func recolour(colour: Color) -> void:
	material_override = _build_material(colour)


## Runs with physics, like the cars and cameras, so the arrow cannot jitter
## against the car it is tracking.
func _physics_process(delta: float) -> void:
	if _owner_car == null or _rival_car == null:
		return
	var weight := 1.0 - exp(-smoothing * delta)
	_bearing = _bearing.slerp(_target_bearing(), weight)
	_place()
	_update_visibility()


## Direction from the owner to the rival, flattened onto the ground.
func _target_bearing() -> Vector3:
	var to_rival := _rival_car.global_position - _owner_car.global_position
	to_rival.y = 0.0
	# Cars exactly on top of each other give no usable bearing; hold the last.
	if to_rival.length_squared() < 0.0001:
		return _bearing
	return to_rival.normalized()


func _place() -> void:
	var centre := _owner_car.global_position
	global_position = centre + _bearing * radius + Vector3.UP * hover_height
	# The mesh is built pointing down -Z, which is where look_at aims.
	look_at(global_position + _bearing, Vector3.UP)
	_face_camera()


## Spin the arrow about its own nose so its flat face turns towards the camera.
## The nose keeps pointing at the rival; only the roll changes. Without this
## the arrow is edge-on, and nearly invisible, whenever the rival is straight
## ahead of or behind the player.
func _face_camera() -> void:
	if _camera == null:
		return
	var to_camera := _camera.global_position - global_position
	var nose := -global_transform.basis.z
	# Only the part of that direction at right angles to the nose can be
	# reached by rolling; the rest is along the axis we are rolling about.
	var target := to_camera - nose * to_camera.dot(nose)
	if target.length_squared() < 0.000001:
		return
	target = target.normalized()
	# The mesh lies in its own XZ plane, so local Y is the face normal.
	var face := global_transform.basis.y
	var side := global_transform.basis.x
	rotate_object_local(Vector3.BACK, -atan2(target.dot(side), target.dot(face)))


## Show the arrow only while the rival is off screen.
func _update_visibility() -> void:
	if not hide_when_rival_on_screen or _camera == null:
		visible = true
		return
	visible = not _rival_on_screen()


func _rival_on_screen() -> bool:
	var target := _rival_car.global_position + Vector3.UP * rival_centre_height
	# Behind the camera unprojects to a meaningless point, so rule it out first.
	if _camera.is_position_behind(target):
		return false

	var view: Vector2 = _camera.get_viewport().get_visible_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return false

	# Widen the test while the arrow is hidden, so it takes a clear exit from
	# the view to bring the arrow back. See the margin exports above.
	var margin := hide_margin if visible else show_margin
	var inset := view * margin
	var box := Rect2(inset, view - inset * 2.0)
	return box.has_point(_camera.unproject_position(target))


## A flat chevron lying in the XZ plane, nose towards -Z.
func _build_arrow() -> ArrayMesh:
	var half_len := arrow_length * 0.5
	var half_wid := arrow_width * 0.5
	var vertices := PackedVector3Array([
		Vector3(0.0, 0.0, -half_len),            # 0 nose
		Vector3(-half_wid, 0.0, half_len),       # 1 left barb
		Vector3(0.0, 0.0, half_len * 0.35),      # 2 notch
		Vector3(half_wid, 0.0, half_len),        # 3 right barb
	])
	var normals := PackedVector3Array()
	normals.resize(vertices.size())
	normals.fill(Vector3.UP)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])

	var arrow := ArrayMesh.new()
	arrow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arrow


func _build_material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	# Unshaded so the arrow reads as UI rather than as part of the scene, and
	# does not go dark when the car drives into shadow.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Two-sided, so the flat arrow never vanishes from a low camera angle.
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
