extends SceneTree

# Drop a car onto the other car's roof, and onto the road beside it.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/roof_bounce.gd
#
# Coming down on the other car is meant to throw a car back up; coming down on
# anything else is meant to put it down and keep it there. Both are asked of
# the same fall from the same height with no speed of its own, so the only
# thing that differs between them is what the car landed on.

## Metres the car falls before it meets whatever is under it.
const DROP := 3.0
## Seconds each drop is watched for before it is given up on.
const WATCH := 3.0


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.chaos = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 10:
		await physics_frame

	var car: Car = main.get_node("Car1")
	var other: Car = main.get_node("Car2")
	# Where the grid put this car, which is open road beside the other one.
	var spot := car.global_position
	var basis := other.global_transform.basis
	var roof_top := other.global_position.y + _roof_height(other)
	var faults := 0

	print("both falls meet the surface at about %.1f m/s; roof_bounce %.2f, nothing slower than %.1f m/s bounces"
		% [sqrt(2.0 * car.gravity * DROP), car.roof_bounce, car.roof_bounce_min])

	var roof: Dictionary = await _drop(car, other,
		Transform3D(basis, Vector3(other.global_position.x, roof_top + DROP,
			other.global_position.z)))
	print("onto the roof: down at %.1f m/s, back up at %.1f m/s and %.2f m, %d bounces, at rest %+.2f m from the roof after %.2f s"
		% [roof["impact"], roof["rebound"], roof["rise"], roof["bounces"],
			roof["rest"] - roof_top, roof["after"]])
	if roof["bounces"] == 0:
		print("  a car that came down on the other car's roof did not bounce")
		faults += 1
	elif roof["rebound"] > roof["impact"]:
		print("  it came off the roof faster than it came down on it")
		faults += 1
	elif roof["rebound"] < roof["impact"] * car.roof_bounce * 0.8:
		print("  it came off the roof well short of what roof_bounce asks for")
		faults += 1
	if not roof["settled"]:
		print("  it never came to rest on the roof")
		faults += 1
	elif absf(roof["rest"] - roof_top) > 0.1:
		print("  it came to rest somewhere other than on the roof")
		faults += 1

	var road: Dictionary = await _drop(car, other,
		Transform3D(basis, spot + Vector3.UP * DROP))
	print("onto the road: down at %.1f m/s, back up at %.1f m/s and %.2f m, %d bounces, at rest after %.2f s"
		% [road["impact"], road["rebound"], road["rise"], road["bounces"], road["after"]])
	if road["bounces"] > 0 or road["rise"] > 0.05:
		print("  a car that came down on the road bounced")
		faults += 1
	if not road["settled"]:
		print("  it never came to rest on the road")
		faults += 1

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Put the car at `from` with no speed, let it fall with the other car parked,
## and watch it: how fast it came down, how fast and how far it went back up,
## how many times, and where and when it came to rest.
func _drop(car: Car, other: Car, from: Transform3D) -> Dictionary:
	car.frozen = true
	car.global_transform = from
	car.reset_motion()
	var result := {
		"impact": 0.0, "rebound": 0.0, "rise": 0.0, "bounces": 0,
		"settled": false, "rest": 0.0, "after": 0.0,
	}
	var touched := false
	var was_on_floor := false
	var landed_at := 0.0
	var still := 0
	for i in int(WATCH * 60.0):
		# The race's own countdown frees both cars partway through, so they are
		# put back the way this wants them every step.
		car.frozen = false
		other.frozen = true
		car._speed = 0.0
		await physics_frame
		var on_floor := car.is_on_floor()
		if on_floor:
			if not was_on_floor:
				touched = true
				landed_at = car.global_position.y
			still += 1
			# Half a second without leaving the floor is at rest.
			if still >= 30:
				result["settled"] = true
				result["rest"] = car.global_position.y
				result["after"] = float(i - 29) / 60.0
				break
		else:
			still = 0
			if not touched:
				result["impact"] = maxf(result["impact"], -car.velocity.y)
			else:
				if was_on_floor and car.velocity.y > 0.5:
					result["bounces"] += 1
					if result["bounces"] == 1:
						result["rebound"] = car.velocity.y
				result["rise"] = maxf(result["rise"], car.global_position.y - landed_at)
		was_on_floor = on_floor
	return result


## How high the top of a car's collision box stands above its origin.
func _roof_height(car: Car) -> float:
	var shape: CollisionShape3D = car.get_node("Collision")
	var box := shape.shape as BoxShape3D
	return shape.position.y + box.size.y * 0.5
