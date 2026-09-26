extends SceneTree

# Build every way of driving every track, and hold each to what it claims.
#   Godot --path . --headless --script tools/checks/variants.gd
#
# A variant is a road nobody laid out. Its track was written and looked at; the
# mirrored copy of it was made by `TrackVariant` and has never been looked at
# by anyone, so this is the only thing that has. It asks four things of every
# track:
#
# - every way the track offers builds with nothing wrong with it, by the rules
#   a hand-made track is held to, and every way that would build clean but is
#   not offered is reported, so no track quietly misses out on one
# - a mirror is its own inverse, to the millimetre - the quickest way to catch
#   a sign that was flipped twice or not at all - and the same length as the
#   track it was made from
# - so is a reverse, as a road: driven back the other way it is the track as
#   written, hole for hole and barrier for barrier, and every hole in it is
#   where a hole was
# - every way of driving it is kept and sent under a key, fingerprint and
#   signature of its own
# - the track as written has exactly the fingerprint and signature it had
#   before variants existed. That is the one number in all of this that must
#   not move: every best time anybody has set is held against it.
#
# Nothing here writes a time. Everything it asks of the times is a hash.

var _faults := 0


## A jump that drops five metres. Reversed, it would have to climb five, which
## is more than a level jump can reach.
class Drop extends TrackDefinition:
	func describe() -> void:
		track_name = "Drop"
		straight(80.0)
		jump(-5.0)
		straight(80.0)


## A jump off a thirty-metre run-up. Reversed, that run-up is all the landing
## there is, and it is too short to come down on.
class ShortRunUp extends TrackDefinition:
	func describe() -> void:
		track_name = "Short run-up"
		straight(80.0)
		corner(90.0, 30.0)
		straight(30.0)
		jump()
		straight(80.0)


func _init() -> void:
	await process_frame
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.chaos = false
	var times: Node = root.get_node_or_null(^"/root/TrackTimes")
	if times == null:
		print("  TrackTimes is not loaded")
		quit(1)
		return

	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	# Nothing is raced here, and the race loop would otherwise start once its
	# countdown ran out, on whichever track happened to be built last.
	main.set_physics_process(false)
	var track: Track = main.get_node("Track")

	var files: Array = TrackRoster.FILES + TrackRoster.ACROBATIC_FILES
	for file: String in files:
		_check_the_names(times, file)
		_check_the_mirror(file)
		if file in TrackRoster.FILES:
			_check_the_reverse(file)
		_check_what_is_offered(track, file)

	_check_what_is_not_a_track()
	_check_the_check()

	print("%d tracks, %d faults" % [files.size(), _faults])
	quit(1 if _faults > 0 else 0)


## The track as written keeps the fingerprint and signature it always had, and
## no two ways of driving it share a key, a fingerprint or a signature.
func _check_the_names(times: Node, file: String) -> void:
	var name := file.get_file().get_basename()
	var text: String = times.source(file)
	if text.is_empty():
		_fault("%s: no text to fingerprint" % name)
		return
	# Worked out by the old route, by hand, rather than asked of anything that
	# knows about variants.
	var material := "%d\n%s" % [times.GEOMETRY, text]
	if times.fingerprint(file) != hash(material):
		_fault("%s: the fingerprint moved, and every time on it would be dropped" % name)
	if times.signature(file) != material.sha256_text():
		_fault("%s: the signature moved, and its board would empty" % name)

	var keys := {}
	var fingerprints := {}
	var signatures := {}
	for variant: String in TrackVariant.ALL:
		keys[TrackVariant.key(file, variant)] = true
		fingerprints[times.fingerprint(file, variant)] = true
		signatures[times.signature(file, variant)] = true
		var back := TrackVariant.split(TrackVariant.key(file, variant))
		if back != [name, variant]:
			_fault("%s: %s comes apart as %s" % [name, TrackVariant.key(file, variant), back])
	var ways := TrackVariant.ALL.size()
	if keys.size() != ways or fingerprints.size() != ways or signatures.size() != ways:
		_fault("%s: two ways of driving it share a key, fingerprint or signature" % name)


