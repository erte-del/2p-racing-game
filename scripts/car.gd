class_name Car
extends CharacterBody3D

## Arcade car controller.
##
## The car keeps a single signed speed along its own -Z (forward) axis and
## steers by rotating the whole body, rather than simulating real suspension.
## That is far easier to tune for split-screen arcade racing than
## VehicleBody3D, and it will not flip over on a procedural track.

## Which set of input actions to read, e.g. "p1" -> p1_accelerate, p1_brake,
## p1_steer_left, p1_steer_right. Player 2 gets its own prefix later.
@export var input_prefix := "p1"

@export_group("Driving")
@export var max_speed := 25.0          ## m/s going forward
@export var max_reverse_speed := 8.0   ## m/s going backwards
@export var acceleration := 12.0       ## m/s^2 under throttle
@export var braking := 24.0            ## m/s^2 under brake
@export var engine_braking := 6.0      ## m/s^2 coasting with no input
@export var steering := 1.8            ## rad/s at full steering effect
@export var gravity := 24.0            ## m/s^2, tuned for arcade feel

@export_group("Wheels")
@export var wheel_radius := 0.312      ## metres, wheel centre height in-game
@export var max_wheel_steer := 0.5     ## rad the front wheels visually turn
@export var wheel_steer_speed := 4.0   ## how fast the wheels visually turn

## Signed speed along local -Z. Positive is forwards.
var _speed := 0.0
## Visual-only wheel state.
var _wheel_steer := 0.0
var _wheel_roll := 0.0

# Action names are built once; doing it per frame would allocate every tick.
var _accelerate: StringName
var _brake: StringName
var _steer_left: StringName
var _steer_right: StringName

var _front_wheels: Array[Node3D] = []
var _rear_wheels: Array[Node3D] = []
# Each wheel's untouched orientation, so the animation composes onto it
# instead of assuming the model exported with identity rotations.
var _wheel_rest: Array[Basis] = []


func _ready() -> void:
	_accelerate = StringName(input_prefix + "_accelerate")
	_brake = StringName(input_prefix + "_brake")
	_steer_left = StringName(input_prefix + "_steer_left")
	_steer_right = StringName(input_prefix + "_steer_right")

	_front_wheels = _collect_wheels(["Wheel_FL", "Wheel_FR"])
	_rear_wheels = _collect_wheels(["Wheel_BL", "Wheel_BR"])
	for wheel in _front_wheels + _rear_wheels:
		_wheel_rest.append(wheel.transform.basis)


## Found by name rather than by path: the glTF importer decides how deeply it
## nests the model, and that should not break the wheels.
func _collect_wheels(names: Array[String]) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for name in names:
		var wheel := find_child(name, true, false) as Node3D
		if wheel:
			found.append(wheel)
		else:
			push_warning("Car: wheel '%s' not found in the model" % name)
	return found


func _physics_process(delta: float) -> void:
	var throttle := Input.get_axis(_brake, _accelerate)
	var steer := Input.get_axis(_steer_right, _steer_left)

	_apply_throttle(throttle, delta)
	_apply_steering(steer, delta)
	_drive(delta)
	_animate_wheels(steer, delta)


## Turn throttle input into a change in speed. Pressing back while rolling
## forwards brakes; holding it once stopped reverses.
func _apply_throttle(throttle: float, delta: float) -> void:
	if is_zero_approx(throttle):
		_speed = move_toward(_speed, 0.0, engine_braking * delta)
	elif throttle > 0.0:
		var rate := braking if _speed < 0.0 else acceleration
		_speed = move_toward(_speed, max_speed, rate * throttle * delta)
	else:
		var rate := braking if _speed > 0.0 else acceleration
		_speed = move_toward(_speed, -max_reverse_speed, rate * -throttle * delta)


## Rotate the car. Steering has no effect when stopped and inverts in
## reverse, so the car handles the way a real one does.
func _apply_steering(steer: float, delta: float) -> void:
	if is_zero_approx(steer) or is_zero_approx(_speed):
		return
	var grip := clampf(absf(_speed) / max_speed, 0.0, 1.0)
	rotate_y(steer * steering * grip * signf(_speed) * delta)


## Move along the car's facing, keeping it pinned to the ground.
func _drive(delta: float) -> void:
	var forward := -global_transform.basis.z
	velocity.x = forward.x * _speed
	velocity.z = forward.z * _speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - gravity * delta
	move_and_slide()


## Purely cosmetic: turn the front wheels and roll all four.
func _animate_wheels(steer: float, delta: float) -> void:
	_wheel_steer = move_toward(
		_wheel_steer, steer * max_wheel_steer, wheel_steer_speed * delta
	)
	# wrap so the angle cannot grow without bound over a long race
	_wheel_roll = fposmod(_wheel_roll - _speed * delta / wheel_radius, TAU)

	for i in _front_wheels.size():
		_set_wheel(_front_wheels[i], _wheel_rest[i], _wheel_steer)
	for i in _rear_wheels.size():
		_set_wheel(_rear_wheels[i], _wheel_rest[_front_wheels.size() + i], 0.0)


## Roll about the wheel's own lateral axis, then yaw it for steering.
func _set_wheel(wheel: Node3D, rest: Basis, steer_angle: float) -> void:
	var spin := Basis.from_euler(
		Vector3(_wheel_roll, steer_angle, 0.0), EULER_ORDER_YXZ
	)
	wheel.transform.basis = rest * spin
