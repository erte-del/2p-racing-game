extends Node

## Cars other players have shared, and sharing this player's own.
##
## This sits over `Backend` the way `Leaderboard` sits over `TrackTimes`.
## `Garage` is what is on this machine and stays the truth the game is played
## against: every car in it is driven, turned and removed with the network
## unplugged and no account ever made. All this does is send a car up and bring
## a car down, and nothing in the garage waits on it.
##
## Sharing is something a player does to one car, on purpose. A car nobody
## shared has no row, no object and no presence on the server at all - there is
## no "private" flag to get wrong, because being in the table is what being
## shared is.
##
## A car that comes down from the server is a stranger's file, and is treated as
## one. Its bytes are hashed before anything else is done with them, and must
## come out as the id they were asked for; then they go through `Garage.adopt`
## and so through `CarImport`, the same door as a file off the player's own
## disk.

## Emitted when the list of shared cars arrives, so a page can put it up
## whenever it lands.
signal catalogue_arrived(rows: Array)

const BUCKET := "cars"
## What a .glb is to the server. The bucket takes nothing else.
const KIND := "model/gltf-binary"
## How many shared cars the list holds, newest first. Enough to browse; few
## enough to fetch in one request and to search without asking again.
const CATALOGUE_SIZE := 60
## How long the list stays worth showing before it is asked for again, in
## seconds. Opening the page and closing it again should not be a request each
## time.
const CACHE_SECONDS := 60.0

## The rows last read, without `here` - that is worked out fresh on every ask,
## since the garage changes underneath the list.
var _rows: Array = []
var _fetched_at := -1.0
## Whether the last ask got an answer. An empty list is two different things:
## a server that said nobody has shared anything, and one that said nothing.
var _answered := false
## The ids of cars this player has shared, whether or not they are among the
## newest few dozen on the list.
var _own := {}
## Cars with a request out, so the same car cannot be sent twice at once.
var _underway := {}


func _ready() -> void:
	Backend.signed_in.connect(_forget_the_list)
	Backend.signed_out.connect(_forget_the_list)


## Whether there is a server at all. Without one, nothing on any screen should
## so much as mention sharing.
func available() -> bool:
	return Backend.configured()


## Whether this player can put a car up. Browsing needs no account; sharing
## does, because a shared car has to belong to somebody.
func can_share() -> bool:
	return available() and Backend.is_signed_in()


## Whether the last time the list was asked for, the server answered.
func answered() -> bool:
	return _answered


## The newest shared cars, as rows of
## `{id, name, by, owner, vertices, shared_at, mine, here}`.
##
## Readable signed out. `here` says whether the car is already in this garage,
## so a page can offer GET only where there is something to get.
func catalogue(force := false) -> Array:
	if not available():
		_answered = false
		return []
	var now := Time.get_ticks_msec() / 1000.0
	if not force and _fetched_at >= 0.0 and now - _fetched_at < CACHE_SECONDS:
		return _with_here(_rows)

	var answer: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
		"/cars?select=id,name,vertices,shared_at,owner,racers(name)"
		+ "&order=shared_at.desc&limit=%d" % CATALOGUE_SIZE)
	if not answer.ok or typeof(answer.data) != TYPE_ARRAY:
		# What was shown before is still worth showing, and a page is told this
		# was not an answer so it does not say nobody has shared anything.
		_answered = false
		return _with_here(_rows)
	_rows = _read(answer.data)
	_fetched_at = now
	_answered = true
	if Backend.is_signed_in():
		await _read_own()
	var rows := _with_here(_rows)
	catalogue_arrived.emit(rows)
	return rows


## Whether a car is on the list, as far as this machine last heard.
func is_shared(id: String) -> bool:
	if _own.has(id):
		return true
	for row: Dictionary in _rows:
		if row.id == id:
			return true
	return false


## Whether this player is the one who shared a car.
func is_mine(id: String) -> bool:
	return _own.has(id)


