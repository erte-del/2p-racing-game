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

## How far the interface may be scaled either side of the size it is laid out
## at. The ceiling is what decides how much room a page is guaranteed: the
## interface is laid out in a 1600x900 space, so at 1.2 a page has 1333x750 to
## fit inside, which is still more than the 1280x720 every page was originally
## built for. There is deliberately no setting that takes it back to the size
## it used to be - that size was the complaint.
const UI_SCALE_MIN := 0.75
const UI_SCALE_MAX := 1.2

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

## How big the interface is drawn, as a multiple of the size it is laid out
## at. One is that size; below one is smaller.
##
## This is not a second set of sizes. Everything on a menu is a number in a
## 1600x900 space that Godot scales to fill the window, and this rides on top
## of that scale, so one setting moves every font, panel and margin in the
## game at once and none of them has to know about it. A player on a screen
## the laid-out size does not suit can therefore fix it without the game
## having to guess anything about their display.
var ui_scale := 1.0:
	set(value):
		value = clampf(value, UI_SCALE_MIN, UI_SCALE_MAX)
		if is_equal_approx(value, ui_scale):
			return
		ui_scale = value
		_apply_ui_scale()
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

## Whether hits wear the cars down until they break. Off until a player asks
## for it: the game has one punishment for a mistake and it is time, and a
## player who never chose a second one should never meet it. What it actually
## does lives in `Car` - this is only the choice.
var damage := false:
	set(value):
		if value == damage:
			return
		damage = value
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
	_apply_ui_scale()


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
	file.set_value("interface", "ui_scale", ui_scale)
	file.set_value("world", "time_of_day", time_of_day)
	file.set_value("race", "chaos", chaos)
	file.set_value("race", "damage", damage)
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
	ui_scale = float(file.get_value("interface", "ui_scale", ui_scale))
	time_of_day = int(file.get_value("world", "time_of_day", time_of_day))
	chaos = bool(file.get_value("race", "chaos", chaos))
	damage = bool(file.get_value("race", "damage", damage))
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


## Godot's own scale on top of the stretch, which is the one place a size can
## be changed without any screen being rebuilt: the laid-out space shrinks or
## grows to suit and every control in it is measured against that. Nothing
## here reaches into a menu, and no menu has to listen for this.
##
## The split screen is the exception that takes care of itself - `SharpView`
## sizes each viewport from the laid-out space it is actually given, so the
## road goes on being drawn at the resolution of the monitor whatever this is.
func _apply_ui_scale() -> void:
	var window := get_window()
	if window == null:
		return
	window.content_scale_factor = ui_scale
