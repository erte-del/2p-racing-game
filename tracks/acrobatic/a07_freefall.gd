extends TrackDefinition

# The seventh acrobatic track: all the way up, and then down in three falls.
#
# The first half is a climb. A ring on the grass, then floating road that
# climbs a grade, a barrier, climbs again, and a lift that carries the car up
# past twenty metres; one more grade to the top, twenty-six metres over the
# grass, the highest road in the game.
#
# The second half is the way down, and it is not a slope. It is three drops,
# each one a jump that lands eight or ten metres lower than it took off, each
# one through a ring that is moving, and each one onto floating road with a
# trap sweeping it straight after the landing - so a car that has just come
# down eight metres has to read a trap before it has finished bouncing. The
# last drop is all the way to the grass.


func describe() -> void:
	track_name = "Freefall"
	blurb = "Climb to the highest road there is, then fall off it three times."
	# For now, from tools/checks/acrobatic_drive.gd, which laps it with the keys
	# in 1:10.95 without falling, scaled as Lift Off's are. To be replaced by
	# the best a player drives.
	medals(61.0, 70.5, 78.0)

	# The grid, a pad, a right hander, and a ring on the grass.
	straight(60.0)
	pad(0.0)
	straight(30.0)
	corner(70.0, 40.0)
	straight(50.0)
	ring_jump(0.0)

	# Up off the grass: a grade to six metres, a barrier, another to twelve.
	corner(-90.0, 34.0)
	straight(40.0)
	floating()
	climb(90.0, 6.0)
	straight(30.0)
	barrier(-1.0, -0.15)
	straight(30.0)
	corner(90.0, 32.0)
	climb(90.0, 6.0)

	# A lift off to the right, rising six metres, to twenty-one and a half,
	# with a level run up to wait on.
	straight(60.0)
	lift_jump(0.3, 6.0, 0.7, 2.0, 1.2, 60.0)

	# The last grade to the top, twenty-six and a half metres up, and a pad on
	# the run to the edge.
	corner(90.0, 32.0)
	climb(80.0, 5.0)
	straight(40.0)
	pad(0.0)
	straight(40.0)

	# The first fall: eight metres, through a ring sliding across the road,
	# onto a trap.
	moving_ring_jump(-0.4, 0.4, 0.7, 1.1, -8.0)
	straight(30.0)
	trap(-0.6, 0.6, 0.55, 1.0, 0.8)
	straight(50.0)

	# The second: eight more, the ring sliding the other way and faster.
	moving_ring_jump(0.4, -0.4, 0.6, 1.0, -8.0)
	corner(90.0, 34.0)
	straight(30.0)
	trap(0.6, -0.6, 0.55, 0.9, 0.7)
	straight(50.0)

	# The last: the rest of the way to the grass, through the fastest ring.
	moving_ring_jump(-0.45, 0.45, 0.5, 0.9, -10.5)
	floating(false)

	# Home.
	corner(-50.0, 45.0)
	straight(60.0)
