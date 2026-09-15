extends TrackDefinition

# Corners that tighten after they have been committed to.
#
# Every corner so far has held one radius from entry to exit, so the speed it
# could be taken at was decided at the moment it came into view. A hook is two
# corners the same way round with nothing between them, the second half the
# radius of the first: it opens like a sweeper, and by the time the car is in
# the part that matters the entry speed is already spent. There are five of
# them here, and the only defence is to give up the first half of each.


func describe() -> void:
	track_name = "The Hook"
	blurb = "Corners that shut on you halfway round."
	medals(49.0, 55.0, 62.0)

	straight(70.0)

	# The first hook, and the gentlest: fifty metres of radius into twenty-six,
	# which is still a corner the car can nearly hold.
	corner(50.0, 50.0)
	corner(64.0, 26.0)
	straight(56.0)

	# The pad, on the road out of it, as payment for having got that right.
	pad(0.3)
	straight(50.0)

	# The second, left, tighter at both ends.
	corner(-46.0, 40.0)
	width(6.4)
	corner(-88.0, 19.0)
	width(8.0)
	straight(60.0)

	# A pair of rows to break the pattern up, so the third hook is not simply
	# expected.
	barrier(0.3, 1.0)
	straight(42.0)
	barrier(-1.0, -0.3)
	straight(54.0)

	# The third, downhill, which is the worst place to find out a corner is
	# tighter than it looked.
	climb(50.0, -4.4)
	corner(54.0, 44.0)
	width(6.0)
	corner(72.0, 17.0)
	width(8.0)
	straight(58.0)

	# The fork, on the flat, three rows in the fast lane.
	fork(-1.0, 74.0)
	straight(20.0)
	barrier(-1.0, -0.58)
	straight(18.0)
	barrier(-0.55, -0.07)
	straight(18.0)
	barrier(-1.0, -0.58)
	straight(18.0)

	# Back uphill, and the fourth at the top: the tightest exit on the track,
	# on the narrowest road it is driven on.
	climb(48.0, 4.4)
	straight(44.0)
	corner(-42.0, 46.0)
	width(5.6)
	corner(-96.0, 15.0)
	width(8.0)
	straight(56.0)

	# A slalom on the way down, three rows, to spend what the hooks left.
	climb(46.0, -4.4)
	barrier(-1.0, 0.28)
	straight(26.0)
	barrier(-0.28, 1.0)
	straight(26.0)
	barrier(-1.0, 0.28)
	straight(50.0)

	# One more hook, right, and the fastest entry of the five.
	corner(44.0, 50.0)
	width(6.0)
	corner(84.0, 18.0)
	width(8.0)
	straight(54.0)

	# The run at the jump, and the one honest corner on the track to set it up.
	corner(-48.0, 44.0)
	straight(66.0)
	jump()

	straight(30.0)
	corner(-40.0, 44.0)
	straight(80.0)
