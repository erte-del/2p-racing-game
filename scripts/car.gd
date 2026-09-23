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
## Static bodies in this group are the road: the surface itself and the rails
## along it. Anything else a car can stand on - the grass, mostly - is off the
## road, where the car is slower and where nothing it does counts towards the
## race. The track puts its own bodies in it.
const ROAD_GROUP := &"road"

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
## How much of its top speed a car keeps with anything but the road under it,
## as a fraction. Mild on purpose: the grass is a mistake that costs time, not
## a trap. What stops it being a way round the course is that checkpoints and
## the finish only count on the road, not that the grass is slow.
@export_range(0.0, 1.0) var off_road_speed := 0.6
## Turning circle at a crawl and at top speed, in metres. Steering is
## expressed as a radius rather than a rate because the tracks are built from
## corners of a known radius, so these numbers say directly which corners the
## car can take. Radius grows with speed, the way a real car washes wide.
@export var tight_turn_radius := 6.5
@export var fast_turn_radius := 16.0
## How much of its steering a car keeps with no road under it, as a fraction.
## Enough to straighten up for the landing it is already heading for, not
## enough to pick a different one: a car that turned as well in the air as on
## the ground would take a jump as just another corner.
@export_range(0.0, 1.0) var air_steer := 0.25
## How long the steering takes to go from straight ahead to full lock, and
## from full lock back to straight, in seconds at top speed. A key is either
## down or up, and a car that snapped to full lock the instant one went down
## would twitch rather than turn in. Letting go is the quicker of the two,
## because a car slow to straighten feels as though it is still turning of its
## own accord, and crossing from one lock to the other goes back through
## straight at that quicker rate. Both shrink with speed, down to nothing at a
## standstill, so a hairpin or a three-point turn taken at a crawl answers the
## keys the way it always did.
@export var steer_rise := 0.12
@export var steer_fall := 0.06
## How quickly the way a car is travelling is pulled back to the way it is
## pointing, in 1/s. Steering turns the car's nose at once, the way it always
## did; what the car is doing is the direction it was already going, dragged
## round after it. The gap between the two is the slip angle, and this is how
## fast the tyres close it.
##
## Held rather than a force, so it is one number with one meaning: a car
## holding a corner settles at its turn rate divided by this, which at top
## speed through the 16 m circle is 1.875 / 12, or 9 degrees of slide. High
## enough and the gap closes inside a step, which is exactly how the car drove
## before this existed.
##
## What it deliberately does not change is the corner itself. Once the slip
## has settled the nose and the travel are turning at the same rate, so the
## circle a car holds is still turn_radius_at() and the track planner's radii
## still mean what they say. What it costs is the entry and the exit, where
## the car is still gathering the angle up or giving it back.
@export var grip := 12.0
## The most the travel may lag the heading, in degrees. Past this a car is no
## longer sliding, it is spinning, and a single signed speed along the heading
## stops describing anything. Ordinary driving never comes near it: the
## tightest a tuned car can hold is about 9 degrees.
@export var max_drift := 45.0
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
## How fast a car is thrown back off the face of an obstacle it has hit, in
## m/s on a square hit, and the seconds that takes to die away. For that long
## the car's own speed stops carrying it into the face as well, so it comes
## off rather than being held there by its own throttle.
##
## Without it a car held against a barrier with the throttle down stayed
## pressed to the face, was hit again every time obstacle_recovery ran out,
## and was scrubbed down to a few metres a second, where it turns slowly.
## None of it is taken off the car's speed: the hit has already cost what a
## hit costs, and this is only where the car goes after it.
@export var obstacle_bounce := 6.0
@export var obstacle_bounce_time := 0.4

@export_group("Damage")
## What a car can take before it is finished, and what a square hit at its own
## top speed costs of that. Every other hit is a fraction of it: scaled by how
## square it was and by how fast the car was going as a share of max_speed, the
## same two numbers the speed a hit costs is worked out from. Three flat-out
## square hits is 102, so the third one breaks the car and a run can carry five
## or six clumsy moments or three bad ones.
##
## Against the car's own max_speed rather than a fixed one, so a chaos car
## rolled fast hits no harder at its top speed than a tuned car does at its
## own. A car over its top speed on a pad is over one, and pays for it: a
## boosted square hit costs more than full_hit.
@export var max_condition := 100.0
@export var full_hit := 34.0
## How much condition is left, as a fraction, when the car starts to show it:
## the bar goes red and the bonnet starts to smoke.
@export_range(0.0, 1.0) var warning_at := 0.33

