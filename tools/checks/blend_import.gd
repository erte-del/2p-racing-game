extends SceneTree

# Hand Blender a real .blend and see a car come out the other end.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/blend_import.gd
#
# The .blend is not kept in the repo. Blender is asked to build one - a box the
# rough shape of a car, off in a corner of its scene, with a camera and a light
# beside it - and save it, and then the game is asked to add that file to the
# garage exactly as a player would. What comes back is fitted, named and put on
# a car in a real race.
#
# A machine without Blender has nothing to check here, and says so and passes:
# the part of the game this covers is the part that does not exist there.

const MAKER := """import sys
import bpy

out = sys.argv[sys.argv.index("--") + 1]
empty = sys.argv[sys.argv.index("--") + 2] == "empty"
bpy.ops.wm.read_factory_settings(use_empty=True)
if not empty:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(5.0, 2.0, 3.0))
    # Blender stands things up along Z, and its length runs along Y.
    bpy.context.active_object.scale = (2.0, 4.5, 1.2)
    bpy.ops.object.light_add(type="POINT", location=(0.0, 0.0, 6.0))
bpy.ops.object.camera_add(location=(0.0, -10.0, 2.0))
bpy.ops.wm.save_as_mainfile(filepath=out)
"""


func _init() -> void:
	await process_frame
	if not Sandbox.on():
		print("  refusing to run: this check adds cars, and would be adding them "
			+ "to a real garage")
		print("1 faults")
		quit(1)
		return

	var faults := 0
	for name: String in ["Blender", "blender.exe", "Blender.app", "blender-5.2"]:
		if not Blender.looks_right(name):
			print("  %s was not taken for Blender" % name)
			faults += 1
	for name: String in ["hatch.blend", "blender_notes.py", "notepad.exe", "car.blend1"]:
		if Blender.looks_right(name):
			print("  %s was taken for Blender" % name)
			faults += 1
	print("Blender is known by its name before it is ever run")

	var blender := Blender.found()
	if blender.is_empty():
		print("Blender is not on this machine, so there is no .blend to convert.")
		print("%d faults" % faults)
		quit(1 if faults > 0 else 0)
		return
	print("using Blender at %s" % blender)

	var garage: Node = root.get_node("/root/Garage")
	var settings: Node = root.get_node("/root/GameSettings")
	_empty(garage)
	settings.car_ids = PackedStringArray(["", ""])
	settings.track_file = ""
	settings.chaos = false

	var hatch := _make_blend("check_hatch", false)
	var hollow := _make_blend("check_hollow", true)
	if hatch.is_empty() or hollow.is_empty():
		print("  Blender did not save the .blend files it was asked to make")
		print("%d faults" % (faults + 1))
		quit(1)
		return

	var started := Time.get_ticks_msec()
	var answer: Dictionary = await garage.add(hatch)
	print("check_hatch.blend: %s, in %.1f s"
		% [answer.name if answer.ok else answer.error,
			(Time.get_ticks_msec() - started) / 1000.0])
	if not answer.ok:
		print("  a .blend with a box in it did not come in")
		faults += 1
	else:
		faults += await _check_the_car(garage, settings, answer.id)

	var empty_answer: Dictionary = await garage.add(hollow)
	print("check_hollow.blend: %s" % (empty_answer.error if not empty_answer.ok else "TAKEN"))
	if empty_answer.ok:
		print("  a .blend with nothing in it but a camera was taken as a car")
		faults += 1

	for path in [hatch, hollow]:
		DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(Sandbox.path("user://make_blend.py"))
	_empty(garage)
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


func _check_the_car(garage: Node, settings: Node, id: String) -> int:
	var faults := 0
	if garage.name_of(id) != "CHECK HATCH":
		print("  the car came in called %s" % garage.name_of(id))
		faults += 1

	# What is kept is the .glb Blender made, not the .blend, so the id is the
	# same however a car arrived.
	var bytes: PackedByteArray = garage.bytes_of(id)
	if bytes.size() < 4 or bytes.slice(0, 4).get_string_from_ascii() != "glTF":
		print("  what the garage kept is not a .glb")
		faults += 1
	if garage.id_for(bytes) != id:
		print("  the car's id is not the hash of the model it kept")
		faults += 1

	var model: Node3D = garage.model_for(id)
	var fitted: AABB = model.transform * CarImport.measure(model)
	var strays := model.find_children("*", "Camera3D", true, false) \
		+ model.find_children("*", "Light3D", true, false)
	model.free()
	print("it fits as %.3f x %.3f x %.3f, standing at %.3f"
		% [fitted.size.x, fitted.size.y, fitted.size.z, fitted.position.y])
	if not is_equal_approx(fitted.size.z, CarImport.CAR_SIZE.z):
		print("  the car from the .blend is not the length of the box")
		faults += 1
	if fitted.size.x > fitted.size.z or absf(fitted.position.y) > 0.0001:
		print("  the car from the .blend is lying across the road or off the ground")
		faults += 1
	if not strays.is_empty():
		print("  the car kept the camera or the light from its .blend")
		faults += 1

	var race: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(race)
	for i in 10:
		await physics_frame
	var car: Car = race.get_node("Car1")
	var shape: CollisionShape3D = car.get_node("Collision")
	var box := (shape.shape as BoxShape3D).size
	settings.set_car_id(0, id)
	await physics_frame
	print("on the road: wearing '%s', cockpit %s, box %s"
		% [car.model_id, car.has_cockpit(), (shape.shape as BoxShape3D).size])
	if car.model_id != id or car.has_cockpit():
		print("  the car from the .blend was not put on the car on the road")
		faults += 1
	if not (shape.shape as BoxShape3D).size.is_equal_approx(box):
		print("  the car from the .blend changed the collision box")
		faults += 1
	settings.set_car_id(0, garage.STOCK)
	race.queue_free()
	await process_frame
	return faults


## Have Blender build and save a .blend. The path, or empty if none appeared.
func _make_blend(name: String, empty: bool) -> String:
	var maker := Sandbox.path("user://make_blend.py")
	var file := FileAccess.open(maker, FileAccess.WRITE)
	file.store_string(MAKER)
	file.close()
	var out := ProjectSettings.globalize_path(Sandbox.path("user://%s.blend" % name))
	DirAccess.remove_absolute(out)
	var output := []
	OS.execute(Blender.found(), PackedStringArray([
		"-b", "--factory-startup", "--python", ProjectSettings.globalize_path(maker),
		"--", out, "empty" if empty else "full",
	]), output, true)
	return out if FileAccess.file_exists(out) else ""


func _empty(garage: Node) -> void:
	for car: Dictionary in garage.cars():
		garage.remove(car.id)
	DirAccess.remove_absolute(garage.portrait_path(garage.STOCK))
	DirAccess.remove_absolute("%s/%s" % [garage.folder, garage.STOCK_FOLDER])
