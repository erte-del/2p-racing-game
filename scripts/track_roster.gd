class_name TrackRoster
extends RefCounted

## The twenty laid-out tracks, in the order they are shown.
##
## The list is as long as the game intends to be, not as long as it currently
## is: a slot with nothing in it is still a slot, and the select screen shows
## it as a track that is coming rather than leaving a gap or a short grid. The
## shape of the game is better shown as nineteen doors that do not open yet
## than sprung on the players one at a time.
##
## A track's name is read off the track itself rather than repeated here.
## Names written down in two places drift apart, and the one on the button
## would be the one nobody notices is wrong.

## How many there will be.
const COUNT := 20

## The tracks that exist, in order. Everything past the end of this is a slot
## waiting to be filled.
const FILES := [
	"res://tracks/01_first_light.gd",
	"res://tracks/02_long_way_round.gd",
	"res://tracks/03_the_weave.gd",
	"res://tracks/04_cold_start.gd",
	"res://tracks/05_overpass.gd",
	"res://tracks/06_split_decision.gd",
	"res://tracks/07_pinch.gd",
	"res://tracks/08_switchback.gd",
	"res://tracks/09_the_gauntlet.gd",
	"res://tracks/10_long_haul.gd",
	"res://tracks/11_the_hook.gd",
	"res://tracks/12_leap_of_faith.gd",
	"res://tracks/13_needle.gd",
	"res://tracks/14_relentless.gd",
	"res://tracks/15_rattlesnake.gd",
]

## Where the overhead shots live. Built by tools/track_thumbnails.gd, one per
## track, named after the track file.
const THUMBNAILS := "res://assets/tracks/%s.png"


## Whether there is a track in this slot yet.
static func exists(index: int) -> bool:
	return index >= 0 and index < FILES.size()


## The track file for a slot, or an empty string for one still to come.
static func file(index: int) -> String:
	return FILES[index] if exists(index) else ""


## What a track calls itself. Read off the track by building its description,
## which costs a few array appends and no geometry at all.
static func track_name(index: int) -> String:
	if not exists(index):
		return "TRACK %02d" % (index + 1)
	var written := load(FILES[index]) as GDScript
	if written == null:
		return "TRACK %02d" % (index + 1)
	var definition: TrackDefinition = written.new()
	definition.describe()
	return definition.track_name


## Which slot a track file sits in, or -1 for one that is not on the list.
static func index_of(track_file: String) -> int:
	return FILES.find(track_file)


## What a lap of this track is worth: gold, silver and bronze in seconds, or
## all zero for a track with no targets set.
static func targets(index: int) -> Vector3:
	if not exists(index):
		return Vector3.ZERO
	var written := load(FILES[index]) as GDScript
	if written == null:
		return Vector3.ZERO
	var definition: TrackDefinition = written.new()
	definition.describe()
	return definition.targets


## The overhead shot for a slot, or null for a track with none yet.
static func thumbnail(index: int) -> Texture2D:
	if not exists(index):
		return null
	var path: String = THUMBNAILS % FILES[index].get_file().get_basename()
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
