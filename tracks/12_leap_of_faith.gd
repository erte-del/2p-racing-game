extends TrackDefinition

# Three jumps, and none of them land on an empty road.
#
# A jump has been a reward so far: the longest straight on the track, nothing
# on it, and a landing that runs on for ninety metres with nothing to do. The
# ramp is the same ramp here - it is the only one the game has, and a player
# who has cleared one knows exactly what it asks - but what is waiting at the
# far end is not nothing. A corner arrives out of the first landing, a row out
# of the second, and the third is taken with the road already falling away.


func describe() -> void:
	track_name = "Leap of Faith"
	blurb = "Three ramps. What matters is where you come down."
	medals(61.0, 68.0, 76.0)

	straight(70.0)

	# A fast opening with the pad on it, so the first ramp is met at the top
	# of what the car has.
	corner(-44.0, 50.0)
	straight(40.0)
	pad(0.0)
	straight(64.0)
	jump()

	# Out of the landing straight into a left. The landing is long, so where
	# the car comes down decides how much of it is left to brake in: a jump
	# taken flat out is a corner entered at speed with no road in hand.
	straight(20.0)
	width(6.2)
	corner(-104.0, 22.0)
	width(8.0)
	straight(56.0)

	# A climbing esse to get the height back and set up the second ramp.
	climb(48.0, 4.4)
	corner(66.0, 38.0)
	corner(-60.0, 36.0)
	straight(58.0)
	jump()

	# And a row on the road out of it, far enough past the landing to be
	# legal and near enough to be met before the car has settled.
	straight(24.0)
	barrier(0.32, 1.0)
	straight(46.0)

	# Down off the high ground into the fork, three rows in the fast lane.
	climb(48.0, -4.4)
	fork(1.0, 74.0)
	straight(20.0)
	barrier(0.58, 1.0)
	straight(18.0)
	barrier(0.07, 0.55)
	straight(18.0)
	barrier(0.58, 1.0)
	straight(18.0)

	# A hairpin, and the second pad on the way out of it, because the third
	# ramp wants to be met fast and there is not much road left to do it in.
	width(5.8)
	corner(-150.0, 18.0)
	width(8.0)
	straight(38.0)
	pad(-0.35)
	straight(50.0)

	# A last esse before the third ramp, so the run up has to be found rather
	# than simply followed.
	corner(62.0, 36.0)
	corner(-58.0, 34.0)
	straight(48.0)
	barrier(-1.0, -0.3)
	straight(44.0)

	# The third, over a crest: the road climbs to the ramp and levels off just
	# before it, so the lip is met blind and the car is already light.
	climb(46.0, 4.0)
	straight(50.0)
	jump()

	# Out of the last landing, tightening, to the line.
	straight(26.0)
	corner(58.0, 34.0)
	straight(80.0)
