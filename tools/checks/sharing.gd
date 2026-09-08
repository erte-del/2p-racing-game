extends SceneTree

# Sharing a car, and what happens when there is nowhere to share it to.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/sharing.gd
#
# There is no server here. A sandboxed run has no backend at all - not "does
# not send", has none - which is exactly the state a build shipped without a
# backend.cfg is in, and that is the state most copies of this game will be in.
# So what this checks is the half that has to work anyway: that the whole
# feature goes quiet rather than failing loudly, and that a model arriving from
# somewhere else is put through the same reader as one off the disk.
#
# What it cannot check is the server itself. The policies in backend/schema.sql
# are the thing that actually stops one player writing over another's car, and
# they are SQL running in somebody's project rather than code running here.

const INBOX := "user://incoming"

var _garage: Node
var _library: Node


func _init() -> void:
	await process_frame
	_garage = root.get_node(^"/root/Garage")
	_library = root.get_node(^"/root/CarLibrary")

	if not Sandbox.on():
		print("  not running in the sandbox, so it would reach a real server; "
			+ "refusing to go on")
		quit(1)
		return

	var faults := 0
	faults += await _quiet_with_no_server()
	faults += await _a_model_off_the_wire_is_checked()
	faults += await _the_id_is_the_model()

	_empty_the_garage()
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## With no server, every one of these has to answer rather than fail. This is
## the path a build with no backend.cfg takes, and it is walked by real players.
func _quiet_with_no_server() -> int:
	var faults := 0
	if _library.available():
		print("  a sandboxed run found a server to talk to")
		faults += 1
	if _library.can_share():
		print("  a sandboxed run thought it could share a car")
		faults += 1

	var listing: Array = await _library.catalogue()
	if not listing.is_empty():
		print("  the catalogue came back with %d rows and no server"
			% listing.size())
		faults += 1

	# Every one of these has to come back with something a screen can put in
	# front of somebody, rather than throwing or handing back null.
	for trial: Array in [
		["publishing", await _library.publish("0123456789abcdef")],
		["unpublishing", await _library.unpublish("0123456789abcdef")],
		["fetching", await _library.fetch("0123456789abcdef")],
	]:
		var answer: Dictionary = trial[1]
		if answer.ok:
			print("  %s worked with no server behind it" % trial[0])
			faults += 1
		elif str(answer.error).is_empty():
			print("  %s failed without saying why" % trial[0])
			faults += 1
	print("with no server: nothing is offered, and every call still answers")
	return faults


## A model that came down off the wire is a model written by a stranger.
func _a_model_off_the_wire_is_checked() -> int:
	var faults := 0

	# Rubbish is refused the same way it is refused off the disk.
	var rubbish: Dictionary = _garage.adopt(
		"this is not a model, it is a sentence".to_utf8_buffer(), "TROJAN")
	if rubbish.ok:
		print("  a sentence was adopted as a car")
		faults += 1
	else:
		print("a sentence off the wire is refused: \"%s\"" % rubbish.error)

	# And something enormous is refused for being enormous, not read first.
	var huge := PackedByteArray()
	huge.resize(CarImport.MAX_BYTES + 1)
	var too_big: Dictionary = _garage.adopt(huge, "ENORMOUS")
	if too_big.ok:
		print("  a %d MB model was adopted" % (huge.size() >> 20))
		faults += 1
	else:
		print("and one over the size cap is turned away before it is parsed")

	# A real one goes in, and is the same car it would have been off the disk.
	var bytes := _a_car()
	var shared: Dictionary = _garage.adopt(bytes, "FROM SOMEBODY")
	if not shared.ok:
		print("  a good model off the wire was refused: %s" % shared.error)
		return faults + 1
	if _garage.name_of(str(shared.id)) != "FROM SOMEBODY":
		print("  a downloaded car did not keep the name it was shared under")
		faults += 1

	var model: Node3D = _garage.model_for(str(shared.id))
	if model == null:
		print("  a downloaded car could not be loaded back")
		faults += 1
	else:
		var fitted: AABB = model.transform * CarImport.measure(model)
		model.queue_free()
		if fitted.size.z > CarImport.CAR_SIZE.z + 0.001:
			print("  a downloaded car was not fitted: it came out %v"
				% fitted.size)
			faults += 1
		else:
			print("a car somebody shared is fitted like any other, at "
				+ "%.2f x %.2f x %.2f" % [fitted.size.x, fitted.size.y,
					fitted.size.z])
	return faults


## The id is the hash of the model, which is what makes it possible to say that
## what came down is what was asked for.
func _the_id_is_the_model() -> int:
	var faults := 0
	var bytes := _a_car()
	var id: String = _garage.id_for(bytes)
	if _garage.id_for(bytes) != id:
		print("  the same model hashed to two different ids")
		faults += 1

	var tampered := bytes.duplicate()
	tampered[tampered.size() - 1] = tampered[tampered.size() - 1] ^ 0xFF
	if _garage.id_for(tampered) == id:
		print("  a model with a byte changed kept the same id")
		faults += 1
	else:
		print("one byte changed anywhere in a model gives it a different id, "
			+ "which is what lets a download be weighed against what was asked for")

	# And adopting the same bytes twice is the car you already had.
	var first: Dictionary = _garage.adopt(bytes, "TWICE")
	var before: int = _garage.cars().size()
	var again: Dictionary = _garage.adopt(bytes, "TWICE OVER")
	if str(again.id) != str(first.id) or _garage.cars().size() != before:
		print("  the same model adopted twice made two cars")
		faults += 1
	else:
		print("downloading a car you already added is the car you already had")
	return faults


## A small .glb, made here, standing in for one that came off a server.
func _a_car() -> PackedByteArray:
	var model := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.9, 1.2, 4.3)
	mesh.mesh = box
	mesh.position.y = 0.6
	model.add_child(mesh)
	mesh.owner = model
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	document.append_from_scene(model, state)
	var bytes := document.generate_buffer(state)
	model.queue_free()
	return bytes


func _empty_the_garage() -> void:
	for details: Dictionary in _garage.cars():
		_garage.remove(str(details["id"]))
