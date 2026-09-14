extends SceneTree

# Sharing cars, with no server anywhere near it.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/sharing.gd
#
# A check must never touch a live server, and a sandboxed run does not have
# one, so everything that needs an answer from the network is checked the
# other way round: that with nothing to talk to, every call comes back with a
# sentence rather than hanging or crashing. What can be checked without a
# server is checked for real - the door a downloaded car comes in through, the
# hash that decides whether it is the car that was asked for, and the way a
# storage error is read.
#
# It adds and removes cars, so it will not run outside the sandbox.


func _init() -> void:
	await process_frame
	if not Sandbox.on():
		print("  refusing to run: this check adds and removes cars, and would be "
			+ "doing it to a real garage")
		print("1 faults")
		quit(1)
		return

	var garage: Node = root.get_node("/root/Garage")
	var backend: Node = root.get_node("/root/Backend")
	var library: Node = root.get_node("/root/CarLibrary")
	_empty(garage)

	var faults := 0
	faults += await _check_there_is_no_server(backend, library)
	faults += _check_the_door(garage)
	faults += _check_the_hash(garage)
	faults += _check_what_storage_says(backend)
	faults += _check_what_is_trusted(library)

	_empty(garage)
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


# --- no server ----------------------------------------------------------

func _check_there_is_no_server(backend: Node, library: Node) -> int:
	var faults := 0
	if backend.configured():
		print("  a sandboxed run has a server to talk to")
		return 1
	if library.available() or library.can_share():
		print("  sharing is offered with no server")
		faults += 1

	var rows: Array = await library.catalogue(true)
	var shared: Dictionary = await library.publish("0123456789abcdef")
	var taken: Dictionary = await library.unpublish("0123456789abcdef")
	var fetched: Dictionary = await library.fetch("0123456789abcdef")
	print("with no server: the list has %d cars, answered %s; sharing says '%s'; "
		% [rows.size(), library.answered(), shared.error]
		+ "getting says '%s'" % fetched.error)
	if not rows.is_empty() or library.answered():
		print("  the list claims an answer from a server that is not there")
		faults += 1
	for answer: Dictionary in [shared, taken, fetched]:
		if answer.ok or str(answer.error).is_empty() or not answer.has("code"):
			print("  a call with no server did not come back as {ok, code, data, error}")
			faults += 1
	return faults


# --- the door -----------------------------------------------------------

func _check_the_door(garage: Node) -> int:
	var faults := 0
	var noise := PackedByteArray()
	for i in 4096:
		noise.append((i * 7919 + 13) % 256)
	var junk: Dictionary = garage.adopt(noise, "JUNK")
	print("adopting noise: %s" % (junk.error if not junk.ok else "TAKEN"))
	if junk.ok:
		print("  bytes that are not a model were adopted")
		faults += 1

	var huge := PackedByteArray()
	huge.resize(CarImport.MAX_BYTES + 1)
	var big: Dictionary = garage.adopt(huge, "BIG")
	print("adopting %d bytes: %s" % [huge.size(), big.error if not big.ok else "TAKEN"])
	if big.ok:
		print("  a model over 8 MB was adopted")
		faults += 1
	if not garage.cars().is_empty():
		print("  a refused download left a car in the garage")
		faults += 1

	var bytes := _model(Vector3(1.9, 1.3, 4.4))
	var kept: Dictionary = garage.adopt(bytes, "Blue streak")
	if not kept.ok:
		print("  a good model was refused: %s" % kept.error)
		return faults + 1
	var model: Node3D = garage.model_for(kept.id)
	var fitted := model.transform * CarImport.measure(model)
	model.free()
	print("adopted as %s, fitted %.3f x %.3f x %.3f"
		% [garage.name_of(kept.id), fitted.size.x, fitted.size.y, fitted.size.z])
	if garage.name_of(kept.id) != "BLUE STREAK":
		print("  a downloaded car did not keep the name it was shared under")
		faults += 1
	if not is_equal_approx(fitted.size.z, CarImport.CAR_SIZE.z):
		print("  a downloaded car was not fitted to the box")
		faults += 1

	var again: Dictionary = garage.adopt(bytes, "SOMETHING ELSE")
	if not again.ok or again.new or garage.cars().size() != 1:
		print("  adopting the same bytes twice did not leave one car")
		faults += 1
	elif garage.name_of(kept.id) != "BLUE STREAK":
		print("  adopting a car already here renamed it")
		faults += 1
	else:
		print("adopting the same bytes again is the same car, still called BLUE STREAK")
	return faults


