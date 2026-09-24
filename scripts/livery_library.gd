extends Node

## Liveries other players have shared, and sharing this player's own.
##
## The same shape as `CarLibrary`, over the same `Backend`, and for the same
## reason: `Liveries` is what is on this machine and stays the truth a livery
## is played against, and nothing in it waits on any of this.
##
## **There is no bucket.** A car has to be a file - a model of a few megabytes
## that the database has no business holding - so `CarLibrary` puts the model
## in storage and the row points at it, and the two-request dance that follows
## is most of that file. A livery is one line of text
## ([scripts/livery.gd](livery.gd)), a few hundred characters of it, so the row
## *is* the livery. One request puts it up and one takes it down, there is no
## half-shared state to clean up after, and a livery cannot exist on the server
## with its design missing.
##
## A livery that comes down is a stranger's design and is treated as one. Its
## text is read into marks through `DecalArt.tidy`, mark by mark, and hashed
## before it is kept; it must come out as the id it was asked for. Then it goes
## in through `Liveries.adopt`, the same door as one drawn on this machine. So
## the worst a hostile row can be is a design this game has no shape for, which
## arrives as a livery with that piece missing.

## Emitted when the list of shared liveries arrives, so a page can put it up
## whenever it lands.
signal catalogue_arrived(rows: Array)

## How many shared liveries the list holds, newest first. The same as the
## cars': enough to browse, few enough to fetch in one request and search
## without asking again.
const CATALOGUE_SIZE := 60
## How long the list stays worth showing before it is asked for again.
const CACHE_SECONDS := 60.0

var _rows: Array = []
var _fetched_at := -1.0
## Whether the last ask got an answer. An empty list is two different things: a
## server that said nobody has shared anything, and one that said nothing.
var _answered := false
## The ids of liveries this player has shared, whether or not they are among
## the newest few dozen on the list.
var _own := {}
## Liveries with a request out, so the same one cannot be sent twice at once.
var _underway := {}


func _ready() -> void:
	Backend.signed_in.connect(_forget_the_list)
	Backend.signed_out.connect(_forget_the_list)


## Whether there is a server at all. Without one, nothing on any screen should
## so much as mention sharing.
func available() -> bool:
	return Backend.configured()


## Whether this player can put a livery up. Browsing needs no account; sharing
## does, because a shared livery has to belong to somebody.
func can_share() -> bool:
	return available() and Backend.is_signed_in()


func answered() -> bool:
	return _answered


## The newest shared liveries, as rows of
## `{id, name, by, owner, marks, shared_at, mine, here}`.
##
## The design comes down with the list rather than being asked for per row,
## because it is a column: the request that says what there is also says what
## each one looks like, so a page of shared liveries can draw every design on
## it without a second request per line. That is the whole of what not having a
## bucket buys.
func catalogue(force := false) -> Array:
	if not available():
		_answered = false
		return []
	var now := Time.get_ticks_msec() / 1000.0
	if not force and _fetched_at >= 0.0 and now - _fetched_at < CACHE_SECONDS:
		return _with_here(_rows)

	var answer: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
		"/liveries?select=id,name,marks,shared_at,owner,racers(name)"
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


## Whether this player is the one who shared a livery.
func is_mine(id: String) -> bool:
	return _own.has(id)


## Put a livery up for everyone.
##
## One request. The design and the name are columns on the row, so the row
## going in is the moment it is shared and there is nothing else to go wrong
## afterwards.
func publish(id: String) -> Dictionary:
	if not available():
		return _problem("This copy of the game has no server set up.")
	if not Backend.is_signed_in():
		return _problem("Sign in to share a livery.")
	if not Liveries.has(id):
		return _problem("That livery is not saved here.")
	if _underway.has(id):
		return _problem("That livery is already on its way.")

	var text := Liveries.written(id)
	# The id is the promise a shared livery makes to whoever downloads it. A
	# design that no longer hashes to it has been edited since it was saved,
	# and sending it up would be sending a lie.
	if Livery.id_for(Livery.read(text)) != id:
		return _problem("That livery has changed since it was saved.")

	_underway[id] = true
	var row: Dictionary = await Backend.rest(HTTPClient.METHOD_POST, "/liveries", {
		"id": id,
		"owner": Backend.user_id,
		"name": Liveries.name_of(id),
		"marks": text,
	})
	_underway.erase(id)
	if not row.ok:
		# Two players who drew the same design hold the same livery, and the
		# row is keyed on the design. A 409 cannot say which of them put it up,
		# so this does not guess.
		if int(row.code) == 409:
			return _problem("That livery is already shared.", 409)
		return row
	_own[id] = true
	_fetched_at = -1.0
	return _fine(id)


