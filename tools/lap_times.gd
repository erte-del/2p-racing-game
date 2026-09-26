extends SceneTree

# Drive every laid-out track and say how long a lap took.
#   Godot --path . --headless --fixed-fps 60 --script tools/lap_times.gd
#   Godot --path . --headless --fixed-fps 60 --script tools/lap_times.gd -- 0.8333
#   Godot --path . --headless --fixed-fps 60 --script tools/lap_times.gd -- 1.0 res://tracks/acrobatic/a01_lift_off.gd
#   Godot --path . --headless --fixed-fps 60 --script tools/lap_times.gd -- reverse
#   Godot --path . --headless --fixed-fps 60 --script tools/lap_times.gd -- mirror res://tracks/03_the_weave.gd
#
# This is what the medal times are set from. A target has to be a fact about
# the road rather than a number somebody liked the look of, and the only way
# to get one is to drive it - so the same crude driver solo_run uses to prove
# the mode works is pointed at all twenty tracks in turn and timed.
#
# The lap it drives is a bad one. It is held flat out, it steers at a point
# fourteen metres ahead on the centreline rather than taking a line, and it
# gives back speed wherever that point is not straight in front of it. What
# makes it useful is not that it is fast but that it is the same on every
# track: the ratio between its lap and a good one is roughly constant, so one
# authored target - the forty seconds First Light was written around - sets
# the rest.
#
# The arguments come in any order, each known by its shape: a number scales the
# cars' top speed, for asking what a lap would have been worth before or after a
# retune without editing the car; a variant (`mirror`, `reverse`, `hard`) drives
# every track that offers it that way; and anything else is a track file, and
# only those are driven.
#
# With a variant, each normal track that offers it is driven twice, as written
# and then the variant way, and the line says how much longer the variant's lap
# took. That ratio is what the variant's targets are: the track's own ladder,
# gold, silver and bronze, each stretched by it and rounded to the second. The
# block printed at the end is those targets as `TrackVariant.TARGETS` wants
# them, so filling the table in is a paste. For MIRROR the ratio is the check
# on an argument rather than a number to paste: a mirrored lap is meant to be
# worth what the track's is, and a mirror more than `MIRROR_DRIFT` off is one
# that argument is wrong for.
#
# Those two laps are the game's own bot's, not this driver's. The crude lap
# is good enough to scale one authored target by, but it drives the centreline
# into slaloms and does not finish half the tracks, and a ratio needs both
# laps. The bot finishes every way of every normal track (variant_drive.gd
# holds it to that), and a ratio between two of its laps is a ratio between
# two roads, whatever it is worth against a player's. A lap it was put back
# during is printed and left out of the table: it is measuring the put-back as
# much as the road. The acrobatic tracks are not driven with a variant, since
# the bot drives roads and not rings; acrobatic_drive.gd -- mirror is where
# their mirrors are compared.
#
# Hard is not one to paste yet. The bot sees every row a long way off and
# dodges it perfectly, so its Hard lap is within a few per cent of its lap of
# the track as written - which says the rows cost nothing, and they cost a
# person reading them a great deal more than that. Its targets wait on a
# person driving it.

const LOOK_AHEAD := 14.0
## How far before a ring the driver starts lining up with it. Far enough to
## cross the whole road on a straight, which is what a ring off to one side asks
## a player to do.
const RING_LINE_UP := 90.0
## Give up on a track after this long, so one road that cannot be driven does
## not stop the other nineteen being timed.
const PATIENCE := 60 * 260
## How far a mirrored lap may come out from the track's own before the track
## needs targets of its own rather than sharing the track's. The car is the
## same on both sides; what is left is the driver's own lean, and the rounding
## of a lap to the frame.
const MIRROR_DRIFT := 0.01


