class_name Track
extends Node3D

## Builds the world for one course: the road mesh, its collision, and a
## mountain range down each side.
##
## The shape itself comes from TrackLayout, which chains modular pieces. This
## node turns that centreline into geometry. Nothing here wraps from the last
## sample back to the first: a course runs from a start line to a finish line
## and does not rejoin itself, so wrapping would draw a road from the finish
## straight back to the start.

signal regenerated

@export_group("Road")
## Distance between cross-sections. Smaller is smoother and heavier.
@export var sample_step := 2.5
@export var wide_half_width := 8.0
@export var narrow_half_width := 4.2
@export var kerb_width := 1.1
## Height of the start of the course above the ground plane.
@export var road_height := 0.06

@export_group("Shape")
@export var min_course_length := 620.0
@export var max_course_length := 1050.0
@export var min_corner_radius := 11.0
@export var max_corner_radius := 70.0
## How many seeds to try before giving up on finding a valid course.
@export var max_attempts := 60

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

var _layout: TrackLayout
## Cross-sections of the finished road.
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


## The curve is the source of truth for progress along the course and for
## placing the cars on the grid.
func curve() -> Curve3D:
	return _path.curve


## Distance from the start line to the finish line.
func length() -> float:
	return _layout.length() if _layout else 0.0


## Half-width of the road at a distance along the course.
func half_width_at(offset: float) -> float:
	if _half_widths.is_empty():
		return wide_half_width
	var i := clampi(int(offset / sample_step), 0, _half_widths.size() - 1)
	return _half_widths[i]


## The pieces this course was built from, for debugging and for the README.
func piece_summary() -> String:
	if _layout == null:
		return "no course"
	var straights := 0
	var corners := 0
	var climbs := 0
	for piece in _layout.pieces:
		match piece.kind:
			TrackLayout.CORNER: corners += 1
			TrackLayout.CLIMB: climbs += 1
			_: straights += 1
	return "%d pieces (%d straights, %d corners, %d climbs), %.0f m" % [
		_layout.pieces.size(), straights, corners, climbs, length()]


## Lay out a fresh course. The seed is advanced until one is found that neither
## crosses itself nor runs off the ground, so a bad roll costs a retry rather
## than producing a broken track.
func generate(track_seed: int) -> void:
	if _asphalt == null:
		_build_materials()

	var tuning := {
		"step": sample_step,
		"min_length": min_course_length,
		"max_length": max_course_length,
		"min_corner_radius": min_corner_radius,
		"max_corner_radius": max_corner_radius,
		"narrow_half_width": narrow_half_width,
		"wide_half_width": wide_half_width,
	}

	var layout: TrackLayout = null
	for attempt in max_attempts:
		layout = TrackLayout.build(track_seed + attempt, tuning)
		if layout != null:
			break
	if layout == null:
		push_error("Track: no valid course after %d attempts" % max_attempts)
		return

	_layout = layout
	_adopt(layout)
	_build_curve()
	_build_road()
	_build_mountains(track_seed)
	regenerated.emit()


# --- reading the layout -------------------------------------------------

func _adopt(layout: TrackLayout) -> void:
	_points = PackedVector3Array()
	for p in layout.points:
		_points.append(p + Vector3.UP * road_height)
	_half_widths = layout.half_widths

	var count := _points.size()
	_rights = PackedVector3Array()
	for i in count:
		# The last sample has no next point, so it borrows the previous
		# heading rather than wrapping round to the start.
		var a := _points[i if i < count - 1 else count - 2]
		var b := _points[i + 1 if i < count - 1 else count - 1]
		var forward := b - a
		forward.y = 0.0
		if forward.length_squared() < 0.000001:
			forward = Vector3.FORWARD
		_rights.append(forward.normalized().cross(Vector3.UP))

	# Signed curvature, used to decide which side of a corner is the inside.
	var raw := PackedFloat32Array()
	for i in count:
		if i == 0 or i == count - 1:
			raw.append(0.0)
			continue
		var into := _points[i] - _points[i - 1]
		var out_of := _points[i + 1] - _points[i]
		into.y = 0.0
		out_of.y = 0.0
		if into.length_squared() < 0.000001 or out_of.length_squared() < 0.000001:
			raw.append(0.0)
			continue
		var f0 := into.normalized()
		var f1 := out_of.normalized()
		# A right-hand turn rotates the heading towards +right, giving a
		# negative Y on this cross product, so negate to make right positive.
		raw.append(signf(-f0.cross(f1).y) * f0.angle_to(f1) / sample_step)
	_curvature = _smooth(raw, 4, 3)


## Moving average that holds its end values instead of wrapping, since the
## course does not join back to itself.
func _smooth(values: PackedFloat32Array, passes: int, window: int) -> PackedFloat32Array:
	var n := values.size()
	if n < 3:
		return values
	var current := values.duplicate()
	for _pass in passes:
		var next := current.duplicate()
		for i in n:
			var total := 0.0
			for k in range(-window, window + 1):
				total += current[clampi(i + k, 0, n - 1)]
			next[i] = total / float(window * 2 + 1)
		current = next
	return current


func _build_curve() -> void:
	var curve3d := Curve3D.new()
	for p in _points:
		curve3d.add_point(p)
	_path.curve = curve3d


# --- road --------------------------------------------------------------

func _build_road() -> void:
	var count := _points.size()
	var mesh := ArrayMesh.new()

	var asphalt := SurfaceTool.new()
	asphalt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var kerbs := SurfaceTool.new()
	kerbs.begin(Mesh.PRIMITIVE_TRIANGLES)

	var run := 0.0
	for i in count - 1:
		var j := i + 1
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

## A ridge down each side. Each cross-section is a foot on the ground, a crest
## and an outer foot, so the range reads as terrain rather than as a wall while
## still being far too steep to drive up.
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
		crests = _smooth(crests, 1, 1)
		runs = _smooth(runs, 1, 1)
		var scales := _ridge_scales(side, runs)

		# Mirroring the cross-section to the other side reverses the winding,
		# so one side has to be wound the other way or its faces point into
		# the mountain and that whole range is invisible.
		var flip: bool = side < 0.0
		for i in count - 1:
			var j := i + 1
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


## The three points of one mountain cross-section: inner foot, crest, outer
## foot. The feet sit on the ground plane while the crest is measured from the
## road, so the range still towers over a section that has climbed.
func _ridge_section(i: int, side: float, crest: float, run: float, scale: float) -> Array:
	var p := _points[i]
	var ground := Vector3(p.x, 0.0, p.z)
	var r := _rights[i] * side
	var foot_at := _half_widths[i] + kerb_width + verge
	var rise := run * scale
	var fall := outer_run * scale
	return [
		ground + r * foot_at,
		ground + r * (foot_at + rise) + Vector3.UP * (p.y + crest * scale),
		ground + r * (foot_at + rise + fall),
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
	return _smooth(scales, 3, 2)


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