@export_group("Contact")
## Coming down on the other car's roof throws a car back up, where coming down
## on anything else puts it down and keeps it there. Nothing needs it; it is
## there because a car that lands on its rival ought to know about it.
##
## How much of the speed a car comes down onto a roof with it goes back up
## with, as a fraction. Under one, so every bounce is lower than the one before
## and a car always settles.
@export_range(0.0, 1.0) var roof_bounce := 0.6
## A car coming down onto a roof slower than this, in m/s, stays on it rather
## than bouncing. Without it the bounces would shrink for ever, and a car
## sitting on a roof would judder there instead of resting.
@export var roof_bounce_min := 2.0
## Running into the other car. Both cars are CharacterBody3D, so to each other
## they are walls: move_and_slide keeps them apart and does nothing else, and
## CarContact adds the bump. It says why that is one node rather than
## something each car does to the other.
##
## How much of the speed two cars are closing at the car doing the hitting
## loses on a square hit, and how much of it the car being hit is given, as
## fractions. The give is always held under the take, so running into a car
## from behind costs more than it hands over, and tuned to come to one between
## them, so after a square hit from behind neither car is still closing on the
## other. A glancing hit passes on only as much as the hitter was pointed into
## it, and the car hit is never given more than its own top speed.
@export_range(0.0, 1.0) var bump_take := 0.75
@export_range(0.0, 1.0) var bump_give := 0.25
## How fast two cars that touch side on are pushed apart, in m/s, and the
## seconds that push takes to die away. It is a push rather than a change of
## speed, so it rides on top of where each car is going, and move_and_slide
## and the rails still have the last word on where that ends up.
@export var side_push := 4.0
@export var push_fade := 0.3
## Seconds after a contact during which another costs nothing, for the reason
## obstacle_recovery gives: two cars leant together touch on every step.
@export var bump_recovery := 0.4

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
##
## Tipping it is only half of standing it on a ramp, and both of these do the
## other half as well. The box does not tip, so on a slope it rests on one
## bottom edge - the nose going up a ramp, the tail coming down one - and the
## point the shell turns about, the middle of that bottom face, is held clear
## of the road by however far the slope has fallen away underneath it: over a
## metre at the lip of a tuned ramp. So the shell is sunk back down onto the
## road by as much as the box has lifted it, which _sink_to_the_road works out.
## The limit is what says how far that can possibly be, since a box this long
## cannot hold its middle any higher than tipping it this far would, and the
## ease is what it comes back up at when the car leaves the ground.
@export var max_pitch := 32.0
@export var pitch_ease := 9.0
## On top of the road, the body leans with what the car is doing: out of a
## corner, nose down under braking and back on its haunches under throttle,
## and down onto its springs when it lands. None of it reaches the collision
## box, for the reason above, and none of it is mixed into the road pitch
## either - that is still worked out on its own and the lean is laid over it,
## so anything reading how the road tips a car reads the road and not the
## driver.
##
## Degrees of roll for every m/s² the car is pulled sideways, and the most it
## may roll, in degrees.
@export var roll_per_accel := 0.12
@export var max_roll := 5.0
## Degrees of pitch for every m/s² the car speeds up or slows down, nose up
## under throttle and down under braking, and the most it may pitch, in
## degrees.
@export var dive_per_accel := 0.1
@export var max_dive := 3.0
## How fast the body starts to sink on landing, as a fraction of how fast the
## car came down, and the furthest it may sink, in metres.
@export var landing_give := 0.08
@export var max_squash := 0.15
## How hard the body is pulled back to where it is being pushed, in 1/s², and
## how quickly its swinging about that dies away, in 1/s. Damped well short of
## what it would take to stop it overshooting, so a lean settles with a small
## swing back rather than arriving dead.
@export var body_spring := 60.0
@export var body_damping := 9.0

@export_group("Wheels")
## Metres: how high the wheel centres sit, which is both the car's ride height
## and the radius its wheels are rolled at. It stays on the car rather than
## going to the shell with the rest of the wheel business, because it is a
## fact about where the car sits on the road rather than about the model, and
## everything that puts a car down on a surface reads it.
@export var wheel_radius := 0.355
## How quickly wheels with no road under them spin down, in m/s of road speed
## lost every second. On the ground they turn at exactly the speed the car is
## covering it; in the air there is nothing to turn them, so they keep the
## speed they left with and lose it slowly rather than stopping dead.
@export var air_wheel_fade := 4.0

## Which garage car this is wearing, and how many quarter turns it was put on
## with. An empty id is the model the car was built with, which is the stock
## car. Kept on the car so that dressing it again in exactly what it already
## has costs nothing - and it takes both to know that, since a car turned while
## the race was paused has the same id and a different model.
var model_id := ""
var model_turns := 0

