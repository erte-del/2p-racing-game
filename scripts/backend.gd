extends Node

## The game's one door out to the internet.
##
## Everything that talks to the server goes through here, so there is exactly
## one place that knows the address, holds the signed-in player's token and
## decides what to do when the network is not there. What sits on top of this
## - `Leaderboard`, and `CarLibrary` - is written as if the server always
## answers, because this is where it is made true.
##
## The rule the whole thing is built on is that nothing here may ever stop the
## game. Every call can be awaited, every call comes back with something even
## when the request failed, and no screen waits on one before it will draw. A
## player on a plane drives exactly the same game as a player at home; they
## just do it without a board on the wall.
##
## Passwords pass through this file and are never kept in it. They go straight
## to the server over HTTPS in the one request that checks them, and what
## comes back - a token that expires and can be revoked - is what gets written
## down. The player's password is not ours to store and we do not store it.

## Where the address and the public key live. Not committed, because it is
## yours rather than the game's; `backend.example.cfg` next to it says what
## goes in it. The game runs without it, with the boards simply absent.
const CONFIG_PATH := "res://backend.cfg"

## Where the signed-in session is remembered between runs, so signing in is
## something a player does once rather than every time they open the game.
##
## This holds a refresh token in plain text in the player's own user folder.
## That is the same trade every game with an account makes: anyone who can
## read that file is already standing at the player's unlocked machine.
const SESSION_PATH := "user://session.cfg"

## How long before a token actually expires we go and get a new one, in
## seconds. A request that sets off valid and arrives expired is a request
## that fails for no reason the player could understand.
const REFRESH_MARGIN := 60.0

## How long any one request may take before we stop waiting on it. Short
## enough that a dead network is a pause rather than a hang.
const TIMEOUT := 10.0

## And how long one carrying a file may take. A model is megabytes rather than
## a row, and a player on a slow line should not be told their car failed to
## upload because it was taking as long as a car takes.
const FILE_TIMEOUT := 120.0

## Emitted when a player signs in or out, so a screen showing who they are can
## follow it without asking every frame.
signal signed_in
signal signed_out

var url := ""
var anon_key := ""

## Who is signed in, or empty for nobody. The id is what the server knows them
## by; the name is what a board shows.
var user_id := ""
var display_name := ""

var _access_token := ""
var _refresh_token := ""
## When the access token stops being any good, against `Time`'s unix clock.
var _expires_at := 0.0


func _ready() -> void:
	# A test run has no backend at all. Leaving the config unread is what does
	# it: with no url and no key nothing is `configured()`, so there is no
	# session to load, no token to refresh, no board to fetch and no time to
	# post - and every one of those paths is the one a build shipped without a
	# `backend.cfg` already takes.
	if Sandbox.on():
		return
	_load_config()
	_load_session()
	if not _refresh_token.is_empty():
		# Signing back in is done in the background on the way past. Nothing
		# on the title screen is waiting for it, and if it fails the player is
		# simply signed out, which is where they would have been anyway.
		_resume_session()


## Whether there is a server to talk to at all.
##
## Everything above this checks it and goes quiet rather than failing loudly:
## a game built without a `backend.cfg` is the game as it was before any of
## this existed, not a game full of errors.
func configured() -> bool:
	return not url.is_empty() and not anon_key.is_empty()


func signed_in_as() -> String:
	return display_name


func is_signed_in() -> bool:
	return not user_id.is_empty()


## Make an account and sign into it.
##
## The name is taken at the same time as the account, in one call as far as
## the player is concerned, because an account without a name on it cannot
## appear on a board and there is no point in a state the game cannot use.
func sign_up(email: String, password: String, name: String) -> Dictionary:
	if not configured():
		return _problem("This copy of the game has no server set up.")
	var answer: Dictionary = await _call(
		HTTPClient.METHOD_POST, "/auth/v1/signup",
		{"email": email, "password": password}, false)
	if not answer.ok:
		return answer
	var body: Dictionary = answer.data

	# A project with email confirmation switched on hands back an account with
	# no session on it. There is nothing wrong and nothing to retry: the
	# player has to go and click a link, and saying so is the whole answer.
	if not body.has("access_token"):
		return _problem(
			"Account made. Check your email for the confirmation link, "
			+ "then sign in.")

	_take_session(body)
	var claimed: Dictionary = await _claim_name(name)
	if not claimed.ok:
		# The account exists and is signed in; only the name did not stick.
		# Saying which is the difference between a player trying another name
		# and a player trying to sign up all over again.
		return claimed
	signed_in.emit()
	return _fine({})


