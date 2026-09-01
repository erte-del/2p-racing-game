class_name Track
extends Node3D

## A procedurally generated circuit: a random closed loop, a road mesh whose
## width follows the curvature, and a mountain range down each side.
##
## The road is built as a mesh rather than extruded with CSGPolygon3D because
## CSG has a single fixed cross-section for the whole path, so it cannot make
## the road narrow in the corners. Building the ribbon by hand also gives the
## collision shape and the mountains the same sampling for free.

signal regenerated

@export_group("Shape")
@export var min_points := 11
@export var max_points := 15
@export var min_radius := 100.0
@export var max_radius := 160.0
## Angular wobble per control point. Must stay well under half the angular
## step, or points can swap order and the loop crosses itself.
@export var angle_jitter := 0.28

@export_group("Road")
## Distance between cross-sections. Smaller is smoother and heavier.
@export var sample_step := 2.5
@export var wide_half_width := 8.0
@export var narrow_half_width := 4.2
@export var kerb_width := 1.1
## Height of the road surface above the ground plane.
@export var road_height := 0.06
## Curvature (1/metres) at which the road reaches its narrowest. A 50 m radius
## corner is 0.02, a 100 m radius sweeper is 0.01.
@export var curvature_for_narrow := 0.019

@export_group("Mountains")
## Flat ground between the kerb and the foot of the range.
@export var verge := 4.0
## Horizontal distance from the foot of the range up to the crest.
@export var ridge_run := 9.0
## Horizontal distance from the crest down the far side.
@export var outer_run := 20.0
@export var min_height := 8.0
@export var max_height := 30.0
@export var noise_frequency := 0.011
## Peaks above this fraction of max_height get a snow cap.
@export var snow_line := 0.72

@onready var _path: Path3D = $Path3D
@onready var _road: MeshInstance3D = $Road
@onready var _road_shape: CollisionShape3D = $RoadBody/Shape
@onready var _mountains: MeshInstance3D = $Mountains
@onready var _mountain_shape: CollisionShape3D = $MountainBody/Shape

## Cross-sections of the finished road, kept so the race can query the track.
var _points: PackedVector3Array
var _rights: PackedVector3Array
var _half_widths: PackedFloat32Array
## Signed curvature per sample; positive bends right.
var _curvature: PackedFloat32Array

var _asphalt: StandardMaterial3D
var _kerb: StandardMaterial3D
var _rock: StandardMaterial3D


func _ready() -> void:
	_build_materials()


## The curve is the source of truth for lap length, progress and the grid.
func curve() -> Curve3D:
	return _path.curve


## Half-width of the road at a distance along the curve, for spawning and
## for telling whether a car has left the track.
func half_width_at(offset: float) -> float:
	if _half_widths.is_empty():
		return wide_half_width
	var i := int(offset / sample_step) % _half_widths.size()
	return _half_widths[i]


## Rebuild the whole circuit from a seed. Passing the same seed twice gives
## the same track, which makes problems reproducible.
func generate(track_seed: int) -> void:
	if _asphalt == null:
		_build_materials()

	var rng := RandomNumberGenerator.new()
	rng.seed = track_seed

	_path.curve = _random_loop(rng)
	_measure_road()
	_build_road()
	_build_mountains(track_seed)
	regenerated.emit()


# --- shape -------------------------------------------------------------

