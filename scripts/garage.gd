extends Node

## The cars a player has brought into the game, kept on this machine.
##
## This is the truth the game is played against. A car a player added is on
## their disk, and it is driven, turned, renamed and removed without an
## account, a network or a `backend.cfg` - the same way `TrackTimes` keeps the
## times whether or not there is a board to put them on. Anything that shares
## cars sits on top of this and asks nothing of it in return.
##
## A car lives in a folder of its own, `user://cars/<id>/`: the model exactly
## as it arrived, a small file saying what it is called and which way round it
## goes, and its portrait. The id is the start of a hash of the model's bytes,
## so the same file added twice is the same car, and a car has the same id on
## every machine it is ever copied to.
##
## Nothing here reaches into a race. `dress` puts a car on whatever `Car` it is
## handed, and the race is what decides to hand it one - from
## `GameSettings.car_id`, whenever that or this announces a change.

## Emitted whenever a car is added, turned, renamed or removed.
signal changed

## The car the game ships with. Not in the garage folder and never can be: it
## is part of the build rather than something a player brought.
const STOCK := ""
const STOCK_MODEL := "res://assets/models/car.glb"
const STOCK_NAME := "THE STOCK CAR"
## How long a car's name may be. Enough for a real name, short enough to fit
## under a tile without being cut off halfway through a word most of the time.
const NAME_LIMIT := 24

## A file that has to be handed to Blender before it is a model at all, and
## where what Blender makes of it is put down on the way through.
const BLEND := "blend"
const CONVERTED := "user://converted.glb"

const FOLDER := "user://cars"
## Where the stock car's portrait is kept. Not an id, so it can never be taken
## for a car that somebody added.
const STOCK_FOLDER := "stock"
const MODEL_FILE := "car.glb"
const INFO_FILE := "car.cfg"
const PORTRAIT_FILE := "thumb.png"

## How many characters of the hash make an id. Sixteen hex characters is
## sixty-four bits: two different cars colliding would take billions of them.
const ID_LENGTH := 16

## Where the cars actually are. A test run is sent somewhere else; see
## `Sandbox`.
var folder := Sandbox.folder(FOLDER)

## True while Blender is working on a file. There is one place its output goes,
## and two conversions at once would be two Blenders writing over each other's
## car.
var _converting := false


## Every car in the garage, as `{id, name}`, oldest first.
##
## Oldest first so a car keeps its place as others arrive. The newest at the
## front would move every tile along by one each time anything was added, and a
## player would have to find their own car again.
func cars() -> Array:
	var found := []
	for id in DirAccess.get_directories_at(folder):
		if not has(id):
			continue
		var info := _info(id)
		found.append({
			"id": id,
			"name": _stored_name(info),
			"added": float(info.get_value("car", "added", 0.0)),
		})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.added != b.added:
			return a.added < b.added
		return a.id < b.id)
	return found.map(func(car: Dictionary) -> Dictionary:
		return {"id": car.id, "name": car.name})


## Whether a car someone added is in the garage. The stock car is not "in" it.
func has(id: String) -> bool:
	return is_id(id) and FileAccess.file_exists(_model_path(id))


## Whether a car can be driven: one in the garage, or the stock car.
func known(id: String) -> bool:
	return id == STOCK or has(id)


## What a car is called. Anything that is not in the garage is driven as the
## stock car, so that is what it is called too.
func name_of(id: String) -> String:
	if not has(id):
		return STOCK_NAME
	return _stored_name(_info(id))


## How many vertices the car's model has, as it was counted when it came in.
func vertices_in(id: String) -> int:
	if not has(id):
		return 0
	return int(_info(id).get_value("car", "vertices", 0))


## How many quarter turns the player has given a car, 0 to 3.
func quarter_turns(id: String) -> int:
	if not has(id):
		return 0
	return posmod(int(_info(id).get_value("car", "turns", 0)), 4)


## The model's bytes exactly as they arrived, or nothing for a car that is not
## here.
func bytes_of(id: String) -> PackedByteArray:
	if not has(id):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(_model_path(id))


