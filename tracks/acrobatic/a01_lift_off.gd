extends TrackDefinition

# The first acrobatic track. It has one of everything the air asks of a car,
# and the ground between the jumps is not a rest.
#
# A ring first, off to the side a barrier pushes the car to - the line past the
# barrier is the line through the ring, so reading one reads the other. Then
# the first platform, sliding slowly left to right in the hole of a long jump:
# the car has to leave the lip when the platform will be under it, not when it
# is. A trap sweeps the road in the run up to it, so the timing starts before
# the ramp does. Then a ring that moves, and last a boost pad dead ahead of the
# final ring, because a ring over a jump catches a boosted car and a player who
# has just learnt to fear the pad before a platform should learn where it is
# safe.
#
# Rings are the checkpoints, so each hard thing sits just after one: a car that
# falls in the platform's hole is put back on the landing of the ring before it,
# a corner away rather than a lap.


func describe() -> void:
	track_name = "Lift Off"
	blurb = "Rings, a moving platform, a trap and a boost. Time the lip."
	# For now, from tools/checks/acrobatic_drive.gd, which laps it with the keys
	# in 50.45 s without falling: scaled the way the old Lift Off's targets
	# were against the same driver. To be replaced by the best a player drives.
	medals(43.5, 50.0, 55.5)

	# The grid, a pad straight off the line, and a right hander.
	straight(60.0)
	pad(0.0)
	straight(40.0)
	corner(70.0, 40.0)

	# A barrier in from the left pushes the car right, and the ring is on the
	# right: take the line past one and it is the line through the other.
	straight(40.0)
	barrier(-1.0, -0.15)
	straight(55.0)
	ring_jump(0.35)

	# A right hander off the landing, a trap sweeping the road, and the first
	# platform. It holds each side for a second and takes a second and a half
	# to cross, so there is always a moment it is coming to meet the car.
	corner(90.0, 34.0)
	straight(30.0)
	trap(-0.6, 0.6, 0.6, 1.4, 1.0)
	straight(60.0)
	platform_jump(-0.45, 0.45, 0.6, 1.0, 1.5)

	# A left hander, a pad off to the left for whoever wants it, and a ring
	# that slides from one side of the road to the other.
	corner(-100.0, 36.0)
	straight(30.0)
	pad(-0.5)
	straight(60.0)
	moving_ring_jump(-0.45, 0.45, 0.9, 1.4)

	# Two barriers either side to thread, and a pad dead ahead of the last
	# ring. A ring catches a boosted car; a platform does not.
	corner(-90.0, 40.0)
	straight(35.0)
	barrier(0.15, 1.0)
	straight(28.0)
	barrier(-1.0, -0.15)
	straight(30.0)
	pad(0.0)
	straight(45.0)
	ring_jump(0.0)

	# Round and home.
	corner(-45.0, 50.0)
	straight(60.0)
