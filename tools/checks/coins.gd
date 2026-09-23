extends SceneTree

# Check the coins on a run of courses, on every laid-out track, and drive
# through one.
#   Godot --path . --headless --fixed-fps 60 --script tools/checks/coins.gd -- [courses]
#
# A coin is the only thing on the road that pays, so the two things that can go
# wrong with one are that it is somewhere nobody can get to - which is money a
# player can see and never have - and that it pays more than once, which is the
# shop's prices quietly meaning nothing. Neither shows up on one course, so
# this drives a hundred of them, and then drives a car through a real coin to
# see what the purse does.
#
# It will not touch the player's own purse: every check under tools/ is
# sandboxed, so what it banks goes to a purse of its own. See Sandbox.

const COURSES := 100

## What every course has to carry. Written here rather than read off the
## planner, so that moving the planner's numbers without meaning to is caught
## rather than agreed with.
const FEWEST := 5
const MOST := 15

var _faults := 0


func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var courses := int(args[0]) if not args.is_empty() else COURSES

	# Chaos would reroll the shape of every course from a random seed the
	# moment the scene loaded, and the counts below would mean nothing to
	# compare. It gets a run of its own further down.
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings != null:
		settings.chaos = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	# The race loop would otherwise start once its countdown ran out, and every
	# course below would be generated out from under a race that thought it was
	# driving the last one.
	main.set_physics_process(false)
	var track: Track = main.get_node("Track")

	_check_the_purse()
	_check_the_courses(track, courses)
	_check_the_tracks(track)
	await _check_the_pickup(main, track)
	# Last, because rolling a chaos world leaves the track tuned the way chaos
	# tuned it, and nothing after this should be driving a rolled road it did
	# not ask for.
	_check_chaos(main, track, courses)

	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


## The purse itself, before any road is involved: what goes in comes out, what
## is spent is gone, and nothing is bought twice.
func _check_the_purse() -> void:
	var purse := root.get_node_or_null(^"/root/Purse")
	if purse == null:
		_fault("there is no purse: the autoload is missing")
		return
	purse.forget()
	if purse.coins() != 0:
		_fault("a forgotten purse still has %d coins in it" % purse.coins())
	purse.bank()
	purse.bank(4)
	if purse.coins() != 5:
		_fault("one coin and four more came to %d" % purse.coins())
	if purse.spend(9):
		_fault("a purse with five coins in it paid nine")
	if purse.coins() != 5:
		_fault("a purse that could not pay was charged anyway")
	if not purse.buy("a hat", 3) or purse.coins() != 2 or not purse.owns("a hat"):
		_fault("buying something for three left %d coins and owns=%s"
			% [purse.coins(), purse.owns("a hat")])
	if purse.buy("a hat", 3):
		_fault("the same thing was bought twice")

	# And that it survives being written down and read back, which is the whole
	# reason there is a file.
	purse.save_purse()
	purse.load_purse()
	if purse.coins() != 2 or not purse.owns("a hat"):
		_fault("a purse read back off disk had %d coins and owns=%s"
			% [purse.coins(), purse.owns("a hat")])
	purse.forget()


## A hundred rolled courses, and every coin on every one of them.
func _check_the_courses(track: Track, courses: int) -> void:
	var total := 0
	var fewest := 999
	var most := 0
	var lanes := {"fork": 0, "past a row": 0, "corner": 0, "open road": 0}

	for course in courses:
		track.generate(course * 977 + 1)
		var coins := track.features().of_kind(TrackFeatures.COIN)
		total += coins.size()
		fewest = mini(fewest, coins.size())
		most = maxi(most, coins.size())
		if coins.size() < FEWEST or coins.size() > MOST:
			_fault("course %d carries %d coins" % [course, coins.size()])
		for coin in coins:
			lanes[_where(track, coin)] += 1
		_check_the_coins(track, course)

	print("%d courses, %d coins, %.1f per course, fewest %d, most %d"
		% [courses, total, float(total) / float(courses), fewest, most])
	var where := PackedStringArray()
	for lane in lanes:
		where.append("%d %s" % [lanes[lane], lane])
	print("where they are: %s" % ", ".join(where))
	# Coins in the interesting places rather than scattered evenly. Loose, on
	# purpose: this is a weighting and not a rule, and a check that pinned it
	# would have to be re-tuned every time one of the weights moved.
	if lanes["open road"] > total / 2:
		_fault("%d of %d coins are on open road: the weighting is not working"
			% [lanes["open road"], total])


