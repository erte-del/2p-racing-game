class_name CarShell
extends Node3D

## Everything about a car that is looked at rather than driven on: the model,
## its paint, its wheels, its headlights and the point the driver's eye sits
## at.
##
## The speed, the steering and the box the car actually collides with are none
## of this node's business; they live in `Car`. The split is what lets a player
## bring their own model. The shell is swapped and the car underneath it is
## not, so whatever somebody drops into the game drives exactly like the car
## that shipped with it and hits things in exactly the same places.
##
## It is also the node that tips. `Car` works out the pitch from the road and
## sets it here, so the shell leans into a climb while the collision box it
## hangs off stays upright.
##
## Everything below is written to work on a model that has none of what the
## car that shipped with the game has. A model with no wheels simply has no
## wheels turning; one with no named paint gets whatever panel is biggest
## painted instead; one with no materials at all is given one, because two
## cars nobody can tell apart is not a split screen anybody can read.

## Name of the material in the stock model that carries the car's paint. Every
## surface using it gets recoloured; the tyres, glass and chrome are left alone.
const PAINT_MATERIAL := "Paint"
## The stock model's glass exports as opaque, which walls the first person view
## in.
const GLASS_MATERIAL := "Glass"
## The headlight panels. Authored permanently emissive, which is only right
## once they are switched on.
const LAMP_MATERIAL := "Lamp"

## The wheels the stock model carries, front pair first.
const FRONT_WHEELS := ["Wheel_FL", "Wheel_FR"]
const REAR_WHEELS := ["Wheel_BL", "Wheel_BR"]

@export_group("Cockpit")
## Where the driver's eye sits, in the car's own space. The car is right hand
## drive, so this sits over on the +X side behind the wheel.
@export var eye_point := Vector3(0.4, 1.18, 0.14)
## How much of the world shows through the windows.
@export_range(0.0, 1.0) var glass_opacity := 0.18
## A steering wheel turns much further than the road wheels do.
@export var wheel_turn_ratio := 3.0

@export_group("Headlights")
## Where the right headlight sits on the stock model, in the car's own space;
## the left one is mirrored. Measured off the model: the two Lamp quads sit at
## x +/-0.602, 0.683 above the ground, 2.179 ahead of the wheelbase centre.
## A model that came from outside has its own shape and gets its beams placed
## off that instead.
@export var headlight_offset := Vector3(0.602, 0.683, -2.179)
## Where the beams go on a model nobody has measured, as fractions of what it
## turned out to be: this far out from the centreline, this far up its height,
## and on the front face. Roughly where a car keeps its lights, which is as
## much as can be said about a shape the game has never seen.
@export var headlight_spread := 0.29
@export var headlight_height := 0.47
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
@export var max_wheel_steer := 0.5     ## rad the front wheels visually turn
@export var wheel_steer_speed := 4.0   ## how fast the wheels visually turn

## The model itself, and whether it is the one the game ships with.
##
## Being the stock model decides three things: that there is an interior for
## the first person camera to sit in, that the materials are the ones this
## script knows by name, and that a missing wheel is worth complaining about.
## They travel together today because there are exactly two kinds of model -
## ours and somebody else's - and the day there is a third they can be split.
var _model: Node3D
var _stock := true

## The beams, and the material of the lamp panels they shine out of.
var _headlights: Array[SpotLight3D] = []
var _lamp_material: StandardMaterial3D
var _paint_material: StandardMaterial3D

## The model's own steering wheel, turned along with the front wheels.
var _steering_wheel: Node3D
var _wheel_rest_basis := Basis.IDENTITY

var _front_wheels: Array[Node3D] = []
var _rear_wheels: Array[Node3D] = []
# Each wheel's untouched orientation, so the animation composes onto it
# instead of assuming the model exported with identity rotations.
var _wheel_rest: Array[Basis] = []

## Visual-only wheel state.
var _wheel_steer := 0.0
var _wheel_roll := 0.0

