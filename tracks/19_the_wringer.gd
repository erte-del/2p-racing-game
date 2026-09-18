extends TrackDefinition

# Every set piece in the game, one after another, with no clear road between.
#
# The eighteen tracks before this one each took a thing and did it: joined
# corners, hidden braking points, thin road, runs of rows, ramps that land on
# something. This one takes all of them and removes the recovery. There is a
# pad on the exit of nearly everything, which is the point - the track keeps
# handing back speed at exactly the moment the next set piece would rather it
# did not have any.


func describe() -> void:
	track_name = "The Wringer"
	blurb = "All of it, in a row, with the speed handed back each time."
	medals(72.0, 81.0, 91.0)

	straight(70.0)

	# Joined corners into a hook, straight off the grid.
	corner(-54.0, 44.0)
	corner(62.0, 38.0)
	straight(30.0)
	corner(70.0, 22.0)
	straight(46.0)

	# Pad on the exit, into a slalom. Four rows at twenty-two metres, taken
	# with a boost still on the car.
	pad(0.0)
	straight(44.0)
	barrier(-1.0, 0.26)
	straight(22.0)
	barrier(-0.26, 1.0)
	straight(22.0)
	barrier(-1.0, 0.26)
	straight(22.0)
	barrier(-0.26, 1.0)
	straight(46.0)

	# Thin road, climbing, into a corner over the crest.
	width(4.8)
	climb(44.0, 4.6)
	corner(-92.0, 26.0)
	straight(40.0)

	# Two rows on the thin road, and a hairpin at the end of it.
	barrier(0.36, 1.0)
	straight(36.0)
	barrier(-1.0, -0.36)
	straight(46.0)
	corner(146.0, 19.0)
	straight(42.0)

	# Wide again, and downhill to a ramp that lands on a corner.
	width(8.0)
	climb(44.0, -4.6)
	straight(48.0)
	jump()
	straight(20.0)
	corner(84.0, 28.0)
	straight(40.0)

	# The fork, four rows, entered off that corner exit.
	fork(1.0, 94.0)
	straight(20.0)
	barrier(0.58, 1.0)
	straight(18.0)
	barrier(0.07, 0.55)
	straight(18.0)
	barrier(0.58, 1.0)
	straight(18.0)
	barrier(0.07, 0.55)
	straight(20.0)

	# Second pad, straight out of the fork, into a hook: fast entry, and an
	# exit at eighteen metres of radius.
	pad(-0.35)
	straight(40.0)
	corner(-48.0, 46.0)
	width(6.0)
	corner(-96.0, 18.0)
	width(8.0)
	straight(44.0)

	# A climb into the second ramp, and a trap on the road out of the landing,
	# whose side can be seen from the lip and has changed by the time the car
	# is down.
	climb(42.0, 4.4)
	straight(46.0)
	jump()
	straight(22.0)
	trap(-0.7, 0.7, 0.6, 1.4, 1.0)
	straight(40.0)

	# Joined corners again, tighter than the first pair, falling.
	climb(42.0, -4.4)
	width(6.2)
	corner(88.0, 24.0)
	corner(-94.0, 21.0)
	width(8.0)
	straight(42.0)

	# Third pad, and the last hairpin, which is the one it is aimed at.
	pad(0.35)
	straight(50.0)
	width(5.8)
	corner(152.0, 17.0)
	width(8.0)
	straight(52.0)

	# A last slalom, three rows, on the run to the ramp.
	barrier(-1.0, 0.28)
	straight(24.0)
	barrier(-0.28, 1.0)
	straight(24.0)
	barrier(-1.0, 0.28)
	straight(48.0)

	# The third ramp, and the road to the line.
	straight(50.0)
	jump()

	straight(26.0)
	corner(-44.0, 44.0)
	straight(80.0)
