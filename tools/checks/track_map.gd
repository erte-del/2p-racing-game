extends SceneTree

# Draw a hand-made track from above.
#   Godot --path . --script tools/checks/track_map.gd -- <out_dir> [file]
#
# Reading a track file tells you what is on it and not what it is like. This
# is the answer to "is that hairpin where I think it is", which is the
# question authoring a track is mostly made of.

const DEFAULT := "res://tracks/01_first_light.gd"
const SIZE := 1400


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var path: String = args[1] if args.size() > 1 else DEFAULT

	root.size = Vector2i(SIZE, SIZE)
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.chaos = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	main.get_node("Track").track_file = path
	root.add_child(main)
	for i in 30:
		await process_frame
	for overlay in ["Hud", "Progress", "Countdown", "Result", "Split"]:
		main.get_node(overlay).hide()

	var track: Track = main.get_node("Track")
	var definition := track.definition()

	# One camera looking straight down, high enough to hold the whole course,
	# in place of the split screen.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _across(track) * 1.12
	camera.position = _middle(track) + Vector3.UP * 400.0
	camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	camera.far = 1000.0
	root.add_child(camera)
	camera.make_current()

	# Both cars off the road and out of the picture.
	for name in ["Car1", "Car2"]:
		main.get_node(name).hide()

	# The sun straight overhead, so the road is read by its own colour rather
	# than by which way the shadows happen to fall.
	main.get_node("DayNight").start_offset = 0.0
	main.get_node("Sun").rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	for i in 20:
		await process_frame

	print("%s - %.0f m, %.0f m across"
		% [definition.track_name, track.length(), _across(track)])
	root.get_texture().get_image().save_png("%s/track_map.png" % out)
	quit()


## How much ground the course covers, in metres, on its widest side.
func _across(track: Track) -> float:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in range(0, int(track.length()), 5):
		var p: Vector3 = track.curve().sample_baked(float(i))
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	return maxf(hi.x - lo.x, hi.y - lo.y) + 60.0


func _middle(track: Track) -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in range(0, int(track.length()), 5):
		var p: Vector3 = track.curve().sample_baked(float(i))
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var middle := (lo + hi) * 0.5
	return track.global_transform * Vector3(middle.x, 0.0, middle.y)
