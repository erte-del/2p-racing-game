extends TrackDefinition

# The fourth acrobatic track: high up, and half the road.
#
# It climbs off the grass onto floating road and the road narrows to half its
# width, and stays that way until the last jump brings the car back down. There
# is a rail either side and nothing past it. On a road that narrow a barrier
# leaves one lane, a trap sweeping across it leaves one lane that moves, and a
# ring off to one side is half a road off to one side - so the three things
# Lift Off taught are the same three things, with no room.
#
# It climbs as it goes: a ring up to seven metres, a platform to nine, a moving
# ring to eleven and a half, and a slalom of barriers along the top before the
# long drop home. Every ring is a checkpoint, and every fall off the rope goes
# back to the last one.


func describe() -> void:
	track_name = "Tightrope"
	blurb = "Half a road, high up, and a rail either side. Stay on it."
	# For now, from tools/checks/acrobatic_drive.gd, which laps it with the keys
	# in 52.33 s without falling, scaled as Lift Off's are. To be replaced by
	# the best a player drives.
	medals(45.0, 52.0, 57.5)

	# The grid, a pad, a right hander, and up off the grass.
	straight(60.0)
	pad(0.0)
	straight(30.0)
	corner(70.0, 40.0)
	straight(50.0)
	floating()
	climb(70.0, 5.0)

	# The road narrows to half, and two barriers leave one lane each.
	width(4.0)
	straight(40.0)
	barrier(-1.0, -0.1)
	straight(35.0)
	barrier(0.1, 1.0)
	straight(40.0)

	# A ring a little right, up to seven metres.
	ring_jump(0.25, 2.0, 60.0)

	# A right hander on the rope, a trap sweeping it, and a platform as wide as
	# the road is, up to nine.
	corner(90.0, 30.0)
	straight(30.0)
	trap(-0.65, 0.65, 0.22, 1.0, 0.9)
	straight(50.0)
	platform_jump(-0.5, 0.5, 1.0, 0.8, 1.2, 2.0, 40.0)

	# A left hander, another trap, and a ring that moves, up to eleven and a
	# half.
	corner(-90.0, 30.0)
	straight(40.0)
	trap(0.65, -0.65, 0.22, 0.9, 0.8)
	straight(50.0)
	moving_ring_jump(-0.3, 0.3, 0.6, 1.0, 2.5)

	# The top: a slalom of three barriers, and the long drop back to the grass.
	corner(80.0, 32.0)
	straight(35.0)
	barrier(-1.0, -0.1)
	straight(30.0)
	barrier(0.1, 1.0)
	straight(30.0)
	barrier(-1.0, -0.1)
	straight(40.0)
	ring_jump(0.0, -11.5)
	width(8.0)
	floating(false)

	# Home.
	corner(-45.0, 50.0)
	straight(60.0)
