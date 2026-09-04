extends TrackDefinition

# Barriers, in numbers, and the first track where they are a sequence rather
# than a series of separate decisions.
#
# Every row up to now has left most of the road open, so the way past one has
# been most of the way past the next. The rows here overlap each other: the
# gap through one is on the far side of the road from the gap through the one
# after it, and the road between them is only just enough to get across. A
# single row read late is recoverable. A slalom read late is not.


func describe() -> void:
	track_name = "The Gauntlet"
	blurb = "Five rows, alternating sides, and just enough road between them."
	medals(52.0, 59.0, 66.0)

	straight(70.0)

	# A fast open corner and the pad, so the slalom is arrived at with more
	# speed than is comfortable in it.
	corner(50.0, 48.0)
	straight(40.0)
	pad(-0.4)
	straight(56.0)

	# The gauntlet. Five rows, each blocking the road up to a third of the way
	# past the middle, so the gap through one sits on the opposite kerb to the
	# gap through the next and the car crosses the full width between every
	# pair. Twenty-four metres apart, which is a little over what the arithmetic
	# says is reachable and a good deal less than it takes to be casual about.
	barrier(-1.0, 0.3)
	straight(24.0)
	barrier(-0.3, 1.0)
	straight(24.0)
	barrier(-1.0, 0.3)
	straight(24.0)
	barrier(-0.3, 1.0)
	straight(24.0)
	barrier(-1.0, 0.3)
	straight(56.0)

	# Out the far end into a left that has to be entered from wherever the
	# last row left the car, which is the outside of it.
	corner(-92.0, 28.0)
	straight(44.0)

	# A climb, and a pair of rows on the crest where they are seen late.
	climb(48.0, 4.2)
	barrier(0.28, 1.0)
	straight(38.0)
	barrier(-1.0, -0.28)
	straight(48.0)

	# An esse on the high ground, wide open and empty, because after eight
	# rows the road owes the player somewhere to look up.
	corner(66.0, 40.0)
	corner(-62.0, 38.0)
	straight(46.0)
	climb(46.0, -4.2)
	corner(74.0, 34.0)
	straight(50.0)

	# The fork, with three rows in the fast lane instead of two - the same
	# idea as the gauntlet, in half the width.
	fork(1.0, 74.0)
	straight(20.0)
	barrier(0.58, 1.0)
	straight(18.0)
	barrier(0.07, 0.55)
	straight(18.0)
	barrier(0.58, 1.0)
	straight(18.0)

	# Into a hairpin, and a row on the exit of it: the one place on the track
	# where a barrier is met while still turning.
	width(6.0)
	corner(-144.0, 19.0)
	width(8.0)
	straight(50.0)
	barrier(0.32, 1.0)
	straight(56.0)

	# The jump, and a clear run to the line.
	straight(58.0)
	jump()

	corner(42.0, 46.0)
	straight(80.0)
