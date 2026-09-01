extends Node3D

## Wires each split-screen camera to the car it follows.
##
## The cars live here, in the main scene, so they share one World3D and can
## collide with each other. Each SubViewport inherits that same world and
## contributes only its own camera, which is what makes split screen work
## without duplicating the level.

@onready var _views: Array[Array] = [
	[$Car1, $Split/TopView/SubViewport/Camera as ChaseCamera],
	[$Car2, $Split/BottomView/SubViewport/Camera as ChaseCamera],
]


func _ready() -> void:
	for view in _views:
		var car := view[0] as Node3D
		var camera := view[1] as ChaseCamera
		camera.follow(car)
