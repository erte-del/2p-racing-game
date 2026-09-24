class_name CarStage
extends SubViewportContainer

## The car in the garage: the model itself, turned and zoomed by the player,
## and the thing decoration is actually put on.
##
## The garage's tiles are still pictures, taken once and kept
## ([scripts/car_portrait.gd](car_portrait.gd)), because a dozen of them on one
## page would be a dozen models rendered every time the screen opened. This is
## the opposite case: one car, changing under the player's hands. A sticker
## pressed has to appear on the car on the same frame the button goes down, for
## the reason the paint screen repaints immediately - a decoration confirmed
## two presses after it was picked is a guess.
##
## It is a world of its own, like the portrait's, and for the same reason: the
## course, the sky and the other car are all in the game's world, and a car
## shown there would be a car standing wherever it happened to be parked. The
## light and the background are taken off `CarPortrait` rather than picked
## again, so the car in the tab and the car on the tile are lit the same way.
##
## **The car does not turn by itself.** It used to, slowly, when it was a thing
## to look at beside a flat drawing of a car that stickers were dragged about
## on. Now it is the drawing: stickers are put on the model, so the model is a
## target, and nobody can be asked to hit a small one that is moving. The
## player turns it, and it stays where they left it.
##
## What is orbited is the camera and not the car. The model stands still at the
## origin, which is what makes picking as simple as it is: a click is a ray in
## the world, the world is the shell's own space, and the shell can say where
## it meets the bodywork without anything having to be undone first.
##
## **Two cameras, and the player picks.** The automatic one is everything above:
## it looks at the middle of the car, frames the whole of it for whatever angle
## it is at, and will not tip under the sills or go nearer than just outside
## the bodywork. The manual one is the player's own. It turns about whatever it
## has been moved to rather than about the middle of the car, it slides sideways
## as well as round, the wheel takes it towards whatever is under the cursor
## rather than towards the middle of the view, and it goes as close as a hand's
## width from the paint - so a player lining a number up on a door handle can
## put the door handle in the middle of the screen and fill it. It starts from
## wherever the automatic one was, so picking it does not move the car.
##
## Nothing here is a `Car`. It is a bare `CarShell`, which is the node that
## knows about models, paint and decoration; the steering, the springs and the
## collision box have no business in a menu.

## How far round and how far up the camera starts: a three-quarter view off the
## nose, which shows a flank and an end at once and so says at a glance that
## there is more than one side to draw on.
const START_YAW := 0.72
const START_PITCH := 0.30

## How far the camera may be tipped. Not quite level at the bottom, because a
## car seen from underneath is a car whose underside is in the way of the car;
## and not quite overhead at the top, where the turn of a yaw stops meaning
## anything anybody can follow.
const PITCH_LEAST := -0.12
const PITCH_MOST := 1.25

## How far back the camera sits, as a multiple of the distance the whole car
## just fits the view at. One is that distance, which is where the page opens;
## under a half is close enough that a door fills the view, and nearly two is
## far enough to see what the whole thing looks like.
const ZOOM_LEAST := 0.42
const ZOOM_MOST := 1.80
const ZOOM_START := 1.0
## How much room is left round the car when it just fits. A car against all
## four edges of a box is a car in a box.
const MARGIN := 1.06
## And how far outside the bodywork the camera is kept whatever the zoom says,
## in metres. Close enough to read a sticker, far enough to be looking at the
## car rather than standing in it.
const CLEAR := 0.5
## How much of that a notch of the wheel is worth. A dozen notches crosses the
## whole range, which is a flick of a finger rather than a job of work.
const ZOOM_STEP := 0.11

## How far a dragged pixel turns the car. A drag across the width of the view
## takes the car most of the way round, which is what a hand expects of
## something it has taken hold of.
##
## A positive yaw swings the camera round to the car's right, which brings the
## near end of the car across to the right of the view - the car turning the
## way the hand dragging it went. A positive pitch lifts the camera, which
## brings the roof into view. Both of those are the opposite of what moving the
## camera would look like if the car were not in front of it, and that is what
## orbiting is.
const DRAG_TO_TURN := 0.011
## And how far an arrow key does, for both players sharing one keyboard.
const KEY_TURN := 0.16