## How big the model turned out to be, in the shell's own space. Only a model
## from outside needs this - it is what its headlights are placed off - but it
## is measured either way, because phase two has to be able to ask.
var _bounds := AABB()

## The paint and the light level the shell is currently wearing. Remembered
## rather than merely applied, so a model swapped in halfway through a race
## arrives already the right colour and already lit, instead of waiting for
## the next time something happens to set them.
var _paint := Color.WHITE
var _light_level := 0.0


func _ready() -> void:
	_build_headlights()
	# Whatever the scene was authored with is the car the game ships with.
	_model = get_node_or_null(^"Model")
	_take_up_the_model(true)


## Put a different model in the shell.
##
## `stock` says this is the model the game ships with, and should be false for
## anything a player brought. Call it on a car that is in the tree: the shell
## measures the model where it stands.
##
## Nothing about the car changes but its looks. The collision box is a sibling
## of this node rather than a child, so it is not touched here and cannot be.
func set_model(model: Node3D, stock := false) -> void:
	if _model != null:
		# Removed before it is freed rather than left to queue_free, which
		# defers: a search run in the same frame would otherwise still find
		# the wheels of the car that has just been thrown away.
		remove_child(_model)
		_model.queue_free()
	_model = model
	if _model != null:
		_model.name = "Model"
		add_child(_model)
	_take_up_the_model(stock)


## Whether there is an interior for the first person camera to sit in.
func has_cockpit() -> bool:
	return _stock and _model != null


## How big the model is, in the shell's own space. Empty until there is one.
func bounds() -> AABB:
	return _bounds


## Where the driver's eye sits, in world space.
func eye_transform() -> Transform3D:
	return Transform3D(global_transform.basis, global_transform * eye_point)


## Switch the headlights on, off, or part way. 0 is off, 1 is full night.
##
## The car is told a level rather than the time of day: it has no business
## knowing what the sky is doing, and a level can just as well come from a
## tunnel or from a player pressing a button later.
func set_headlights(level: float) -> void:
	var clamped := clampf(level, 0.0, 1.0)
	# Asked every frame, and the answer only changes while the sun is going
	# down or coming up.
	if clamped == _light_level:
		return
	_light_level = clamped
	_light_the_lamps()


## Put the light level the shell is holding onto the beams and the lamps.
func _light_the_lamps() -> void:
	for light in _headlights:
		light.light_energy = headlight_energy * _light_level
		# A light at zero energy still costs something to render, so the beams
		# are switched off outright rather than merely turned down.
		light.visible = _light_level > 0.01
	if _lamp_material:
		_lamp_material.emission_energy_multiplier = lamp_glow * _light_level


## Paint the car. The material is this shell's own copy rather than the one
## the model shipped with, so this repaints one car and not both.
func repaint(colour: Color) -> void:
	_paint = colour
	if _paint_material != null:
		_paint_material.albedo_color = colour


## Turn the front wheels and roll all four. Purely cosmetic, and a model with
## no wheels quietly has nothing to do here.
func animate_wheels(steer: float, speed: float, wheel_radius: float,
		delta: float) -> void:
	_wheel_steer = move_toward(
		_wheel_steer, steer * max_wheel_steer, wheel_steer_speed * delta
	)
	# wrap so the angle cannot grow without bound over a long race
	_wheel_roll = fposmod(
		_wheel_roll - speed * delta / maxf(wheel_radius, 0.001), TAU)

	for i in _front_wheels.size():
		_set_wheel(_front_wheels[i], _wheel_rest[i], _wheel_steer)
	for i in _rear_wheels.size():
		_set_wheel(_rear_wheels[i], _wheel_rest[_front_wheels.size() + i], 0.0)

	if _steering_wheel:
		# The wheel's disc lies in its own XZ plane, so local Y is the column
		# it turns about. Post-multiplying keeps the model's column tilt.
		_steering_wheel.transform.basis = _wheel_rest_basis * Basis(
			Vector3.UP, _wheel_steer * wheel_turn_ratio)


