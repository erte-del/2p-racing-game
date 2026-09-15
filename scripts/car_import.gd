class_name CarImport
extends RefCounted

## The one door every car model comes in through.
##
## A model a player picked off their own disk and a model downloaded from a
## stranger are the same bytes to this, and they go through exactly the same
## checks. There is no second way in that skips them, so there is no second
## way in for a bad file to find.
##
## What comes out the other side is a scene holding meshes and nothing else,
## and `fit` works out the transform that sits it on the car. Neither touches
## the car: the collision box, the tuning and the road are none of this
## script's business, which is the whole reason a car can wear anything.
##
## Everything is read at run time with `GLTFDocument` rather than imported. A
## shipped game has no import step - the editor that turns a .glb into a
## resource is not on the player's machine - so the game does the reading
## itself.

## The biggest file taken, in bytes. A car nobody can download in a few seconds
## is a car nobody downloads, and the cap is also what bounds everything below
## it: nothing here can be asked to decode more than this.
const MAX_BYTES := 8 << 20
## What one car may cost to draw. There are two of them on the road, and each
## is drawn twice - once in each half of the screen.
const MAX_VERTICES := 250000
## Every surface is a draw call of its own, and a model exported with a
## material per face is a model that draws itself a thousand times a frame.
const MAX_SURFACES := 96
## What a model file is called. A .blend is a different thing entirely and
## comes in through `Blender`, which turns it into one of these first.
const EXTENSIONS := ["glb", "gltf"]

## The box the car collides with: width, height, length. A model is fitted to
## the box rather than the box to the model, because the box is what decides
## where the car can go and a lap in one car has to mean a lap in any other.
const CAR_SIZE := Vector3(2.06, 1.45, 4.87)
## How far past the box a model may reach across and upwards, as a fraction.
## A car with mirrors, a spoiler or wide arches is a little bigger than the box
## it drives in; a model half again as wide as it would be seen scraping
## through gaps the car is not actually touching.
const ALLOWANCE := 1.15

## The four bytes a binary glTF starts with, and the name of the chunk that
## holds its description.
const GLB_MAGIC := 0x46546C67
const JSON_CHUNK := 0x4E4F534A

## The only kinds of node a car is allowed to keep. A whitelist rather than a
## list of what to throw out, because the list of what to throw out is
## whatever the next exporter thinks of.
const KEPT := ["Node3D", "MeshInstance3D", "Skeleton3D", "BoneAttachment3D"]


## Read a model off the disk: the same as `from_bytes`, once the file has been
## found to be the right kind and not too big.
static func read(path: String) -> Dictionary:
	var extension := path.get_extension().to_lower()
	if not extension in EXTENSIONS:
		return _refused("A car has to be a .glb or a .gltf file.")
	var loaded := bytes_at(path)
	if not loaded.ok:
		return _refused(loaded.error)
	return from_bytes(loaded.bytes)


## The bytes of a file, refused before they are read if there are too many of
## them. Asked of the length first, so an enormous file is turned away without
## first being pulled into memory to be counted.
static func bytes_at(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "That file is not there any more.",
			"bytes": PackedByteArray()}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "That file could not be opened.",
			"bytes": PackedByteArray()}
	var length := file.get_length()
	if length > MAX_BYTES:
		return {"ok": false, "error": _too_big(length), "bytes": PackedByteArray()}
	return {"ok": true, "error": "", "bytes": file.get_buffer(length)}


