extends SceneTree

# Trace what a boost pad is worth, with no track and no player.
#   Godot --path . --headless --script tools/checks/boost_trace.gd
#
# Two cars run flat out on level ground, already at their tuned top speed the
# way a car reaching a pad on a straight would be. One takes the pad a second
# in, the other does not, and the gap between them is what the pad is worth.
#
# What to look for: the surge, the hold at the raised ceiling, and then the
# coast back down. That last part is the point - the boost outlives its own
# timer, so a pad keeps paying into whatever corner comes after it.

const STEP := 1.0 / 60.0
const SECONDS := 6.0
const BOOST_AT := 1.0


func _init() -> void:
	var boosted := _car()
	var plain := _car()
	await process_frame

	print("tuned top speed %.1f m/s, boost +%.0f%% held %.1fs then fading %.2f/s"
		% [boosted.max_speed, boosted.boost_bonus * 100.0,
			boosted.boost_hold, boosted.boost_fade])
	print(" time   speed   ceiling  boost   gap")

	var taken := false
	var peak := 0.0
	var gap := 0.0
	var time := 0.0
	while time <= SECONDS + 0.0001:
		if not taken and time >= BOOST_AT:
			boosted.boost()
			taken = true
		if fmod(time + 0.0001, 0.1) < 0.0002:
			print("%5.1fs  %5.1f    %5.1f   %5.2f  %5.1f m"
				% [time, boosted._speed, boosted.top_speed(),
					boosted.boost_amount(), gap])
		_step(boosted)
		_step(plain)
		gap += (boosted._speed - plain._speed) * STEP
		peak = maxf(peak, boosted._speed)
		time += STEP

	print("peak %.1f m/s, %.0f%% over tuned; %.1f m gained by the end"
		% [peak, (peak / boosted.max_speed - 1.0) * 100.0, gap])
	quit()


## A car sitting at its tuned top speed, frozen so its own physics step -
## which reads the keyboard and drives the body - stays out of the way and the
## throttle below is the only thing moving it.
func _car() -> Car:
	var car: Car = load("res://scenes/car/car.tscn").instantiate()
	car.frozen = true
	root.add_child(car)
	car._speed = car.max_speed
	return car


## One physics step, flat out: the two calls the car makes either side of the
## drive step, without the input read or the wheels.
func _step(car: Car) -> void:
	car._update_boost(STEP)
	car._apply_throttle(1.0, STEP)
