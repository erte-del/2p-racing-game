extends SceneTree

# Push on the medal gate and find out whether it is where it says it is.
#   Godot --path . --headless --script tools/checks/progress.gd
#
# The gate is one number - five golds out of the ten in front of it - and a
# number in a design document is not a number in a program. What is driven here
# is the difference: that four golds do not open it and five do, that a gold
# taken away shuts it again, that winning the race opens the ten behind it and
# nothing else, and that a time set on some other road never counted towards it
# at all.
#
# Medals are not stored anywhere, and the case that moves a gold target is the
# one that proves it. The target is moved in memory and put back again - the
# track file on the disk is left exactly as it was found - and the gate is asked
# the same question on either side of the move. The day anything starts
# remembering a count instead of working it out, that is the case that fails.
#
# Nothing here touches the player's own profile. Both stores are pointed at
# scratch files through Sandbox.path(), so they land beside the sandbox's own
# saves rather than beside the real ones, and both are deleted on the way out.
#
# The stores are fetched out of the tree rather than named. A script run with
# --script is compiled before the autoloads have registered their names, so
# `Progress` and `TrackTimes` are not identifiers here the way they are in the
# game's own scripts - only the nodes at /root are.

const PROGRESS_SCRATCH := "user://progress_check.cfg"
const TIMES_SCRATCH := "user://times_progress_check.cfg"

var _faults := 0
var _progress: Node
var _times: Node


func _init() -> void:
	await process_frame
	_progress = root.get_node_or_null(^"/root/Progress")
	_times = root.get_node_or_null(^"/root/TrackTimes")
	if _progress == null or _times == null:
		print("  a store is not loaded")
		quit(1)
		return
	_progress.save_path = Sandbox.path(PROGRESS_SCRATCH)
	_times.save_path = Sandbox.path(TIMES_SCRATCH)
	print("asking for %d golds in %d, kept at %s"
		% [_progress.GOLDS_NEEDED, _progress.BLOCK, _progress.save_path])

	_a_fresh_profile()
	_four_is_shut_and_five_is_open()
	_a_target_that_moved()
	_winning_a_race()
	_a_win_survives_the_game_closing()
	_times_that_do_not_count()

	_wipe(_progress.save_path)
	_wipe(_times.save_path)
	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


## Somebody who has just installed the game: the first ten to drive, and
## everything after them shut until they have driven them.
func _a_fresh_profile() -> void:
	_from_nothing()
	var said := PackedStringArray()
	for block in _every_block():
		said.append("%s %s" % [_range(block),
			"open" if _progress.open(block) else "shut"])
	print("a fresh profile: %s" % ", ".join(said))
	for block in _every_block():
		if _progress.open(block) != (block == 0):
			_fault("%s is %s on a profile that has done nothing"
				% [_range(block), "open" if _progress.open(block) else "shut"])
		if _progress.won(block):
			_fault("%s's race is won on a profile that has done nothing"
				% _range(block))
		# Including the first: nothing stands in front of the first ten, so
		# there is no gate there to be open.
		if _progress.gate_open(block):
			_fault("the gate into %s is open with no golds behind it"
				% _range(block))


## The whole of the gate, one gold at a time. Written against GOLDS_NEEDED
## rather than against the five it happens to be, so retuning the number moves
## this check with it instead of turning it into a check of the wrong boundary
## that passes anyway.
func _four_is_shut_and_five_is_open() -> void:
	_from_nothing()
	var needed: int = _progress.GOLDS_NEEDED
	var walk := PackedStringArray()
	var opened_at := -1
	for count in range(0, needed + 2):
		if count > 0:
			_lay_down_golds(count)
		var counted: int = _progress.golds_in(0)
		var open: bool = _progress.gate_open(1)
		walk.append("%d:%s" % [counted, "open" if open else "shut"])
		if counted != count:
			_fault("%d golds were set in %s and %d were counted"
				% [count, _range(0), counted])
		if open and opened_at < 0:
			opened_at = count
		if open != (count >= needed):
			_fault("with %d golds the gate is %s"
				% [count, "open" if open else "shut"])
	print("golds in %s against the gate: %s" % [_range(0), " ".join(walk)])
	print("  the gate opened on %d, and it asks for %d" % [opened_at, needed])
	if opened_at != needed:
		_fault("the gate opened on %d golds rather than %d" % [opened_at, needed])
	# The golds buy the race and nothing else. The ten behind it are still shut
	# until that race has actually been driven.
	if _progress.open(1):
		_fault("%s opened on golds alone, without the race being won" % _range(1))


