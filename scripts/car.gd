class_name Car
extends CharacterBody3D

## Arcade car controller.
##
## The car keeps a single signed speed along its own -Z (forward) axis and
## steers by rotating the whole body, rather than simulating real suspension.
## That is far easier to tune for split-screen arcade racing than
## VehicleBody3D, and it will not flip over on a procedural track.

## Name of the material in the model that carries the car's paint. Every
## surface using it gets recoloured; the tyres, glass and chrome are left alone.
const PAINT_MATERIAL := "Paint"
## The model's glass exports as opaque, which walls the first person view in.
const GLASS_MATERIAL := "Glass"
## The headlight panels. Authored permanently emissive, which is only right
## once they are switched on.
const LAMP_MATERIAL := "Lamp"

## Which set of input actions to read, e.g. "p1" -> p1_accelerate, p1_brake,
## p1_steer_left, p1_steer_right.
@export var input_prefix := "p1"

## Paint colour. Defaults to the red the model ships with.
@export var body_color := Color(0.9063, 0.0, 0.0224)

@export_group("Driving")
@export var max_speed := 25.0          ## m/s going forward
@export var max_reverse_speed := 8.0   ## m/s going backwards
@export var acceleration := 12.0       ## m/s^2 under throttle
@export var braking := 24.0            ## m/s^2 under brake
@export var engine_braking := 6.0      ## m/s^2 coasting with no input
## Turning circle at a crawl and at top speed, in metres. Steering is
## expressed as a radius rather than a rate because the tracks are built from
## corners of a known radius, so these numbers say directly which corners the
## car can take. Radius grows with speed, the way a real car washes wide.
@export var tight_turn_radius := 6.5
@export var fast_turn_radius := 16.0
@export var gravity := 24.0            ## m/s^2, tuned for arcade feel

@export_group("Slipstream")
## Tucking in behind the other car gives a top-speed boost, so a trailing
## player has a way back into the race on the straights.
@export var slipstream_enabled := true
## Beyond this distance there is no effect at all.
@export var slipstream_range := 22.0
## Inside this distance the effect stops growing, so ramming is not rewarded.
@export var slipstream_peak_range := 4.0
## Extra top speed at full effect, as a fraction.
@export var slipstream_bonus := 0.22
## How directly ahead the rival must be, as a dot product.
@export var slipstream_cone := 0.82
## How closely the two cars must be pointing the same way.
@export var slipstream_alignment := 0.6
## How quickly the effect builds and fades.
@export var slipstream_fade := 2.5

@export_group("Cockpit")
## Where the driver's eye sits, in the car's own space. The car is right hand
## drive, so this sits over on the +X side behind the wheel.
@export var eye_point := Vector3(0.4, 1.18, 0.14)
## How much of the world shows through the windows.
@export_range(0.0, 1.0) var glass_opacity := 0.18
## A steering wheel turns much further than the road wheels do.
@export var wheel_turn_ratio := 3.0

@export_group("Headlights")
## Where the right headlight sits, in the car's own space; the left one is
## mirrored. Measured off the model: the two Lamp quads sit at x +/-0.602,
## 0.683 above the ground, 2.179 ahead of the wheelbase centre.
@export var headlight_offset := Vector3(0.602, 0.683, -2.179)
## Degrees the beams are tipped down, so they light the road rather than the
## horizon.
@export var headlight_dip := 5.0
## Half-angle of the beam, in degrees.
@export var headlight_angle := 26.0
## How far the beam carries, in metres.
@export var headlight_range := 55.0
## Brightness at full night.
@export var headlight_energy := 4.5
@export var headlight_color := Color(1.0, 0.96, 0.86)
## How brightly the lamp panels themselves glow when lit.
@export var lamp_glow := 3.5

@export_group("Wheels")
@export var wheel_radius := 0.355      ## metres, wheel centre height in-game
@export var max_wheel_steer := 0.5     ## rad the front wheels visually turn
@export var wheel_steer_speed := 4.0   ## how fast the wheels visually turn

## The beams, and the material of the lamp panels they shine out of.
var _headlights: Array[SpotLight3D] = []
var _lamp_material: StandardMaterial3D

