extends SceneTree

# Look at the garage, open over a race.
#   Godot --path . --fixed-fps 60 --script tools/checks/garage_shot.gd -- <out_dir>
#
# Three cars go in, built here out of boxes and wheels, and the garage is
# opened from the pause menu the way a player opens it. Saves garage.png, and
# garage_turned.png after one of them has been given a quarter turn.
#
# Sandboxed, like everything in tools/: the cars go into a garage of their
# own, which is emptied again at the end.


func _init() -> void:
	await process_frame
	if not Sandbox.on():
		print("refusing to run outside the sandbox")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	var garage: Node = root.get_node("/root/Garage")
	var settings: Node = root.get_node("/root/GameSettings")
	_empty(garage)
	settings.track_file = ""
	settings.chaos = false
	settings.solo = false
	settings.car_ids = PackedStringArray(["", ""])

	var ids := []
	for car: Array in [
		["wedge", _wedge()], ["post_van", _van()], ["hot_rod", _rod()],
	]:
		var path := Sandbox.path("user://%s.glb" % car[0])
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		document.append_from_scene(car[1], state)
		(car[1] as Node).free()
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(document.generate_buffer(state))
		file.close()
		var answer: Dictionary = await garage.add(path)
		DirAccess.remove_absolute(path)
		print("added %s: %s" % [car[0], answer.name if answer.ok else answer.error])
		ids.append(answer.id)

	settings.set_car_id(0, ids[0])
	settings.set_car_id(1, ids[1])
	change_scene_to_file("res://scenes/main.tscn")
	for i in 30:
		await process_frame
	var race: Node = current_scene
	race.call("_open_pause")
	await process_frame
	var pause: Control = race.get_node("Pause")
	pause.get_node("Page/Panel/Margin/Box/Garage").emit_signal("pressed")
	var screen: Control = pause.get_node("GarageScreen")
	await _portraits(garage, ids)
	_report(screen)
	root.get_texture().get_image().save_png("%s/garage.png" % out)

	screen.set("_subject", ids[2])
	screen.call("_on_turn_pressed")
	await _portraits(garage, ids)
	print("after TURN: %s has %d quarter turn(s), status says '%s'"
		% [garage.name_of(ids[2]), garage.quarter_turns(ids[2]),
			screen.get_node("Page/Panel/Margin/Box/Status").text])
	root.get_texture().get_image().save_png("%s/garage_turned.png" % out)

	# Both players back in the stock car before the screen writes the settings
	# out on its way closed, so nothing run after this opens in a car that is
	# about to be thrown away.
	settings.car_ids = PackedStringArray(["", ""])
	screen.call("close")
	await process_frame
	_empty(garage)
	quit()


## Wait until every car has a portrait on the disk, and a few frames more for
## the tiles to show them.
func _portraits(garage: Node, ids: Array) -> void:
	for frame in 600:
		var all := FileAccess.file_exists(garage.portrait_path(garage.STOCK))
		for id in ids:
			all = all and FileAccess.file_exists(garage.portrait_path(id))
		if all:
			break
		await process_frame
	for frame in 6:
		await process_frame


func _report(screen: Control) -> void:
	var panel: Control = screen.get_node("Page/Panel")
	var back: Control = screen.get_node("Page/Panel/Margin/Box/Back")
	var window := Rect2(Vector2.ZERO, Vector2(root.size))
	print("panel %s at %s, inside the window: %s"
		% [panel.size, panel.position, window.encloses(panel.get_global_rect())])
	print("BACK visible on the screen: %s" % window.encloses(back.get_global_rect()))
	for player in ["P1", "P2"]:
		var grid: Node = screen.get_node("Page/Panel/Margin/Box/Columns/%s/Scroll/Grid" % player)
		var line := PackedStringArray()
		for tile: Button in grid.get_children():
			line.append("%s%s%s" % [tile.text, " [held]" if tile.button_pressed else "",
				"" if tile.icon != null else " (no picture)"])
		print("%s: %s" % [player, ", ".join(line)])


# --- three cars ---------------------------------------------------------

func _wedge() -> Node3D:
	var car := Node3D.new()
	# A prism's triangle stands in its own XY plane, so it is laid along the
	# car with a quarter turn about the upright: low at the nose, tall at the
	# tail, and as wide as a car across.
	var wedge := PrismMesh.new()
	wedge.left_to_right = 1.0
	_part(car, wedge, Vector3(4.4, 1.0, 1.8), Vector3(0, 0.85, 0),
		Color(0.95, 0.75, 0.1), Vector3(0, 90, 0))
	_wheels(car, 1.5, 1.4, 0.34)
	return car


func _van() -> Node3D:
	var car := Node3D.new()
	_part(car, BoxMesh.new(), Vector3(2.0, 2.1, 5.2), Vector3(0, 1.35, 0.2),
		Color(0.85, 0.12, 0.12))
	_part(car, BoxMesh.new(), Vector3(1.9, 0.5, 0.05), Vector3(0, 1.8, -2.43),
		Color(0.2, 0.25, 0.3))
	_wheels(car, 1.6, 1.8, 0.4)
	return car


func _rod() -> Node3D:
	var car := Node3D.new()
	_part(car, BoxMesh.new(), Vector3(1.4, 0.55, 4.0), Vector3(0, 0.6, 0),
		Color(0.2, 0.3, 0.85))
	_part(car, BoxMesh.new(), Vector3(1.2, 0.5, 1.3), Vector3(0, 1.1, 0.7),
		Color(0.15, 0.2, 0.6))
	_part(car, CylinderMesh.new(), Vector3(0.5, 1.2, 0.5), Vector3(0, 0.95, -1.4),
		Color(0.7, 0.7, 0.72))
	_wheels(car, 1.4, 1.45, 0.42)
	return car


func _wheels(car: Node3D, track: float, base: float, radius: float) -> void:
	for x in [-track * 0.5, track * 0.5]:
		for z in [-base, base]:
			_part(car, CylinderMesh.new(), Vector3(radius * 2.0, 0.3, radius * 2.0),
				Vector3(x, radius, z), Color(0.08, 0.08, 0.09), Vector3(0, 0, 90))


func _part(car: Node3D, mesh: PrimitiveMesh, size: Vector3, at: Vector3,
		colour: Color, turn := Vector3.ZERO) -> void:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is PrismMesh:
		(mesh as PrismMesh).size = size
	elif mesh is CylinderMesh:
		var cylinder := mesh as CylinderMesh
		cylinder.top_radius = size.x * 0.5
		cylinder.bottom_radius = size.x * 0.5
		cylinder.height = size.y
	var paint := StandardMaterial3D.new()
	paint.albedo_color = colour
	mesh.material = paint
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.position = at
	part.rotation_degrees = turn
	car.add_child(part)


func _empty(garage: Node) -> void:
	for car: Dictionary in garage.cars():
		garage.remove(car.id)
	DirAccess.remove_absolute(garage.portrait_path(garage.STOCK))
	DirAccess.remove_absolute("%s/%s" % [garage.folder, garage.STOCK_FOLDER])
