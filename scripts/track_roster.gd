class_name TrackRoster
extends RefCounted

## The laid-out tracks, normal and acrobatic, in the order they are shown.
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

## The two kinds of track, which the select screen shows as two grids. An
## acrobatic track is a different thing to drive - rings instead of painted
## checkpoints, and mostly in the air - so the two are never mixed in one grid.
const NORMAL := 0
const ACROBATIC := 1

## How many normal tracks there will be.
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
	"res://tracks/16_grinder.gd",
	"res://tracks/17_whiplash.gd",
	"res://tracks/18_bottleneck.gd",
	"res://tracks/19_the_wringer.gd",
	"res://tracks/20_last_light.gd",
]

## How many acrobatic tracks there will be, and the ones that exist.
##
## Every track has one slot number across both lists - the normal tracks are
## slots 0 to 19 and the acrobatic ones 20 onwards - so everything that only
## wants "a track" keeps working with one number. Acrobatic files start with an
## `a`, because a time is kept and sent under the file's name, and the
## first acrobatic track and the first normal one must never share one.
const ACROBATIC_COUNT := 10
const ACROBATIC_FILES := [
	"res://tracks/acrobatic/a01_lift_off.gd",
	"res://tracks/acrobatic/a02_sky_stairs.gd",
	"res://tracks/acrobatic/a03_island_hopper.gd",
	"res://tracks/acrobatic/a04_tightrope.gd",
	"res://tracks/acrobatic/a05_elevator.gd",
	"res://tracks/acrobatic/a06_high_road_low_road.gd",
	"res://tracks/acrobatic/a07_freefall.gd",
	"res://tracks/acrobatic/a08_pinball.gd",
	"res://tracks/acrobatic/a09_knot.gd",
	"res://tracks/acrobatic/a10_last_leap.gd",
]

## Where the overhead shots live. Built by tools/track_thumbnails.gd, one per
## track, named after the track file.
const THUMBNAILS := "res://assets/tracks/%s.png"


## Every slot, normal and acrobatic.
const TOTAL := COUNT + ACROBATIC_COUNT


## The first slot of a kind, and how many slots it has.
static func first(kind: int) -> int:
	return COUNT if kind == ACROBATIC else 0


static func count(kind: int) -> int:
	return ACROBATIC_COUNT if kind == ACROBATIC else COUNT


## Which kind of track a slot holds.
static func kind_of(index: int) -> int:
	return ACROBATIC if index >= COUNT else NORMAL


## Every track that exists, of both kinds, in slot order.
static func all_files() -> Array:
	return FILES + ACROBATIC_FILES


## Whether there is a track in this slot yet.
static func exists(index: int) -> bool:
	if index < 0 or index >= TOTAL:
		return false
	if index < COUNT:
		return index < FILES.size()
	return index - COUNT < ACROBATIC_FILES.size()


## The track file for a slot, or an empty string for one still to come.
static func file(index: int) -> String:
	if not exists(index):
		return ""
	return FILES[index] if index < COUNT else ACROBATIC_FILES[index - COUNT]


## What a track calls itself. Read off the track by building its description,
## which costs a few array appends and no geometry at all.
static func track_name(index: int) -> String:
	# Numbered within its own grid, so the first acrobatic slot is 01 too.
	var numbered := "TRACK %02d" % (index - first(kind_of(index)) + 1)
	if not exists(index):
		return numbered
	var written := load(file(index)) as GDScript
	if written == null:
		return numbered
	var definition: TrackDefinition = written.new()
	definition.describe()
	return definition.track_name


## Which slot a track file sits in, or -1 for one that is not on the list.
static func index_of(track_file: String) -> int:
	var normal := FILES.find(track_file)
	if normal >= 0:
		return normal
	var acrobatic := ACROBATIC_FILES.find(track_file)
	return COUNT + acrobatic if acrobatic >= 0 else -1


## What a lap of this track is worth: gold, silver and bronze in seconds, or
## all zero for a track with no targets set.
static func targets(index: int) -> Vector3:
	if not exists(index):
		return Vector3.ZERO
	var written := load(file(index)) as GDScript
	if written == null:
		return Vector3.ZERO
	var definition: TrackDefinition = written.new()
	definition.describe()
	return definition.targets


## The overhead shot for a slot, or null for a track with none yet.
static func thumbnail(index: int) -> Texture2D:
	if not exists(index):
		return null
	var path: String = THUMBNAILS % file(index).get_file().get_basename()
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
