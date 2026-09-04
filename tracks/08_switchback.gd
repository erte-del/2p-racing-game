extends TrackDefinition

# Four hairpins, and short straights between them.
#
# One hairpin is a braking point. Four in a row is a rhythm, and the thing
# that costs time is not any of them but the fifty metres in between, where
# there is exactly enough road to get back to speed and no more. Arriving at
# the next one too fast loses more than lifting early for it, and the whole
# track is spent finding out where that line is.


func describe() -> void:
	track_name = "Switchback"
	blurb = "Four hairpins, and not much road between them."
	medals(53.0, 59.0, 66.0)

	straight(70.0)

	# A long fast opening, so there is something to lose before the first one.
	corner(-42.0, 52.0)
	straight(50.0)
	pad(0.0)
	straight(58.0)
	corner(56.0, 40.0)
	corner(-52.0, 38.0)
	straight(46.0)
	barrier(-1.0, -0.32)
	straight(56.0)

	# First. The widest of the four, and the only one with a straight both
	# sides of it long enough to make a mess of and recover from.
	width(6.2)
	corner(-152.0, 20.0)
	width(8.0)
	straight(62.0)

	# Second, the other way, with a row on the way in - so the braking point
	# and the last chance to move across the road are the same moment.
	barrier(0.3, 1.0)
	straight(44.0)
	width(6.0)
	corner(150.0, 18.0)
	width(8.0)
	straight(54.0)

	# Third, downhill into it, which is the one thing that makes a hairpin
	# genuinely hard: the car arrives at the braking point already going
	# faster than it thought it was.
	climb(46.0, -4.2)
	width(5.8)
	corner(-156.0, 17.0)
	width(8.0)
	straight(48.0)

	# A breath: the fork, on the flat, and the only stretch on this track
	# where the road is doing one thing for long enough to think about it.
	fork(-1.0, 54.0)
	straight(20.0)
	barrier(-1.0, -0.58)
	straight(18.0)
	barrier(-0.55, -0.07)
	straight(16.0)
	straight(46.0)

	# Fourth, and tightest, coming back uphill.
	climb(44.0, 4.2)
	width(5.6)
	corner(158.0, 16.0)
	width(8.0)
	straight(58.0)

	# Out of the last one and straight at the ramp. The run up is the longest
	# stretch on the track, which after four hairpins reads as an invitation.
	corner(-50.0, 44.0)
	straight(70.0)
	jump()

	corner(38.0, 48.0)
	straight(80.0)