## Put a car from the garage up for everyone.
##
## The order of the two requests is the whole of what makes this safe. The
## model goes up first, and nobody can read it: the bucket only hands out a
## model that a row points at. The row goes in second, and that is the moment
## the car is shared. A share that falls over in between leaves a private file
## in the player's own folder, not a car on the list with nothing behind it,
## and a row that is refused has its model taken back down.
##
## The name comes from the garage rather than from whoever asked, so a car is
## only ever called one thing.
func publish(id: String) -> Dictionary:
	if not available():
		return _problem("This copy of the game has no server set up.")
	if not Backend.is_signed_in():
		return _problem("Sign in to share a car.")
	if not Garage.has(id):
		return _problem("That car is not in the garage.")
	if _underway.has(id):
		return _problem("That car is already on its way.")
	_underway[id] = true
	var answer: Dictionary = await _publish(id)
	_underway.erase(id)
	return answer


func _publish(id: String) -> Dictionary:
	var bytes := Garage.bytes_of(id)
	# The id is the promise a shared car makes to whoever downloads it. A file
	# that no longer hashes to it has been changed on this disk since it was
	# added, and sending it up would be sending a lie.
	if Garage.id_for(bytes) != id:
		return _problem("That car's model has changed on the disk since it was added.")
	var model := model_path(Backend.user_id, id)

	var sent: Dictionary = await Backend.upload(BUCKET, model, bytes, KIND)
	if not sent.ok and int(sent.code) == 409:
		# Something is already at that path, and it can only be this same car:
		# the path is the hash, in this player's own folder. A share that fell
		# over halfway left it, or an unshare that could not clear up. Whether
		# it can be replaced is asked of the server rather than of the list in
		# hand - if a row points at it, somebody may be downloading it now.
		var listed: Dictionary = await _is_listed(id)
		if not listed.ok:
			return listed
		if str(listed.data) == Backend.user_id:
			# This player's own share, from another run or another machine, that
			# the list in hand had not heard about.
			_own[id] = true
			return _problem("You have already shared that car.", 409)
		if not str(listed.data).is_empty():
			return _problem("That car is already shared.", 409)
		await Backend.erase(BUCKET, model)
		sent = await Backend.upload(BUCKET, model, bytes, KIND)
	if not sent.ok:
		return _problem("The car could not be sent: %s" % sent.error, int(sent.code))

	var row: Dictionary = await Backend.rest(HTTPClient.METHOD_POST, "/cars", {
		"id": id,
		"owner": Backend.user_id,
		"name": Garage.name_of(id),
		"model": model,
		"vertices": maxi(Garage.vertices_in(id), 1),
	})
	if not row.ok:
		await Backend.erase(BUCKET, model)
		# Two players who added the same file hold the same car, and the row
		# is keyed on the car. A 409 cannot say which of them put it up, so this
		# does not guess.
		if int(row.code) == 409:
			return _problem("That car is already shared.", 409)
		return row
	_own[id] = true
	_fetched_at = -1.0
	return _fine(id)


## Take a car back down.
##
## The reverse order of putting it up: the row first, so the car stops being
## shared on the very first request, and nobody new can start downloading it.
## The model after, and what happens to that is not waited on to decide
## anything - a model with no row is unreadable to everybody else, and the next
## share of this car clears it away.
func unpublish(id: String) -> Dictionary:
	if not available():
		return _problem("This copy of the game has no server set up.")
	if not Backend.is_signed_in():
		return _problem("Sign in first.")
	if not Garage.is_id(id):
		return _problem("That is not a car.")
	if _underway.has(id):
		return _problem("That car is already on its way.")
	_underway[id] = true
	var gone: Dictionary = await Backend.rest(HTTPClient.METHOD_DELETE,
		"/cars?id=eq.%s&owner=eq.%s" % [id, Backend.user_id])
	if gone.ok:
		await Backend.erase(BUCKET, model_path(Backend.user_id, id))
		_own.erase(id)
		_fetched_at = -1.0
	_underway.erase(id)
	if not gone.ok:
		return gone
	return _fine(id)


