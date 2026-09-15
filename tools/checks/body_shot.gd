extends SceneTree

# Look at the body moving on its springs: leaning out of a corner, and sunk
# down onto them just after a landing.
#   Godot --path . --fixed-fps 60 --script tools/checks/body_shot.gd -- <out_dir>
#
# The lean is laid on the shell and on nothing else, so no number any physics
# check reads can show it. The top half of each picture is the chase view the
# player drives with; the bottom half is a camera stood off the same car - in
# front of it for the corner, beside it for the landing - which is where a roll
# and a squat actually show.

const LOOK_AHEAD := 12.0
const CORNER_SPEED := 26.0


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
	for overlay in ["Hud", "Progress", "Countdown", "Result"]:
		main.get_node(overlay).hide()
	var day_night: Node = main.get_node("DayNight")
	day_night.start_offset = 0.0
	day_night._time = 0.0
	day_night._apply(day_night._nightness_at(0.0))

	var track: Track = main.get_node("Track")
	var car: Car = main.get_node("Car1")
	var other: Car = main.get_node("Car2")
	var chase: ChaseCamera = main.get_node("Split/TopView/SubViewport/Camera")
	var side: ChaseCamera = main.get_node("Split/BottomView/SubViewport/Camera")
	# The bottom camera is taken off its car and stood wherever it is told.
	side.follow(null)
	var faults := 0

	var corner := _find(track, TrackLayout.CORNER)
	if corner == null:
		print("  no course in the first 60 had a corner to lean through")
		faults += 1
	else:
		_park(track, car, corner.start_offset - 20.0)
		chase.follow(car)
		await _drive_to(track, car, other,
			corner.start_offset + corner.length * 0.5, CORNER_SPEED)
		print("mid-corner at %.1f m/s: roll %+.1f deg, pitch on top of the road %+.1f deg, sunk %.3f m"
			% [car._wheel_speed, rad_to_deg(car._roll), rad_to_deg(car._dive), -car._drop])
		if absf(rad_to_deg(car._roll)) < 0.5:
			print("  the body is not leaning through the corner")
			faults += 1
		_stand(side, car, -car.global_transform.basis.z * 7.0 + Vector3.UP * 0.4)
		await _shoot(car, other, "%s/01_corner.png" % out)

	var jump := _find(track, TrackLayout.JUMP)
	if jump == null:
		print("  no course in the first 60 had a jump to land")
		faults += 1
	else:
		_park(track, car, jump.start_offset - 24.0)
		chase.follow(car)
		var came_down := await _land(car, other)
		print("just after landing at %.1f m/s: sunk %.3f m, roll %+.1f deg, pitch on top of the road %+.1f deg"
			% [came_down, -car._drop, rad_to_deg(car._roll), rad_to_deg(car._dive)])
		if -car._drop < 0.03:
			print("  the body did not sink onto its springs on landing")
			faults += 1
		_stand(side, car, -car.global_transform.basis.x * 5.0 + Vector3.UP * 0.3)
		await _shoot(car, other, "%s/02_landing.png" % out)

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## The first piece of a kind, far enough in to have road behind it, on the
## first course that has one. The course is left built.
func _find(track: Track, kind: int) -> TrackLayout.Piece:
	for course in range(1, 60):
		track.generate(course * 977)
		for piece in track.layout().pieces:
			if piece.kind == kind and piece.start_offset > 40.0:
				return piece
	return null


## Put a car on the centreline facing down the course, just clear of the road,
## stopped, and drawn there rather than slid there.
func _park(track: Track, car: Car, at: float) -> void:
	var curve := track.curve()
	var here: Vector3 = track.global_transform * curve.sample_baked(at)
	var ahead: Vector3 = track.global_transform * curve.sample_baked(at + 2.0)
	car.frozen = true
	car.global_position = here + Vector3.UP * 0.05
	car.look_at(Vector3(ahead.x, car.global_position.y, ahead.z), Vector3.UP)
	car.reset_motion()
	car.reset_physics_interpolation()


## Drive the car at a point a little way along the centreline, the way
## solo_run's driver does, at a steady speed, until it is `until` metres along.
func _drive_to(track: Track, car: Car, other: Car, until: float, speed: float) -> void:
	var curve := track.curve()
	var to_track := track.global_transform.affine_inverse()
	for i in 600:
		# The race's own countdown freezes and frees both cars on its timers,
		# so they are put back the way this wants them every step.
		car.frozen = false
		other.frozen = true
		var offset: float = curve.get_closest_offset(to_track * car.global_position)
		if offset >= until:
			return
		var target: Vector3 = track.global_transform * curve.sample_baked(
			minf(offset + LOOK_AHEAD, track.length()))
		var wanted := target - car.global_position
		wanted.y = 0.0
		if wanted.length_squared() > 0.01:
			var turn := (-car.global_transform.basis.z).signed_angle_to(
				wanted.normalized(), Vector3.UP)
			car.rotate_y(clampf(turn, -0.05, 0.05))
		car._speed = speed
		await physics_frame


## Drive the car flat out off the jump ahead of it, and stop it at the bottom
## of the sink its landing puts the body into. Returns how fast it came down.
func _land(car: Car, other: Car) -> float:
	var airborne := 0
	var falling := 0.0
	var landed := false
	for i in 600:
		car.frozen = false
		other.frozen = true
		car._speed = car.max_speed
		await physics_frame
		if not landed:
			if not car.is_on_floor():
				airborne += 1
				falling = -car.velocity.y
			elif airborne >= 20:
				landed = true
			else:
				airborne = 0
		elif car._drop_rate >= 0.0:
			return falling
	return falling


## Stand a camera `offset` away from the car's middle and point it there.
func _stand(camera: Camera3D, car: Car, offset: Vector3) -> void:
	var middle := car.global_position + Vector3.UP * 0.7
	camera.global_position = middle + offset
	camera.look_at(middle, Vector3.UP)
	camera.reset_physics_interpolation()


## Hold both cars where they are while the chase camera settles, and save the
## picture.
func _shoot(car: Car, other: Car, path: String) -> void:
	for i in 20:
		car.frozen = true
		other.frozen = true
		await physics_frame
	for i in 5:
		await process_frame
	root.get_texture().get_image().save_png(path)