## The case the whole design rests on: move a gold target, ask again, and the
## answer changes.
##
## Nothing was told that anything had happened - no signal, no recount, no save
## - because there is nothing to tell. The gate works the count out from
## TrackTimes.best() and TrackRoster.targets() at the moment it is asked, so a
## target pulled in under a standing lap takes the gold with it there and then.
## That is what a track being tuned looks like from here.
##
## The target is moved by standing a script with a different medals() line in
## the track's place in memory. The file on the disk is not written to, not
## even briefly: a check that can leave a track edited if it falls over is a
## worse thing to have than the case it was proving.
func _a_target_that_moved() -> void:
	_from_nothing()
	var needed: int = _progress.GOLDS_NEEDED
	_lay_down_golds(needed)
	var index := needed - 1
	var track := TrackRoster.file(index)
	var was := FileAccess.get_file_as_string(track)
	var targets := TrackRoster.targets(index)
	var before: bool = _progress.gate_open(1)
	var lap: float = _times.best(track)

	# Gold pulled in under the lap that is already standing, so a time that was
	# a gold a moment ago is a silver now. Nothing else about the track moves.
	var tighter := targets.x - 1.0
	if not _stand_in(track, _moved_gold(was, tighter, targets)):
		_fault("could not move %s's gold target" % TrackRoster.track_name(index))
		return
	var counted: int = _progress.golds_in(0)
	var after: bool = _progress.gate_open(1)

	# And back, which has to bring the gold back with it.
	if not _stand_in(track, was):
		_fault("could not put %s back the way it was" % TrackRoster.track_name(index))
		return
	var again: bool = _progress.gate_open(1)
	print("%s stands at %.2f s: gold %.1f -> %d golds, gate %s; gold %.1f -> %d golds, gate %s"
		% [TrackRoster.track_name(index), lap, targets.x, needed,
			"open" if before else "shut", tighter, counted,
			"open" if after else "shut"])
	if not before:
		_fault("the gate was shut on %d golds before the target was touched" % needed)
	if counted != needed - 1:
		_fault("the lap is over the new gold target and is still being counted")
	if after:
		_fault("the gate stayed open after the gold it was leaning on moved away")
	if not again:
		_fault("putting the target back did not bring the gold back")
	# Nothing was written down on the way through. A count that had been saved
	# somewhere is a count that would still be saved there now.
	if FileAccess.get_file_as_string(_progress.save_path).contains("gold"):
		_fault("the profile has medals written into it")


## Winning the race at the end of a block opens the ten behind it. One block:
## not the one after that, and not the acrobatic tracks, which are not gated.
func _winning_a_race() -> void:
	_from_nothing()
	_lay_down_golds(_progress.GOLDS_NEEDED)
	var heard := [0]
	var ear := func() -> void: heard[0] += 1
	_progress.changed.connect(ear)
	_progress.win(0)
	_progress.changed.disconnect(ear)

	var said := PackedStringArray()
	for block in _every_block():
		said.append("%s %s" % [_range(block),
			"open" if _progress.open(block) else "shut"])
	print("after winning the race at the end of %s: %s, and the screen was told %d time(s)"
		% [_range(0), ", ".join(said), heard[0]])
	for block in _every_block():
		if _progress.open(block) != (block <= 1):
			_fault("%s is %s after one race was won"
				% [_range(block), "open" if _progress.open(block) else "shut"])
		if _progress.won(block) != (block == 0):
			_fault("%s's race is %s after the race at the end of %s was won"
				% [_range(block), "won" if _progress.won(block) else "not won",
					_range(0)])
	if heard[0] != 1:
		_fault("winning one race announced itself %d times" % heard[0])
	# Winning it twice is not a second event.
	_progress.win(0)
	# The acrobatic slots carry on from the same numbering, and a block that ran
	# into them would be asking a player for golds on roads no gate has ever
	# mentioned. Golds on every one of them, and the count is still nothing.
	_lay_down_acrobatic_golds()
	var beyond: int = TrackRoster.first(TrackRoster.ACROBATIC) / _progress.BLOCK
	print("  with a gold on all %d acrobatic tracks, block %s counts %d golds"
		% [TrackRoster.ACROBATIC_COUNT, _range(beyond), _progress.golds_in(beyond)])
	if _progress.golds_in(beyond) != 0:
		_fault("the acrobatic tracks are being counted towards a gate")
	if _progress.gate_open(beyond + 1):
		_fault("golds on the acrobatic tracks opened a gate")


## A door that has been opened stays open. The race is driven once, and a
## player who closes the game and comes back does not find it shut again.
func _a_win_survives_the_game_closing() -> void:
	_from_nothing()
	_progress.win(0)
	var on_disk := FileAccess.get_file_as_string(_progress.save_path)
	# Read back the way the game reads it at startup, off the file rather than
	# out of what is already in memory.
	_progress.load_progress()
	print("written out as %d bytes; after reading it back, %s is %s and %s is %s"
		% [on_disk.length(), _range(0),
			"won" if _progress.won(0) else "not won", _range(1),
			"open" if _progress.open(1) else "shut"])
	if on_disk.is_empty():
		_fault("winning a race wrote nothing to the disk")
	if not _progress.won(0):
		_fault("the win did not survive being written out and read back")
	if not _progress.open(1):
		_fault("%s is shut again after the game was closed and opened" % _range(1))
	if _progress.won(1):
		_fault("reading the profile back won a race nobody drove")


