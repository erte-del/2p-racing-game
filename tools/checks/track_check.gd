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
	print("%d faults" % faults)
	quit(1 if faults > 0 else 0)


## Where each jump on the track is, since a ramp is the one piece whose
## length is not the author's to choose and is worth seeing spelled out.
func _jumps(track: Track, layout: TrackLayout) -> String:
	var out := PackedStringArray()
	for piece in layout.pieces:
		if piece.kind != TrackLayout.JUMP:
			continue
		out.append("\n  a jump at %.0f m: ramp to %.0f, hole to %.0f, road again to %.0f"
			% [piece.start_offset, piece.start_offset + track.ramp_length,
				piece.start_offset + track.ramp_length + track.jump_gap,
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
		var what := "pad" if placement.kind == TrackFeatures.BOOST_PAD else "barrier"
		if placement.offset < 0.0 or placement.offset + placement.length > track.length():
			found.append("the %s at %.0f m runs off the end of the course"
				% [what, placement.offset])
		if absf(placement.lateral) + placement.half_span > 1.001:
			found.append("the %s at %.0f m hangs over the kerb"
				% [what, placement.offset])
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
