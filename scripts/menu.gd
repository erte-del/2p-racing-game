class_name Menu
extends Control

## The title screen: the name of the game and a button to start it.
##
## The title never sits perfectly still. It rocks and bobs gently, which is
## what keeps a screen that is doing nothing from looking frozen.

## The scene the Play button starts.
@export_file("*.tscn") var race_scene := "res://scenes/main.tscn"

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

var _elapsed := 0.0


func _ready() -> void:
	_play.pressed.connect(_on_play_pressed)
	# So the keyboard alone can start the game - both players are on one
	# keyboard, and neither has been asked to find the mouse yet.
	_play.grab_focus()


func _process(delta: float) -> void:
	_elapsed += delta
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


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(race_scene)