## Every laid-out track, which gets its coins from the same pass a rolled
## course does even though everything else on it was written down.
func _check_the_tracks(track: Track) -> void:
	var shortest := ""
	var fewest := 999
	for index in TrackRoster.TOTAL:
		if not TrackRoster.exists(index):
			continue
		var file := TrackRoster.file(index)
		var script: GDScript = load(file)
		track.lay_out(script.new())
		var coins := track.features().of_kind(TrackFeatures.COIN)
		if coins.size() < FEWEST or coins.size() > MOST:
			_fault("%s carries %d coins" % [file.get_file(), coins.size()])
		if coins.size() < fewest:
			fewest = coins.size()
			shortest = file.get_file()
		_check_the_coins(track, -1, file.get_file())
		# A high road is not a course and has no coins of its own: one there
		# would be change the course's own count knows nothing about.
		for road in track.branches():
			var extra := road.features().of_kind(TrackFeatures.COIN)
			if not extra.is_empty():
				_fault("a high road off %s carries %d coins"
					% [file.get_file(), extra.size()])

		# The same track twice is the same coins. A player who learned where
		# they were yesterday is remembering the road, not guessing.
		var was := _laterals(coins)
		track.lay_out(script.new())
		if _laterals(track.features().of_kind(TrackFeatures.COIN)) != was:
			_fault("%s put its coins somewhere else the second time"
				% file.get_file())
	print("every laid-out track carries coins; the thinnest is %s with %d"
		% [shortest, fewest])


## Chaos rerolls where the coins are, because it rerolls the road. What it must
## not do is reroll how many there are: a chaos run that paid better would be
## the quick way to a full purse rather than a different race.
func _check_chaos(main: Node, track: Track, courses: int) -> void:
	var settings := root.get_node_or_null(^"/root/GameSettings")
	if settings == null:
		return
	var cars: Array[Car] = [main.get_node("Car1")]
	var chaos := Chaos.new(cars, null, track)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var total := 0
	var runs: int = maxi(courses / 4, 8)
	for course in runs:
		chaos.reroll(rng)
		track.generate(course * 613 + 7)
		var coins := track.features().of_kind(TrackFeatures.COIN)
		total += coins.size()
		if coins.size() < FEWEST or coins.size() > MOST:
			_fault("chaos course %d carries %d coins" % [course, coins.size()])
		_check_the_coins(track, course, "chaos")
	print("%d chaos courses, %.1f coins per course"
		% [runs, float(total) / float(runs)])


## Every rule one coin on one course has to keep.
func _check_the_coins(track: Track, course: int, what := "") -> void:
	var named := what if not what.is_empty() else "course %d" % course
	var features := track.features()
	var layout := track.layout()
	# The planner's own account of what is wrong with the plan, which is where
	# "inside something", "behind something" and "off the road" are decided -
	# asked here so the two can never drift apart.
	for problem in features.faults(layout):
		if problem.begins_with("coin"):
			_fault("%s: %s" % [named, problem])

	var marks := PackedFloat32Array([track.start_offset(), track.finish_offset()])
	marks.append_array(track.checkpoint_offsets())
	var coins := features.of_kind(TrackFeatures.COIN)
	for i in coins.size():
		var coin := coins[i]
		for mark in marks:
			if absf(coin.centre() - mark) < 18.0:
				_fault("%s: a coin at %.0f m is on a line at %.0f m"
					% [named, coin.centre(), mark])
		if coin.centre() < 0.0 or coin.centre() > track.length():
			_fault("%s: a coin at %.0f m is not on the course" % [named, coin.centre()])
		# Two coins in the same place are one coin a player can see and a
		# second they cannot.
		for other in coins.slice(i + 1):
			if absf(coin.centre() - other.centre()) < 1.0:
				_fault("%s: two coins stand at %.0f m" % [named, coin.centre()])


