extends SceneTree

# Look at the speed rush - the streaks and the camera pulling back - at rest,
# in a slipstream and on a boost.
#   Godot --path . --script tools/checks/rush_shot.gd -- <out_dir>
#
# Both cars are parked side by side on the same stretch of road, and only the
# top one is given anything. The bottom half of every picture is therefore the
# same car at the same place with nothing going on, which is what makes the
# top half readable.

const PARK_AT := 120.0
const LANE := 0.45


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var out: String = OS.get_cmdline_user_args()[0]

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	for overlay in ["Hud", "Progress", "Countdown", "Result"]:
		main.get_node(overlay).hide()

	var track: Track = main.get_node("Track")
	var car1: Car = main.get_node("Car1")
	var car2: Car = main.get_node("Car2")
	_park(track, car1, -LANE)
	_park(track, car2, LANE)
	main.get_node("Split/TopView/SubViewport/Camera").follow(car1)
	main.get_node("Split/BottomView/SubViewport/Camera").follow(car2)

	car1.reset_motion()
	car2.reset_motion()
	for shot in ["01_rest", "02_slipstream", "03_boost"]:
		# Held rather than set: the race's own countdown unfreezes the cars
		# partway through this, and a slipstream decays on its own, so the
		# state has to be put back every frame to sit still for a picture.
		for i in 90:
			_hold(car2, 0.0, false)
			_hold(car1, 1.0 if shot == "02_slipstream" else 0.0,
					shot == "03_boost")
			await physics_frame
		for i in 5:
			await process_frame
		print("%-14s overspeed %.2f, top speed %.1f m/s"
			% [shot, car1.overspeed(), car1.top_speed()])
		root.get_texture().get_image().save_png("%s/%s.png" % [out, shot])
	quit()


## Flat out but going nowhere, with whatever is meant to be lifting it.
func _hold(car: Car, slipstream: float, boosted: bool) -> void:
	car.frozen = true
	car._speed = car.max_speed
	car._slipstream = slipstream
	if boosted:
		car.boost()


## Drop a car on the road facing the way it runs, across it by `lateral`.
func _park(track: Track, car: Car, lateral: float) -> void:
	var curve := track.curve()
	var here: Vector3 = curve.sample_baked(PARK_AT)
	var ahead: Vector3 = curve.sample_baked(PARK_AT + 2.0)
	var forward := ahead - here
	forward.y = 0.0
	var right := forward.normalized().cross(Vector3.UP)
	car.global_position = track.global_transform * (
		here + right * (lateral * track.half_width_at(PARK_AT))
		+ Vector3.UP * car.wheel_radius)
	# look_at points -Z at the target, and -Z is the way the car drives.
	car.look_at(track.global_transform * ahead, Vector3.UP)
