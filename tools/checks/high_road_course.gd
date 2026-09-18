extends TrackDefinition

# Not a track anyone drives. The course tools/checks/high_road.gd drives: a
# kicker onto a high road with a platform jump and a climbing jump on it, over
# a low road that goes the long way round and comes back underneath.


func describe() -> void:
	track_name = "High Road Test"
	straight(120.0)
	var high := high_road(0.55, 2.5)
	high.straight(20.0)
	high.platform_jump(0.0, 0.0, 0.6, 1.0, 1.0, 3.0, 35.0)
	high.jump(3.5, 55.0)
	# The low road: out to the left, along, and back onto the line.
	corner(-90.0, 26.0)
	straight(40.0)
	corner(90.0, 26.0)
	straight(170.0)
	corner(90.0, 26.0)
	straight(40.0)
	corner(-90.0, 26.0)
	high_road_end()
	straight(120.0)
