extends TrackDefinition

# The door out of the first ten tracks: a race against one computer-driven car.
#
# Not a track. A door asks for what the ten tracks behind it taught rather than
# teaching an eleventh thing, so there is nothing new on this road - sweepers,
# three rows of barriers, a fork, a jump, a hairpin, and pads. All of it has
# been met before. What has not been met before is another car in the middle of
# it.
#
# Which is what the road is shaped for. Every metre of it is a metre two cars
# have to share, so it is nine metres either side of the middle where they will
# be closest - off the grid, and into the ramp - rather than the usual eight. A
# door decided by which car got the inside of a narrow road is a door decided
# before the flag, and the point of the gate is that it is winnable by a player
# who can drive.
#
# The pads come in pairs on opposite sides of the road, because a pad both cars
# can take is worth nothing to either of them: one of them gets it. The last
# one is on the middle of the run to the flag, which makes the end of the race
# a straight fight for it.
#
# It curls steadily one way, which is not for the driving - it is so that the
# road fits on the ground it is laid on.
#
# The medals() targets are never shown. A bot road keeps no time and hands out
# no disc, and Solo leaves its targets at zero rather than reading these. They
# are here for tools/checks/bot_race.gd, which measures the bot against the gold
# of the road it is on: without one the check can time the bot but cannot say
# whether it came in fast enough to be worth racing.


func describe() -> void:
	track_name = "The Gate"
	blurb = "No clock and no medal. One car to beat."
	medals(40.0, 44.0, 49.0)

	# Wide off the line, and long enough that the two cars have sorted
	# themselves out before the first corner rather than in it.
	width(9.0)
	straight(110.0)

	# One pad each side of the middle. Both cars cannot have one.
	pad(-0.55)
	straight(34.0)
	pad(0.55)
	straight(40.0)

	# A long right that is held flat from the right entry and not from the
	# wrong one, which is most of what the first ten tracks taught.
	corner(88.0, 52.0)
	straight(44.0)

	# The first row, on the outside of the exit: the car that ran wide meets it
	# and the car that did not does not.
	barrier(-1.0, -0.3)
	straight(46.0)

	climb(58.0, 5.0)
	corner(-40.0, 60.0)
	straight(30.0)

	# The fork, in the one place on the road where a car has to commit to a
	# side and stay on it. The pad is in the right lane and two rows are in
	# there with it, which is what makes the slower lane a choice rather than a
	# mistake.
	width(8.0)
	straight(36.0)
	fork(1.0, 70.0)
	straight(26.0)
	barrier(0.58, 1.0)
	straight(24.0)
	barrier(0.06, 0.55)
	straight(20.0)

	# Back onto one road, and into the hairpin: the one corner here that cannot
	# be carried, so it is where a lead built on the straights is handed back.
	#
	# Seven metres wide rather than the six a time trial pinches a hairpin to,
	# and twenty-six of radius rather than the seventeen to twenty-one the late
	# tracks use. Two cars arrive at this one together, and a hairpin only one of
	# them fits through decides the race instead of asking anything of it. The
	# radius is not a guess: written at twenty-one, `bot_road.gd` had a bot
	# turned down to 0.3 beating a car driven flat out, because a corner that
	# tight costs the quicker car more than it costs the slower one. A door has
	# to be the other way round.
	width(7.0)
	corner(146.0, 26.0)
	width(8.0)
	straight(46.0)
	climb(56.0, -5.0)
	corner(-34.0, 70.0)

	# Wide again for the ramp, because a jump is met square or not at all, and
	# two cars arriving at one together both need the room to be square.
	width(9.0)
	straight(60.0)
	jump()

	corner(84.0, 46.0)
	straight(40.0)
	barrier(0.3, 1.0)
	straight(44.0)

	# The run to the flag: one long sweep, one pad on the middle of it, and a
	# last corner nobody arrives at alone.
	corner(-30.0, 80.0)
	straight(40.0)
	pad(0.0)
	straight(50.0)
	corner(76.0, 40.0)
	straight(80.0)