## The manual camera's reach. It may be tipped nearly straight down or straight
## up, since the player chose to be in charge of it - under the sills included.
## Not quite either, where a yaw stops meaning anything.
const MANUAL_PITCH := 1.50
## As near as it may go to what it is looking at, in metres: about a hand's
## width, close enough that a door handle fills the view.
const MANUAL_NEAREST := 0.12
## And as far back, as a multiple of the distance the whole car just fits at.
const MANUAL_FURTHEST := 3.0
## How much nearer a notch of the wheel takes it: to 85% of the way, so every
## notch feels the same whether it is two metres off or twenty centimetres.
const MANUAL_ZOOM := 0.85
## How far the manual camera may slide the thing it turns about off the car,
## as a share of the car's size. Enough to put any corner of it in the middle of
## the view, and not so far that the car can be lost off the edge of the world.
const MANUAL_SLACK := 0.5

## The colour the overlay is drawn in: the ring round whatever is selected,
## and the line round the view while it has the keyboard.
const RING_LINE := Color(0.98, 0.99, 1.0, 0.92)

var _stage: SubViewport
var _camera: Camera3D
var _shell: CarShell
var _overlay: Control

## Where the camera is standing, and how far back.
var _yaw := START_YAW
var _pitch := START_PITCH
var _zoom := ZOOM_START

## True while the manual camera is the one in use, and what it turns about and
## how far off that it is, in metres. See `set_manual`.
var _manual := false
var _focus := Vector3.ZERO
var _distance := 1.0

## Which car is standing there, and which way round it was. Kept so that
## recolouring or redecorating does not read a model off the disk again - only
## a different car does.
var _shown := ""
var _shown_turns := -1
var _empty := true

## What the overlay is drawing over the car: the mark that is selected, and
## the stroke of a word being drawn right now.
var _marks: Array = []
var _chosen := -1
var _pen: Array = []
var _pen_colour := Color.WHITE
var _pen_width := 0.0


## Stretched, which means the container keeps the viewport the size it ended up
## itself: the page is laid out in a 1600x900 space that Godot scales to the
## window, and a viewport given a size in pixels here would be the one thing on
## the screen that did not scale with the rest.
func _init() -> void:
	stretch = true
	# The page drives everything on this view - turning it, zooming it, and
	# putting things on it - so it has to be able to take a press.
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_stage = SubViewport.new()
	_stage.own_world_3d = true
	_stage.transparent_bg = false
	_stage.msaa_3d = Viewport.MSAA_4X
	_stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Nothing inside this world takes a press. Everything the mouse does here
	# is done by the page on the way in - finding the bodywork under a ray, turning
	# the camera - so the events are not passed on into the world to be
	# swallowed by whatever a container would otherwise offer them to.
	_stage.gui_disable_input = true
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

	_camera = Camera3D.new()
	# Wider than the portrait's, because this car is turned about: a frame a
	# parked car exactly fills is a frame its nose leaves as it comes round.
	_camera.fov = 42.0
	_camera.current = true
	# The camera moves when the mouse does, never on the physics step, and a
	# camera smoothed between physics steps is drawn, and asked where a press
	# landed, a step behind where it was put - which the manual camera's
	# wheel, holding what is under the cursor still, shows at once. The title
	# screen and the pause menu turn it off already, but that does not reach
	# in through the viewport, so the camera and the car say it themselves.
	_camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_stage.add_child(_camera)

	_shell = CarShell.new()
	_shell.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_stage.add_child(_shell)

	# The ring round what is selected and the ink of a word being written are
	# drawn flat, over the picture of the car rather than in it. A line in the
	# world would be a line that has to be kept off the road, out of the way of
	# the decals and in front of the bodywork; a line on the glass is a line.
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Kept inside the view. A ring round a sticker on a car that has been
	# zoomed right into is a ring most of which is off the side of the car, and
	# without this it is drawn across the rest of the garage.
	_overlay.clip_contents = true
	_overlay.draw.connect(_draw_the_overlay)
	add_child(_overlay)


func _ready() -> void:
	# The distance is worked out against the shape of the view, so a window
	# that changes shape is a car that has to be framed again.
	resized.connect(_stand_the_camera)
	focus_entered.connect(_overlay.queue_redraw)
	focus_exited.connect(_overlay.queue_redraw)
	_stand_the_camera()


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
			# A different car is a different size, so the camera has to step
			# back or in to frame it - the manual one as well, since what it
			# was looking at is not there any more.
			if _manual:
				_home_the_manual_camera()
			_stand_the_camera()
	_shell.repaint(paint)
	_shell.decorate(marks)


