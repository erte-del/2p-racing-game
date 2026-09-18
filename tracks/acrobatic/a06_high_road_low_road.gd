extends TrackDefinition

# The sixth acrobatic track: the road splits, twice.
#
# Each split is a kicker in one lane - a ramp that is not across the whole road
# - and off the top of it a high road running straight ahead through the air,
# while the course itself turns away and goes the long way round underneath.
# The high road is shorter and quicker, and it has a platform or a lift in it
# and nothing but grass under it. The low road is long, and safe, with only
# barriers and a trap to thread. The two meet again where the high road ends in
# mid air over the course and drops the car back onto it.
#
# A car chooses by where it is on the road, not by a menu: stay out of the
# kicker's lane and the choice is made. Rings are on the road both routes share,
# after each split, so a fall off a high road is a fall back to before it - the
# price of the short way.
#
# The first split kicks off the right and has a moving platform and a climbing
# jump on its high road. The second kicks off the left, and its high road has a
# lift.


func describe() -> void:
	track_name = "High Road, Low Road"
	blurb = "Two splits. Take the kicker for the short way over, or go round."
	# For now, from tools/checks/acrobatic_drive.gd, which laps it with the keys
	# in 1:15.13 without falling - and always the long way round, since it
	# never takes a kicker. Scaled as Lift Off's are. A player who takes the
	# high roads beats these. To be replaced by the best a player drives.
	medals(64.5, 74.5, 82.5)

	# The grid, a pad, a right hander, a barrier and a ring.
	straight(60.0)
	pad(0.0)
	straight(30.0)
	corner(70.0, 40.0)
	straight(50.0)
	barrier(-1.0, -0.15)
	straight(45.0)
	ring_jump(0.3)

	# The run up to the first split. The kicker is on the right.
	corner(90.0, 34.0)
	straight(60.0)
	var high := high_road(0.65, 2.5)
	high.straight(25.0)
	high.platform_jump(-0.6, 0.6, 0.5, 0.8, 1.3, 3.0, 35.0)
	high.straight(15.0)
	high.pad(0.0)
	high.straight(30.0)
	high.jump(3.5, 55.0)

	# The low road: out to the left, a long straight with barriers and a trap,
	# and back onto the line.
	corner(-90.0, 22.0)
	straight(40.0)
	corner(90.0, 26.0)
	straight(40.0)
	barrier(0.15, 1.0)
	straight(40.0)
	trap(-0.6, 0.6, 0.55, 1.2, 0.9)
	straight(50.0)
	barrier(-1.0, -0.15)
	straight(70.0)
	corner(90.0, 26.0)
	straight(40.0)
	corner(-90.0, 22.0)
	high_road_end()

	# Where the high road comes down, and a moving ring both roads share.
	straight(80.0)
	moving_ring_jump(-0.35, 0.35, 0.8, 1.2)

	# A right hander, a pad, and the run up to the second split. This kicker is
	# on the left.
	corner(80.0, 36.0)
	straight(40.0)
	pad(-0.5)
	straight(50.0)
	var lifted := high_road(-0.65, 2.0)
	lifted.straight(20.0)
	lifted.lift_jump(0.0, 5.0, 0.7, 1.4, 1.2, 40.0)
	lifted.straight(20.0)

	# The low road: out to the right this time, a trap, and back.
	corner(90.0, 22.0)
	straight(40.0)
	corner(-90.0, 26.0)
	straight(30.0)
	trap(-0.6, 0.6, 0.55, 1.0, 0.8)
	straight(80.0)
	corner(-90.0, 26.0)
	straight(40.0)
	corner(90.0, 22.0)
	high_road_end()

	# Down, and a last ring.
	straight(80.0)
	ring_jump(0.0)

	# Home.
	corner(-50.0, 45.0)
	straight(60.0)
