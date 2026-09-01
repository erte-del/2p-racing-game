class_name ChaseCamera
extends Camera3D

## Third-person camera that trails a car.
##
## It lives inside a SubViewport rather than under the car, because each
## split-screen view needs its own camera while both views share one world.
## The target is therefore wired up in code by the level, not by a NodePath.

@export var distance := 7.0        ## metres behind the car
@export var height := 2.9          ## metres above the car
@export var look_height := 1.1     ## aim this far above the car's origin
## Higher follows more tightly; lower lets the camera swing wide on corners.
@export var smoothing := 7.5

var _target: Node3D


## Called by the level once the world is built.
func follow(target: Node3D) -> void:
	_target = target
	# Start already in position, or the first frame flies in from the origin.
	global_position = _desired_position()
	_aim()


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	# Exponential smoothing, so the feel does not change with frame rate.
	var weight := 1.0 - exp(-smoothing * delta)
	global_position = global_position.lerp(_desired_position(), weight)
	_aim()


func _desired_position() -> Vector3:
	# The car faces -Z, so +Z is directly behind it.
	var behind := _target.global_transform.basis.z * distance
	return _target.global_position + behind + Vector3.UP * height


func _aim() -> void:
	var focus := _target.global_position + Vector3.UP * look_height
	# look_at asserts if the camera is sitting exactly on its focus point.
	if global_position.distance_squared_to(focus) > 0.001:
		look_at(focus, Vector3.UP)
