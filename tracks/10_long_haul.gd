extends TrackDefinition

# The longest track so far, and deliberately not the hardest metre for metre.
#
# Halfway through the twenty, and what is being asked here is stamina rather
# than any one skill. Nothing on it is harder than something already met, but
# there is a great deal of it, and the mistake that ends a run is nearly
# always the one made after the point where concentration was still free.
# Two jumps, two forks, a hairpin, a slalom, and a mile of road.


func describe() -> void:
	track_name = "Long Haul"
	blurb = "Nothing new, and a very long way to keep getting it right."
	medals(65.0, 72.0, 80.0)

	straight(70.0)

	# Opening sweepers, fast and empty.
	corner(46.0, 50.0)
	straight(44.0)
	corner(-54.0, 46.0)
	straight(36.0)
	pad(0.0)
	straight(52.0)

	# First jump, early, off a clear run.
	straight(46.0)
	jump()

	# A pair of rows on the road out of the landing, far enough past it that
	# a long jump does not put the car down on top of the first one.
	straight(20.0)
	barrier(-1.0, -0.3)
	straight(40.0)
	barrier(0.3, 1.0)
	straight(52.0)

	# Climbing esse.
	climb(50.0, 4.4)
	corner(-70.0, 36.0)
	corner(64.0, 34.0)
	straight(48.0)

	# The first fork, on the high ground.
	fork(-1.0, 54.0)
	straight(20.0)
	barrier(-1.0, -0.58)
	straight(18.0)
	barrier(-0.55, -0.07)
	straight(16.0)
	straight(44.0)

	# Down off the plateau into a hairpin, turning back the way the track came.
	climb(48.0, -4.4)
	width(6.0)
	corner(-148.0, 19.0)
	width(8.0)
	straight(48.0)

	# A short slalom, three rows, the same alternating pattern as the Gauntlet
	# but with a little more room between them.
	barrier(-1.0, 0.28)
	straight(26.0)
	barrier(-0.28, 1.0)
	straight(26.0)
	barrier(-1.0, 0.28)
	straight(46.0)

	# A long open right, then the second pad on the exit of it.
	corner(84.0, 40.0)
	straight(30.0)
	pad(0.35)
	straight(46.0)

	# The second fork, right lane, on a road that is already fast.
	fork(1.0, 54.0)
	straight(20.0)
	barrier(0.58, 1.0)
	straight(18.0)
	barrier(0.07, 0.55)
	straight(16.0)

	# A tight left, a rise, and the second jump off the top of it.
	width(6.2)
	corner(-118.0, 21.0)
	width(8.0)
	straight(40.0)
	climb(50.0, 4.0)
	straight(50.0)
	jump()

	# And a last esse to the line, because a straight run in after all that
	# would be a track that stopped caring before the player did.
	corner(-48.0, 42.0)
	corner(44.0, 40.0)
	straight(80.0)
