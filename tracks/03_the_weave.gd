extends TrackDefinition

# Esses, and the first track that is mostly one idea.
#
# A sweeper is a corner you hold. An esse is two corners you cannot hold the
# same way, because the exit of the first is the entry of the second and
# there is no straight in between to fix a bad one on. Everything on this
# track is placed to make that matter: the barriers stand on the exits, so
# coming out of a bend badly means arriving at one badly as well.


func describe() -> void:
	track_name = "The Weave"
	blurb = "Corner into corner, and no room to sort it out."
	medals(38.0, 42.0, 46.0)

	straight(70.0)

	# Opening esse. Wide enough to be an introduction rather than a test, and
	# the last time on this track two corners will have anything between them.
	corner(52.0, 42.0)
	straight(28.0)
	corner(-58.0, 38.0)
	straight(50.0)

	# The pad, on open road and dead centre, because what follows it is where
	# the track starts asking questions and the speed should be free.
	pad(0.0)
	straight(55.0)

	# The weave itself: four corners, joined. The road narrows through them,
	# which is what stops the whole thing being taken in a straight line
	# across the kerbs.
	width(6.6)
	corner(-64.0, 30.0)
	corner(70.0, 28.0)
	corner(-66.0, 30.0)
	corner(58.0, 32.0)
	width(8.0)
	straight(48.0)

	# Out of the weave onto a straight with two rows on it, swapping sides.
	# The gaps overlap in the middle of the road, so the line through both is
	# one gentle move rather than two, for anyone who looks far enough ahead.
	barrier(-1.0, -0.28)
	straight(38.0)
	barrier(0.3, 1.0)
	straight(52.0)

	# A climb into a left that arrives over the crest.
	climb(48.0, 3.6)
	corner(-78.0, 34.0)
	straight(36.0)

	# The fork, left lane, with the rows staggered the hard way round: the
	# first is against the outer kerb, so the boost has to be picked up while
	# already moving off the line the pad is on.
	fork(-1.0, 54.0)
	straight(20.0)
	barrier(-1.0, -0.58)
	straight(18.0)
	barrier(-0.55, -0.07)
	straight(16.0)

	# Downhill esse out of the fork, tightening.
	climb(46.0, -3.6)
	corner(74.0, 26.0)
	corner(-80.0, 22.0)
	straight(58.0)

	# The jump, off the one long straight left on the track.
	straight(60.0)
	jump()

	corner(44.0, 40.0)
	straight(80.0)
