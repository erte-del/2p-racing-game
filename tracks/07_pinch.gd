extends TrackDefinition

# Narrow road, for most of its length.
#
# Width has been used up to now as punctuation - a corner pulled in a little
# to stop it being cut. Here it is the subject. The road spends more than half
# this track at four and a half metres either side of the middle, which is
# barely two cars, and the rails are close enough that a line taken a metre
# wide is a line taken into the wall. Nothing here is tight. It is thin.


func describe() -> void:
	track_name = "Pinch"
	blurb = "The road is not short of corners. It is short of room."
	medals(52.0, 58.0, 65.0)

	straight(70.0)

	# The last wide stretch on the track, and everything that needs room is
	# on it: the pad, and two rows on opposite sides.
	corner(48.0, 48.0)
	straight(36.0)
	pad(0.0)
	straight(44.0)
	barrier(-1.0, -0.3)
	straight(40.0)
	barrier(0.3, 1.0)
	straight(50.0)

	# In it comes. The first narrow stretch is straight, so the width is felt
	# before it has to be used.
	width(5.4)
	straight(56.0)
	corner(-72.0, 38.0)
	straight(40.0)

	# Narrower again, through an esse. At this width a sweeper that could be
	# held with a metre in hand is held with none.
	width(4.6)
	corner(64.0, 34.0)
	corner(-68.0, 32.0)
	straight(48.0)

	# A climb, still thin, into a corner over the crest.
	climb(50.0, 4.4)
	corner(58.0, 30.0)
	straight(42.0)

	# The one row on the narrow road. It blocks less of it than any row on the
	# track and leaves the same three and a half metres of gap as all of them,
	# which on this width is most of the road.
	barrier(-1.0, -0.1)
	straight(46.0)

	# Falling away, and tightening while it does.
	climb(48.0, -4.4)
	corner(-96.0, 24.0)
	straight(44.0)

	# The road opens again for the fork, because a fork on a thin road is two
	# lanes neither of which can be driven.
	width(8.0)
	straight(40.0)
	fork(1.0, 54.0)
	straight(20.0)
	barrier(0.58, 1.0)
	straight(18.0)
	barrier(0.07, 0.55)
	straight(16.0)

	# And closes one last time, for a hairpin taken between two walls.
	width(5.0)
	straight(38.0)
	corner(146.0, 18.0)
	straight(46.0)

	# Wide again for the jump, since a ramp is met square or not at all.
	width(8.0)
	straight(62.0)
	jump()

	corner(44.0, 46.0)
	straight(80.0)
