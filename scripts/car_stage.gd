class_name CarStage
extends SubViewportContainer

## A car turning on the spot inside a menu, for the decoration tab to show what
## is being drawn on.
##
## The garage's tiles are still pictures, taken once and kept
## ([scripts/car_portrait.gd](car_portrait.gd)), because a dozen of them on one
## page would be a dozen models rendered every time the screen opened. This is
## the opposite case: one car, changing under the player's hands. A stripe
## chosen has to appear on the car on the same frame the button goes down, for
## the reason the paint screen repaints immediately - a decoration confirmed
## two presses after it was picked is a guess.
##
## It is a world of its own, like the portrait's, and for the same reason: the
## course, the sky and the other car are all in the game's world, and a car
## shown there would be a car standing wherever it happened to be parked. The
## light and the background are taken off `CarPortrait` rather than picked
## again, so the car in the tab and the car on the tile are lit the same way.
##
## Nothing here is a `Car`. It is a bare `CarShell`, which is the node that
## knows about models, paint and decoration; the steering, the springs and the
## collision box have no business in a menu.

## How long the car takes to go round once. Slow: this is something to look at
## while deciding where a sticker goes, not something to watch.
const TURN_SECONDS := 16.0

var _stage: SubViewport
var _turntable: Node3D
var _shell: CarShell
var _turned := 0.0

## Which car is standing there, and which way round it was. Kept so that
## recolouring or redecorating does not read a model off the disk again - only
## a different car does.
var _shown := ""
var _shown_turns := -1
var _empty := true


## Stretched, which means the container keeps the viewport the size it ended up
## itself: the page is laid out in a 1600x900 space that Godot scales to the
## window, and a viewport given a size in pixels here would be the one thing on
## the screen that did not scale with the rest.
func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage = SubViewport.new()
	_stage.own_world_3d = true
	_stage.transparent_bg = false
	_stage.msaa_3d = Viewport.MSAA_4X
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_stage)

	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = CarPortrait.BACKGROUND
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color(0.62, 0.68, 0.8)
	sky.ambient_light_energy = 0.7
	sky.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var environment := WorldEnvironment.new()
	environment.environment = sky
	_stage.add_child(environment)

	var sun := DirectionalLight3D.new()
	var sun_from := Vector3(2.5, 5.0, -3.0)
	sun.transform = Transform3D(Basis.looking_at(-sun_from, Vector3.UP), sun_from)
	sun.light_energy = 1.3
	_stage.add_child(sun)

	var camera := Camera3D.new()
	# Further back and wider than the portrait's, because this car turns: a
	# frame a parked car exactly fills is a frame its nose leaves as it comes
	# round.
	camera.fov = 42.0
	var eye := Vector3(0.0, 2.1, -6.4)
	camera.transform = Transform3D(
		Basis.looking_at(Vector3(0.0, 0.66, 0.0) - eye, Vector3.UP), eye)
	camera.current = true
	_stage.add_child(camera)

	_turntable = Node3D.new()
	_stage.add_child(_turntable)
	_shell = CarShell.new()
	_turntable.add_child(_shell)




## Show a car, in a paint, wearing a decoration.
##
## Called every time anything on the page changes, which is why the model is
## only read off the disk when the car itself is different: a player dragging a
## sticker about would otherwise be loading a .glb per frame.
func show_car(id: String, paint: Color, marks: Array) -> void:
	var turns := Garage.quarter_turns(id)
	if _empty or id != _shown or turns != _shown_turns:
		var model := Garage.model_for(id)
		if model != null:
			_shell.set_model(model, id == Garage.STOCK)
			_shown = id
			_shown_turns = turns
			_empty = false
	_shell.repaint(paint)
	_shell.decorate(marks)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_turned = fmod(_turned + delta / TURN_SECONDS * TAU, TAU)
	_turntable.rotation.y = _turned

