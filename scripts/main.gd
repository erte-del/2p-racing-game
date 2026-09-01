extends Node3D

## Builds the two split-screen views.
##
## The cars live here, in the main scene, so they share one World3D and can
## collide with each other. Each SubViewport inherits that same world and
## contributes only its own camera, which is what makes split screen work
## without duplicating the level.

## Visual layers carrying each player's private overlay. Because both halves
## of the screen render the same world, anything on these layers has to be
## culled by the other player's camera or it shows up in both views.
const LAYER_WORLD := 1
const LAYER_P1_ONLY := 2
const LAYER_P2_ONLY := 3

const ALL_LAYERS := 0xFFFFF  # Godot's 20 visual layers

@onready var _car1: Car = $Car1
@onready var _car2: Car = $Car2
@onready var _camera1: ChaseCamera = $Split/TopView/SubViewport/Camera
@onready var _camera2: ChaseCamera = $Split/BottomView/SubViewport/Camera
@onready var _arrow1: RivalArrow = $ArrowP1
@onready var _arrow2: RivalArrow = $ArrowP2
@onready var _path: Path3D = $Track/Path3D

@export_group("Starting grid")
## Sideways offset from the racing line, in metres.
@export var grid_spread := 3.6
## How far the second car starts back along the track, in metres.
@export var grid_stagger := 6.0
## Ride height above the road surface at the spawn point.
@export var grid_clearance := 0.05


func _ready() -> void:
	_place_on_grid()

	_camera1.follow(_car1)
	_camera2.follow(_car2)

	# Each player sees an arrow in the *other* car's colour.
	_arrow1.setup(_car1, _car2, _car2.body_color, LAYER_P1_ONLY, _camera1)
	_arrow2.setup(_car2, _car1, _car1.body_color, LAYER_P2_ONLY, _camera2)

	# Show everything except the rival's private layer. Subtracting one layer
	# rather than listing the wanted ones means anything added to the world
	# later is visible to both players by default.
	_camera1.cull_mask = ALL_LAYERS & ~_bit(LAYER_P2_ONLY)
	_camera2.cull_mask = ALL_LAYERS & ~_bit(LAYER_P1_ONLY)


func _bit(layer: int) -> int:
	return 1 << (layer - 1)


## Line the cars up on the track's own curve, staggered, facing the racing
## direction. Deriving the grid from the path means it keeps working when the
## track is reshaped in the editor, and it avoids hand-written basis maths.
func _place_on_grid() -> void:
	var curve := _path.curve
	var to_world := _path.global_transform
	var lap := curve.get_baked_length()
	var cars: Array[Car] = [_car1, _car2]

	for i in cars.size():
		var along := fposmod(-grid_stagger * i, lap)
		var here := to_world * curve.sample_baked(along)
		var ahead := to_world * curve.sample_baked(fposmod(along + 1.0, lap))

		var forward := ahead - here
		forward.y = 0.0
		if forward.length_squared() < 0.000001:
			push_warning("Main: degenerate track tangent at %.1f m" % along)
			continue
		forward = forward.normalized()
		var across := forward.cross(Vector3.UP)

		var side := grid_spread if i % 2 == 1 else -grid_spread
		var car := cars[i]
		car.global_position = here + across * side + Vector3.UP * grid_clearance
		# look_at aims -Z, which is the car's forward.
		car.look_at(car.global_position + forward, Vector3.UP)
