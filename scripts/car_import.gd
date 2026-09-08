class_name CarImport
extends RefCounted

## Reading a model somebody brought, and working out how big it has to be.
##
## Everything a player adds to their garage comes through here, and so does
## everything they download from anybody else. One door, because the checks
## below are the only thing standing between the game and a file that was
## written by a stranger - and a second door that skipped half of them would
## be the one that got used.
##
## What comes out is a plain `Node3D` full of meshes, already stripped of
## anything that is not one, and a transform that will sit it on the road at
## the size of the car the game ships with. What does not come out is a car:
## a model is a thing to look at, and `CarShell` is what wears it.

## What the game will read. A .blend is not on the list and cannot be: Godot
## imports those in the editor by handing them to Blender, and there is no
## editor in a game somebody is playing. Turning one into a .glb is a separate
## job for a machine that has Blender on it.
const EXTENSIONS := ["glb", "gltf"]

## How big a model may be, in bytes. Generous for a car - the one the game
## ships with is half a megabyte - and small enough that a file which is
## clearly not a car is turned away before it is parsed rather than after.
const MAX_BYTES := 8 << 20

## And how much model may be inside it. A glTF is only data, so nothing in one
## can run; what it can do is be enormous, and a car with two million vertices
## in it is a race that runs at four frames a second on the machine of whoever
## downloaded it rather than on the machine of whoever made it.
const MAX_VERTICES := 250000
const MAX_SURFACES := 96

## The size of the car the game ships with: the collision box in car.tscn,
## which every car keeps whatever it looks like. A model is fitted to this
## rather than to the stock model's own mesh, because the box is what the
## player actually drives and what they hit things with.
##
## Written down here rather than read off the scene because the fitting is
## done in the garage, where there is no car to ask. `tools/checks/garage.gd`
## holds the two together, so moving the box moves this.
const CAR_SIZE := Vector3(2.06, 1.45, 4.87)

## How far outside the box a model may reach, as a fraction. A little over,
## because a car whose mirrors and spoiler are inside its own collision box
## looks shrunken - and not much over, because what a player sees should be
## roughly what they hit things with.
const ALLOWANCE := 1.15


## Read a model off the disk.
##
## Answers {ok, model, error} rather than throwing or returning null, so the
## screen that called it always has something to put in front of the player.
## The error is written to be read by whoever picked the file.
static func read(path: String) -> Dictionary:
	if not EXTENSIONS.has(path.get_extension().to_lower()):
		return _no("A car has to be a .glb or .gltf file.")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _no("That file could not be opened.")
	var size := file.get_length()
	if size > MAX_BYTES:
		return _no("That file is %.1f MB. The limit is %d MB."
				% [size / 1048576.0, MAX_BYTES >> 20])
	var bytes := file.get_buffer(size)
	file.close()
	return from_bytes(bytes)


