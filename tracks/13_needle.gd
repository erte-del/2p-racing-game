extends TrackDefinition

# The thinnest road in the game, and everything placed to use the width that
# is left.
#
# Pinch narrowed the road and then largely left it alone: the corners on it
# were open, and the barriers stayed on the wide parts. Here the road is
# narrow through the corners as well, and the rows stand on it - which they
# can, because a row only ever has to leave three and a half metres open, and
# on a road eight and a half metres wide that is nearly all of it. The gap is
# the same gap it always was. There is simply nothing either side of it.


func describe() -> void:
	track_name = "Needle"
	blurb = "The gap is the size it always was. The road is not."
	medals(56.0, 62.0, 69.0)

	straight(70.0)

	# Wide to begin with, and quick, so the first narrowing is felt as one.
	corner(46.0, 50.0)
	straight(40.0)
	pad(0.0)
	straight(58.0)

	# Down to five metres, through an esse. From here to the fork the road
	# does not open again.
	width(5.0)
	corner(-70.0, 32.0)
	corner(64.0, 30.0)
	straight(50.0)

	# The first row on the thin road. It blocks a third of it and leaves the
	# same three and a half metres as every row on every track.
	barrier(-1.0, -0.32)
	straight(44.0)
	barrier(0.34, 1.0)
	straight(52.0)

	# Thinner still, and climbing, into a corner over the crest.
	width(4.4)
	climb(48.0, 4.2)
	corner(-84.0, 28.0)
	straight(46.0)

	# Two rows at four and a half metres of half-width, which is as close as
	# this game comes to threading a needle: the gap is most of the road, and
	# the road is two cars.
	barrier(0.4, 1.0)
	straight(40.0)
	barrier(-1.0, -0.4)
	straight(48.0)

	# A tight left, still thin, still falling.
	climb(46.0, -4.2)
	corner(-112.0, 20.0)
	straight(54.0)

	# The road opens for the fork, and closes again the moment it is over.
	width(8.0)
	straight(44.0)
	fork(-1.0, 74.0)
	straight(20.0)
	barrier(-1.0, -0.58)
	straight(18.0)
	barrier(-0.55, -0.07)
	straight(18.0)
	barrier(-1.0, -0.58)
	straight(18.0)

	# The last thin stretch, and the longest: an esse, a hairpin and a row,
	# with no wide road anywhere in it.
	width(4.6)
	straight(40.0)
	corner(58.0, 32.0)
	corner(-54.0, 30.0)
	straight(46.0)
	barrier(0.36, 1.0)
	straight(50.0)
	corner(136.0, 19.0)
	straight(52.0)

	# And a slalom on it, which is the whole track in one place: three rows
	# alternating across a road that has no room to alternate across.
	barrier(-1.0, 0.2)
	straight(30.0)
	barrier(-0.2, 1.0)
	straight(30.0)
	barrier(-1.0, 0.2)
	straight(56.0)

	# One more thin corner, and the second pad on the exit of it.
	corner(-96.0, 24.0)
	straight(36.0)
	pad(-0.3)
	straight(48.0)

	# Wide again for the ramp, because a jump taken off a thin road is a jump
	# taken by whoever happened to be pointing the right way.
	width(8.0)
	straight(64.0)
	jump()

	straight(26.0)
	corner(-44.0, 44.0)
	straight(80.0)