## Mirrored twice is the track as written, and mirrored once is not.
func _check_the_mirror(file: String) -> void:
	var name := file.get_file().get_basename()
	var base := TrackVariant.described(file, TrackVariant.NORMAL)
	var once := TrackVariant.described(file, TrackVariant.MIRROR)
	var twice := TrackVariant.described(file, TrackVariant.MIRROR)
	TrackVariant.mirror(twice)
	var as_written := TrackVariant.plan(base)
	if TrackVariant.plan(twice) != as_written:
		_fault("%s: mirrored twice is not the track as written" % name)
	if TrackVariant.plan(once) == as_written:
		_fault("%s: mirrored is the same as the track as written" % name)
	if not is_equal_approx(once.length(), base.length()):
		_fault("%s: mirrored is %.1f m long, and the track %.1f m"
			% [name, once.length(), base.length()])
	if once.targets != base.targets:
		_fault("%s: mirrored has targets of its own" % name)
	# Every corner turned the other way, not just the first.
	for i in base.pieces.size():
		if not is_equal_approx(once.pieces[i].turn, -base.pieces[i].turn):
			_fault("%s: piece %d turns %.3f mirrored, and %.3f as written"
				% [name, i, once.pieces[i].turn, base.pieces[i].turn])
			break
	for i in base.branches.size():
		var theirs: BranchDefinition = once.branches[i]
		var ours: BranchDefinition = base.branches[i]
		if not is_equal_approx(theirs.lane, -ours.lane):
			_fault("%s: a high road leaves from %+.2f mirrored, and %+.2f as written"
				% [name, theirs.lane, ours.lane])


## Reversed twice is the track as written, and reversed once is the same road
## the other way round: as long, with its holes where the holes were.
##
## Compared as the road that gets built, not piece for piece. Reversing a jump
## twice can move where the jump's piece ends and the straight after it begins
## - a short run-up makes a short landing, and the rest stays straight - and two
## level straights in a row are exactly the road one straight of both lengths
## is. What stands on the road is compared placement for placement.
func _check_the_reverse(file: String) -> void:
	var name := file.get_file().get_basename()
	var base := TrackVariant.described(file, TrackVariant.NORMAL)
	var once := TrackVariant.described(file, TrackVariant.REVERSE)
	var twice := TrackVariant.described(file, TrackVariant.REVERSE)
	TrackVariant.reverse(twice)
	if _road(twice) != _road(base) or _placed(twice) != _placed(base):
		_fault("%s: reversed twice is not the track as written" % name)
	if _road(once) == _road(base):
		_fault("%s: reversed is the same as the track as written" % name)
	if not is_equal_approx(once.length(), base.length()):
		_fault("%s: reversed is %.1f m long, and the track %.1f m"
			% [name, once.length(), base.length()])
	if once.targets != Vector3.ZERO:
		_fault("%s: reversed has medal targets nobody measured" % name)
	# Every hole where a hole was, read from the far end, within a sample: a
	# jump is built again from its parts, and the sample it rounds to may move.
	var ours := _holes(base)
	var theirs := _holes(once)
	var length := base.length()
	if ours.size() != theirs.size():
		_fault("%s: %d holes reversed, and %d as written" % [name, theirs.size(), ours.size()])
		return
	for i in ours.size():
		var mirrored := Vector2(length - ours[-1 - i].y, length - ours[-1 - i].x)
		if (absf(theirs[i].x - mirrored.x) > base.step + 0.01
				or absf(theirs[i].y - mirrored.y) > base.step + 0.01):
			_fault("%s: a hole reversed runs %.0f-%.0f m, where it was %.0f-%.0f m"
				% [name, theirs[i].x, theirs[i].y, mirrored.x, mirrored.y])