## The model's own steering wheel, turned along with the front wheels.
var _steering_wheel: Node3D
var _wheel_rest_basis := Basis.IDENTITY

## The other car, for slipstream. Wired up by the level.
var rival: Car
## While frozen the car ignores input and holds still, used for the pause
## between generated tracks.
var frozen := false

## Signed speed along local -Z. Positive is forwards.
var _speed := 0.0
## Current slipstream strength, 0 to 1, smoothed.
var _slipstream := 0.0
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

	_prepare_materials()
	_build_headlights()
	_steering_wheel = find_child("SteeringWheel", true, false) as Node3D
	if _steering_wheel:
		_wheel_rest_basis = _steering_wheel.transform.basis
	else:
		push_warning("Car: no SteeringWheel in the model")

	# Courses have climbs, and a body that only zeroes its vertical velocity on
	# the floor launches off every crest. Snapping keeps it on the surface.
	floor_snap_length = 0.6


## Switch the headlights on, off, or part way. 0 is off, 1 is full night.
##
## The car is told a level rather than the time of day: it has no business
## knowing what the sky is doing, and a level can just as well come from a
## tunnel or from a player pressing a button later.
func set_headlights(level: float) -> void:
	level = clampf(level, 0.0, 1.0)
	for light in _headlights:
		light.light_energy = headlight_energy * level
		# A light at zero energy still costs something to render, so the beams
		# are switched off outright rather than merely turned down.
		light.visible = level > 0.01
	if _lamp_material:
		_lamp_material.emission_energy_multiplier = lamp_glow * level


## A beam either side of the nose. They are built here rather than placed in
## the scene so the offsets sit next to the measurement they came from, and so
## both cars cannot drift apart.
##
## No shadows: two cars, two beams each, in two split-screen views is eight
## shadow-casting spot lights for something that is meant to be decoration.
func _build_headlights() -> void:
	for side in [-1.0, 1.0]:
		var light := SpotLight3D.new()
		light.position = Vector3(
			headlight_offset.x * side, headlight_offset.y, headlight_offset.z)
		light.rotation = Vector3(deg_to_rad(-headlight_dip), 0.0, 0.0)
		light.spot_angle = headlight_angle
		light.spot_range = headlight_range
		light.spot_attenuation = 0.9
		light.spot_angle_attenuation = 0.6
		light.light_color = headlight_color
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_headlights.append(light)


## Where the driver's eye sits, in world space.
func eye_transform() -> Transform3D:
	return Transform3D(global_transform.basis, global_transform * eye_point)


## Give this car its own copy of the materials it needs changed.
##
## The imported materials are shared between both car instances, so editing
## one in place would change the other. Three need changing: the paint, which
## carries the player's colour; the glass, which the model exports fully opaque
## and which therefore walls the driver in; and the lamp panels, which are
## authored permanently emissive and have to start off. Everything else is left
## as authored, including the double-sided faces - this car has a real interior,
## so the shell reading solid from within is what encloses the cockpit.
func _prepare_materials() -> void:
	var copies: Dictionary = {}
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.get_surface_override_material_count():
			var source := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var key := source.resource_name
			if key != PAINT_MATERIAL and key != GLASS_MATERIAL \
					and key != LAMP_MATERIAL:
				continue
			if not copies.has(key):
				var copy := source.duplicate() as StandardMaterial3D
				if key == PAINT_MATERIAL:
					copy.albedo_color = body_color
				elif key == LAMP_MATERIAL:
					# Authored permanently lit; off until switched on.
					copy.emission_energy_multiplier = 0.0
					_lamp_material = copy
				else:
					copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					copy.albedo_color.a = glass_opacity
					# Glass casting a solid shadow would put a dark slab over
					# the cabin from inside.
					copy.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				copies[key] = copy
			mesh_instance.set_surface_override_material(surface, copies[key])
	if not copies.has(PAINT_MATERIAL):
		push_warning("Car: no '%s' material found to paint" % PAINT_MATERIAL)
	if _lamp_material == null:
		push_warning("Car: no '%s' material, so the headlights cannot light up"
				% LAMP_MATERIAL)


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
	if frozen:
		velocity = Vector3.ZERO
		return

	var throttle := Input.get_axis(_brake, _accelerate)
	var steer := Input.get_axis(_steer_right, _steer_left)

	_update_slipstream(delta)
	_apply_throttle(throttle, delta)
	_apply_steering(steer, delta)
	_drive(delta)
	_animate_wheels(steer, delta)


