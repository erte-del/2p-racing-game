extends SceneTree

# What happens to a model somebody brought.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/garage.gd
#
# The models are made here rather than kept as files, because the point is to
# try the shapes nobody would ever put in a repository: a lorry, a marble, a
# lamp post, a plank. Each one is written out as a real .glb and then added
# through the same door a player uses, so what is being checked is the whole
# path - read it, refuse it or keep it, fit it, and put it on a car.
#
# It runs in the sandbox, so it adds and deletes cars in a garage that is not
# the one belonging to whoever is running it.

const INBOX := "user://incoming"

# Name, size in metres, and whether it is meant to survive the door.
const SHAPES := [
	["a car-sized box", Vector3(1.9, 1.3, 4.4)],
	["a lorry", Vector3(2.6, 4.1, 12.0)],
	["a marble", Vector3(0.2, 0.2, 0.2)],
	["a lamp post", Vector3(0.3, 9.0, 0.3)],
		["a plank", Vector3(0.1, 0.1, 6.0)],
]

## Fetched off the tree rather than named. A script harness is compiled before
## the autoloads are registered, so `Garage` is not an identifier here yet -
## which is why every check in this folder reaches for them this way.
var _garage: Node


func _init() -> void:
	await process_frame
	var faults := 0
	_garage = root.get_node(^"/root/Garage")

	if not Sandbox.on():
		print("  this is not running in the sandbox, so it would have written "
			+ "into a real garage; refusing to go on")
		quit(1)
		return

	faults += _the_box_has_not_moved()
	faults += await _every_shape_fits()
	faults += await _the_same_file_is_the_same_car()
	faults += await _rubbish_is_turned_away()
	faults += await _a_car_can_be_worn()
	faults += await _a_quarter_turn_refits()

	_empty_the_garage()
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## The size a model is fitted to is written down in one file and the box it is
## fitted to lives in another. This is what holds them together.
func _the_box_has_not_moved() -> int:
	var car: Car = load("res://scenes/car/car.tscn").instantiate()
	var shape := (car.get_node("Collision") as CollisionShape3D).shape as BoxShape3D
	var size := shape.size
	car.queue_free()
	if not size.is_equal_approx(CarImport.CAR_SIZE):
		print("  the collision box is %v and models are fitted to %v"
			% [size, CarImport.CAR_SIZE])
		return 1
	print("models are fitted to the %.2f x %.2f x %.2f box the car actually has"
		% [size.x, size.y, size.z])
	return 0


## Whatever went in, what comes out has to be roughly car-sized, standing on
## the ground, and centred on the road.
func _every_shape_fits() -> int:
	var faults := 0
	var room := CarImport.CAR_SIZE * CarImport.ALLOWANCE
	for shape: Array in SHAPES:
		var what: String = shape[0]
		var size: Vector3 = shape[1]
		var added: Dictionary = await _garage.add(_write_a_car(what, size))
		if not added.ok:
			print("  %s was refused: %s" % [what, added.error])
			faults += 1
			continue
		var model: Node3D = _garage.model_for(added.id)
		if model == null:
			print("  %s could not be loaded back" % what)
			faults += 1
			continue
		var fitted: AABB = model.transform * CarImport.measure(model)
		model.queue_free()

		# Inside the box it is allowed, on the ground, and on the centreline.
		var over := Vector3(fitted.size.x - room.x, fitted.size.y - room.y,
			fitted.size.z - room.z)
		if over.x > 0.001 or over.y > 0.001 or over.z > 0.001:
			print("  %s came out %v, past the %v it is allowed"
				% [what, fitted.size, room])
			faults += 1
		if absf(fitted.position.y) > 0.001:
			print("  %s does not stand on the ground; its base is at %.3f"
				% [what, fitted.position.y])
			faults += 1
		var middle: Vector3 = fitted.position + fitted.size * 0.5
		if absf(middle.x) > 0.001 or absf(middle.z) > 0.001:
			print("  %s is not on the centreline; it sits at %.2f, %.2f"
				% [what, middle.x, middle.z])
			faults += 1
		# Scaled by one number, so it is still the shape that went in.
		var was := size / _biggest(size)
		var is_now: Vector3 = fitted.size / _biggest(fitted.size)
		if not was.is_equal_approx(is_now):
			print("  %s changed shape: %v went in and %v came out"
				% [what, was, is_now])
			faults += 1
		print("%s went in at %.1f x %.1f x %.1f and came out at %.2f x %.2f x %.2f"
			% [what, size.x, size.y, size.z,
				fitted.size.x, fitted.size.y, fitted.size.z])
		await process_frame
	return faults


## A car is named by the model itself, so adding the same file again is the
## car you already had rather than a second copy of it.
func _the_same_file_is_the_same_car() -> int:
	# Written once and added twice. Exporting the same shape a second time is
	# not guaranteed to give the same bytes, and it is the bytes that name a
	# car - what is being checked is the same file, not the same shape.
	var path := _write_a_car("a twin", Vector3(1.9, 1.3, 4.4))
	var first: Dictionary = await _garage.add(path)
	var before: int = _garage.cars().size()
	var again: Dictionary = await _garage.add(path)
	if not again.ok or str(again.id) != str(first.id):
		print("  the same file came back as a different car")
		return 1
	if _garage.cars().size() != before:
		print("  adding the same file again made a second car")
		return 1
	print("adding the same file twice leaves %d cars in the garage" % before)
	return 0


