extends SceneTree

# Look at the garage, with a few brought-in cars in it.
#   Godot --path . --script tools/checks/garage_shot.gd -- <out_dir>
#
# Three shots: the garage as two players see it, the same after a car has been
# turned, and the race behind it with a brought-in car actually on the road.
# The cars are made here rather than kept as files, for the reason the garage
# check makes its own: what wants looking at is what the game does with a
# shape nobody designed for it.

const SHAPES := [
	["Wedge", Vector3(1.9, 1.1, 4.6)],
	["Lorry", Vector3(2.6, 4.1, 12.0)],
	["Marble", Vector3(0.4, 0.4, 0.4)],
]


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	var garage: Node = root.get_node(^"/root/Garage")
	var settings: Node = root.get_node(^"/root/GameSettings")
	settings.solo = false
	settings.chaos = false
	settings.track_file = ""

	var ids: Array = []
	for shape: Array in SHAPES:
		var added: Dictionary = await garage.add(_write_a_car(shape[0], shape[1]))
		garage.rename(str(added.id), str(shape[0]).to_upper())
		ids.append(str(added.id))
	# Both players in something they brought, so the shot shows the thing
	# being checked rather than two stock cars with a menu over them.
	settings.set_car_id(0, ids[0])
	settings.set_car_id(1, ids[1])

	var race: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(race)
	for i in 30:
		await process_frame

	# Untyped on purpose. Naming `PauseMenu` here would make this script
	# depend on it at compile time, and a --script harness is compiled
	# before the autoloads exist - so the menu scripts, which do name them,
	# would fail to compile and take this with them.
	var pause: Node = race.get_node("Pause")
	pause.open("ENDLESS COURSE", "NEXT COURSE")
	var screen: Node = pause.get_node("GarageScreen")
	screen.open(2)
	# The pictures are drawn a frame at a time as the models load.
	for i in 40:
		await process_frame
	await _shoot(out, "garage")

	# Turned a quarter of the way round, which refits it and redraws it.
	screen._under_the_cursor = ids[1]
	screen._on_turn_pressed()
	for i in 40:
		await process_frame
	await _shoot(out, "garage_turned")

	# And the road underneath, with what was picked actually on it.
	screen.close()
	pause.close()
	for i in 20:
		await process_frame
	await _shoot(out, "on_the_road")

	for id: String in ids:
		garage.remove(id)
	print("wrote three shots to %s" % out)
	quit(0)


func _write_a_car(what: String, size: Vector3) -> String:
	var model := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = Vector3(0.0, size.y * 0.5, 0.0)
	model.add_child(mesh)
	mesh.owner = model
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_scene(model, state)
	var bytes := document.generate_buffer(state)
	model.queue_free()
	var where := "%s/%s.glb" % [Sandbox.folder("user://incoming"), what]
	var file := FileAccess.open(where, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	return where


func _shoot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	var shot := root.get_texture().get_image()
	shot.save_png("%s/%s.png" % [out, name])
	print("%s" % name)