## The other car, for slipstream. Wired up by the level.
var rival: Car
## Who is driving, when it is not a keyboard: anything with a
## `controls(car, delta) -> Vector2` giving throttle and steering the way the
## keys would, from -1 to 1 each. Null is the player on `input_prefix`.
##
## Asked rather than handed the car. A driver only ever says what it wants of
## the pedals and the wheel, and everything the car does with that - the
## easing, the grip, the ceiling on its speed - is the same sums a player's
## keys go through, which is the whole of what stops a bot being quicker than
## the car it is in.
var driver: Object
## While frozen the car ignores input and holds still, used for the pause
## between generated tracks.
var frozen := false
## Whether hits wear this car down. Told to it by whatever built the race
## rather than read from GameSettings, because the title screen backdrop is a
## race scene too and nothing behind the menu is being driven.
var damage := false

## Signed speed along local -Z. Positive is forwards.
var _speed := 0.0
## Where the steering is, from -1 at full right lock to +1 at full left, eased
## towards what the keys ask for. It is the one steering state the car has: it
## is what turns the car, and what turns the wheels.
var _steer := 0.0
## How far the way the car is travelling lags the way it is pointing, in
## radians, as a rotation about up applied to the heading. Steering adds to it
## - the nose turns, the travel does not - and grip takes it away again. It is
## the one thing standing between the heading and where the car actually goes.
var _drift := 0.0
## How far the steering turned the nose on this step, in radians, waiting for
## the travel to be asked to catch up with it.
var _turned := 0.0
## Current slipstream strength, 0 to 1, smoothed.
var _slipstream := 0.0
## Extra top speed from the last boost pad, as a fraction, and the seconds it
## still has left at full strength before it begins to fade.
var _boost := 0.0
var _boost_hold := 0.0
## Seconds left before another obstacle can cost anything.
var _hit_recovery := 0.0
## What the car has left of max_condition. Kept out of reset_motion on purpose:
## a car put back at a checkpoint is the same car, and if that repaired it,
## damage would be a thing a player undoes by pressing R.
var _condition := 100.0
## After hitting an obstacle: the seconds left of being thrown back off it,
## which way that is, flat on the ground, and how fast the throw started.
var _rebound := 0.0
var _rebound_normal := Vector3.ZERO
var _rebound_speed := 0.0
## How fast the car was climbing on the last step it had road under it, and
## the height it was at, which is what that is worked out from. The climb is
## used up throwing the car off the end of the road, so a car always comes
## back down with none.
var _climb := 0.0
var _last_height := 0.0
## How fast the car is to go back up on its next step, having just come down
## on the other car's roof. Held for a step rather than set at once: the step
## that lands a car is also what tells the next one it is on the floor, and a
## car on the floor has its vertical speed taken away before it moves.
var _bounce := 0.0
## The push the other car last gave this one, in m/s across the ground, fading
## away; and whether the car moved on its last step, which is what says
## whether what it ran into on that step is still news.
var _shove := Vector3.ZERO
var _moved := false
## Whether the last thing the car stood on was off the road. Coming down on
## the other car's roof leaves it as it was: a car sitting on its rival is not
## on the grass.
var _off_road := false
## Everything that is looked at rather than driven on: the model, its paint,
## its lights and the driver's eye. It tips to follow the road while the body
## it hangs off stays upright.
var _shell: CarShell
## The decoration the car is wearing, and whether it turns through the colours.
## Kept here as well as on the shell so that a car told either before its shell
## has come up is still wearing it afterwards.
var _marks: Array = []
var _decals_wild := false
## How far the road tips the shell, in radians, nose up positive.
var _pitch := 0.0
## How far the shell is sunk to meet the road the box has lifted it off, in
## metres, and how far the box can lift it: half the box's length, which is how
## far its nose and tail reach from the point the shell turns about.
var _sink := 0.0
var _box_reach := 0.0
## How far the body leans on its springs on top of that - roll in radians,
## right side up positive; pitch in radians, nose up positive; and how far it
## has sunk, in metres, down negative - each with how fast it is moving.
var _roll := 0.0
var _roll_rate := 0.0
var _dive := 0.0
var _dive_rate := 0.0
var _drop := 0.0
var _drop_rate := 0.0
## How fast the car came down on the step it landed, for the body to sink with.
var _landing := 0.0
## The heading, and the speed along it, on the last step: what the pulls the
## body leans with are worked out from.
var _last_yaw := 0.0
var _last_ground_speed := 0.0
## How fast the wheels are turning, as the road speed they would cover in m/s.
var _wheel_speed := 0.0

# Action names are built once; doing it per frame would allocate every tick.
var _accelerate: StringName
var _brake: StringName
var _steer_left: StringName
var _steer_right: StringName