## The road a definition makes, sample by sample, to the millimetre: where the
## centreline goes, how wide it is, and whether there is road there at all.
func _road(definition: TrackDefinition) -> String:
	var layout := TrackLayout.adopt(definition.pieces, {"centred": false})
	var out := PackedStringArray()
	for i in layout.points.size():
		var point := layout.points[i]
		out.append("%.3f %.3f %.3f %.3f %d" % [point.x, point.y, point.z,
			layout.half_widths[i], layout.road_present[i]])
	return "\n".join(out)


## What stands on a definition's road, as `TrackVariant.plan` writes it.
func _placed(definition: TrackDefinition) -> String:
	return "\n".join(Array(TrackVariant.plan(definition).split("\n")).filter(
		func(line: String) -> bool: return line.begins_with("placement")))


## Where there is no road, from the start of each hole to its end, in metres.
func _holes(definition: TrackDefinition) -> Array[Vector2]:
	var layout := TrackLayout.adopt(definition.pieces, {"centred": false})
	var holes: Array[Vector2] = []
	var from := -1
	for i in layout.road_present.size():
		if layout.road_present[i] == 0 and from < 0:
			from = i
		elif layout.road_present[i] != 0 and from >= 0:
			holes.append(Vector2(from, i) * layout.step)
			from = -1
	return holes


## Every way the track is offered builds clean, and every way that would build
## clean is offered.
func _check_what_is_offered(track: Track, file: String) -> void:
	var name := file.get_file().get_basename()
	var offered := TrackVariant.offered(file)
	if offered.is_empty() or offered[0] != TrackVariant.NORMAL:
		_fault("%s: not offered as written" % name)
	for variant: String in TrackVariant.BUILT:
		if variant == TrackVariant.NORMAL:
			continue
		# An acrobatic track is never driven in reverse, whatever a build of it
		# would say: rings, platforms, lifts and high roads are aimed at where a
		# ramp throws a car, and no check here can tell that a platform is in
		# the wrong place for a car coming the other way.
		if variant == TrackVariant.REVERSE and file in TrackRoster.ACROBATIC_FILES:
			continue
		var wrong := _build(track, file, variant)
		if variant in offered:
			for problem in wrong:
				_fault("%s %s: %s" % [name, variant, problem])
		elif wrong.is_empty():
			_fault("%s: %s would build clean and is not offered" % [name, variant])
		elif file in TrackRoster.FILES and not TrackVariant.WHY_NOT.get(name, {}).has(variant):
			# The page says why a way is not offered, and a reason nobody wrote
			# down is a generic line where the real one should be.
			_fault("%s: does not offer %s and has no reason written down for it"
				% [name, variant])
	for variant: String in TrackVariant.WHY_NOT.get(name, {}):
		if variant in offered:
			_fault("%s: offers %s and has a reason written down for not offering it"
				% [name, variant])
	for variant: String in offered:
		if variant not in TrackVariant.BUILT:
			_fault("%s: offers %s, which nothing knows how to make yet" % [name, variant])
	print("%-24s %s" % [name, ", ".join(offered.map(
		func(v: String) -> String: return TrackVariant.display_name(v)))])


## Build a track one way, the way a race does - through its file and the
## `variant` on the node - and say what is wrong with it.
func _build(track: Track, file: String, variant: String) -> PackedStringArray:
	var found := PackedStringArray()
	track.track_file = file
	track.variant = variant
	track.generate(0)
	var layout := track.layout()
	if layout == null or track.definition() == null:
		found.append("did not build")
		return found
	found.append_array(layout.problems())
	found.append_array(track.features().faults(layout))
	for road in track.branches():
		if road.variant != TrackVariant.NORMAL:
			found.append("a high road was handed the variant, and would be put through it twice")
		for problem in road.layout().problems() + road.features().faults(road.layout()):
			# A high road does not start or end on a grid or a finish.
			if problem.contains("the grid needs") or problem.contains("the finish needs"):
				continue
			found.append("the high road: %s" % problem)
	found.append_array(track.branch_problems())
	found.append_array(_on_a_jump(track))

	# What the race got is what TrackVariant makes of the file, and not the
	# file as written or the file put through it twice.
	if _as_laid(track.definition()) != _as_laid(TrackVariant.described(file, variant)):
		found.append("the road built is not the road the variant describes")
	track.variant = TrackVariant.NORMAL
	return found


