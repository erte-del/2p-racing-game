extends SceneTree

# Look at a coin from the car's own view, by day and at night, and again a
# moment after it has been taken.
#   Godot --path . --script tools/checks/coin_shot.gd -- <out_dir>
#
# A coin is a small thing at the side of a road going past at thirty metres a
# second, and the whole of its job is being seen in time to decide about. So it
# is lit, the way the pads and the rings are - half of every race is at night -
# and it turns, because a small still thing beside a road is scenery.

## A long, slow cycle held at noon and at midnight, retimed rather than nudged,
## for the reason pad_shot.gd gives.
const HOLD := 600.0
const FADE := 5.0
## How far back down the road the car is parked from the coin.
const APPROACH := 14.0


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]

	# The sky is let run rather than pinned, because these two shots are the
	# two ends of it. A check that ran before this one may have left the
	# setting pinned in the sandbox, and a day shot taken at midnight says
	# nothing about whether a coin can be seen by day.
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.time_of_day = settings.NORMAL

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame

	var track: Track = main.get_node("Track")
	var coin := _first_coin(track)
	if coin == null:
		print("no coin on this course")
		quit(1)
		return
	print("coin at %.0f m of %.0f m, lane %+.2f, %.2f m up, %s"
		% [coin.centre(), track.length(), coin.lateral, coin.height,
			track.piece_summary()])

	_park(main, track, coin, APPROACH)
	for overlay in ["Progress", "Countdown", "Result"]:
		main.get_node(overlay).hide()
	# The HUD stays up in these, unlike the pad shots: the tally in the corner
	# is half of what taking a coin is meant to look like.
	var day_night: DayNight = main.get_node("DayNight")
	for shot in [["01_day", HOLD * 0.5], ["02_night", HOLD * 1.5 + FADE]]:
		day_night.retime(HOLD, HOLD, FADE, shot[1])
		# Caught at its worst moment: a quarter turn from facing the driver,
		# which is where a flat disc would be an invisible line. What should be
		# there instead is an ellipse, because the coin leans.
		track.set_race_time(_edge_on(main))
		for i in 10:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [out, shot[0]])
		print("wrote %s" % shot[0])

	# And the pickup: the car driven into it, caught partway through the lift.
	day_night.retime(HOLD, HOLD, FADE, HOLD * 0.5)
	_park(main, track, coin, 0.0)
	for i in 14:
		await physics_frame
	root.get_texture().get_image().save_png("%s/03_taken.png" % out)
	print("wrote 03_taken")
	quit()


## The moment on the race clock a coin is turned furthest from facing the
## driver, read off the furniture's own spin rather than written down here.
func _edge_on(main: Node) -> float:
	var furniture: TrackFurniture = main.get_node("Track/Furniture")
	return 0.25 / maxf(furniture.coin_spin, 0.001)


## Put the car on the road `back` metres short of the coin, looking at it, and
## snap the camera onto it.
func _park(
	main: Node, track: Track, coin: TrackFeatures.Placement, back: float
) -> void:
	# Off `centre_at` rather than off the curve: a course offset is a distance
	# along the flat and the curve is a 3D line, and the two have drifted apart
	# by the far end of a course with climbs in it.
	var at: float = maxf(coin.centre() - back, 0.0)
	var here := track.centre_at(at)
	var ahead := track.centre_at(at + 2.0)
	var right := (ahead - here) * Vector3(1, 0, 1)
	right = right.normalized().cross(Vector3.UP)
	var car: Car = main.get_node("Car1")
	car.frozen = true
	car.global_position = (here + Vector3.UP * car.wheel_radius
		+ right * (coin.lateral * track.half_width_at(at)))
	# look_at points -Z at the target, and -Z is the way the car drives.
	car.look_at(ahead, Vector3.UP)
	main.get_node("Split/TopView/SubViewport/Camera").follow(car)


func _first_coin(track: Track) -> TrackFeatures.Placement:
	for seed_ in range(1, 40):
		track.generate(seed_ * 977)
		var coins := track.features().of_kind(TrackFeatures.COIN)
		if not coins.is_empty():
			# Not the first one on the course: that is often just past the
			# grid, where the camera has nothing behind it.
			return coins[mini(1, coins.size() - 1)]
	return null
