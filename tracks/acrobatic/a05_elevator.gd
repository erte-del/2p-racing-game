extends TrackDefinition

# The fifth acrobatic track: platforms that go up.
#
# A lift is a long platform in the hole of a jump that rises and falls, and the
# road on the far side is up at the top of it - higher than any jump could
# reach. Come down on it while it is low, stop, let it carry the car up, and
# drive off the end while it is high. Arrive while it is up and there is
# nothing to land on; leave before it has risen and there is nothing to drive
# onto. A player in a hurry can take one flat out if they arrive at exactly the
# right moment. A player who waits on it never misses.
#
# Two lifts, the second shorter in the waiting and off to one side, take the
# road from the grass to nearly twenty metres. Between them the road is
# floating, with a trap and a ring on it. The way back down is a platform
# sliding across the road and a moving ring that drops the car the whole way
# to the grass.


func describe() -> void:
	track_name = "Elevator"
	blurb = "Land on the lift, wait for the top, drive off. Or don't wait."
	# For now, from tools/checks/acrobatic_drive.gd, which laps it with the keys
	# in 1:14.10 without falling, scaled as Lift Off's are. It waits for every
	# lift, stopped, on both ends, so a player who takes one flat out on the
	# right moment beats these by a long way. To be replaced by the best a
	# player drives.
	medals(64.0, 73.5, 81.5)

	# The grid, a pad, a right hander, a barrier and a ring on the ground.
	straight(60.0)
	pad(0.0)
	straight(30.0)
	corner(70.0, 40.0)
	straight(55.0)
	barrier(-1.0, -0.15)
	straight(50.0)
	ring_jump(0.3)

	# The first lift: in the middle, six metres, holding the bottom and the top
	# for two seconds each.
	corner(-90.0, 34.0)
	straight(70.0)
	floating()
	lift_jump(0.0, 6.0, 0.7, 2.0, 1.5, 60.0)

	# Nine metres up. A right hander, a trap, and a ring up to eleven.
	corner(90.0, 32.0)
	straight(35.0)
	trap(-0.6, 0.6, 0.5, 1.1, 0.9)
	straight(50.0)
	ring_jump(-0.3, 2.0, 60.0)

	# The second lift: off to the right, narrower, and it waits less.
	corner(-90.0, 32.0)
	straight(60.0)
	lift_jump(0.3, 5.0, 0.6, 1.6, 1.3, 60.0)

	# The top, nearly twenty metres up. A pad, and a platform sliding across
	# the road that takes the first step down.
	corner(80.0, 34.0)
	straight(35.0)
	pad(-0.5)
	straight(45.0)
	platform_jump(-0.5, 0.5, 0.55, 0.7, 1.2, -3.0, 45.0)

	# And a moving ring that drops the car the whole way to the grass.
	corner(80.0, 34.0)
	straight(50.0)
	moving_ring_jump(-0.4, 0.4, 0.7, 1.1, -16.8)
	floating(false)

	# Home.
	corner(50.0, 45.0)
	straight(60.0)
