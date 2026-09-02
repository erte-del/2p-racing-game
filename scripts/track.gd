class_name Track
extends Node3D

## Builds the world for one course: the road mesh and its collision, laid on
## flat ground.
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
## How far out the foot of an embankment sits per metre of height. Sloping it
## reads as built-up ground; a vertical face reads as a cliff.
@export var embankment_batter := 1.8

@export_group("Shape")
@export var min_course_length := 620.0
@export var max_course_length := 1050.0
@export var min_corner_radius := 11.0
## Lower for a twistier course. Corner radius and straight length are what
## actually decide how twisty a course is; the clearance below only rejects
## courses that fold too tightly, it never makes the generator fold them.
@export var max_corner_radius := 45.0
@export var min_straight := 28.0
@export var max_straight := 110.0
## How close the course may pass to another part of itself. Lower is twistier;
## below about 19 m the road starts overlapping itself.
@export var self_clearance := 20.0
## How many seeds to try before giving up on finding a valid course.
@export var max_attempts := 60

@onready var _path: Path3D = $Path3D
@onready var _road: MeshInstance3D = $Road
@onready var _road_shape: CollisionShape3D = $RoadBody/Shape
@onready var _embankment: MeshInstance3D = $Embankment

var _layout: TrackLayout
## Cross-sections of the finished road.
var _points: PackedVector3Array
var _rights: PackedVector3Array
var _half_widths: PackedFloat32Array

var _asphalt: StandardMaterial3D
var _kerb: StandardMaterial3D
var _earth: StandardMaterial3D


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


## The pieces this course was built from, for debugging.
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
		"min_straight": min_straight,
		"max_straight": max_straight,
		"clearance": self_clearance,
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
	_build_embankment()
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


func _build_curve() -> void:
	var curve3d := Curve3D.new()
	# The centreline is dense and collinear along the straights, so baking up
	# vectors degenerates: consecutive tangents are identical and the cross
	# product used to carry the up vector along has no direction. Nothing here
	# uses curve tilt, so baking them is pure noise.
	curve3d.up_vector_enabled = false
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


## Skirt the raised parts of the road down to the ground, so a climb reads as
## an embankment instead of a ribbon floating over the grass.
##
## This carries no collision on purpose: driving off the edge of a raised
## section should drop the car onto the grass, not run it into a wall.
func _build_embankment() -> void:
	var count := _points.size()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false

	for i in count - 1:
		var j := i + 1
		# Only where the road actually stands above the ground.
		if _points[i].y < 0.15 and _points[j].y < 0.15:
			continue
		any = true
		var edge_i := _half_widths[i] + kerb_width
		var edge_j := _half_widths[j] + kerb_width
		for side: float in [-1.0, 1.0]:
			var out_i := _rights[i] * side
			var out_j := _rights[j] * side
			var top_a := _points[i] + out_i * edge_i
			var top_b := _points[j] + out_j * edge_j
			# Splay the foot outwards in proportion to the height.
			var foot_a := (top_a + out_i * top_a.y * embankment_batter)
			var foot_b := (top_b + out_j * top_b.y * embankment_batter)
			foot_a.y = 0.0
			foot_b.y = 0.0
			for v in [top_a, foot_a, top_b, foot_a, foot_b, top_b]:
				st.add_vertex(v)

	if not any:
		_embankment.mesh = null
		return
	st.generate_normals()
	_embankment.mesh = st.commit()
	_embankment.set_surface_override_material(0, _earth)


# --- materials ---------------------------------------------------------

func _build_materials() -> void:
	_asphalt = StandardMaterial3D.new()
	_asphalt.albedo_color = Color(0.176, 0.18, 0.196)
	_asphalt.roughness = 0.92

	_kerb = StandardMaterial3D.new()
	_kerb.albedo_color = Color(0.85, 0.85, 0.87)
	_kerb.roughness = 0.8

	_earth = StandardMaterial3D.new()
	_earth.albedo_color = Color(0.28, 0.33, 0.20)
	_earth.roughness = 1.0
	# Two-sided: the skirt is a single sheet, and which way each quad faces
	# depends on the side of the road and the direction of travel.
	_earth.cull_mode = BaseMaterial3D.CULL_DISABLED
