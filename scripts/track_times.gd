extends Node

## The best time set on each laid-out track, kept between runs.
##
## Separate from GameSettings because these are not preferences. A setting is
## something a player chose and can change back; a time is something that
## happened, and the only thing that may overwrite one is a better one.
##
## A time is stored next to a fingerprint of the track it was set on. Edit a
## corner on track seven and every time set on the old track seven stops
## meaning anything - it was a different road - so the record goes rather than
## standing as a wall nobody can get over because nobody ever drove it.

const SAVE_PATH := "user://times.cfg"

## Bumped by hand when something outside the track files changes what a lap of
## them is worth: the sampling step, the size of a jump, how much speed a pad
## is worth, how fast the car goes. A track file untouched by that is still a
## different track to drive, and its times are worth as little as if it had
## been rewritten.
##
## Two: the cars were retuned from 25 m/s to 30, so every time set before it
## was set by a slower car and none of them stand.
const GEOMETRY := 2

## Emitted when a time is beaten, so a screen showing one can follow it.
signal beaten(track: String, seconds: float)

## Not a const, so a check can point at somewhere that is not the player's own
## record of what they have done.
var save_path := SAVE_PATH

## Track key -> seconds, and track key -> the fingerprint it was set on.
var _best := {}
var _fingerprints := {}


func _ready() -> void:
	load_times()


## The best time on a track, or below zero for one nobody has finished.
##
## A time set on a track that has since been edited is not returned and not
## kept: it is quietly dropped the first time anything asks for it.
func best(track_file: String) -> float:
	var key := _key(track_file)
	if not _best.has(key):
		return -1.0
	if int(_fingerprints.get(key, 0)) != fingerprint(track_file):
		_best.erase(key)
		_fingerprints.erase(key)
		save_times()
		return -1.0
	return float(_best[key])


## Offer a time. Returns true if it was better than what was there, in which
## case it has been written down.
func record(track_file: String, seconds: float) -> bool:
	var standing := best(track_file)
	if standing >= 0.0 and seconds >= standing:
		return false
	var key := _key(track_file)
	_best[key] = seconds
	_fingerprints[key] = fingerprint(track_file)
	save_times()
	beaten.emit(key, seconds)
	return true


## What a track is, as one number. The file itself rather than the course
## built from it: the file is what an author edits, and it changes if and only
## if they changed the track.
func fingerprint(track_file: String) -> int:
	var text := FileAccess.get_file_as_string(track_file)
	if text.is_empty():
		return 0
	return hash("%d\n%s" % [GEOMETRY, text])


## Forget a track's time. Nothing in the game calls this yet; it is here for
## the day a screen offers to.
func forget(track_file: String) -> void:
	var key := _key(track_file)
	_best.erase(key)
	_fingerprints.erase(key)
	save_times()


func save_times() -> void:
	var file := ConfigFile.new()
	for key in _best:
		# A section per track rather than one section of many keys, so what a
		# track has to its name can grow - when it was set, how many runs it
		# took - without moving what is already written down.
		file.set_value(key, "best", _best[key])
		file.set_value(key, "fingerprint", _fingerprints.get(key, 0))
	file.save(save_path)


func load_times() -> void:
	_best.clear()
	_fingerprints.clear()
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	for key in file.get_sections():
		_best[key] = float(file.get_value(key, "best", -1.0))
		_fingerprints[key] = int(file.get_value(key, "fingerprint", 0))


## Tracks are keyed by their file name rather than their path, so moving the
## tracks folder does not lose everything anyone has driven.
func _key(track_file: String) -> String:
	return track_file.get_file().get_basename()
