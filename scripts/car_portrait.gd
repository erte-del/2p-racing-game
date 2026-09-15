class_name CarPortrait
extends RefCounted

## A picture of a car, for its tile in the garage.
##
## Taken in a world of its own inside a viewport that exists only for as long
## as the picture does. The course, the sky and the other car are all in the
## game's world, and a portrait shot there would be a picture of wherever the
## car happened to be parked.
##
## Pictures are taken once, the first time a car is seen, and kept beside the
## model. Opening the garage must not mean rendering a dozen models every time,
## and a car's picture does not change unless the car is turned - which is the
## one thing that throws its picture away.

const SIZE := Vector2i(208, 136)
## Where the camera stands: ahead of the car, off to one side and a little
## above, so the picture shows the front, one flank and the roof.
const EYE := Vector3(3.5, 2.0, -4.9)
const LOOK_AT := Vector3(0.0, 0.62, 0.0)
## Narrow, so a car the length of the box fills the frame from that distance.
const FOV := 38.0
## The same dark blue as the garage panel it will sit on.
const BACKGROUND := Color(0.11, 0.13, 0.19)


## Take a picture of a model, which is used up in the taking.
##
## Awaited, because a viewport has to actually draw before there is anything to
## read off it. Comes back null where there is nothing that can draw - a
## headless run has no renderer, and waiting on one would be waiting forever.
##
## `host` is any node in the tree, and only lends somewhere to hang the
## viewport. Drawing carries on whether the tree is paused or not, which
## matters because the garage is opened over a paused race.
static func draw(host: Node, model: Node3D) -> Image:
	if model == null:
		return null
	if host == null or not host.is_inside_tree() \
			or DisplayServer.get_name() == "headless":
		model.free()
		return null

	var stage := SubViewport.new()
	stage.size = SIZE
	stage.own_world_3d = true
	stage.transparent_bg = false
	stage.msaa_3d = Viewport.MSAA_4X
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = BACKGROUND
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color(0.62, 0.68, 0.8)
	sky.ambient_light_energy = 0.7
	sky.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var environment := WorldEnvironment.new()
	environment.environment = sky
	stage.add_child(environment)

	var sun := DirectionalLight3D.new()
	var sun_from := Vector3(2.5, 5.0, -3.0)
	sun.transform = Transform3D(Basis.looking_at(-sun_from, Vector3.UP), sun_from)
	sun.light_energy = 1.3
	stage.add_child(sun)

	var camera := Camera3D.new()
	camera.fov = FOV
	camera.transform = Transform3D(Basis.looking_at(LOOK_AT - EYE, Vector3.UP), EYE)
	camera.current = true
	stage.add_child(camera)

	stage.add_child(model)
	host.add_child(stage)
	# Two frames: the first one the viewport is set up in, the second one it is
	# actually drawn in. A third for luck costs a sixtieth of a second.
	for frame in 3:
		await RenderingServer.frame_post_draw
	var image := stage.get_texture().get_image()
	host.remove_child(stage)
	stage.queue_free()
	return image


## Take a picture of a model and write it down. True if there is a picture on
## the disk afterwards.
static func keep(host: Node, model: Node3D, where: String) -> bool:
	var image: Image = await draw(host, model)
	if image == null or image.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(where.get_base_dir())
	return image.save_png(where) == OK
