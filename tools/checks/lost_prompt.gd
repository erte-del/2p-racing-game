extends SceneTree

# Put a car on the grass and see whether the game says how to get back.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/lost_prompt.gd
#
# Off the road nothing counts: checkpoints are not banked there and the finish
# is not crossed there, so a player driving back towards the course is driving
# a lap that is already over. The way out is one key, shown once on a sheet
# before the race, and the line that now comes up in the middle of one is the
# only place it is said when it is needed.
#
# Which makes it worth more than a label. It has to come up when a car is
# actually lost - on the grass, and over the edge of a floating road, where
# nothing has landed on the car to tell it anything yet - and stay down when a
# car is merely clipping a verge. It has to name the key that is bound now
# rather than the one that was bound when it was written. And on a split screen
# it has to speak to one player without speaking to the other.
#
# So a real car is driven off real roads, in both modes, and what the label
# says is read back.

const ROAD := "res://tracks/01_first_light.gd"
## Metres out beyond the rail a car is put on the grass.
const OUT := 6.0
## How fast a car is driven along the grass, in m/s.
const CRAWL := 14.0
## How long the line may take to come up after a car leaves the road, on top of
## the wait it holds itself to: one fade, and a step or two of slack.
const SLACK := 0.3
## How long a car is driven down the middle of the road to prove the line stays
## down, in seconds.
const CLEAN := 5.0


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	settings.damage = false

	var faults := 0
	faults += await _on_a_road()
	faults += await _over_the_edge()
	faults += await _waiting_on_a_lift()
	faults += await _one_player_at_a_time()
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


# --- a car on the grass ---------------------------------------------------

## Solo, on a road with grass beside it: quiet while the car is on it, said
## when the car is off it, named after whichever key is bound at the time, and
## quiet again the moment the car is put back.
func _on_a_road() -> int:
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.track_file = ROAD
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	var lost: LostPrompt = solo.get_node("Hud/Lost")
	await _let_it_go(solo)
	var faults := 0

	# Down the middle of the road, which is not being lost.
	var spoke := await _down_the_road(solo, track, car, lost, CLEAN)
	print("%.0f s down the middle of the road: %s"
		% [CLEAN, "said \"%s\"" % spoke if not spoke.is_empty() else "nothing said"])
	if not spoke.is_empty():
		print("  a car on the road was told it was off it")
		faults += 1

	# Out on the grass beside it.
	var run := await _out_on_the_grass(solo, track, car, lost)
	print("out on the grass: %s after %.2f s off the road"
		% ["said \"%s\"" % run[1] if not String(run[1]).is_empty() else "nothing said",
			float(run[0])])
	faults += _judge(run, "R")

	# And put back, which is the line being taken.
	solo.call("_back_to_checkpoint")
	for i in 60:
		car._speed = 0.0
		await physics_frame
	print("a second after being put back at the checkpoint: %s"
		% ["still up" if lost.is_showing() else "gone"])
	if lost.is_showing():
		print("  the line stayed up after the car was put back on the road")
		faults += 1

	# The key is named, not assumed: moved, it is named where it is now.
	var was := InputMap.action_get_events("solo_reset")
	InputMap.action_erase_events("solo_reset")
	InputMap.action_add_event("solo_reset", _moved_to_k())
	run = await _out_on_the_grass(solo, track, car, lost)
	print("with the reset moved to K: %s"
		% ["said \"%s\"" % run[1] if not String(run[1]).is_empty() else "nothing said"])
	faults += _judge(run, "K")
	InputMap.action_erase_events("solo_reset")
	for event in was:
		InputMap.action_add_event("solo_reset", event)

	solo.queue_free()
	await process_frame
	return faults


## The reset put somewhere else, to prove the line reads the binding rather
## than remembering what it used to be.
func _moved_to_k() -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_K
	return event


# --- a car over the edge --------------------------------------------------

## The acrobatic tracks, where falling off is not landing on grass: a car that
## has gone over the side of a floating road is touching nothing at all, and
## nothing has told it that what it was driving on has ended. It should be told
## on the way down rather than on the way back up.
func _over_the_edge() -> int:
	var settings := root.get_node_or_null(^"/root/GameSettings")
	var faults := 0
	var tried := 0
	for file: String in TrackRoster.ACROBATIC_FILES:
		settings.track_file = file
		var solo: Node = load("res://scenes/solo.tscn").instantiate()
		root.add_child(solo)
		var track: Track = solo.get_node("Track")
		var car: Car = solo.get_node("Car")
		var lost: LostPrompt = solo.get_node("Hud/Lost")
		await _let_it_go(solo)

		var at := _somewhere_floating(track)
		if at < 0.0:
			solo.queue_free()
			await process_frame
			continue
		tried += 1
		# Beside the road, level with it, in the air: exactly where a car that
		# has just run out of road is.
		var centre := track.centre_at(at)
		var beside := (centre
			+ _right(track, at) * (track.half_width_at(at) + track.kerb_width + OUT))
		car.frozen = true
		car.global_position = beside
		car.look_at(beside + _heading(track, at), Vector3.UP)
		car.reset_motion()
		car.reset_physics_interpolation()
		car.frozen = false
		lost.forget()

		var run := await _wait_for_it(solo, lost, 6.0, func() -> void: car._speed = 0.0)
		var height: float = centre.y - car.global_position.y
		print("%-16s off the side at %.0f m, road %.0f m up: %s after %.2f s, %.0f m below it by then"
			% [track.definition().track_name, at, centre.y,
				"said" if not String(run[1]).is_empty() else "nothing said",
				float(run[0]), height])
		faults += _judge(run, "R")
		solo.queue_free()
		await process_frame
	if tried == 0:
		print("  no acrobatic track had a stretch of floating road to fall off")
		faults += 1
	return faults


