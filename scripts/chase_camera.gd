class_name ChaseCamera
extends Camera3D

## Camera for one player, either trailing the car or sitting in its cockpit.
##
## It lives inside a SubViewport rather than under the car, because each
## split-screen view needs its own camera while both views share one world.
## The target is therefore wired up in code by the level, not by a NodePath.

@export var distance := 7.0        ## metres behind the car
@export var height := 2.9          ## metres above the car
@export var look_height := 1.1     ## aim this far above the car's origin
## Higher follows more tightly; lower lets the camera swing wide on corners.
@export var smoothing := 7.5
## Field of view from inside the car, a little wider than the chase view so
## the cockpit does not feel like looking down a tube.
@export var cockpit_fov := 80.0

@export_group("Speed rush")
## Extra metres back and extra degrees of view at full overspeed. Small on
## purpose: this is meant to be felt as the car pulling away from the camera,
## not noticed as the camera moving. The cockpit only gets the wider view,
## since there is nowhere for a camera bolted to the driver to pull back to.
@export var rush_distance := 1.5
@export var rush_fov := 7.0
## How quickly the camera follows the car's overspeed. Slower than the effect
## it is reacting to, so the frame breathes rather than snapping about.
@export var rush_ease := 4.0

var _target: Car
## Chase view when false, driver's eye when true.
var _inside := false
var _chase_fov := 75.0
## How much of the speed rush the camera is currently showing, 0 to 1.
var _rush := 0.0


## The resting field of view is read once, here, rather than off `fov`: by the
## time a course is swapped the speed rush has already been added to it, and
## reading it back would bake that in and creep wider every race.
func _ready() -> void:
	_chase_fov = fov


## Called by the level once the world is built.
func follow(target: Car) -> void:
	_target = target
	_rush = 0.0
	# A car with nowhere to sit takes the camera back outside rather than
	# leaving it buried in whatever the player is now driving.
	if _inside and (target == null or not target.has_cockpit()):
		_inside = false
	_apply_fov()
	_snap()


## Swap between the chase view and the driver's eye.
##
## A car the players brought from outside has no interior: it is a shape, and
## a camera put inside one looks at the back of a solid shell. The refusal
## lives here rather than where the key is read, because both the race and the
## solo run press this same button and neither should have to remember.
func set_inside(inside: bool) -> void:
	if inside and (_target == null or not _target.has_cockpit()):
		return
	if _inside == inside:
		return
	_inside = inside
	_apply_fov()
	_snap()


func is_inside() -> bool:
	return _inside


func _snap() -> void:
	if _target == null:
		return
	if _inside:
		global_transform = _target.eye_transform()
	else:
		global_position = _desired_position()
		_aim()


func _physics_process(delta: float) -> void:
	if _target == null:
		return
	# Exponential easing, so the feel does not change with frame rate.
	_rush = lerpf(_rush, _target.overspeed(), 1.0 - exp(-rush_ease * delta))
	_apply_fov()
	if _inside:
		# Rigidly bolted to the car. Smoothing a first person view lags the
		# horizon behind the steering and reads as the world sliding about.
		global_transform = _target.eye_transform()
		return
	var weight := 1.0 - exp(-smoothing * delta)
	global_position = global_position.lerp(_desired_position(), weight)
	_aim()


func _desired_position() -> Vector3:
	# The car faces -Z, so +Z is directly behind it.
	var behind := _target.global_transform.basis.z * (distance + rush_distance * _rush)
	return _target.global_position + behind + Vector3.UP * height


func _apply_fov() -> void:
	fov = (cockpit_fov if _inside else _chase_fov) + rush_fov * _rush


func _aim() -> void:
	var focus := _target.global_position + Vector3.UP * look_height
	# look_at asserts if the camera is sitting exactly on its focus point.
	if global_position.distance_squared_to(focus) > 0.001:
		look_at(focus, Vector3.UP)
