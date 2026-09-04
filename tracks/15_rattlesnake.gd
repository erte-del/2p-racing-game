extends TrackDefinition

# Rows, and more of them than the rest of the game put together.
#
# The Gauntlet ran five in a row and then let go. This one has twenty-two, in
# four runs, and each run is tighter than the last: twenty-eight metres between
# them at the start of the track and twenty at the end, which is very close
# to the arithmetic that says a car can get across at all. What makes it hard
# is not any one of them. It is that there is never a row that can be taken
# lazily, because the line out of a lazy one is on the wrong side of the next.


func describe() -> void:
	track_name = "Rattlesnake"
	blurb = "Twenty-two rows, and each run of them tighter than the last."
	medals(71.0, 79.0, 89.0)

	straight(70.0)

	# The pad first, because every run of rows after this is easier with speed
	# and harder to survive with it, and that trade is the track.
	corner(-48.0, 48.0)
	straight(38.0)
	pad(0.0)
	straight(56.0)

	# First run. Five rows, twenty-eight metres apart, which is comfortable.
	barrier(-1.0, 0.28)
	straight(28.0)
	barrier(-0.28, 1.0)
	straight(28.0)
	barrier(-1.0, 0.28)
	straight(28.0)
	barrier(-0.28, 1.0)
	straight(28.0)
	barrier(-1.0, 0.28)
	straight(52.0)

	# A corner, to break the rhythm before it becomes one.
	corner(-88.0, 32.0)
	straight(46.0)

	# Second run. Five rows at twenty-four, on a road that is climbing, so the
	# far ones are hidden behind the near ones until late.
	climb(46.0, 4.2)
	barrier(0.28, 1.0)
	straight(24.0)
	barrier(-1.0, -0.28)
	straight(24.0)
	barrier(0.28, 1.0)
	straight(24.0)
	barrier(-1.0, -0.28)
	straight(24.0)
	barrier(0.28, 1.0)
	straight(54.0)

	# Four corners of clear road on the high ground - an esse and then two
	# lefts that turn the track back on itself - and the fork at the end of
	# them, which after ten rows reads as a rest even though it is four more.
	corner(66.0, 36.0)
	corner(-60.0, 34.0)
	straight(44.0)
	corner(-94.0, 32.0)
	straight(48.0)
	corner(-86.0, 34.0)
	straight(44.0)
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

	# Third run, downhill, five rows at twenty-one.
	climb(48.0, -4.2)
	barrier(-1.0, 0.26)
	straight(21.0)
	barrier(-0.26, 1.0)
	straight(21.0)
	barrier(-1.0, 0.26)
	straight(21.0)
	barrier(-0.26, 1.0)
	straight(21.0)
	barrier(-1.0, 0.26)
	straight(50.0)

	# A hairpin, and the second pad on the way out, because the last run wants
	# to be met with speed that has to be thrown away immediately.
	width(6.0)
	corner(144.0, 19.0)
	width(8.0)
	straight(38.0)
	pad(-0.3)
	straight(52.0)

	# Fourth and last. Three rows at twenty metres, which is about as close as
	# two rows on opposite sides of the road are allowed to stand.
	barrier(0.24, 1.0)
	straight(20.0)
	barrier(-1.0, -0.24)
	straight(20.0)
	barrier(0.24, 1.0)
	straight(58.0)

	# The jump, off a straight with nothing on it at all - the only one.
	corner(52.0, 44.0)
	straight(64.0)
	jump()

	straight(26.0)
	corner(-40.0, 46.0)
	straight(80.0)