func _ready() -> void:
	_shell = $Body
	_condition = max_condition
	# Read off the box rather than written down, so a box that is ever resized
	# takes the sink that goes with it along.
	var box := ($Collision as CollisionShape3D).shape as BoxShape3D
	if box != null:
		_box_reach = box.size.z * 0.5

	_accelerate = StringName(input_prefix + "_accelerate")
	_brake = StringName(input_prefix + "_brake")
	_steer_left = StringName(input_prefix + "_steer_left")
	_steer_right = StringName(input_prefix + "_steer_right")

	# The shell has already taken up the model it was authored with - children
	# are readied first - so all that is left is to hand it the paint and the
	# decoration, which are the two things about the way this car looks that it
	# cannot know on its own.
	_shell.repaint(body_color)
	_shell.wild = _decals_wild
	_shell.decorate(_marks)

	# Snapped down onto the road, by up to 0.6 m a step. A car on the ground
	# has no vertical speed of its own, so on a falling road it runs flat off
	# the surface and has to drop back onto it: without snapping, a car driven
	# flat out down a 4.7 m descent spent three fifths of the run off the
	# floor, in hops of up to nine steps, with the shell reading every one of
	# them as a flight.
	#
	# Snapping does not stop a jump, and Godot's own rules for it say why: it
	# is only tried on a step the car began on the floor and is not moving
	# upwards, and it reaches no further down than floor_snap_length. On the
	# step a car rolls off a lip there is a hole metres deep under it and
	# nothing in reach to snap to, so it leaves the floor. _drive then hands it
	# the ramp's climb, and from the next step on it is rising, so snapping is
	# not tried again until it is back on the ground.
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


## Put a decoration on the car: the stripes, stickers and hand-written words
## kept against whichever model it is wearing. See `Decals`.
##
## Handed the marks rather than a car id, for the reason `repaint` is handed a
## colour and not a slot: what the car looks like is settled here, and where
## the choice was kept is whoever called this one's business.
func decorate(marks: Array) -> void:
	_marks = marks.duplicate(true)
	if _shell != null:
		_shell.decorate(_marks)


## Whether this car's decoration turns through the colours.
##
## Told rather than read off `GameSettings.chaos`, the same way the wood and
## the speed streaks are told: the title screen backdrop is a race scene too,
## and a strobing sticker behind the menu is not what the menu is for.
func set_decals_wild(on: bool) -> void:
	_decals_wild = on
	if _shell != null:
		_shell.wild = on


## What the decoration is wearing this frame. Only a check asks.
func decal_colours() -> PackedColorArray:
	return _shell.decal_colours() if _shell != null else PackedColorArray()


func _physics_process(delta: float) -> void:
	# The body is only ever yawed; the shell is what tips. Anything that aims
	# a car with look_at - putting one on the grid, or back on the course at a
	# checkpoint - pitches the whole body when the point it is aimed at is not
	# level with it, which on a climb or a ramp it is not. A body left leaning
	# drives itself into the ground.
	rotation.x = 0.0
	rotation.z = 0.0
	# A broken car stops where it broke, in the air as well: dropping one that
	# broke over a jump through the hole under it would be a second thing
	# happening to it that the player did nothing to earn.
	if frozen or is_broken():
		velocity = Vector3.ZERO
		return

	var throttle := 0.0
	var steer := 0.0
	if driver != null:
		var wanted: Vector2 = driver.controls(self, delta)
		throttle = clampf(wanted.x, -1.0, 1.0)
		steer = clampf(wanted.y, -1.0, 1.0)
	else:
		throttle = Input.get_axis(_brake, _accelerate)
		steer = Input.get_axis(_steer_right, _steer_left)

	_hit_recovery = maxf(_hit_recovery - delta, 0.0)
	_update_slipstream(delta)
	_update_boost(delta)
	_ease_steering(steer, delta)
	# With no road under it the car has nothing to push against and nothing
	# to brake on, so its speed is whatever it left the road with, and only a
	# little of its steering is left. Decided here rather than inside the
	# throttle and the steering, so anything that works those directly -
	# boost_trace, which has no road at all - gets the car's own sums.
	if is_on_floor():
		_apply_throttle(throttle, delta)
		_apply_steering(_steer, delta)
		_slide(grip, delta)
	else:
		_apply_steering(_steer * air_steer, delta)
		# No grip at all: the nose turns and the travel does not.
		_slide(0.0, delta)
	_drive(delta)
	_shell.smoke(_smoke_level())
	_tilt(delta)
	_lean(delta)
	_roll_wheels(delta)
	_shell.animate_wheels(_steer, _wheel_speed, wheel_radius, delta)


## Put a copy of the car somewhere to rehearse from, going `speed` along its
## nose and with nothing else carried over: no lock on, no slide, no boost.
func rehearse_from(at: Transform3D, speed := 0.0) -> void:
	transform = at
	_speed = speed
	_steer = 0.0
	_drift = 0.0
	_turned = 0.0
	_slipstream = 0.0
	_boost = 0.0
	_boost_hold = 0.0
	_off_road = false


