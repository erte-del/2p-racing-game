extends Node

## Everyone's times on every track, and this player's place among them.
##
## `TrackTimes` is what this machine has done and stays the truth the game is
## played against - the best on the track screen, the split on the result
## screen and the medal all come from there, and all of it works with the
## network unplugged and no account ever made. This is the layer above: it
## sends what was done up, brings what everyone else has done down, and asks
## nothing of the rest of the game in return.
##
## Nothing here is ever waited on before something is shown. A finished run
## puts its time on the screen immediately and posts it in the background; a
## board that has not arrived yet is a board that is not on the screen yet.
## The game is exactly as playable signed out, offline, or against a server
## that has fallen over.
##
## A time that could not be sent is not lost. It goes in an outbox on disk and
## is tried again the next time the game finds a network and an account, which
## is what makes a week of playing on a train arrive all at once rather than
## not at all.

## Where times that have not reached the server yet wait their turn.
const OUTBOX_PATH := "user://outbox.cfg"

## How many places a board shows. Enough that a good player is on it and
## short enough to read at a glance.
const BOARD_SIZE := 25

## How long a board stays worth showing before it is asked for again, in
## seconds. Moving along the grid of tracks and back should not be a request
## per keypress, and a leaderboard that is a minute stale is not wrong in any
## way a player would notice.
const CACHE_SECONDS := 60.0

## Emitted when a board arrives, so a screen can put it up whenever it lands
## rather than holding still until it does.
signal board_arrived(track_file: String, rows: Array)

## Emitted when the sync finishes and local records may have moved, so a
## screen showing a best time can go and read it again.
signal times_changed

## Track key -> {"rows": Array, "at": float}.
var _boards := {}
## Track key -> seconds, for times the server has not taken yet.
var _outbox := {}
## Guards against a second sync starting on top of the first.
var _syncing := false


func _ready() -> void:
	_load_outbox()
	TrackTimes.beaten.connect(_on_beaten)
	Backend.signed_in.connect(_on_signed_in)


## Whether there is anything for a screen to offer the player at all. A build
## with no server in it should not grow an Account button that cannot do
## anything.
func available() -> bool:
	return Backend.configured()


## The board for one track: the quickest times set on this exact version of
## it, quickest first, as rows of `{name, seconds, mine}`.
##
## Readable signed out. A player deciding whether an account is worth making
## should be able to see what they would be joining.
func board(track_file: String, force: bool = false) -> Array:
	if not available():
		return []
	var key := track_file.get_file().get_basename()

	var held: Dictionary = _boards.get(key, {})
	if not force and not held.is_empty():
		if Time.get_ticks_msec() / 1000.0 - float(held["at"]) < CACHE_SECONDS:
			return held["rows"]

	var signature := TrackTimes.signature(track_file)
	if signature.is_empty():
		return []

	# The name is pulled through the foreign key in the same request rather
	# than as a second round trip per row, which is the difference between one
	# request and twenty-six.
	var path := "/times?select=seconds,set_at,racer,racers(name)" + (
		"&track=eq.%s&signature=eq.%s&order=seconds.asc&limit=%d"
		% [key, signature, BOARD_SIZE])
	var answer: Dictionary = await Backend.rest(HTTPClient.METHOD_GET, path)
	if not answer.ok or typeof(answer.data) != TYPE_ARRAY:
		# A board that did not arrive is not an error anybody needs telling
		# about. The screen shows what it showed before, or nothing.
		if held.is_empty():
			return []
		var stale: Array = held["rows"]
		return stale

	var rows := _read_board(answer.data)
	_boards[key] = {"rows": rows, "at": Time.get_ticks_msec() / 1000.0}
	board_arrived.emit(track_file, rows)
	return rows


## Send a time up, or put it in the outbox to be sent later.
##
## Written as an upsert because the game does not know whether this player has
## been here before and should not have to ask. Whether it is a first time or
## a twentieth, and whether it is actually an improvement, are both the
## server's business - it is the one holding the record, and it is the only
## one whose answer cannot be edited by whoever is holding the keyboard.
func submit(track_file: String, seconds: float, refresh: bool = true) -> void:
	if not available():
		return
	var key := track_file.get_file().get_basename()
	if not Backend.is_signed_in():
		_hold(key, seconds)
		return
	var signature := TrackTimes.signature(track_file)
	if signature.is_empty():
		return

	var answer: Dictionary = await Backend.rest(
		HTTPClient.METHOD_POST, "/times",
		{
			"racer": Backend.user_id,
			"track": key,
			"signature": signature,
			"seconds": seconds,
		},
		"resolution=merge-duplicates")

	if not answer.ok:
		_hold(key, seconds)
		return
	_release(key, seconds)
	# The board this time belongs on has just changed, and the copy in hand
	# is now the board as it was before the player got on it.
	_boards.erase(key)
	if refresh:
		board(track_file, true)


