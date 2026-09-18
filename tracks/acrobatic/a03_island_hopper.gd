extends TrackDefinition

# The third acrobatic track: once it leaves the ground, there is no ground.
#
# One ring on the grass to start, then a string of floating islands - short
# slabs of road hanging in the air, each ending in its own ramp - with a moving
# platform in every gap between them. Each platform slides the other way from
# the one before, so the rhythm of the last gap is the wrong rhythm for this
# one. The islands are just long enough to land, settle and go again, or to
# brake and wait for a platform that is on the wrong side: that choice, made
# forty metres at a time, is the track.
#
# Some islands turn a corner, and those have room for a trap or a pad. A ring
# over a climbing jump sits between the two chains of hops, so a fall in the
# second chain is not a fall back to the start, and the last ring moves and
# drops the car back to the grass for the run home.


func describe() -> void:
	track_name = "Island Hopper"
	blurb = "Island to island over moving platforms. No ground to fall back on."
	# For now, from tools/checks/acrobatic_drive.gd, which laps it with the keys
	# in 1:02.22 without falling, scaled as Lift Off's are. To be replaced by
	# the best a player drives.
	medals(53.5, 61.5, 68.5)

	# The grid, a pad, a right hander, and a ring on the ground.
	straight(60.0)
	pad(0.0)
	straight(35.0)
	corner(70.0, 40.0)
	straight(60.0)
	ring_jump(0.0)

	# Round, and up off the grass for good.
	corner(-80.0, 36.0)
	straight(60.0)
	floating()

	# The first chain: two hops. The first platform starts on the left, the
	# second on the right, and the island between them is forty metres long.
	platform_jump(-0.5, 0.5, 0.6, 0.9, 1.4, 2.0, 40.0)
	platform_jump(0.5, -0.5, 0.55, 0.8, 1.3, 1.0, 50.0)

	# An island with a corner in it, and a trap across its far straight.
	corner(90.0, 30.0)
	straight(30.0)
	trap(-0.6, 0.6, 0.6, 1.1, 0.9)
	straight(45.0)

	# A ring off to the left, climbing to five and a half metres.
	ring_jump(-0.3, 2.5, 60.0)

	# The second chain: three hops, faster and narrower, each platform the other
	# way from the last, and the middle island a step down.
	corner(90.0, 32.0)
	straight(50.0)
	platform_jump(-0.5, 0.5, 0.5, 0.6, 1.1, 0.0, 40.0)
	platform_jump(0.5, -0.5, 0.5, 0.6, 1.0, -1.0, 40.0)
	platform_jump(-0.4, 0.4, 0.5, 0.5, 1.0, 0.0, 50.0)

	# A last island with a pad on it, and a moving ring that drops the car back
	# to the ground.
	corner(-80.0, 34.0)
	straight(30.0)
	pad(0.4)
	straight(50.0)
	moving_ring_jump(-0.4, 0.4, 0.7, 1.1, -4.5)
	floating(false)

	# Home.
	corner(50.0, 45.0)
	straight(60.0)