## Turn bytes into a car, or say plainly why not.
##
## Always answers `{ok, error, model, vertices}`, whatever it was handed. The
## bytes may be anything at all - a download that stopped halfway, a file with
## the wrong name on it, or something written to be hostile - and none of those
## is allowed to be a crash.
static func from_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return _refused("That file is empty.")
	if bytes.size() > MAX_BYTES:
		return _refused(_too_big(bytes.size()))

	var description: Variant = _description_of(bytes)
	if typeof(description) != TYPE_DICTIONARY:
		return _refused("That is not a glTF model.")
	# A car has to be one file. A .gltf that keeps its geometry or its textures
	# in files beside it is only the whole car on the machine it was made on,
	# and handed to anybody else it would arrive as a car with pieces missing.
	# Refused here, in words, rather than left to fail inside the reader.
	if _reaches_outside(description):
		return _refused("That model keeps its parts in other files beside it. "
			+ "Export it as a single .glb, so it is still the whole car when "
			+ "it is handed to someone else.")

	var document := GLTFDocument.new()
	var state := GLTFState.new()
	# No base path, which is what makes the rule above hold for good: with
	# nowhere to look, the reader cannot go and find a file beside this one
	# even if something slipped past the check.
	if document.append_from_buffer(bytes, "", state) != OK:
		return _refused("That model could not be read.")
	var scene := document.generate_scene(state)
	if scene == null:
		return _refused("That model could not be read.")

	# Held in a plain node of its own, so whatever the file made its root - a
	# mesh, a camera, anything - is a child to be judged like every other, and
	# the transform `fit` works out has somewhere to go that is nobody's own.
	var model := Node3D.new()
	model.name = "Model"
	# The reader marks everything it built as belonging to the scene it built,
	# which is only worth anything to a scene that is going to be saved. This
	# one never is, and a node that still claims an owner complains when it is
	# moved somewhere that owner is not.
	for node in scene.find_children("*", "", true, false):
		node.owner = null
	model.add_child(scene)
	_strip(model)

	var cost := _cost_of(model)
	var problem := ""
	if cost.y == 0:
		problem = "There is nothing to see in that model."
	elif cost.x > MAX_VERTICES:
		problem = ("That model has %d vertices. A car can have %d at most."
			% [cost.x, MAX_VERTICES])
	elif cost.y > MAX_SURFACES:
		problem = ("That model is made of %d separate surfaces. A car can "
			+ "have %d at most.") % [cost.y, MAX_SURFACES]
	if not problem.is_empty():
		model.free()
		return _refused(problem)
	return {"ok": true, "error": "", "model": model, "vertices": cost.x}


## How much room a model takes up, in its own space: every mesh in it, merged.
##
## The model's own transform is left out, since that is what `fit` is about to
## replace. Worked out by walking up the parents rather than from global
## transforms, so it gives the same answer in the tree and out of it.
static func measure(model: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var box := _placed_within(mesh_instance, model) * mesh_instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


## The transform that puts a model on the car: turned to face down the road,
## sized to the box, centred across and along it and stood on the ground.
##
## One scale for all three axes, never three. A motorbike squashed out to the
## width of a car and a rubber duck stretched to its length are not those
## things any more, and a player who brought one wanted to drive that.
##
## The length is matched to the box, and the width and the height are held
## under it with a little allowance. Whichever of the three runs out first is
## the one that decides: a lorry is brought down by its height, and a lamp
## post comes out as a short lamp post rather than a tall thin one the length
## of a car.
##
## `quarter_turns` are applied before anything is measured. A quarter turn puts
## the length across the road, and the fit on the far side of that turn is a
## different fit - so it is worked out there rather than turned afterwards.
static func fit(model: Node3D, quarter_turns := 0) -> Transform3D:
	var bounds := measure(model)
	if bounds.size.is_zero_approx():
		return Transform3D.IDENTITY

	# A guess, and only a guess: most things are longer than they are wide, so
	# the longer way across the ground is taken to be the length. The player
	# turns it from there if the guess was wrong.
	var turn := quarter_turn(1 if bounds.size.x > bounds.size.z else 0)
	turn = quarter_turn(quarter_turns) * turn
	var turned := Transform3D(turn, Vector3.ZERO) * bounds

	var scale := INF
	scale = _tighter(scale, CAR_SIZE.z, turned.size.z)
	scale = _tighter(scale, CAR_SIZE.x * ALLOWANCE, turned.size.x)
	scale = _tighter(scale, CAR_SIZE.y * ALLOWANCE, turned.size.y)
	if is_inf(scale):
		scale = 1.0

	var low := turned.position * scale
	var high := turned.end * scale
	var offset := Vector3(-(low.x + high.x) * 0.5, -low.y, -(low.z + high.z) * 0.5)
	return Transform3D(turn.scaled(Vector3.ONE * scale), offset)


## A turn about the upright, a quarter at a time. Written out exactly rather
## than worked out from an angle, so a car that has been turned four times is
## the car it started as and not one a ten-millionth of a degree off.
static func quarter_turn(quarters: int) -> Basis:
	match posmod(quarters, 4):
		1:
			return Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0))
		2:
			return Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1))
		3:
			return Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
	return Basis.IDENTITY