## Stop dead and forget any slipstream. Used when the track is replaced.
func reset_motion() -> void:
	_speed = 0.0
	_slipstream = 0.0
	velocity = Vector3.ZERO


## How much top speed the car currently has, including any slipstream.
func top_speed() -> float:
	return max_speed * (1.0 + slipstream_bonus * _slipstream)


## True while the car is drafting, for effects and UI later.
func is_drafting() -> bool:
	return _slipstream > 0.05


## Build or decay the slipstream effect. It applies only to the car that is
## behind: the rival has to be ahead of us, within range, and travelling the
## same way, which is what makes it an overtaking aid rather than a free boost.
func _update_slipstream(delta: float) -> void:
	var target := 0.0
	if slipstream_enabled and rival != null and _speed > 0.0:
		var to_rival := rival.global_position - global_position
		to_rival.y = 0.0
		var gap := to_rival.length()
		if gap > 0.001 and gap <= slipstream_range:
			var forward := -global_transform.basis.z
			var ahead := forward.dot(to_rival / gap)
			var same_way := forward.dot(-rival.global_transform.basis.z)
			if ahead >= slipstream_cone and same_way >= slipstream_alignment:
				# Full strength from the peak range out to the limit.
				target = 1.0 - smoothstep(slipstream_peak_range, slipstream_range, gap)
	_slipstream = move_toward(_slipstream, target, slipstream_fade * delta)


## Turn throttle input into a change in speed. Pressing back while rolling
## forwards brakes; holding it once stopped reverses.
func _apply_throttle(throttle: float, delta: float) -> void:
	if is_zero_approx(throttle):
		_speed = move_toward(_speed, 0.0, engine_braking * delta)
	elif throttle > 0.0:
		var rate := braking if _speed < 0.0 else acceleration
		_speed = move_toward(_speed, top_speed(), rate * throttle * delta)
	else:
		var rate := braking if _speed > 0.0 else acceleration
		_speed = move_toward(_speed, -max_reverse_speed, rate * -throttle * delta)


## Rotate the car. Steering has no effect when stopped and inverts in
## reverse, so the car handles the way a real one does.
##
## The turning radius is what varies with speed, not the turn rate. An earlier
## version scaled the turn rate by speed, which cancelled the speed out
## entirely and left one fixed 13.9 m turning circle at every speed, so no
## hairpin was ever drivable however slowly you took it.
func _apply_steering(steer: float, delta: float) -> void:
	if is_zero_approx(steer) or is_zero_approx(_speed):
		return
	var speed := absf(_speed)
	# Squared, so the car stays tight through slow corners and only washes
	# wide as it approaches top speed.
	var pace := clampf(speed / max_speed, 0.0, 1.0)
	var radius := lerpf(tight_turn_radius, fast_turn_radius, pace * pace)
	rotate_y(steer * (speed / radius) * signf(_speed) * delta)


## The tightest corner the car can hold at a given speed, in metres.
func turn_radius_at(speed: float) -> float:
	var pace := clampf(absf(speed) / max_speed, 0.0, 1.0)
	return lerpf(tight_turn_radius, fast_turn_radius, pace * pace)


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

	if _steering_wheel:
		# The wheel's disc lies in its own XZ plane, so local Y is the column
		# it turns about. Post-multiplying keeps the model's column tilt.
		_steering_wheel.transform.basis = _wheel_rest_basis * Basis(
			Vector3.UP, _wheel_steer * wheel_turn_ratio)


## Roll about the wheel's own lateral axis, then yaw it for steering.
func _set_wheel(wheel: Node3D, rest: Basis, steer_angle: float) -> void:
	var spin := Basis.from_euler(
		Vector3(_wheel_roll, steer_angle, 0.0), EULER_ORDER_YXZ
	)
	wheel.transform.basis = rest * spin