## One step of the car's own sums with nothing of the world in them: no road
## to stand on, nothing to hit, no gravity. Returns where the car is going, in
## m/s across the ground, and leaves moving it there to the caller.
##
## For a driver rehearsing a lap on a copy of the car rather than on the car:
## BotDriver practises a track this way before it races it, and a practice lap
## taken through anything but the car's own easing, grip and ceiling would be
## practice at driving some other car. A copy is never added to the tree, so it
## is the transform rather than the global one that is turned.
func rehearse(throttle: float, steer: float, grounded: bool, delta: float) -> Vector3:
	_update_boost(delta)
	_ease_steering(clampf(steer, -1.0, 1.0), delta)
	if grounded:
		_apply_throttle(clampf(throttle, -1.0, 1.0), delta)
		_apply_steering(_steer, delta)
		_slide(grip, delta)
	else:
		_apply_steering(_steer * air_steer, delta)
		_slide(0.0, delta)
	var travel := (-transform.basis.z).rotated(Vector3.UP, _drift)
	return Vector3(travel.x, 0.0, travel.z) * _speed


## Stop dead and forget any slipstream. Used when the track is replaced.
func reset_motion() -> void:
	_speed = 0.0
	_steer = 0.0
	_drift = 0.0
	_turned = 0.0
	_slipstream = 0.0
	_boost = 0.0
	_boost_hold = 0.0
	_hit_recovery = 0.0
	_rebound = 0.0
	_climb = 0.0
	_last_height = global_position.y
	_bounce = 0.0
	_shove = Vector3.ZERO
	_off_road = false
	_pitch = 0.0
	_sink = 0.0
	_roll = 0.0
	_roll_rate = 0.0
	_dive = 0.0
	_dive_rate = 0.0
	_drop = 0.0
	_drop_rate = 0.0
	_landing = 0.0
	_last_yaw = rotation.y
	_last_ground_speed = 0.0
	_wheel_speed = 0.0
	if _shell != null:
		_shell.pose(0.0, 0.0, 0.0, 0.0, 0.0)
	velocity = Vector3.ZERO


## Put the car back to full condition. Only a fresh start does this - the car
## back on the line, or a new course - never a checkpoint.
func repair() -> void:
	_condition = max_condition
	if _shell != null:
		_shell.smoke(0.0)


## How much condition the car has left, from 1 for untouched to 0 for broken.
func condition() -> float:
	return clampf(_condition / maxf(max_condition, 0.001), 0.0, 1.0)


## Whether the car has been worn down to nothing. Only ever true with damage
## on, since nothing else takes condition away.
func is_broken() -> bool:
	return _condition <= 0.0


## Whether the car is far enough gone to warn about.
func is_failing() -> bool:
	return damage and condition() <= warning_at


## How thick the smoke off the bonnet is: none until the warning, thin there,
## and thickening all the way down to broken.
func _smoke_level() -> float:
	if not is_failing():
		return 0.0
	return lerpf(0.25, 1.0, 1.0 - condition() / maxf(warning_at, 0.001))


## How much top speed the car currently has, including any slipstream and any
## boost. Steering is deliberately left out of this: the turning circle is
## worked out against max_speed, so a boosted car does not wash any wider than
## one flat out on its own. Being fast enough to miss the corner is the risk a
## pad is meant to carry; being unable to steer is not.
##
## Off the road the car keeps only off_road_speed of it. Nothing sets the speed
## down: the ceiling drops, and a car over it sheds the difference the way it
## sheds a fading boost.
func top_speed() -> float:
	var ceiling := max_speed * (1.0 + slipstream_bonus * _slipstream + _boost)
	return ceiling * off_road_speed if _off_road else ceiling


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


## Ease the steering towards what the keys are asking for.
##
## Heading back towards straight - letting go, easing off, or on the way over
## to the other lock - goes at the steer_fall rate, and heading out from it at
## the steer_rise rate. A change of side spends whatever is left of the step
## after reaching straight turning in the other way, so a flick across is not
## charged a whole step at the slower rate for passing through the middle. A
## stick held part of the way over is eased to in the same way, rather than
## jumped to.
func _ease_steering(wanted: float, delta: float) -> void:
	# Both times shrink with speed. What the easing is for is a car at speed
	# twitching on a key press; at a crawl the same key has always turned the
	# car at once, and it still should.
	var pace := clampf(absf(_speed) / maxf(max_speed, 0.001), 0.0, 1.0)
	var rise := 1.0 / maxf(steer_rise * pace, 0.0001)
	var fall := 1.0 / maxf(steer_fall * pace, 0.0001)
	var time := delta
	if not is_zero_approx(_steer) and (
			signf(wanted) != signf(_steer) or absf(wanted) < absf(_steer)):
		var back_to := wanted if signf(wanted) == signf(_steer) else 0.0
		var needed := absf(_steer - back_to) / fall
		if needed >= time:
			_steer = move_toward(_steer, back_to, fall * time)
			return
		_steer = back_to
		time -= needed
	_steer = move_toward(_steer, wanted, rise * time)


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
	var turn := steer * (speed / turn_radius_at(_speed)) * signf(_speed) * delta
	rotate_y(turn)
	# Handed to _slide, which is what the travel has to catch up with. Taken
	# here rather than from the yaw the body ended the step at, because only
	# steering slides a car: everything else that turns one - a car put on the
	# grid, or back on the course at a checkpoint, or a bot driver aiming its
	# own body - is picking the car up and pointing it somewhere else, not
	# sliding it.
	_turned += turn


