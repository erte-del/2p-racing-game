extends TrackDefinition

# Not a track anyone drives. The course tools/checks/floating.gd climbs a car up
# into the air on: a jump 3.5 m up onto floating road, a platform jump 3 m
# higher, a ring jump 3.5 m higher again, and one long drop back to the ground.


func describe() -> void:
	track_name = "Floating Test"
	straight(120.0)
	floating()
	jump(3.5)
	straight(60.0)
	platform_jump(0.0, 0.0, 0.6, 1.0, 1.0, 3.0)
	straight(60.0)
	ring_jump(0.0, 3.5)
	straight(60.0)
	jump(-10.0)
	floating(false)
	straight(60.0)
	corner(120.0, 40.0)
	straight(60.0)
	# Two platform jumps back to back, the first landing on the least road a
	# platform jump may, straight into the ramp of the second.
	floating()
	platform_jump(0.0, 0.0, 0.6, 1.0, 1.0, 0.0, 35.0)
	platform_jump(0.0, 0.0, 0.6, 1.0, 1.0, 1.5, 40.0)
	# And the longest drop any track makes: up a grade to twenty-eight metres
	# and straight off the end of it.
	climb(100.0, 26.5)
	straight(50.0)
	jump(-28.0)
	floating(false)
	straight(60.0)
