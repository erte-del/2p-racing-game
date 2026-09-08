extends Node

## Cars people have shared, and this player's among them.
##
## `Garage` is what this machine has and stays the truth the game is played
## against - what a tile shows, what a car wears, what a race dresses from -
## and all of it works with the network unplugged and no account ever made.
## This is the layer above: it sends a car up when a player says to, brings
## other people's down when a player asks for one, and asks nothing of the rest
## of the game in return. It is exactly the split `Leaderboard` has over
## `TrackTimes`, for the same reason.
##
## Nothing is uploaded until a player shares it. That is the whole shape of the
## feature: a private car has no row, no object and no presence on the server
## at all, which is a much easier promise to keep than a flag somebody has to
## remember to check. Sharing is therefore an act rather than a setting, and
## unsharing takes the car back down.
##
## A model that comes back down is a model written by a stranger, and it is
## treated as one. It goes through `Garage.adopt`, which puts it through the
## same reader a file off the disk goes through - and its bytes are weighed
## against the id they were asked for before any of that, because the id is the
## hash of the model and a server handing back something else is a server
## handing back a different car.

## The bucket the models live in, and what they are.
const BUCKET := "cars"
const KIND := "model/gltf-binary"

## How many are shown. Enough to browse and short enough to arrive at once.
const CATALOGUE_SIZE := 60

## How long the list stays worth showing before it is asked for again, in
## seconds. Opening the page and going back should not be a request a keypress.
const CACHE_SECONDS := 60.0

## Emitted when the list arrives, so a screen can put it up whenever it lands
## rather than holding still until it does.
signal catalogue_arrived(rows: Array)

## What the last look at the server said, and when.
var _rows: Array = []
var _looked_at := 0.0
## Whether that look actually got an answer. An empty list and a server
## that did not reply both come back as no rows, and they are not the same
## thing to say to somebody - one means nobody has shared a car and the
## other means we do not know.
var _answered := false


## Whether there is a server to talk to at all. A build with no `backend.cfg`
## does not grow a Share button that cannot do anything.
func available() -> bool:
	return Backend.configured()


## And whether this player could actually put a car up. Browsing works signed
## out - somebody deciding whether an account is worth making should be able to
## see what they would be joining - but sharing is a thing done as somebody.
func can_share() -> bool:
	return available() and Backend.is_signed_in()


## Everything people have shared, newest first, as rows of
## {id, name, by, vertices, mine, here}.
##
## `here` is whether this machine already has that car, which is what lets the
## page say GET on some rows and HAVE IT on others without a second question.
func catalogue(force := false) -> Array:
	if not available():
		return []
	var now := Time.get_ticks_msec() / 1000.0
	if not force and not _rows.is_empty() and now - _looked_at < CACHE_SECONDS:
		return _mark(_rows)

	# The owner's name comes through the foreign key in the same request
	# rather than as a second round trip per row.
	var answer: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
			"/cars?select=id,name,vertices,owner,racers(name)"
			+ "&order=shared_at.desc&limit=%d" % CATALOGUE_SIZE)
	if not answer.ok or typeof(answer.data) != TYPE_ARRAY:
		# A list that did not arrive is not an error anybody needs telling
		# about. The page shows what it showed before, or nothing - and
		# says which of the two nothings it is.
		_answered = false
		return _mark(_rows)

	_rows = []
	for row in answer.data:
		var entry: Dictionary = row
		var by: Variant = entry.get("racers")
		_rows.append({
			"id": str(entry.get("id", "")),
			"name": str(entry.get("name", "")),
			"vertices": int(entry.get("vertices", 0)),
			"owner": str(entry.get("owner", "")),
			"by": str((by as Dictionary).get("name", "somebody"))
				if typeof(by) == TYPE_DICTIONARY else "somebody",
		})
	_looked_at = now
	_answered = true
	var marked := _mark(_rows)
	catalogue_arrived.emit(marked)
	return marked