func _init() -> void:
	await process_frame
	var scale := 1.0
	var variant := TrackVariant.NORMAL
	var files: Array = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.is_valid_float():
			scale = float(arg)
		elif arg in TrackVariant.ALL:
			variant = arg
		else:
			files.append(arg)
	# Named on the command line, only those: timing all thirty to set the
	# targets of one is several minutes of watching nothing change.
	if files.is_empty():
		files = TrackRoster.all_files()
	if variant != TrackVariant.NORMAL:
		files = files.filter(func(file: String) -> bool:
			return file in TrackRoster.FILES and variant in TrackVariant.offered(file))

	var settings := root.get_node_or_null(^"/root/GameSettings")
	settings.chaos = false
	# Pointed at a scratch file, so timing every track does not write itself
	# into the player's own record of what they have driven. One per variant,
	# so the four can be timed side by side.
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times != null:
		times.save_path = Sandbox.path("user://times_lap_tool%s.cfg"
			% TrackVariant.key("", variant))
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(times.save_path))
		times.load_times()

	print("driving at %.0f%% of tuned top speed" % (scale * 100.0))
	if variant == TrackVariant.NORMAL:
		print("%-4s %-16s %7s %8s %8s" % ["", "track", "metres", "lap", "m/s"])
	else:
		print("%-4s %-16s %8s %8s %8s   %s" % ["", "track", "lap",
			TrackVariant.display_name(variant).to_lower(), "ratio", "targets"])
	var table := PackedStringArray()
	var by_bot := variant != TrackVariant.NORMAL
	for file: String in files:
		var run := await _time(settings, file, TrackVariant.NORMAL, scale, by_bot)
		if variant == TrackVariant.NORMAL:
			print("%-4d %-16s %7.0f %8s %8.1f" % [TrackRoster.index_of(file) + 1,
				run["name"], run["metres"], _clock(run["lap"]),
				run["metres"] / maxf(run["lap"], 0.001)])
			continue
		var other := await _time(settings, file, variant, scale, by_bot)
		var line := "%-4d %-16s %8s %8s" % [TrackRoster.index_of(file) + 1,
			run["name"], _clock(run["lap"]), _clock(other["lap"])]
		if run["lap"] < 0.0 or other["lap"] < 0.0:
			print(line)
			continue
		if run["put_back"] > 0 or other["put_back"] > 0:
			print("%s   put back %d and %d times, left out" % [line, run["put_back"],
				other["put_back"]])
			continue
		var ratio: float = other["lap"] / run["lap"]
		var base := TrackRoster.targets(TrackRoster.index_of(file))
		var stretched := Vector3(roundf(base.x * ratio), roundf(base.y * ratio),
			roundf(base.z * ratio))
		var note := ""
		if variant == TrackVariant.MIRROR:
			note = "  same as the track" if absf(ratio - 1.0) <= MIRROR_DRIFT \
				else "  MORE THAN %.0f%% OFF: give it targets of its own" % (MIRROR_DRIFT * 100.0)
		print("%s %8.3f   %.0f/%.0f/%.0f%s" % [line, ratio, stretched.x, stretched.y,
			stretched.z, note])
		table.append('\t\t"%s": Vector3(%.1f, %.1f, %.1f),' % [
			file.get_file().get_basename(), stretched.x, stretched.y, stretched.z])

	# Only for a way the table is filled from. Mirror shares the track's, and
	# a Hard block would be the bot saying the rows cost nothing - see above.
	if variant == TrackVariant.HARD:
		print("\nno block for HARD: the bot's lap is no measure of how hard a row is to read")
	elif variant != TrackVariant.MIRROR and not table.is_empty():
		print("\n\t%s: {\n%s\n\t}," % [variant.to_upper(), "\n".join(table)])
	if times != null:
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(times.save_path))
	quit(0)


## One lap of a track driven one way, in a Solo of its own: the track's name,
## how long the road is, the lap, or -1 for a road the driver gave up on, and
## how many times the driver was put back on the way.
func _time(settings: Node, file: String, variant: String, scale: float,
		by_bot: bool) -> Dictionary:
	settings.track_file = file
	settings.track_variant = variant
	var solo: Node = load("res://scenes/solo.tscn").instantiate()
	root.add_child(solo)
	for i in 10:
		await physics_frame
	var track: Track = solo.get_node("Track")
	var car: Car = solo.get_node("Car")
	car.max_speed *= scale

	var waited := 0.0
	while not solo.get("_running") and waited < 8.0:
		await physics_frame
		waited += 1.0 / 60.0
	var put_back := [0]
	var finished := false
	if by_bot:
		finished = await _bot_drive(solo, track, car, put_back)
	else:
		finished = await _drive(solo, track, car)
	var run := {
		"name": track.definition().track_name,
		"metres": track.length(),
		"lap": solo.get("_time") if finished else -1.0,
		"put_back": put_back[0],
	}
	solo.queue_free()
	await process_frame
	return run


