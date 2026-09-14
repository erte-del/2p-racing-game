class_name Car
extends CharacterBody3D

## Arcade car controller.
##
## The car keeps a single signed speed along its own -Z (forward) axis and
## steers by rotating the whole body, rather than simulating real suspension.
## That is far easier to tune for split-screen arcade racing than
## VehicleBody3D, and it will not flip over on a procedural track.

## Static bodies in this group cost speed to hit. The rails are not in it: a
## car scraping down a barrier at the edge of the road is already being pushed
## back where it belongs, and taking its speed as well for a mistake it is in
## the middle of recovering from would be punishing it twice.
const OBSTACLE_GROUP := &"obstacle"

## Which set of input actions to read, e.g. "p1" -> p1_accelerate, p1_brake,
## p1_steer_left, p1_steer_right.
@export var input_prefix := "p1"

## Paint colour. Defaults to the red the model ships with.
@export var body_color := Color(0.9063, 0.0, 0.0224)

@export_group("Driving")
@export var max_speed := 30.0          ## m/s going forward
@export var max_reverse_speed := 8.0   ## m/s going backwards
@export var acceleration := 12.0       ## m/s^2 under throttle
@export var braking := 24.0            ## m/s^2 under brake
@export var engine_braking := 6.0      ## m/s^2 coasting with no input
## Turning circle at a crawl and at top speed, in metres. Steering is
## expressed as a radius rather than a rate because the tracks are built from
## corners of a known radius, so these numbers say directly which corners the
## car can take. Radius grows with speed, the way a real car washes wide.
@export var tight_turn_radius := 6.5
@export var fast_turn_radius := 16.0
@export var gravity := 24.0            ## m/s^2, tuned for arcade feel
## How much of the climb a car was making when it ran out of road it carries
## into the air. One is what the ramp actually gave it; anything less reads as
## the car being dragged back down over the lip rather than thrown off it.
@export_range(0.0, 1.5) var launch := 1.0
## The fastest a lip may throw a car upwards, in m/s. A ramp taken at chaos
## speed can work out to a great deal more than the ramp looks like it should
## be worth, and a car pitched that far up comes down long after the road it
## was aimed at.
@export var max_launch := 12.0
## How quickly the climb a car is carrying is forgotten, in m/s per second.
##
## The car is a single long box, so as it crests a lip the front of it loses
## the road while the back is still on the ramp, and for a tenth of a second
## it settles rather than climbs. Taking the climb from the last step alone
## would read that settling as the launch and throw the car at the ground.
## What it left the ramp with is the climb the ramp was giving it a moment
## before, which is what this remembers.
@export var climb_memory := 6.0

@export_group("Slipstream")
## Tucking in behind the other car gives a top-speed boost, so a trailing
## player has a way back into the race on the straights.
@export var slipstream_enabled := true
## Beyond this distance there is no effect at all.
@export var slipstream_range := 22.0
## Inside this distance the effect stops growing, so ramming is not rewarded.
@export var slipstream_peak_range := 4.0
## Extra top speed at full effect, as a fraction.
@export var slipstream_bonus := 0.22
## How directly ahead the rival must be, as a dot product.
@export var slipstream_cone := 0.82
## How closely the two cars must be pointing the same way.
@export var slipstream_alignment := 0.6
## How quickly the effect builds and fades.
@export var slipstream_fade := 2.5

@export_group("Boost")
## Extra top speed a pad gives, as a fraction, when it does not name its own.
@export var boost_bonus := 0.55
## Seconds the boost is held at full strength before it starts to fade.
@export var boost_hold := 1.4
## How quickly the boost bleeds away once the hold is over, in fraction per
## second. Slow enough that the car is still carrying the surge into whatever
## comes after the pad, which is what makes where a pad sits a decision rather
## than a gift.
@export var boost_fade := 0.35