## A closed loop of control points at increasing angles around the origin.
## Keeping the angles strictly increasing and the radii positive makes the
## polygon star-shaped, which guarantees it cannot cross itself.
func _random_loop(rng: RandomNumberGenerator) -> Curve3D:
	var count := rng.randi_range(min_points, max_points)
	var step := TAU / count
	var jitter: float = minf(angle_jitter, step * 0.35)

	# Build the radius from a few harmonics around the loop rather than from
	# independent random values. Independent values had to be smoothed so hard
	# to avoid undrivable spikes that every circuit came out a near-circle;
	# harmonics give long straights and real corners while staying smooth.
	# Vary the overall size too, or every circuit comes out the same length.
	var mid := (min_radius + max_radius) * 0.5 * rng.randf_range(0.8, 1.2)
	var swing := (max_radius - min_radius) / (min_radius + max_radius)
	var amp := [
		rng.randf_range(0.45, 1.0) * swing,
		rng.randf_range(0.30, 0.75) * swing,
		rng.randf_range(0.15, 0.45) * swing,
	]
	var phase := [rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU]

	var radii := PackedFloat32Array()
	for i in count:
		var theta := step * i
		var shape := 1.0
		for h in 3:
			shape += amp[h] * sin(float(h + 1) * theta + phase[h])
		# A little per-point noise keeps corners from feeling mechanical.
		radii.append(mid * shape * rng.randf_range(0.97, 1.03))
	radii = _smooth_cyclic(radii, 1, 1)

	var flat: Array[Vector2] = []
	for i in count:
		var angle := step * i + rng.randf_range(-jitter, jitter)
		flat.append(Vector2(cos(angle), sin(angle)) * radii[i])

	var curve := Curve3D.new()
	for i in count + 1:  # repeat the first point so the curve truly closes
		var j := i % count
		var prev := flat[(j - 1 + count) % count]
		var next := flat[(j + 1) % count]
		# Catmull-Rom tangent, converted to a bezier handle length.
		var tangent := (next - prev) * 0.5 / 3.0
		curve.add_point(
			Vector3(flat[j].x, road_height, flat[j].y),
			Vector3(-tangent.x, 0.0, -tangent.y),
			Vector3(tangent.x, 0.0, tangent.y)
		)
	return curve


## Walk the curve at a fixed spacing, recording position, sideways direction
## and a width that narrows through the corners.
func _measure_road() -> void:
	var c := curve()
	var lap := c.get_baked_length()
	var count := maxi(8, int(lap / sample_step))

	_points = PackedVector3Array()
	_rights = PackedVector3Array()
	for i in count:
		var here := c.sample_baked(fposmod(float(i) * sample_step, lap))
		var ahead := c.sample_baked(fposmod(float(i + 1) * sample_step, lap))
		var forward := ahead - here
		forward.y = 0.0
		if forward.length_squared() < 0.000001:
			forward = Vector3.FORWARD
		forward = forward.normalized()
		_points.append(here)
		_rights.append(forward.cross(Vector3.UP))

	# Signed curvature from the turn angle between neighbouring segments.
	# Positive means the track is bending to the right, which tells the
	# mountain builder which side is the inside of the corner.
	var raw := PackedFloat32Array()
	for i in count:
		var a := _points[(i - 1 + count) % count]
		var b := _points[i]
		var d := _points[(i + 1) % count]
		var into := (b - a)
		var out_of := (d - b)
		if into.length_squared() < 0.000001 or out_of.length_squared() < 0.000001:
			raw.append(0.0)
			continue
		var f0 := into.normalized()
		var f1 := out_of.normalized()
		# A right-hand turn rotates the heading towards +right, giving a
		# negative Y on this cross product, so negate to make right positive.
		var direction := signf(-f0.cross(f1).y)
		raw.append(direction * f0.angle_to(f1) / sample_step)
	# Smooth hard, so the road tapers into a corner instead of stepping.
	raw = _smooth_cyclic(raw, 6, 3)
	_curvature = raw

	_half_widths = PackedFloat32Array()
	for i in count:
		var tightness := clampf(absf(raw[i]) / curvature_for_narrow, 0.0, 1.0)
		_half_widths.append(lerpf(wide_half_width, narrow_half_width, tightness))


