extends Node

## Every car on this machine that did not come with the game.
##
## A player can point the game at a model and drive it. What that is worth
## depends entirely on it changing nothing else: the car keeps the collision
## box, the tuning and the road it always had, so a brought-in car is a
## different thing to look at and not a different thing to race. `CarShell` is
## where that line is drawn and `tools/checks/car_shell.gd` is where it is
## held; this is only the cupboard the models are kept in.
##
## Nothing here needs an account, a network or a `backend.cfg`. A car somebody
## adds is theirs, on their machine, and stays there. Sharing one is a separate
## act that has not been built yet, and when it is it will be an upload rather
## than a flag flipped on something that was already sent.
##
## One folder per car, under `user://cars`, holding the model as it arrived,
## a little config beside it, and a picture of it for the garage screen. The
## folder is named by the hash of the model itself, so adding the same file
## twice is the same car twice rather than two of it - and so that a car
## carries the same name on every machine it ever reaches.

## Where they live. A test run keeps its own, somewhere else; see `Sandbox`.
const CARS := "user://cars"

## What a car is called on disk, inside its own folder.
const MODEL := "car.glb"
const DETAILS := "car.cfg"
const PORTRAIT := "thumb.png"

## The id of the car the game ships with, which is no id at all. Everything
## reads a car id, and an empty one is the JDM model - so a player who has
## never opened the garage is already driving a car this file knows about.
const STOCK := ""

## And where that one lives.
const STOCK_MODEL := "res://assets/models/car.glb"

## How long a car's name may be. Long enough to say what it is and short
## enough to sit under a tile on the garage screen.
const NAME_LIMIT := 24

## Emitted whenever a car is added, removed or renamed, so a screen showing
## the garage can go and read it again rather than being told what changed.
signal changed


func _ready() -> void:
	# Made on the way up rather than checked for on every read.
	Sandbox.folder(CARS)


## Every car in the garage, oldest first, as
## {id, name, added_at, quarter_turns, vertices}.
##
## Read off the disk each time rather than held in memory. There are a handful
## of these and they are asked for when a screen opens, and a list kept in a
## variable is a list that can disagree with the folder it came from.
func cars() -> Array:
	var found: Array = []
	var root := Sandbox.folder(CARS)
	for id in DirAccess.get_directories_at(root):
		var details := _details(id)
		if details.is_empty():
			continue
		found.append(details)
	found.sort_custom(func(a, b): return float(a["added_at"]) < float(b["added_at"]))
	return found


## Whether there is a car under this id. The stock car is not in the garage
## and never will be, so it answers false - use `known` for "may be driven".
func has(id: String) -> bool:
	return not id.is_empty() and FileAccess.file_exists(_file(id, DETAILS))


## Whether this id names a car that can actually be driven, the stock one
## included. Anything else is a car that has been deleted since it was chosen.
func known(id: String) -> bool:
	return id == STOCK or has(id)


func name_of(id: String) -> String:
	if id == STOCK:
		return "THE STOCK CAR"
	var details := _details(id)
	return str(details.get("name", "")) if not details.is_empty() else ""


## Where a car's picture is, whether or not one has been drawn yet.
func portrait_path(id: String) -> String:
	Sandbox.folder("%s/%s" % [CARS, id if not id.is_empty() else "stock"])
	return _file(id, PORTRAIT)


## Add a model to the garage.
##
## Answers {ok, id, error}. The model is read and checked before a byte of it
## is written down, so a file that is not a car never becomes a folder that
## has to be cleaned up.
func add(path: String) -> Dictionary:
	var read := CarImport.read(path)
	if not read.ok:
		return {"ok": false, "id": "", "error": str(read.error)}
	# Only wanted to know it would load. The garage screen asks for its own
	# copy a moment later to draw the picture, which is one parse more than
	# strictly needed on the one action a person is waiting on anyway.
	(read.model as Node3D).queue_free()

	var bytes := FileAccess.get_file_as_bytes(path)
	var id := _id_for(bytes)
	if has(id):
		# The same model, added again. Nothing to write and nothing wrong -
		# the player gets the car they already had, which is the car they
		# asked for.
		return {"ok": true, "id": id, "error": ""}

	var folder := Sandbox.folder("%s/%s" % [CARS, id])
	var file := FileAccess.open("%s/%s" % [folder, MODEL], FileAccess.WRITE)
	if file == null:
		return {"ok": false, "id": "", "error": "That car could not be saved."}
	file.store_buffer(bytes)
	file.close()

	var details := ConfigFile.new()
	details.set_value("car", "name", _name_from(path))
	details.set_value("car", "added_at", Time.get_unix_time_from_system())
	details.set_value("car", "quarter_turns", 0)
	details.set_value("car", "vertices", read.vertices)
	details.set_value("car", "came_from", path.get_file())
	details.save("%s/%s" % [folder, DETAILS])

	changed.emit()
	return {"ok": true, "id": id, "error": ""}


