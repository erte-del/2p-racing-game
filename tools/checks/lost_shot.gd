extends SceneTree

# Look at the line a player off the road is shown, in both modes.
#   Godot --path . --fixed-fps 60 --script tools/checks/lost_shot.gd -- <out_dir>
#
# The rules behind it are driven and measured by lost_prompt.gd, which says
# nothing about whether it can be read from the driving seat. This is the part
# only eyes settle: whether it sits where a player looking at the road ahead
# will see it, whether it clears the clock and the tally already up there, and
# whether it reads at all over grass and sky.

## How long the car is left on the grass before the picture is taken: long
## enough for the line to have come up and finished fading in.
const WAIT := 2.5
## Metres out beyond the rail the car is put.
const OUT := 6.0


func _init() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	settings.damage = false
	settings.track_file = "res://tracks/01_first_light.gd"

	await _solo(out)
	await _split(out)
	quit()


## One player, on the grass beside the road.
func _solo(out: String) -> void:
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	var camera: ChaseCamera = solo.get_node("Camera")
	var waited := 0
	while not solo.get("_running") and waited < 600:
		await physics_frame
		waited += 1

	_onto_the_grass(track, car, track.start_offset() + 60.0)
	camera.follow(car)
	for i in int(WAIT * 60.0):
		car._speed = 14.0
		await physics_frame
	await _shoot(out, "lost_solo", car, solo)
	solo.queue_free()
	await process_frame


## Two players, one of them on the grass and one still on the road, so the
## halves can be compared against each other in the one picture.
func _split(out: String) -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var waited := 0
	while not main.get("_racing") and waited < 600:
		await physics_frame
		waited += 1
	var track: Track = main.get_node("Track")
	var car: Car = main.get_node("Car1")
	var other: Car = main.get_node("Car2")

	# Player two off, player one left where the countdown put them.
	_onto_the_grass(track, other, track.start_offset() + 60.0)
	for i in int(WAIT * 60.0):
		car._speed = 14.0
		other._speed = 14.0
		await physics_frame
	await _shoot(out, "lost_split", other, main)
	main.queue_free()
	await process_frame


## Put a car out on the grass beyond the right-hand rail, pointed down the
## course, which is roughly where one arrives after sliding off a corner.
func _onto_the_grass(track: Track, car: Car, at: float) -> void:
	var centre := track.centre_at(at)
	var right := _heading(track, at).cross(Vector3.UP)
	car.frozen = true
	car.global_position = (Vector3(centre.x, 0.05, centre.z)
		+ right * (track.half_width_at(at) + track.kerb_width + OUT))
	car.look_at(car.global_position + _heading(track, at), Vector3.UP)
	car.reset_motion()
	car.reset_physics_interpolation()
	car.frozen = false


## Hold everything still and draw one frame, so what is saved is the frame that
## was on the screen rather than whatever the renderer had last finished.
func _shoot(out: String, named: String, car: Car, mode: Node) -> void:
	mode.set_physics_process(false)
	car.frozen = true
	for i in 4:
		await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("%s/%s.png" % [out, named])
	print("%s/%s.png" % [out, named])


func _heading(track: Track, at: float) -> Vector3:
	var here := track.centre_at(clampf(at, 0.0, track.length()))
	var ahead := track.centre_at(clampf(at + 2.0, 0.0, track.length()))
	var forward := ahead - here
	forward.y = 0.0
	return forward.normalized()
