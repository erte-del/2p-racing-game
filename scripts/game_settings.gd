extends Node

## The handful of choices the players make on the title screen, kept in one
## place and remembered between runs.
##
## This is an autoload rather than state on the menu because the menu is thrown
## away the moment the race starts: the race scene has to be able to ask what
## was chosen, and the next run has to be able to ask what was chosen last
## time. Everything here is written to disk as it is settled, so quitting from
## the title screen keeps the choice.
##
## Nothing here reaches into the game itself. Whoever cares about a setting
## reads it and listens for `changed` - the day/night cycle does exactly that.

## How the sky should behave. Kept as plain constants rather than an enum so
## other scripts holding this node as an untyped autoload can still name them.
const NORMAL := 0
const ALWAYS_DAY := 1
const ALWAYS_NIGHT := 2

const SAVE_PATH := "user://settings.cfg"

## Where they actually go. A test run is sent somewhere else entirely; see
## `Sandbox`.
var save_path := Sandbox.path(SAVE_PATH)

## Emitted whenever any setting changes, however it was changed.
signal changed

## Master volume, 0 to 1. There is no audio in the game yet, so this currently
## rides the master bus with nothing on it - it is wired up so that the day
## sound arrives it is already under the player's control.
var volume := 0.8:
	set(value):
		value = clampf(value, 0.0, 1.0)
		if is_equal_approx(value, volume):
			return
		volume = value
		_apply_volume()
		changed.emit()

## Whether the next race is driven alone or by two players sharing the
## keyboard. Asked before anything else, because it is the one choice that
## changes what every other choice means: the same endless course is a race
## against someone in co-op and a run against the clock alone.
var solo := true:
	set(value):
		if value == solo:
			return
		solo = value
		changed.emit()

## Whether infinite mode races under chaos rules: the cars, the shape of the
## course and the clock all rerolled for every race. What that actually
## changes lives in `Chaos` - this is only the choice the players made.
var chaos := false:
	set(value):
		if value == chaos:
			return
		chaos = value
		changed.emit()

## The laid-out track a race is about to be run on, or an empty string for
## the endless course. Not written to disk: it is what was picked on the way
## into this race rather than a preference, and a game that opened straight
## back onto the last track someone tried would be answering a question
## nobody asked.
var track_file := ""

## What each player's car is painted, player 1 first.
##
## Held as colours rather than as places in the palette, so a paint that is
## not on the palette is still a paint this can carry - and so that reordering
## the swatches one day cannot silently repaint somebody's car.
##
## Kept in an array rather than as two properties because everything that
## reads it is already looping over players, and because a one-car race is
## simply the same list read one entry deep.
var car_colours := PackedColorArray([
	Paints.default_for(0), Paints.default_for(1),
])


## Which car each player drives, player 1 first, by its garage id - and
## `Garage.STOCK` for the car the game ships with.
##
## Ids rather than places in the garage's list. The list changes every time a
## car is added or removed, and "the third one" silently becomes a different
## car the moment anything before it goes; an id is the same car for as long
## as there is one.
var car_ids := PackedStringArray(["", ""])


## One of NORMAL, ALWAYS_DAY, ALWAYS_NIGHT.
var time_of_day := NORMAL:
	set(value):
		if value == time_of_day:
			return
		time_of_day = value
		changed.emit()


func _ready() -> void:
	load_settings()
	_apply_volume()


## What a player's car is painted. Out of range answers with the default for
## player one rather than failing, so a mode that only has one car can ask
## without first checking how many there are.
func car_colour(player: int) -> Color:
	if player < 0 or player >= car_colours.size():
		return Paints.default_for(0)
	return car_colours[player]


## Repaint a player's car.
##
## Announced through `changed` like everything else here, which is what lets
## the paint appear on the car the moment the swatch is pressed: the race is
## already listening, and it repaints from this rather than being told to by
## whatever screen the press happened on.
func set_car_colour(player: int, colour: Color) -> void:
	if player < 0 or player >= car_colours.size():
		return
	if car_colours[player].is_equal_approx(colour):
		return
	car_colours[player] = colour
	changed.emit()


## Which car a player drives. Out of range answers with the stock car, for the
## same reason `car_colour` answers with a default: a mode with one car can ask
## about player two without checking first.
func car_id(player: int) -> String:
	if player < 0 or player >= car_ids.size():
		return Garage.STOCK
	return car_ids[player]


## Put a player in a different car.
##
## The same path paint takes. Nothing that picks a car ever touches one: it
## writes the choice here, and the race - already listening - dresses the car
## from it. Announced only when something actually changed, because announcing
## a car a player is already in has every listener rebuild nothing.
func set_car_id(player: int, id: String) -> void:
	if player < 0 or player >= car_ids.size():
		return
	if car_ids[player] == id:
		return
	car_ids[player] = id
	changed.emit()


## Write the current choices out. Called when a screen that was changing them
## is closed, rather than on every change, so dragging the volume slider does
## not write a file per frame.
func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "volume", volume)
	file.set_value("world", "time_of_day", time_of_day)
	file.set_value("race", "chaos", chaos)
	file.set_value("race", "solo", solo)
	for i in car_colours.size():
		file.set_value("cars", "colour_%d" % (i + 1), car_colours[i])
	for i in car_ids.size():
		file.set_value("cars", "model_%d" % (i + 1), car_ids[i])
	file.save(save_path)


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(save_path) != OK:
		return
	volume = float(file.get_value("audio", "volume", volume))
	time_of_day = int(file.get_value("world", "time_of_day", time_of_day))
	chaos = bool(file.get_value("race", "chaos", chaos))
	solo = bool(file.get_value("race", "solo", solo))
	for i in car_colours.size():
		# Checked rather than trusted: this file is on the player's disk, and
		# a car painted with whatever was in it is a crash rather than a
		# setting that failed to load.
		var stored: Variant = file.get_value(
			"cars", "colour_%d" % (i + 1), Paints.default_for(i))
		if stored is Color:
			car_colours[i] = stored
	for i in car_ids.size():
		# Taken as it is, not checked against the garage. The garage may not be
		# up yet, and a car that has since been deleted is not a broken setting:
		# `Garage.dress` drives an id it does not know as the stock car, and
		# the player's choice comes back the moment the car does.
		var stored: Variant = file.get_value("cars", "model_%d" % (i + 1), "")
		if stored is String:
			car_ids[i] = stored


## Silence is its own state: fading a bus to -80 dB is still audible on some
## mixes, so the bottom of the slider mutes outright.
func _apply_volume() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	AudioServer.set_bus_mute(master, volume <= 0.0)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(volume, 0.0001)))