## Take a livery back down. The row is the livery, so this is the whole of it.
func unpublish(id: String) -> Dictionary:
	if not available():
		return _problem("This copy of the game has no server set up.")
	if not Backend.is_signed_in():
		return _problem("Sign in first.")
	if not Livery.is_id(id):
		return _problem("That is not a livery.")
	if _underway.has(id):
		return _problem("That livery is already on its way.")
	_underway[id] = true
	var gone: Dictionary = await Backend.rest(HTTPClient.METHOD_DELETE,
		"/liveries?id=eq.%s&owner=eq.%s" % [id, Backend.user_id])
	_underway.erase(id)
	if not gone.ok:
		return gone
	_own.erase(id)
	_fetched_at = -1.0
	return _fine(id)


## Keep a shared livery.
##
## The design is already in hand - it came down with the list - so this asks
## the server nothing at all. What it does is check that the text really is the
## livery it is filed under, and then put it in through the same door as one
## drawn here.
func fetch(id: String) -> Dictionary:
	if not available():
		return _problem("This copy of the game has no server set up.")
	if Liveries.has(id):
		return _fine(id)
	var row := _row(id)
	if row.is_empty():
		return _problem("That livery is not on the list any more.")
	var marks := Livery.read(str(row.marks))
	if Livery.id_for(marks) != id:
		return _problem("What came back from the server is not that livery.")
	var kept: Dictionary = Liveries.adopt(str(row.marks), str(row.name))
	if not kept.ok:
		return _problem(str(kept.error))
	return _fine(id)


## Which liveries this player has shared, including any too old to be on the
## list.
func _read_own() -> void:
	var answer: Dictionary = await Backend.rest(HTTPClient.METHOD_GET,
		"/liveries?select=id&owner=eq.%s" % Backend.user_id)
	if not answer.ok or typeof(answer.data) != TYPE_ARRAY:
		return
	_own.clear()
	for entry: Variant in answer.data:
		if typeof(entry) == TYPE_DICTIONARY and Livery.is_id(str(entry.get("id", ""))):
			_own[str(entry.get("id"))] = true


## Turn what the database sent into rows a page can show, keeping only rows
## that make sense.
##
## Checked rather than trusted: an id ends up in a request and a design ends up
## on a car, so anything shaped wrong is dropped here. A row whose text does
## not hash to its own id is dropped outright - it is a design filed under a
## name that is not its own, and there is nothing sensible to show for it.
func _read(data: Array) -> Array:
	var read := []
	for entry: Variant in data:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = entry
		var id := str(row.get("id", ""))
		var owner := str(row.get("owner", ""))
		if not Livery.is_id(id) or not Backend.is_uuid(owner):
			continue
		var text := str(row.get("marks", ""))
		var marks := Livery.read(text)
		if not Livery.holds(marks) or Livery.id_for(marks) != id:
			continue
		var racer: Variant = row.get("racers")
		var by := "—"
		if typeof(racer) == TYPE_DICTIONARY:
			by = str((racer as Dictionary).get("name", "—"))
		var name := Liveries.clean_name(str(row.get("name", "")))
		read.append({
			"id": id,
			"name": name if not name.is_empty() else "A LIVERY",
			"by": by,
			"owner": owner,
			"marks": text,
			"shared_at": str(row.get("shared_at", "")),
			"mine": owner == Backend.user_id,
		})
	return read


func _with_here(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> Dictionary:
		var copy := row.duplicate()
		copy["here"] = Liveries.has(row.id)
		return copy)


func _row(id: String) -> Dictionary:
	for row: Dictionary in _rows:
		if row.id == id:
			return row
	return {}


func _forget_the_list() -> void:
	_fetched_at = -1.0
	_own.clear()


func _fine(id: String) -> Dictionary:
	return {"ok": true, "code": 200, "data": id, "error": ""}


func _problem(why: String, code: int = 0) -> Dictionary:
	return {"ok": false, "code": code, "data": null, "error": why}
