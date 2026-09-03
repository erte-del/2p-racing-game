class_name Chaos
extends RefCounted

## Everything chaos mode changes about a race, in one place.
##
## Chaos rerolls the world for every course: how quick the cars are, how hard
## they are held down, how the course is laid out, and where the clock stands
## in the day. What it will not do is roll a race that cannot be driven, so
## every number here is a range with both ends picked to stay playable rather
## than a free multiplier - fast enough to be a handful, never fast enough to
## be a passenger.
##
## Both cars always get the same roll. Two players sharing one keyboard are
## racing each other, and a race decided by which seat drew the faster car is
## not chaos, it is broken.
##
## The tuned values are read once, when this is built, and every roll is made
## against those. Rolling against whatever the last course left behind would
## compound: a session would drift faster and faster until nothing was
## driveable.

## How far the cars' top speed may stray from the tuned 25 m/s. The floor is
## slow enough to feel heavy without dragging the race out; the ceiling is
## genuinely quick, and is the point at which the corners start to matter.
const SPEED_SCALE := Vector2(0.78, 1.7)
## How much of the speed roll the pull off the line follows, plus its own
## jitter. A quick car that will not accelerate is only frustrating.
const ACCELERATION_JITTER := Vector2(0.9, 1.4)
## Stopping power follows speed and never drops below tuned, so a fast roll
## cannot also be a roll that will not slow down for the corner.
const BRAKING_FLOOR := 1.0
## How much of the speed roll the turning circle follows. Held well under the
## full scale so the fastest cars still steer, and well under the tightest
## corner chaos will lay down, so the road is never sharper than the car.
const STEERING_FOLLOW := 0.5
const STEERING_JITTER := Vector2(0.9, 1.1)
## Floaty to heavy. Lower makes the crests throw the car; much below this and
## a landing stops being recoverable.
const GRAVITY_SCALE := Vector2(0.65, 1.4)
## The tow a car gets from sitting in the other's wake, from none at all to
## rather more than the tuned 0.22.
const SLIPSTREAM_BONUS := Vector2(0.0, 0.55)

## The shape of the course. Corner radius and straight length are what decide
## how twisty it is; the widths decide how much room there is to be wrong in.
const MIN_CORNER_RADIUS := Vector2(13.0, 22.0)
const CORNER_RADIUS_SPREAD := Vector2(15.0, 45.0)
const MIN_STRAIGHT := Vector2(12.0, 45.0)
const STRAIGHT_SPREAD := Vector2(30.0, 110.0)
const MIN_COURSE_LENGTH := Vector2(380.0, 800.0)
const COURSE_LENGTH_SPREAD := Vector2(180.0, 550.0)
## Half-widths. The narrow end is still wider than the starting grid is set to
## spread, so the cars can always be lined up on the road.
const NARROW_HALF_WIDTH := Vector2(3.6, 5.6)
const WIDTH_SPREAD := Vector2(1.5, 4.5)
const CHECKPOINTS := Vector2i(3, 6)

## How far a car flies off a ramp, as powers of the speed and gravity rolls.
## Measured off real flights rather than worked out: the launch is capped, so
## range does not follow the clean projectile square of speed.
const FLIGHT_BY_SPEED := 1.4
const FLIGHT_BY_GRAVITY := 0.75
## The least of the tuned hole a roll may be asked to clear. Below this the
## hole stops being longer than the car, and a hole a car can lie across is
## one it drives over without ever leaving the ground.
const MIN_JUMP_GAP := 0.5

## The day, sped up. Both holds and the fades are rolled separately, so one
## race runs a long afternoon and the next flickers between dusk and dawn -
## but the fades stay long enough that it reads as a sky and not a light
## switch.
const DAY_SECONDS := Vector2(8.0, 75.0)
const NIGHT_SECONDS := Vector2(8.0, 75.0)
const TRANSITION_SECONDS := Vector2(5.0, 25.0)

var _cars: Array[Car] = []
var _day_night: DayNight
var _track: Track

## The tuned values every roll is made against.
var _base_car := {}
## The tuned hole, which every roll is measured against for the same reason
## the cars are: scaling whatever the last course left behind would compound.
var _base_gap := 0.0
## The speed and gravity this roll gave the cars, which is what decides how
## far they can throw themselves off a ramp.
var _speed_roll := 1.0
var _gravity_roll := 1.0


