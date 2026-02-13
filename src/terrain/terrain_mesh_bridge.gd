extends RefCounted
class_name TerrainMeshBridge


func generate_chunk_mesh_data(
	heightmap: PackedFloat32Array,
	heightmap_size: int,
	chunk_origin: Vector2i,
	chunk_resolution: int,
	meters_per_vertex: float,
	height_scale: float
) -> Dictionary:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var grid = chunk_resolution + 1
	vertices.resize(grid * grid)
	normals.resize(grid * grid)
	uvs.resize(grid * grid)

	for y in range(grid):
		for x in range(grid):
			var sample_x = chunk_origin.x + x
			var sample_y = chunk_origin.y + y
			var idx = y * grid + x
			var h = _sample_height(heightmap, heightmap_size, sample_x, sample_y) * height_scale
			vertices[idx] = Vector3(float(x) * meters_per_vertex, h, float(y) * meters_per_vertex)
			normals[idx] = _estimate_normal(heightmap, heightmap_size, sample_x, sample_y, height_scale)
			uvs[idx] = Vector2(float(x) / float(chunk_resolution), float(y) / float(chunk_resolution))

	indices.resize(chunk_resolution * chunk_resolution * 6)
	var tri = 0
	for y in range(chunk_resolution):
		for x in range(chunk_resolution):
			var i0 = y * grid + x
			var i1 = i0 + 1
			var i2 = i0 + grid
			var i3 = i2 + 1

			indices[tri + 0] = i0
			indices[tri + 1] = i2
			indices[tri + 2] = i1
			indices[tri + 3] = i1
			indices[tri + 4] = i2
			indices[tri + 5] = i3
			tri += 6

	return {
		"vertices": vertices,
		"normals": normals,
		"uvs": uvs,
		"indices": indices
	}


func _sample_height(heightmap: PackedFloat32Array, size: int, x: int, y: int) -> float:
	var sx = clampi(x, 0, size - 1)
	var sy = clampi(y, 0, size - 1)
	return heightmap[sy * size + sx]


func _estimate_normal(heightmap: PackedFloat32Array, size: int, x: int, y: int, height_scale: float) -> Vector3:
	var hl = _sample_height(heightmap, size, x - 1, y) * height_scale
	var hr = _sample_height(heightmap, size, x + 1, y) * height_scale
	var hd = _sample_height(heightmap, size, x, y - 1) * height_scale
	var hu = _sample_height(heightmap, size, x, y + 1) * height_scale
	return Vector3(hl - hr, 2.0, hd - hu).normalized()
