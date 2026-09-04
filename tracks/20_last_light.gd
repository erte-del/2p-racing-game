extends TrackDefinition

# The last one.
#
# Nearly three kilometres of road, seven hairpins, three ramps, twenty-two
# rows, two forks and four pads - and the thing that makes it the last track
# is none of those. It is that the set pieces are laid end to end with the
# recovery taken out from between them, so a mistake made at the first hairpin
# is still being paid for at the second, and there is nowhere on it a driver
# who has stopped concentrating gets away with it for more than fifty metres.
#
# It is meant to be finished before it is beaten. The bronze is a lap that got
# round; the gold is a lap with nothing wrong in it.


func describe() -> void:
	track_name = "Last Light"
	blurb = "Everything the road knows how to do, with the rests taken out."
	medals(90.0, 100.0, 112.0)

	# The grid, and the only stretch of this track that asks for nothing.
	straight(70.0)

	# Straight into it: joined corners, tightening, off cold tyres.
	corner(-50.0, 44.0)
	corner(64.0, 34.0)
	corner(-78.0, 24.0)
	straight(44.0)

	# First pad, and the first slalom on the boost it gives. Four rows at
	# twenty-two metres, which is the closest the game stands two of them.
	pad(0.0)
	straight(44.0)
	barrier(-1.0, 0.26)
	straight(22.0)
	barrier(-0.26, 1.0)
	straight(22.0)
	barrier(-1.0, 0.26)
	straight(22.0)
	barrier(-0.26, 1.0)
	straight(40.0)

	# First hairpin, straight out of the last row.
	width(5.8)
	corner(150.0, 18.0)
	width(8.0)
	straight(42.0)

	# Climbing into the first ramp, and a corner waiting in the landing.
	climb(42.0, 4.6)
	straight(46.0)
	jump()
	straight(20.0)
	width(6.2)
	corner(96.0, 22.0)
	width(8.0)
	straight(36.0)

	# Second hairpin, downhill into it.
	climb(42.0, -4.6)
	width(5.8)
	corner(-144.0, 18.0)
	width(8.0)
	straight(40.0)

	# The first fork, four rows in the fast lane, entered at speed.
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

	# Third hairpin, straight out of it, taken from whichever side of the road
	# the lane left the car on.
	width(5.6)
	corner(152.0, 17.0)
	width(8.0)
	straight(40.0)

	# Thin road, and two rows on it, climbing.
	width(4.6)
	climb(42.0, 4.4)
	barrier(-1.0, -0.34)
	straight(36.0)
	barrier(0.34, 1.0)
	straight(44.0)

	# A hook on the thin road: fast in, seventeen metres out.
	corner(-44.0, 40.0)
	corner(-92.0, 17.0)
	straight(42.0)

	# Wide again, second pad, and the second ramp off the back of it.
	width(8.0)
	climb(42.0, -4.4)
	pad(-0.3)
	straight(50.0)
	jump()

	# A row in the landing, then the fourth hairpin.
	straight(22.0)
	barrier(0.3, 1.0)
	straight(38.0)
	width(5.8)
	corner(-148.0, 18.0)
	width(8.0)
	straight(36.0)

	# The second slalom, four rows, on the flat.
	barrier(-1.0, 0.28)
	straight(24.0)
	barrier(-0.28, 1.0)
	straight(24.0)
	barrier(-1.0, 0.28)
	straight(24.0)
	barrier(-0.28, 1.0)
	straight(44.0)

	# Fifth hairpin, and the third pad on the exit, aimed at the second fork.
	width(5.8)
	corner(146.0, 18.0)
	width(8.0)
	straight(36.0)
	pad(0.35)
	straight(40.0)

	# The second fork, on the left, four rows, taken with the boost still on.
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

	# Sixth hairpin, climbing.
	climb(40.0, 4.2)
	width(5.6)
	corner(-154.0, 17.0)
	width(8.0)
	straight(40.0)

	# Joined corners, falling, and the last pad between them and the seventh
	# hairpin - which is the tightest corner in the game.
	climb(40.0, -4.2)
	width(6.0)
	corner(82.0, 22.0)
	corner(-88.0, 20.0)
	width(8.0)
	straight(34.0)
	pad(-0.35)
	straight(44.0)
	width(5.4)
	corner(156.0, 16.0)
	width(8.0)
	straight(46.0)

	# The last slalom, three rows, on the run to the last ramp.
	barrier(-1.0, 0.28)
	straight(24.0)
	barrier(-0.28, 1.0)
	straight(24.0)
	barrier(-1.0, 0.28)
	straight(50.0)

	# The third ramp, and the road home.
	straight(46.0)
	jump()

	straight(26.0)
	corner(-42.0, 44.0)
	straight(80.0)