func sign_in(email: String, password: String) -> Dictionary:
	if not configured():
		return _problem("This copy of the game has no server set up.")
	var answer: Dictionary = await _call(
		HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password",
		{"email": email, "password": password}, false)
	if not answer.ok:
		return answer
	_take_session(answer.data)
	await _load_name()
	signed_in.emit()
	return _fine({})


## Sign out on this machine.
##
## The times already on the server stay there - they are the player's, and
## signing out is not the same as saying none of it happened. What goes is the
## token and the memory of it here.
func sign_out() -> void:
	if not _access_token.is_empty():
		# Told to the server so the token stops working everywhere rather than
		# only being forgotten here. Not waited on: whether it lands changes
		# nothing about being signed out on this machine.
		_call(HTTPClient.METHOD_POST, "/auth/v1/logout", {}, true)
	user_id = ""
	display_name = ""
	_access_token = ""
	_refresh_token = ""
	_expires_at = 0.0
	DirAccess.remove_absolute(Sandbox.path(SESSION_PATH))
	signed_out.emit()


## Change the name shown on the boards. The times keep their place; only what
## is written beside them changes.
func rename(name: String) -> Dictionary:
	if not is_signed_in():
		return _problem("Sign in first.")
	var answer: Dictionary = await _call(
		HTTPClient.METHOD_PATCH, "/rest/v1/racers?id=eq.%s" % user_id,
		{"name": name}, true)
	if not answer.ok:
		return _name_problem(answer)
	display_name = name
	signed_in.emit()
	return _fine({})


## A read or write against the database, as the signed-in player where there
## is one and as nobody where there is not.
##
## This is what `Leaderboard` is written in terms of. Reading a board works
## signed out, which is why the token is optional rather than required.
func rest(method: int, path: String, body: Variant = null,
		prefer: String = "") -> Dictionary:
	if not configured():
		return _problem("No server.")
	return await _call(method, "/rest/v1" + path, body, true, prefer)


## Put a file in a bucket. `path` is everything after the bucket name.
##
## Storage is not the database and does not go through `rest`: what travels is
## the file itself rather than a row, so nothing is stringified on the way out
## and nothing is parsed on the way back.
func upload(bucket: String, path: String, bytes: PackedByteArray,
		kind: String) -> Dictionary:
	if not configured():
		return _problem("No server.")
	return await _send_bytes(HTTPClient.METHOD_POST,
			"/storage/v1/object/%s/%s" % [bucket, path], bytes, kind)


## Fetch a file out of a bucket, as bytes.
##
## Read as the signed-in player where there is one and as nobody where there is
## not, the same as everything else here - which is what lets somebody look at
## what other people have shared before deciding an account is worth making.
func download(bucket: String, path: String) -> Dictionary:
	if not configured():
		return _problem("No server.")
	return await _send_bytes(HTTPClient.METHOD_GET,
			"/storage/v1/object/%s/%s" % [bucket, path], PackedByteArray(), "")


## Take a file back out of a bucket.
func erase(bucket: String, path: String) -> Dictionary:
	if not configured():
		return _problem("No server.")
	return await _send_bytes(HTTPClient.METHOD_DELETE,
			"/storage/v1/object/%s/%s" % [bucket, path], PackedByteArray(), "")


