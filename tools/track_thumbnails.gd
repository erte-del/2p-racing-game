extends SceneTree

# Draw every laid-out track from above and save the shots the select screen
# puts on its buttons.
#   Godot --path . --script tools/track_thumbnails.gd
#   Godot --path . --script tools/track_thumbnails.gd -- res://tracks/acrobatic/a01_lift_off.gd
#   Godot --path . --script tools/track_thumbnails.gd -- --wide res://tracks/01_first_light.gd
#
# `--wide` draws the long picture the track's own page shows instead of the
# square one on its button, into `assets/tracks/wide/`. A road is rarely as
# tall as it is wide, and a square frame round a long one is mostly grass; the
# wide shot turns the road so its long side runs across the picture.
#
# Run this after laying out a track or changing the shape of one. The shots
# are checked in rather than drawn at load: a menu that built twenty tracks to
# show twenty pictures of them would take a second to open, and the pictures
# do not change between runs.
#
# Scenery is left out. At the size these are shown, trees and hills come out
# as noise across the one thing the picture is for, which is the shape of the
# road.

const OUT := "res://assets/tracks"
const SIZE := 512
const WIDE_OUT := "res://assets/tracks/wide"
const WIDE_SIZE := Vector2i(1024, 512)


func _init() -> void:
	await process_frame
	var wanted: Array = OS.get_cmdline_user_args()
	var wide := wanted.has("--wide")
	wanted.erase("--wide")
	var out := WIDE_OUT if wide else OUT
	root.size = WIDE_SIZE if wide else Vector2i(SIZE, SIZE)
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.chaos = false
		# Pinned to day, whatever the sandbox's settings were left at by the
		# last check to run: a shot drawn at night is a dark road on dark grass.
		settings.time_of_day = settings.ALWAYS_DAY
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	for hidden in ["Hud", "Progress", "Lost", "Countdown", "Result", "Split",
			"Surroundings", "Trees", "Car1", "Car2"]:
		main.get_node(hidden).hide()

	# One camera looking straight down in place of the split screen, and the
	# sun straight overhead so the road is read by its own colour rather than
	# by which way the shadows happen to fall.
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	camera.far = 1200.0
	# Moved by this script between frames rather than on a physics step, so it
	# is drawn where it is put rather than interpolated towards it.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	root.add_child(camera)
	camera.make_current()
	main.get_node("DayNight").start_offset = 0.0
	main.get_node("Sun").rotation = Vector3(-PI * 0.5, 0.0, 0.0)

	var track: Track = main.get_node("Track")
	# Only the tracks named after `--`, if any are: redrawing all of them to add
	# one changes pictures nobody asked to change.
	#
	# The sweep is the two grids rather than every road there is. A bot road is
	# never drawn as a cell with an overhead shot in it - the select screen
	# gives it its own face - so a picture of one is a picture nothing hangs.
	# Named explicitly it is still drawn, because that is what naming it means.
	var aspect := float(root.size.x) / float(root.size.y)
	for path in (wanted if not wanted.is_empty()
			else TrackRoster.FILES + TrackRoster.ACROBATIC_FILES):
		track.track_file = path
		track.generate(0)
		await process_frame
		var bounds := _bounds(track)
		var across: float = bounds[1].x - bounds[0].x
		var down: float = bounds[1].y - bounds[0].y
		# The camera's size is the height of what it sees, and the width is
		# that times the picture's aspect. A wide picture of a road that runs
		# north to south is turned a quarter first, so the road fills it.
		var turned := wide and down > across
		camera.rotation = Vector3(-PI * 0.5, PI * 0.5 if turned else 0.0, 0.0)
		if turned:
			var swap := across
			across = down
			down = swap
		camera.size = maxf(down, across / aspect) + 70.0
		camera.position = track.global_transform * Vector3(
			(bounds[0].x + bounds[1].x) * 0.5, 0.0,
			(bounds[0].y + bounds[1].y) * 0.5) + Vector3.UP * 500.0
		for i in 12:
			await process_frame
		var file := "%s/%s.png" % [out, String(path).get_file().get_basename()]
		root.get_texture().get_image().save_png(
			ProjectSettings.globalize_path(file))
		print("%-22s %5.0f m, %4.0f m across -> %s"
			% [track.definition().track_name, track.length(), camera.size, file])
	quit()


## The ground a course covers, as the two corners of a box round it.
func _bounds(track: Track) -> Array:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in range(0, int(track.length()), 5):
		var p: Vector3 = track.curve().sample_baked(float(i))
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	return [lo, hi]