## Anything standing on a jump, or within the keep-out either side of one: the
## rule every hand-made track is held to by `track_check.gd`, and the one a
## reversed jump can break, since its landing is made of what was its run-up.
func _on_a_jump(track: Track) -> PackedStringArray:
	var found := PackedStringArray()
	var spans := track.jump_spans()
	for placement in track.features().placements:
		if placement.kind in [TrackFeatures.FORK, TrackFeatures.RING,
				TrackFeatures.PLATFORM, TrackFeatures.WEDGE, TrackFeatures.COIN]:
			continue
		for span in spans:
			if placement.offset < span.y and span.x < placement.offset + placement.length:
				found.append("something at %.0f m is standing on the jump at %.0f-%.0f m"
					% [placement.offset, span.x, span.y])
	return found


## A plan as `TrackVariant.plan` writes it, less the pieces of its high roads.
## Building a track stretches each high road with straight road until it meets
## the course again, which is the course's business and not the variant's - and
## a high road has no corners, so there is nothing in its pieces for a mirror to
## get wrong. Where it leaves from and what stands on it are still compared.
func _as_laid(definition: TrackDefinition) -> String:
	var kept := PackedStringArray()
	var on_a_high_road := false
	for line in TrackVariant.plan(definition).split("\n"):
		if line.begins_with("high road"):
			on_a_high_road = true
		if on_a_high_road and line.begins_with("piece"):
			continue
		kept.append(line)
	return "\n".join(kept)


## A road that is not a time trial offers nothing.
func _check_what_is_not_a_track() -> void:
	for file: String in TrackRoster.BOT_FILES + ["res://tracks/nothing_here.gd", ""]:
		if not TrackVariant.offered(file).is_empty():
			_fault("%s offers %s" % [file, TrackVariant.offered(file)])


## The comparison above has been seen to fail. A mirror with one lane left
## unturned is not its own inverse, and the plan has to notice - a check that
## has never said no has not been shown to work.
func _check_the_check() -> void:
	var file: String = TrackRoster.FILES[0]
	var base := TrackVariant.described(file, TrackVariant.NORMAL)
	var broken := TrackVariant.described(file, TrackVariant.MIRROR)
	var moved := false
	for placement in broken.placements:
		if not is_zero_approx(placement.lateral):
			placement.lateral = -placement.lateral
			moved = true
			break
	TrackVariant.mirror(broken)
	if not moved:
		_fault("the first track has nothing off the centreline to break a mirror with")
	elif TrackVariant.plan(broken) == TrackVariant.plan(base):
		_fault("a mirror with one lane left unturned passed for its own inverse")
	else:
		print("a mirror with one lane left unturned is caught")

	# And reverses that cannot be driven are refused by the rules the tracks
	# are built under, rather than quietly made into something else.
	for wrong: Array in [[Drop.new(), "lands 5.0 m up"], [ShortRunUp.new(), "to land on"]]:
		var definition: TrackDefinition = wrong[0]
		definition.describe()
		TrackVariant.reverse(definition)
		var problems := TrackLayout.adopt(definition.pieces).problems()
		var caught := Array(problems).any(func(p: String) -> bool: return p.contains(wrong[1]))
		if not caught:
			_fault("%s reversed was not refused: %s" % [definition.track_name, problems])
		else:
			print("%s reversed is refused" % definition.track_name.to_lower())


func _fault(message: String) -> void:
	print("  " + message)
	_faults += 1
