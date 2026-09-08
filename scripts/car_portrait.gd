class_name CarPortrait
extends RefCounted

## A picture of a car, for the garage screen to put on a tile.
##
## Drawn rather than shipped, because the cars it has to draw are ones nobody
## here has ever seen. It is done once, when a car is first added, and the
## picture is kept beside the model - a garage of a dozen cars should not be a
## dozen models being rendered every time the screen opens.
##
## The car is drawn in a world of its own rather than in the one the race is
## using. Sharing that world would put the course, the sky and the other car
## in the shot, and would light the portrait with whatever the time of day
## happened to be.

const SIZE := Vector2i(208, 136)

## Three quarters on from the front, which is how a car is always
## photographed: it is the one angle that shows the length, the width and
## the face at once. Negative Z, because that is the way a car faces.
const EYE := Vector3(3.5, 2.0, -4.9)
const LOOKING_AT := Vector3(0.0, 0.62, 0.0)

## Plain and dark, so a pale car and a black one both read against it, and so
## a row of tiles looks like a row rather than a patchwork.
const BACKDROP := Color(0.11, 0.13, 0.19)


## Draw a model and hand back the picture.
##
## Answers null where there is nothing to draw with. A headless run has no
## renderer, and a check that adds a car should not be trying to photograph it.
static func draw(host: Node, model: Node3D) -> Image:
	if DisplayServer.get_name() == "headless" or model == null:
		return null

	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false

	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKDROP
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.62, 0.68, 0.82)
	environment.ambient_light_energy = 0.75
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	viewport.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(35.0), 0.0)
	sun.light_energy = 1.35
	viewport.add_child(sun)

	var camera := Camera3D.new()
	camera.position = EYE
	camera.look_at_from_position(EYE, LOOKING_AT, Vector3.UP)
	camera.fov = 42.0
	viewport.add_child(camera)
	viewport.add_child(model)

	host.add_child(viewport)
	# Two frames: one for the viewport to be laid out and told to draw, and
	# one for what it drew to be readable.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	viewport.queue_free()
	return image


## The same, written down beside the model it is of. Answers whether it stuck.
static func keep(host: Node, model: Node3D, where: String) -> bool:
	var image: Image = await draw(host, model)
	if image == null:
		return false
	return image.save_png(where) == OK
