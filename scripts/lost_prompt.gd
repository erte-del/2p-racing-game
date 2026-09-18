class_name LostPrompt
extends Label

## Tells a player who has come off the road which key puts them back on it.
##
## Falling off is the one thing in this game the game will not undo for you.
## The grass is slow but it is drivable, and nothing out there stops a car, so
## a player who has slid down an embankment or dropped off a floating road can
## spend a long time driving towards a course they cannot rejoin: checkpoints
## and the finish only count on the road, so the lap they are still driving is
## already over. The key that ends it was shown to them once, on a sheet,
## before the race.
##
## So it is said again at the moment it is worth knowing, in their own half of
## the screen, naming the key that is actually bound to their own reset rather
## than the one that was bound when this was written. Both players have their
## own, and either can be moved.
##
## Held back for a moment first. Clipping the verge through a corner is not
## being lost, and a line that flashes up every time a wheel touches grass is
## one players learn to stop reading.

## How long a car has to be off the road before the line appears, in seconds.
@export var patience := 1.2
## How far below the road counts as having left it altogether, in metres.
## A car that has gone off the side of a floating road is touching nothing at
## all, so nothing has told it that it is off the road - it is only falling,
## and it should not have to land on the grass to be told what to press.
@export var drop := 5.0
## How long the line takes to fade up, and back out again.
@export var fade_seconds := 0.25

var _car: Car
var _track: Track
## The action this player's reset is on, e.g. "p1_reset".
var _action := ""
## Seconds the car has been off the road for, without a break.
var _away := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	hide()


## Follow one car on one course, and name one player's reset.
func watch(car: Car, track: Track, action: String) -> void:
	_car = car
	_track = track
	_action = action
	forget()


## Have another look, a physics step's worth.
##
## Asked by whichever mode is running rather than running itself, because only
## the mode knows whether the car is being driven: one held on the grid, or sat
## on a finished run, or parked behind the title screen, is not lost. The
## distance along the course comes in with it for the same reason the modes
## look it up once - finding the nearest point on the curve is a walk along the
## whole of it, and it is already being walked this step.
func check(delta: float, offset: float) -> void:
	if _car == null or _track == null:
		return
	_away = _away + delta if _lost(offset) else 0.0
	_fade(delta, _away > patience)


## Nothing to say: the car is on the line, or back at a checkpoint, or the run
## is over. The count goes with it, so a player who has just been put back is
## not told again the moment they touch grass on the way past.
func forget() -> void:
	_away = 0.0
	modulate.a = 0.0
	hide()


## Whether the line is being shown, for anything asking rather than watching.
func is_showing() -> bool:
	return visible and modulate.a > 0.5


## Off the road, or off the road and still on the way down.
##
## Standing on the grass answers itself. Falling does not: a car the physics
## has not reported touching anything keeps whatever it was last standing on,
## which is the right answer over a jump and the wrong one over the edge - so a
## car that has run out of floating road would go on believing it was on the
## road for the whole of the way down, and only be told once it had landed.
##
## What tells the two apart is where the road is. Across a jump the course
## runs straight from the lip to the landing, and a car in flight is following
## a curve that falls away, which puts it above that line the whole way over:
## clear the jump and you are never under the road at all. Come up short and
## you are, by as much as you are going to miss by. So being well under the
## course, with nothing at all beneath the wheels, is a car on its way down and
## nothing else - the wheels matter, because a car riding a lift down is under
## the course as well, and it is standing on the thing carrying it.
func _lost(offset: float) -> bool:
	if not _car.on_the_road():
		return true
	if _car.is_on_floor():
		return false
	return _car.global_position.y < _track.centre_at(offset).y - drop


func _fade(delta: float, wanted: bool) -> void:
	if wanted and not visible:
		text = _what_to_press()
		show()
	var to := 1.0 if wanted else 0.0
	modulate.a = move_toward(modulate.a, to, delta / maxf(fade_seconds, 0.001))
	if not wanted and modulate.a <= 0.0:
		hide()


## Read when the line goes up rather than kept, so a key moved between runs is
## named as it is now.
func _what_to_press() -> String:
	var key := Controls.key_for(_action)
	if key.is_empty():
		# Nothing bound to get back with. Saying where they are is still worth
		# more than saying nothing, since off the road nothing counts.
		return "OFF THE ROAD"
	return "OFF THE ROAD      PRESS  %s  TO GET BACK ON" % key.to_upper()
