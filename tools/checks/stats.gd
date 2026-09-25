extends SceneTree

# Push on the lifetime totals, the store on its own.
#   Godot --path . --headless --script tools/checks/stats.gd
#
# A fresh profile is all zeros. Each call raises the thing it names and nothing
# else. The totals survive being written down and read back, and `forget()`
# clears every one of them. A damaged or partial file loads as zeros - without
# throwing, and without a negative or a nan that would end up on the page. And
# distance, which is held in memory rather than written every physics step, is
# on the disk after every flush the store itself is responsible for.
#
# What the race scenes feed it is the other half, and stats_race.gd drives it.
#
# The store is fetched out of the tree rather than named. A script run with
# --script is compiled before the autoloads have registered their names, so
# `Stats` is not an identifier here the way it is in the game's own scripts.

const SCRATCH := "user://stats_check.cfg"

## Every counter, by the name it is kept under.
const COUNTERS := [
	"distance_metres", "time_driven_seconds", "races_completed",
	"races_contested", "races_won", "cars_wrecked", "resets", "coins_earned",
]

var _faults := 0
var _stats: Node


func _init() -> void:
	await process_frame
	_stats = root.get_node_or_null(^"/root/Stats")
	if _stats == null:
		print("  the store is not loaded")
		quit(1)
		return
	_stats.save_path = Sandbox.path(SCRATCH)
	_wipe()
	_stats.load_stats()
	print("kept at %s" % _stats.save_path)

	_a_fresh_profile()
	_each_call_moves_its_own_count()
	_what_cannot_be_won()
	_totals_survive_a_reload()
	_forgetting()
	_damaged_files()
	_distance_is_flushed()

	_wipe()
	print("%d faults" % _faults)
	quit(1 if _faults > 0 else 0)


func _a_fresh_profile() -> void:
	for key in COUNTERS:
		if float(_stats.get(key)) != 0.0:
			_fault("a fresh profile has %s at %s" % [key, _stats.get(key)])
	if not _stats.is_empty():
		_fault("a fresh profile does not call itself empty")
	print("a fresh profile: all zeros")


## Every call, one at a time, from nothing: what it names moves, and nothing
## else does.
func _each_call_moves_its_own_count() -> void:
	var cases := [
		["add_distance", [120.0, 6.0], {"distance_metres": 120.0, "time_driven_seconds": 6.0}],
		["race_finished", [false, false], {"races_completed": 1}],
		["race_finished", [true, false], {"races_completed": 1, "races_contested": 1}],
		["race_finished", [true, true],
			{"races_completed": 1, "races_contested": 1, "races_won": 1}],
		["wrecked", [], {"cars_wrecked": 1}],
		["wrecked", [2], {"cars_wrecked": 2}],
		["reset_taken", [], {"resets": 1}],
		["coins_collected", [3], {"coins_earned": 3}],
	]
	for case in cases:
		_stats.forget()
		_stats.callv(case[0], case[1])
		var wanted: Dictionary = case[2]
		for key in COUNTERS:
			var should: float = float(wanted.get(key, 0.0))
			if not is_equal_approx(float(_stats.get(key)), should):
				_fault("%s%s left %s at %s, not %s"
					% [case[0], case[1], key, _stats.get(key), should])
	print("each call moves what it names and nothing else")

	# Nonsense is not a count.
	_stats.forget()
	_stats.add_distance(-50.0, -1.0)
	_stats.add_distance(NAN, 1.0)
	_stats.add_distance(1.0, INF)
	_stats.wrecked(0)
	_stats.coins_collected(-4)
	if not _stats.is_empty():
		_fault("a negative, a nan or a zero moved a count")


## A win on a race nobody could have won is a caller's mistake, and must not
## push the win rate over a hundred.
func _what_cannot_be_won() -> void:
	_stats.forget()
	_stats.race_finished(false, true)
	if _stats.races_won != 0:
		_fault("a solo run was counted as a win")


