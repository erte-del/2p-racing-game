extends SceneTree

# Build a hand-made track and say what is wrong with it.
#   Godot --path . --headless --script tools/checks/track_check.gd -- [file]
#
# A generated course is one of thousands and a bad one is thrown away for the
# next. A hand-made one is the only one there is, so nothing here rejects it -
# it is built, and then told what a generated course would have been rerolled
# for: passing too close to itself, running off the ground, and every barrier
# rule the planner holds itself to.

const DEFAULT := "res://tracks/01_first_light.gd"


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if not args.is_empty() else DEFAULT

	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.chaos = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame

	var track: Track = main.get_node("Track")
	var script: GDScript = load(path)
	var definition: TrackDefinition = script.new()
	track.lay_out(definition)

	var layout := track.layout()
	var features := track.features()
	print("%s - %s" % [definition.track_name, definition.blurb])
	print("%.0f m from the line to the flag, %d pieces"
		% [track.length(), layout.pieces.size()])
	print("%s" % features.summary())
	print("start line at %.0f m, finish at %.0f m, respawns at %s"
		% [track.start_offset(), track.finish_offset(),
			_metres(track.checkpoint_offsets())])
	print("%s%s" % [_shape(layout), _jumps(track, layout)])

	print(_crossings(track, layout))

	var faults := 0
	for problem in layout.problems():
		print("  %s" % problem)
		faults += 1
	for problem in features.faults(layout):
		print("  %s" % problem)
		faults += 1
	for problem in _furniture_problems(track, layout, features):
		print("  %s" % problem)
		faults += 1
	# And each high road: its own shape and furniture, and where it meets the
	# course.
	for road in track.branches():
		print("a high road: %.0f m, %s" % [road.length(), road.features().summary()])
		for problem in road.layout().problems() + road.features().faults(road.layout()):
			# A high road does not start or end on a grid or a finish.
			if problem.contains("the grid needs") or problem.contains("the finish needs"):
				continue
			print("  the high road: %s" % problem)
			faults += 1
	for problem in track.branch_problems():
		print("  %s" % problem)
		faults += 1
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Where the course passes over itself, which is a thing worth seeing written
## down on a track built to do it. Two parts of the course closer than two roads
## wide across the ground, far enough apart along it to be a crossing rather
## than the road being itself.
func _crossings(track: Track, layout: TrackLayout) -> String:
	var out := PackedStringArray()
	var stride: int = maxi(1, int(5.0 / layout.step))
	var apart: int = maxi(3, int(60.0 / (layout.step * float(stride))))
	var last := -999.0
	for i in range(0, layout.points.size(), stride):
		for j in range(i + apart, layout.points.size(), stride):
			var a := track.centre_at(float(i) * layout.step)
			var b := track.centre_at(float(j) * layout.step)
			if Vector2(a.x - b.x, a.z - b.z).length() > 18.0:
				continue
			var at := float(i) * layout.step
			if at - last < 60.0:
				continue
			last = at
			out.append("crosses over itself at %.0f m and %.0f m, %.1f m apart in height"
				% [at, float(j) * layout.step, absf(a.y - b.y)])
			break
	return "\n".join(out) if not out.is_empty() else "never crosses over itself"


## Where each jump on the track is, since a ramp is the one piece whose
## length is not the author's to choose and is worth seeing spelled out.
func _jumps(track: Track, layout: TrackLayout) -> String:
	var out := PackedStringArray()
	for piece in layout.pieces:
		if piece.kind != TrackLayout.JUMP:
			continue
		out.append("\n  a jump at %.0f m: ramp to %.0f, hole to %.0f, road again to %.0f"
			% [piece.start_offset, piece.start_offset + track.ramp_length,
				piece.start_offset + track.ramp_length + layout.gap_of(piece),
				piece.end_offset])
	return "".join(out)


## What the track is made of, counted.
func _shape(layout: TrackLayout) -> String:
	var counts := {"straights": 0, "corners": 0, "climbs": 0, "jumps": 0}
	for piece in layout.pieces:
		match piece.kind:
			TrackLayout.CORNER: counts["corners"] += 1
			TrackLayout.CLIMB: counts["climbs"] += 1
			TrackLayout.JUMP: counts["jumps"] += 1
			_: counts["straights"] += 1
	return "%d straights, %d corners, %d climbs, %d jumps" % [
		counts["straights"], counts["corners"], counts["climbs"], counts["jumps"]]


## The things a hand-made plan can get wrong that a planned one cannot, because
## the planner would never have written them down: furniture off the end of the
## road, off the side of it, or standing on a jump.
func _furniture_problems(
	track: Track, layout: TrackLayout, features: TrackFeatures
) -> PackedStringArray:
	var found := PackedStringArray()
	for placement in features.placements:
		if placement.kind == TrackFeatures.FORK:
			# A fork marker is not built and does not stand anywhere: it
			# covers the stretch the fork runs over, and its lateral records
			# which side the fast lane is on rather than a position on the
			# road. The rules below are about things with edges.
			continue
		if placement.kind in [TrackFeatures.RING, TrackFeatures.PLATFORM, TrackFeatures.WEDGE]:
			# A ring stands in the air rather than on the road, and over a jump
			# is where it belongs. What it can get wrong is in faults().
			continue
		var what := "pad" if placement.kind == TrackFeatures.BOOST_PAD else (
				"trap" if placement.kind == TrackFeatures.TRAP else "barrier")
		if placement.offset < 0.0 or placement.offset + placement.length > track.length():
			found.append("the %s at %.0f m runs off the end of the course"
				% [what, placement.offset])
		# Everywhere a trap goes, not only where it starts.
		var laterals := placement.phases if placement.moves() else (
				PackedFloat32Array([placement.lateral]))
		for lateral in laterals:
			if absf(lateral) + placement.half_span > 1.001:
				found.append("the %s at %.0f m hangs over the kerb at %+.2f"
					% [what, placement.offset, lateral])
		for span in track.jump_spans():
			if placement.offset < span.y and span.x < placement.offset + placement.length:
				found.append("the %s at %.0f m is standing on a jump"
					% [what, placement.offset])
	return found


func _metres(offsets: PackedFloat32Array) -> String:
	var out := PackedStringArray()
	for offset in offsets:
		out.append("%.0f" % offset)
	return ", ".join(out) + " m"
