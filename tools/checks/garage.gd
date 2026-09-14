extends SceneTree

# What a car brought in from outside is made into, and what it can never change.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/garage.gd
#
# Every model here is built in code - a box of a given size, written out as a
# .glb - rather than kept as a binary file in the repo. A fixture nobody can
# read is a fixture nobody can tell is still testing what it says.
#
# The fitting is checked on the numbers, and then the one promise that matters
# most is checked on the road: a car wearing somebody else's model is measured
# by firing rays at it in the physics world, because what the fit says it did
# is not the same thing as what the car actually collides with.
#
# It adds and removes cars, so it will not run outside the sandbox.

const CAR_SIZE := CarImport.CAR_SIZE
const ROOM := CarImport.CAR_SIZE * CarImport.ALLOWANCE
## The stock collision box, which is the thing that must never move.
const BOX := Vector3(2.06, 1.45, 4.87)


func _init() -> void:
	await process_frame
	if not Sandbox.on():
		print("  refusing to run: this check adds and removes cars, and would be "
			+ "doing it to a real garage")
		print("1 faults")
		quit(1)
		return

	var garage: Node = root.get_node("/root/Garage")
	var settings: Node = root.get_node("/root/GameSettings")
	print("the garage is at %s" % garage.folder)
	_empty(garage)
	settings.car_ids = PackedStringArray(["", ""])
	settings.track_file = ""
	settings.chaos = false

	var faults := 0
	faults += _check_the_fit()
	faults += _check_what_is_kept()
	faults += _check_the_door(garage)
	faults += await _check_the_road(garage, settings)

	_empty(garage)
	var left: Array = garage.cars()
	if not left.is_empty() or not DirAccess.get_directories_at(garage.folder).is_empty():
		print("  the sandbox garage was not left empty")
		faults += 1
	else:
		print("the sandbox garage is empty again")
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


# --- the fit ------------------------------------------------------------

func _check_the_fit() -> int:
	var faults := 0

	var car := _fitted(Vector3(2.06, 1.45, 4.87))
	print("a car-sized box comes out %s" % _size(car))
	if not is_equal_approx(car.size.z, CAR_SIZE.z):
		print("  a car-sized box is %.4f m long rather than %.2f" % [car.size.z, CAR_SIZE.z])
		faults += 1

	# Ten metres rather than an articulated twelve. A 4.1 m tall lorry twelve
	# metres long runs out of length first, by a hair: 4.87 / 12 is a scale of
	# 0.4058 and 1.6675 / 4.1 is 0.4067. Ten is plainly a lorry and plainly
	# brought down by its height, which is the case this is here to catch.
	var lorry := _fitted(Vector3(2.6, 4.1, 10.0))
	print("a lorry comes out %s" % _size(lorry))
	if not is_equal_approx(lorry.size.y, ROOM.y) or lorry.size.z >= CAR_SIZE.z:
		print("  the lorry was not brought down by its height")
		faults += 1

	for thing: Array in [["a lamp post", Vector3(0.3, 6.0, 0.3)],
			["a plank stood on end", Vector3(0.3, 2.4, 0.05)]]:
		var fitted := _fitted(thing[1])
		print("%s comes out %s" % [thing[0], _size(fitted)])
		if fitted.size.z > 1.0:
			print("  %s came out as long as a car" % thing[0])
			faults += 1
		faults += _over_the_room(thing[0], fitted)

	var marble := _fitted(Vector3(0.02, 0.02, 0.02))
	print("a marble comes out %s, %.0f times the size it went in"
		% [_size(marble), marble.size.z / 0.02])
	if marble.size.z < 1.0:
		print("  the marble was not scaled up")
		faults += 1
	faults += _over_the_room("the marble", marble)

	# Every one of them stands on the ground and sits in the middle of the
	# road, however far off both the model was when it was made.
	for fitted in [car, lorry, marble]:
		var centre: Vector3 = fitted.get_center()
		if absf(fitted.position.y) > 0.0001 or absf(centre.x) > 0.0001 \
				or absf(centre.z) > 0.0001:
			print("  a fitted model sits at %s rather than on the ground in the middle"
				% fitted)
			faults += 1
	print("every fitted model stands on the ground, centred")

	# A quarter turn puts the car's length across the road, and the fit on
	# the far side of that is a different fit: the width is what runs out.
	var turned := _fitted(Vector3(2.06, 1.45, 4.87), 1)
	print("the same box a quarter turned comes out %s" % _size(turned))
	if not is_equal_approx(turned.size.x, ROOM.x) or turned.size.z >= CAR_SIZE.z:
		print("  a quarter turn did not swap the length limit for the width one")
		faults += 1
	if not _fitted(Vector3(2.06, 1.45, 4.87), 4).is_equal_approx(car):
		print("  four quarter turns is not where the car started")
		faults += 1

	# And a box that is wider than it is long is guessed to be lying across
	# the road, and turned to lie along it.
	var sideways := _fitted(Vector3(4.87, 1.45, 2.06))
	if not is_equal_approx(sideways.size.z, CAR_SIZE.z):
		print("  a car modelled lying across the road was not turned to face down it")
		faults += 1
	return faults


