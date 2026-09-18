extends TrackDefinition

# Long, and tight the whole way.
#
# Long Haul was long and easy metre for metre; Relentless was hard and no
# longer than it had to be. This is both. Six hairpins, nine corners under
# twenty-five metres of radius, a mile and a quarter of road, and the pads
# placed where they make the next corner worse rather than the last one
# better. What it grinds down is not skill. It is attention.


func describe() -> void:
	track_name = "Grinder"
	blurb = "A mile and a quarter, and none of it is a rest."
	medals(56.0, 62.0, 71.0)

	straight(70.0)

	# Straight into the first hairpin. No opening sweeper, no run to settle
	# into: the first thing this track asks is a full stop.
	straight(56.0)
	width(6.0)
	corner(-146.0, 19.0)
	width(8.0)
	straight(50.0)

	# A pad on the exit, aimed at the second hairpin. The boost is worth about
	# a second and costs about two if it is still on the car at the braking
	# point, which is the joke the whole track is built on.
	pad(0.0)
	straight(56.0)
	width(6.0)
	corner(140.0, 18.0)
	width(8.0)
	straight(44.0)

	# An esse, tight, with a trap on the exit of it - a quick one, so where it
	# is has to be read on the way out of the second corner rather than from
	# the straight.
	width(6.4)
	corner(-84.0, 24.0)
	corner(78.0, 22.0)
	width(8.0)
	straight(40.0)
	trap(-0.7, 0.7, 0.6, 1.2, 0.9)
	straight(52.0)

	# Third hairpin, uphill into it.
	climb(46.0, 4.4)
	width(5.8)
	corner(-152.0, 17.0)
	width(8.0)
	straight(48.0)

	# A slalom on the high ground, four rows at twenty-four metres.
	barrier(-1.0, 0.28)
	straight(24.0)
	barrier(-0.28, 1.0)
	straight(24.0)
	barrier(-1.0, 0.28)
	straight(24.0)
	barrier(-0.28, 1.0)
	straight(52.0)

	# Fourth hairpin, and the road falls away through the exit of it, which is
	# where a car that got the entry right loses it anyway.
	width(6.0)
	corner(144.0, 19.0)
	width(8.0)
	climb(46.0, -4.4)
	straight(44.0)

	# The fork, with four rows in the fast lane - the most any lane in the
	# game carries.
	fork(1.0, 94.0)
	straight(20.0)
	barrier(0.58, 1.0)
	straight(18.0)
	barrier(0.07, 0.55)
	straight(18.0)
	barrier(0.58, 1.0)
	straight(18.0)
	barrier(0.07, 0.55)
	straight(20.0)

	# Fifth, straight out of the fork, taken from whichever side of the road
	# the lane left the car on.
	width(5.8)
	corner(-150.0, 17.0)
	width(8.0)
	straight(46.0)

	# A pair of tight corners joined, then the second pad, then the sixth
	# hairpin - which is to say, the same trick as the first pad, at the point
	# in the lap where it is least likely to be remembered.
	width(6.2)
	corner(88.0, 22.0)
	corner(-80.0, 24.0)
	width(8.0)
	straight(38.0)
	pad(-0.3)
	straight(50.0)
	width(6.0)
	corner(138.0, 18.0)
	width(8.0)
	straight(52.0)

	# The jump, and the first clear road since the grid.
	corner(-46.0, 46.0)
	straight(66.0)
	jump()

	straight(26.0)
	corner(42.0, 46.0)
	straight(80.0)
