extends SceneTree

# Drive a car into things and see what it costs the car.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/damage.gd
#
# Most of this is on a floor and a wall built here rather than on a course, so
# every hit is exactly as square, and exactly as fast, as it says: a barrier on
# a course sits on a road that bends, and a check that has to allow for that
# cannot tell a hit costing the wrong amount from a hit landing at an angle.
# The wall is a plain body in the obstacle group and the rail a plain body in
# the road group, which is all either of them is to the car.
#
# What it shows:
#   - a square hit at top speed costs full_hit, and at half speed half of it
#   - a glancing hit costs nearly nothing, and a boosted one more than full_hit
#   - a car held into a face is charged once per obstacle_recovery, not per step
#   - three flat-out hits break a car, and two and a third of one do not
#   - a rail costs nothing, however it is hit
#   - a car that breaks in the air stays in the air
#   - a checkpoint does not mend a car, and the smoke comes and goes with it
#   - with damage off none of it happens, and the car drives exactly the same
#     either way - which is what keeps every time already set standing
# and then that the two race scenes do what they say with a broken car.

const STEP := 1.0 / 60.0

var _world: Node3D
var _car: Car
var _wall: StaticBody3D
var _faults := 0


func _init() -> void:
	await process_frame
	_world = Node3D.new()
	root.add_child(_world)
	var floor_body := _box(Vector3(400.0, 1.0, 400.0), Vector3(0.0, -0.5, 0.0))
	floor_body.add_to_group(Car.ROAD_GROUP)
	_car = load("res://scenes/car/car.tscn").instantiate()
	_world.add_child(_car)
	for i in 5:
		await physics_frame
	_car.damage = true

	await _costs()
	await _held_into_the_face()
	await _breaking()
	await _rails()
	await _in_the_air()
	await _mending_and_smoke()
	await _switched_off()
	_world.queue_free()
	await process_frame

	await _solo()
	await _two_players()

	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


# --- what a hit costs -----------------------------------------------------

func _costs() -> void:
	var full := _car.full_hit
	_car.repair()
	var square: Dictionary = await _hit(_car.max_speed, 0.0, true)
	_car.repair()
	var half: Dictionary = await _hit(_car.max_speed * 0.5, 0.0, false)
	_car.repair()
	var glancing: Dictionary = await _hit(_car.max_speed, 82.0, true)
	_car.repair()
	var boosted: Dictionary = await _hit(_car.max_speed * (1.0 + _car.boost_bonus), 0.0, true)
	_car.repair()

	print("square at %.1f m/s costs %.1f of %.0f (full_hit %.0f)"
		% [square["speed"], square["cost"], _car.max_condition, full])
	if absf(square["cost"] - full) > 0.5:
		_fault("a square hit at top speed did not cost full_hit")
	print("square at %.1f m/s costs %.1f, %.2f of the flat-out hit"
		% [half["speed"], half["cost"], half["cost"] / maxf(square["cost"], 0.001)])
	if absf(half["cost"] / maxf(square["cost"], 0.001) - 0.5) > 0.05:
		_fault("a hit at half speed did not cost about half")
	print("glancing, 8 degrees off the face at %.1f m/s, costs %.1f"
		% [glancing["speed"], glancing["cost"]])
	if glancing["cost"] < 0.0 or glancing["cost"] > full * 0.2:
		_fault("a glancing hit cost more than a scrape should")
	print("square on a pad at %.1f m/s costs %.1f"
		% [boosted["speed"], boosted["cost"]])
	if boosted["cost"] <= full + 0.5:
		_fault("a boosted hit cost no more than one at top speed")