## How big the car standing there is, in its own space. Everything about where
## a mark goes is worked out against this.
func bounds() -> AABB:
	return _shell.bounds()


# --- turning it and looking closer --------------------------------------

func turn_by(yaw: float, pitch: float) -> void:
	_yaw = wrapf(_yaw + yaw, -PI, PI)
	_pitch = clampf(_pitch + pitch, -MANUAL_PITCH if _manual else PITCH_LEAST,
		MANUAL_PITCH if _manual else PITCH_MOST)
	_stand_the_camera()


## Closer for a positive number of notches, further off for a negative one.
##
## `at` is the point on the view to go towards, for the manual camera: what is
## under the cursor stays under the cursor, and the rest of the car grows
## round it. The automatic camera always looks at the middle of the car and
## ignores it.
func zoom_by(notches: float, at := Vector2(-1.0, -1.0)) -> void:
	if not _manual:
		_zoom = clampf(_zoom - notches * ZOOM_STEP, ZOOM_LEAST, ZOOM_MOST)
		_stand_the_camera()
		return
	var box := _shell.bounds()
	var furthest := _how_far_back(box, _focus,
		_camera.global_transform.basis) * MANUAL_FURTHEST
	var wanted := clampf(_distance * pow(MANUAL_ZOOM, notches), MANUAL_NEAREST,
		maxf(furthest, MANUAL_NEAREST))
	var shrink := wanted / _distance
	# Whatever is under the cursor, on the bodywork if the cursor is on the
	# car and level with what the camera turns about if not. Everything is
	# drawn in towards it by the same share, which is what keeps it still on
	# the screen - and why the camera can never pass through it.
	var towards := _focus
	if at.x >= 0.0:
		var hit := _surface_under(at)
		if not hit.is_empty():
			towards = _shell.global_transform * (hit.point as Vector3)
		else:
			var from := _camera.project_ray_origin(at)
			var along := _camera.project_ray_normal(at)
			var ahead := -_camera.global_transform.basis.z
			var facing := along.dot(ahead)
			if facing > 0.000001:
				towards = from + along * ((_focus - from).dot(ahead) / facing)
	_focus = _kept_near_the_car(towards + (_focus - towards) * shrink)
	_distance = wanted
	_stand_the_camera()


## Slide the manual camera across the view by a drag of `pixels`, so the point
## it turns about goes where the cursor goes - and the car with it, anything
## nearer the camera than that point a little further, the way a thing held
## up close does. The automatic camera does not
## slide: it always looks at the middle of the car.
func pan_by(pixels: Vector2) -> void:
	if not _manual:
		return
	var tall := maxf(float(_stage.size.y), 1.0)
	var metres := 2.0 * _distance * tan(deg_to_rad(_camera.fov) * 0.5) / tall
	var basis := _camera.global_transform.basis
	_focus = _kept_near_the_car(_focus
		+ (-basis.x * pixels.x + basis.y * pixels.y) * metres)
	_stand_the_camera()


## Which camera is in use: the manual one for true, the automatic one for
## false. See the top of this file.
##
## The manual one starts exactly where the automatic one is, looking at the
## same point from the same distance, so picking it changes nothing on the
## screen until the camera is moved. Going back to the automatic one keeps the
## angle and frames the whole car from it again.
func set_manual(on: bool) -> void:
	if on == _manual:
		return
	_manual = on
	if on:
		var box := _shell.bounds()
		_focus = _middle_of(box)
		_distance = maxf(_camera.global_position.distance_to(_focus),
			MANUAL_NEAREST)
	else:
		_pitch = clampf(_pitch, PITCH_LEAST, PITCH_MOST)
	_stand_the_camera()


func is_manual() -> bool:
	return _manual


## Back to the view the page opens on. What a player who has turned the car
## upside down and lost the nose reaches for. The manual camera comes back to
## it as well, and stays manual.
func reset_view() -> void:
	_yaw = START_YAW
	_pitch = START_PITCH
	_zoom = ZOOM_START
	if _manual:
		_home_the_manual_camera()
	_stand_the_camera()