## The same, for a model that arrived as bytes rather than as a file - which
## is how every car downloaded from somebody else will arrive. Sharing adds no
## new checks because it goes through these.
static func from_bytes(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() > MAX_BYTES:
		return _no("That model is %.1f MB. The limit is %d MB."
				% [bytes.size() / 1048576.0, MAX_BYTES >> 20])

	var document := GLTFDocument.new()
	var state := GLTFState.new()
	# Read with no base path on purpose. A .gltf that keeps its meshes and its
	# textures in files beside it cannot reach them from here, and fails - and
	# that is the wanted answer, not a limitation being worked around. A car
	# has to be one file, because one file is what can be handed to somebody
	# else and still be the same car when it gets there.
	if document.append_from_buffer(bytes, "", state) != OK:
		return _no("That file could not be read as a model. If it is a .gltf "
				+ "with its textures in files beside it, export it again as "
				+ "a single .glb.")

	var built := document.generate_scene(state)
	var model := built as Node3D
	if model == null:
		if built != null:
			built.queue_free()
		return _no("There is no model in that file.")

	_strip(model)
	var tally := _tally(model)
	if int(tally["meshes"]) == 0:
		return _turn_away(model, "There is nothing in that file to look at.")
	if int(tally["surfaces"]) > MAX_SURFACES:
		return _turn_away(model, "That model is made of %d pieces, and the "
				% tally["surfaces"] + "limit is %d." % MAX_SURFACES)
	if int(tally["vertices"]) > MAX_VERTICES:
		return _turn_away(model, "That model has %d vertices in it, and the "
				% tally["vertices"] + "limit is %d." % MAX_VERTICES)

	return {
		"ok": true, "error": "", "model": model,
		"meshes": tally["meshes"], "surfaces": tally["surfaces"],
		"vertices": tally["vertices"],
	}


## Where a model has to be put, and how big, to drive as the car it is standing
## in for: turned by however many quarter turns the player asked for, scaled
## until it fits the collision box, centred across the road and sat down on it.
##
## Scaled by one number on all three axes, never three. Fitting each axis
## separately would make every model exactly car-shaped, which is to say it
## would flatten a motorbike and stretch a rubber duck, and the whole appeal of
## bringing your own car is that it still looks like the thing you brought.
##
## What is being matched is the length. Length is what a person means by how
## big a car is, so a model that is already roughly car-shaped comes out at
## exactly the length of the car the game ships with, and looks like it belongs
## on the road beside it.
##
## Width and height are not matched, only capped. They are what keeps the
## fitting honest when the model is not car-shaped at all: whichever of the
## three limits bites first is the one that decides, so a lorry is brought down
## by its height rather than being stretched to fill the road. That is what
## makes the game readable - what a player sees is roughly what they hit things
## with - and it is why something tall and thin comes out small. A lamp post
## scaled until it fits under 1.7 m of car is a short lamp post, and the
## alternative is a car whose corners are nowhere near it.
static func fit(model: Node3D, quarter_turns := 0) -> Transform3D:
	var measured := measure(model)
	if measured.size.x <= 0.0 or measured.size.y <= 0.0 or measured.size.z <= 0.0:
		return Transform3D()

	var turn := Basis(Vector3.UP, quarter_turns * PI * 0.5)
	# Measured after the turn, because a quarter turn swaps a model's length
	# for its width and the fit is a different number on the other side of it.
	var turned := Transform3D(turn, Vector3.ZERO) * measured
	var room := CAR_SIZE * ALLOWANCE
	# The length is the target and is taken off the box itself; the other two
	# are ceilings and get the allowance, because a wing mirror reaching a
	# little past the box is a wing mirror and not a fault.
	var scale: float = minf(CAR_SIZE.z / turned.size.z,
			minf(room.x / turned.size.x, room.y / turned.size.y))

	var sized := Transform3D(turn.scaled(Vector3.ONE * scale), Vector3.ZERO) * measured
	return Transform3D(turn.scaled(Vector3.ONE * scale), Vector3(
		# Centred across the road and along it, and stood on the ground rather
		# than hung at whatever height it was modelled at.
		-(sized.position.x + sized.size.x * 0.5),
		-sized.position.y,
		-(sized.position.z + sized.size.z * 0.5)))


## How much room a model takes up in its own space.
##
## Its own transform is deliberately left out: what comes back is measured
## against the root, which is the thing `fit` is about to overwrite.
static func measure(model: Node3D) -> AABB:
	var boxes: Array[AABB] = []
	_collect(model, Transform3D.IDENTITY, boxes, true)
	if boxes.is_empty():
		return AABB()
	var bounds := boxes[0]
	for i in range(1, boxes.size()):
		bounds = bounds.merge(boxes[i])
	return bounds


static func _collect(node: Node, into: Transform3D, boxes: Array[AABB],
		is_root := false) -> void:
	var here := into
	if node is Node3D and not is_root:
		here = into * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		boxes.append(here * (node as MeshInstance3D).get_aabb())
	for child in node.get_children():
		_collect(child, here, boxes, false)


## Throw out everything that is not something to look at.
##
## A glTF can carry cameras, lights and animations as well as meshes, and none
## of those are wanted: a camera in the file would fight the two the split
## screen already has, a light would be a second sun bolted to somebody's
## bumper, and an animation nothing plays is weight in memory. Removed rather
## than ignored, so there is no path by which any of them can later be found.
static func _strip(model: Node3D) -> void:
	for kind in ["Camera3D", "Light3D", "AnimationPlayer", "AnimationTree"]:
		for node in model.find_children("*", kind, true, false):
			node.get_parent().remove_child(node)
			node.queue_free()


## What is left, counted: meshes, surfaces and vertices.
static func _tally(model: Node3D) -> Dictionary:
	var meshes := 0
	var surfaces := 0
	var vertices := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (node as MeshInstance3D).mesh
		if mesh == null:
			continue
		meshes += 1
		surfaces += mesh.get_surface_count()
		if mesh is ArrayMesh:
			for surface in mesh.get_surface_count():
				vertices += (mesh as ArrayMesh).surface_get_array_len(surface)
	return {"meshes": meshes, "surfaces": surfaces, "vertices": vertices}


## A model that got as far as being built and then failed a check. It is freed
## on the way out: a rejected car should not be sitting in memory waiting for
## somebody to notice it was handed back.
static func _turn_away(model: Node3D, why: String) -> Dictionary:
	model.queue_free()
	return _no(why)


static func _no(why: String) -> Dictionary:
	return {"ok": false, "error": why, "model": null,
		"meshes": 0, "surfaces": 0, "vertices": 0}