## Two seconds into a face with the throttle down. Every charge has to be at
## least obstacle_recovery after the one before, or a single mistake would take
## a car from whole to broken before the player could steer out of it. The car
## is given room to take all of it, so what is counted is the gate and not the
## car running out.
func _held_into_the_face() -> void:
	var kept := _car.max_condition
	_car.max_condition = 10000.0
	_car.repair()
	var held: Dictionary = await _hit(_car.max_speed, 0.0, true, 120)
	_car.max_condition = kept
	_car.repair()
	var frames: Array = held["frames"]
	var closest := 1 << 30
	for i in range(1, frames.size()):
		closest = mini(closest, int(frames[i]) - int(frames[i - 1]))
	print("held into a face for 2.0 s: charged %d times, never closer than %s"
		% [frames.size(),
			"%.2f s apart" % (closest * STEP) if frames.size() > 1 else "- only once"])
	var gate := int(round(_car.obstacle_recovery / STEP))
	if frames.size() > 1 and closest < gate - 1:
		_fault("a car held into a face was charged more often than obstacle_recovery")
	if frames.size() > int(2.0 / _car.obstacle_recovery) + 1:
		_fault("a car held into a face was charged too many times")


func _breaking() -> void:
	_car.repair()
	for i in 2:
		await _hit(_car.max_speed, 0.0, true)
	print("two flat-out hits leave %.0f%%, broken: %s"
		% [_car.condition() * 100.0, _car.is_broken()])
	if _car.is_broken():
		_fault("two hits broke the car")
	await _hit(_car.max_speed, 0.0, true)
	print("a third breaks it: %s" % _car.is_broken())
	if not _car.is_broken():
		_fault("three flat-out square hits did not break the car")

	_car.repair()
	for i in 2:
		await _hit(_car.max_speed, 0.0, true)
	await _hit(_car.max_speed / 3.0, 0.0, false)
	print("two and a third of one leave %.0f%%, broken: %s"
		% [_car.condition() * 100.0, _car.is_broken()])
	if _car.is_broken():
		_fault("two hits and a third of one broke the car")
	_car.repair()


func _rails() -> void:
	_car.repair()
	var square: Dictionary = await _hit(_car.max_speed, 0.0, true, 30, Car.ROAD_GROUP)
	var scrape: Dictionary = await _hit(_car.max_speed, 82.0, true, 60, Car.ROAD_GROUP)
	print("into a rail square costs %.1f, scraping down one costs %.1f"
		% [maxf(square["cost"], 0.0), maxf(scrape["cost"], 0.0)])
	if _car.condition() < 1.0:
		_fault("a rail cost condition")


## Broken over a hole, a car stays where it broke rather than dropping in.
func _in_the_air() -> void:
	_car.repair()
	_car._condition = 1.0
	_wall = _place(0.0, 0.3, 3.0, Car.OBSTACLE_GROUP)
	_car.reset_motion()
	_car._speed = _car.max_speed
	var broke_at := Vector3.INF
	for i in 30:
		await physics_frame
		if _car.is_broken() and broke_at == Vector3.INF:
			broke_at = _car.global_position
	for i in 30:
		await physics_frame
	_clear()
	if broke_at == Vector3.INF:
		_fault("a car in the air did not break on its last hit")
	else:
		print("broken %.2f m up, and %.2f m up half a second later"
			% [broke_at.y, _car.global_position.y])
		if _car.global_position.distance_to(broke_at) > 0.01:
			_fault("a car that broke in the air went on moving")
	_car.repair()


func _mending_and_smoke() -> void:
	_car.repair()
	await _hit(_car.max_speed, 0.0, true)
	var once := _car.condition()
	var smoke_once := (_car.get_node("Body") as CarShell).smoke_level()
	_car.reset_motion()
	if _car.condition() != once:
		_fault("being put back at a checkpoint changed the car's condition")
	await _hit(_car.max_speed, 0.0, true)
	var shell := _car.get_node("Body") as CarShell
	var smoke_twice := shell.smoke_level()
	print("smoke: %.2f at %.0f%%, %.2f at %.0f%%"
		% [smoke_once, once * 100.0, smoke_twice, _car.condition() * 100.0])
	if smoke_once > 0.0:
		_fault("a car one hit down is smoking")
	if smoke_twice <= 0.0:
		_fault("a car two hits down, past warning_at, is not smoking")
	_car.repair()
	print("repaired: %.0f%%, smoke %.2f" % [_car.condition() * 100.0, shell.smoke_level()])
	if _car.condition() < 1.0 or shell.smoke_level() > 0.0:
		_fault("repair did not put the car back as it was")


