extends TrackDefinition

# The tenth acrobatic track, and the last: one of everything, and then the drop.
#
# Two platforms that barely stop - four tenths of a second at each side, and
# nine to cross - with a trap on the island between them. Two rings that move,
# back to back, with only a landing between them, so the second has to be read
# while the first is still being flown. A lift to twenty metres, a trap and a
# ring above that, a grade to the top of the track at twenty-eight, a pad on the
# last of the road - and then the leap: a ring in the air over nothing, and the
# whole twenty-eight metres down to the grass on the far side of it.


func describe() -> void:
	track_name = "Last Leap"
	blurb = "Everything there is, and then a ring with twenty-eight metres under it."
	# For now, from tools/checks/acrobatic_drive.gd, which laps it with the keys
	# in 1:16.92 without falling, scaled as Lift Off's are. To be replaced by
	# the best a player drives.
	medals(66.0, 76.0, 84.5)

	# The grid, a pad, a barrier, and a ring on the grass.
	straight(60.0)
	pad(0.0)
	straight(30.0)
	corner(70.0, 40.0)
	straight(40.0)
	barrier(-1.0, -0.15)
	straight(50.0)
	ring_jump(0.0)

	# Up, and the two fast platforms with a trap on the island between them.
	corner(-90.0, 32.0)
	straight(50.0)
	floating()
	platform_jump(-0.6, 0.6, 0.5, 0.4, 0.9, 3.0, 45.0)
	straight(35.0)
	trap(-0.6, 0.6, 0.5, 0.9, 0.7)
	straight(45.0)
	platform_jump(0.6, -0.6, 0.5, 0.4, 0.9, 3.0, 45.0)

	# Two moving rings back to back, sliding opposite ways.
	corner(90.0, 30.0)
	straight(45.0)
	moving_ring_jump(-0.45, 0.45, 0.5, 0.9, 2.0, 60.0)
	moving_ring_jump(0.45, -0.45, 0.5, 0.9, 2.0, 60.0)

	# A lift to twenty metres, with a level run up to wait on.
	corner(90.0, 32.0)
	straight(60.0)
	lift_jump(0.0, 7.0, 0.65, 2.0, 1.3, 60.0)

	# A trap and a ring up there.
	corner(80.0, 34.0)
	straight(35.0)
	trap(0.6, -0.6, 0.5, 0.9, 0.7)
	straight(45.0)
	ring_jump(0.3, 2.0, 60.0)

	# The climb to the top of the game, and a pad on the last of the road.
	corner(-80.0, 34.0)
	climb(80.0, 6.0)
	straight(30.0)
	pad(0.0)
	straight(30.0)

	# The leap: a ring with everything under it, and the grass a long way down.
	moving_ring_jump(-0.4, 0.4, 0.6, 1.0, -28.4)
	floating(false)

	# Home.
	corner(50.0, 45.0)
	straight(80.0)