## Put this step's steering into the slip angle and let grip work it off.
##
## The nose has turned and the travel has not, so the whole of the turn is owed
## to the slip angle; grip closes it at a rate of its own. Written out as the
## exact answer to that pair over the step rather than as a turn added and a
## decay applied one after the other, because the order and the length of the
## step would then both show up in the slide a car settles at, and the settled
## slide is meant to be one number - the turn rate over grip - whatever rate
## the physics happens to be running at.
##
## How much grip there is, is asked of it rather than worked out here, for the
## reason the throttle and the steering are: it is _physics_process that knows
## whether there is road under the car, and a check driving a car with no floor
## at all gets the car's own sums either way. Nothing but a car in the air is
## ever given none, and none is the whole turn kept as slide - which is a car
## flying where it was thrown. Air steering still turns the nose, and all that
## decides is which way the car will be pointing when the grip catches it on
## landing; the flight itself is a straight line either way, so what a ramp is
## worth has not moved.
func _slide(rate: float, delta: float) -> void:
	var turn := _turned
	_turned = 0.0
	var limit := deg_to_rad(max_drift)
	var fade := rate * delta
	if fade < 0.0001:
		_drift = clampf(_drift - turn, -limit, limit)
		return
	var kept := exp(-fade)
	_drift = clampf(_drift * kept - turn * (1.0 - kept) / fade, -limit, limit)


## The tightest corner the car can hold at a given speed, in metres.
func turn_radius_at(speed: float) -> float:
	# Squared, so the car stays tight through slow corners and only washes
	# wide as it approaches top speed.
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
	# Where the car is actually going, which is where it is pointing turned
	# back by however far the travel is still lagging the nose.
	var travel := (-global_transform.basis.z).rotated(Vector3.UP, _drift)
	# A push from the other car rides on top of the car's own speed rather
	# than changing it, and fades away.
	_shove = _shove.move_toward(Vector3.ZERO,
		side_push / maxf(push_fade, 0.001) * delta)
	velocity.x = travel.x * _speed + _shove.x
	velocity.z = travel.z * _speed + _shove.z
	if _rebound > 0.0:
		# Thrown back off a barrier just hit. Whatever of the car's own speed
		# is still carrying it into the face is taken out of where it goes -
		# not out of its speed - and the throw put in instead, fading.
		_rebound = maxf(_rebound - delta, 0.0)
		var into := -(velocity.x * _rebound_normal.x + velocity.z * _rebound_normal.z)
		var off := (maxf(into, 0.0)
			+ _rebound_speed * _rebound / maxf(obstacle_bounce_time, 0.001))
		velocity.x += _rebound_normal.x * off
		velocity.z += _rebound_normal.z * off
	var grounded := is_on_floor()
	var bouncing := _bounce > 0.0
	if bouncing:
		velocity.y = _bounce
		_bounce = 0.0
	elif grounded:
		velocity.y = 0.0
	else:
		velocity.y -= gravity * delta
	# How fast it is coming down, taken before move_and_slide lands it and
	# takes that away.
	var falling := -velocity.y
	move_and_slide()
	_moved = true

	if is_on_floor():
		# Measured rather than worked out from the slope: this is the height
		# the car actually gained, so it is right on a ramp, on a crest and on
		# the eased-off climbs alike. Kept as a fading peak rather than as
		# whatever the last step did, for the reason climb_memory gives.
		var measured := (global_position.y - _last_height) / maxf(delta, 0.0001)
		_climb = maxf(measured, _climb - climb_memory * delta)
		_note_the_floor()
		if not grounded:
			# Touched down on this step, and this is how hard, which is what
			# the body sinks onto its springs with.
			_landing = maxf(falling, 0.0)
		if not grounded and not bouncing:
			_bounce_off_a_roof(falling)
	elif grounded and not bouncing:
		# The step it left the ground on.
		velocity.y = clampf(_climb * launch, -max_launch, max_launch)
		# And spent. Nothing wears the climb away while the car is in the air,
		# so a car left holding it comes down still carrying the ramp, and
		# throws itself up again off the next edge it runs out of floor on -
		# the other car's roof, the end of the landing, a crest just past
		# touchdown - until climb_memory has worn it away seconds later.
		_climb = 0.0
	_last_height = global_position.y
	_take_the_hits()


