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

	DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH))
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)