func _totals_survive_a_reload() -> void:
	_stats.forget()
	_stats.add_distance(1234.5, 61.0)
	_stats.race_finished(true, true)
	_stats.race_finished(false, false)
	_stats.wrecked()
	_stats.reset_taken()
	_stats.reset_taken()
	_stats.coins_collected(7)
	var before := _snapshot()
	_stats.load_stats()
	var after := _snapshot()
	if before != after:
		_fault("the totals changed on the way back from the disk: %s against %s"
			% [before, after])
	print("read back: %s" % after)


func _forgetting() -> void:
	_stats.add_distance(10.0, 1.0)
	_stats.forget()
	if not _stats.is_empty():
		_fault("forgetting left something behind: %s" % _snapshot())
	_stats.load_stats()
	if not _stats.is_empty():
		_fault("forgetting was not written down: %s" % _snapshot())


## Files nobody should have to trust: gone, empty, half written, edited by
## hand into nonsense.
func _damaged_files() -> void:
	var files := {
		"missing": null,
		"empty": "",
		"not a config file": "this is not [ a config file",
		"a partial one": "[totals]\nraces_completed=4\n",
		"negatives and nan": ("[totals]\ndistance_metres=-12.0\n"
			+ "time_driven_seconds=nan\nraces_completed=-3\ncoins_earned=inf\n"),
		"words where numbers go": "[totals]\nresets=\"lots\"\nraces_won=[1, 2]\n",
		"more wins than races": ("[totals]\nraces_completed=2\n"
			+ "races_contested=5\nraces_won=9\n"),
	}
	for named in files:
		_wipe()
		if files[named] != null:
			var out := FileAccess.open(_stats.save_path, FileAccess.WRITE)
			out.store_string(files[named])
			out.close()
		_stats.load_stats()
		for key in COUNTERS:
			var value := float(_stats.get(key))
			if not is_finite(value) or value < 0.0:
				_fault("%s put %s at %s" % [named, key, value])
		if _stats.races_won > _stats.races_contested \
				or _stats.races_contested > _stats.races_completed:
			_fault("%s left more wins than races: %s" % [named, _snapshot()])
	_wipe()
	_stats.load_stats()
	if _stats.races_completed != 0:
		_fault("the last damaged file was still being read")
	print("damaged files load as zeros where they make no sense")


## Distance is held in memory, so what matters is that it is on the disk after
## each of the flushes the store owns: an explicit flush, the running timer, and
## the window being closed. A result flushes it by saving, like any other count.
func _distance_is_flushed() -> void:
	_stats.forget()
	_stats.add_distance(30.0, 1.0)
	if _on_disk() != 0.0:
		_fault("a second of driving was written straight away")
	_stats.flush()
	if not is_equal_approx(_on_disk(), 30.0):
		_fault("flushing did not write the distance down: %s" % _on_disk())

	# The timer, counted in seconds driven.
	_stats.forget()
	var steps := int(ceil(_stats.FLUSH_EVERY * 60.0)) + 1
	for i in steps:
		_stats.add_distance(0.5, 1.0 / 60.0)
	if _on_disk() <= 0.0:
		_fault("%.0f s of driving went unwritten" % _stats.FLUSH_EVERY)

	# A result.
	_stats.forget()
	_stats.add_distance(40.0, 1.0)
	_stats.race_finished(false, false)
	if not is_equal_approx(_on_disk(), 40.0):
		_fault("a result did not take the distance with it: %s" % _on_disk())

	# The window closing.
	_stats.forget()
	_stats.add_distance(55.0, 1.0)
	_stats.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	if not is_equal_approx(_on_disk(), 55.0):
		_fault("closing the window lost the distance: %s" % _on_disk())
	print("distance held in memory is on the disk after every flush")


func _on_disk() -> float:
	var file := ConfigFile.new()
	if file.load(_stats.save_path) != OK:
		return 0.0
	return float(file.get_value("totals", "distance_metres", 0.0))


func _snapshot() -> Dictionary:
	var out := {}
	for key in COUNTERS:
		out[key] = _stats.get(key)
	return out


func _wipe() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_stats.save_path))


func _fault(what: String) -> void:
	print("  " + what)
	_faults += 1
