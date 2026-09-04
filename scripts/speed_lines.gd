class_name SpeedLines
extends Control

## White streaks sweeping out past the edges of the frame while a car is
## going faster than it should be able to.
##
## There is nothing here about pads or slipstreams. The car reports one number
## - how far past its own max speed it is - and everything that can make a car
## quick shows up the same way, so a player never has to learn a second signal
## for a second kind of speed.
##
## One of these sits inside each player's SubViewport, so the streaks are
## clipped to that player's half of the screen and cannot bleed across the
## split.

## How many streaks there are in all. Only as many as the rush earns are ever
## drawn; the rest wait their turn.
@export var line_count := 56
@export var line_color := Color(1.0, 1.0, 1.0, 0.8)
@export var line_width := 2.4
## Where a streak begins and ends its sweep, as a fraction of the distance
## from the middle of the frame to its edge. It starts well outside the middle
## because the middle is where the car and the road ahead are, and streaks
## drawn over those read as a dirty screen rather than as speed.
@export var inner_reach := 0.5
@export var outer_reach := 1.25
## How long a streak is, in the same fractions.
@export var line_length := 0.34
## Sweeps a second, and how quickly the whole effect follows the car.
@export var sweep_rate := 2.2
@export var rush_ease := 5.0

@export_group("Chaos")
## Under chaos the streaks are not white. They turn through the colours, each
## from a slightly different place in them, so the frame comes out as a
## shifting spread rather than one tinted sheet.
@export var wild_cycle_seconds := 2.6
## How far apart round the wheel the streaks are spread. A whole turn would
## put every colour on the screen at once and read as noise; a quarter reads
## as a colour that happens to be several colours.
@export_range(0.0, 1.0) var wild_spread := 0.25
@export_range(0.0, 1.0) var wild_saturation := 0.85

## Whether this is a chaotic race. Set by whatever built the race, not read
## off the settings: the title screen backdrop is a race scene too, and it
## should not be shimmering behind the menu.
var wild := false

var _car: Car
## How much of the rush is currently showing, 0 to 1.
var _rush := 0.0
var _time := 0.0
## Fixed angle and starting phase per streak. Rolled once and kept, so the
## streaks stay where they are rather than boiling about from frame to frame.
var _angles := PackedFloat32Array()
var _phases := PackedFloat32Array()


func _ready() -> void:
	# The lines are scenery, not a control anyone clicks on.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260903
	for i in line_count:
		# One streak per equal slice of the circle, jittered inside its own
		# slice. Angles rolled freely clump, which leaves bald patches around
		# the frame that read as the effect being broken rather than random.
		_angles.append((float(i) + rng.randf()) / float(line_count) * TAU)
		_phases.append(rng.randf())


## Called by the level: whose speed this view is showing.
func watch(car: Car) -> void:
	_car = car
	_rush = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	var target := _car.overspeed() if _car != null else 0.0
	var eased := lerpf(_rush, target, 1.0 - exp(-rush_ease * delta))
	# Nothing to draw and nothing changing: leave the frame alone rather than
	# redrawing an empty overlay sixty times a second.
	if is_zero_approx(eased) and is_zero_approx(_rush):
		_rush = 0.0
		return
	_rush = eased
	_time += delta
	queue_redraw()


func _draw() -> void:
	if _rush < 0.01:
		return
	var centre := size * 0.5
	# The frame is a wide letterbox, so the streaks are spread out over an
	# ellipse the shape of the view. Spreading them over a circle instead
	# would leave the sides bare and crowd the top and bottom edges.
	var reach := size * 0.5

	for i in line_count:
		var along := fmod(_phases[i] + _time * sweep_rate, 1.0)
		var direction := Vector2.from_angle(_angles[i])
		var from: float = lerpf(inner_reach, outer_reach, along)
		var to := from + line_length * _rush
		# In and out again across the sweep, so a streak never pops into or
		# out of the frame at full strength.
		var colour := line_color
		if wild:
			colour = Color.from_hsv(
				fmod(_time / wild_cycle_seconds + _phases[i] * wild_spread, 1.0),
				wild_saturation, 1.0, line_color.a)
		# In and out again across the sweep, but flattened, so a streak
		# spends most of its life at full strength instead of only touching
		# it in passing.
		colour.a *= _rush * pow(sin(along * PI), 0.5)
		draw_line(
			centre + direction * reach * from,
			centre + direction * reach * to,
			colour, line_width, true)