## A gold has to be a gold on one of the ten in front of the gate. A time on
## another road is somebody else's business, and a time set on a road that has
## been redrawn since was set on a different road.
func _times_that_do_not_count() -> void:
	_from_nothing()
	var needed: int = _progress.GOLDS_NEEDED
	var block: int = _progress.BLOCK
	_lay_down_golds(needed - 1)
	# Golds in the ten after this one, which is a block of its own with a gate
	# of its own.
	for index in range(block, mini(block + needed, TrackRoster.FILES.size())):
		_times.record(TrackRoster.file(index), TrackRoster.targets(index).x - 0.5)
	print("%d golds in %s and %d in %s: %s counts %d, gate %s"
		% [needed - 1, _range(0), needed, _range(1), _range(0),
			_progress.golds_in(0), "open" if _progress.gate_open(1) else "shut"])
	if _progress.golds_in(0) != needed - 1:
		_fault("golds from another ten are being counted towards this gate")
	if _progress.gate_open(1):
		_fault("the gate opened on golds set on the tracks behind it")

	# And the one that makes it up, set on a track that has been redrawn since.
	# TrackTimes keeps a fingerprint of the road a time was set on beside the
	# time; scribble on it and the store drops the lap the moment anything asks
	# for it, exactly as it would after a corner was moved.
	_from_nothing()
	_lay_down_golds(needed)
	var stale := needed - 1
	var track := TrackRoster.file(stale)
	var opened: bool = _progress.gate_open(1)
	_the_track_was_redrawn(track)
	print("%s was redrawn under its own gold: %s counts %d, gate went %s -> %s"
		% [TrackRoster.track_name(stale), _range(0), _progress.golds_in(0),
			"open" if opened else "shut",
			"open" if _progress.gate_open(1) else "shut"])
	if not opened:
		_fault("the gate was shut on %d golds before the track was redrawn" % needed)
	if _times.best(track) >= 0.0:
		_fault("a lap set on a road that has since been redrawn is still standing")
	if _progress.golds_in(0) != needed - 1:
		_fault("a lap set on a road that has since been redrawn is still a gold")
	if _progress.gate_open(1):
		_fault("the gate stayed open on a gold set on a road that no longer exists")


# --- setting it up ------------------------------------------------------

## Back to a profile that has driven nothing and won nothing, so each case
## above stands on its own and can be read without the ones before it.
func _from_nothing() -> void:
	_progress.forget()
	_wipe(_progress.save_path)
	_progress.load_progress()
	_wipe(_times.save_path)
	_times.load_times()


## Golds on the first so many tracks of the first block, set just under each
## track's own target rather than at some time written down here: what counts
## as a gold is a fact about the road.
func _lay_down_golds(count: int) -> void:
	for index in count:
		var targets := TrackRoster.targets(index)
		if targets.x <= 0.0:
			_fault("%s offers no gold to earn" % TrackRoster.track_name(index))
			continue
		_times.record(TrackRoster.file(index), targets.x - 0.5)


func _lay_down_acrobatic_golds() -> void:
	var first := TrackRoster.first(TrackRoster.ACROBATIC)
	for offset in TrackRoster.ACROBATIC_COUNT:
		var index := first + offset
		if not TrackRoster.exists(index):
			continue
		var targets := TrackRoster.targets(index)
		if targets.x > 0.0:
			_times.record(TrackRoster.file(index), targets.x - 0.5)


## Stand a script in a track's place in memory, built from the source given.
##
## Nothing is written to the disk. The track is loaded by its path wherever it
## is asked for, so taking over that path is enough to change what every one of
## those places sees, and handing the original source back afterwards puts it
## the way it was.
func _stand_in(track_file: String, source: String) -> bool:
	if source.is_empty():
		return false
	var script := GDScript.new()
	script.source_code = source
	if script.reload() != OK:
		return false
	script.take_over_path(track_file)
	return true


## The same track with its gold target somewhere else, as source text.
func _moved_gold(source: String, gold: float, targets: Vector3) -> String:
	var at := source.find("\tmedals(")
	if at < 0:
		return ""
	var ends := source.find(")", at)
	if ends < 0:
		return ""
	return source.substr(0, at + 1) \
		+ "medals(%.2f, %.2f, %.2f)" % [gold, targets.y, targets.z] \
		+ source.substr(ends + 1)


## Leave behind what a redrawn track leaves behind: a time with the fingerprint
## of a road that is not the one on the disk any more.
func _the_track_was_redrawn(track_file: String) -> void:
	_times.save_times()
	var file := ConfigFile.new()
	if file.load(_times.save_path) != OK:
		_fault("the times were not written out to be scribbled on")
		return
	file.set_value(track_file.get_file().get_basename(), "fingerprint", 1)
	file.save(_times.save_path)
	_times.load_times()


## Every block there is, and one past the end of them - a gate that opens a
## block of ten nobody has built yet must stay shut like any other.
func _every_block() -> Array:
	return range(0, _progress.blocks() + 1)


## A block of ten the way a player counts them, so the first is 1-10.
func _range(block: int) -> String:
	return "%d-%d" % [block * _progress.BLOCK + 1, (block + 1) * _progress.BLOCK]


func _wipe(path: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fault(what: String) -> void:
	print("  %s" % what)
	_faults += 1
