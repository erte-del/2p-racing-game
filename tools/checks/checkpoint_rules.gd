extends SceneTree

# Bank the checkpoints out of order, skip past one, and see what the finish
# makes of it.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/checkpoint_rules.gd
#
# A race is finished on the road with every checkpoint banked, and nothing
# less. The checkpoints can come in any order - a player who was put back
# somewhere odd, or took a wrong way round, still only has to have driven over
# each of them - but each one has to be driven over: coming back onto the road
# a little way past a checkpoint does not bank it.
#
# The car is put on the road and driven, so everything here goes through the
# race's own banking and its own finish, in a race that is really running.

## Metres short of a line the car is put on the road, and past it that it is
## driven to. Short, because barriers are only kept 18 m clear of a line.
const RUN := 12.0
## How fast it is driven over each line, in m/s.
const PACE := 20.0


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	settings.track_file = ""
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var waited := 0
	while not main.get("_racing") and waited < 600:
		await physics_frame
		waited += 1

	var track: Track = main.get_node("Track")
	var car: Car = main.get_node("Car1")
	var other: Car = main.get_node("Car2")
	var marks := track.checkpoint_offsets()
	var window: float = main.get("checkpoint_window")
	var tally: Label = main.get_node("Progress/Top/Label")
	var faults := 0
	var at := PackedStringArray()
	for mark in marks:
		at.append("%.0f" % mark)
	print("%d checkpoints at %s m, each banked within %.0f m past it; the finish at %.0f m"
		% [marks.size(), ", ".join(at), window, track.finish_offset()])

	await _over(track, car, other, track.finish_offset() - RUN)
	var racing: bool = main.get("_racing")
	print("over the finish on the road with nothing banked: %s"
		% ("the race went on" if racing else "the race ended"))
	if not racing:
		print("  a car finished without banking a single checkpoint")
		print("%d faults" % (faults + 1))
		quit(1)
		return

	await _over(track, car, other, marks[0] + window + 5.0)
	print("onto the road %.0f m past the first checkpoint and on: tally %s"
		% [window + 5.0, tally.text])
	if _banked(main) > 0:
		print("  coming back onto the road past a checkpoint banked it")
		faults += 1

	for index in range(marks.size() - 1, -1, -1):
		await _over(track, car, other, marks[index] - RUN)
		var respawn: float = main.get("_respawn")[0]
		print("over checkpoint %d at %.0f m: tally %s, a reset now goes to %.0f m"
			% [index + 1, marks[index], tally.text, respawn])
		if _banked(main) != marks.size() - index:
			print("  driving over a checkpoint out of order did not bank it")
			faults += 1
		if not is_equal_approx(respawn, marks[index]):
			print("  a reset does not go to the checkpoint banked last")
			faults += 1
		if not main.get("_racing"):
			print("  the race ended before the finish")
			faults += 1

	await _over(track, car, other, track.finish_offset() - RUN)
	racing = main.get("_racing")
	print("over the finish on the road with every checkpoint banked: %s"
		% ("the race went on" if racing else "the race ended"))
	if racing:
		print("  a car with every checkpoint banked did not finish")
		faults += 1

	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Put the car on the centreline at `from`, facing down the course, and drive
## it RUN * 2 metres on.
func _over(track: Track, car: Car, other: Car, from: float) -> void:
	var here := track.centre_at(from)
	var ahead := track.centre_at(minf(from + 2.0, track.length()))
	var forward := ahead - here
	forward.y = 0.0
	car.frozen = true
	car.global_position = here + Vector3.UP * 0.05
	car.look_at(car.global_position + forward.normalized(), Vector3.UP)
	car.reset_motion()
	for i in 10:
		car.frozen = false
		other.frozen = true
		car._speed = 0.0
		await physics_frame
	for i in int(RUN * 2.0 / PACE * 60.0):
		car.frozen = false
		other.frozen = true
		car._speed = PACE
		await physics_frame
	# Stopped where it is, so the next placement is not raced by the last run.
	car._speed = 0.0
	await physics_frame


func _banked(main: Node) -> int:
	return (main.get("_banked")[0] as PackedByteArray).count(1)