## With damage off nothing above may happen - and with it on, nothing about
## how the car moves may be any different until it breaks.
func _switched_off() -> void:
	# Room for every charge the held face costs, so the car being compared is
	# never one that has broken and stopped.
	var kept := _car.max_condition
	_car.max_condition = 10000.0
	_car.repair()
	var on: Dictionary = await _hit(_car.max_speed, 0.0, true, 90)
	_car.damage = false
	_car.repair()
	var off: Dictionary = await _hit(_car.max_speed, 0.0, true, 90)
	_car.max_condition = kept
	_car.repair()
	for i in 3:
		await _hit(_car.max_speed, 0.0, true)
	print("with damage off, three hits and a held face later: %.0f%%, broken: %s"
		% [_car.condition() * 100.0, _car.is_broken()])
	if _car.condition() < 1.0 or _car.is_broken():
		_fault("a car with damage off was worn down")

	var track_on: PackedVector3Array = on["track"]
	var track_off: PackedVector3Array = off["track"]
	var worst := 0.0
	for i in mini(track_on.size(), track_off.size()):
		worst = maxf(worst, track_on[i].distance_to(track_off[i]))
	print("the same hit with damage on and off drives %.4f m apart at worst" % worst)
	if track_on.size() != track_off.size() or worst > 0.001:
		_fault("damage changed how the car drives")
	_car.damage = true


## Drive the car at a wall and hand back what it cost: `speed` in m/s, `angle`
## off square in degrees, the throttle held or not, watched for `frames`. The
## car starts close enough that it arrives at the speed it was given. Returns
## the speed it hit at, the first charge, the step of every charge, and where
## the car was on every step.
func _hit(speed: float, angle: float, throttle: bool, frames := 30,
		group := Car.OBSTACLE_GROUP) -> Dictionary:
	var result := {"speed": 0.0, "cost": -1.0, "frames": [], "track": PackedVector3Array()}
	_wall = _place(angle, 0.3, 0.05, group)
	# Down onto the floor before it goes anywhere.
	for i in 10:
		_car._speed = 0.0
		await physics_frame
	_car.reset_motion()
	_car._speed = speed
	if speed > _car.max_speed:
		_car.boost()
	if throttle:
		Input.action_press("p1_accelerate")
	var was := _car._condition
	var going := speed
	for i in frames:
		await physics_frame
		(result["track"] as PackedVector3Array).append(_car.global_position)
		if _car._condition < was:
			if result["cost"] < 0.0:
				result["cost"] = was - _car._condition
				result["speed"] = going
			(result["frames"] as Array).append(i)
		was = _car._condition
		going = _car.speed()
	Input.action_release("p1_accelerate")
	if result["cost"] < 0.0:
		result["speed"] = speed
	_clear()
	return result


## Put the car down facing `angle` degrees off straight at a wall `gap` metres
## in front of its nose, `height` off the floor, and build the wall.
func _place(angle: float, gap: float, height: float, group: StringName) -> StaticBody3D:
	_clear()
	_car.frozen = true
	_car.global_position = Vector3(0.0, height, 0.0)
	_car.rotation = Vector3(0.0, deg_to_rad(angle), 0.0)
	var box := ((_car.get_node("Collision") as CollisionShape3D).shape as BoxShape3D).size
	var a := deg_to_rad(angle)
	var reach := box.z * 0.5 * cos(a) + box.x * 0.5 * sin(a)
	var wall := _box(Vector3(400.0, 6.0, 1.0),
		Vector3(0.0, 3.0, -(reach + gap + 0.5)))
	wall.add_to_group(group)
	_car.reset_motion()
	_car.frozen = false
	return wall


func _clear() -> void:
	if _wall != null:
		_wall.get_parent().remove_child(_wall)
		_wall.free()
		_wall = null


func _box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	_world.add_child(body)
	return body


# --- the races --------------------------------------------------------------

