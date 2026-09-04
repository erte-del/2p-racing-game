extends TrackDefinition

# The first track that has to be braked for.
#
# Everything up to here can be driven flat out by someone willing to hold the
# throttle down, because nothing on it turns tighter than the car turns at
# top speed. This one has three corners the car simply cannot hold at speed,
# and they are spaced so that each one arrives out of a stretch that wanted
# to be taken fast. Learning where to lift is the track.


func describe() -> void:
	track_name = "Cold Start"
	blurb = "Three corners the throttle cannot argue with."
	medals(38.0, 42.0, 48.0)

	straight(70.0)

	# A fast opening, so the first braking point comes at the end of the
	# quickest stretch on the track rather than while still finding fourth.
	corner(-46.0, 50.0)
	straight(70.0)
	pad(-0.35)
	straight(55.0)

	# First hairpin. Twenty metres is wide for a hairpin and still far tighter
	# than the car holds at speed, so this is the one that teaches the lesson
	# rather than the one that punishes not knowing it.
	width(6.0)
	corner(-150.0, 20.0)
	width(8.0)
	straight(64.0)

	# Two rows on the way out, on opposite sides and far enough apart to be
	# taken one at a time.
	barrier(-1.0, -0.32)
	straight(42.0)
	barrier(0.32, 1.0)
	straight(56.0)

	# A rising right onto a plateau, then the second tight one at the top of
	# it, met over the crest.
	climb(52.0, 4.0)
	corner(62.0, 38.0)
	straight(44.0)
	width(6.2)
	corner(108.0, 17.0)
	width(8.0)
	straight(50.0)

	# Downhill run to the fork, so the fast lane is entered with more speed
	# than the rows in it really want.
	climb(50.0, -4.0)
	fork(1.0, 58.0)
	straight(22.0)
	barrier(0.56, 1.0)
	straight(18.0)
	barrier(0.07, 0.52)
	straight(18.0)

	# Third and tightest. Straight out of the fork, which is exactly where
	# nobody is looking for it.
	width(5.8)
	corner(-138.0, 16.0)
	width(8.0)
	straight(46.0)

	# A last sweeper to gather speed, and the jump off the end of it.
	corner(54.0, 44.0)
	straight(66.0)
	jump()

	corner(-42.0, 46.0)
	straight(80.0)
