extends TrackDefinition

# The eighth acrobatic track: never empty road.
#
# Every other track has road between its jumps to settle on. This one fills it.
# Barriers and traps come one after another the whole way round, the rings are
# close together, and the only clear road is the run up to each ramp.
#
# The two pads late on are the choice in it. A boosted car clears a platform
# altogether - it comes down past the far end, on the road beyond - so the pad
# before the platform is a way to skip the platform's timing, paid for by
# arriving flat out and dead straight with a trap and a barrier just behind. The
# pad before the last ring is free: a ring catches a boosted car. Both stand
# twenty-five metres from their ramp, as close as a pad may stand to a jump, and
# the boost is still on at the lip - 43.8 m/s there, against 30 without.
#
# What keeps it fair is the rule every row obeys: there is always a way past,
# and it can be reached from the way past the row before. Rows that swap sides
# need most of a straight between them, so the pairs that sit close together
# are on the same side, and the ones that swap are the long ones.


func describe() -> void:
	track_name = "Pinball"
	blurb = "No empty road. Barriers, traps, rings, and two pads worth thinking about."
	# For now, from tools/checks/acrobatic_drive.gd, which laps it with the keys
	# in 1:06.83 without falling, scaled as Lift Off's are. To be replaced by
	# the best a player drives.
	medals(57.5, 66.0, 73.5)

	# The grid, a pad, and two rows on the ground.
	straight(60.0)
	pad(0.0)
	straight(30.0)
	corner(70.0, 40.0)
	straight(40.0)
	barrier(-1.0, -0.15)
	straight(60.0)
	barrier(0.15, 1.0)
	straight(40.0)
	ring_jump(0.0)

	# Up onto floating road, and a trap straight into a barrier on the same
	# side as the way past it.
	corner(90.0, 30.0)
	floating()
	climb(60.0, 4.0)
	straight(30.0)
	trap(-0.6, 0.6, 0.5, 1.0, 0.8)
	straight(60.0)
	barrier(-1.0, -0.2)
	straight(40.0)
	ring_jump(0.3, 2.0, 60.0)

	# A barrier, a trap sweeping the other way, and the first pad: take it and
	# the platform after it can be flown over entirely.
	corner(90.0, 30.0)
	straight(35.0)
	barrier(0.2, 1.0)
	straight(60.0)
	trap(0.6, -0.6, 0.5, 0.9, 0.75)
	straight(45.0)
	pad(0.0)
	straight(25.0)
	platform_jump(-0.5, 0.5, 0.55, 0.7, 1.2, 0.0, 45.0)

	# A trap, a barrier, and a ring that moves.
	corner(-80.0, 32.0)
	straight(30.0)
	trap(-0.55, 0.55, 0.5, 0.9, 0.7)
	straight(60.0)
	barrier(-1.0, -0.2)
	straight(40.0)
	moving_ring_jump(-0.4, 0.4, 0.7, 1.1, 1.5)

	# Two rows swapping sides, the second pad - free speed, since a ring catches
	# a boosted car - and the drop back to the grass.
	corner(80.0, 30.0)
	straight(35.0)
	barrier(-1.0, -0.2)
	straight(60.0)
	barrier(0.2, 1.0)
	straight(40.0)
	pad(0.0)
	straight(25.0)
	ring_jump(0.0, -7.5)
	floating(false)

	# Home.
	corner(-50.0, 45.0)
	straight(60.0)
