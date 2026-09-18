extends TrackDefinition

# Not a track anyone drives. The course tools/checks/platforms.gd flies a car
# at: a platform that stands still in the middle of the road, one that slides
# out to the right and back, and a ring that does the same.


func describe() -> void:
	track_name = "Platform Test"
	straight(120.0)
	platform_jump(0.0, 0.0, 0.6, 1.0, 1.0)
	straight(80.0)
	platform_jump(0.0, 0.8, 0.6, 1.5, 1.2)
	straight(80.0)
	moving_ring_jump(0.0, 0.6, 1.5, 1.2)
	straight(60.0)