## Somewhere on a track where the road is floating, with road either side of
## it, well clear of the ends. Below zero on a track with none.
func _somewhere_floating(track: Track) -> float:
	var layout := track.layout()
	if layout.floating.is_empty():
		return -1.0
	var reach: int = maxi(1, int(10.0 / layout.step))
	for i in range(reach, layout.floating.size() - reach):
		var at := float(i) * layout.step
		if at < track.start_offset() + 30.0 or at > track.finish_offset() - 30.0:
			continue
		var whole := true
		for k in range(i - reach, i + reach + 1):
			if layout.floating[k] == 0 or layout.road_present[k] == 0:
				whole = false
		if whole and track.centre_at(at).y > 8.0:
			return at
	return -1.0


# --- a car standing on a lift ---------------------------------------------

## The one place a car is legitimately a long way under the course and going
## nowhere: standing on a lift at the bottom of its cycle, waiting for the top.
## The course across a lift jump runs from the low road to a landing up above
## it, so a car down at the bottom is metres beneath the line the road takes -
## which is exactly what being over the edge looks like from a height alone.
## What tells them apart is the lift under the wheels, and this is the case
## that says so.
func _waiting_on_a_lift() -> int:
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.track_file = "res://tools/checks/lift_course.gd"
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	var lost: LostPrompt = solo.get_node("Hud/Lost")
	await _let_it_go(solo)
	var faults := 0

	var lifts := track.find_children("Platform", "AnimatableBody3D", true, false)
	if lifts.is_empty():
		print("  the lift course came out with no lift on it")
		solo.queue_free()
		await process_frame
		return 1
	var lift: Node3D = lifts[0]
	# Held at the bottom of the cycle: the clock is what moves a lift, so
	# winding it back every step is the lift standing still down there.
	solo.set("_time", 0.0)
	track.set_race_time(0.0)
	await physics_frame
	car.frozen = true
	car.global_position = lift.global_position + Vector3.UP * 1.2
	car.reset_motion()
	car.reset_physics_interpolation()
	car.frozen = false
	lost.forget()

	var under := 0.0
	for i in 240:
		solo.set("_time", 0.0)
		track.set_race_time(0.0)
		car._speed = 0.0
		await physics_frame
		var offset := track.offset_of(car.global_position)
		under = maxf(under, track.centre_at(offset).y - car.global_position.y)
	print("four seconds waiting on a lift, %.1f m under the course at the deepest: %s"
		% [under, "said \"%s\"" % lost.text if lost.is_showing() else "nothing said"])
	if lost.is_showing():
		print("  a car standing on a lift was told it had fallen off the road")
		faults += 1

	solo.queue_free()
	await process_frame
	return faults


# --- two players, one keyboard --------------------------------------------

## Split screen: the half whose car is on the grass is told, in its own words,
## and the other half is left alone.
func _one_player_at_a_time() -> int:
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.track_file = ROAD
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var waited := 0
	while not main.get("_racing") and waited < 600:
		await physics_frame
		waited += 1
	var track: Track = main.get_node("Track")
	var car: Car = main.get_node("Car1")
	var other: Car = main.get_node("Car2")
	var top: LostPrompt = main.get_node("Lost/Top/Label")
	var bottom: LostPrompt = main.get_node("Lost/Bottom/Label")
	var faults := 0

	# Player two out on the grass, player one held on the road.
	var at: float = track.start_offset() + 60.0
	var centre := track.centre_at(at)
	other.frozen = true
	other.global_position = (Vector3(centre.x, 0.05, centre.z)
		+ _right(track, at) * (track.half_width_at(at) + track.kerb_width + OUT))
	other.look_at(other.global_position + _heading(track, at), Vector3.UP)
	other.reset_motion()
	other.reset_physics_interpolation()
	bottom.forget()
	for i in 240:
		car.frozen = true
		other.frozen = false
		other._speed = CRAWL
		await physics_frame

	print("player two on the grass, player one on the road: the bottom half %s, the top half %s"
		% ["said \"%s\"" % bottom.text if bottom.is_showing() else "said nothing",
			"said \"%s\"" % top.text if top.is_showing() else "said nothing"])
	if not bottom.is_showing():
		print("  the player on the grass was not told how to get back")
		faults += 1
	elif not bottom.text.contains(" M "):
		print("  the player on the grass was named a key that is not their own reset")
		faults += 1
	if top.is_showing():
		print("  the player still on the road was told they were off it")
		faults += 1

	main.queue_free()
	await process_frame
	return faults


