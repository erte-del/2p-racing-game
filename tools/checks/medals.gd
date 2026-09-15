extends SceneTree

# Work out what times are worth on a track that offers medals.
#   Godot --path . --headless --script tools/checks/medals.gd
#
# The rules are small enough to look obviously right and small enough to be
# wrong at the edges: a time exactly on a target, a track that offers only
# some of the medals, and what to tell a player who is chasing the next one.


func _init() -> void:
	await process_frame
	var faults := 0
	var targets := TrackRoster.targets(0)
	print("%s asks for %.0f / %.0f / %.0f"
		% [TrackRoster.track_name(0), targets.x, targets.y, targets.z])
	if targets == Vector3.ZERO:
		print("  the first track offers no medals")
		faults += 1

	# Written against the targets rather than against the numbers they happen
	# to hold, so retuning the car - which moves every target on every track -
	# does not turn this into a check that tests the wrong boundaries and
	# passes anyway.
	for trial: Array in [
		[targets.x - 2.0, Medal.GOLD], [targets.x - 0.01, Medal.GOLD],
		# On the target is not under it. A medal for exactly the target time
		# would make the number on the screen a lie in one direction or the
		# other, and under is the one a player can act on.
		[targets.x, Medal.SILVER], [targets.y - 0.01, Medal.SILVER],
		[targets.y, Medal.BRONZE], [targets.z - 0.01, Medal.BRONZE],
		[targets.z, Medal.NONE], [targets.z + 11.0, Medal.NONE],
		[-1.0, Medal.NONE],
	]:
		var got: int = Medal.earned(trial[0], targets)
		if got != trial[1]:
			print("  %.2f earned %s, not %s"
				% [trial[0], _name(got), _name(int(trial[1]))])
			faults += 1
	print("%.2f is %s and %.2f is %s, so a target is a time to get under"
		% [targets.x, _name(Medal.earned(targets.x, targets)),
			targets.x - 0.01, _name(Medal.earned(targets.x - 0.01, targets))])

	# What a player is driving at next.
	for trial: Array in [
		[targets.y + 2.0, Medal.SILVER, 2.0], [targets.x + 2.0, Medal.GOLD, 2.0],
		[targets.x - 2.0, Medal.NONE, 0.0], [targets.z + 5.0, Medal.BRONZE, 5.0],
	]:
		var up: Array = Medal.next_up(trial[0], targets)
		if up[0] != trial[1] or not is_equal_approx(up[1], trial[2]):
			print("  from %.2f the next up came out as %s by %.2f, not %s by %.2f"
				% [trial[0], _name(int(up[0])), up[1], _name(int(trial[1])), trial[2]])
			faults += 1
	var chasing := targets.y + 2.0
	print("from %.2f the next up is %s, %.2f away"
		% [chasing, _name(int(Medal.next_up(chasing, targets)[0])),
			Medal.next_up(chasing, targets)[1]])

	# A track that offers only some of them is walked past, not stalled on.
	var sparse := Vector3(30.0, 0.0, 50.0)
	if Medal.earned(40.0, sparse) != Medal.BRONZE:
		print("  a track with no silver did not fall through to bronze")
		faults += 1
	var up_sparse: Array = Medal.next_up(40.0, sparse)
	if up_sparse[0] != Medal.GOLD:
		print("  a track with no silver did not skip over it to gold")
		faults += 1
	print("with no silver on offer, 40.00 is %s and aims at %s"
		% [_name(Medal.earned(40.0, sparse)), _name(int(up_sparse[0]))])

	# And a track with no targets has no medals rather than every medal.
	if Medal.earned(1.0, Vector3.ZERO) != Medal.NONE:
		print("  a track with no targets handed out a medal anyway")
		faults += 1

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


func _name(medal: int) -> String:
	return Medal.label(medal) if medal != Medal.NONE else "nothing"