## Take up whatever model is now in place: find its moving parts, take copies
## of the materials that have to change, work out where its lights go, and put
## the paint and the light level back on it.
func _take_up_the_model(stock: bool) -> void:
	_stock = stock
	_front_wheels = _collect_wheels(FRONT_WHEELS)
	_rear_wheels = _collect_wheels(REAR_WHEELS)
	_wheel_rest.clear()
	for wheel in _front_wheels + _rear_wheels:
		_wheel_rest.append(wheel.transform.basis)
	# A fresh model starts square rather than inheriting however far the last
	# one happened to be turned.
	_wheel_steer = 0.0
	_wheel_roll = 0.0

	_steering_wheel = _find("SteeringWheel")
	if _steering_wheel != null:
		_wheel_rest_basis = _steering_wheel.transform.basis
	else:
		_wheel_rest_basis = Basis.IDENTITY
		if _stock:
			push_warning("CarShell: no SteeringWheel in the model")

	_bounds = _measure()
	_prepare_materials()
	_place_headlights()
	repaint(_paint)
	# Put on outright rather than through set_headlights, which would see the
	# level has not changed and skip the fresh lamp material.
	_light_the_lamps()


## Found by name rather than by path: the glTF importer decides how deeply it
## nests the model, and that should not break the wheels. Searched from the
## model rather than from here, so the shell's own children - the headlights -
## can never be mistaken for part of it.
func _find(name: String) -> Node3D:
	if _model == null:
		return null
	return _model.find_child(name, true, false) as Node3D


## A model that came from outside is not expected to have any of these, so it
## is not complained at for going without.
func _collect_wheels(names: Array) -> Array[Node3D]:
	var found: Array[Node3D] = []
	for name in names:
		var wheel := _find(name)
		if wheel:
			found.append(wheel)
		elif _stock:
			push_warning("CarShell: wheel '%s' not found in the model" % name)
	return found


## How much room the model takes up, in the shell's own space.
func _measure() -> AABB:
	if _model == null or not is_inside_tree():
		return AABB()
	var into := global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var box := (into * mesh_instance.global_transform) * mesh_instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


## Give this shell its own copies of the materials it needs to change, so that
## editing one car's paint does not edit the other's - the imported materials
## are shared between every instance of a model.
func _prepare_materials() -> void:
	_paint_material = null
	_lamp_material = null
	if _model == null:
		return
	if _stock:
		_prepare_stock_materials()
	else:
		_prepare_brought_in_materials()


## Three of the stock model's materials need changing: the paint, which
## carries the player's colour; the glass, which the model exports fully opaque
## and which therefore walls the driver in; and the lamp panels, which are
## authored permanently emissive and have to start off. Everything else is left
## as authored, including the double-sided faces - this car has a real
## interior, so the shell reading solid from within is what encloses the
## cockpit.
func _prepare_stock_materials() -> void:
	var copies: Dictionary = {}
	for entry in _surfaces():
		var mesh_instance: MeshInstance3D = entry[0]
		var surface: int = entry[1]
		var source: StandardMaterial3D = entry[2]
		if source == null:
			continue
		var key := source.resource_name
		if key != PAINT_MATERIAL and key != GLASS_MATERIAL \
				and key != LAMP_MATERIAL:
			continue
		if not copies.has(key):
			var copy := source.duplicate() as StandardMaterial3D
			if key == PAINT_MATERIAL:
				_paint_material = copy
			elif key == LAMP_MATERIAL:
				# Authored permanently lit; off until switched on.
				copy.emission_energy_multiplier = 0.0
				_lamp_material = copy
			else:
				copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				copy.albedo_color.a = glass_opacity
				# Glass casting a solid shadow would put a dark slab over the
				# cabin from inside.
				copy.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			copies[key] = copy
		mesh_instance.set_surface_override_material(surface, copies[key])
	if _paint_material == null:
		push_warning("CarShell: no '%s' material found to paint" % PAINT_MATERIAL)
	if _lamp_material == null:
		push_warning("CarShell: no '%s' material, so the headlights cannot light up"
				% LAMP_MATERIAL)