func _over_the_room(what: String, fitted: AABB) -> int:
	for axis in 3:
		if fitted.size[axis] > ROOM[axis] + 0.0001:
			print("  %s is %.3f m on axis %d, past the %.3f allowed"
				% [what, fitted.size[axis], axis, ROOM[axis]])
			return 1
	return 0


func _fitted(size: Vector3, turns := 0) -> AABB:
	var read := CarImport.from_bytes(_model(size))
	if not read.ok:
		print("  a %s box would not import: %s" % [size, read.error])
		return AABB()
	var model: Node3D = read.model
	var bounds := CarImport.fit(model, turns) * CarImport.measure(model)
	model.free()
	return bounds


# --- what a model is allowed to keep ------------------------------------

func _check_what_is_kept() -> int:
	var faults := 0
	var read := CarImport.from_bytes(_model(Vector3(2.0, 1.4, 4.4), true))
	if not read.ok:
		print("  a model with a camera, a light and a body in it was refused: %s"
			% read.error)
		return 1
	var model: Node3D = read.model
	for kind in ["Camera3D", "Light3D", "CollisionObject3D", "CollisionShape3D",
			"AnimationPlayer"]:
		var found := model.find_children("*", kind, true, false)
		if not found.is_empty():
			print("  a brought-in model kept a %s" % kind)
			faults += 1
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 1:
		print("  stripping left %d meshes where there was one" % meshes.size())
		faults += 1
	model.free()
	if faults == 0:
		print("a model's camera, light, animation player and physics body are all stripped")
	return faults


# --- the door -----------------------------------------------------------

func _check_the_door(garage: Node) -> int:
	var faults := 0
	var before := DirAccess.get_directories_at(garage.folder).size()

	var garbage := Sandbox.path("user://garage_check_garbage.glb")
	var noise := PackedByteArray()
	for i in 4096:
		noise.append((i * 7919 + 13) % 256)
	_write(garbage, noise)
	var text := Sandbox.path("user://garage_check_note.txt")
	_write(text, "not a car".to_utf8_buffer())

	for path in [garbage, text]:
		var answer: Dictionary = garage.add(path)
		print("%s: %s" % [path.get_file(), answer.error if not answer.ok else "TAKEN"])
		if answer.ok:
			print("  %s was taken as a car" % path.get_file())
			faults += 1

	# A .gltf keeping its geometry in a file beside it is only the whole car
	# on the machine it was made on.
	var loose := Sandbox.folder("user://garage_check_loose")
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var scene := _scene(Vector3(2.0, 1.4, 4.4), false)
	document.append_from_scene(scene, state)
	scene.free()
	document.write_to_filesystem(state, loose + "/loose.gltf")
	var answer: Dictionary = garage.add(loose + "/loose.gltf")
	print("loose.gltf: %s" % (answer.error if not answer.ok else "TAKEN"))
	if answer.ok:
		print("  a .gltf with its buffer in another file was taken")
		faults += 1

	if DirAccess.get_directories_at(garage.folder).size() != before:
		print("  a refused file left something behind in the garage")
		faults += 1
	else:
		print("nothing refused left anything in the garage")

	var wedge := Sandbox.path("user://wedge.glb")
	_write(wedge, _model(Vector3(1.9, 1.2, 4.3)))
	var first: Dictionary = garage.add(wedge)
	var second: Dictionary = garage.add(wedge)
	print("wedge.glb added twice: %s then %s, %d car(s) in the garage"
		% ["new" if first.new else "known", "new" if second.new else "known",
			garage.cars().size()])
	if not first.ok or garage.cars().size() != 1 or second.new:
		print("  adding the same file twice did not leave one car")
		faults += 1
	if first.ok and garage.name_of(first.id) != "WEDGE":
		print("  the wedge is called %s" % garage.name_of(first.id))
		faults += 1

	for path in [garbage, text, wedge, loose + "/loose.gltf", loose + "/loose0.bin"]:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(loose)
	return faults


