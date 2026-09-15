extends SceneTree

# Look at a boost pad from the car's own view, by day and at night.
#   Godot --path . --script tools/checks/pad_shot.gd -- <out_dir>
#
# A pad has to read as a pad in both, which is why it is emissive: the course
# runs through a whole day and night cycle, and paint that only shows up in
# sunlight would leave half the races with furniture nobody can see.

## A long, slow cycle held at noon and at midnight. The sky is retimed rather
## than nudged, because the game itself runs the day through in seconds and a
## forced clock reading would have moved on again by the time this renders.
const HOLD := 600.0
const FADE := 5.0
## How far back down the road the car is parked from the pad.
const APPROACH := 16.0


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame

	var track: Track = main.get_node("Track")
	var pad := _first_pad(track)
	if pad == null:
		print("no pad on this course")
		quit(1)
		return
	print("pad at %.0f m of %.0f m, lane %+.2f, %s"
		% [pad.offset, track.length(), pad.lateral, track.piece_summary()])

	_park(main, track, pad)
	# The countdown and the tally sit exactly over the road ahead, which is
	# the one part of the picture this check is about.
	for overlay in ["Hud", "Progress", "Countdown", "Result"]:
		main.get_node(overlay).hide()
	var day_night: DayNight = main.get_node("DayNight")
	for shot in [["01_day", HOLD * 0.5], ["02_night", HOLD * 1.5 + FADE]]:
		day_night.retime(HOLD, HOLD, FADE, shot[1])
		for i in 10:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [out, shot[0]])
		print("wrote %s" % shot[0])
	quit()


## Put the car on the road a little way short of the pad, looking at it, and
## snap the camera onto it.
func _park(main: Node, track: Track, pad: TrackFeatures.Placement) -> void:
	var curve := track.curve()
	var at: float = maxf(pad.centre() - APPROACH, 0.0)
	var here: Vector3 = track.global_transform * curve.sample_baked(at)
	var ahead: Vector3 = track.global_transform * curve.sample_baked(at + 2.0)
	var car: Car = main.get_node("Car1")
	car.frozen = true
	car.global_position = here + Vector3.UP * car.wheel_radius
	# look_at points -Z at the target, and -Z is the way the car drives.
	car.look_at(ahead, Vector3.UP)
	main.get_node("Split/TopView/SubViewport/Camera").follow(car)


func _first_pad(track: Track) -> TrackFeatures.Placement:
	for seed_ in range(1, 40):
		track.generate(seed_ * 977)
		var pads := track.features().of_kind(TrackFeatures.BOOST_PAD)
		if not pads.is_empty():
			return pads[0]
	return null