@export_group("Obstacles")
## How much speed a square hit on an obstacle costs, as a fraction. A glancing
## blow along one costs proportionally less, so brushing past a barrier is a
## mistake worth making and driving straight into one is not.
@export_range(0.0, 1.0) var obstacle_scrub := 0.72
## Seconds after a hit during which another one costs nothing. A car held
## against a barrier is touching it every frame, and charging for each of
## those would take a single mistake to a dead stop before the player had a
## frame to steer out of it.
@export var obstacle_recovery := 0.4

@export_group("Speed rush")
## How far past its own max speed a car has to be for the rush - the speed
## lines and the camera pulling back - to be at full strength, as a fraction
## of max_speed. A pad is worth 55%, so it very nearly fills the gauge; a
## slipstream is worth 22%, so it shows plainly without ever looking like one.
@export var overspeed_reference := 0.5

@export_group("Body")
## The shell tips to follow the road; the collision box does not. The box is
## what the car drives on, and pitching that would change what the car can
## climb, how it sits on a kerb and where its nose catches - all for something
## that is only ever looked at.
##
## How far it may tip, in degrees, and how quickly it follows. The limit is
## there for the odd bad surface normal - a car reading one triangle of a kerb
## should not stand on its nose.
@export var max_pitch := 32.0
@export var pitch_ease := 9.0

@export_group("Wheels")
## Metres: how high the wheel centres sit, which is both the car's ride height
## and the radius its wheels are rolled at. It stays on the car rather than
## going to the shell with the rest of the wheel business, because it is a
## fact about where the car sits on the road rather than about the model, and
## everything that puts a car down on a surface reads it.
@export var wheel_radius := 0.355

## Which garage car this is wearing, and how many quarter turns it was put on
## with. An empty id is the model the car was built with, which is the stock
## car. Kept on the car so that dressing it again in exactly what it already
## has costs nothing - and it takes both to know that, since a car turned while
## the race was paused has the same id and a different model.
var model_id := ""
var model_turns := 0

## The other car, for slipstream. Wired up by the level.
var rival: Car
## While frozen the car ignores input and holds still, used for the pause
## between generated tracks.
var frozen := false

## Signed speed along local -Z. Positive is forwards.
var _speed := 0.0
## Current slipstream strength, 0 to 1, smoothed.
var _slipstream := 0.0
## Extra top speed from the last boost pad, as a fraction, and the seconds it
## still has left at full strength before it begins to fade.
var _boost := 0.0
var _boost_hold := 0.0
## Seconds left before another obstacle can cost anything.
var _hit_recovery := 0.0
## How fast the car was climbing on the last step it had road under it, and
## the height it was at, which is what that is worked out from.
var _climb := 0.0
var _last_height := 0.0
## Everything that is looked at rather than driven on: the model, its paint,
## its lights and the driver's eye. It tips to follow the road while the body
## it hangs off stays upright.
var _shell: CarShell
## How far the shell is tipped, in radians, nose up positive.
var _pitch := 0.0

# Action names are built once; doing it per frame would allocate every tick.
var _accelerate: StringName
var _brake: StringName
var _steer_left: StringName
var _steer_right: StringName


func _ready() -> void:
	_shell = $Body
	# No snapping to the floor. Snapping exists to keep a body glued to the
	# ground over a crest, which is exactly what a ramp must not do: with it
	# on, a car runs off the lip of a jump and is dragged down over the edge
	# still reporting itself as on the road, and never launches at all.
	floor_snap_length = 0.0

	_accelerate = StringName(input_prefix + "_accelerate")
	_brake = StringName(input_prefix + "_brake")
	_steer_left = StringName(input_prefix + "_steer_left")
	_steer_right = StringName(input_prefix + "_steer_right")

	# The shell has already taken up the model it was authored with - children
	# are readied first - so all that is left is to hand it the paint, which is
	# the one thing about the way this car looks that it cannot know on its own.
	_shell.repaint(body_color)

	# Courses have climbs, and a body that only zeroes its vertical velocity on
	# the floor launches off every crest. Snapping keeps it on the surface.
	floor_snap_length = 0.6