## Bring a shared car down into the garage.
##
## The bytes are hashed before they are so much as parsed. A server handing
## back different bytes under this id is handing back a different car, however
## it came to be doing that. Then they go into the garage through
## `Garage.adopt` - the same `CarImport` door as a file off the disk.
func fetch(id: String) -> Dictionary:
	if not available():
		return _problem("This copy of the game has no server set up.")
	if Garage.has(id):
		return _fine(id)
	var row := _row(id)
	if row.is_empty():
		return _problem("That car is not on the list any more.")
	if _underway.has(id):
		return _problem("That car is already on its way.")
	_underway[id] = true
	var answer: Dictionary = await _fetch(row)
	_underway.erase(id)
	return answer


func _fetch(row: Dictionary) -> Dictionary:
	var id: String = row.id
	var got: Dictionary = await Backend.download(BUCKET, model_path(row.owner, id),
		CarImport.MAX_BYTES)
	if not got.ok:
		if int(got.code) == 404:
			return _problem("The model for that car is not on the server. Only "
				+ "whoever shared it can put that right.", 404)
		return got
	var bytes: PackedByteArray = got.data
	if Garage.id_for(bytes) != id:
		return _problem("What came back from the server is not that car.")
	var kept: Dictionary = Garage.adopt(bytes, str(row.name))
	if not kept.ok:
		return _problem(str(kept.error))
	return _fine(id)


## Where a car's model is kept: in its owner's own folder, named by its id.
static func model_path(owner: String, id: String) -> String:
	return "%s/%s.glb" % [owner, id]


## Who has a row for a car, asked of the server itself. `data` is the owner's
## id, or empty when nobody has shared it.
func _is_listed(id: String) -> Dictionary:
	var answer: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
		"/cars?select=id,owner&id=eq.%s" % id)
	if not answer.ok:
		return answer
	var owner := ""
	if typeof(answer.data) == TYPE_ARRAY and not (answer.data as Array).is_empty():
		var row: Variant = (answer.data as Array)[0]
		if typeof(row) == TYPE_DICTIONARY:
			owner = str((row as Dictionary).get("owner", "?"))
	return {"ok": true, "code": 200, "data": owner, "error": ""}


## Which cars this player has shared, including any too old to be on the list.
func _read_own() -> void:
	var answer: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
		"/cars?select=id&owner=eq.%s" % Backend.user_id)
	if not answer.ok or typeof(answer.data) != TYPE_ARRAY:
		return
	_own.clear()
	for entry: Variant in answer.data:
		if typeof(entry) == TYPE_DICTIONARY and Garage.is_id(str(entry.get("id", ""))):
			_own[str(entry.get("id"))] = true


## Turn what the database sent into rows a page can show, keeping only rows
## that make sense.
##
## Checked rather than trusted: an id and an owner end up in a path, and
## anything shaped wrong is dropped here rather than built into one.
func _read(data: Array) -> Array:
	var read := []
	for entry: Variant in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		var id := str(row.get("id", ""))
		var owner := str(row.get("owner", ""))
		if not Garage.is_id(id) or not _is_uuid(owner):
			continue
		var racer: Variant = row.get("racers")
		var by := "—"
		if typeof(racer) == TYPE_DICTIONARY:
			by = str((racer as Dictionary).get("name", "—"))
		var name := Garage.clean_name(str(row.get("name", "")))
		read.append({
			"id": id,
			"name": name if not name.is_empty() else "A CAR",
			"by": by,
			"owner": owner,
			"vertices": int(row.get("vertices", 0)),
			"shared_at": str(row.get("shared_at", "")),
			"mine": owner == Backend.user_id,
		})
	return read


func _with_here(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> Dictionary:
		var copy := row.duplicate()
		copy["here"] = Garage.has(row.id)
		return copy)


func _row(id: String) -> Dictionary:
	for row: Dictionary in _rows:
		if row.id == id:
			return row
	return {}


func _forget_the_list() -> void:
	_fetched_at = -1.0
	_own.clear()


static func _is_uuid(text: String) -> bool:
	if text.length() != 36:
		return false
	for i in text.length():
		var character := text[i]
		if i in [8, 13, 18, 23]:
			if character != "-":
				return false
		elif not character in "0123456789abcdefABCDEF":
			return false
	return true


func _fine(id: String) -> Dictionary:
	return {"ok": true, "code": 200, "data": id, "error": ""}


func _problem(why: String, code: int = 0) -> Dictionary:
	return {"ok": false, "code": code, "data": null, "error": why}