## The manual camera where the automatic one would be now: looking at the
## middle of the car, far enough back to see all of it.
func _home_the_manual_camera() -> void:
	var box := _shell.bounds()
	_focus = _middle_of(box)
	var saved := _zoom
	_zoom = ZOOM_START
	_distance = _how_close(box, _focus, Basis.looking_at(-_away(), Vector3.UP))
	_zoom = saved


## A point for the manual camera to turn about, kept within reach of the car.
func _kept_near_the_car(point: Vector3) -> Vector3:
	var box := _shell.bounds()
	if box.size.is_zero_approx():
		return point
	var slack := box.size * MANUAL_SLACK
	return point.clamp(box.position - slack, box.end + slack)


func _middle_of(box: AABB) -> Vector3:
	return box.get_center() if not box.size.is_zero_approx() \
		else Vector3(0.0, 0.66, 0.0)


## Which way from what it is looking at the camera stands, for the yaw and the
## pitch it is at.
func _away() -> Vector3:
	return Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), -cos(_yaw) * cos(_pitch))


## Put the camera where the yaw, the pitch and the zoom say, looking at the
## middle of the car.
##
## How far back it stands is worked out from the car rather than written down,
## because it has to hold a model the game has never seen: a fixed number of
## metres is a wall in front of one car and a speck of another. It is aimed at
## the middle of the box for the same reason - a fixed height is over the roof
## of one model and under the sill of another.
##
## The distance is worked out for the angle the car is being looked at from
## and not once for the car, which is the difference between a car that fills
## a view three times as wide as it is tall and one that sits in the middle of
## it with room all round for the one angle where it needs it. What that costs
## is that the camera steps back a little as the car is tipped up to show its
## roof, which is the right way round: the car keeps fitting.
##
## The manual camera skips all of that. It stands where the player put it: the
## same yaw and pitch, round the point they moved it to, as far off as they
## zoomed it.
func _stand_the_camera() -> void:
	var box := _shell.bounds()
	var away := _away()
	var facing_it := Basis.looking_at(-away, Vector3.UP)
	if _manual:
		_camera.transform = Transform3D(facing_it, _focus + away * _distance)
		_overlay.queue_redraw()
		return
	var middle := _middle_of(box)
	var eye := middle + away * _how_close(box, middle, facing_it)
	_camera.transform = Transform3D(facing_it, eye)
	_overlay.queue_redraw()


## How far off the middle of the car the camera ends up: as far back as the
## whole car needs, brought in by the zoom, and never nearer than just outside
## the bodywork.
##
## The floor is what the zoom is worth having. Without it the closest notch
## puts the camera through the boot lid on a car looked at end-on, because the
## distance the whole car fits at is mostly the half of the car nearest the
## camera - taking a fraction of that takes a fraction of the standoff too.
func _how_close(box: AABB, middle: Vector3, facing_it: Basis) -> float:
	var nearest := 0.0
	for corner in 8:
		nearest = maxf(nearest,
			(box.get_endpoint(corner) - middle).dot(facing_it.z))
	return maxf(_how_far_back(box, middle, facing_it) * _zoom, nearest + CLEAR)


## How far back the whole car just fits the view from, looked at this way
## round.
##
## Every corner of the box is asked how far away the camera would have to be
## for that corner to sit on the edge of the view, and the answer is the
## furthest of the sixteen. The corner's own distance is in the sum because
## this is a perspective view and not a drawing: the near corner of a car seen
## from off the front is a metre closer than the middle of it, and a distance
## worked out as though it were not is a distance that cuts the nose off.
func _how_far_back(box: AABB, middle: Vector3, facing_it: Basis) -> float:
	if box.size.is_zero_approx():
		return 6.4
	var view := Vector2(_stage.size)
	# Before the page has been laid out there is no view to fit anything to.
	# Two to one is what this one is, and the next frame corrects it anyway.
	var aspect := view.x / view.y if view.x > 1.0 and view.y > 1.0 else 2.0
	# The field of view is the vertical one - Godot keeps the height and lets
	# the width follow the shape of the view - so across is up times the shape.
	var up := tan(deg_to_rad(_camera.fov) * 0.5)
	var across := up * aspect
	var back := 0.0
	for corner in 8:
		var gap := box.get_endpoint(corner) - middle
		# How far towards the camera this corner leans. Negative for the ones
		# round the far side, which need less room and get it.
		var near := gap.dot(facing_it.z)
		back = maxf(back, absf(gap.dot(facing_it.x)) / across + near)
		back = maxf(back, absf(gap.dot(facing_it.y)) / up + near)
	return back * MARGIN


