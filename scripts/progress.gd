extends Node

## Which bot races have been won, and therefore how far into the game a player
## has been let.
##
## The twenty tracks are two blocks of ten. At the end of each block stands a
## race against a computer-driven car, and winning that race opens the ten
## behind it. Standing in front of the race is a gate: five golds among the ten
## you have just driven, or it will not start. Finishing ten tracks is not the
## same as being able to drive them, and a player who scraped a bronze on all
## ten and walks into a race against a fast bot loses, repeatedly, with no idea
## what to change.
##
## What is written down here is the wins, and only the wins. Medals are not
## stored and must not be: `golds_in` counts them at the moment it is asked,
## out of `TrackTimes.best()` and `TrackRoster.targets()` through
## `Medal.earned()`. That costs a few file reads on a screen that is being
## drawn anyway, and it buys the thing that matters while the tracks are still
## being tuned - move a gold target and every gate that leaned on it moves with
## it, in the same run, with nothing to invalidate and nothing to migrate. A
## remembered count would be a second copy of a number that already exists, and
## the two would disagree the first time anybody touched a track.
##
## Acrobatic tracks are not gated. They are a different thing to drive, they
## are shown in their own grid, and a player who cannot find five golds among
## the first ten normal tracks should still be free to go and fly through some
## rings. Do not fold them into a block as a kindness: it would be a wall.

const SAVE_PATH := "user://progress.cfg"

## A section is named for its block. See `save_progress` for why there is a
## section at all rather than one section of many keys.
const SECTION := "block_"

## How many tracks stand between one bot race and the next.
const BLOCK := 10

## How many golds out of those ten the race asks for before it will start.
##
## Five of ten, not ten of ten, on purpose: a player may simply hate track
## seven, and the gate is meant to say "you have driven half of these
## properly", not "you have driven every one of them". It is a tuning number
## and it will be argued about, so it is written down once, here, and nowhere
## else - an argument about it should be an argument about this line.
const GOLDS_NEEDED := 5

## Emitted when a race is won, so a screen showing the grid can rebuild without
## a restart: a player who wins sees the next ten open immediately.
##
## Nothing emits this for a medal, and nothing needs to. A medal is earned on a
## track's results screen, which is not the grid, and the grid counts golds
## afresh every time it is built.
signal changed

## Not a const, so a check can point at somewhere that is not the player's own
## record of what they have done.
var save_path := Sandbox.path(SAVE_PATH)

## Block -> true, for the blocks whose race has been won. A block that is not
## in here has not been won; there is no false written anywhere.
var _won := {}


func _ready() -> void:
	load_progress()


## How many blocks of ten there are to get through. A last block short of ten
## still counts as a block - it is still ten slots on the grid, some of them
## waiting for a track.
func blocks() -> int:
	return (TrackRoster.COUNT + BLOCK - 1) / BLOCK


## How many golds a player has among a block's ten tracks.
##
## Counted now rather than remembered; see the note at the top of the file.
func golds_in(block: int) -> int:
	var golds := 0
	for index in range(block * BLOCK, (block + 1) * BLOCK):
		# Time trials only. The acrobatic slots carry on from the same
		# numbering, and a block that ran into them would be asking a player
		# for golds on roads no gate has ever mentioned.
		if not TrackRoster.exists(index):
			continue
		if TrackRoster.kind_of(index) != TrackRoster.NORMAL:
			continue
		var best := TrackTimes.best(TrackRoster.file(index))
		if Medal.earned(best, TrackRoster.targets(index)) == Medal.GOLD:
			golds += 1
	return golds


## Whether the race standing in front of a block may be started at all: five
## golds or more among the ten before it.
##
## Numbered by the block it lets a player into rather than the block it stands
## at the end of, which is the same way round as `open`. The race in front of
## block 1 is the one at the end of block 0, and it asks for golds in block 0.
##
## Nothing stands in front of the first block - it is open to somebody who has
## just installed the game - so there is no gate there to be open, and this
## says so. `open(0)` is the question you want.
func gate_open(block: int) -> bool:
	if block <= 0:
		return false
	return golds_in(block - 1) >= GOLDS_NEEDED


## Whether a block's own race - the one at the end of it - has been won.
##
## The other way round from `open` and `gate_open`: a race belongs to the block
## it finishes and opens the one after, so block 0's race is the door into
## block 1.
func won(block: int) -> bool:
	return _won.has(block)


## Write down that a block's race has been won, and say so.
##
## Winning one twice is not an event: the second time changes nothing, so
## nothing is written and nothing is announced.
func win(block: int) -> void:
	if block < 0 or won(block):
		return
	_won[block] = true
	save_progress()
	changed.emit()


## Whether a block's ten tracks may be driven at all.
##
## The first block is always open. Every block after it waits on the race at
## the end of the one before - having the golds is not enough, because the
## golds only buy the right to start that race. A player who has the golds and
## has not driven it sees the race open and the next ten shut.
func open(block: int) -> bool:
	if block == 0:
		return true
	return won(block - 1)


## Forget every race won. Nothing in the game calls this yet; it is here for
## the day a screen offers to start again, and for a check that wants to begin
## from a profile that has done nothing.
func forget() -> void:
	if _won.is_empty():
		return
	_won.clear()
	save_progress()
	changed.emit()


func save_progress() -> void:
	var file := ConfigFile.new()
	for block in _won:
		# A section per block rather than one section of many keys, for the
		# reason `TrackTimes` keeps a section per track: what a race has to its
		# name can grow - when it was won, by how much, how many goes it took -
		# without moving what is already written down.
		file.set_value(_section(block), "won", true)
	file.save(save_path)


func load_progress() -> void:
	_won.clear()
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	for section in file.get_sections():
		# Anything that is not a block of ours is left alone rather than read
		# as block zero, which is what `int()` would make of it.
		if not section.begins_with(SECTION):
			continue
		if not bool(file.get_value(section, "won", false)):
			continue
		_won[int(section.trim_prefix(SECTION))] = true


func _section(block: int) -> String:
	return "%s%d" % [SECTION, block]