func _init(cars: Array[Car], day_night: DayNight, track: Track) -> void:
	_cars = cars
	_day_night = day_night
	_track = track
	if _track != null:
		_base_gap = _track.jump_gap
	if not _cars.is_empty():
		var car := _cars[0]
		_base_car = {
			"max_speed": car.max_speed,
			"acceleration": car.acceleration,
			"braking": car.braking,
			"tight_turn_radius": car.tight_turn_radius,
			"fast_turn_radius": car.fast_turn_radius,
			"gravity": car.gravity,
		}


## Roll a new world. Called before the course is generated, since the shape of
## the course is part of what is being rolled.
func reroll(rng: RandomNumberGenerator) -> void:
	_roll_the_cars(rng)
	_roll_the_course(rng)
	_roll_the_sky(rng)


## One roll, both cars.
func _roll_the_cars(rng: RandomNumberGenerator) -> void:
	if _base_car.is_empty():
		return
	var speed := _spread(rng, SPEED_SCALE)
	var steering: float = (lerpf(1.0, speed, STEERING_FOLLOW)
			* _spread(rng, STEERING_JITTER))
	var acceleration := speed * _spread(rng, ACCELERATION_JITTER)
	var braking: float = maxf(speed, BRAKING_FLOOR)
	var gravity := _spread(rng, GRAVITY_SCALE)
	var slipstream := _spread(rng, SLIPSTREAM_BONUS)
	# Kept, because the course is rolled next and the hole in a jump has to be
	# one these cars can clear.
	_speed_roll = speed
	_gravity_roll = gravity

	for car in _cars:
		car.max_speed = _base_car["max_speed"] * speed
		car.acceleration = _base_car["acceleration"] * acceleration
		car.braking = _base_car["braking"] * braking
		car.tight_turn_radius = _base_car["tight_turn_radius"] * steering
		car.fast_turn_radius = _base_car["fast_turn_radius"] * steering
		car.gravity = _base_car["gravity"] * gravity
		car.slipstream_bonus = slipstream


## The course is described as a floor and a spread rather than as two ends, so
## a roll can never hand the generator a minimum above its maximum.
func _roll_the_course(rng: RandomNumberGenerator) -> void:
	if _track == null:
		return
	_track.min_corner_radius = _spread(rng, MIN_CORNER_RADIUS)
	_track.max_corner_radius = (_track.min_corner_radius
			+ _spread(rng, CORNER_RADIUS_SPREAD))
	_track.min_straight = _spread(rng, MIN_STRAIGHT)
	_track.max_straight = _track.min_straight + _spread(rng, STRAIGHT_SPREAD)
	_track.min_course_length = _spread(rng, MIN_COURSE_LENGTH)
	_track.max_course_length = (_track.min_course_length
			+ _spread(rng, COURSE_LENGTH_SPREAD))
	_track.narrow_half_width = _spread(rng, NARROW_HALF_WIDTH)
	_track.wide_half_width = (_track.narrow_half_width
			+ _spread(rng, WIDTH_SPREAD))
	_track.checkpoint_count = rng.randi_range(CHECKPOINTS.x, CHECKPOINTS.y)
	# The hole a jump leaves is the one thing about a course that has to be
	# measured against the cars rather than rolled freely. A world of slow,
	# heavy cars cannot throw them as far, and a hole they cannot clear flat
	# out is not a risk, it is a wall across the road.
	_track.jump_gap = _base_gap * jump_gap_scale(_speed_roll, _gravity_roll)


func _roll_the_sky(rng: RandomNumberGenerator) -> void:
	if _day_night == null:
		return
	var day := _spread(rng, DAY_SECONDS)
	var night := _spread(rng, NIGHT_SECONDS)
	var fade := _spread(rng, TRANSITION_SECONDS)
	# Anywhere in the cycle, so a race can open at noon, at midnight or in the
	# middle of a sunset.
	var cycle := day + night + 2.0 * fade
	_day_night.retime(day, night, fade, rng.randf_range(0.0, cycle))


## How much of the tuned hole cars rolled this way can be asked to clear.
##
## Never more than the tuned one: a faster world could clear a longer hole,
## but the road to come down on is a fixed length, and a jump that got wider
## every time chaos rolled a quick car would eventually outrun its landing.
static func jump_gap_scale(speed: float, gravity: float) -> float:
	var reach := pow(speed, FLIGHT_BY_SPEED) / pow(gravity, FLIGHT_BY_GRAVITY)
	return clampf(reach, MIN_JUMP_GAP, 1.0)


## The ranges are written as vectors so each one reads as its two ends on a
## single line; this is what turns one into a number.
func _spread(rng: RandomNumberGenerator, range_: Vector2) -> float:
	return rng.randf_range(range_.x, range_.y)