# --- the road -----------------------------------------------------------

func _check_the_road(garage: Node, settings: Node) -> int:
	var faults := 0
	var race: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(race)
	for i in 10:
		await physics_frame
	var car: Car = race.get_node("Car1")
	var other: Car = race.get_node("Car2")

	var stock := _box_on_the_road(car)
	print("the stock car measures %s on the road" % _size(AABB(Vector3.ZERO, stock)))
	if not stock.is_equal_approx(BOX):
		print("  the stock car does not measure as its own collision box")
		faults += 1

	# The worst case: a model carrying a physics body twenty metres across. If
	# the strip ever let that through, the rays would find it.
	var cluttered := Sandbox.path("user://cluttered_car.glb")
	_write(cluttered, _model(Vector3(1.8, 1.3, 4.1), true))
	var added: Dictionary = garage.add(cluttered)
	DirAccess.remove_absolute(cluttered)
	if not added.ok:
		print("  the cluttered car was refused: %s" % added.error)
		race.queue_free()
		return faults + 1
	var id: String = added.id

	settings.set_car_id(0, id)
	await physics_frame
	await physics_frame
	if car.model_id != id:
		print("  picking a car did not dress the car on the road")
		faults += 1
	if car.has_cockpit():
		print("  a brought-in car reported a cockpit")
		faults += 1

	var dressed := _box_on_the_road(car)
	print("dressed in %s it measures %s on the road"
		% [garage.name_of(id), _size(AABB(Vector3.ZERO, dressed))])
	if not dressed.is_equal_approx(stock):
		print("  a brought-in model changed what the car collides with")
		faults += 1
	if not other.model_id.is_empty():
		print("  dressing player one's car dressed player two's as well")
		faults += 1

	# What is on the road is the fit, measured off the model where it stands
	# rather than trusted from the numbers - and the measuring has to be able
	# to tell when it is not.
	var worn := _model_on(car)
	print("the model on the road is %s" % _size(worn))
	if not _problems_with(worn).is_empty():
		print("  the model on the road is not fitted: %s" % _problems_with(worn))
		faults += 1
	var model: Node3D = car.get_node("Body/Model")
	model.scale *= 2.0
	var doubled := _model_on(car)
	model.scale /= 2.0
	if _problems_with(doubled).is_empty():
		print("  a model at twice the size would not have been noticed")
		faults += 1
	else:
		print("a model at twice the size would be caught: %s" % _problems_with(doubled))

	# Turning the car while it is on the road turns it on the road.
	garage.turn(id, 1)
	await physics_frame
	var turned := _model_on(car)
	print("turned a quarter, the model on the road is %s" % _size(turned))
	if car.model_turns != 1 or not is_equal_approx(turned.size.x, ROOM.x):
		print("  turning the car did not turn the one on the road")
		faults += 1
	if not _box_on_the_road(car).is_equal_approx(stock):
		print("  turning the model changed what the car collides with")
		faults += 1

	# Take it away with the player still in it.
	garage.remove(id)
	await physics_frame
	print("removed with player one in it: player one is in '%s', cockpit %s"
		% [settings.car_id(0), car.has_cockpit()])
	if settings.car_id(0) != garage.STOCK:
		print("  removing a car left the player's setting pointing at it")
		faults += 1
	if not car.has_cockpit() or not car.model_id.is_empty():
		print("  removing the car a player was in did not put them in the stock car")
		faults += 1

	# And an id nobody has - a setting from another machine - is the stock car.
	settings.set_car_id(1, "0123456789abcdef")
	await physics_frame
	if not other.has_cockpit():
		print("  an id that is not in the garage left a car with no stock model")
		faults += 1
	settings.set_car_id(1, garage.STOCK)

	race.queue_free()
	await process_frame
	return faults


