extends TrackDefinition

# The second acrobatic track: up off the ground and into the air, a jump at a
# time, and back down.
#
# The first half of it is on the ground, and it is the part Lift Off already
# taught - a barrier, a ring, a trap. Then a moving platform, and off the far
# end of it the road does not come back down: it carries on in the air, three
# metres up, with nothing under it. Every jump after that lands higher than it
# took off, a ring at six and a half metres and a moving ring at nine and a
# half, with corners, a pad and a trap on the road between them, until a second
# platform starts the way down and a last ring drops the car back to the ground
# for the run home. Four right handers in a row curl the climb round, so the
# road in the air comes back over the ground it started from.
#
# Up there the rail is all there is. A car that goes over it falls to the
# grass, and is put back on the landing of the last ring - so the rings are
# spaced to keep that a corner away, not a climb away.


func describe() -> void:
	track_name = "Sky Stairs"
	blurb = "Onto a moving platform and up into the air. Mind the rail."
	# For now, from tools/checks/acrobatic_drive.gd, which laps it with the keys
	# in 1:04.03 without falling, scaled as Lift Off's are. To be replaced by
	# the best a player drives.
	medals(55.0, 63.5, 70.5)

	# The grid, a pad, and a right hander.
	straight(60.0)
	pad(0.0)
	straight(30.0)
	corner(80.0, 36.0)

	# A barrier in from the right, and the first ring on the left.
	straight(35.0)
	barrier(0.1, 1.0)
	straight(50.0)
	ring_jump(-0.3)

	# A second right hander, and a trap in the run up to the first platform. Off the far end of it the road
	# floats, three metres up.
	corner(90.0, 34.0)
	straight(35.0)
	trap(-0.6, 0.6, 0.55, 1.2, 0.9)
	straight(55.0)
	floating()
	platform_jump(-0.5, 0.5, 0.55, 0.8, 1.3, 3.0)

	# In the air. A right hander with nothing but the rail outside it, and a
	# ring that lands three and a half metres higher again.
	corner(90.0, 32.0)
	straight(60.0)
	ring_jump(0.3, 3.5)

	# Six and a half metres up. Another right hander, a pad off to the left, and a
	# ring that moves, landing at nine and a half.
	corner(100.0, 34.0)
	straight(35.0)
	pad(-0.5)
	straight(50.0)
	moving_ring_jump(-0.4, 0.4, 0.7, 1.2, 3.0)

	# The top, curling back over the road below. A left hander, a trap across the road, and a second platform that starts the
	# way down, faster and narrower than the first.
	corner(-85.0, 36.0)
	straight(30.0)
	trap(-0.6, 0.6, 0.6, 1.0, 0.8)
	straight(55.0)
	platform_jump(-0.5, 0.5, 0.5, 0.6, 1.1, -3.5)

	# And the last ring, straight off that landing, dropping all the way back to
	# the ground.
	straight(50.0)
	ring_jump(0.0, -6.0)
	floating(false)

	# Home.
	corner(60.0, 45.0)
	straight(60.0)