func _solo() -> void:
	var settings: Node = root.get_node(^"/root/GameSettings")
	var times: Node = root.get_node(^"/root/TrackTimes")
	settings.chaos = false

	# The setting off is a car that cannot be hurt, and no bar to say so.
	settings.damage = false
	settings.track_file = TrackRoster.file(0)
	var calm: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(calm)
	await physics_frame
	await process_frame
	var calm_car: Car = calm.get_node("Car")
	var calm_bar: Control = calm.get_node("Hud/Corner/Box/Condition/Bar")
	if calm_car.damage or calm_bar.visible:
		_fault("solo with damage off has a car that can be hurt, or shows the bar")
	calm.queue_free()
	await process_frame

	settings.damage = true
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	var car: Car = solo.get_node("Car")
	if not await _until(func() -> bool: return solo._running, 600):
		_fault("the solo run never started")
		solo.queue_free()
		return
	for i in 30:
		await physics_frame
	if not (solo.get_node("Hud/Corner/Box/Condition/Bar") as Control).visible:
		_fault("solo with damage on does not show the bar")

	car._condition = car.max_condition * 0.5
	solo._back_to_checkpoint()
	if car.condition() != 0.5:
		_fault("a checkpoint mended the car in solo")

	var best: float = times.best(settings.track_file)
	car._condition = 0.0
	for i in 2:
		await physics_frame
	var stopped: float = solo._time
	for i in 30:
		await physics_frame
	var medal: Label = solo._result_medal
	print("solo, broken: running %s, panel %s \"%s  %s\", clock held at %s"
		% [solo._running, solo._result.visible, medal.text,
			(solo._result_note as Label).text, RaceClock.format(stopped)])
	if solo._running or not solo._result.visible or medal.text != "BROKEN":
		_fault("breaking the car did not end the solo run")
	if not is_equal_approx(solo._time, stopped):
		_fault("the clock went on after the car broke")
	if not is_equal_approx(times.best(settings.track_file), best):
		_fault("a broken run set a time")
	if not solo._choice.visible:
		_fault("a broken run on a track offers no way on")

	solo._restart()
	print("run again: %.0f%%" % (car.condition() * 100.0))
	if car.condition() < 1.0:
		_fault("running again did not mend the car")
	solo.queue_free()
	await process_frame
	settings.track_file = ""


func _two_players() -> void:
	var settings: Node = root.get_node(^"/root/GameSettings")
	settings.chaos = false
	settings.damage = true
	settings.track_file = ""

	# Behind the title nothing is being driven, whatever the setting says.
	var backdrop: Node = load("res://scenes/main.tscn").instantiate()
	backdrop.attract_mode = true
	root.add_child(backdrop)
	await physics_frame
	if (backdrop.get_node("Car1") as Car).damage or (backdrop.get_node("Car2") as Car).damage:
		_fault("the title screen's cars can be damaged")
	backdrop.queue_free()
	await process_frame

	var race: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(race)
	var one: Car = race.get_node("Car1")
	var two: Car = race.get_node("Car2")
	if not await _until(func() -> bool: return race._racing, 600):
		_fault("the two-player race never started")
		race.queue_free()
		return
	for i in 5:
		await physics_frame
	if not one.damage or not two.damage:
		_fault("two players with damage on have cars that cannot be hurt")

	two._condition = 0.0
	for i in 2:
		await physics_frame
	var said: String = (race._results[0] as Label).text.replace("\n", " / ")
	print("two players, one broken: \"%s\"" % said)
	var winner: String = race._colour_name(one.body_color)
	if race._racing or not said.begins_with(winner + " WINS") or not said.contains("BROKE DOWN"):
		_fault("one car breaking did not hand the course to the other")

	if not await _until(func() -> bool: return race._racing, 900):
		_fault("the next race never started")
		race.queue_free()
		return
	for i in 5:
		await physics_frame
	if one.condition() < 1.0 or two.condition() < 1.0:
		_fault("a new course did not mend the cars")
	one._condition = 0.0
	two._condition = 0.0
	for i in 2:
		await physics_frame
	said = (race._results[0] as Label).text.replace("\n", " / ")
	print("two players, both broken on one step: \"%s\"" % said)
	if not said.begins_with("DRAW"):
		_fault("both cars breaking together was not a draw")
	race.queue_free()
	await process_frame


func _until(done: Callable, frames: int) -> bool:
	for i in frames:
		if done.call():
			return true
		await physics_frame
	return done.call()


func _fault(what: String) -> void:
	print("  " + what)
	_faults += 1
