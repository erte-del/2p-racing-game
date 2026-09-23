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

## The kinds of road. The first two are the select screen's two grids: an
## acrobatic track is a different thing to drive - rings instead of painted
## checkpoints, and mostly in the air - so the two are never mixed in one grid.
##
## The third is not a grid. A bot road is a door at the end of a block of ten,
## driven once against a computer, and it is a kind rather than a flag because
## everything that asks a slot what it is - which grid it belongs in, what comes
## after it - has to have an answer that is neither of the other two.
const NORMAL := 0
const ACROBATIC := 1
const BOT := 2

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

## The bot races, one at the end of each block of ten, and their slots.
##
## A bot road is not a twenty-first track: it is a door. It is driven once,
## against a computer, and nothing a time trial writes down is written down on
## one - no time, no medal, no place on the leaderboard - so it appears in
## neither grid.
##
## It still has a slot, because everything that wants to look a road up by its
## file and ask what it is worth goes through one: `index_of()` into `targets()`
## is how `tools/checks/bot_race.gd` finds the time it measures the bot against.
## The slots carry on where the acrobatic ones stop, so no road anywhere in the
## game shares a number with another.
##
## Bot files start with a `b` for the reason the acrobatic ones start with an
## `a`: a time is kept and sent under the file's name, and no two roads may
## share a key.
const BOT_COUNT := 2
const BOT_FILES := [
	"res://tracks/bot/b1_the_gate.gd",
	"res://tracks/bot/b2_the_toll.gd",
]


## Where the overhead shots live. Built by tools/track_thumbnails.gd, one per
## track, named after the track file.
const THUMBNAILS := "res://assets/tracks/%s.png"


## Every slot there is: the normal tracks, the acrobatic ones, the bot roads.
const TOTAL := COUNT + ACROBATIC_COUNT + BOT_COUNT


## The first slot of a kind, and how many slots it has.
static func first(kind: int) -> int:
	match kind:
		ACROBATIC:
			return COUNT
		BOT:
			return COUNT + ACROBATIC_COUNT
		_:
			return 0


static func count(kind: int) -> int:
	match kind:
		ACROBATIC:
			return ACROBATIC_COUNT
		BOT:
			return BOT_COUNT
		_:
			return COUNT


## Which kind of road a slot holds.
static func kind_of(index: int) -> int:
	if index >= COUNT + ACROBATIC_COUNT:
		return BOT
	return ACROBATIC if index >= COUNT else NORMAL


## Every road that exists, of all three kinds, in slot order.
##
## This is every road the game has, which is what a tool sweeping the lot wants
## - it is not every track, and anything that means the time trials wants the
## two lists rather than this.
static func all_files() -> Array:
	return FILES + ACROBATIC_FILES + BOT_FILES


## Whether there is a road in this slot yet.
static func exists(index: int) -> bool:
	if index < 0 or index >= TOTAL:
		return false
	return index - first(kind_of(index)) < _list(kind_of(index)).size()


## The road file for a slot, or an empty string for one still to come.
static func file(index: int) -> String:
	if not exists(index):
		return ""
	var kind := kind_of(index)
	return _list(kind)[index - first(kind)]


## The files of one kind. The three lists are kept apart because they are three
## different things to a player; this is the one place that stops caring which.
static func _list(kind: int) -> Array:
	match kind:
		ACROBATIC:
			return ACROBATIC_FILES
		BOT:
			return BOT_FILES
		_:
			return FILES


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


## Whether a road file is a bot road rather than a time trial. Asked of the
## file rather than of a slot, because `Solo` is handed a file and wants the
## answer before it has built anything.
static func is_bot_road(track_file: String) -> bool:
	return BOT_FILES.has(track_file)


## The bot road standing at the end of a block of ten, or an empty string for a
## block whose door is not built yet.
##
## Here rather than worked out at the call sites, because the arithmetic that
## turns a block into a road and back is the one thing the menu and the race
## have to agree about: the menu opens a door and the race writes down which
## door was opened, and the two are the same number or the gate opens the wrong
## ten.
static func bot_road(block: int) -> String:
	if block < 0 or block >= BOT_FILES.size():
		return ""
	return BOT_FILES[block]


## Which block a bot road is the door at the end of, or -1 for a road that is
## not one.
static func block_of_bot_road(track_file: String) -> int:
	return BOT_FILES.find(track_file)


## Which slot a road file sits in, or -1 for one that is not on any list.
static func index_of(track_file: String) -> int:
	for kind in [NORMAL, ACROBATIC, BOT]:
		var at: int = _list(kind).find(track_file)
		if at >= 0:
			return first(kind) + at
	return -1


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