## Throw the car back up if what it has just come down on is the other car.
##
## Only a floor counts. A car that comes down across the other car's flank, or
## clips a corner of it on the way past, has hit a wall, and a wall throws
## nothing back up. The bounce is capped the way a launch off a lip is, for
## the same reason: a car thrown far higher than the thing it hit looks like it
## was fired, not bounced.
func _bounce_off_a_roof(falling: float) -> void:
	if falling < roof_bounce_min:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_collider() is Car and collision.get_angle() <= floor_max_angle:
			_bounce = minf(falling * roof_bounce, max_launch)
			return


## Signed speed along the car's own heading, in m/s. Positive is forwards.
func speed() -> float:
	return _speed


## Where the steering is, from -1 at full right lock to +1 at full left: not
## what was asked of it, but how far the easing has got towards that.
func steering() -> float:
	return _steer


## The slip angle: how far the way the car is travelling lags the way it is
## pointing, in radians. Positive is travelling to the left of the nose, which
## is what a car set into a right-hand corner is doing.
func drift() -> float:
	return _drift


## The middle of the car's body, in the world. The origin sits down at the
## wheels, which is the wrong point to ask whether a car went through a ring:
## a car whose wheels scraped under the rim went under it.
func middle() -> Vector3:
	return ($Collision as CollisionShape3D).global_position


## Whether the last thing the car stood on was the road, for the race to ask
## before it banks a checkpoint or lets the car finish. A car in the air has not
## left the road it took off from.
func on_the_road() -> bool:
	return not _off_road


## Remember whether what the car is standing on is the road. The other car
## does not count either way, and a car the physics has not reported touching
## anything this step keeps what it had.
func _note_the_floor() -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		if collision.get_angle() > floor_max_angle:
			continue
		var collider := collision.get_collider() as Node
		if collider == null or collider is Car:
			return
		_off_road = not collider.is_in_group(ROAD_GROUP)
		return


## Take a knock from the other car: `change` in m/s along the car's own
## heading, and `push` across the ground, fading over push_fade. Handed over
## by CarContact, which has worked out both cars' knocks together.
##
## A loss slows the car towards a standstill and never through it. A gain is
## capped at the car's own top speed, and never takes a car that is already
## over it - on a fading boost - any higher. The boost itself is left alone,
## for either car: the other car is not the hazard a pad was offered against,
## and a boost that a rival could end just by getting in the way would make
## blocking pay.
func knock(change: float, push: Vector3) -> void:
	if change < 0.0:
		_speed = move_toward(_speed, 0.0, -change)
	elif change > 0.0:
		_speed = minf(_speed + change, maxf(top_speed(), _speed))
	if push.length_squared() > _shove.length_squared():
		_shove = push


## Whether the car moved on its last step, forgetting it as it is asked.
## What move_and_slide ran into is kept until the next move, so a car held
## frozen still reports the last thing it touched, however long ago that was.
func take_moved() -> bool:
	var moved := _moved
	_moved = false
	return moved


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
		# Charged on the speed the car hit with, before the hit takes it away,
		# and behind the same recovery gate: one hit, one charge, however many
		# frames the car spends touching the face.
		if damage:
			_condition = maxf(_condition
				- full_hit * head_on * maxf(_speed, 0.0) / maxf(max_speed, 0.001), 0.0)
		_speed *= 1.0 - obstacle_scrub * head_on
		_hit_recovery = obstacle_recovery
		# And thrown back off the face, for the reason obstacle_bounce gives,
		# by as much as the hit was square.
		var away := collision.get_normal()
		away.y = 0.0
		if away.length_squared() > 0.0001 and head_on > 0.0:
			_rebound_normal = away.normalized()
			_rebound_speed = obstacle_bounce * head_on
			_rebound = obstacle_bounce_time
		# A hit ends the boost outright rather than scaling it. Carrying a pad
		# through the hazard it was offered against would leave nothing to
		# weigh up, which is the whole of what the pad is for.
		_boost = 0.0
		_boost_hold = 0.0
		return


## Work out how far the shell tips to follow the road, and in the air to follow
## the flight. It is put on the shell by _lean, with the body's own lean on top.
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
	_sink_to_the_road(delta)


