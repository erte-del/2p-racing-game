class_name MedalBadge
extends Control

## The medal itself, drawn rather than written.
##
## A run already says GOLD in words, and the word is what a player reads; this
## is what they see from across the room. It hangs on the corner of the result
## panel the way a rosette is pinned to a board - overlapping the edge rather
## than sitting inside it, because a thing pinned on top of something reads as
## having been awarded, and the same disc centred in the panel would read as
## another row of the form.
##
## It hangs the way a medal hangs: disc up, ribbon down, and a few degrees off
## square. Perfectly upright it reads as an icon that was placed there; leaning
## slightly it reads as an object that was hung there and settled.
##
## And it arrives rather than appearing. A panel that fades up with a medal
## already on it is a panel with a decoration; a medal that drops onto the
## corner while the player is reading their time is the moment they won
## something. It falls in, overshoots, and swings to rest on its pin.
##
## Drawn in code rather than imported, so it is the medal colours the rest of
## the game already uses and there is no third place for gold to be defined.
## It is also three colours and a star, which is less to keep than a file.

## How wide the disc is, and how far the ribbon hangs below it.
@export var disc_diameter := 92.0
@export var ribbon_height := 46.0
## How wide each ribbon tail is where it leaves the disc, and how far apart
## the two tails spread at the top.
@export var ribbon_width := 22.0
@export var ribbon_spread := 30.0
## How deep the notch cut into the end of each tail is. A ribbon ends in a
## swallowtail; cut square it reads as a stub of grey lying on the panel.
@export var ribbon_notch := 13.0

@export_group("Hanging")
## How far off square it rests, in degrees, turning about the pin. Described
## by where it puts the ribbon, since the ribbon is the part that visibly
## hangs: positive swings the tail to the left, away from the panel it is
## pinned to, so the medal leans out over the corner rather than in across the
## words underneath it.
@export var tilt_degrees := 10.0

@export_group("Arrival")
## How far above its resting place it falls from, in pixels, and how long the
## fall takes. Far enough to be plainly falling rather than sliding.
@export var drop_pixels := 210.0
@export var drop_seconds := 0.6
## How long it takes to swing to rest afterwards. Longer than the fall,
## because the settling is the part that reads as weight.
@export var swing_seconds := 0.9

## The medal on show, or NONE for a run that earned nothing - which is not a
## blank badge but no badge at all.
var _medal := Medal.NONE
## Where the pin is - the resting place the fall is aimed at. Read every frame
## of the fall rather than captured, so a panel that changes width halfway
## through still ends up with the medal on its corner.
var _resting := Vector2.ZERO
var _fall: Tween


func _ready() -> void:
	# The drop is tweened on the frame, not on the physics step, so it is drawn
	# where the tween puts it rather than interpolated towards it a step late.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	custom_minimum_size = size_needed()
	size = size_needed()
	visible = false


## How much room the whole thing wants, disc and ribbon together.
func size_needed() -> Vector2:
	return Vector2(disc_diameter + ribbon_spread, disc_diameter + ribbon_height)


## Where the middle of the disc sits inside this control. Whoever is placing
## the badge wants to put *this* point on a corner, not the top left of a
## rectangle that is mostly ribbon. It is also what the medal turns about,
## since that is where the pin would be.
func disc_centre() -> Vector2:
	return Vector2(size_needed().x * 0.5, disc_diameter * 0.5)


## Hang the medal on a point. Called again whenever the panel it is pinned to
## changes shape, which is why the resting place is kept rather than used once.
func pin_to(point: Vector2) -> void:
	pivot_offset = disc_centre()
	_resting = point - disc_centre()
	if _fall == null or not _fall.is_running():
		position = _resting


## Drop it onto the pin.
##
## The fall is driven through a method rather than straight onto `position`,
## so every frame of it is measured from wherever the pin is now. The panel
## grows when the buttons arrive on it, and a fall aimed at the corner as it
## was when the medal left would land beside the new one.
func drop_in() -> void:
	if not visible:
		return
	if _fall:
		_fall.kill()
	modulate.a = 0.0
	rotation = 0.0
	_fall_to(0.0)

	_fall = create_tween()
	_fall.set_parallel(true)
	# Overshooting and coming back is what makes it land rather than stop.
	_fall.tween_method(_fall_to, 0.0, 1.0, drop_seconds) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fall.tween_property(self, "modulate:a", 1.0, drop_seconds * 0.35)
	# The swing starts before the fall has finished, so the medal is already
	# turning as it arrives instead of landing flat and then tipping.
	_fall.tween_property(self, "rotation", deg_to_rad(tilt_degrees),
		swing_seconds) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT) \
		.set_delay(drop_seconds * 0.45)


## One frame of the fall, `at` running 0 to 1 - and past 1 and back, which is
## the overshoot.
func _fall_to(at: float) -> void:
	position = _resting - Vector2(0.0, drop_pixels * (1.0 - at))


## Put a medal on, or take it off. NONE hides the badge outright: an empty
## disc hanging off the corner would be a medal for having finished, and
## finishing is not what this says.
func show_medal(medal: int) -> void:
	if _fall:
		_fall.kill()
	_medal = medal
	visible = medal != Medal.NONE
	# Put back the way it hangs before anything is animated, so a second medal
	# does not start from wherever the last one was left.
	position = _resting
	rotation = 0.0
	modulate.a = 1.0
	queue_redraw()


func _draw() -> void:
	if _medal == Medal.NONE:
		return
	var face := Medal.colour(_medal)
	var centre := disc_centre()
	var radius := disc_diameter * 0.5

	# The ribbon first, so the disc lies over the ends of it rather than the
	# ribbon crossing the face.
	_draw_ribbon(centre, radius)

	# Three rings out of the one colour: a dark rim, the face, and a darker
	# inner line a little way in. A single flat circle reads as a counter.
	draw_circle(centre, radius, face.darkened(0.45), true, -1.0, true)
	draw_circle(centre, radius * 0.88, face, true, -1.0, true)
	draw_arc(centre, radius * 0.72, 0.0, TAU, 48, face.darkened(0.28), 2.0, true)
	draw_colored_polygon(
		_star(centre, radius * 0.52, radius * 0.22), face.darkened(0.42))


## Two tails hanging down and out from behind the disc. Drawn in a muted
## colour of their own rather than in the medal's, so the medal is the only
## thing on the badge saying which one it is.
func _draw_ribbon(centre: Vector2, radius: float) -> void:
	var ribbon := Color(0.22, 0.27, 0.38)
	var hem := centre.y + radius + ribbon_height
	for side: float in [-1.0, 1.0]:
		var foot := centre.x + side * ribbon_width * 0.5
		var head := centre.x + side * ribbon_spread * 0.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(foot - side * ribbon_width * 0.5, centre.y),
			Vector2(foot + side * ribbon_width * 0.5, centre.y),
			Vector2(head + side * ribbon_width * 0.5, hem),
			Vector2(head, hem - ribbon_notch),
			Vector2(head - side * ribbon_width * 0.5, hem),
		]), ribbon.lightened(0.06) if side > 0.0 else ribbon)


## A five pointed star, starting at the top so it sits upright.
func _star(centre: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 10:
		var reach := outer if i % 2 == 0 else inner
		var angle := -PI * 0.5 + TAU * float(i) / 10.0
		points.append(centre + Vector2(cos(angle), sin(angle)) * reach)
	return points