## Switch the headlights on, off, or part way. 0 is off, 1 is full night.
##
## The car is told a level rather than the time of day: it has no business
## knowing what the sky is doing, and a level can just as well come from a
## tunnel or from a player pressing a button later.
func set_headlights(level: float) -> void:
	_shell.set_headlights(level)


## Where the driver's eye sits, in world space.
func eye_transform() -> Transform3D:
	return _shell.eye_transform()


## Whether this car has an interior for the first person camera to sit in.
##
## A model a player brought from outside has no cabin and no windows, so a
## camera put inside one is a camera looking at the back of a solid shell.
## The view is refused rather than handed over broken.
func has_cockpit() -> bool:
	return _shell.has_cockpit()


## Put a different model on the car.
##
## Nothing about how it drives changes. The collision box is a sibling of the
## shell rather than a child of it, so a car wearing somebody else's model
## still has exactly the same corners in exactly the same places, and still
## drives on the tuning above rather than on whatever it now looks like.
func set_model(model: Node3D, stock := false) -> void:
	_shell.set_model(model, stock)


## Paint the car a different colour, after it has already been built. The
## material is this car's own copy rather than the one the model shipped with,
## so this repaints one car and not both.
func repaint(colour: Color) -> void:
	body_color = colour
	_shell.repaint(colour)


func _physics_process(delta: float) -> void:
	# The body is only ever yawed; the shell is what tips. Anything that aims
	# a car with look_at - putting one on the grid, or back on the course at a
	# checkpoint - pitches the whole body when the point it is aimed at is not
	# level with it, which on a climb or a ramp it is not. A body left leaning
	# drives itself into the ground.
	rotation.x = 0.0
	rotation.z = 0.0
	if frozen:
		velocity = Vector3.ZERO
		return

	var throttle := Input.get_axis(_brake, _accelerate)
	var steer := Input.get_axis(_steer_right, _steer_left)

	_hit_recovery = maxf(_hit_recovery - delta, 0.0)
	_update_slipstream(delta)
	_update_boost(delta)
	_apply_throttle(throttle, delta)
	_apply_steering(steer, delta)
	_drive(delta)
	_tilt(delta)
	_shell.animate_wheels(steer, _speed, wheel_radius, delta)


## Stop dead and forget any slipstream. Used when the track is replaced.
func reset_motion() -> void:
	_speed = 0.0
	_slipstream = 0.0
	_boost = 0.0
	_boost_hold = 0.0
	_hit_recovery = 0.0
	_climb = 0.0
	_last_height = global_position.y
	_pitch = 0.0
	if _shell != null:
		_shell.rotation.x = 0.0
	velocity = Vector3.ZERO


## How much top speed the car currently has, including any slipstream and any
## boost. Steering is deliberately left out of this: the turning circle is
## worked out against max_speed, so a boosted car does not wash any wider than
## one flat out on its own. Being fast enough to miss the corner is the risk a
## pad is meant to carry; being unable to steer is not.
func top_speed() -> float:
	return max_speed * (1.0 + slipstream_bonus * _slipstream + _boost)


## True while the car is drafting, for effects and UI later.
func is_drafting() -> bool:
	return _slipstream > 0.05


## How far past its own max speed the car is, from 0 to 1, for the camera and
## the speed lines to read. One number for every way a car can be quick, so a
## boost, a slipstream and a run down a hill all look like the same thing to
## whatever is showing it.
##
## The ceiling counts as well as the speed itself, so the rush lands the
## instant a pad is crossed rather than a second later once the car has caught
## up with its new top speed. It is scaled by how fast the car is actually
## going, which is what stops a car crawling along in someone else's wake from
## putting on a light show.
func overspeed() -> float:
	if _speed <= 0.0 or max_speed <= 0.0:
		return 0.0
	var over: float = maxf(top_speed(), _speed) - max_speed
	var pace := clampf(_speed / max_speed, 0.0, 1.0)
	return clampf(over / (max_speed * overspeed_reference), 0.0, 1.0) * pace


