extends SceneTree

# Trace how the steering eases, with no track and no player.
#   Godot --path . --headless --script tools/checks/steer_trace.gd
#
# A key is either down or up, and the car eases what it asks for: out to full
# lock over steer_rise, back to straight over the quicker steer_fall, back
# through straight at that quicker rate when the other key goes down, a stick
# held part of the way over eased to rather than jumped to, and near enough
# at once at a crawl, where a hairpin has always been taken on the key.
#
# The car is frozen and its easing stepped by hand, the way boost_trace steps
# the throttle, so nothing here is the keyboard or the road.

const STEP := 1.0 / 60.0
## A crawl, as a fraction of top speed.
const CRAWL := 0.1


func _init() -> void:
	var car: Car = load("res://scenes/car/car.tscn").instantiate()
	car.frozen = true
	root.add_child(car)
	await process_frame
	var top := car.max_speed
	print("steer_rise %.2f s, steer_fall %.2f s, top speed %.1f m/s"
		% [car.steer_rise, car.steer_fall, top])

	var rise := _time_to(car, top, 0.0, 1.0)
	var fall := _time_to(car, top, 1.0, 0.0)
	var across := _time_to(car, top, 1.0, -1.0)
	var half := _time_to(car, top, 0.0, 0.5)
	var crawl := _time_to(car, top * CRAWL, 0.0, 1.0)
	print("flat out: straight to full lock %.3f s, full lock to straight %.3f s, lock to lock %.3f s"
		% [rise, fall, across])
	print("flat out, a stick held half over is reached in %.3f s; at %.1f m/s full lock takes %.3f s"
		% [half, top * CRAWL, crawl])

	var faults := 0
	if absf(rise - car.steer_rise) > STEP:
		print("  full lock does not take steer_rise at top speed")
		faults += 1
	if absf(fall - car.steer_fall) > STEP:
		print("  letting go does not take steer_fall at top speed")
		faults += 1
	if absf(across - (car.steer_fall + car.steer_rise)) > STEP:
		print("  lock to lock is not back through straight at the quicker rate")
		faults += 1
	if half <= STEP:
		print("  a part-way input was jumped to rather than eased to")
		faults += 1
	if crawl > car.steer_rise * CRAWL + STEP:
		print("  at a crawl the steering is not near enough instant")
		faults += 1
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## How long, in whole physics steps, the steering takes to get from `from` to
## `wanted` with the car going `speed`.
func _time_to(car: Car, speed: float, from: float, wanted: float) -> float:
	car._speed = speed
	car._steer = from
	var steps := 0
	while not is_equal_approx(car._steer, wanted) and steps < 600:
		car._ease_steering(wanted, STEP)
		steps += 1
	return float(steps) * STEP