## The same request as `_call`, carrying bytes instead of a row.
##
## It is a second function rather than a flag on the first because almost
## everything about it differs: what goes out is not JSON, what comes back is
## not JSON, and the only interesting thing about the answer is the file. What
## it does share is the token - a storage request is as much this player as any
## other, and it is refreshed the same way before it is sent.
func _send_bytes(method: int, path: String, bytes: PackedByteArray,
		kind: String) -> Dictionary:
	await _fresh_token()

	var headers := PackedStringArray(["apikey: " + anon_key])
	if not kind.is_empty():
		headers.append("Content-Type: " + kind)
	if not _access_token.is_empty():
		headers.append("Authorization: Bearer " + _access_token)
	else:
		headers.append("Authorization: Bearer " + anon_key)

	var http := HTTPRequest.new()
	# A model is megabytes rather than a row, so it gets longer than the ten
	# seconds a request for a board is allowed.
	http.timeout = FILE_TIMEOUT
	_keep_running(http)

	var started := http.request_raw(url + path, headers, method, bytes)
	if started != OK:
		http.queue_free()
		return _problem("Could not reach the server.")

	var result: Array = await http.request_completed
	http.queue_free()

	if int(result[0]) != HTTPRequest.RESULT_SUCCESS:
		return _problem("No connection.")
	var code := int(result[1])
	var body: PackedByteArray = result[3]
	if code < 200 or code >= 300:
		# A storage error is JSON even though nothing else about this is, so
		# the human half of it can still be dug out the usual way.
		return _problem(_message_in(
			JSON.parse_string(body.get_string_from_utf8()), code), code)
	return _fine(body)


## The one request, and the only place in the game that touches HTTP.
##
## `authorised` asks for the player's token to be used if there is one. The
## public key goes on every request either way: it is what identifies the
## project, not what identifies the player, and it is meant to be shipped -
## what stops one player writing another's row is the policies on the tables,
## not the secrecy of this key.
func _call(method: int, path: String, body: Variant, authorised: bool,
		prefer: String = "") -> Dictionary:
	if authorised:
		await _fresh_token()

	var headers := PackedStringArray([
		"apikey: " + anon_key,
		"Content-Type: application/json",
		# Ask PostgREST for the rows it wrote back, so a write can be checked
		# rather than assumed.
		"Prefer: " + ("return=representation" if prefer.is_empty()
			else prefer + ",return=representation"),
	])
	if authorised and not _access_token.is_empty():
		headers.append("Authorization: Bearer " + _access_token)
	else:
		headers.append("Authorization: Bearer " + anon_key)

	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	# One node per request rather than one shared node, so two things asking
	# at once do not cancel each other - which is exactly what happens on the
	# track screen, where a board is fetched while a time is being sent.
	_keep_running(http)

	var payload := "" if body == null else JSON.stringify(body)
	var started := http.request(url + path, headers, method, payload)
	if started != OK:
		http.queue_free()
		return _problem("Could not reach the server.")

	var result: Array = await http.request_completed
	http.queue_free()

	var outcome := int(result[0])
	var code := int(result[1])
	var text := (result[3] as PackedByteArray).get_string_from_utf8()

	if outcome != HTTPRequest.RESULT_SUCCESS:
		# Every one of these is the same thing to a player - the server is not
		# answering - and none of them are anything they can do something
		# about, so they are not spelled out.
		return _problem("No connection.")

	var parsed: Variant = JSON.parse_string(text)
	if code < 200 or code >= 300:
		return _problem(_message_in(parsed, code), code)
	return _fine(parsed if parsed != null else {})


## Hang a request off this node in a way that survives the game being paused.
##
## An HTTPRequest polls in `_process`, and a paused tree stops that: the
## request sets off and then simply never finishes. That cost nothing while
## every screen that asked the server anything was a menu screen, and costs
## everything now that the garage sits over a paused race - sharing a car,
## taking one down and fetching one all happen with the tree stopped.
##
## Set on the request rather than on this node, because it is the request that
## is not part of the game: whether a player has stopped the race has nothing
## to do with whether some bytes already on the wire should keep moving.
func _keep_running(http: HTTPRequest) -> void:
	http.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(http)