## Throw away everything that is not something to look at.
##
## A camera in a model would fight the split-screen cameras for the view. A
## light would be a second sun bolted to the bumper. An animation player would
## run the thing about. And a physics body would be worst of all: a box of
## somebody else's size hung off the car, colliding with the road, which is
## precisely the one thing a model is never allowed to change.
##
## A node of a kind that is not kept is swapped for a plain one in the same
## place rather than thrown away with everything under it, because exporters
## hang meshes off whatever they like and a wheel under a light is still a
## wheel. The name is kept too, so anything in the model that points at a node
## by its path - a skin at its skeleton - still finds it.
static func _strip(node: Node) -> void:
	for child in node.get_children():
		if not child is Node3D:
			node.remove_child(child)
			child.free()
			continue
		var kept := child as Node3D
		if not kept.get_class() in KEPT:
			kept = _plain_in_place_of(kept)
		_strip(kept)
		# Anything left with nothing to see in it - an empty, or what used to
		# be a camera - goes as well, so the model is only what is drawn.
		if not kept is MeshInstance3D and kept.find_children(
				"*", "MeshInstance3D", true, false).is_empty():
			node.remove_child(kept)
			kept.free()


static func _plain_in_place_of(node: Node3D) -> Node3D:
	var parent := node.get_parent()
	var plain := Node3D.new()
	plain.transform = node.transform
	# Put in place before anything is moved into it, so the children arrive
	# somewhere already under the scene that owns them.
	parent.add_child(plain)
	parent.move_child(plain, node.get_index())
	plain.owner = node.owner
	for child in node.get_children():
		node.remove_child(child)
		plain.add_child(child)
	var name := node.name
	parent.remove_child(node)
	node.free()
	plain.name = name
	return plain


## Vertices and surfaces, counted per mesh instance rather than per mesh. The
## same wheel used four times is drawn four times, and it is what is drawn that
## the limits are about.
static func _cost_of(model: Node3D) -> Vector2i:
	var vertices := 0
	var surfaces := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			surfaces += 1
			if mesh is ArrayMesh:
				vertices += (mesh as ArrayMesh).surface_get_array_len(surface)
			else:
				var arrays := mesh.surface_get_arrays(surface)
				vertices += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	return Vector2i(vertices, surfaces)


## The JSON that describes a glTF, from either kind of file, or null when the
## bytes are not a glTF at all.
##
## Read by hand ahead of the real reader so the file can be judged before
## anything is built from it, and so bytes that are not a model at all are
## turned away in a sentence instead of in a page of engine errors.
static func _description_of(bytes: PackedByteArray) -> Variant:
	var text := ""
	if bytes.size() >= 20 and bytes.decode_u32(0) == GLB_MAGIC:
		var length := bytes.decode_u32(12)
		if bytes.decode_u32(16) != JSON_CHUNK or length > bytes.size() - 20:
			return null
		text = bytes.slice(20, 20 + length).get_string_from_utf8()
	else:
		# The first thing in a .gltf that is not a space is its opening brace.
		# Looked for in the bytes before any of them are decoded, because
		# decoding a file of noise as text complains about every byte of it.
		if not _opens_with_a_brace(bytes):
			return null
		text = bytes.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("asset"):
		return null
	return parsed


static func _opens_with_a_brace(bytes: PackedByteArray) -> bool:
	var at := 0
	# A byte order mark, which some editors put at the front of a text file.
	if bytes.size() >= 3 and bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF:
		at = 3
	while at < bytes.size() and bytes[at] in [0x20, 0x09, 0x0A, 0x0D]:
		at += 1
	return at < bytes.size() and bytes[at] == 0x7B


## Whether any buffer or image in the description lives outside the file. The
## chunk inside a .glb has no address at all, and a `data:` address carries its
## contents with it; anything else is a file somewhere else.
static func _reaches_outside(description: Dictionary) -> bool:
	for key in ["buffers", "images"]:
		var entries: Variant = description.get(key, [])
		if typeof(entries) != TYPE_ARRAY:
			continue
		for entry: Variant in entries:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var uri: Variant = (entry as Dictionary).get("uri")
			if uri != null and not str(uri).begins_with("data:"):
				return true
	return false


## Where a node sits in the space of one of its ancestors.
static func _placed_within(node: Node3D, top: Node3D) -> Transform3D:
	var placed := Transform3D.IDENTITY
	var at: Node = node
	while at != null and at != top:
		if at is Node3D:
			placed = (at as Node3D).transform * placed
		at = at.get_parent()
	return placed


## The smaller of the scale so far and the one this axis allows. An axis with
## no size cannot say anything about how big the model may be, so it is not
## asked.
static func _tighter(scale: float, room: float, size: float) -> float:
	if size <= 0.000001:
		return scale
	return minf(scale, room / size)


static func _too_big(bytes: int) -> String:
	return "That model is %.1f MB. A car can be %d MB at most." % [
		bytes / float(1 << 20), MAX_BYTES >> 20]


static func _refused(why: String) -> Dictionary:
	return {"ok": false, "error": why, "model": null, "vertices": 0}