## True while a boost is still worth something, for effects and UI later.
func is_boosting() -> bool:
	return _boost > 0.01


## How much of the current boost is left, as a fraction of top speed.
func boost_amount() -> float:
	return _boost


## Take a boost, from a pad or from anything else that wants to hand one out.
## Both arguments default to the car's own tuning, so a plain pad can just
## call boost().
##
## Boosts do not stack. Driving over a second pad takes whichever bonus is
## larger and restarts the hold on it; adding them together would turn a run
## of pads into an unrecoverable car, and a line of pads is exactly what a
## generated course will sometimes lay down.
func boost(strength := -1.0, seconds := -1.0) -> void:
	_boost = maxf(_boost, boost_bonus if strength < 0.0 else strength)
	_boost_hold = maxf(_boost_hold, boost_hold if seconds < 0.0 else seconds)


## Run down the boost: full strength for the hold, then a fade.
##
## Nothing here touches the car's speed. The boost only lifts the ceiling the
## throttle is working towards, so as it fades the car is left above its own
## top speed and coasts back down to it - which is what carries the surge on
## past the pad instead of ending it the moment the timer does.
func _update_boost(delta: float) -> void:
	if _boost_hold > 0.0:
		_boost_hold = maxf(_boost_hold - delta, 0.0)
		return
	_boost = move_toward(_boost, 0.0, boost_fade * delta)


## Build or decay the slipstream effect. It applies only to the car that is
## behind: the rival has to be ahead of us, within range, and travelling the
## same way, which is what makes it an overtaking aid rather than a free boost.
func _update_slipstream(delta: float) -> void:
	var target := 0.0
	if slipstream_enabled and rival != null and _speed > 0.0:
		var to_rival := rival.global_position - global_position
		to_rival.y = 0.0
		var gap := to_rival.length()
		if gap > 0.001 and gap <= slipstream_range:
			var forward := -global_transform.basis.z
			var ahead := forward.dot(to_rival / gap)
			var same_way := forward.dot(-rival.global_transform.basis.z)
			if ahead >= slipstream_cone and same_way >= slipstream_alignment:
				# Full strength from the peak range out to the limit.
				target = 1.0 - smoothstep(slipstream_peak_range, slipstream_range, gap)
	_slipstream = move_toward(_slipstream, target, slipstream_fade * delta)


## Turn throttle input into a change in speed. Pressing back while rolling
## forwards brakes; holding it once stopped reverses.
func _apply_throttle(throttle: float, delta: float) -> void:
	if is_zero_approx(throttle):
		_speed = move_toward(_speed, 0.0, engine_braking * delta)
	elif throttle > 0.0:
		var rate := braking if _speed < 0.0 else acceleration
		# Already over the ceiling, which is where a fading boost leaves the
		# car: shed the overspeed at the coasting rate rather than the
		# acceleration rate, so holding the throttle can never slow the car
		# faster than lifting off would.
		if _speed > top_speed():
			rate = engine_braking
		_speed = move_toward(_speed, top_speed(), rate * throttle * delta)
	else:
		var rate := braking if _speed > 0.0 else acceleration
		_speed = move_toward(_speed, -max_reverse_speed, rate * -throttle * delta)


## Rotate the car. Steering has no effect when stopped and inverts in
## reverse, so the car handles the way a real one does.
##
## The turning radius is what varies with speed, not the turn rate. An earlier
## version scaled the turn rate by speed, which cancelled the speed out
## entirely and left one fixed 13.9 m turning circle at every speed, so no
## hairpin was ever drivable however slowly you took it.
func _apply_steering(steer: float, delta: float) -> void:
	if is_zero_approx(steer) or is_zero_approx(_speed):
		return
	var speed := absf(_speed)
	# Squared, so the car stays tight through slow corners and only washes
	# wide as it approaches top speed.
	var pace := clampf(speed / max_speed, 0.0, 1.0)
	var radius := lerpf(tight_turn_radius, fast_turn_radius, pace * pace)
	rotate_y(steer * (speed / radius) * signf(_speed) * delta)