## Laying coins out correctly is worth nothing if driving through one does not
## pay. Park a car in a coin and see what the purse does - and leave it sitting
## there, because a coin that pays for as long as a car is inside it is a coin
## that pays for ever.
func _check_the_pickup(main: Node, track: Track) -> void:
	var purse := root.get_node_or_null(^"/root/Purse")
	if purse == null:
		return
	var car: Car = main.get_node("Car1")
	car.frozen = true

	for course in range(1, 40):
		track.generate(course * 977)
		var coins := track.features().of_kind(TrackFeatures.COIN)
		if coins.is_empty():
			continue
		var coin: TrackFeatures.Placement = coins[0]

		purse.forget()
		# In an array rather than a plain int: a lambda takes a copy of what it
		# closes over, so a counter it added to would be a counter only it
		# could see. An array is the same array on both sides.
		var taken := [0]
		var watching := func() -> void: taken[0] += 1
		track.coin_taken.connect(watching)

		car.reset_motion()
		await _park_at(main, track, coin, coin.lateral)
		if purse.coins() != 1:
			_fault("a car sitting in a coin banked %d" % purse.coins())
		if taken[0] != 1:
			_fault("driving through one coin was announced %d times" % taken[0])

		# Still sitting in it, a moment later.
		for i in 20:
			await physics_frame
		if purse.coins() != 1:
			_fault("a car left sitting in a coin banked %d" % purse.coins())

		# Away and back again: the same coin, taken twice, still one coin.
		car.reset_motion()
		await _park_at(main, track, coin, coin.lateral, 40.0)
		car.reset_motion()
		await _park_at(main, track, coin, coin.lateral)
		if purse.coins() != 1:
			_fault("a coin driven through twice banked %d" % purse.coins())

		# And a car alongside it, on the road, which should come away with
		# nothing.
		var beside := coin.lateral + (1.5 if coin.lateral <= 0.0 else -1.5) * (
				coin.half_span * 2.0 + 0.2)
		if absf(beside) < 1.0:
			car.reset_motion()
			await _park_at(main, track, coin, beside)
			if purse.coins() != 1:
				_fault("a car alongside a coin picked one up anyway")

		# A fresh course takes its coins with it: the ones that were taken do
		# not come back as taken, and the new ones pay.
		var banked: int = purse.coins()
		track.generate(course * 977 + 3)
		var fresh := track.features().of_kind(TrackFeatures.COIN)
		if not fresh.is_empty():
			car.reset_motion()
			await _park_at(main, track, fresh[0], fresh[0].lateral)
			if purse.coins() != banked + 1:
				_fault("a coin on the next course banked %d, not one"
					% (purse.coins() - banked))

		track.coin_taken.disconnect(watching)
		purse.forget()
		print("a coin pays one, once, and the purse holds it")
		return

	_fault("no course in the first 40 had a coin to drive through")


## Drop the car onto the road at a coin, across the road by `lateral` and
## `along` metres past it, and let the physics run long enough for the coin to
## notice it.
##
## Off `centre_at` rather than off the curve, which is not the same thing: the
## curve is a 3D line and a course offset is a distance along the flat, so on a
## course with a climb or two in it the two have drifted metres apart by the
## far end - and a coin is a metre wide.
func _park_at(
	main: Node, track: Track, coin: TrackFeatures.Placement,
	lateral: float, along := 0.0
) -> void:
	var at: float = clampf(coin.centre() + along, 0.0, track.length() - 1.0)
	var centre := track.centre_at(at)
	var ahead := track.centre_at(minf(at + 2.0, track.length()))
	var forward := (ahead - centre) * Vector3(1, 0, 1)
	var right := forward.normalized().cross(Vector3.UP)
	var car: Car = main.get_node("Car1")
	car.global_position = (centre
		+ right * (lateral * track.half_width_at(at)) + Vector3.UP * 0.5)
	for i in 6:
		await physics_frame


## Which of the interesting places a coin ended up in, for the tally. The same
## order the planner looks in, so the two agree about what a coin is doing.
func _where(track: Track, coin: TrackFeatures.Placement) -> String:
	var at := coin.centre()
	for fork in track.features().of_kind(TrackFeatures.FORK):
		if at >= fork.offset and at < fork.offset + fork.length:
			return "fork"
	for row in track.features().rows():
		if row.moves():
			continue
		var behind := at - (row.offset + row.length)
		if behind >= 5.0 and behind <= 16.0:
			return "past a row"
	for piece in track.layout().pieces:
		if at >= piece.start_offset and at < piece.end_offset:
			if piece.kind == TrackLayout.CORNER:
				return "corner"
	return "open road"


func _laterals(coins: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for coin in coins:
		out.append(coin.centre())
		out.append(coin.lateral)
	return out


func _fault(why: String) -> void:
	print("  %s" % why)
	_faults += 1