func _smooth_cyclic(values: PackedFloat32Array, passes: int, window: int) -> PackedFloat32Array:
	var n := values.size()
	var current := values.duplicate()
	for _pass in passes:
		var next := current.duplicate()
		for i in n:
			var total := 0.0
			for k in range(-window, window + 1):
				total += current[(i + k + n) % n]
			next[i] = total / float(window * 2 + 1)
		current = next
	return current


# --- road --------------------------------------------------------------

func _build_road() -> void:
	var count := _points.size()
	var mesh := ArrayMesh.new()

	var asphalt := SurfaceTool.new()
	asphalt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kerbs := SurfaceTool.new()
	kerbs.begin(Mesh.PRIMITIVE_TRIANGLES)

	var run := 0.0
	for i in count:
		var j := (i + 1) % count
		var run_next := run + sample_step

		var pi := _points[i]
		var pj := _points[j]
		var ri := _rights[i]
		var rj := _rights[j]
		var wi := _half_widths[i]
		var wj := _half_widths[j]

		_strip(asphalt, pi - ri * wi, pi + ri * wi, pj - rj * wj, pj + rj * wj, run, run_next)
		# A kerb strip either side, sitting just outside the asphalt.
		_strip(kerbs, pi - ri * (wi + kerb_width), pi - ri * wi,
				pj - rj * (wj + kerb_width), pj - rj * wj, run, run_next)
		_strip(kerbs, pi + ri * wi, pi + ri * (wi + kerb_width),
				pj + rj * wj, pj + rj * (wj + kerb_width), run, run_next)
		run = run_next

	asphalt.commit(mesh)
	kerbs.commit(mesh)
	_road.mesh = mesh
	_road.set_surface_override_material(0, _asphalt)
	_road.set_surface_override_material(1, _kerb)
	_road_shape.shape = mesh.create_trimesh_shape()


## One quad of road, given its two left and two right edge points.
func _strip(
	st: SurfaceTool, left_a: Vector3, right_a: Vector3,
	left_b: Vector3, right_b: Vector3, run_a: float, run_b: float
) -> void:
	var v := run_a / 8.0
	var v_next := run_b / 8.0
	st.set_normal(Vector3.UP)
	# Wound clockwise seen from above, which is Godot's front face. Getting
	# this backwards makes the road invisible from above and, because a
	# ConcavePolygonShape3D only collides with its front faces, drivable
	# straight through.
	for corner in [
		[left_a, 0.0, v], [right_b, 1.0, v_next], [right_a, 1.0, v],
		[left_a, 0.0, v], [left_b, 0.0, v_next], [right_b, 1.0, v_next],
	]:
		st.set_uv(Vector2(corner[1], corner[2]))
		st.add_vertex(corner[0])


# --- mountains ---------------------------------------------------------