## Put one of this player's cars up for everybody.
##
## The model goes first and the row second, because the row is what makes it
## readable: an object with nothing pointing at it is readable by nobody, so a
## half-finished share is a private car rather than a leak.
func publish(id: String) -> Dictionary:
	if not can_share():
		return _no("Sign in to share a car.")
	var bytes := Garage.bytes_of(id)
	if bytes.is_empty():
		return _no("That car is not in your garage.")

	var where := _model_path(Backend.user_id, id)
	var sent: Dictionary = await Backend.upload(BUCKET, where, bytes, KIND)
	if not sent.ok:
		return _no(str(sent.error))

	var listed: Dictionary = await Backend.rest(HTTPClient.METHOD_POST, "/cars",
			{
				"id": id, "owner": Backend.user_id,
				"name": Garage.name_of(id), "model": where,
				"vertices": Garage.vertices_in(id),
			})
	if not listed.ok:
		# The model is up and nothing points at it, which means nobody can read
		# it - but it is still sitting there taking up room in somebody's
		# project, so it is taken back down rather than left.
		await Backend.erase(BUCKET, where)
		if int(listed.code) == 409:
			# Whether it was this player or somebody else who put it up is not
			# something a 409 says, and guessing would mean telling half of
			# them the wrong thing. It is already shared either way.
			return _no("That car is already shared.")
		return _no(str(listed.error))

	_looked_at = 0.0
	return _yes()


## Take it back down. A record is something that happened and is not the
## setter's to erase; a car is a thing somebody is lending out, and they are
## allowed to stop.
##
## The row goes first, for the reason it went last on the way up: without it
## the model is readable by nobody, so the car stops being shared on the first
## of the two requests rather than the second.
func unpublish(id: String) -> Dictionary:
	if not can_share():
		return _no("Sign in first.")
	var removed: Dictionary = await Backend.rest(
			HTTPClient.METHOD_DELETE, "/cars?id=eq.%s" % id)
	if not removed.ok:
		return _no(str(removed.error))
	await Backend.erase(BUCKET, _model_path(Backend.user_id, id))
	_looked_at = 0.0
	return _yes()


## Bring somebody else's car down into this garage.
##
## The id is the hash of the model, so what arrives can be weighed against what
## was asked for. That is not a formality: it is the one check that says the
## bytes on the wire are the car the list described, and it costs nothing
## because the name was always going to be computed anyway.
func fetch(id: String) -> Dictionary:
	if not available():
		return _no("No server.")
	var row := _row_for(id)
	if row.is_empty():
		return _no("That car is not on the list any more.")

	var got: Dictionary = await Backend.download(
			BUCKET, _model_path(str(row["owner"]), id))
	if not got.ok:
		return _no(str(got.error))
	var bytes: PackedByteArray = got.data
	if Garage.id_for(bytes) != id:
		return _no("What came down was not the car that was asked for.")

	var kept: Dictionary = Garage.adopt(bytes, str(row["name"]))
	if not kept.ok:
		return _no(str(kept.error))
	return _yes()


## Whether the last look at the server got an answer, so a page with nothing
## on it can say which kind of nothing it is.
func answered() -> bool:
	return _answered


## Whether this player has already shared a car, according to the last look.
func is_shared(id: String) -> bool:
	return not _row_for(id).is_empty()


## And whether it is theirs to take down again.
func is_mine(id: String) -> bool:
	var row := _row_for(id)
	return not row.is_empty() and str(row["owner"]) == Backend.user_id


## Say of each row whether it is this player's and whether this machine has it.
## Worked out on the way out rather than stored, because both answers change
## without the list changing - a car added or deleted here moves them.
func _mark(rows: Array) -> Array:
	var marked: Array = []
	for row: Dictionary in rows:
		var copy := row.duplicate()
		copy["mine"] = str(row["owner"]) == Backend.user_id
		copy["here"] = Garage.has(str(row["id"]))
		marked.append(copy)
	return marked


func _row_for(id: String) -> Dictionary:
	for row: Dictionary in _rows:
		if str(row["id"]) == id:
			return row
	return {}


## Always this shape. The storage policies are what hold it: a player may only
## write inside the folder named after them, so one cannot write over another's
## model and leave the row pointing at it.
func _model_path(owner: String, id: String) -> String:
	return "%s/%s.glb" % [owner, id]


func _yes() -> Dictionary:
	return {"ok": true, "error": ""}


func _no(why: String) -> Dictionary:
	return {"ok": false, "error": why}
