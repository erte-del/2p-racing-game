class_name ConditionBar
extends Control

## How much a car has left before it breaks, as a bar in the HUD.
##
## Meant to be read without being counted. A player doing thirty metres a
## second has a glance to spare, not a moment, so the bar says three things and
## no more: full, going, and nearly gone. It is in the car's own paint, so on a
## split screen each player finds their own under their own clock, and it goes
## red and flashes once the car is far enough gone to smoke - which is the only
## warning anyone at speed has time to take in. Flashes to white rather than
## merely fading, because a red car's bar is already red, and a warning that
## looks like the paint is no warning.
##
## Hidden outright while damage is off. A bar that never moves is a thing on
## the screen that means nothing.

## What the bar turns to once the car is failing, and how fast it pulses, in
## pulses a second.
@export var warning_colour := Color(0.95, 0.16, 0.12)
@export var pulse_rate := 2.5

var _car: Car
var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


## Follow a car. Read every frame rather than told when it changes, the way
## the speed lines watch theirs: a car is hit, repaired and repainted from
## several places, and every one of them would have to remember to say so.
func watch(car: Car) -> void:
	_car = car


func _process(delta: float) -> void:
	var shown := _car != null and _car.damage
	if visible != shown:
		visible = shown
	if not shown:
		return
	_clock = fposmod(_clock + delta * pulse_rate, 1.0)
	queue_redraw()


func _draw() -> void:
	if _car == null:
		return
	var box := Rect2(Vector2.ZERO, size)
	draw_rect(box, Color(0.0, 0.0, 0.0, 0.55))
	var left := _car.condition()
	var colour := Paints.legible(_car.body_color)
	if _car.is_failing():
		# Never fading out, so the bar is always there at the moment it
		# matters most.
		colour = warning_colour.lerp(Color.WHITE, 0.5 - 0.5 * cos(_clock * TAU))
	var inset := 3.0
	var inner := box.grow(-inset)
	inner.size.x *= left
	if inner.size.x > 0.0:
		draw_rect(inner, colour)
	draw_rect(box, Color(1.0, 1.0, 1.0, 0.35), false, 1.5)
