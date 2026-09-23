class_name PurseTally
extends Control

## How many coins are in the purse, in the corner of a race or under the title.
##
## Drawn rather than written, because the thing it is counting is a gold disc
## and a player should not have to read a word to know that. One disc and one
## number, in the corner, small: it is a running total, not a score, and it
## must never be the brightest thing on a screen somebody is driving on.
##
## It ticks when a coin goes in - the number swells and settles - and does not
## otherwise move. Without that a pickup on the road and a number in the corner
## are two separate things a player has to connect for themselves; with it,
## the corner answers the road.
##
## There is one purse, so on a split screen both halves show the same number.
## That is not a mistake: the two of them are saving up together, and a player
## who could only see their own share would be looking at a number that means
## nothing to the shop they are going to spend it in.

## The disc, and the number beside it.
@export var coin_color := Color(1.0, 0.82, 0.24)
@export var text_color := Color(0.93, 0.95, 1.0)
@export var font_size := 26
## How big the disc is drawn, in pixels, and the gap between it and the number.
@export var coin_size := 11.0
@export var gap := 9.0
## How far the number swells when a coin goes in, and how long it takes to
## settle back. Short: a tick, not an animation.
@export var tick_swell := 0.45
@export var tick_seconds := 0.38
## Whether the disc and the number sit in the middle of the space given to them
## or at the left of it. The title screen wants them under the middle of a
## column of buttons; a race wants them lined up with the clock above.
@export var centred := false

## How much of the tick is left to play, from one down to nothing.
var _tick := 0.0
var _coins := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(
		coin_size * 2.0 + gap + float(font_size) * 2.4, float(font_size) * 1.3)
	# Found off the tree rather than named, for the reason
	# `TrackFurniture._the_purse` gives: this is a `class_name` script and the
	# purse is an autoload, and a check that depends on this file compiles it
	# before there are any autoloads to name.
	var purse := get_tree().root.get_node_or_null(^"/root/Purse")
	if purse == null:
		hide()
		return
	_coins = purse.coins()
	# Watched rather than told by whoever is running the race: a coin is banked
	# by the road, in the furniture, and every screen that shows the total
	# would otherwise have to be remembered separately.
	purse.changed.connect(_on_purse_changed)


func _on_purse_changed(coins: int) -> void:
	# Only a coin going in is worth a tick. Spending is something a player did
	# deliberately, on a screen of its own, and does not need pointing out.
	if coins > _coins:
		_tick = 1.0
	_coins = coins
	queue_redraw()


func _process(delta: float) -> void:
	if _tick <= 0.0:
		return
	_tick = maxf(_tick - delta / maxf(tick_seconds, 0.001), 0.0)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var swell := 1.0 + tick_swell * _tick * _tick
	var middle := size.y * 0.5
	var text := str(_coins)
	var size_now: int = int(round(float(font_size) * swell))

	# Laid out from the left of whatever room there is, or from the middle of
	# it. The number is measured rather than guessed at: it grows a digit at
	# ten and again at a hundred, and a group centred on a guess would shuffle
	# sideways as it did.
	var across := font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_now).x
	var wide := coin_size * 2.0 + gap + across
	var from := (size.x - wide) * 0.5 if centred else 0.0

	# The disc, flat on, with a darker rim so it reads against a bright sky as
	# well as against asphalt.
	var centre := Vector2(from + coin_size, middle)
	draw_circle(centre, coin_size * swell, coin_color)
	draw_arc(centre, coin_size * swell, 0.0, TAU, 24,
		Color(0.0, 0.0, 0.0, 0.5), 1.5, true)

	var at := Vector2(
		from + coin_size * 2.0 + gap, middle + float(font_size) * 0.36)
	# The outline first and the face over it, the way every other number on the
	# HUD is drawn: a thin number over a road can land on anything.
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		size_now, 8, Color(0.0, 0.0, 0.0, 0.75))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		size_now, text_color)
