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

	for trial: Array in [
		[38.0, Medal.GOLD], [39.99, Medal.GOLD],
		# On the target is not under it. A medal for exactly forty seconds
		# would make the number on the screen a lie in one direction or the
		# other, and under is the one a player can act on.
		[40.0, Medal.SILVER], [44.99, Medal.SILVER],
		[45.0, Medal.BRONZE], [49.99, Medal.BRONZE],
		[50.0, Medal.NONE], [61.0, Medal.NONE],
		[-1.0, Medal.NONE],
	]:
		var got: int = Medal.earned(trial[0], targets)
		if got != trial[1]:
			print("  %.2f earned %s, not %s"
				% [trial[0], _name(got), _name(int(trial[1]))])
			faults += 1
	print("40.00 is %s and 39.99 is %s, so a target is a time to get under"
		% [_name(Medal.earned(40.0, targets)), _name(Medal.earned(39.99, targets))])

	# What a player is driving at next.
	for trial: Array in [
		[47.0, Medal.SILVER, 2.0], [42.0, Medal.GOLD, 2.0],
		[38.0, Medal.NONE, 0.0], [55.0, Medal.BRONZE, 5.0],
	]:
		var up: Array = Medal.next_up(trial[0], targets)
		if up[0] != trial[1] or not is_equal_approx(up[1], trial[2]):
			print("  from %.2f the next up came out as %s by %.2f, not %s by %.2f"
				% [trial[0], _name(int(up[0])), up[1], _name(int(trial[1])), trial[2]])
			faults += 1
	print("from 47.00 the next up is %s, %.2f away"
		% [_name(int(Medal.next_up(47.0, targets)[0])), Medal.next_up(47.0, targets)[1]])

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
