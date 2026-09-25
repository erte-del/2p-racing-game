extends Node

## Lifetime totals: how far the cars have been driven, how many races were
## finished and how many won, how many cars were wrecked, how many coins were
## picked up.
##
## One record for the machine, for the reason there is one purse: two people on
## a split screen are sharing a keyboard, and a win by whoever was in the top
## half is a win this machine has. So a two-player course is one race and at
## most one win, whichever half took it.
##
## Kept apart from GameSettings because a total is something that happened, not
## something chosen. Kept apart from `TrackTimes` because a total is not a
## record: it is never beaten, only added to. The best times are not copied in
## here - they live in `TrackTimes` already, and a second copy would be a second
## thing to disagree with the first. The page reads them from there.
##
## Nothing here goes to the server, and that was decided rather than forgotten.
## A time goes to `Leaderboard` because it means the same thing on every
## machine. A lifetime total does not, and syncing one would need a rule for
## merging every counter in the file.
##
## No fingerprint either, unlike a time. A lap time stops meaning anything when
## the track under it is edited; a distance does not. The kilometres driven on
## the old track seven were still driven.
##
## What each number means is settled in the README, under Statistics, and the
## calls below are named for the thing that happened rather than the number
## they move, so a race scene says what went on and this decides what it is
## worth. The rules worth repeating at the call sites are repeated there.

const SAVE_PATH := "user://stats.cfg"

## The one section everything lives in. `TrackTimes` and `Progress` give each
## track or block a section of its own, because what they keep grows a section
## at a time. This is a fixed handful of counters that grows by nothing, so a
## section per key would be noise.
const TOTALS := "totals"

## How many seconds of driving are held in memory before they are written
## down anyway, whatever else is going on. See `add_distance`.
const FLUSH_EVERY := 5.0

## Emitted whenever a total moves on the disk, so an open page can follow it.
signal changed

## Not a const, so a check can point at somewhere that is not the player's own
## record of what they have done.
var save_path := Sandbox.path(SAVE_PATH)

# The counters, as named variables rather than a dictionary of whatever keys
# turn up, so a misspelt one is a compile error rather than a quiet second
# statistic. Read them freely; move them only through the calls below, which
# are what write them down.

## Metres raced. Counted only while a race clock is running, never during the
## countdown or on a finished course, and only for cars a person drove - on a
## split screen that is both cars, so this is never "how far player one has
## driven".
var distance_metres := 0.0
## Seconds spent racing, once per race however many cars were in it.
var time_driven_seconds := 0.0
## Races that ended in a result, good or bad: a finish, a win, a loss, a
## breakdown, a draw, and every course crossed on the endless one. A run quit
## or restarted announced nothing and completes nothing.
var races_completed := 0
## The races among those that could have been won - bot races and two-player
## courses. What the win rate is worked out over; a solo time trial has nobody
## to beat and is not in here.
var races_contested := 0
## Races won: beating the bot, or on a two-player course being the car that got
## there first or did not break down. A draw is not a win.
var races_won := 0
## Cars worn to nothing that somebody was driving. The bot's car breaking is
## the player's win, not the player's wreck.
var cars_wrecked := 0
## Times somebody asked to go back to their last checkpoint. The bot asking is
## not counted.
var resets := 0
## Coins ever picked up. Not what is in the purse - the two part company the
## first time anything is bought, and the purse is the shop's number.
var coins_earned := 0

## Seconds of driving added since the last time anything was written down.
## Distance is the one count that moves every physics step, and writing sixty
## times a second would grind the disk for nothing.
var _held_seconds := 0.0


func _ready() -> void:
	load_stats()


## A window closed with the cross rather than through a menu still flushes. The
## race scene's own `_exit_tree` does too, but this is the one place sure to
## hear about it whatever scene is up.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		flush()


## Some driving. Held in memory rather than written, and flushed:
##
## - when a result is announced, since every other call here saves;
## - when the pause screen opens, and when a run is quit or restarted;
## - from the race scene's `_exit_tree`, and on the window's close request;
## - and after every `FLUSH_EVERY` seconds of driving, whatever else happens.
##
## A hard kill loses at most those few seconds, which is fine; writing on every
## physics step is not.
func add_distance(metres: float, seconds: float) -> void:
	if not is_finite(metres) or not is_finite(seconds):
		return
	distance_metres += maxf(metres, 0.0)
	var driven := maxf(seconds, 0.0)
	time_driven_seconds += driven
	_held_seconds += driven
	if _held_seconds >= FLUSH_EVERY:
		save_stats()


