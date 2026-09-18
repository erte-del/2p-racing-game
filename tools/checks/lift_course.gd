extends TrackDefinition

# Not a track anyone drives. The course tools/checks/lifts.gd drives at: a lift
# that rises six metres, holding the bottom and the top for two seconds.


func describe() -> void:
	track_name = "Lift Test"
	straight(120.0)
	floating()
	lift_jump(0.0, 6.0, 0.7, 2.0, 1.5, 60.0)
	straight(60.0)
