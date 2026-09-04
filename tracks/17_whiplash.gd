extends TrackDefinition

# Everything arrives out of somewhere the car could not see.
#
# Leap of Faith put a corner and a row after two of its landings, at the far
# end of a ninety metre run out. This track shortens that run: the corner is
# there as soon as the wheels are, the crests are steep enough to hide what is
# behind them, and both hairpins are met over one. There is no piece here that
# has not been driven twenty times already. What is new is that none of them
# announce themselves.


func describe() -> void:
	track_name = "Whiplash"
	blurb = "Nothing new on it. You just cannot see any of it coming."
	medals(62.0, 69.0, 78.0)

	straight(70.0)

	# One honest corner and the pad, to set up a ramp met at full speed.
	corner(-46.0, 48.0)
	straight(40.0)
	pad(0.0)
	straight(58.0)
	jump()

	# The first landing. A row as early as the rules will allow one, and then
	# a corner immediately after it: a car that flew long meets both at once.
	straight(20.0)
	barrier(-1.0, -0.32)
	straight(38.0)
	width(6.2)
	corner(-108.0, 21.0)
	width(8.0)
	straight(46.0)

	# A crest with a corner hidden behind it. The climb is short and steep for
	# its length, which is what makes it a crest rather than a hill.
	climb(40.0, 4.6)
	corner(76.0, 30.0)
	straight(36.0)

	# And another, the other way, straight after.
	climb(38.0, -4.6)
	corner(-82.0, 28.0)
	straight(44.0)

	# First hairpin, over a crest. The braking point is on the far side of the
	# rise, which means it is found by memory or not at all.
	climb(40.0, 4.4)
	width(5.8)
	corner(148.0, 18.0)
	width(8.0)
	straight(50.0)

	# The fork on the high ground, four rows, taken downhill.
	climb(42.0, -4.4)
	fork(-1.0, 94.0)
	straight(20.0)
	barrier(-1.0, -0.58)
	straight(18.0)
	barrier(-0.55, -0.07)
	straight(18.0)
	barrier(-1.0, -0.58)
	straight(18.0)
	barrier(-0.55, -0.07)
	straight(20.0)

	# The second ramp, met straight out of the fork with no run up worth the
	# name - so how far the car flies is decided by which lane it took.
	straight(46.0)
	jump()

	# Second landing, into an esse that starts at once.
	straight(20.0)
	corner(64.0, 32.0)
	corner(-58.0, 30.0)
	straight(42.0)

	# A slalom, four rows, on the only stretch of level road left.
	barrier(0.28, 1.0)
	straight(24.0)
	barrier(-1.0, -0.28)
	straight(24.0)
	barrier(0.28, 1.0)
	straight(24.0)
	barrier(-1.0, -0.28)
	straight(50.0)

	# Second hairpin, over the last crest, with the second pad on the exit -
	# which is a gift that arrives while the car is still pointing sideways.
	climb(40.0, 4.2)
	width(5.8)
	corner(-152.0, 17.0)
	width(8.0)
	straight(36.0)
	pad(0.3)
	straight(46.0)

	# The third ramp, downhill onto a level run up, and a last corner out of
	# the landing to the line.
	climb(42.0, -4.2)
	straight(54.0)
	jump()

	straight(26.0)
	corner(44.0, 44.0)
	straight(80.0)
