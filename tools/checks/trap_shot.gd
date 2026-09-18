extends SceneTree

# Look at the first trap in the game from where a player meets it, at three
# moments: holding the left, halfway across, and holding the right.
#   Godot --path . --script tools/checks/trap_shot.gd -- <out_dir>
#
# What no number says: whether a row that moves still reads as the same striped
# barrier as one that does not, which side the way past is on at a glance, and
# whether the panels face the car on the way across as well as at either end.

const BACK_FROM := 30.0


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.chaos = false

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	main.set_physics_process(false)
	for overlay in ["Hud", "Progress", "Countdown", "Result"]:
		main.get_node(overlay).hide()

	var track: Track = main.get_node("Track")
	var day_night: Node = main.get_node("DayNight")
	var car1: Car = main.get_node("Car1")
	var car2: Car = main.get_node("Car2")

	var file := ""
	for index in TrackRoster.FILES.size():
		track.lay_out(load(TrackRoster.file(index)).new())
		if not track.features().of_kind(TrackFeatures.TRAP).is_empty():
			file = TrackRoster.file(index)
			break
	if file.is_empty():
		print("  no track has a trap on it")
		quit(1)
		return
	var trap: TrackFeatures.Placement = track.features().of_kind(TrackFeatures.TRAP)[0]
	print("%s: a trap at %.0f m, %+.2f to %+.2f"
		% [track.definition().track_name, trap.offset, trap.phases[0], trap.phases[1]])

	# Both cars back from it, one either side, so the two halves of the picture
	# are the two ways past it - and which of them is open swaps between shots.
	_park(track, car1, trap.offset - BACK_FROM, -0.5)
	_park(track, car2, trap.offset - BACK_FROM, 0.5)
	main.get_node("Split/TopView/SubViewport/Camera").follow(car1)
	main.get_node("Split/BottomView/SubViewport/Camera").follow(car2)
	day_night.start_offset = 0.0
	day_night._time = 0.0
	day_night._apply(day_night._nightness_at(0.0))

	for shot: Array in [
		["01_holding_start", 0.0],
		["02_halfway", trap.dwell + trap.travel * 0.5],
		["03_holding_end", trap.dwell + trap.travel],
	]:
		track.set_race_time(shot[1])
		for i in 10:
			car1.frozen = true
			car2.frozen = true
			await physics_frame
		for i in 5:
			await process_frame
		root.get_texture().get_image().save_png("%s/%s.png" % [out, shot[0]])
	quit()


## Drop a car on the road facing the way it runs, across it by `lateral`.
func _park(track: Track, car: Car, at: float, lateral: float) -> void:
	var curve := track.curve()
	var here: Vector3 = curve.sample_baked(at)
	var ahead: Vector3 = curve.sample_baked(at + 2.0)
	var forward := ahead - here
	forward.y = 0.0
	var right := forward.normalized().cross(Vector3.UP)
	car.global_position = track.global_transform * (
		here + right * (lateral * track.half_width_at(at))
		+ Vector3.UP * car.wheel_radius)
	car.look_at(track.global_transform * ahead, Vector3.UP)
