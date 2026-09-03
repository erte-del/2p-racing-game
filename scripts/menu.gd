class_name Menu
extends Control

## The title screen: the name of the game and a button to start it, over the
## game itself.
##
## The backdrop is a real instance of the race scene in attract mode - the same
## generated course, scenery and day/night cycle the players are about to
## drive, with two cars parked on the grid - turning slowly under the title.
## Being the real thing rather than a picture means it can never go stale.
##
## The title never sits perfectly still either. It rocks and bobs gently, which
## is what keeps a screen that is doing nothing from looking frozen.

## The scene the Play button starts.
@export_file("*.tscn") var race_scene := "res://scenes/main.tscn"

@export_group("Backdrop")
## How fast the view turns about the cars, in degrees per second. A full
## circuit at 4 deg/s takes a minute and a half, which reads as drifting rather
## than as a turntable.
@export var orbit_speed := 4.0
## How far out and how high the camera sits, in metres.
@export var orbit_radius := 16.0
@export var orbit_height := 5.0
## Where the camera aims, above the point it is turning about.
@export var look_height := 1.4
## Where it starts, in degrees, so the cars open side on rather than tail on.
@export var orbit_start := 55.0

@export_group("Idle motion")
## How far the title rocks either side of upright, in degrees.
@export var tilt_degrees := 2.5
## How long one rock across and back takes, in seconds.
@export var tilt_period := 2.6
## How far it bobs, in pixels.
@export var bounce_pixels := 7.0
## Deliberately not a multiple of the rock: two motions on the same beat read
## as one mechanical wobble, while two that drift apart read as idling.
@export var bounce_period := 1.7

@onready var _title: Label = $TitleSlot/Title
@onready var _play: Button = $Play
@onready var _world: Node3D = $World
@onready var _orbit: Camera3D = $Orbit

var _elapsed := 0.0


func _ready() -> void:
	_play.pressed.connect(_on_play_pressed)
	# So the keyboard alone can start the game - both players are on one
	# keyboard, and neither has been asked to find the mouse yet.
	_play.grab_focus()


func _process(delta: float) -> void:
	_elapsed += delta
	_turn_the_backdrop()
	# The pivot has to be re-centred every frame: the label's size is not known
	# until it has been laid out, and it changes with the window.
	_title.pivot_offset = _title.size * 0.5
	_title.rotation = deg_to_rad(
		tilt_degrees * sin(TAU * _elapsed / tilt_period))
	# The label rides inside a slot that the layout positions, so its own
	# resting position is always zero. Bobbing it from a captured position
	# would drift, and would be wrong again the moment the window resized.
	_title.position = Vector2(
		0.0, bounce_pixels * sin(TAU * _elapsed / bounce_period))


## Swing the camera round the parked cars. The centre is asked for every frame
## rather than taken once: the backdrop generates its own course, and the grid
## is wherever that course happens to start.
func _turn_the_backdrop() -> void:
	var centre: Vector3 = _world.grid_centre()
	var angle := deg_to_rad(orbit_start + orbit_speed * _elapsed)
	_orbit.global_position = centre + Vector3(
		sin(angle) * orbit_radius, orbit_height, cos(angle) * orbit_radius)
	_orbit.look_at(centre + Vector3.UP * look_height, Vector3.UP)


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(race_scene)
