extends TrackDefinition

# Not a track anyone drives. The course tools/checks/rings.gd flies a car
# through: a ring over a jump in the middle of the road, a ring standing over
# level road high enough to drive under, and a ring over a jump off to one side.


func describe() -> void:
	track_name = "Ring Test"
	straight(120.0)
	ring_jump(0.0)
	straight(60.0)
	ring(0.0, 5.0)
	straight(60.0)
	ring_jump(0.6)
	straight(60.0)
