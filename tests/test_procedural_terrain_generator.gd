extends TestBase

const GeneratorScript = preload("res://src/terrain/procedural_terrain_generator.gd")
const ProfileScript = preload("res://src/terrain/terrain_noise_profile.gd")


func test_generate_heightmap_returns_expected_size_and_range() -> void:
	var generator = GeneratorScript.new()
	var profile = ProfileScript.new()
	profile.seed = 42
	profile.height_scale = 300.0
	var size = 128

	var map = generator.generate_heightmap(size, profile)
	assert_eq(map.size(), size * size)

	var min_h = INF
	var max_h = -INF
	for h in map:
		min_h = min(min_h, h)
		max_h = max(max_h, h)
	assert_gte(min_h, 0.0)
	assert_lte(max_h, profile.height_scale + 0.001)


func test_island_falloff_tapers_edges() -> void:
	var generator = GeneratorScript.new()
	var profile = ProfileScript.new()
	profile.seed = 7
	profile.height_scale = 280.0
	var size = 128
	var map = generator.generate_heightmap(size, profile)

	var center = int(size * 0.5)
	var center_h = map[center * size + center]
	var corner_h = map[0]
	assert_gt(center_h, corner_h)
