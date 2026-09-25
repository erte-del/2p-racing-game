extends SceneTree

# Every track has a signature, and prints it.
#   Godot --path . --headless --script tools/checks/track_sources.gd
#
# In the editor this can only fail on a track file that is missing. What it is
# for is the list it prints: the signatures an export has to agree with.
# `tools/signature_probe.gd` prints the same list from inside an exported game,
# which will not run a `--script` (see Exported builds in the README).
#
# An export ships every script compiled and leaves the text behind, and a track
# with no text has no signature - so a release could not post a time or read a
# board, while the editor worked perfectly and nothing looked wrong until a
# player on another machine asked where their times had gone. The two lists
# have to be the same, line for line, or a release and the editor are keeping
# two different boards for every track.


func _init() -> void:
	await process_frame
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times == null:
		print("  TrackTimes is not loaded")
		quit(1)
		return

	var faults := 0
	for file: String in TrackRoster.all_files():
		var signature: String = times.signature(file)
		print("%s %s" % [file.get_file().get_basename(), signature])
		if signature.is_empty():
			print("  %s has no signature: its text is not in this build" % file)
			faults += 1
		elif times.fingerprint(file) == 0:
			print("  %s has a signature but no fingerprint" % file)
			faults += 1

	print("%d fault(s)" % faults)
	quit(1 if faults > 0 else 0)
