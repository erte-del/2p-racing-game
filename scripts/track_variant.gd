class_name TrackVariant
extends RefCounted

## The ways a laid-out track can be driven, and what each is called wherever a
## time is written down or sent.
##
## A variant is a different road to drive, so it keeps its own best time and
## has its own board. Nothing set on one may land on another: a time set on the
## mirrored First Light is not a time on First Light.
##
## Named constants rather than strings typed out at each call site, so a
## misspelt variant is a compile error and not a quiet fifth board nobody can
## find. NORMAL is the empty string on purpose: it is the track as written, and
## a key with nothing added to it is the key every time set before variants
## existed was already kept under. Not one of those moves.

const NORMAL := ""
const HARD := "hard"
## Track chaos: the track as written, in the tuned car, with its hazards rolled
## again every run. **Not chaos mode**, the endless course's `GameSettings.chaos`
## that re-rolls the car, the sky and the road itself, and which a laid-out
## track always turns off. The two share the word on their buttons and nothing
## else, so this one is called track chaos everywhere it is named - here, in
## the key its times are kept under, and in the notes.
const TRACK_CHAOS := "track_chaos"
const MIRROR := "mirror"

## In the order the track page shows them.
const ALL := [NORMAL, HARD, TRACK_CHAOS, MIRROR]


## What a track's time is kept and sent under: the file's name, and for any
## way but NORMAL, a hyphen and the variant. Hyphen because every track file
## is named with underscores, so the two halves can never be confused.
static func key(track_file: String, variant := NORMAL) -> String:
	var base := track_file.get_file().get_basename()
	return base if variant == NORMAL else "%s-%s" % [base, variant]


## A key taken apart again: the file name it was made from, and the variant.
## A key with no variant on the end is NORMAL, which is every key written down
## before variants existed.
static func split(track_key: String) -> Array:
	for variant: String in ALL:
		if variant != NORMAL and track_key.ends_with("-" + variant):
			return [track_key.trim_suffix("-" + variant), variant]
	return [track_key, NORMAL]


## What the page calls it. Track chaos is CHAOS on the page, since it is on a
## track's own page and the word has nothing to be confused with there.
static func display_name(variant: String) -> String:
	match variant:
		NORMAL:
			return "NORMAL"
		TRACK_CHAOS:
			return "CHAOS"
	return variant.to_upper()
