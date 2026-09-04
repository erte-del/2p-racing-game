extends TrackDefinition

# The first track, and the one that has to teach the rest of them.
#
# Everything the game can put on a road appears here once, in the order a
# player can afford to meet it: a pad on open road before any pad is worth
# refusing, a barrier on a straight long enough to see it coming, the fork
# once lanes mean something, and the jump last, off the longest run up on the
# track. Nothing here is trying to be hard. It is trying to be legible.


func describe() -> void:
	track_name = "First Light"
	blurb = "Open road, one of everything, nothing hidden."
	# Forty is a clean lap that took the pad and cleared the jump; fifty is
	# getting round without falling in anything.
	medals(33.0, 38.0, 42.0)

	# The grid, and enough road to reach it in a straight line.
	straight(70.0)

	# A long right to settle into, wide open. First corner on a track should
	# be one nobody has to brake for.
	corner(55.0, 46.0)
	straight(30.0)

	# The first pad, in the middle of the road on the exit of that corner.
	# Middle, because a pad off the racing line is a decision and this one is
	# a demonstration.
	pad(0.0)
	straight(85.0)

	# Tightening left, and the road narrows into it.
	width(6.4)
	corner(-70.0, 26.0)
	width(8.0)
	straight(45.0)

	# First barrier. Blocking in from the left on a long straight, with the
	# whole right-hand side of the road open, seen from far enough back that
	# missing it is a choice.
	barrier(-1.0, -0.15)
	straight(70.0)

	# A short climb into a blind-ish right, so the corner arrives over a crest.
	climb(55.0, 3.4)
	corner(48.0, 32.0)
	straight(40.0)

	# The fork. Divider down the middle for fifty metres, fast lane on the
	# left with the pad in it, and two rows inside that lane staggered against
	# the divider and the outer kerb.
	fork(-1.0, 50.0)
	straight(20.0)
	barrier(-1.0, -0.55)
	straight(16.0)
	barrier(-0.5, -0.07)
	straight(14.0)

	# Out of the fork and straight into a hairpin, so whatever speed was
	# carried through it has to be given back.
	corner(-135.0, 15.0)
	straight(50.0)

	# Falling right, to set up the run at the jump.
	climb(60.0, -3.4)
	corner(62.0, 40.0)

	# The run up. Long, level, and empty: the only thing to decide here is
	# whether to be flat out, and the answer is yes.
	straight(80.0)
	jump()

	# The road out of the landing, and the run to the line.
	corner(-40.0, 44.0)
	straight(90.0)