## The tightest corner the car can hold at a given speed, in metres.
func turn_radius_at(speed: float) -> float:
	var pace := clampf(absf(speed) / max_speed, 0.0, 1.0)
	return lerpf(tight_turn_radius, fast_turn_radius, pace * pace)


## Move along the car's facing, keeping it pinned to the ground.
##
## A car on the ground has no vertical speed of its own: it follows whatever
## the road does, because move_and_slide slides it along the surface. That is
## right everywhere except the moment the road runs out, where it would leave
## a ramp travelling flat and simply fall off the end of it. So the climb the
## road was giving it is measured while it is still on the ground and handed
## to it as it goes, which is what turns a ramp into a launch.
func _drive(delta: float) -> void:
	var forward := -global_transform.basis.z
	velocity.x = forward.x * _speed
	velocity.z = forward.z * _speed
	var grounded := is_on_floor()
	if grounded:
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	move_and_slide()

	if is_on_floor():
		# Measured rather than worked out from the slope: this is the height
		# the car actually gained, so it is right on a ramp, on a crest and on
		# the eased-off climbs alike. Kept as a fading peak rather than as
		# whatever the last step did, for the reason climb_memory gives.
		var measured := (global_position.y - _last_height) / maxf(delta, 0.0001)
		_climb = maxf(measured, _climb - climb_memory * delta)
	elif grounded:
		# The step it left the ground on.
		velocity.y = clampf(_climb * launch, -max_launch, max_launch)
	_last_height = global_position.y
	_take_the_hits()


## Pay for anything the car ran into on the way.
##
## move_and_slide has already stopped the car going through the obstacle; what
## it will not do on its own is take the speed away, so a car held against a
## barrier would sit there at full throttle reading as fast while going
## nowhere. The cost is scaled by how square the hit was, from everything for
## driving straight into one to almost nothing for a glancing blow.
func _take_the_hits() -> void:
	if _hit_recovery > 0.0:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider() as Node
		if collider == null or not collider.is_in_group(OBSTACLE_GROUP):
			continue
		# The normal points out of the obstacle and back at the car, so a car
		# driving straight at one has its heading directly opposed to it.
		var forward := -global_transform.basis.z
		var head_on := clampf(-forward.dot(collision.get_normal()), 0.0, 1.0)
		_speed *= 1.0 - obstacle_scrub * head_on
		_hit_recovery = obstacle_recovery
		# A hit ends the boost outright rather than scaling it. Carrying a pad
		# through the hazard it was offered against would leave nothing to
		# weigh up, which is the whole of what the pad is for.
		_boost = 0.0
		_boost_hold = 0.0
		return


## Tip the shell to follow the road, and in the air to follow the flight.
##
## On the ground the angle comes from the surface the car is standing on, so a
## car reads the road it is actually on rather than the road it has been over.
## In the air it comes from where the car is going, which is what puts the nose
## up off a ramp and down again on the way to the landing.
##
## Eased rather than set, because the ground under a car changes in steps - one
## triangle to the next, and all at once on landing - and a shell that followed
## that exactly would snap about.
func _tilt(delta: float) -> void:
	var target := 0.0
	if is_on_floor():
		var forward := -global_transform.basis.z
		# Nose up when the surface leans away from the way the car faces.
		target = asin(clampf(-forward.dot(get_floor_normal()), -1.0, 1.0))
	else:
		# Held off the horizontal speed rather than divided by it, so a car
		# that has almost stopped does not read as pointing straight down.
		var flat := Vector2(velocity.x, velocity.z).length()
		target = atan2(velocity.y, maxf(flat, 4.0))
	var limit := deg_to_rad(max_pitch)
	target = clampf(target, -limit, limit)
	_pitch = lerpf(_pitch, target, 1.0 - exp(-pitch_ease * delta))
	_shell.rotation.x = _pitch