## The collision box as the physics world sees it: rays fired in at the car
## along each of its own axes, stopping at the first thing that is the car.
func _box_on_the_road(car: Car) -> Vector3:
	var space := car.get_world_3d().direct_space_state
	var basis := car.global_transform.basis
	var centre := car.global_position + basis.y * 0.725
	var reach := 40.0
	var found := Vector3.ZERO
	for axis in 3:
		var direction: Vector3 = basis[axis].normalized()
		var total := 0.0
		for side in [1.0, -1.0]:
			var from: Vector3 = centre + direction * reach * side
			total += reach - _first_hit_on(space, car, from, centre)
		found[axis] = total
	return found


func _first_hit_on(space: PhysicsDirectSpaceState3D, car: Car, from: Vector3,
		to: Vector3) -> float:
	var skip: Array[RID] = []
	for attempt in 16:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = skip
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return from.distance_to(to)
		var collider: Object = hit.collider
		# Anything hung off the car counts as the car: a body a model smuggled
		# in would be exactly that.
		if collider == car or (collider is Node and car.is_ancestor_of(collider)):
			return from.distance_to(hit.position)
		skip.append(hit.rid)
	return from.distance_to(to)


## The model the car is wearing, measured in the car's own space.
func _model_on(car: Car) -> AABB:
	var into := car.global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	for node in car.get_node("Body/Model").find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var box := (into * mesh.global_transform) * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


## What is wrong with a model as it sits on a car, or nothing.
func _problems_with(bounds: AABB) -> String:
	var wrong := PackedStringArray()
	if bounds.size.z > CAR_SIZE.z + 0.001:
		wrong.append("longer than the car")
	if bounds.size.x > ROOM.x + 0.001:
		wrong.append("wider than the room")
	if bounds.size.y > ROOM.y + 0.001:
		wrong.append("taller than the room")
	if absf(bounds.position.y) > 0.02:
		wrong.append("not on the ground")
	var fills := false
	for axis in 3:
		var room: float = CAR_SIZE.z if axis == 2 else ROOM[axis]
		fills = fills or is_equal_approx(bounds.size[axis], room)
	if not fills:
		wrong.append("no side reaches its limit")
	return ", ".join(wrong)


# --- models -------------------------------------------------------------

## A box of the given size as .glb bytes. Put off to one side and up in the
## air on purpose, so centring and grounding are what is being checked rather
## than something the model already had.
##
## `clutter` hangs everything a model is not allowed to bring in off it: a
## camera, a light, an animation player, and a physics body far bigger than
## the car.
func _model(size: Vector3, clutter := false) -> PackedByteArray:
	var scene := _scene(size, clutter)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_scene(scene, state)
	var bytes := document.generate_buffer(state)
	scene.free()
	return bytes


func _scene(size: Vector3, clutter: bool) -> Node3D:
	var scene := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = Vector3(3.0, 5.0, -2.0)
	scene.add_child(mesh)
	if clutter:
		scene.add_child(Camera3D.new())
		scene.add_child(OmniLight3D.new())
		scene.add_child(AnimationPlayer.new())
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var huge := BoxShape3D.new()
		huge.size = Vector3(20.0, 20.0, 20.0)
		shape.shape = huge
		body.add_child(shape)
		scene.add_child(body)
	return scene


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _empty(garage: Node) -> void:
	for car: Dictionary in garage.cars():
		garage.remove(car.id)
	DirAccess.remove_absolute(garage.portrait_path(garage.STOCK))
	DirAccess.remove_absolute("%s/%s" % [garage.folder, garage.STOCK_FOLDER])


func _size(bounds: AABB) -> String:
	return "%.3f x %.3f x %.3f" % [bounds.size.x, bounds.size.y, bounds.size.z]
