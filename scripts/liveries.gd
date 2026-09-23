extends Node

## The liveries a player has saved, kept on this machine.
##
## A livery is a decoration with no car under it: a design drawn on the
## garage's decoration tab and then kept as a thing in its own right, so it can
## be put on any car, sits beside the cars in the garage, and can be handed to
## somebody else. `Decals` is what a *car* is wearing; this is a design a
## player made. The two hold the same marks and obey the same rules, and
## neither knows about the other.
##
## This is the truth a livery is played against, the way `Garage` is for cars:
## a livery is saved, renamed, applied and removed with the network unplugged
## and no account ever made. `LiveryLibrary` sits on top and asks nothing of
## it in return.
##
## One file rather than a folder each. A car has to keep its model exactly as
## it arrived and its portrait beside it, so it gets a folder; a livery is a
## line of text ([scripts/livery.gd](livery.gd)) and a name, and a folder per
## livery would be a folder per line.

## Emitted whenever a livery is saved, renamed or removed.
signal changed

const SAVE_PATH := "user://liveries.cfg"

## How many a player may keep.
##
## Generous rather than tight - they cost a line of text each - but not
## unbounded, because every one of them is a tile in the garage with a picture
## of the design on it, and a page of four hundred is a page nobody can find
## anything on. Forty is more designs than anybody will draw with a mouse.
const LIMIT := 40

## Not a const, so a check can point at somewhere that is not the player's own
## liveries. See `Sandbox`.
var save_path := Sandbox.path(SAVE_PATH)

## Livery id -> `{name, marks, added}`, oldest first when handed out.
var _kept := {}


func _ready() -> void:
	load_liveries()


## Every livery there is, as `{id, name}`, oldest first.
##
## Oldest first so a livery keeps its place as others arrive, for the reason
## the garage gives about cars: the newest at the front would move every tile
## along by one each time anything was saved, and a player would have to find
## their own design again.
func all() -> Array:
	var found := []
	for id in _kept:
		var kept: Dictionary = _kept[id]
		found.append({"id": id, "name": kept.name, "added": float(kept.added)})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.added != b.added:
			return a.added < b.added
		return a.id < b.id)
	return found.map(func(one: Dictionary) -> Dictionary:
		return {"id": one.id, "name": one.name})


func has(id: String) -> bool:
	return _kept.has(id)


func count() -> int:
	return _kept.size()


## What a livery is called, or nothing at all for one that is not here.
func name_of(id: String) -> String:
	if not has(id):
		return ""
	return str((_kept[id] as Dictionary).name)


## The marks a livery is made of. A copy, so nothing can edit the store by
## holding on to what it was handed.
func marks_of(id: String) -> Array:
	if not has(id):
		return []
	var out := []
	for mark: Dictionary in (_kept[id] as Dictionary).marks:
		out.append(mark.duplicate(true))
	return out


## Keep a design, calling it `called` if it is new.
##
## Answers `{ok, error, id, name, new}`, the same shape `Garage.adopt` answers
## in and for the same reason: `new` false is not a failure, it is the same
## design saved twice, and that is worth saying rather than swallowing.
##
## The id is the design hashed, so saving the same thing twice under two names
## keeps the first name. That is the right way round: a player who saved a
## design and then drew their way back to it has not made a second design, and
## silently renaming the one they had would lose the name they chose.
func keep(marks: Array, called: String) -> Dictionary:
	var tidied := []
	for mark in marks:
		if not (mark is Dictionary):
			continue
		var clean := DecalArt.tidy(mark)
		if not clean.is_empty():
			tidied.append(clean)
	if not Livery.holds(tidied):
		if tidied.is_empty():
			return _problem("There is nothing on the car to save.")
		return _problem("That design is too much for one livery.")

	var id := Livery.id_for(tidied)
	if has(id):
		return _fine(id, false)
	if _kept.size() >= LIMIT:
		return _problem("There is room for %d liveries. Remove one first." % LIMIT)
	var name := clean_name(called)
	if name.is_empty():
		name = "A LIVERY"
	_kept[id] = {
		"name": name,
		"marks": tidied,
		"added": Time.get_unix_time_from_system(),
	}
	save_liveries()
	changed.emit()
	return _fine(id, true)


