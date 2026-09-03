class_name DayNight
extends Node

## Turns the world from day to night and back on a fixed clock.
##
## The cycle is a hold, a fade, a hold, a fade: three minutes of daylight, a
## sunset, three minutes of night, a sunrise. The holds are what the times name
## - "night lasts three minutes" means three minutes of actual night, with the
## fades on either side of it rather than eaten out of it.
##
## It drives three things that have to move together, or the scene reads wrong:
## the sun, the sky, and the ambient light. Dimming only the sun leaves a bright
## blue sky at midnight; dimming only the sky leaves black grass under a white
## sun.
##
## The clock is wall clock time from the moment the game starts, and it is
## deliberately not reset when a new course is generated - a session that runs
## through several courses should still get to night.

## Seconds of full daylight before the sun starts to go down.
@export var day_seconds := 180.0
## Seconds of full night before it starts to come back up.
@export var night_seconds := 180.0
## How long each fade takes. This sits between the holds, not inside them.
@export var transition_seconds := 25.0
## Skip straight to this point in the cycle at startup, in seconds. Handy for
## looking at the night without waiting three minutes for it.
@export var start_offset := 0.0

@export_group("Sun")
## Which way the sun sits, in degrees round the compass.
@export var sun_azimuth := 30.0
## How far the moon is swung round from the sun, in degrees, so it does not
## simply pop back up where the sun went down.
@export var moon_azimuth_offset := 150.0
## Height above the horizon, in degrees, at midday / sunset / midnight.
@export var sun_elevation := 35.0
@export var dusk_elevation := 1.0
@export var moon_elevation := 52.0

@export_group("Nodes")
@export var sun_path: NodePath = ^"../Sun"
@export var environment_path: NodePath = ^"../WorldEnvironment"

# Each look is described at three points: full day, the middle of the fade, and
# full night. The fade runs day -> dusk -> night, which is what puts an orange
# sun on the horizon on the way past rather than simply dimming the daylight.
const SUN_COLOUR := [
	Color(1.0, 0.97, 0.92), Color(1.0, 0.55, 0.25), Color(0.55, 0.68, 1.0),
]
const SUN_ENERGY := [1.0, 0.5, 0.32]
const SKY_TOP := [
	Color(0.32, 0.52, 0.85), Color(0.28, 0.30, 0.52), Color(0.02, 0.03, 0.08),
]
const SKY_HORIZON := [
	Color(0.72, 0.82, 0.92), Color(0.95, 0.52, 0.28), Color(0.06, 0.08, 0.18),
]
const GROUND_HORIZON := [
	Color(0.55, 0.55, 0.50), Color(0.45, 0.30, 0.22), Color(0.05, 0.06, 0.10),
]
const GROUND_BOTTOM := [
	Color(0.20, 0.22, 0.20), Color(0.15, 0.12, 0.12), Color(0.02, 0.02, 0.04),
]
## At night the sky is nearly black, so ambient taken from it is nearly nothing
## and the track becomes undrivable. Below full contribution the ambient colour
## fills in, which is the moonlight the players actually see by.
const SKY_CONTRIBUTION := [1.0, 1.0, 0.35]
const AMBIENT_ENERGY := [1.0, 1.0, 1.2]
const MOONLIGHT := Color(0.16, 0.20, 0.34)

var _sun: DirectionalLight3D
var _sky: ProceduralSkyMaterial
var _environment: Environment
var _time := 0.0
## 0 is full day, 1 is full night.
var _nightness := 0.0


func _ready() -> void:
	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	var world := get_node_or_null(environment_path) as WorldEnvironment
	_environment = world.environment if world else null
	if _sun == null or _environment == null:
		push_warning("DayNight: no sun or environment to drive")
		set_process(false)
		return

	# The sky material is a sub-resource of the scene, and these edits are made
	# every frame. Working on a copy keeps the scene's own resource untouched.
	var sky := _environment.sky
	if sky and sky.sky_material is ProceduralSkyMaterial:
		sky.sky_material = sky.sky_material.duplicate()
		_sky = sky.sky_material

	_environment.ambient_light_color = MOONLIGHT
	_time = start_offset
	_apply(_nightness_at(_time))


## How far through the change to night the world is: 0 full day, 1 full night.
## Anything that wants to react to nightfall later - headlights, say - can ask
## rather than keeping a second clock of its own.
func night_amount() -> float:
	return _nightness


func _process(delta: float) -> void:
	_time += delta
	_apply(_nightness_at(_time))


## Where the cycle stands at a given time. Smoothstepped so the fades ease in
## and out instead of starting and stopping abruptly.
func _nightness_at(time: float) -> float:
	var cycle := day_seconds + night_seconds + 2.0 * transition_seconds
	var at := fposmod(time, cycle)
	if at < day_seconds:
		return 0.0
	at -= day_seconds
	if at < transition_seconds:
		return smoothstep(0.0, 1.0, at / transition_seconds)
	at -= transition_seconds
	if at < night_seconds:
		return 1.0
	at -= night_seconds
	return 1.0 - smoothstep(0.0, 1.0, at / transition_seconds)


func _apply(nightness: float) -> void:
	_nightness = nightness

	# The sun drops to the horizon over the first half of the fade and the moon
	# climbs over the second, so the two are never both up.
	var elevation := _blend_number([sun_elevation, dusk_elevation, moon_elevation], nightness)
	var azimuth := sun_azimuth + moon_azimuth_offset * maxf(0.0, nightness - 0.5) * 2.0
	_sun.rotation = Vector3(deg_to_rad(-elevation), deg_to_rad(azimuth), 0.0)
	_sun.light_color = _blend_colour(SUN_COLOUR, nightness)
	_sun.light_energy = _blend_number(SUN_ENERGY, nightness)

	if _sky:
		_sky.sky_top_color = _blend_colour(SKY_TOP, nightness)
		_sky.sky_horizon_color = _blend_colour(SKY_HORIZON, nightness)
		_sky.ground_horizon_color = _blend_colour(GROUND_HORIZON, nightness)
		_sky.ground_bottom_color = _blend_colour(GROUND_BOTTOM, nightness)

	_environment.ambient_light_sky_contribution = _blend_number(SKY_CONTRIBUTION, nightness)
	_environment.ambient_light_energy = _blend_number(AMBIENT_ENERGY, nightness)


## Read a three-key day / dusk / night ramp at a point between 0 and 1.
func _blend_number(keys: Array, at: float) -> float:
	if at <= 0.5:
		return lerpf(keys[0], keys[1], at * 2.0)
	return lerpf(keys[1], keys[2], (at - 0.5) * 2.0)


func _blend_colour(keys: Array, at: float) -> Color:
	if at <= 0.5:
		return keys[0].lerp(keys[1], at * 2.0)
	return keys[1].lerp(keys[2], (at - 0.5) * 2.0)