## Paint a model that knows nothing about any of this.
##
## Nothing in it is called Paint, so the biggest panel is taken to be the body
## and painted instead - on almost anything shaped like a vehicle that is the
## shell. The colour multiplies whatever the material already had, so a model
## that arrived with a texture keeps its texture and wears the player's colour
## over it rather than losing it.
##
## Which car is which is not decoration. Both halves of a split screen show the
## same world from two seats, and a player picks their own car out of it by its
## colour, so a model with no materials at all is given one rather than being
## left the same shade as the car it is racing.
func _prepare_brought_in_materials() -> void:
	var surfaces := _surfaces()
	var biggest: StandardMaterial3D = null
	var most := -1
	for entry in surfaces:
		var source: StandardMaterial3D = entry[2]
		if source == null:
			continue
		var size: int = entry[3]
		if size > most:
			most = size
			biggest = source

	if biggest == null:
		# Nothing to take a copy of, so the paint is the only material it has.
		_paint_material = StandardMaterial3D.new()
		for entry in surfaces:
			(entry[0] as MeshInstance3D).set_surface_override_material(
					entry[1], _paint_material)
		return

	_paint_material = biggest.duplicate() as StandardMaterial3D
	for entry in surfaces:
		if entry[2] == biggest:
			(entry[0] as MeshInstance3D).set_surface_override_material(
					entry[1], _paint_material)


## Every surface in the model, as [mesh instance, surface, material, vertices].
##
## The vertex count stands in for how big a panel is. It is not the area, but
## it sorts a car's shell above its wing mirrors on any model somebody actually
## modelled, and it can be had without pulling the mesh apart.
func _surfaces() -> Array:
	var found: Array = []
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var mesh := mesh_instance.mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			var size := 1
			if mesh is ArrayMesh:
				size = (mesh as ArrayMesh).surface_get_array_len(surface)
			found.append([mesh_instance, surface,
					mesh_instance.get_active_material(surface) as StandardMaterial3D,
					size])
	return found


## A beam either side of the nose. They are built here rather than placed in
## the scene so the offsets sit next to the measurement they came from, and so
## both cars cannot drift apart.
##
## No shadows: two cars, two beams each, in two split-screen views is eight
## shadow-casting spot lights for something that is meant to be decoration.
##
## They belong to the shell rather than to the model, so swapping the model
## does not leave a car driving through the night with nothing lit - and they
## are on the shell rather than on the car so that they tip with it, since
## headlights that stayed level would light the sky on a ramp and the road at
## their feet on the way down.
func _build_headlights() -> void:
	for side in [-1.0, 1.0]:
		var light := SpotLight3D.new()
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


## Put the beams where this particular model keeps its lights: on the numbers
## measured off the stock car, and on the shape itself for anything else.
func _place_headlights() -> void:
	var offset := headlight_offset
	if not _stock:
		offset = _headlights_off_the_shape()
	for i in _headlights.size():
		var side := -1.0 if i == 0 else 1.0
		_headlights[i].position = Vector3(offset.x * side, offset.y, offset.z)


func _headlights_off_the_shape() -> Vector3:
	if _bounds.size.is_zero_approx():
		return headlight_offset
	return Vector3(
		_bounds.size.x * headlight_spread,
		_bounds.position.y + _bounds.size.y * headlight_height,
		# The car faces -Z, so the front of the model is the near edge of it.
		_bounds.position.z)


## Roll about the wheel's own lateral axis, then yaw it for steering.
func _set_wheel(wheel: Node3D, rest: Basis, steer_angle: float) -> void:
	var spin := Basis.from_euler(
		Vector3(_wheel_roll, steer_angle, 0.0), EULER_ORDER_YXZ
	)
	wheel.transform.basis = rest * spin