## Take a livery in from somebody else, as the line of text it travelled as.
##
## The same door as saving one drawn here: it goes through `Livery.read` and so
## through `DecalArt.tidy`, mark by mark, and then through `keep`, which hashes
## it and holds it to the same cap. So a design from a stranger can be a design
## this game has no shape for and simply arrive without that piece, and can
## never be a design a player could not have drawn themselves.
func adopt(text: String, called: String) -> Dictionary:
	return keep(Livery.read(text), called)


## Call a livery something else. False if there is no such livery or nothing is
## left of the name once it is tidied.
##
## The id does not move: it is the design, and renaming is not redesigning.
func rename(id: String, to: String) -> bool:
	if not has(id):
		return false
	var name := clean_name(to)
	if name.is_empty():
		return false
	if name_of(id) == name:
		return true
	(_kept[id] as Dictionary).name = name
	save_liveries()
	changed.emit()
	return true


## Throw a livery away.
##
## Nothing happens to the cars wearing it. A livery is a design that was
## *copied* onto a car, not a thing the car points at - the car holds its own
## marks in `Decals` - so removing one takes away a way of putting it on
## another car and touches nothing that is already painted. That is the whole
## reason the two stores are separate.
func remove(id: String) -> bool:
	if not has(id):
		return false
	_kept.erase(id)
	save_liveries()
	changed.emit()
	return true


## Which livery a set of marks is, or an empty string for a design that has not
## been saved. It is a hash, so this is a lookup rather than a search.
func which(marks: Array) -> String:
	var id := Livery.id_for(marks)
	return id if has(id) else ""


## A livery as the line of text it is shared and written down as.
func written(id: String) -> String:
	return Livery.written(marks_of(id))


## Tidy up a name somebody typed. The garage's own rules, so a livery and a car
## are named by the same hand and neither can hold a character the other
## cannot.
static func clean_name(called: String) -> String:
	return Garage.clean_name(called).left(Livery.NAME_LIMIT).strip_edges()


# --- the file -----------------------------------------------------------

func save_liveries() -> void:
	var file := ConfigFile.new()
	for id in _kept:
		var kept: Dictionary = _kept[id]
		file.set_value(id, "name", kept.name)
		# Written as the line it is shared as, rather than as the dictionaries
		# it is drawn from. One form for the file and the wire means a livery
		# that reads back wrong is wrong in one place, and it is the form the
		# id was taken of - so a file edited by hand stops being that livery
		# rather than quietly becoming a different one under its old id.
		file.set_value(id, "marks", Livery.written(kept.marks))
		file.set_value(id, "added", kept.added)
	file.save(save_path)


func load_liveries() -> void:
	_kept.clear()
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	for section in file.get_sections():
		if not Livery.is_id(section):
			continue
		var marks := Livery.read(str(file.get_value(section, "marks", "")))
		# Held to its own id. A section whose marks do not hash to the name it
		# is filed under has been edited since it was written, and keeping it
		# would be keeping a livery that means one thing here and another
		# everywhere else it is ever copied.
		if not Livery.holds(marks) or Livery.id_for(marks) != section:
			continue
		var name := clean_name(str(file.get_value(section, "name", "")))
		_kept[section] = {
			"name": name if not name.is_empty() else "A LIVERY",
			"marks": marks,
			"added": float(file.get_value(section, "added", 0.0)),
		}
		if _kept.size() >= LIMIT:
			break


func _fine(id: String, fresh: bool) -> Dictionary:
	return {"ok": true, "error": "", "id": id, "name": name_of(id), "new": fresh}


func _problem(why: String) -> Dictionary:
	return {"ok": false, "error": why, "id": "", "name": "", "new": false}
