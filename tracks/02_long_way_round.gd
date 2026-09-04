extends TrackDefinition

# The second track, and the first one that asks for anything.
#
# First Light showed the pieces one at a time on open road. This one puts
# them in each other's way: the pad sits before a corner rather than after
# one, the barriers are met carrying speed, and the jump is taken out of a
# bend instead of off a straight that had nothing else to say. Every corner
# here is still one the car can hold flat, so the only thing being asked is
# whether the player will commit to it.


func describe() -> void:
	track_name = "Long Way Round"
	blurb = "Open sweepers, taken flat if you dare."
	medals(43.0, 48.0, 53.0)

	# The grid.
	straight(70.0)

	# Three sweepers in a row, none of them tight enough to brake for, each
	# turning back on the one before. The road never stops bending, which is
	# the whole lesson: speed is kept by not lifting, not by finding straights.
	corner(60.0, 52.0)
	corner(-72.0, 48.0)
	straight(35.0)

	# The pad on the exit of the second, aimed into the third. A boost that
	# runs out on a straight is a gift; one that runs out mid corner has to
	# be steered.
	pad(0.3)
	straight(45.0)
	corner(58.0, 44.0)
	straight(60.0)

	# The first pair of barriers, both blocking the same side. Held on one
	# side they read as one long wall to go round, which is the gentle way to
	# meet two of them.
	barrier(0.25, 1.0)
	straight(34.0)
	barrier(0.3, 1.0)
	straight(56.0)

	# A long left with a rise through the middle of it, so the exit is not
	# visible from the entry.
	climb(50.0, 3.0)
	corner(-84.0, 40.0)
	straight(40.0)

	# The fork, on the right this time. Two rows inside the fast lane, one
	# against the outer kerb and one against the divider, so the fast way
	# through is a swap across a lane half as wide as the road.
	fork(1.0, 56.0)
	straight(22.0)
	barrier(0.58, 1.0)
	straight(18.0)
	barrier(0.07, 0.55)
	straight(16.0)

	# Out of the fork, down the hill and into the only corner on the track
	# worth braking for.
	climb(45.0, -3.0)
	corner(-96.0, 24.0)
	straight(50.0)

	# The run at the jump comes out of a bend, so the car arrives at the ramp
	# already having spent its attention on something else.
	corner(46.0, 42.0)
	straight(62.0)
	jump()

	# And a last sweeper onto the run to the line.
	corner(38.0, 50.0)
	straight(85.0)
