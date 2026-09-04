extends TrackDefinition

# Sixteen corners, and nowhere to put the throttle down and leave it.
#
# The Weave joined two corners together to show what that costs. This track
# does it for a mile. There are four straights on it long enough to reach top
# speed, and three of them have something standing on them; everywhere else
# the road is turning, and the exit of each corner is the entry of the next.
# Nothing here is tighter than corners already met on other tracks. There is
# simply no moment on it that is not one.


func describe() -> void:
	track_name = "Relentless"
	blurb = "Sixteen corners. Four straights. Draw your own conclusions."
	medals(53.0, 60.0, 68.0)

	straight(70.0)

	# The first of the four straights is the grid. The road starts turning
	# at seventy metres and does not stop for two hundred.
	corner(-52.0, 44.0)
	corner(58.0, 40.0)
	straight(30.0)
	corner(-64.0, 36.0)
	corner(70.0, 34.0)
	straight(28.0)
	corner(-76.0, 30.0)

	# The second straight, with the pad on it, which is the whole of the rest
	# this track offers before the fork.
	straight(44.0)
	pad(0.0)
	straight(52.0)

	# And back into it, climbing, alternating, tightening.
	climb(46.0, 4.4)
	corner(82.0, 32.0)
	corner(-88.0, 28.0)
	straight(32.0)
	corner(94.0, 26.0)

	# The third straight, on the high ground, with two rows on it swapping
	# sides - met at the one moment on the track when the car is straight.
	straight(40.0)
	barrier(-1.0, -0.3)
	straight(42.0)
	barrier(0.3, 1.0)
	straight(46.0)

	# Falling, and turning while it falls.
	climb(48.0, -4.4)
	corner(-84.0, 30.0)
	straight(30.0)
	width(6.4)
	corner(96.0, 24.0)
	width(8.0)

	# The fork, and the only stretch of properly straight road in the second
	# half of the track. Three rows in the fast lane.
	straight(38.0)
	fork(-1.0, 74.0)
	straight(20.0)
	barrier(-1.0, -0.58)
	straight(18.0)
	barrier(-0.55, -0.07)
	straight(18.0)
	barrier(-1.0, -0.58)
	straight(18.0)

	# Straight out of the fork into the tightest pair on the track, joined.
	width(6.0)
	corner(-102.0, 22.0)
	corner(88.0, 20.0)
	width(8.0)
	straight(34.0)

	# A hairpin, because after all that the track should ask for the one
	# thing it has not: a full stop and a start again.
	width(5.8)
	corner(-148.0, 18.0)
	width(8.0)
	straight(40.0)
	pad(-0.35)
	straight(48.0)

	# Two more, gentler, to get the speed back for the ramp.
	corner(60.0, 40.0)
	corner(-54.0, 44.0)

	# The fourth straight, which is the run up, and the first stretch of empty
	# road on the track since the grid.
	straight(66.0)
	jump()

	straight(26.0)
	corner(44.0, 46.0)
	straight(80.0)