## Write down whatever driving is held in memory. Nothing to do when nothing
## is held, so it is cheap to call from everywhere a run can end.
func flush() -> void:
	if _held_seconds > 0.0:
		save_stats()


## A race ended in a result. `contested` when it was a race that could have
## been won at all; `won` when it was.
func race_finished(contested: bool, won: bool) -> void:
	races_completed += 1
	if contested:
		races_contested += 1
	# Only a contested race can be won. A caller that says otherwise is wrong,
	# and a win rate over a hundred per cent is how that would show.
	if contested and won:
		races_won += 1
	save_stats()


## A car somebody was driving was worn to nothing.
func wrecked(count := 1) -> void:
	if count <= 0:
		return
	cars_wrecked += count
	save_stats()


## Somebody pressed their reset key during a race.
func reset_taken() -> void:
	resets += 1
	save_stats()


## Coins picked up off the road.
func coins_collected(count := 1) -> void:
	if count <= 0:
		return
	coins_earned += count
	save_stats()


## Whether anything at all has been counted yet. A fresh profile is the first
## thing a new player sees on the page, and it should read as a page rather
## than a grid of zeros.
func is_empty() -> bool:
	return (distance_metres <= 0.0 and time_driven_seconds <= 0.0
		and races_completed == 0 and cars_wrecked == 0 and resets == 0
		and coins_earned == 0)


## Forget every total. Nothing in the game calls this yet; it is here for the
## day a page offers to start again, and for a check that wants to begin from
## a profile that has done nothing.
func forget() -> void:
	distance_metres = 0.0
	time_driven_seconds = 0.0
	races_completed = 0
	races_contested = 0
	races_won = 0
	cars_wrecked = 0
	resets = 0
	coins_earned = 0
	save_stats()


func save_stats() -> void:
	_held_seconds = 0.0
	var file := ConfigFile.new()
	file.set_value(TOTALS, "distance_metres", distance_metres)
	file.set_value(TOTALS, "time_driven_seconds", time_driven_seconds)
	file.set_value(TOTALS, "races_completed", races_completed)
	file.set_value(TOTALS, "races_contested", races_contested)
	file.set_value(TOTALS, "races_won", races_won)
	file.set_value(TOTALS, "cars_wrecked", cars_wrecked)
	file.set_value(TOTALS, "resets", resets)
	file.set_value(TOTALS, "coins_earned", coins_earned)
	file.save(save_path)
	changed.emit()


## Read the totals back. A missing file is a fresh profile. A damaged one is
## read as far as it makes sense: a key that is missing, is not a number, is
## negative or is not finite comes back as zero, so nothing a file says can put
## `-nan KM` on the page.
func load_stats() -> void:
	_held_seconds = 0.0
	var file := ConfigFile.new()
	var loaded := file.load(save_path) == OK
	distance_metres = _amount(file, loaded, "distance_metres")
	time_driven_seconds = _amount(file, loaded, "time_driven_seconds")
	races_completed = _count(file, loaded, "races_completed")
	races_contested = _count(file, loaded, "races_contested")
	races_won = _count(file, loaded, "races_won")
	cars_wrecked = _count(file, loaded, "cars_wrecked")
	resets = _count(file, loaded, "resets")
	coins_earned = _count(file, loaded, "coins_earned")
	# A file edited by hand can say more wins than races. Held to what the
	# races allow rather than trusted, for the same reason as above: the page
	# works a rate out of these, and it must never read over a hundred.
	races_contested = mini(races_contested, races_completed)
	races_won = mini(races_won, races_contested)


func _amount(file: ConfigFile, loaded: bool, key: String) -> float:
	if not loaded:
		return 0.0
	var value: Variant = file.get_value(TOTALS, key, 0.0)
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return 0.0
	var amount := float(value)
	if not is_finite(amount) or amount < 0.0:
		return 0.0
	return amount


func _count(file: ConfigFile, loaded: bool, key: String) -> int:
	return int(_amount(file, loaded, key))
