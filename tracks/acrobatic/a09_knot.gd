extends TrackDefinition

# The ninth acrobatic track: a road tied in a knot.
#
# Three times it turns all the way round on itself and comes back over the road
# it left on, twelve metres higher, and each of those crossings has a ring on the
# road just after it - so the thing a player is lined up for is a ring with
# their own road underneath it, and the way they came is always in sight.
#
# The turns are what climb: a corner that turns two hundred and seventy degrees
# at forty-two metres, rising twelve across the arc. Two of them go up and the
# last comes back down, so the road stacks - eight metres, twenty, thirty-two,
# and then down through the middle of its own knot to the grass.


func describe() -> void:
	track_name = "Knot"
	blurb = "Three times over your own road, each time twelve metres higher."
	# For now, from tools/checks/acrobatic_drive.gd, which laps it with the keys
	# in 1:19.80 without falling, scaled as Lift Off's are. To be replaced by
	# the best a player drives.
	medals(68.5, 79.0, 87.5)

	# The grid, a pad, a right hander, and a ring on the grass.
	straight(60.0)
	pad(0.0)
	straight(30.0)
	corner(70.0, 40.0)
	straight(50.0)
	ring_jump(0.0)

	# Up onto floating road at six metres, and the straight the first turn
	# comes back over.
	corner(-80.0, 34.0)
	straight(40.0)
	floating()
	climb(70.0, 8.0)
	straight(70.0)

	# The first turn: right, all the way round, twelve metres up. It crosses back
	# over the straight it left on, and a ring stands just after the crossing.
	corner(270.0, 42.0, 12.0)
	straight(30.0)
	ring_jump(0.0, 0.0, 60.0)

	# The second: left, all the way round, twelve more. It comes back over the
	# road out of the first, and the ring after it moves.
	corner(-270.0, 42.0, 12.0)
	straight(30.0)
	moving_ring_jump(-0.4, 0.4, 0.7, 1.1, 0.0, 60.0)

	# A long straight out of the knot, so the last turn ties its own loop
	# rather than coming down through the first one, and then the third turn:
	# right again, and down fourteen.
	straight(120.0)
	corner(270.0, 50.0, -14.0)
	straight(40.0)
	ring_jump(0.0, -10.0, 60.0)

	# Down to the grass.
	corner(-70.0, 40.0)
	straight(40.0)
	ring_jump(0.0, -8.0)
	floating(false)

	# Home.
	corner(50.0, 45.0)
	straight(60.0)
