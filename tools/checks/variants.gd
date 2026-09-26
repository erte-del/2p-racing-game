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
# - every way of driving it is kept and sent under a key, fingerprint and
#   signature of its own
# - the track as written has exactly the fingerprint and signature it had
#   before variants existed. That is the one number in all of this that must
#   not move: every best time anybody has set is held against it.
#
# Nothing here writes a time. Everything it asks of the times is a hash.

var _faults := 0


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
		var wrong := _build(track, file, variant)
		if variant in offered:
			for problem in wrong:
				_fault("%s %s: %s" % [name, variant, problem])
		elif wrong.is_empty():
			_fault("%s: %s would build clean and is not offered" % [name, variant])
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

	# What the race got is what TrackVariant makes of the file, and not the
	# file as written or the file put through it twice.
	if _as_laid(track.definition()) != _as_laid(TrackVariant.described(file, variant)):
		found.append("the road built is not the road the variant describes")
	track.variant = TrackVariant.NORMAL
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


func _fault(message: String) -> void:
	print("  " + message)
	_faults += 1
