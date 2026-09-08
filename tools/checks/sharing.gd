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
	faults += await _a_name_is_asked_for_before_it_goes_up()
	faults += await _the_list_can_be_searched()

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
## Pressing SHARE asks what the car is called before it sends anything, and
## what is typed is the car's name in the garage as well as on the list.
##
## Checked with no server, which is where this run is: everything up to the
## request itself happens the same way either way, and it is the panel in front
## of the request that is being looked at rather than the request.
func _a_name_is_asked_for_before_it_goes_up() -> int:
	var faults := 0
	var added: Dictionary = _garage.adopt(_a_car(), "WEDGE")
	var id := str(added.id)

	var screen: Control = load("res://scenes/garage.tscn").instantiate()
	root.add_child(screen)
	# Added rather than opened. `open` starts drawing a picture for every
	# tile, in a world of its own with a camera in it, and this run has no
	# renderer to finish that in - what is being looked at here is the panels,
	# which do not need the tiles behind them.
	await process_frame

	var panel: Control = screen.get_node(^"Naming")
	var field: LineEdit = screen.get_node(^"Naming/Page/Panel/Margin/Box/Name")
	var go: Button = screen.get_node(^"Naming/Page/Panel/Margin/Box/Row/Share")

	screen._under_the_cursor = id
	screen._on_share_pressed()
	await process_frame
	if not panel.visible:
		print("  SHARE sent the car without asking what it is called")
		faults += 1
	if field.text != "WEDGE":
		print("  the box did not start from what the car is already called: %s"
			% field.text)
		faults += 1

	# A car has to be called something.
	field.text = "   "
	screen._on_name_typed(field.text)
	if not go.disabled:
		print("  a car with no name at all could still be shared")
		faults += 1

	# What is typed is what it is called here, not only there.
	field.text = "  THE GREEN ONE  "
	screen._on_name_typed(field.text)
	await screen._confirm_the_name()
	if _garage.name_of(id) != "THE GREEN ONE":
		print("  the car is still called %s" % _garage.name_of(id))
		faults += 1
	if panel.visible:
		print("  the panel stayed up after it was answered")
		faults += 1

	# And backing out of the panel changes nothing.
	screen._under_the_cursor = id
	screen._on_share_pressed()
	await process_frame
	field.text = "SOMETHING ELSE"
	screen._close_naming()
	if _garage.name_of(id) != "THE GREEN ONE":
		print("  cancelling renamed it anyway: %s" % _garage.name_of(id))
		faults += 1
	if panel.visible:
		print("  cancelling left the panel up")
		faults += 1

	await _let_it_go(screen)
	if faults == 0:
		print("SHARE asks what the car is called, and the answer is its name "
			+ "in the garage too")
	return faults


## Typing on the browse page narrows the list, and the number beside the box
## says how many are up there.
##
## The rows are made here rather than fetched. What is being checked is the
## page - what it shows, what it says when a search matches nothing, and what
## the count reads - and that is the same page whether the rows came off a real
## server or out of this function.
func _the_list_can_be_searched() -> int:
	var faults := 0
	var screen: Control = load("res://scenes/garage.tscn").instantiate()
	root.add_child(screen)
	# Added rather than opened. `open` starts drawing a picture for every
	# tile, in a world of its own with a camera in it, and this run has no
	# renderer to finish that in - what is being looked at here is the panels,
	# which do not need the tiles behind them.
	await process_frame

	var search: LineEdit = screen.get_node(
			^"Shared/Page/Panel/Margin/Box/Find/Search")
	var count: Label = screen.get_node(
			^"Shared/Page/Panel/Margin/Box/Find/Count")
	var list: VBoxContainer = screen.get_node(
			^"Shared/Page/Panel/Margin/Box/Scroll/List")
	var message: Label = screen.get_node(^"Shared/Page/Panel/Margin/Box/Message")

	screen._fill_shared([
		_a_row("banana", "THE BANANA", "kit"),
		_a_row("lorry", "A BIG LORRY", "erte"),
		_a_row("wedge", "WEDGE", "kit"),
	])
	if list.get_child_count() != 3:
		print("  the whole list is %d rows, not 3" % list.get_child_count())
		faults += 1
	if count.text != "3 shared":
		print("  the count reads '%s' rather than '3 shared'" % count.text)
		faults += 1

	# By name, and case does not matter.
	search.text = "lorry"
	screen._show_the_shared_list()
	if list.get_child_count() != 1:
		print("  searching a name gave %d rows, not 1" % list.get_child_count())
		faults += 1
	if count.text != "1 of 3":
		print("  the count reads '%s' rather than '1 of 3'" % count.text)
		faults += 1

	# By who shared it, which is the other thing a player might have in mind.
	search.text = "KIT"
	screen._show_the_shared_list()
	if list.get_child_count() != 2:
		print("  searching a name gave %d rows, not 2" % list.get_child_count())
		faults += 1

	# Matching nothing is not the same as nobody having shared anything.
	search.text = "zzz"
	screen._show_the_shared_list()
	if list.get_child_count() != 0:
		print("  a search matching nothing still drew rows")
		faults += 1
	if not message.visible or message.text.contains("Nobody has shared"):
		print("  a search matching nothing says: %s" % message.text)
		faults += 1

	# A full page cannot know how many there are, and says so.
	var many: Array = []
	for i in _library.CATALOGUE_SIZE:
		many.append(_a_row("car%d" % i, "CAR %d" % i, "kit"))
	search.text = ""
	screen._fill_shared(many)
	if count.text != "%d+ shared" % _library.CATALOGUE_SIZE:
		print("  a full page counts itself as '%s'" % count.text)
		faults += 1

	await _let_it_go(screen)
	if faults == 0:
		print("the browse page can be searched by name or by who shared it, "
			+ "and counts what is up there")
	return faults


## Take a screen back down and wait for it to actually go. The garage draws
## its pictures in a world of its own, and quitting on top of that leaves the
## renderer holding things it then complains about at exit.
func _let_it_go(screen: Node) -> void:
	screen.queue_free()
	for i in 4:
		await process_frame


## One row shaped the way the catalogue hands them over.
func _a_row(id: String, called: String, by: String) -> Dictionary:
	return {
		"id": id, "name": called, "by": by, "vertices": 4200,
		"owner": "somebody", "mine": false, "here": false,
	}


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