## The first sixteen hex characters of the sha256 of the model.
##
## A hash of the bytes rather than a name or a number handed out here, so the
## id means the same thing everywhere: the same file added twice is the same
## car, and a car shared with somebody else arrives under the id it left under.
## sha256 rather than the engine's own hash for the reason `TrackTimes`
## gives - it is the same on every machine and every version of Godot.
static func id_for(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	if not bytes.is_empty():
		hashing.update(bytes)
	return hashing.finish().hex_encode().left(ID_LENGTH)


## Whether a string could be an id at all.
##
## Checked before an id is ever used to build a path, because ids also arrive
## from other people. An id is sixteen lower-case hex characters and nothing
## else, so it can never climb out of its folder or name one that is not a car.
static func is_id(id: String) -> bool:
	if id.length() != ID_LENGTH:
		return false
	for character in id:
		if not character in "0123456789abcdef":
			return false
	return true


## Tidy up a name somebody typed, or a file was called: upper case, no control
## characters, one space at a time, and no longer than the limit.
##
## Underscores become spaces, since a file called `blue_wedge.glb` was only
## written that way because file names are awkward about spaces.
static func clean_name(called: String) -> String:
	var name := ""
	for character in called.replace("_", " "):
		name += " " if character.unicode_at(0) < 32 or character.unicode_at(0) == 127 \
			else character
	name = name.strip_edges().to_upper()
	while name.contains("  "):
		name = name.replace("  ", " ")
	return name.left(NAME_LIMIT).strip_edges()


## Bring a car in from a file on the disk.
##
## Always awaited by whoever calls it. A .glb or a .gltf comes in on the spot,
## but a .blend has to be handed to Blender first, and that takes seconds.
##
## Answers `{ok, error, id, name, new}`. `new` is false when the car was already
## here, which is not a failure - it is the same car - but is worth saying.
func add(path: String) -> Dictionary:
	var extension := path.get_extension().to_lower()
	if extension == BLEND:
		return await _add_blend(path)
	if not extension in CarImport.EXTENSIONS:
		return _problem("A car has to be a .glb, a .gltf or a .blend file.")
	var loaded := CarImport.bytes_at(path)
	if not loaded.ok:
		return _problem(loaded.error)
	return adopt(loaded.bytes, path.get_file().get_basename())


## A .blend comes in as whatever Blender turns it into.
##
## What is kept is the .glb, never the .blend, and it goes through `adopt` like
## a file picked off the disk. So the car's id is the hash of the model rather
## than of the file it was made from, and the same car arrives under the same id
## however it got here - which is what lets it be shared with somebody who has
## no Blender at all.
func _add_blend(path: String) -> Dictionary:
	if _converting:
		return _problem("Blender is still busy with another car.")
	_converting = true
	var converted := Sandbox.path(CONVERTED)
	var answer: Dictionary = await Blender.convert(self, path, converted)
	_converting = false
	if not answer.ok:
		return _problem(str(answer.error))
	var loaded := CarImport.bytes_at(converted)
	DirAccess.remove_absolute(converted)
	if not loaded.ok:
		return _problem(loaded.error)
	return adopt(loaded.bytes, path.get_file().get_basename())


## Keep a car from its bytes, calling it `called` if it is new.
##
## The bytes go through `CarImport` exactly as a file from the disk does -
## this is also how a car downloaded from someone else comes in, and there is
## no second way in that is any less careful. What is kept is the bytes
## themselves, untouched, so the car can be read again, hashed again and handed
## on again and still be the same car.
func adopt(bytes: PackedByteArray, called: String) -> Dictionary:
	var read := CarImport.from_bytes(bytes)
	if not read.ok:
		return _problem(read.error)
	(read.model as Node).free()

	var id := id_for(bytes)
	if has(id):
		return _fine(id, false)

	var name := clean_name(called)
	if name.is_empty():
		name = "A CAR"
	DirAccess.make_dir_recursive_absolute(_folder_of(id))
	var info := ConfigFile.new()
	info.set_value("car", "name", name)
	info.set_value("car", "turns", 0)
	info.set_value("car", "vertices", int(read.vertices))
	info.set_value("car", "added", Time.get_unix_time_from_system())
	# The description goes down first and the model last, because the model
	# being there is what `has` asks. A garage interrupted halfway through
	# writing is a garage with a stray folder in it, not a car with no name.
	if info.save(_info_path(id)) != OK:
		_forget(id)
		return _problem("The car could not be written to the disk.")
	var file := FileAccess.open(_model_path(id), FileAccess.WRITE)
	if file == null:
		_forget(id)
		return _problem("The car could not be written to the disk.")
	file.store_buffer(bytes)
	file.close()
	changed.emit()
	return _fine(id, true)


## Take a car out of the garage.
##
## Anyone sitting in it is put back in the stock car first, through the same
## setting the garage screen writes, so the race swaps the model out from under
## them before the file it was read from is gone. Nobody is ever left driving
## nothing. Whatever the car was decorated with goes too; see
## `Decals`.
func remove(id: String) -> bool:
	if not has(id):
		return false
	for player in GameSettings.car_ids.size():
		if GameSettings.car_id(player) == id:
			GameSettings.set_car_id(player, STOCK)
	# Whatever was drawn on it goes with it. A decoration is kept against a car
	# id rather than in the car's folder (the stock car has no folder), so
	# throwing the folder away is not enough on its own - and a section left
	# behind would be handed straight back to whoever added the same file
	# again, which is not the same person's decoration.
	Decals.forget(id)
	_forget(id)
	changed.emit()
	return true


## Call a car something else. False if there is no such car or nothing left of
## the name once it is tidied.
func rename(id: String, to: String) -> bool:
	if not has(id):
		return false
	var name := clean_name(to)
	if name.is_empty():
		return false
	var info := _info(id)
	if _stored_name(info) == name:
		return true
	info.set_value("car", "name", name)
	info.save(_info_path(id))
	changed.emit()
	return true


## Set how many quarter turns a car is given, kept 0 to 3.
##
## The portrait goes with it. It is a picture of the car the old way round, and
## a tile showing the car facing one way while it drives facing another is
## worse than a tile with no picture on it until the new one is drawn.
func turn(id: String, turns: int) -> void:
	if not has(id):
		return
	var info := _info(id)
	info.set_value("car", "turns", posmod(turns, 4))
	info.save(_info_path(id))
	DirAccess.remove_absolute(portrait_path(id))
	changed.emit()


## A fresh model for a car, fitted and ready to go on one.
##
## Read through `CarImport` every time rather than kept, because every car on
## the road needs its own copy - the shell takes private copies of materials to
## paint - and because a car read back off the disk is a car that is checked
## again. Null when a car's file has gone bad since it was added.
func model_for(id: String) -> Node3D:
	if not has(id):
		return (load(STOCK_MODEL) as PackedScene).instantiate() as Node3D
	var read := CarImport.read(_model_path(id))
	if not read.ok:
		push_warning("Garage: %s could not be read back: %s" % [id, read.error])
		return null
	var model: Node3D = read.model
	model.transform = CarImport.fit(model, quarter_turns(id))
	return model


## Put a car on a `Car`.
##
## An id that is not in the garage - deleted, or left in a settings file from
## another machine - is the stock car. So is a car whose file cannot be read
## any more. A player never ends up with nothing to drive.
##
## Only the stock car is handed over as stock, which is what gives it its
## cockpit: a model somebody brought has no inside to sit in.
##
## A car already wearing this car, this way round, is left alone. The id alone
## is not enough to go on - a car turned while the race was paused has the same
## id and a different model - and rebuilding on every settings change would
## rebuild it every time the volume slider moved.
func dress(car: Car, id: String) -> void:
	if car == null:
		return
	if not known(id):
		id = STOCK
	var turns := quarter_turns(id)
	if car.model_id == id and car.model_turns == turns:
		return
	var model := model_for(id)
	if model == null:
		id = STOCK
		turns = 0
		if car.model_id == STOCK and car.model_turns == 0:
			return
		model = model_for(STOCK)
	car.set_model(model, id == STOCK)
	car.model_id = id
	car.model_turns = turns


## Where a car's portrait is kept, whether or not it has been drawn yet.
func portrait_path(id: String) -> String:
	var holder := STOCK_FOLDER if id == STOCK else id
	return "%s/%s/%s" % [folder, holder, PORTRAIT_FILE]


## A car's portrait, or null if it has not been drawn yet.
##
## Read as an image rather than loaded as a resource: it is a file the game
## wrote into `user://`, and there is no import step to have turned it into
## anything else.
func portrait(id: String) -> Texture2D:
	var path := portrait_path(id)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


## Draw a car's portrait if it does not have one. True if it has one now.
func draw_portrait(host: Node, id: String) -> bool:
	if FileAccess.file_exists(portrait_path(id)):
		return true
	if not known(id):
		return false
	var model := model_for(id)
	if model == null:
		return false
	return await CarPortrait.keep(host, model, portrait_path(id))


func _folder_of(id: String) -> String:
	return "%s/%s" % [folder, id]


func _model_path(id: String) -> String:
	return "%s/%s/%s" % [folder, id, MODEL_FILE]


func _info_path(id: String) -> String:
	return "%s/%s/%s" % [folder, id, INFO_FILE]


func _info(id: String) -> ConfigFile:
	var info := ConfigFile.new()
	info.load(_info_path(id))
	return info


func _stored_name(info: ConfigFile) -> String:
	var name := clean_name(str(info.get_value("car", "name", "")))
	return name if not name.is_empty() else "A CAR"


## Throw a car's folder away, and everything in it. Only ever called with an id
## that has been checked, so this can only ever reach into a car's own folder.
func _forget(id: String) -> void:
	if not is_id(id):
		return
	var where := _folder_of(id)
	for file in DirAccess.get_files_at(where):
		DirAccess.remove_absolute("%s/%s" % [where, file])
	DirAccess.remove_absolute(where)


func _fine(id: String, fresh: bool) -> Dictionary:
	return {"ok": true, "error": "", "id": id, "name": name_of(id), "new": fresh}


func _problem(why: String) -> Dictionary:
	return {"ok": false, "error": why, "id": "", "name": "", "new": false}