## Make sure the token in hand will still be good when the request lands, and
## quietly swap it for a new one when it will not.
func _fresh_token() -> void:
	if _refresh_token.is_empty():
		return
	if not _access_token.is_empty():
		if Time.get_unix_time_from_system() < _expires_at - REFRESH_MARGIN:
			return
	var answer: Dictionary = await _call(
		HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token",
		{"refresh_token": _refresh_token}, false)
	if answer.ok:
		_take_session(answer.data)
		return
	# A refresh token the server no longer honours means this machine is
	# signed out, whatever it thought a moment ago. Anything else - a dead
	# network, a server having a bad day - leaves the session alone to be
	# tried again later, because a player should not be thrown out of their
	# account by a dropped wifi connection.
	if int(answer.code) >= 400 and int(answer.code) < 500:
		sign_out()


## Come back to a session left by a previous run.
func _resume_session() -> void:
	await _fresh_token()
	if _refresh_token.is_empty():
		return
	await _load_name()
	signed_in.emit()


## Write down what a sign-in handed back.
func _take_session(body: Variant) -> void:
	if typeof(body) != TYPE_DICTIONARY:
		return
	var answer: Dictionary = body
	_access_token = str(answer.get("access_token", ""))
	_refresh_token = str(answer.get("refresh_token", _refresh_token))
	_expires_at = Time.get_unix_time_from_system() + float(
		answer.get("expires_in", 3600))
	var who: Variant = answer.get("user")
	if typeof(who) == TYPE_DICTIONARY:
		user_id = str((who as Dictionary).get("id", user_id))
	_save_session()


## Take a name on a new account.
func _claim_name(name: String) -> Dictionary:
	var answer: Dictionary = await _call(
		HTTPClient.METHOD_POST, "/rest/v1/racers",
		{"id": user_id, "name": name}, true)
	if not answer.ok:
		return _name_problem(answer)
	display_name = name
	return _fine({})


## Ask the server what this player is called.
func _load_name() -> void:
	var answer: Dictionary = await _call(
		HTTPClient.METHOD_GET,
		"/rest/v1/racers?select=name&id=eq.%s" % user_id, null, true)
	if not answer.ok or typeof(answer.data) != TYPE_ARRAY:
		return
	var rows: Array = answer.data
	if rows.is_empty():
		return
	display_name = str((rows[0] as Dictionary).get("name", ""))


## The database says a unique index was violated; a player needs to be told
## somebody already races under that name.
func _name_problem(answer: Dictionary) -> Dictionary:
	if int(answer.code) == 409:
		return _problem("That name is taken.")
	return answer


func _save_session() -> void:
	var file := ConfigFile.new()
	# The access token is deliberately not written. It is worth minutes and
	# would be stale by the next run anyway, and the fewer keys sitting in a
	# file on disk the better.
	file.set_value("session", "refresh_token", _refresh_token)
	file.set_value("session", "user_id", user_id)
	file.save(Sandbox.path(SESSION_PATH))


func _load_session() -> void:
	var file := ConfigFile.new()
	if file.load(Sandbox.path(SESSION_PATH)) != OK:
		return
	_refresh_token = str(file.get_value("session", "refresh_token", ""))
	user_id = str(file.get_value("session", "user_id", ""))


func _load_config() -> void:
	var file := ConfigFile.new()
	if file.load(CONFIG_PATH) != OK:
		return
	url = str(file.get_value("supabase", "url", "")).rstrip("/")
	anon_key = str(file.get_value("supabase", "anon_key", ""))


## Dig the human half out of whatever shape the server put its complaint in.
func _message_in(parsed: Variant, code: int) -> String:
	if typeof(parsed) == TYPE_DICTIONARY:
		var body: Dictionary = parsed
		for key in ["msg", "message", "error_description", "error_message"]:
			if body.has(key):
				return str(body[key])
	if code == 401 or code == 403:
		return "Signed out. Sign in again."
	return "The server said no (%d)." % code


func _fine(data: Variant) -> Dictionary:
	return {"ok": true, "code": 200, "data": data, "error": ""}


func _problem(why: String, code: int = 0) -> Dictionary:
	return {"ok": false, "code": code, "data": null, "error": why}
