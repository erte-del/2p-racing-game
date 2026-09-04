extends TrackDefinition

# The narrowest road the game builds, and rows standing on it.
#
# Needle went down to four and a half metres of half-width and kept the
# barriers mostly off the thin parts. This one goes to four point two, which
# is the narrowest the generator ever rolls - eight and a half metres of road,
# and the gap a row has to leave is three and a half of them - and puts rows,
# hairpins and a slalom on it. Nothing about the gap has changed since the
# first track. What has changed is that here the gap is the whole road, and
# the kerb is close enough on both sides that a car crossing from one to the
# next has nowhere to be wrong in.


func describe() -> void:
	track_name = "Bottleneck"
	blurb = "The narrowest road in the game, with barriers on it."
	medals(54.0, 62.0, 70.0)

	straight(70.0)

	# Wide, fast and open, for exactly one corner and one pad. This is the
	# last of it.
	corner(50.0, 48.0)
	straight(38.0)
	pad(0.0)
	straight(58.0)

	# Six metres of half-width, through an esse, to set the expectation.
	width(6.0)
	corner(-72.0, 34.0)
	corner(66.0, 32.0)
	straight(46.0)
	barrier(-1.0, -0.34)
	straight(48.0)

	# Down to four and a half, and a hairpin at it.
	width(4.6)
	corner(-140.0, 19.0)
	straight(52.0)

	# Two rows on that road, alternating. The gaps still overlap in the middle,
	# so the line through both is one move - but the move is the whole width
	# of the road and there is a wall at each end of it.
	barrier(0.36, 1.0)
	straight(34.0)
	barrier(-1.0, -0.36)
	straight(50.0)

	# Four point two: the narrowest road the game builds anywhere, generated
	# or written down. Climbing, and turning while it does.
	width(4.2)
	climb(46.0, 4.4)
	corner(88.0, 26.0)
	straight(42.0)

	# The slalom, three rows, each taking exactly half the road. On this width
	# half the road is four metres, which is the gap every row in the game
	# leaves and not a centimetre more.
	barrier(-1.0, 0.0)
	straight(32.0)
	barrier(0.0, 1.0)
	straight(32.0)
	barrier(-1.0, 0.0)
	straight(52.0)

	# A tight left, still at four, still climbing away from the last one.
	corner(-104.0, 22.0)
	straight(44.0)

	# The road opens for the fork - it has to, since a fork on this width is
	# two lanes neither of which a car fits down - and shuts again after it.
	width(8.0)
	climb(44.0, -4.4)
	straight(40.0)
	fork(1.0, 74.0)
	straight(20.0)
	barrier(0.58, 1.0)
	straight(18.0)
	barrier(0.07, 0.55)
	straight(18.0)
	barrier(0.58, 1.0)
	straight(18.0)

	# Back to four and a half for the last stretch: two joined corners, a row,
	# and the second hairpin of the track.
	width(4.6)
	straight(38.0)
	corner(-76.0, 28.0)
	corner(70.0, 26.0)
	straight(44.0)
	barrier(-1.0, -0.34)
	straight(48.0)
	corner(144.0, 19.0)
	straight(40.0)
	pad(-0.3)
	straight(50.0)

	# Wide for the ramp, and wide to the line.
	width(8.0)
	straight(64.0)
	jump()

	straight(26.0)
	corner(-42.0, 46.0)
	straight(80.0)
