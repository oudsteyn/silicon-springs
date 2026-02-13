extends TestBase

const TerrainDetailScatterScript = preload("res://src/terrain/terrain_detail_scatter.gd")


func _build_hill_height(size: int) -> PackedFloat32Array:
	var height := PackedFloat32Array()
	height.resize(size * size)
	var c = float(size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var dx = (float(x) - c) / c
			var dy = (float(y) - c) / c
			height[y * size + x] = 24.0 - (dx * dx + dy * dy) * 12.0
	return height


func test_build_scatter_transforms_returns_grass_and_rock_instances() -> void:
	var scatter = TerrainDetailScatterScript.new()
	var size = 64
	var height = _build_hill_height(size)

	var result = scatter.build_scatter_transforms(height, size, 4.0, 0.0, 1234)

	assert_true(result.has("grass"))
	assert_true(result.has("rocks"))
	assert_gt(result.grass.size(), 0)
	assert_gt(result.rocks.size(), 0)

