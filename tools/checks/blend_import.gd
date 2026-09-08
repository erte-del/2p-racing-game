extends SceneTree

# A .blend, all the way from the file to a car on the road.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/blend_import.gd
#
# It makes its own .blend rather than keeping one in the repository, by asking
# Blender to build a cube and save it - so the check works on any machine that
# has Blender, and the file it reads is one Blender actually wrote rather than
# one somebody committed years ago.
#
# A machine without Blender is a supported machine: .blend is a convenience and
# .glb is the road everything else takes. So this passes quietly rather than
# failing when there is no Blender to run.

const MADE := "user://made.blend"

## Big enough that the fitting has to do something, and with a light and a
## camera in the scene, which have to be gone by the time it reaches the game.
const BUILD := ("import bpy; bpy.ops.wm.read_factory_settings(use_empty=True); "
		+ "bpy.ops.mesh.primitive_cube_add(size=3.0); "
		+ "bpy.ops.object.light_add(type='SUN'); "
		+ "bpy.ops.object.camera_add(); "
		+ "bpy.ops.wm.save_as_mainfile(filepath='%s')")

var _garage: Node


func _init() -> void:
	await process_frame
	_garage = root.get_node(^"/root/Garage")

	if not Sandbox.on():
		print("  not running in the sandbox, so it would write into a real "
			+ "garage; refusing to go on")
		quit(1)
		return

	var blender := Blender.found()
	if blender.is_empty():
		# Not a fault. The game says so and points at .glb, which is exactly
		# what this machine would do.
		print("no Blender on this machine, so there is nothing to convert")
		print("0 faults")
		quit(0)
		return
	print("Blender is at %s" % blender)

	var faults := 0
	var made := await _build_a_blend(blender)
	if made.is_empty():
		print("  Blender would not write a .blend to read back")
		print("1 faults")
		quit(1)
		return

	var added: Dictionary = await _garage.add(made)
	if not added.ok:
		print("  the .blend was refused: %s" % added.error)
		print("1 faults")
		quit(1)
		return
	var id := str(added.id)
	print("a .blend went in and came out as %s" % _garage.name_of(id))

	# It is named after what the player picked, not after the .glb it became
	# on the way past.
	if not _garage.name_of(id).contains("MADE"):
		print("  the car was named after the file it was converted into, "
			+ "not the one that was picked")
		faults += 1

	var model: Node3D = _garage.model_for(id)
	if model == null:
		print("  the converted car could not be loaded back")
		print("%d faults" % (faults + 1))
		quit(1)
		return

	# A 3 m cube is held by its height, so it comes out as tall as a car is
	# allowed to be and square with it.
	var fitted: AABB = model.transform * CarImport.measure(model)
	var room := CarImport.CAR_SIZE * CarImport.ALLOWANCE
	if fitted.size.y > room.y + 0.001 or fitted.size.z > room.z + 0.001:
		print("  a 3 m cube came out %v, past the %v it is allowed"
			% [fitted.size, room])
		faults += 1
	if absf(fitted.position.y) > 0.001:
		print("  it does not stand on the ground; its base is at %.3f"
			% fitted.position.y)
		faults += 1
	print("a 3 m cube came out %.2f x %.2f x %.2f, standing on the road"
		% [fitted.size.x, fitted.size.y, fitted.size.z])

	# The sun and the camera in that scene are not the game's to carry.
	var lights := model.find_children("*", "Light3D", true, false)
	var cameras := model.find_children("*", "Camera3D", true, false)
	if not lights.is_empty() or not cameras.is_empty():
		print("  %d lights and %d cameras came through with the model"
			% [lights.size(), cameras.size()])
		faults += 1
	else:
		print("the sun and the camera that were in the scene did not come with it")
	model.queue_free()

	# And it goes on a car without taking the car with it.
	var car: Car = load("res://scenes/car/car.tscn").instantiate()
	root.add_child(car)
	await process_frame
	var box := _hitbox(car)
	_garage.dress(car, id)
	await process_frame
	if car.model_id != id:
		print("  the car would not wear the converted model")
		faults += 1
	if not _hitbox(car).is_equal_approx(box):
		print("  wearing a converted model moved the collision box")
		faults += 1
	if car.has_cockpit():
		print("  a converted car reported a cockpit")
		faults += 1
	print("it drives on the same %.2f x %.2f x %.2f box as everything else"
		% [box.size.x, box.size.y, box.size.z])
	car.queue_free()

	_garage.remove(id)
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Ask Blender to build a scene and save it, so there is a real .blend to read.
func _build_a_blend(blender: String) -> String:
	var where := ProjectSettings.globalize_path(Sandbox.path(MADE))
	DirAccess.remove_absolute(where)
	var pid := OS.create_process(blender, [
		"--factory-startup", "--disable-autoexec", "-b",
		"--python-expr", BUILD % where,
	])
	if pid < 0:
		return ""
	# Against the clock, not against the frames: a headless run gets
	# through thousands of those a second.
	var started := Time.get_ticks_msec()
	while OS.is_process_running(pid):
		await process_frame
		if Time.get_ticks_msec() - started > 120000:
			OS.kill(pid)
			return ""
	return where if FileAccess.file_exists(where) else ""


func _hitbox(car: Car) -> AABB:
	var shape: CollisionShape3D = car.get_node("Collision")
	var box := shape.shape as BoxShape3D
	return AABB(shape.position - box.size * 0.5, box.size)
