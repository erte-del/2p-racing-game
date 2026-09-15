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
#
# The screens are driven for real as well: the panel SHARE opens to ask what a
# car is called, and the search on the page of shared cars. The garage screen
# is made without `open`, which would start drawing portraits, and a headless
# run has nothing to draw them with.
#
# Every autoload is reached through the tree, never by its name. This script is
# compiled before the autoloads exist, and naming one here drags its script in
# early, where it fails to compile and leaves the autoload a bare node - every
# call into which is an error that counts as nothing. So the first thing done is
# to make sure each one actually came up with its script, and to stop if not.


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
	for loaded: Array in [["Garage", garage, "adopt"], ["Backend", backend, "_code_in"],
			["CarLibrary", library, "publish"]]:
		if not (loaded[1] as Node).has_method(loaded[2]):
			print("  %s came up without its script, so nothing checked here would mean anything"
				% loaded[0])
			print("1 faults")
			quit(1)
			return
	_empty(garage)

	var faults := 0
	faults += await _check_there_is_no_server(backend, library)
	faults += _check_the_door(garage)
	faults += _check_the_hash(garage)
	faults += _check_what_storage_says(backend)
	faults += _check_what_is_trusted(library)
	faults += await _check_the_name_it_goes_up_under(garage)
	faults += await _check_the_search(library)

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


# --- the screens --------------------------------------------------------

## SHARE asks what the car is called before it goes anywhere.
##
## There is no server here, so SHARE itself is refused on the page - that is
## the page doing its job. What it opens is asked for directly instead, and
## what confirming does is followed all the way through: the name lands in the
## garage, and the share after it comes back saying there is no server rather
## than going anywhere.
func _check_the_name_it_goes_up_under(garage: Node) -> int:
	var faults := 0
	var kept: Dictionary = garage.adopt(_model(Vector3(1.8, 1.2, 4.0)), "Old banger")
	if not kept.ok:
		print("  the car to name would not go in: %s" % kept.error)
		return 1
	var id: String = kept.id
	var screen: Control = load("res://scenes/garage.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	screen.show()

	screen.call("_ask_for_a_name", id)
	await process_frame
	var naming: Control = screen.get("_naming")
	var field: LineEdit = screen.get("_name_edit")
	var share_it: Button = screen.get("_share_it")
	var selected := field.has_selection() and field.get_selected_text() == field.text
	print("SHARE asks: panel up %s, the box says '%s', all of it selected %s, at most %d"
		% [naming.visible, field.text, selected, field.max_length])
	if not naming.visible or field.text != "OLD BANGER" or not selected:
		print("  SHARE did not open on the car's current name, ready to be typed over")
		faults += 1
	if field.max_length != garage.NAME_LIMIT:
		print("  the name box takes names longer than the garage keeps")
		faults += 1

	field.text = "   "
	field.text_changed.emit(field.text)
	if not share_it.disabled:
		print("  SHARE IT could be pressed with no name in the box")
		faults += 1
	field.text = "Night bus"
	field.text_changed.emit(field.text)
	if share_it.disabled:
		print("  SHARE IT stayed refused with a name in the box")
		faults += 1

	await screen.call("_on_share_it_pressed")
	var status: Label = screen.get_node("Page/Panel/Margin/Box/Status")
	print("SHARE IT: the garage calls it %s, the panel is %s, the page says '%s'"
		% [garage.name_of(id), "up" if naming.visible else "gone", status.text])
	if garage.name_of(id) != "NIGHT BUS":
		print("  the name typed was not the name the car kept")
		faults += 1
	if naming.visible:
		print("  the panel stayed up after SHARE IT")
		faults += 1

	screen.call("_ask_for_a_name", id)
	field.text = "Something else entirely"
	field.text_changed.emit(field.text)
	screen.call("_on_cancel_naming")
	print("CANCEL: the garage still calls it %s" % garage.name_of(id))
	if garage.name_of(id) != "NIGHT BUS" or naming.visible:
		print("  cancelling the name changed something")
		faults += 1

	screen.queue_free()
	await process_frame
	garage.remove(id)
	return faults


## The search on the page of shared cars narrows what is already in hand, and
## the count says how many of how many rather than looking like cars vanishing
## off the server.
func _check_the_search(library: Node) -> int:
	var faults := 0
	var screen: Control = load("res://scenes/garage.tscn").instantiate()
	root.add_child(screen)
	await process_frame
	var rows := []
	for car: Array in [["NIGHT BUS", "ada"], ["WEDGE", "bo"], ["BUSY BEE", "cy"],
			["POST VAN", "BUSTER"], ["HOT ROD", "ada"], ["DUCK", "dee"]]:
		rows.append({"id": "%016x" % rows.size(), "name": car[0], "by": car[1],
			"owner": "3f2c1a90-8b7e-4d21-9c55-0e6f7a8b9c0d", "here": false})
	screen.call("_list_the_shared_cars", rows)
	var search: LineEdit = screen.get("_search")
	var count: Label = screen.get("_count")
	var lines: VBoxContainer = screen.get("_shared_rows")
	var note: Label = screen.get("_shared_note")
	print("six shared cars: %d lines, the count says '%s'" % [lines.get_child_count(), count.text])
	if lines.get_child_count() != 6 or count.text != "6":
		print("  the page does not show six of six")
		faults += 1

	for query: Array in [["bus", 3, "3 of 6"], ["ADA", 2, "2 of 6"]]:
		search.text = query[0]
		search.text_changed.emit(search.text)
		print("searching '%s': %d lines, the count says '%s'"
			% [query[0], lines.get_child_count(), count.text])
		if lines.get_child_count() != query[1] or count.text != query[2]:
			print("  searching '%s' should have left %d, counted '%s'"
				% [query[0], query[1], query[2]])
			faults += 1

	search.text = "zeppelin"
	search.text_changed.emit(search.text)
	print("searching 'zeppelin': %d lines, the page says '%s'"
		% [lines.get_child_count(), note.text])
	if lines.get_child_count() != 0 or note.text != "Nothing matches that.":
		print("  a search with no match did not say so")
		faults += 1

	search.text = ""
	search.text_changed.emit(search.text)
	if lines.get_child_count() != 6 or count.text != "6":
		print("  clearing the search did not bring every car back")
		faults += 1

	# A page as full as the list gets is the newest sixty of an unknown number.
	var full := []
	for i in library.CATALOGUE_SIZE:
		full.append({"id": "%016x" % i, "name": "CAR %d" % i, "by": "ada",
			"owner": "3f2c1a90-8b7e-4d21-9c55-0e6f7a8b9c0d", "here": i % 2 == 0})
	screen.call("_list_the_shared_cars", full)
	print("a full page counts as '%s'" % count.text)
	if count.text != "%d+" % library.CATALOGUE_SIZE:
		print("  a full page claimed to know how many cars there are")
		faults += 1

	# And one long name cannot stretch the page.
	var long := [{"id": "00000000000000aa", "by": "someone with a long name too",
		"name": "A NAME FAR LONGER THAN ANY NAME SHOULD BE ALLOWED TO RUN ON FOR",
		"owner": "3f2c1a90-8b7e-4d21-9c55-0e6f7a8b9c0d", "here": false}]
	screen.call("_list_the_shared_cars", long)
	await process_frame
	var width := (lines.get_child(0) as Control).get_combined_minimum_size().x
	print("a line with a long name asks for %.0f px" % width)
	if width > 760.0:
		print("  a long name widened the line past 760 px")
		faults += 1

	screen.queue_free()
	await process_frame
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
