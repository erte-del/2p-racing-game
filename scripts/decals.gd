extends Node

## What each car has been decorated with.
##
## A decoration belongs to a car, not to a player. Two people driving the same
## model see the same stripes and the same stickers on both of them, which is
## correct - it is one car - and it is why the split-screen rule the paint
## screen holds matters more here rather than less: the paint is then the only
## thing telling the two apart. See `COVER_CAP`.
##
## Kept in a store of its own rather than in the car's folder, because the
## stock car has no folder. Its id is the empty string and it is part of the
## build ([scripts/garage.gd](garage.gd)), so there is nowhere beside it to put
## anything. It gets the section `stock`, which is the word the garage already
## uses for where the stock car's portrait goes.
##
## A hand-written word is kept as the points the pen went through, not as a
## picture. It is a few hundred numbers instead of a file, it can be drawn
## again at whatever size the car wants it, and a decoration saved on one
## machine is a decoration that means the same thing on another.
##
## Kept apart from `GameSettings` for the reason `Purse` is: a setting is
## something a player chose off a list and can change back, and this is
## something they made.

## Emitted whenever a car's decoration changes, with the car it was. Whoever
## is showing that car repaints from it; nothing here reaches into a race.
signal changed(id: String)

const SAVE_PATH := "user://decals.cfg"

## What the stock car's section is called. Not an id, so it can never be taken
## for a car somebody added - `Garage.is_id` refuses a five-letter word.
const STOCK_SECTION := "stock"

## The three kinds, taken from `DecalArt` rather than written down again here.
const STRIPE := DecalArt.STRIPE
const STICKER := DecalArt.STICKER
const SCRAWL := DecalArt.SCRAWL

## What a decoration may be, taken from `DecalArt` rather than written down
## again here. The rules belong beside the shapes they are about: a cap on how
## much of a car is covered wants to sit next to the thing that measures
## coverage, and a livery has to apply exactly the same rules without being a
## car at all - see `Livery`.
const COVER_CAP := DecalArt.COVER_CAP
const MARKS_LIMIT := DecalArt.MARKS_LIMIT

## Not a const, so a check can point at somewhere that is not the player's own
## decoration. See `Sandbox`.
var save_path := Sandbox.path(SAVE_PATH)

## Car id -> its marks. The stock car is in here under the empty string, the
## same way it is everywhere else in the game; `stock` is only what it is
## called in the file.
var _marks := {}


func _ready() -> void:
	load_decals()


## What a car is wearing. A copy, so nothing can edit the store by holding on
## to what it was handed.
func marks_on(id: String) -> Array:
	var kept: Array = _marks.get(id, [])
	var out := []
	for mark: Dictionary in kept:
		out.append(mark.duplicate(true))
	return out


## Whether a car has been decorated at all.
func decorated(id: String) -> bool:
	return not marks_on(id).is_empty()


## Put a whole decoration on a car, or refuse it.
##
## Refused as a whole rather than trimmed. A player who has just drawn one
## sticker too many should be told the car is full, not handed back a car with
## something else quietly missing off it.
func set_marks(id: String, marks: Array) -> bool:
	var tidied := []
	for mark in marks:
		if not (mark is Dictionary):
			return false
		var clean := DecalArt.tidy(mark)
		if clean.is_empty():
			return false
		tidied.append(clean)
	if tidied.size() > MARKS_LIMIT:
		return false
	if DecalArt.cover_of_all(tidied) > COVER_CAP:
		return false
	if tidied.is_empty():
		_marks.erase(id)
	else:
		_marks[id] = tidied
	save_decals()
	changed.emit(id)
	return true


## Put one more thing on a car. False if it would not fit under the cap.
func add_mark(id: String, mark: Dictionary) -> bool:
	var marks := marks_on(id)
	marks.append(mark)
	return set_marks(id, marks)


## Change the mark at a slot. False for a slot that is not there, or a change
## that would not fit.
func change_mark(id: String, at: int, mark: Dictionary) -> bool:
	var marks := marks_on(id)
	if at < 0 or at >= marks.size():
		return false
	marks[at] = mark
	return set_marks(id, marks)


## Take one thing off a car.
func remove_mark(id: String, at: int) -> bool:
	var marks := marks_on(id)
	if at < 0 or at >= marks.size():
		return false
	marks.remove_at(at)
	return set_marks(id, marks)


## Take everything off a car, leaving it in its paint.
func clear(id: String) -> void:
	if not _marks.has(id):
		return
	_marks.erase(id)
	save_decals()
	changed.emit(id)


## Forget a car's decoration entirely, because the car has gone.
##
## Called by the garage when a car is removed. The stock car cannot be removed,
## so nothing ever asks this about it - but if something did, it would do what
## it says, because a decoration whose car is gone is a section of a file that
## nothing can ever show anybody again.
func forget(id: String) -> void:
	clear(id)


## How much of a car is covered, and how much it is allowed to be.
func cover_on(id: String) -> float:
	return DecalArt.cover_of_all(marks_on(id))


# --- the file -----------------------------------------------------------

## Which section of the file a car's decoration is written in.
func _section_of(id: String) -> String:
	return STOCK_SECTION if id == Garage.STOCK else id


## Whole sections are written rather than patched, and a car with nothing on it
## has no section at all, so a decoration taken off is a decoration gone from
## the file rather than an empty one left in it.
func save_decals() -> void:
	var file := ConfigFile.new()
	for id in _marks:
		file.set_value(_section_of(id), "marks", _marks[id])
	file.save(save_path)


func load_decals() -> void:
	_marks.clear()
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	for section in file.get_sections():
		var id := Garage.STOCK if section == STOCK_SECTION else section
		# Anything that is not the stock car has to be an id, so a section
		# somebody typed into the file by hand cannot name a path.
		if id != Garage.STOCK and not Garage.is_id(id):
			continue
		var kept: Variant = file.get_value(section, "marks", [])
		if not (kept is Array):
			continue
		var marks := []
		for mark in kept:
			if not (mark is Dictionary):
				continue
			# Thinned on the way in too, which is what puts right a word
			# drawn by a build that kept every point the pen was read at -
			# one too long to save as a livery. It takes nothing out of a
			# word that is thin already. See `DecalArt.thinned`.
			var clean := DecalArt.thinned_word(DecalArt.tidy(mark))
			if not clean.is_empty():
				marks.append(clean)
		# The cap is applied on the way in as well as on the way out. A file
		# from a build with a looser cap is a car that would otherwise wear
		# more than this one allows.
		while DecalArt.cover_of_all(marks) > COVER_CAP or marks.size() > MARKS_LIMIT:
			marks.pop_back()
		if not marks.is_empty():
			_marks[id] = marks