## Take a car out of the garage, and its model and picture with it. A player
## still sitting on it is put back in the stock car the next time a race asks,
## because `dress` will not find it.
func remove(id: String) -> void:
	if not has(id):
		return
	var folder := Sandbox.folder("%s/%s" % [CARS, id])
	for name in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute("%s/%s" % [folder, name])
	DirAccess.remove_absolute(folder)
	changed.emit()


func rename(id: String, to: String) -> void:
	var trimmed := to.strip_edges().substr(0, NAME_LIMIT)
	if not has(id) or trimmed.is_empty():
		return
	_write(id, "name", trimmed)


## Turn a car a quarter of the way round.
##
## Nothing can work out which end of an arbitrary model is the front, so the
## game guesses - the long way round is the length - and this is how a player
## says it guessed wrong. Stored rather than applied, because the fit is
## worked out from the model after the turn: a quarter turn swaps a car's
## length for its width, and it has to be scaled again on the other side of it.
func turn(id: String, quarter_turns: int) -> void:
	if not has(id):
		return
	_write(id, "quarter_turns", posmod(quarter_turns, 4))


func quarter_turns(id: String) -> int:
	var details := _details(id)
	return int(details.get("quarter_turns", 0)) if not details.is_empty() else 0


## A fresh model for a car, fitted and ready to be worn, or null.
##
## Fresh every time rather than cached: two players may pick the same car, and
## one node tree cannot hang off two of them. It is a parse of half a megabyte
## at the start of a race and when a garage tile is drawn, which is nowhere
## near anything anybody is waiting on.
func model_for(id: String) -> Node3D:
	if id == STOCK:
		var stock := load(STOCK_MODEL) as PackedScene
		return stock.instantiate() as Node3D if stock != null else null
	if not has(id):
		return null
	var read := CarImport.from_bytes(FileAccess.get_file_as_bytes(_file(id, MODEL)))
	if not read.ok:
		return null
	var model := read.model as Node3D
	model.transform = CarImport.fit(model, quarter_turns(id))
	return model


## Put a car's model on a car, if it is not wearing it already.
##
## The guard matters: this is called from the settings changing, and the
## settings change when somebody moves the volume slider. Rebuilding both cars
## every time anybody touched anything would be a stutter with no cause a
## player could see.
##
## A car that has been deleted since it was chosen falls back to the stock one
## rather than failing. That is the same posture the paint takes with a colour
## it does not recognise, and it is the only sane answer: the player is in a
## race, and the car they picked is not there any more.
func dress(car: Car, id: String) -> void:
	var wanted := id if known(id) else STOCK
	# The turn counts as part of which model this is. A car turned in the
	# garage has to be fitted again on the other side of the turn, so a
	# guard that looked only at the id would leave the player looking at
	# the old way round until they picked something else and came back.
	var turns := quarter_turns(wanted)
	if car.model_id == wanted and car.model_turns == turns:
		return
	var model := model_for(wanted)
	if model == null:
		if wanted == STOCK:
			return
		wanted = STOCK
		model = model_for(STOCK)
		if model == null:
			return
	car.set_model(model, wanted == STOCK)
	car.model_id = wanted
	car.model_turns = quarter_turns(wanted)


## The id of a model is the model itself, shortened. Two players who add the
## same file have the same car, and a car keeps its id wherever it travels.
func _id_for(bytes: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(bytes)
	return hashing.finish().hex_encode().substr(0, 16)


## What to call a car nobody has named: the file it came out of, tidied up.
func _name_from(path: String) -> String:
	var stem := path.get_file().get_basename().replace("_", " ").replace("-", " ")
	stem = stem.strip_edges().substr(0, NAME_LIMIT)
	return stem.to_upper() if not stem.is_empty() else "A CAR"


func _details(id: String) -> Dictionary:
	var file := ConfigFile.new()
	if id.is_empty() or file.load(_file(id, DETAILS)) != OK:
		return {}
	return {
		"id": id,
		"name": str(file.get_value("car", "name", "A CAR")),
		"added_at": float(file.get_value("car", "added_at", 0.0)),
		"quarter_turns": int(file.get_value("car", "quarter_turns", 0)),
		"vertices": int(file.get_value("car", "vertices", 0)),
	}


func _write(id: String, key: String, value: Variant) -> void:
	var where := _file(id, DETAILS)
	var file := ConfigFile.new()
	if file.load(where) != OK:
		return
	file.set_value("car", key, value)
	file.save(where)
	changed.emit()


func _file(id: String, name: String) -> String:
	# The stock car has no id, so it gets a folder named for what it is.
	# Only its picture ever lands there; the model itself ships with the
	# game and is not the garage's to keep.
	return "%s/%s/%s" % [Sandbox.folder(CARS), id if not id.is_empty() else "stock", name]
