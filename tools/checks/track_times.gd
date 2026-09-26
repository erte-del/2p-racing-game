extends SceneTree

# Set times, close the game, and see what is still there.
#   Godot --path . --headless --script tools/checks/track_times.gd
#
# Three things have to hold and only one of them is obvious. A time has to
# survive the game closing. Only a better time may replace one. And a time set
# on a track that has since been edited has to go - it was a different road,
# and a record nobody can beat because nobody ever drove it is worse than no
# record at all.
#
# Nothing here touches the player's own times: the store is pointed at a
# scratch file for the duration.

const TRACK := "res://tracks/01_first_light.gd"
const SCRATCH := "user://times_check.cfg"


func _init() -> void:
	await process_frame
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times == null:
		print("  TrackTimes is not loaded")
		quit(1)
		return
	times.save_path = SCRATCH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	times.load_times()

	var faults := 0
	if times.best(TRACK) >= 0.0:
		print("  a track nobody has driven already has a time")
		faults += 1

	# A first time is always an improvement.
	if not times.record(TRACK, 41.55):
		print("  the first time set was not taken")
		faults += 1
	print("first time %.2f s" % times.best(TRACK))

	# A worse one is not.
	if times.record(TRACK, 44.10):
		print("  a slower run replaced the best")
		faults += 1
	# A better one is.
	if not times.record(TRACK, 39.80):
		print("  a faster run did not replace the best")
		faults += 1
	print("after a slower run and a faster one: %.2f s" % times.best(TRACK))
	if not is_equal_approx(times.best(TRACK), 39.80):
		print("  the best is not the fastest run set")
		faults += 1

	# Close the game and open it again.
	times.load_times()
	print("read back from disk: %.2f s" % times.best(TRACK))
	if not is_equal_approx(times.best(TRACK), 39.80):
		print("  the time did not survive the game closing")
		faults += 1

	# Edit the track, and the time on the old one stops meaning anything.
	var real: int = times.fingerprint(TRACK)
	times._fingerprints[TRACK.get_file().get_basename()] = real + 1
	if times.best(TRACK) >= 0.0:
		print("  a time set on an older version of the track still stands")
		faults += 1
	else:
		print("editing the track drops the time set on the old one")
	times.load_times()
	if times.best(TRACK) >= 0.0:
		print("  the dropped time came back off disk")
		faults += 1

	# A release from before the tracks' text shipped with it wrote every time
	# down against a fingerprint of nothing. Those are kept, and from then on
	# held to the track as it is.
	var key := TRACK.get_file().get_basename()
	times._best[key] = 40.25
	times._fingerprints[key] = 0
	times.save_times()
	times.load_times()
	if not is_equal_approx(times.best(TRACK), 40.25):
		print("  a time from a release that could not read its tracks was lost")
		faults += 1
	elif times._fingerprints[key] != real:
		print("  a time from such a release was not given the track's fingerprint")
		faults += 1
	else:
		print("a time set by a release that could not read its tracks is kept")

	# And a track that does not exist has no fingerprint to match against.
	if times.fingerprint("res://tracks/nothing_here.gd") != 0:
		print("  a track that is not there fingerprinted as something")
		faults += 1

	faults += _check_the_variants(times)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Each way of driving a track keeps a time of its own, and NORMAL keeps the
## one it always had. The last is the one that matters most: if a NORMAL
## fingerprint moved, every time anybody has ever set would be dropped the next
## time the game asked for it.
func _check_the_variants(times: Node) -> int:
	var faults := 0
	times.forget(TRACK)
	for variant in ["hard", "track_chaos", "mirror"]:
		times.forget(TRACK, variant)

	var text: String = times.source(TRACK)
	var as_it_was := hash("%d\n%s" % [times.GEOMETRY, text])
	if times.fingerprint(TRACK) != as_it_was:
		print("  NORMAL's fingerprint is not the one every standing time was set against")
		faults += 1
	if times.signature(TRACK) != ("%d\n%s" % [times.GEOMETRY, text]).sha256_text():
		print("  NORMAL's signature moved, so every board would empty")
		faults += 1

	times.record(TRACK, 40.0)
	times.record(TRACK, 50.0, "hard")
	if times.best(TRACK) != 40.0 or times.best(TRACK, "hard") != 50.0:
		print("  a HARD time and a NORMAL time landed on each other")
		faults += 1
	if times.best(TRACK, "mirror") >= 0.0 or times.best(TRACK, "track_chaos") >= 0.0:
		print("  a time set on one way of driving showed up on another")
		faults += 1
	times.load_times()
	if times.best(TRACK, "hard") != 50.0:
		print("  a HARD time did not survive the game closing")
		faults += 1

	var seen := {}
	for variant in ["", "hard", "track_chaos", "mirror"]:
		seen[times.signature(TRACK, variant)] = true
		var key := TrackVariant.key(TRACK, variant)
		var back := TrackVariant.split(key)
		if back[0] != TRACK.get_file().get_basename() or back[1] != variant:
			print("  %s does not come apart into what it was made of" % key)
			faults += 1
	if seen.size() != 4:
		print("  two ways of driving share a board")
		faults += 1
	if faults == 0:
		print("each way of driving keeps its own time and board, and NORMAL's are untouched")
	return faults