## A file that is not a model has to be turned away with something a person
## can read, and has to leave nothing behind.
func _rubbish_is_turned_away() -> int:
	var faults := 0
	var where := "%s/not-a-car.glb" % Sandbox.folder(INBOX)
	var file := FileAccess.open(where, FileAccess.WRITE)
	file.store_string("this is not a model, it is a sentence")
	file.close()
	var before: int = _garage.cars().size()
	var added: Dictionary = await _garage.add(where)
	if added.ok:
		print("  a text file was accepted as a car")
		faults += 1
	elif _garage.cars().size() != before:
		print("  a refused car still left something in the garage")
		faults += 1
	else:
		print("a text file is refused: \"%s\"" % added.error)

	var wrong: Dictionary = await _garage.add("%s/car.txt" % Sandbox.folder(INBOX))
	if wrong.ok:
		print("  a .txt was accepted as a car")
		faults += 1
	return faults


## And it has to actually go on a car, without taking the car with it.
func _a_car_can_be_worn() -> int:
	var faults := 0
	var added: Dictionary = await _garage.add(_write_a_car("a lorry", Vector3(2.6, 4.1, 12.0)))
	var car: Car = load("res://scenes/car/car.tscn").instantiate()
	root.add_child(car)
	await process_frame

	var box := _hitbox(car)
	_garage.dress(car, added.id)
	await process_frame
	if car.model_id != added.id:
		print("  the car would not wear the model it was given")
		faults += 1
	if car.has_cockpit():
		print("  a brought-in car reported a cockpit")
		faults += 1
	if not _hitbox(car).is_equal_approx(box):
		print("  wearing a brought-in car moved the collision box")
		faults += 1

	# The size on the road is the whole promise, so it is measured there
	# rather than trusted from the fitting. A model fitted correctly and
	# then hung on the car at some other scale would pass every check
	# above this one.
	var shell: CarShell = car.get_node("Body")
	var on_the_road: AABB = shell.bounds()
	var loose: Node3D = _garage.model_for(added.id)
	var meant: AABB = loose.transform * CarImport.measure(loose)
	loose.queue_free()
	if not on_the_road.size.is_equal_approx(meant.size):
		print("  the car was fitted to %v and put on the road at %v"
			% [meant.size, on_the_road.size])
		faults += 1
	else:
		print("a lorry sits on the road at %.2f x %.2f x %.2f, the size it "
			% [on_the_road.size.x, on_the_road.size.y, on_the_road.size.z]
			+ "was fitted to")

	# Asked for the same car again, it must not rebuild: this is called every
	# time any setting changes, the volume slider included.
	var worn := car.get_node("Body/Model")
	_garage.dress(car, added.id)
	if car.get_node_or_null("Body/Model") != worn:
		print("  being asked for the car it is already wearing rebuilt it")
		faults += 1

	# And a car deleted out from under a player puts them back in the stock
	# one rather than leaving them with nothing to drive.
	_garage.remove(added.id)
	_garage.dress(car, added.id)
	await process_frame
	if car.model_id != _garage.STOCK or not car.has_cockpit():
		print("  a deleted car did not fall back to the stock one")
		faults += 1
	else:
		print("a car deleted mid-race puts the player back in the stock car")
	car.queue_free()
	return faults


## Turning a car swaps its length for its width, so it has to be fitted again
## on the other side of the turn rather than merely spun where it stands.
func _a_quarter_turn_refits() -> int:
	var added: Dictionary = await _garage.add(_write_a_car("a plank", Vector3(0.1, 0.1, 6.0)))
	var straight: Node3D = _garage.model_for(added.id)
	var square: AABB = straight.transform * CarImport.measure(straight)
	straight.queue_free()

	_garage.turn(added.id, 1)
	var turned_model: Node3D = _garage.model_for(added.id)
	var turned: AABB = turned_model.transform * CarImport.measure(turned_model)
	turned_model.queue_free()

	# Not the same numbers swapped over: the fit is worked out again on the
	# other side of the turn, and a plank lying across the road is held by
	# a different limit from one lying along it. What has to be true is
	# that it now runs across the road rather than along it.
	if square.size.z <= square.size.x or turned.size.x <= turned.size.z:
		print("  a quarter turn did not turn it: %v became %v"
			% [square.size, turned.size])
		return 1
	print("a quarter turn takes a %.2f m plank lying along the road to a "
		% square.size.z + "%.2f m one lying across it" % turned.size.x)
	return 0


## Write a box of a given size out as a real .glb, the way a player's model
## arrives: one file, nothing beside it.
func _write_a_car(what: String, size: Vector3) -> String:
	var model := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	# Modelled sitting on its own origin rather than centred on it, because
	# that is what most models actually do and the fit has to cope with it.
	mesh.position = Vector3(0.0, size.y * 0.5, 0.0)
	model.add_child(mesh)
	mesh.owner = model

	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_scene(model, state)
	var bytes := document.generate_buffer(state)
	model.queue_free()

	var where := "%s/%s.glb" % [Sandbox.folder(INBOX), what.replace(" ", "_")]
	var file := FileAccess.open(where, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return where


func _biggest(size: Vector3) -> float:
	return maxf(size.x, maxf(size.y, size.z))


func _hitbox(car: Car) -> AABB:
	var shape: CollisionShape3D = car.get_node("Collision")
	var box := shape.shape as BoxShape3D
	return AABB(shape.position - box.size * 0.5, box.size)


## Left as it was found, so a second run starts where the first one did.
func _empty_the_garage() -> void:
	for details: Dictionary in _garage.cars():
		_garage.remove(str(details["id"]))
