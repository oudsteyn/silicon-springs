extends Node3D
class_name ProceduralRoadSegment
## Dynamic road strip generation from a Path3D/Curve3D spline.

@export var width_meters: float = 8.0
@export var sample_step_meters: float = 2.0
@export var uv_tile_meters: float = 4.0
@export var shoulder_meters: float = 0.5
@export var marking_interval_meters: float = 6.0

var mesh_instance: MeshInstance3D = MeshInstance3D.new()

var _decal_mark_positions: PackedVector3Array = PackedVector3Array()


func _ready() -> void:
	if mesh_instance.get_parent() == null:
		mesh_instance.name = "RoadMesh"
		add_child(mesh_instance)


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if mesh_instance and is_instance_valid(mesh_instance) and mesh_instance.get_parent() == null:
		mesh_instance.free()


func build_from_path(path: Path3D) -> void:
	if path == null or path.curve == null:
		mesh_instance.mesh = null
		_decal_mark_positions = PackedVector3Array()
		return
	build_from_curve(path.curve)


func build_from_curve(curve: Curve3D) -> void:
	if curve == null:
		mesh_instance.mesh = null
		_decal_mark_positions = PackedVector3Array()
		return

	var baked_length = curve.get_baked_length()
	if baked_length <= 0.01:
		mesh_instance.mesh = null
		_decal_mark_positions = PackedVector3Array()
		return

	var half_width = (width_meters * 0.5) + shoulder_meters
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var points: Array[Vector3] = []
	var distances: Array[float] = []

	var d = 0.0
	while d < baked_length:
		points.append(curve.sample_baked(d, true))
		distances.append(d)
		d += maxf(0.25, sample_step_meters)
	points.append(curve.sample_baked(baked_length, true))
	distances.append(baked_length)

	if points.size() < 2:
		mesh_instance.mesh = null
		_decal_mark_positions = PackedVector3Array()
		return

	for i in range(points.size()):
		var p = points[i]
		var tangent = _tangent_at(points, i)
		var right = Vector3.UP.cross(tangent).normalized()
		if right.length_squared() < 0.001:
			right = Vector3.RIGHT

		var left_pos = p - right * half_width
		var right_pos = p + right * half_width
		positions.append(left_pos)
		positions.append(right_pos)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)
		var v = distances[i] / maxf(0.1, uv_tile_meters)
		uvs.append(Vector2(0.0, v))
		uvs.append(Vector2(1.0, v))

	for i in range(points.size() - 1):
		var i0 = i * 2
		var i1 = i0 + 1
		var i2 = i0 + 2
		var i3 = i0 + 3
		indices.append_array([i0, i2, i1, i1, i2, i3])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	_decal_mark_positions = _build_decal_anchor_positions(curve, baked_length)


func get_decal_mark_positions() -> PackedVector3Array:
	return _decal_mark_positions


func _build_decal_anchor_positions(curve: Curve3D, length: float) -> PackedVector3Array:
	var anchors := PackedVector3Array()
	if marking_interval_meters <= 0.01:
		return anchors
	var d = 0.0
	while d <= length:
		anchors.append(curve.sample_baked(d, true) + Vector3.UP * 0.02)
		d += marking_interval_meters
	return anchors


func _tangent_at(points: Array[Vector3], index: int) -> Vector3:
	if points.size() < 2:
		return Vector3.FORWARD
	if index == 0:
		return (points[1] - points[0]).normalized()
	if index == points.size() - 1:
		return (points[index] - points[index - 1]).normalized()
	return (points[index + 1] - points[index - 1]).normalized()
