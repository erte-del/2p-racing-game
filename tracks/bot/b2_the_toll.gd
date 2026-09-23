extends TrackDefinition

# The door out of the twenty: the second race against a computer-driven car.
#
# The Gate asked for what the first ten tracks taught. This asks for what the
# second ten did, which is a harder list and a longer road - two hairpins, a
# hook, two ramps, a trap, a slalom, two forks - but still nothing a player who
# has driven as far as Last Light has not met. A door is not the place to
# introduce anything. It is the place to find out whether the twenty behind it
# were driven or survived.
#
# What makes it harder than The Gate is not any one corner. It is that the set
# pieces are laid closer together, the way the late tracks lay them, so the
# metre of clear road either car would use to get back alongside is mostly not
# there. A mistake here is paid for against a rival rather than against a clock,
# and the rival does not wait.
#
# Every rule The Gate is shaped by holds here, for the same reasons:
#
# - Nine metres where the cars are closest - off the grid and into each ramp -
#   and eight for the rest, rather than the six a time trial pinches to. Both
#   hairpins are held at seven metres and twenty-six of radius, against the
#   seventeen to twenty-one the late tracks turn theirs on. A corner two cars
#   cannot both take decides the race before the flag, and a corner tight
#   enough to cost the quicker car more than the slower one decides it the
#   wrong way round - which is measured rather than assumed, in the note on
#   The Gate's hairpin. The point of a door is that it is winnable by a player
#   who can drive.
# - The pads come in pairs on opposite sides of the road. A pad both cars can
#   take is worth nothing to either of them; one of these is worth having. The
#   last one sits on the middle of the run home, so the end of the race is a
#   straight fight for it.
# - It snakes rather than curls, which is not for the driving either. The Gate
#   is short enough to curl one way the whole distance and still fit on its
#   ground; two kilometres curling one way would close on itself long before
#   the flag, so this one turns back as often as it turns on.
#
# The medals() targets are never shown. A bot road keeps no time and hands out
# no disc, and Solo leaves its targets at zero rather than reading these. They
# are here for tools/checks/bot_race.gd, which measures the bot against the gold
# of the road it is on: without one the check can time the bot but cannot say
# whether it came in fast enough to be worth racing.


func describe() -> void:
	track_name = "The Toll"
	blurb = "Everything the twenty taught, with another car in the way."
	medals(64.0, 71.0, 80.0)

	# Wide off the line, and long enough that the two cars have sorted
	# themselves out before the first corner rather than in it.
	width(9.0)
	straight(110.0)

	# One pad each side of the middle, straight away. The Gate opens the same
	# way, and it is the first thing either car has to decide.
	pad(-0.55)
	straight(32.0)
	pad(0.55)
	straight(44.0)

	# A hook off the grid: a fast entry that tightens, which is track eleven.
	# Held wide, so it is the line that is hard and not the room.
	width(8.0)
	corner(-52.0, 56.0)
	corner(-88.0, 30.0)
	straight(44.0)

	# A row on the outside of the exit, met by whichever car ran wide out of
	# the hook and not by the one that did not.
	barrier(0.3, 1.0)
	straight(48.0)

	# Climbing into the first hairpin. Seven metres rather than six: two cars
	# arrive at this together and both need to be able to get round it.
	climb(52.0, 4.6)
	straight(38.0)
	width(7.0)
	corner(140.0, 26.0)
	width(8.0)
	straight(46.0)

	# The first fork, on the high ground, with two rows in the fast lane. The
	# lane is a choice rather than a mistake, and on a road with one rival it is
	# also the one place a car behind can take a different road to the one in
	# front and come out level.
	fork(1.0, 76.0)
	straight(24.0)
	barrier(0.58, 1.0)
	straight(22.0)
	barrier(0.07, 0.55)
	straight(22.0)

	# Back onto one road and down off the plateau, into a long sweeper that
	# neither car has to lift for.
	climb(50.0, -4.6)
	corner(-44.0, 64.0)
	straight(40.0)

	# Wide for the first ramp, because a jump is met square or not at all, and
	# two cars arriving at one together both need the room to be square.
	width(9.0)
	straight(56.0)
	jump()

	# A corner waiting in the landing, which is track twelve, and a trap on the
	# road out of it: its side can be read from the lip and has changed by the
	# time either car is down.
	width(8.0)
	straight(22.0)
	corner(-86.0, 34.0)
	straight(26.0)
	trap(-0.7, 0.7, 0.6, 1.4, 1.0)
	straight(44.0)

	# The second pair of pads, on the flat, aimed at the slalom.
	pad(0.5)
	straight(30.0)
	pad(-0.5)
	straight(40.0)

	# A slalom of three rows, taken with whichever boost was won. Twenty-six
	# metres apart rather than the twenty-two the late tracks stand them at:
	# there are two cars threading it.
	barrier(-1.0, 0.28)
	straight(26.0)
	barrier(-0.28, 1.0)
	straight(26.0)
	barrier(-1.0, 0.28)
	straight(48.0)

	# A long right, and the second hairpin off the end of it, falling away. It
	# turns the other way to the first, the way the late tracks alternate
	# theirs: a driver who learned where to put the car in the first one has
	# not thereby learned this one.
	corner(78.0, 46.0)
	straight(38.0)
	climb(50.0, -4.4)
	width(7.0)
	corner(-134.0, 26.0)
	width(8.0)
	straight(48.0)

	# The second fork, the other side, two rows in it - and entered off a
	# hairpin, so which lane a car is in is settled by how it got out of the
	# corner rather than by a decision made on a straight.
	fork(-1.0, 76.0)
	straight(24.0)
	barrier(-1.0, -0.58)
	straight(22.0)
	barrier(-0.55, -0.07)
	straight(22.0)

	# Climbing to the second ramp, wide again, off a road that is already fast.
	corner(-58.0, 50.0)
	straight(36.0)
	climb(48.0, 4.2)
	width(9.0)
	straight(54.0)
	jump()

	# Out of the landing and onto the run home: one long sweep, the last pad on
	# the middle of it, and a corner nobody arrives at alone.
	width(8.0)
	straight(26.0)
	corner(-36.0, 74.0)
	straight(42.0)
	pad(0.0)
	straight(48.0)
	corner(70.0, 42.0)
	straight(80.0)