## A ridge down each side of the track. Each cross-section is a foot, a crest
## and an outer foot, so the range reads as terrain rather than as a wall,
## while still being far too steep to drive up.
func _build_mountains(track_seed: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = track_seed
	noise.frequency = noise_frequency
	noise.fractal_octaves = 3

	var count := _points.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for side: float in [-1.0, 1.0]:
		var crests := PackedFloat32Array()
		var runs := PackedFloat32Array()
		for i in count:
			var p := _points[i]
			# Offset the noise per side so the two ranges differ.
			var n := noise.get_noise_2d(p.x + side * 500.0, p.z)
			crests.append(lerpf(min_height, max_height, (n + 1.0) * 0.5))
			runs.append(ridge_run * lerpf(0.75, 1.45, (noise.get_noise_2d(
					p.z * 2.0, p.x + side * 250.0) + 1.0) * 0.5))
		crests = _smooth_cyclic(crests, 1, 1)
		runs = _smooth_cyclic(runs, 1, 1)

		# Mirroring the cross-section to the inside of the loop reverses the
		# winding, so that side has to be wound the other way or its faces
		# point into the mountain and the whole inner range is invisible.
		var flip: bool = side < 0.0
		var scales := _ridge_scales(side, runs)
		for i in count:
			var j := (i + 1) % count
			var a := _ridge_section(i, side, crests[i], runs[i], scales[i])
			var b := _ridge_section(j, side, crests[j], runs[j], scales[j])
			# foot -> crest, then crest -> outer foot
			_ridge_quad(st, a[0], a[1], b[0], b[1], crests[i], crests[j], flip)
			_ridge_quad(st, a[1], a[2], b[1], b[2], crests[i], crests[j], flip)

	st.generate_normals()
	var mesh: ArrayMesh = st.commit()
	_mountains.mesh = mesh
	_mountains.set_surface_override_material(0, _rock)
	_mountain_shape.shape = mesh.create_trimesh_shape()


## The three points of one mountain cross-section: inner foot, crest, outer foot.
func _ridge_section(i: int, side: float, crest: float, run: float, scale: float) -> Array:
	var p := _points[i]
	var r := _rights[i] * side
	var foot_at := _half_widths[i] + kerb_width + verge
	var rise := run * scale
	var fall := outer_run * scale
	return [
		p + r * foot_at,
		p + r * (foot_at + rise) + Vector3.UP * (crest * scale),
		p + r * (foot_at + rise + fall),
	]


## How far the range may reach on this side before its offset line folds
## through itself. Offsetting a curve inwards by more than the local radius of
## curvature creates a cusp, which threw mountain geometry across the road.
func _ridge_scales(side: float, runs: PackedFloat32Array) -> PackedFloat32Array:
	var scales := PackedFloat32Array()
	for i in _points.size():
		var foot_at := _half_widths[i] + kerb_width + verge
		var bend := _curvature[i]
		var scale := 1.0
		# side and bend share a sign when this side is the inside of the turn.
		if side * bend > 0.0 and absf(bend) > 0.0001:
			var room: float = 0.8 / absf(bend)
			var natural := foot_at + runs[i] + outer_run
			if room < natural:
				scale = maxf(room / natural, 0.3)
		scales.append(scale)
	# Smooth it, or neighbouring sections shrink by very different amounts and
	# the range breaks up into thin slivers.
	return _smooth_cyclic(scales, 3, 2)


func _ridge_quad(
	st: SurfaceTool, a0: Vector3, a1: Vector3, b0: Vector3, b1: Vector3,
	crest_a: float, crest_b: float, flip: bool
) -> void:
	var corners := [[a0, crest_a], [a1, crest_a], [b1, crest_b],
			[a0, crest_a], [b1, crest_b], [b0, crest_b]]
	if flip:
		corners = [[a0, crest_a], [b1, crest_b], [a1, crest_a],
				[a0, crest_a], [b0, crest_b], [b1, crest_b]]
	for corner in corners:
		var point: Vector3 = corner[0]
		st.set_color(_rock_colour(point.y, corner[1]))
		st.add_vertex(point)


## Grass at the foot, rock up the slope, snow on the highest crests.
func _rock_colour(height: float, crest: float) -> Color:
	var up := clampf(height / maxf(crest, 0.001), 0.0, 1.0)
	var colour := Color(0.30, 0.40, 0.24).lerp(Color(0.36, 0.34, 0.32), smoothstep(0.05, 0.55, up))
	var snow := smoothstep(snow_line, 1.0, crest / max_height) * smoothstep(0.72, 0.98, up)
	return colour.lerp(Color(0.93, 0.94, 0.96), snow)


# --- materials ---------------------------------------------------------

func _build_materials() -> void:
	_asphalt = StandardMaterial3D.new()
	_asphalt.albedo_color = Color(0.176, 0.18, 0.196)
	_asphalt.roughness = 0.92

	_kerb = StandardMaterial3D.new()
	_kerb.albedo_color = Color(0.85, 0.85, 0.87)
	_kerb.roughness = 0.8

	_rock = StandardMaterial3D.new()
	_rock.vertex_color_use_as_albedo = true
	_rock.roughness = 0.95