# --- the hash -----------------------------------------------------------

func _check_the_hash(garage: Node) -> int:
	var faults := 0
	var bytes := _model(Vector3(1.9, 1.3, 4.4))
	var id: String = garage.id_for(bytes)
	if garage.id_for(bytes.duplicate()) != id or not garage.is_id(id):
		print("  the same bytes did not give the same id")
		faults += 1
	var tampered := bytes.duplicate()
	var middle := tampered.size() / 2
	tampered[middle] = tampered[middle] ^ 0x01
	var changed: String = garage.id_for(tampered)
	print("id %s; one bit flipped halfway in gives %s" % [id, changed])
	if changed == id:
		print("  a changed byte did not change the id")
		faults += 1

	# An id is also part of a path, and arrives from other people.
	for bad: String in ["../../settings", "0123456789ABCDEF", "0123456789abcde",
			"0123456789abcdeg", ""]:
		if garage.is_id(bad):
			print("  '%s' was taken for an id" % bad)
			faults += 1
	return faults


# --- what storage says --------------------------------------------------

## Storage puts the status that means something in the body, as a string, and
## a blunter one on the response: a missing object comes back as a 400 whose
## body says 404.
func _check_what_storage_says(backend: Node) -> int:
	var faults := 0
	for case: Array in [
		['{"statusCode":"409","error":"Duplicate","message":"The resource already exists"}', 400, 409],
		['{"statusCode":"404","error":"not_found","message":"Object not found"}', 400, 404],
		["<html>Forbidden</html>", 403, 403],
		["{}", 500, 500],
	]:
		# Through the same reading the real response takes, so a body that is
		# not JSON is found to be not JSON the way a real one would be.
		var parsed: Variant = backend._parsed_body((case[0] as String).to_utf8_buffer())
		var read: int = backend._code_in(parsed, case[1])
		print("%s with %d reads as %d" % [case[0].left(22), case[1], read])
		if read != case[2]:
			print("  that should have read as %d" % case[2])
			faults += 1
	return faults


# --- what is trusted ----------------------------------------------------

## A row off the server is somebody else's data. Anything that would build a
## path out of something shaped wrong is dropped before it can.
func _check_what_is_trusted(library: Node) -> int:
	var faults := 0
	var good_owner := "3f2c1a90-8b7e-4d21-9c55-0e6f7a8b9c0d"
	var rows: Array = library._read([
		{"id": "0123456789abcdef", "owner": good_owner, "name": "fine",
			"racers": {"name": "ada"}},
		{"id": "../../../settings", "owner": good_owner, "name": "climbing out"},
		{"id": "fedcba9876543210", "owner": "../elsewhere", "name": "wrong owner"},
		"not even a row",
	])
	print("of four rows off the server, %d kept: %s"
		% [rows.size(), ", ".join(rows.map(func(row: Dictionary) -> String:
			return "%s by %s" % [row.name, row.by]))])
	if rows.size() != 1 or rows[0].name != "FINE" or rows[0].by != "ada":
		print("  a row shaped wrong was kept, or a good one was not")
		faults += 1
	var path: String = library.model_path(good_owner, "0123456789abcdef")
	if path != good_owner + "/0123456789abcdef.glb":
		print("  a car's model is kept at %s" % path)
		faults += 1
	return faults


# --- models -------------------------------------------------------------

func _model(size: Vector3) -> PackedByteArray:
	var scene := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	scene.add_child(mesh)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_scene(scene, state)
	var bytes := document.generate_buffer(state)
	scene.free()
	return bytes


func _empty(garage: Node) -> void:
	for car: Dictionary in garage.cars():
		garage.remove(car.id)
	DirAccess.remove_absolute(garage.portrait_path(garage.STOCK))
	DirAccess.remove_absolute("%s/%s" % [garage.folder, garage.STOCK_FOLDER])