## Sink the shell onto the road the box is holding it off, and let it back up
## again once the car leaves the ground.
##
## Measured straight down from the middle of the car rather than worked out
## from the slope, because the slope only gives the right answer where the road
## is flat under the whole car. A ramp that steepens the whole way up is
## already not, and a crest with the car astride it is the case that would
## bury the shell: the road under the middle is right there under the wheels
## while the surface the box is resting on reads as a slope.
##
## Not eased, either, unlike the pitch. The pitch is eased because what the car
## is standing on changes in steps - one triangle's normal to the next, and all
## at once on landing - but the height of the road under the middle of the car
## does not. It is one surface and the car is driving along it, and easing it
## only ever puts the shell where the road was a moment ago, which on the way
## up a ramp is a shell still hanging off it.
func _sink_to_the_road(delta: float) -> void:
	if not is_on_floor():
		# Nothing to sit on. Eased back up rather than dropped, at the rate the
		# tipping eases at, so a car that leaves a lip with its shell sunk onto
		# it does not pop up off it as it goes.
		_sink = lerpf(_sink, 0.0, 1.0 - exp(-pitch_ease * delta))
		return
	# A box this long cannot hold its middle further off the road than tipping
	# it to max_pitch would lift it, so that is as far down as there is any
	# point in looking.
	var reach := _box_reach * tan(deg_to_rad(max_pitch))
	var from := global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(
		from, from + Vector3.DOWN * (reach + 0.5), collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		# Road under the box but none under the middle of it: the car is out
		# over the hole a jump is made of, or past the edge of a bridge, with
		# the box still resting on what is behind it. There is nothing to
		# measure against, so the shell stays where it is until the car is
		# either back over road or off the ground - which at a lip is the next
		# thing that happens anyway.
		return
	_sink = clampf(global_position.y - (hit["position"] as Vector3).y, 0.0, reach)


## Lean the body on its springs with what the car is doing, and put the road
## pitch and the lean on the shell together.
##
## The pulls are worked out from how the car actually moved rather than from
## what the player asked of it, the same as the wheels are. A car held against
## a barrier with the throttle down does not squat as though it were pulling
## away, and a car turned by something other than the steering - the bot
## drivers turn the body directly - still leans into the turn.
##
## In the air there is nothing to lean against, so the body swings back to
## sitting square while the road pitch follows the flight.
func _lean(delta: float) -> void:
	var step := maxf(delta, 0.0001)
	var forward := -global_transform.basis.z
	var ground_speed := get_real_velocity().dot(forward)
	var turning := angle_difference(_last_yaw, rotation.y) / step
	var pull := (ground_speed - _last_ground_speed) / step
	_last_yaw = rotation.y
	_last_ground_speed = ground_speed

	var roll_to := 0.0
	var dive_to := 0.0
	if is_on_floor():
		# Sideways pull is speed times how fast the heading is turning. A car
		# turning left is pulled left and its body swings out to the right,
		# which drops the right side: a negative roll.
		roll_to = deg_to_rad(-roll_per_accel * ground_speed * turning)
		dive_to = deg_to_rad(dive_per_accel * pull)
	var roll := _spring(_roll, _roll_rate, roll_to, deg_to_rad(max_roll), delta)
	var dive := _spring(_dive, _dive_rate, dive_to, deg_to_rad(max_dive), delta)
	if _landing > 0.0:
		# Knocked rather than pushed: the car does not sit any lower for having
		# landed, it is thrown down onto its springs and comes back up.
		_drop_rate -= _landing * landing_give
		_landing = 0.0
	var drop := _spring(_drop, _drop_rate, 0.0, max_squash, delta)
	_roll = roll.x
	_roll_rate = roll.y
	_dive = dive.x
	_dive_rate = dive.y
	_drop = drop.x
	_drop_rate = drop.y
	# The sink is not a lean and does not ride on the springs: it is the shell
	# being put down on the road the box has lifted it off. It goes to the
	# shell on its own rather than folded into the spring's drop, because the
	# wheels have to come down with it and they do not come down with the drop.
	_shell.pose(_pitch, _dive, _roll, _drop, _sink)


## One step of a damped spring pulling `value` towards `target`, with the target
## and the value both kept within `limit` either side of rest. Returns the new
## value and how fast it is now moving.
func _spring(value: float, rate: float, target: float, limit: float,
		delta: float) -> Vector2:
	target = clampf(target, -limit, limit)
	rate += (body_spring * (target - value) - body_damping * rate) * delta
	value += rate * delta
	if absf(value) > limit:
		value = signf(value) * limit
		rate = 0.0
	return Vector2(value, rate)


## How fast the wheels turn: at exactly the speed the car is covering the road
## while it is on it, which is what stops them spinning flat out against a
## barrier or the other car, and in the air at whatever they left the road
## with, slowly running down.
func _roll_wheels(delta: float) -> void:
	if is_on_floor():
		_wheel_speed = get_real_velocity().dot(-global_transform.basis.z)
	else:
		_wheel_speed = move_toward(_wheel_speed, 0.0, air_wheel_fade * delta)
