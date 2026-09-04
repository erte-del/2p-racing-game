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


## Write the current choices out. Called when a screen that was changing them
## is closed, rather than on every change, so dragging the volume slider does
## not write a file per frame.
func save_settings() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "volume", volume)
	file.set_value("world", "time_of_day", time_of_day)
	file.set_value("race", "chaos", chaos)
	file.save(SAVE_PATH)


func load_settings() -> void:
	var file := ConfigFile.new()
	if file.load(SAVE_PATH) != OK:
		return
	volume = float(file.get_value("audio", "volume", volume))
	time_of_day = int(file.get_value("world", "time_of_day", time_of_day))
	chaos = bool(file.get_value("race", "chaos", chaos))


## Silence is its own state: fading a bus to -80 dB is still audible on some
## mixes, so the bottom of the slider mutes outright.
func _apply_volume() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master < 0:
		return
	AudioServer.set_bus_mute(master, volume <= 0.0)
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(volume, 0.0001)))
