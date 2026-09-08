class_name Sandbox
extends RefCounted

## Whether this run is allowed to touch anything real.
##
## A test harness drives the game itself - it loads the race scene, finishes a
## run, presses the buttons - and everything the game does when a player does
## those things, it also does when a test does them. It writes the time down.
## It sends the time to the server. A harness written to look at a screen
## quietly rewrites the records of whoever is running it, and the damage is
## discovered later, if at all.
##
## So a sandboxed run keeps its files somewhere else and has no server at all.
## Not "does not send" - has none: the backend never reads its config, so
## nothing is configured, nothing is signed in, and every path that would have
## gone to the network takes the branch it already has for a game built
## without a backend. That branch is exercised by real players, which is worth
## more than a flag checked in one place before an HTTP call.
##
## Two ways in, because the one that has to be remembered is the one that gets
## forgotten. `--sandbox` on the command line asks for it outright; and any
## run whose scene lives in `tools/` is a test by definition and gets it
## whether it asked or not.

## What to pass to ask for it: `godot --path . -- --sandbox`.
const FLAG := "--sandbox"

## Where a sandboxed run keeps its files. Beside the real ones rather than in
## a temporary folder, so it is obvious what they are and what wrote them.
const FOLDER := "user://sandbox"

## Worked out once. Nothing about it can change while the game is running, and
## it is asked for on every save.
static var _settled := false
static var _sandboxed := false


## Whether this run is a test.
static func on() -> bool:
	if _settled:
		return _sandboxed
	_settled = true
	_sandboxed = _asked_for() or _running_out_of_tools()
	if _sandboxed:
		# Said out loud, once. A test that silently writes somewhere else is
		# the same surprise as a test that silently writes somewhere real.
		print("Sandbox: files under %s, and no backend." % FOLDER)
	return _sandboxed


## Where a file actually goes. Real runs get the path they asked for; test
## runs get the same name inside the sandbox, so the two cannot collide and
## nothing has to invent a second naming scheme.
static func path(wanted: String) -> String:
	if not on():
		return wanted
	DirAccess.make_dir_recursive_absolute(FOLDER)
	return "%s/%s" % [FOLDER, wanted.get_file()]


## Where a whole folder of files goes. `path` flattens what it is given into
## one directory, which is right for the handful of single files that were all
## there was when it was written, and wrong for anything that keeps a folder
## per thing - the garage keeps a folder per car. This relocates the folder
## instead and leaves what is under it alone.
##
## It makes the folder as well, because every caller wants it to be there.
static func folder(wanted: String) -> String:
	var made := wanted
	if on():
		made = "%s/%s" % [FOLDER, wanted.trim_prefix("user://")]
	DirAccess.make_dir_recursive_absolute(made)
	return made


static func _asked_for() -> bool:
	return FLAG in OS.get_cmdline_args() or FLAG in OS.get_cmdline_user_args()


## Anything under `tools/` named on the command line. Those are harnesses -
## there is nothing in that folder a player runs - so they are sandboxed
## without being asked, which is the only kind of guard that holds.
##
## Scripts as well as scenes. Harnesses come in both shapes: some load a scene
## and drive it, and most are a `--script` that never names one. Only scenes
## were caught at first, which meant the guard that was meant to stop a test
## rewriting somebody's records was missing from the harnesses that actually
## finish a lap.
static func _running_out_of_tools() -> bool:
	for arg in OS.get_cmdline_args():
		if not arg.contains("tools/"):
			continue
		if arg.ends_with(".tscn") or arg.ends_with(".gd"):
			return true
	return false
