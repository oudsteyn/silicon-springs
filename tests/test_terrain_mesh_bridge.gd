extends TestBase

const TerrainMeshBridgeScript = preload("res://src/terrain/terrain_mesh_bridge.gd")


func _build_flat_height(size: int, value: float = 10.0) -> PackedFloat32Array:
	var height := PackedFloat32Array()
	height.resize(size * size)
	for i in height.size():
		height[i] = value
	return height


func test_generate_chunk_mesh_data_builds_vertices_and_indices() -> void:
	var bridge = TerrainMeshBridgeScript.new()
	var size = 64
	var height = _build_flat_height(size, 12.0)

	var mesh_data = bridge.generate_chunk_mesh_data(
		height,
		size,
		Vector2i(0, 0),
		16,
		1.0,
		1.0
	)

	assert_eq(mesh_data.vertices.size(), 17 * 17)
	assert_eq(mesh_data.normals.size(), 17 * 17)
	assert_eq(mesh_data.uvs.size(), 17 * 17)
	assert_eq(mesh_data.indices.size(), 16 * 16 * 6)

