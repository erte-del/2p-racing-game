extends TrackDefinition

# Height, and two jumps.
#
# The road has been broadly flat so far: a climb here and there to hide a
# corner behind, and one jump at the end where there was room for it. This
# track spends its whole length going up and down, and both jumps are taken
# on a road that is doing something else at the time - the first out of a
# fall, the second onto a rise. What lands where stops being obvious.


func describe() -> void:
	track_name = "Overpass"
	blurb = "Up, over, and down the other side. Twice."
	medals(50.0, 56.0, 62.0)

	straight(70.0)

	# Straight up out of the grid, into a right taken on the flat at the top.
	climb(52.0, 4.5)
	corner(58.0, 44.0)
	straight(34.0)

	# Falling left, with the pad on the way down, where the car is already
	# fast and the boost is worth the most.
	climb(48.0, -4.5)
	pad(0.4)
	straight(40.0)
	corner(-70.0, 36.0)

	# First jump, off the bottom of the drop. Nothing on the run up, because
	# what is being asked is only whether the ramp is met square.
	straight(52.0)
	jump()

	# Straight from the landing into the climb, so the whole of the flat run
	# out is spent gaining height rather than resting.
	climb(50.0, 4.8)
	corner(-64.0, 32.0)
	straight(40.0)

	# Barriers on the high ground, seen against the sky.
	barrier(-1.0, -0.3)
	straight(38.0)
	barrier(0.28, 1.0)
	straight(40.0)

	# Off the plateau, tightening as it drops.
	climb(48.0, -4.8)
	corner(96.0, 26.0)
	straight(40.0)

	# The fork on the level, left lane, two rows in it.
	fork(-1.0, 54.0)
	straight(20.0)
	barrier(-1.0, -0.58)
	straight(18.0)
	barrier(-0.55, -0.07)
	straight(16.0)

	# A hairpin at the bottom of the track, then the climb back up to the
	# second jump - which is taken uphill, and so lands short of where the
	# first one taught it would.
	width(6.0)
	corner(-132.0, 19.0)
	width(8.0)
	straight(36.0)
	climb(50.0, 4.2)
	straight(48.0)
	jump()

	corner(46.0, 42.0)
	straight(80.0)