# --- what a click on the car means --------------------------------------

## Where a point on this view meets the car's bodywork, as `{point, normal}` in
## the car's own space - or nothing, for a point that is not on the car.
##
## The model itself, not the box round it. Everything placed is placed here:
## a sticker lands on the bonnet where the bonnet is, and a word is written on
## whatever the pen is over, however that part of the car happens to slope.
##
## `spread` is how far round the point to feel the surface, in pixels. A car
## is triangles, and a sticker aimed square at whichever one the cursor is on
## would tip from one to the next as it is dragged across a curve; asked at
## four more points round it the width of the sticker, and pointed the way
## they face between them, it lies along the curve instead. Points that land
## on some other part of the car altogether - off the edge of the bonnet and
## onto the road side of the wing - are left out of it.
func surface_at(where: Vector2, spread := 0.0) -> Dictionary:
	var found := _surface_under(where)
	if found.is_empty() or spread <= 0.0:
		return found
	var normal: Vector3 = found.normal
	var total := normal
	for step in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		var near := _surface_under(where + step * spread)
		if not near.is_empty() and (near.normal as Vector3).dot(normal) > 0.5:
			total += near.normal as Vector3
	return {"point": found.point, "normal": total.normalized()}


## Where a point on this view meets the car if it is on it, facing roughly
## `normal` and no further than `reach` off the plane through `point` - and
## where it meets that plane if not.
##
## For the pen once a word has started. A letter that runs off the edge of the
## bonnet carries on being that letter in the air past it, rather than
## stopping dead or jumping down onto the bumper; one that runs off the bottom
## of a door carries on past the sill, rather than diving through the wheel
## arch into the inside of the car. The word is flattened onto one plane in
## the end anyway, and the part in the air lands on whatever of the car is
## under it.
func surface_or_plane(where: Vector2, point: Vector3, normal: Vector3,
		reach: float) -> Dictionary:
	var found := _surface_under(where)
	if not found.is_empty() and (found.normal as Vector3).dot(normal) > 0.25 \
			and absf(((found.point as Vector3) - point).dot(normal)) <= reach:
		return found
	var from := _into_the_car(_camera.project_ray_origin(where))
	var along := _into_the_car_along(_camera.project_ray_normal(where))
	var facing := along.dot(normal)
	if absf(facing) < 0.000001:
		return {}
	var how_far := (point - from).dot(normal) / facing
	if how_far < 0.0:
		return {}
	return {"point": from + along * how_far, "normal": normal}


func _surface_under(where: Vector2) -> Dictionary:
	return _shell.surface(_into_the_car(_camera.project_ray_origin(where)),
		_into_the_car_along(_camera.project_ray_normal(where)))


## The car stands at the origin untouched, so its own space is the world's -
## but only because nothing moves it, and that is not a thing to lean on.
func _into_the_car(point: Vector3) -> Vector3:
	return _shell.global_transform.affine_inverse() * point


func _into_the_car_along(direction: Vector3) -> Vector3:
	return (_shell.global_transform.basis.inverse() * direction).normalized()


## Which way is right on the screen, in the car's own space. What a sticker put
## on the car is turned to line up with, so it goes on the way up the car is
## being looked at, and what a word is written along.
func screen_right() -> Vector3:
	return _into_the_car_along(_camera.global_transform.basis.x)


## Which face the player is looking at, as `{face, side}`. Where a sticker goes
## when the middle of the view is not on the car at all.
func facing() -> Dictionary:
	return CarFaces.facing(_shell.bounds(), -_camera.global_transform.basis.z)


## Whether a point on the car, facing `out`, is turned towards the camera. What
## keeps the ring round a selected sticker off the screen while the sticker
## itself is round the other side of the car.
func sees(point: Vector3, out: Vector3) -> bool:
	var eye := _into_the_car(_camera.global_position)
	return out.dot(eye - point) > 0.0