## Bring this machine and the server back into line: everything done here that
## the server has not got, and everything the player has done elsewhere that
## this machine has not.
##
## Run on sign-in and after that whenever a screen that shows times opens. The
## outbox goes first, so a week of driving offline is on the server before
## anything is read back and nothing is pulled down that is about to be beaten
## by something already sitting in the outbox.
func sync() -> void:
	if not available() or not Backend.is_signed_in() or _syncing:
		return
	_syncing = true
	await _flush_outbox()
	await _pull_own_times()
	_syncing = false


## Everything this player has on the server, merged into the local record.
##
## This is the backup half of the feature. A player who reinstalls the game,
## or opens it on another machine, signs in and finds their twenty best laps
## where they left them.
func _pull_own_times() -> void:
	var answer: Dictionary = await Backend.rest(
		HTTPClient.METHOD_GET,
		"/times?select=track,signature,seconds&racer=eq.%s" % Backend.user_id)
	if not answer.ok or typeof(answer.data) != TYPE_ARRAY:
		return

	var moved := false
	for row in answer.data:
		var entry: Dictionary = row
		var file := _file_for(str(entry.get("track", "")))
		if file.is_empty():
			continue
		# A time set on a version of the track this copy of the game does not
		# have is not this player's best on the track in front of them. It
		# stays on the server, where it is still their record on the road it
		# was set on, and it is simply not what is shown here.
		if str(entry.get("signature", "")) != TrackTimes.signature(file):
			continue
		if TrackTimes.adopt(file, float(entry.get("seconds", 0.0))):
			moved = true

	# Anything better here than what came back is something the server has not
	# seen - a run set before this machine ever signed in. Sent up now, so the
	# account holds everything the player has done rather than everything they
	# did after making it.
	await _push_local_bests(answer.data)

	if moved:
		times_changed.emit()


## Offer the server every local best it does not already hold, or holds a
## slower version of.
func _push_local_bests(known: Array) -> void:
	var theirs := {}
	for row in known:
		var entry: Dictionary = row
		theirs[str(entry.get("track", ""))] = float(entry.get("seconds", 0.0))

	for index in TrackRoster.FILES.size():
		var file: String = TrackRoster.file(index)
		var mine := TrackTimes.best(file)
		if mine < 0.0:
			continue
		var key := file.get_file().get_basename()
		if theirs.has(key) and mine >= float(theirs[key]):
			continue
		await submit(file, mine, false)


## Turn what the database sent into what a board shows.
func _read_board(rows: Array) -> Array:
	var read := []
	for row in rows:
		var entry: Dictionary = row
		var racer: Variant = entry.get("racers")
		var name := "—"
		if typeof(racer) == TYPE_DICTIONARY:
			name = str((racer as Dictionary).get("name", "—"))
		read.append({
			"name": name,
			"seconds": float(entry.get("seconds", 0.0)),
			# Worked out here rather than on the screen, because the screen
			# should not have to know what a user id is to put a highlight on
			# the player's own row.
			"mine": str(entry.get("racer", "")) == Backend.user_id,
		})
	return read


## A run just beat this machine's record. Whether it beats what the server
## holds is not this function's business to decide.
func _on_beaten(track: String, seconds: float) -> void:
	var file := _file_for(track)
	if file.is_empty():
		return
	submit(file, seconds)


func _on_signed_in() -> void:
	sync()


## Keep a time that could not be sent, if it is the best unsent one.
func _hold(key: String, seconds: float) -> void:
	if _outbox.has(key) and float(_outbox[key]) <= seconds:
		return
	_outbox[key] = seconds
	_save_outbox()


## Take a time out of the outbox now the server has it.
func _release(key: String, seconds: float) -> void:
	if not _outbox.has(key):
		return
	# Only if what landed was at least as good as what is waiting. A player
	# who improved twice while offline has the better of the two still owed.
	if float(_outbox[key]) < seconds:
		return
	_outbox.erase(key)
	_save_outbox()


func _flush_outbox() -> void:
	for key in _outbox.keys():
		var file := _file_for(key)
		if file.is_empty():
			# A time for a track this build no longer has. Nothing can be done
			# with it and keeping it means retrying it forever.
			_outbox.erase(key)
			continue
		await submit(file, float(_outbox[key]), false)


func _save_outbox() -> void:
	var file := ConfigFile.new()
	for key in _outbox:
		file.set_value(key, "seconds", _outbox[key])
	file.save(OUTBOX_PATH)


func _load_outbox() -> void:
	_outbox.clear()
	var file := ConfigFile.new()
	if file.load(OUTBOX_PATH) != OK:
		return
	for key in file.get_sections():
		_outbox[key] = float(file.get_value(key, "seconds", -1.0))


## The track file a key came off, or empty for a key this build knows nothing
## about. Tracks travel as their file name for the same reason they are stored
## under it: moving the tracks folder should not orphan everything anyone has
## driven.
func _file_for(key: String) -> String:
	for index in TrackRoster.FILES.size():
		var file: String = TrackRoster.file(index)
		if file.get_file().get_basename() == key:
			return file
	return ""
