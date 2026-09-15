extends SceneTree

# Drive a hand-made track, in the game as it stands.
#   Godot --path . --script tools/drive_track.gd -- [file]
#
# Two cars and a split screen, because that is what the game is until solo
# mode exists. What this is for is the road itself: whether the corners come
# at the right moment, whether the barriers can be seen in time, and whether
# the jump is where the run up says it is.

const DEFAULT := "res://tracks/01_first_light.gd"


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if not args.is_empty() else DEFAULT

	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.chaos = false

	var main: Node = load("res://scenes/main.tscn").instantiate()
	# Set before the scene enters the tree, so the first course it builds is
	# already the laid-out one rather than a rolled one thrown away.
	main.get_node("Track").track_file = path
	root.add_child(main)
