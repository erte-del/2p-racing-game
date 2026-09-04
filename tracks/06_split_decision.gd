extends TrackDefinition

# Two forks, and the second one asks a harder question than the first.
#
# A fork is a trade: the boost, or the clear road. Every track so far has
# offered it once, on the level, with a straight afterwards to sort out
# whatever the choice cost. Here the first one is exactly that, so the trade
# is understood, and the second one is put where the clear lane leads
# somewhere worse - straight at a hairpin from the wrong side of the road.


func describe() -> void:
	track_name = "Split Decision"
	blurb = "Take the boost, or take the room. Twice, and the second one bites."
	medals(52.0, 58.0, 64.0)

	straight(70.0)

	# An honest opening: two sweepers and a pad, to arrive at the first fork
	# with speed already up.
	corner(-54.0, 46.0)
	straight(38.0)
	pad(-0.3)
	straight(50.0)
	corner(62.0, 42.0)
	straight(44.0)

	# The first fork. Right lane, two rows, straight road out of it. This one
	# is the offer stated plainly.
	fork(1.0, 54.0)
	straight(20.0)
	barrier(0.58, 1.0)
	straight(18.0)
	barrier(0.07, 0.55)
	straight(16.0)
	straight(50.0)

	# A long left, then a rise into a right, to put some road between the two
	# set pieces and stop them reading as one.
	corner(-88.0, 34.0)
	straight(40.0)
	climb(48.0, 4.0)
	corner(76.0, 30.0)
	straight(46.0)

	# A row on its own, on the fast approach, to make the point that this
	# stretch is not the quiet one.
	barrier(-1.0, -0.34)
	straight(56.0)

	# The second fork. Left lane again, but longer, with three rows in it,
	# and the road it opens onto is a hairpin the wrong way round: the fast
	# lane spits the car out on the inside of it, the clear lane on the
	# outside. The boost costs a corner, and the corner costs the boost.
	fork(-1.0, 74.0)
	straight(20.0)
	barrier(-1.0, -0.58)
	straight(18.0)
	barrier(-0.55, -0.07)
	straight(18.0)
	barrier(-1.0, -0.58)
	straight(18.0)

	width(5.8)
	corner(140.0, 18.0)
	width(8.0)
	straight(52.0)

	# An esse to gather it all back up, with a row on the exit of the second
	# corner where the car is still straightening.
	corner(-60.0, 34.0)
	corner(56.0, 32.0)
	straight(44.0)
	barrier(0.34, 1.0)
	straight(50.0)

	# Downhill, and a last tight left before the run at the jump.
	climb(46.0, -4.0)
	corner(-104.0, 22.0)
	straight(64.0)
	jump()

	corner(40.0, 44.0)
	straight(80.0)