## The game's own bot round the track, the way variant_drive.gd drives it: on
## the pedals and the wheel, put back at its checkpoint when it asks to be.
## `put_back` counts how often, so a lap with a put-back in it can be told apart.
func _bot_drive(solo: Node, track: Track, car: Car, put_back: Array) -> bool:
	var bot := BotDriver.new(track, car)
	bot.finish_planning()
	car.driver = bot
	for i in PATIENCE:
		if not solo.get("_running"):
			car.driver = null
			return true
		bot.race_time = solo.get("_time")
		await physics_frame
		if bot.wants_reset() and solo.get("_running"):
			solo.call("_back_to_checkpoint")
			put_back[0] += 1
			if put_back[0] > 20:
				break
	car.driver = null
	return false


## Drive the car round by aiming it a little way further along the centreline,
## flat out where that aim point is straight ahead and slower where it is not.
## The same driver solo_run uses, for the same reason: it is not a good lap,
## but it is the same bad lap on every track.
func _drive(solo: Node, track: Track, car: Car) -> bool:
	var curve := track.curve()
	var to_track := track.global_transform.affine_inverse()
	var stuck := 0.0
	var resets := 0
	var was := -1.0
	for i in PATIENCE:
		if not solo.get("_running"):
			return true
		var offset: float = curve.get_closest_offset(to_track * car.global_position)
		var aim: float = minf(offset + LOOK_AHEAD, track.length())
		var target: Vector3 = _through_the_gap(track, aim, _across(track, offset, car))
		# A ring coming up is aimed at instead: through it is the only way on,
		# and the middle of the road is not through a ring off to one side.
		var ring_lane := _next_ring_lane(track, offset)
		if not is_nan(ring_lane):
			target = track.global_transform * (track.curve().sample_baked(aim)
				+ _right(track, aim) * (ring_lane * track.half_width_at(aim)))
		var forward := -car.global_transform.basis.z
		var wanted := target - car.global_position
		wanted.y = 0.0
		var turn := 0.0
		if wanted.length_squared() > 0.01:
			turn = forward.signed_angle_to(wanted.normalized(), Vector3.UP)
			car.rotate_y(clampf(turn, -0.05, 0.05))
		var pace: float = lerpf(1.0, 0.45, clampf(absf(turn) / 0.55, 0.0, 1.0))
		car._speed = maxf(car._speed, car.max_speed * pace)
		await physics_frame

		if offset - was < 0.5:
			stuck += 1.0 / 60.0
			if stuck > 3.0:
				solo.call("_back_to_checkpoint")
				stuck = 0.0
				resets += 1
				if resets > 20:
					return false
		else:
			stuck = 0.0
			was = offset
	return false


## The lane of the next ring within `RING_LINE_UP` metres ahead, or NAN if
## there is none that close.
func _next_ring_lane(track: Track, offset: float) -> float:
	if track.definition() == null:
		return NAN
	for placement in track.definition().placements:
		if placement.kind != TrackFeatures.RING:
			continue
		var ahead := placement.centre() - offset
		if ahead > 0.0 and ahead < RING_LINE_UP:
			return placement.lateral
	return NAN


## Where on the road to aim, in world space: the middle of whichever way past
## is nearest to where the car already is.
func _through_the_gap(track: Track, at: float, lateral: float) -> Vector3:
	var centre: Vector3 = track.curve().sample_baked(at)
	var lane := 0.0
	var nearest := INF
	for gap in track.features().gaps_at(track.layout(), at):
		var middle := (gap.x + gap.y) * 0.5
		if absf(middle - lateral) < nearest:
			nearest = absf(middle - lateral)
			lane = middle
	return track.global_transform * (
		centre + _right(track, at) * (lane * track.half_width_at(at)))


## How far across the road the car is, from -1 at the left edge to +1 at the
## right, which is the same way everything on the road is described.
func _across(track: Track, at: float, car: Car) -> float:
	var centre: Vector3 = track.global_transform * track.curve().sample_baked(at)
	var right: Vector3 = track.global_transform.basis * _right(track, at)
	var half: float = maxf(track.half_width_at(at), 0.001)
	return clampf((car.global_position - centre).dot(right.normalized()) / half,
		-1.0, 1.0)


## Which way is right, at a distance along the course, in the track's own space.
func _right(track: Track, at: float) -> Vector3:
	var curve := track.curve()
	var here: Vector3 = curve.sample_baked(at)
	var ahead: Vector3 = curve.sample_baked(minf(at + 2.0, track.length()))
	var forward := ahead - here
	forward.y = 0.0
	if forward.length_squared() < 0.000001:
		return Vector3.RIGHT
	return forward.normalized().cross(Vector3.UP)


func _clock(seconds: float) -> String:
	return "%.2f" % seconds if seconds >= 0.0 else "  -  "
