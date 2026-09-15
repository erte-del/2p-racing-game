extends SceneTree

# What survives a car being given somebody else's model.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/car_shell.gd
#
# The whole promise of a brought-in car is that it changes nothing but the
# view: the same box, the same tuning, the same road. So this drives the two
# cars in a real race, swaps a model onto one of them mid-race and looks at
# what moved. The model it swaps in is deliberately the worst case - a bare
# box with no wheels, no steering wheel, no named materials and no interior -
# because that is the shape of most of what a player will actually drop in.

## Everything about how a car drives and moves that its model must not be able
## to change, compared between the car given a new model and the one that was
## not.
const TUNING := [
	"max_speed", "gravity", "tight_turn_radius", "air_steer", "steer_rise",
	"steer_fall", "roof_bounce",
	"roll_per_accel", "max_roll", "dive_per_accel", "max_dive",
	"landing_give", "max_squash", "body_spring", "body_damping",
	"air_wheel_fade",
]


func _init() -> void:
	await process_frame
	var settings: Node = root.get_node_or_null(^"/root/GameSettings")
	settings.track_file = ""
	settings.chaos = false

	var faults := 0
	var race: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(race)
	for i in 10:
		await physics_frame

	var car: Car = race.get_node("Car1")
	var other: Car = race.get_node("Car2")
	var camera: ChaseCamera = race.get_node("Split/TopView/SubViewport/Camera")

	# The stock car, before anything is done to it.
	var box := _hitbox(car)
	print("the stock car has a %.2f x %.2f x %.2f box at %.3f, and a cockpit"
		% [box.size.x, box.size.y, box.size.z, box.position.y])
	if not car.has_cockpit():
		print("  the car the game ships with has no cockpit")
		faults += 1
	camera.set_inside(true)
	if not camera.is_inside():
		print("  the stock car would not take the first person camera")
		faults += 1
	camera.set_inside(false)

	# Reloading the stock model through the same door a player's car comes
	# through has to leave a car nobody could tell had been touched.
	car.set_model(load("res://assets/models/car.glb").instantiate(), true)
	await physics_frame
	if not _hitbox(car).is_equal_approx(box):
		print("  reloading the stock model moved the collision box")
		faults += 1
	if not car.has_cockpit():
		print("  the stock model came back without its cockpit")
		faults += 1
	if car.find_child("Wheel_FL", true, false) == null:
		print("  the stock model came back without its wheels")
		faults += 1
	print("the stock model loaded at run time is the same car again")

	# And now the worst case.
	var speed := _speed(car)
	car.set_model(_a_box_on_wheels_it_does_not_have(), false)
	await physics_frame

	if not _hitbox(car).is_equal_approx(box):
		print("  a brought-in model changed the collision box")
		faults += 1
	else:
		print("a car wearing a bare box still has the same %.2f x %.2f x %.2f"
			% [box.size.x, box.size.y, box.size.z])
	if not is_equal_approx(_speed(car), speed):
		print("  swapping the model changed how fast the car was going")
		faults += 1
	for property in TUNING:
		if car.get(property) != other.get(property):
			print("  swapping the model retuned the car's %s" % property)
			faults += 1

	# No interior, so no first person - and the key that asks for it is not a
	# key that does nothing else afterwards.
	if car.has_cockpit():
		print("  a bare box reported a cockpit")
		faults += 1
	camera.set_inside(true)
	if camera.is_inside():
		print("  the camera went inside a car with no inside")
		faults += 1
	else:
		print("the first person view is refused on a car that has no interior")

	# It still has to be paintable, or the two cars cannot be told apart.
	car.repaint(Color(0.1, 0.9, 0.2))
	await physics_frame
	var worn := _paint_worn_by(car)
	if worn == null:
		print("  a brought-in model has no material to paint")
		faults += 1
	elif not worn.albedo_color.is_equal_approx(Color(0.1, 0.9, 0.2)):
		print("  a brought-in model would not take the paint")
		faults += 1
	else:
		print("and it takes the paint, so the two cars are still tellable apart")

	# Its lights have to be somewhere on it rather than out where the stock
	# car keeps them.
	var shell: CarShell = car.get_node("Body")
	var lights: Array = shell.find_children("*", "SpotLight3D", true, false)
	if lights.size() != 2:
		print("  a brought-in model has %d headlights" % lights.size())
		faults += 1
	else:
		var bounds: AABB = shell.bounds().grow(0.05)
		for light: SpotLight3D in lights:
			if not bounds.has_point(light.position):
				print("  a headlight sits outside the model at %v" % light.position)
				faults += 1
		print("its beams sit on the shape itself, at %v and %v"
			% [lights[0].position, lights[1].position])

	# And it still drives. A car that has stopped answering the road is the
	# failure this whole split was meant to make impossible. Driven by
	# holding the speed on rather than by pressing a key, because there is
	# nobody at the keyboard in a headless run.
	car.frozen = false
	var was := car.global_position
	for i in 30:
		car._speed = car.max_speed
		await physics_frame
	var went := car.global_position.distance_to(was)
	# Half a second at the tuned 30 m/s, less whatever the road took off it.
	if went < 10.0:
		print(("  a car wearing a brought-in model went %.1f m in half a "
				+ "second, where it should have gone about 15") % went)
		faults += 1
	else:
		print("it went %.1f m in half a second, the same as it ever did" % went)

	race.queue_free()
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## The collision box in the car's own space, which is the thing that must not
## move however the car is dressed.
func _hitbox(car: Car) -> AABB:
	var shape: CollisionShape3D = car.get_node("Collision")
	var box := shape.shape as BoxShape3D
	return AABB(shape.position - box.size * 0.5, box.size)


## A model with none of what the game's own car has: one flat-shaded box,
## nothing named, nothing to sit in.
func _a_box_on_wheels_it_does_not_have() -> Node3D:
	var root_node := Node3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 1.2, 4.2)
	mesh.mesh = box
	mesh.position.y = 0.6
	root_node.add_child(mesh)
	return root_node


func _paint_worn_by(car: Car) -> StandardMaterial3D:
	for node in car.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.get_surface_override_material_count():
			var worn := mesh_instance.get_surface_override_material(surface)
			if worn is StandardMaterial3D:
				return worn
	return null


func _speed(car: Car) -> float:
	return car.velocity.length()