# --- shared ---------------------------------------------------------------

## Let the countdown out of the way and the car go. The clock has to be running
## for any of this: a car held on the grid is not lost, it is waiting.
func _let_it_go(solo: Node) -> void:
	var waited := 0
	while not solo.get("_running") and waited < 600:
		await physics_frame
		waited += 1


## Put the car on the grass beyond the right-hand rail and drive it along
## there. Returns how long it took to be told, and what it was told.
func _out_on_the_grass(solo: Node, track: Track, car: Car, lost: LostPrompt) -> Array:
	var at: float = track.start_offset() + 60.0
	var centre := track.centre_at(at)
	car.frozen = true
	car.global_position = (Vector3(centre.x, 0.05, centre.z)
		+ _right(track, at) * (track.half_width_at(at) + track.kerb_width + OUT))
	car.look_at(car.global_position + _heading(track, at), Vector3.UP)
	car.reset_motion()
	car.reset_physics_interpolation()
	car.frozen = false
	lost.forget()
	return await _wait_for_it(solo, lost, 6.0, func() -> void: car._speed = CRAWL)


## Drive the car down the middle of the road for `seconds`, and hand back
## whatever the line said if it said anything. Steered at a point a little way
## ahead, which is the same crude driver everything else here uses.
func _down_the_road(
	solo: Node, track: Track, car: Car, lost: LostPrompt, seconds: float
) -> String:
	var at: float = track.start_offset() + 20.0
	var centre := track.centre_at(at)
	car.frozen = true
	car.global_position = centre + Vector3.UP * 0.05
	car.look_at(car.global_position + _heading(track, at), Vector3.UP)
	car.reset_motion()
	car.reset_physics_interpolation()
	car.frozen = false
	lost.forget()
	for i in int(seconds * 60.0):
		var offset := track.offset_of(car.global_position)
		var aim := track.centre_at(minf(offset + 14.0, track.length()))
		var wanted := aim - car.global_position
		wanted.y = 0.0
		if wanted.length_squared() > 0.01:
			car.rotate_y(clampf((-car.global_transform.basis.z).signed_angle_to(
				wanted.normalized(), Vector3.UP), -0.05, 0.05))
		car._speed = CRAWL
		await physics_frame
		if lost.is_showing():
			return lost.text
	return ""


## Run until the line comes up or `patience` runs out, holding the car to
## whatever `each_step` does to it. Returns the seconds from the car leaving the
## road - not from the start - and what the line said, or an empty string.
func _wait_for_it(
	solo: Node, lost: LostPrompt, patience: float, each_step: Callable
) -> Array:
	var left := -1.0
	var clock := 0.0
	for i in int(patience * 60.0):
		each_step.call()
		await physics_frame
		clock += 1.0 / 60.0
		if left < 0.0 and not solo.get("_running"):
			# The run ended under it, which is not what is being asked about.
			break
		if left < 0.0 and _is_off(lost):
			left = clock
		if lost.is_showing():
			return [clock - maxf(left, 0.0), lost.text]
	return [clock - maxf(left, 0.0), ""]


## Whether the prompt itself thinks the car is off the road, asked of the same
## rule the prompt uses rather than a second copy of it.
func _is_off(lost: LostPrompt) -> bool:
	return float(lost.get("_away")) > 0.0


## Whether the line came up in time and named the right key.
func _judge(run: Array, key: String) -> int:
	var said := String(run[1])
	var took := float(run[0])
	var faults := 0
	if said.is_empty():
		print("  a car off the road was never told how to get back")
		return 1
	if took > _patience() + SLACK:
		print("  the line took %.2f s to come up, which is longer than the %.2f s it holds itself to"
			% [took, _patience() + SLACK])
		faults += 1
	if not said.contains(" %s " % key):
		print("  the line said \"%s\", which does not name %s" % [said, key])
		faults += 1
	return faults


## How long the prompt waits before speaking, read off the prompt rather than
## written down twice.
func _patience() -> float:
	var prompt := LostPrompt.new()
	var waited: float = prompt.patience + prompt.fade_seconds
	prompt.free()
	return waited


func _heading(track: Track, at: float) -> Vector3:
	var here := track.centre_at(clampf(at, 0.0, track.length()))
	var ahead := track.centre_at(clampf(at + 2.0, 0.0, track.length()))
	var forward := ahead - here
	forward.y = 0.0
	return forward.normalized()


func _right(track: Track, at: float) -> Vector3:
	return _heading(track, at).cross(Vector3.UP)