## Where a point in the car's own space lands on this view. Nothing for a point
## behind the camera, which `unproject_position` would otherwise answer with a
## number that is off in the wrong direction.
func flat(point: Vector3) -> Dictionary:
	var there := _shell.global_transform * point
	if _camera.is_position_behind(there):
		return {}
	return {"at": _camera.unproject_position(there)}


## How many pixels of this view a length in metres covers, laid across the
## screen at a point on the car. For drawing a pen stroke the width it will
## come out, and for feeling the surface the width of a sticker.
func pixels_across(point: Vector3, metres: float) -> float:
	var one := flat(point)
	var two := flat(point + screen_right() * metres)
	if one.is_empty() or two.is_empty():
		return 0.0
	return (one.at as Vector2).distance_to(two.at)


# --- the overlay --------------------------------------------------------

## What is selected, so the car can carry a ring round it.
func show_ring(marks: Array, chosen: int) -> void:
	_marks = marks
	_chosen = chosen
	_overlay.queue_redraw()


## The stroke being drawn right now, as points on the car.
##
## Only the one in progress. Every stroke that is finished is on the car as a
## decal by then, which is the whole point of drawing on the car rather than in
## a box beside it - what is on the screen is what is on the paintwork.
##
## `width` is how thick the pen draws, as a fraction of the car's length: the
## same number the finished word is drawn at, so a stroke does not change
## width the moment it is let go of.
func show_pen(strokes: Array, colour: Color, width: float = 0.0) -> void:
	_pen = strokes
	_pen_colour = colour
	_pen_width = width
	_overlay.queue_redraw()


func _draw_the_overlay() -> void:
	# A line round the view while it has the keyboard. Every other control on
	# the page says so out of the theme, and a car that quietly started taking
	# the arrow keys with nothing to show for it would be a page that had
	# stopped responding to them.
	if has_focus():
		_overlay.draw_rect(Rect2(Vector2.ONE, _overlay.size - Vector2.ONE * 2.0),
			RING_LINE, false, 2.0)
	if _shell.bounds().size.is_zero_approx():
		return
	_draw_the_ring()
	_draw_the_pen()


## A ring round the mark that is selected, drawn where the mark actually is on
## the car rather than near it - the same square the decal projects, turned the
## same way. Round the copy of it that is being looked at, for a mark worn on
## both doors.
##
## An outline rather than a tint: the mark is already a colour, and a colour
## laid over a colour says nothing about which one is selected.
func _draw_the_ring() -> void:
	if _chosen < 0 or _chosen >= _marks.size():
		return
	var mark: Dictionary = _marks[_chosen]
	if str(mark.get("kind", "")) == DecalArt.STRIPE:
		return
	for placement: Dictionary in CarFaces.placements(_shell.bounds(), mark):
		var middle: Vector3 = placement.point
		var out: Vector3 = placement.out
		if not sees(middle, out):
			continue
		var right: Vector3 = placement.right
		var down := right.cross(out)
		var half := float(placement.half)
		var ring := PackedVector2Array()
		for step in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0),
				Vector2(-1.0, 1.0)]:
			var flat_at := flat(middle + right * (step.x * half) + down * (step.y * half))
			if flat_at.is_empty():
				return
			ring.append(flat_at.at)
		ring.append(ring[0])
		_overlay.draw_polyline(ring, RING_LINE, 2.0, true)
		return


## The stroke a player is in the middle of drawing, laid on the car where the
## pen went.
func _draw_the_pen() -> void:
	if _pen.is_empty():
		return
	var box := _shell.bounds()
	for stroke in _pen:
		var points: PackedVector3Array = stroke
		if points.is_empty():
			continue
		# As thick on the screen as it will be on the car. The width is a
		# fraction of the car's length, measured where the stroke starts.
		var thick := maxf(pixels_across(points[0],
			CarFaces.span_of(box, 1.0) * _pen_width), 2.0)
		var line := PackedVector2Array()
		for point in points:
			var flat_at := flat(point)
			if not flat_at.is_empty():
				line.append(flat_at.at)
		if line.size() == 1:
			_overlay.draw_circle(line[0], thick * 0.5, _pen_colour)
		elif line.size() > 1:
			_overlay.draw_polyline(line, _pen_colour, thick, true)
