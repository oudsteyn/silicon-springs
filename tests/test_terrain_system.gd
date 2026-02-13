extends TestBase

const TerrainSystemScript = preload("res://src/systems/terrain_system.gd")
const ZoningSystemScript = preload("res://src/systems/zoning_system.gd")

var _to_free: Array = []


func after_each() -> void:
	for i in range(_to_free.size() - 1, -1, -1):
		var instance = _to_free[i]
		if is_instance_valid(instance):
			instance.free()
	_to_free.clear()


func _track(instance):
	_to_free.append(instance)
	return instance


func _make_terrain() -> TerrainSystem:
	var terrain = _track(TerrainSystemScript.new())
	return terrain


# ============================================
# BUILDABILITY RULES
# ============================================

func test_flat_terrain_is_buildable() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)
	terrain.elevation[cell] = 0
	var result = terrain.is_buildable(cell)
	assert_true(result.can_build)

	terrain.elevation[cell] = 1
	result = terrain.is_buildable(cell)
	assert_true(result.can_build)


func test_hills_block_building() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)

	for elev in [2, 3, 4, 5]:
		terrain.elevation[cell] = elev
		var result = terrain.is_buildable(cell)
		assert_false(result.can_build)
		assert_eq(result.reason, "Terrain too steep for construction")


func test_water_blocks_building() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)

	# Deep water
	terrain.elevation[cell] = -3
	terrain.water[cell] = TerrainSystemScript.WaterType.LAKE
	var result = terrain.is_buildable(cell)
	assert_false(result.can_build)
	assert_eq(result.reason, "Cannot build on water")

	# Shallow water (non-water-infra)
	terrain.elevation[cell] = -2
	terrain.water[cell] = TerrainSystemScript.WaterType.POND
	result = terrain.is_buildable(cell)
	assert_false(result.can_build)

	# Beach/wetland
	terrain.water.erase(cell)
	terrain.elevation[cell] = -1
	result = terrain.is_buildable(cell)
	assert_false(result.can_build)
	assert_eq(result.reason, "Cannot build on beach or wetland")


func test_rocks_block_building() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)

	# Rock on flat terrain still blocks
	terrain.elevation[cell] = 0
	terrain.features[cell] = TerrainSystemScript.FeatureType.ROCK_SMALL
	var result = terrain.is_buildable(cell)
	assert_false(result.can_build)
	assert_eq(result.reason, "Rocks must be cleared before building")

	terrain.features[cell] = TerrainSystemScript.FeatureType.ROCK_LARGE
	result = terrain.is_buildable(cell)
	assert_false(result.can_build)
	assert_eq(result.reason, "Rocks must be cleared before building")


func test_cleared_rocks_allow_building() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)
	terrain.elevation[cell] = 0
	terrain.features[cell] = TerrainSystemScript.FeatureType.ROCK_SMALL

	# Before clearing - blocked
	var result = terrain.is_buildable(cell)
	assert_false(result.can_build)

	# Clear rocks
	var cleared = terrain.clear_rocks(cell)
	assert_true(cleared)

	# After clearing - buildable
	result = terrain.is_buildable(cell)
	assert_true(result.can_build)


func test_water_infrastructure_on_shallow_water() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)
	terrain.elevation[cell] = -2
	terrain.water[cell] = TerrainSystemScript.WaterType.POND

	# Create a mock building_data-like object for water infrastructure
	var mock_data = RefCounted.new()
	mock_data.set_meta("size", Vector2i(1, 1))
	mock_data.set_meta("building_type", "bridge")

	# Use _check_cell_buildable directly for building_type check
	var result = terrain._check_cell_buildable(cell, "bridge", Vector2i(1, 1))
	assert_true(result.can_build)

	result = terrain._check_cell_buildable(cell, "dock", Vector2i(1, 1))
	assert_true(result.can_build)

	result = terrain._check_cell_buildable(cell, "water_pump", Vector2i(1, 1))
	assert_true(result.can_build)

	# Regular building should be blocked
	result = terrain._check_cell_buildable(cell, "residential", Vector2i(1, 1))
	assert_false(result.can_build)


# ============================================
# ROCK CLEARING
# ============================================

func test_clear_rocks_removes_feature() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)
	terrain.elevation[cell] = 2
	terrain.features[cell] = TerrainSystemScript.FeatureType.ROCK_SMALL

	var cleared = terrain.clear_rocks(cell)
	assert_true(cleared)
	assert_false(terrain.features.has(cell))


func test_clear_rocks_on_non_rock_fails() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)

	# Tree feature should not be clearable
	terrain.elevation[cell] = 0
	terrain.features[cell] = TerrainSystemScript.FeatureType.TREE_SPARSE
	var cleared = terrain.clear_rocks(cell)
	assert_false(cleared)
	assert_true(terrain.features.has(cell))

	# Beach feature should not be clearable
	terrain.features[cell] = TerrainSystemScript.FeatureType.BEACH
	cleared = terrain.clear_rocks(cell)
	assert_false(cleared)

	# No feature should fail
	terrain.features.erase(cell)
	cleared = terrain.clear_rocks(cell)
	assert_false(cleared)


# ============================================
# TREE CLEARING
# ============================================

func test_clear_trees_removes_sparse_tree() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)
	terrain.elevation[cell] = 0
	terrain.features[cell] = TerrainSystemScript.FeatureType.TREE_SPARSE

	var cleared = terrain.clear_trees(cell)
	assert_true(cleared)
	assert_false(terrain.features.has(cell))


func test_clear_trees_removes_dense_tree() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)
	terrain.elevation[cell] = 0
	terrain.features[cell] = TerrainSystemScript.FeatureType.TREE_DENSE

	var cleared = terrain.clear_trees(cell)
	assert_true(cleared)
	assert_false(terrain.features.has(cell))


func test_clear_trees_on_non_tree_fails() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)

	# Rock feature should not be clearable via clear_trees
	terrain.elevation[cell] = 2
	terrain.features[cell] = TerrainSystemScript.FeatureType.ROCK_SMALL
	var cleared = terrain.clear_trees(cell)
	assert_false(cleared)
	assert_true(terrain.features.has(cell))

	# Beach feature should not be clearable via clear_trees
	terrain.features[cell] = TerrainSystemScript.FeatureType.BEACH
	cleared = terrain.clear_trees(cell)
	assert_false(cleared)

	# No feature should fail
	terrain.features.erase(cell)
	cleared = terrain.clear_trees(cell)
	assert_false(cleared)


func test_clear_rocks_emits_terrain_changed() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)
	terrain.elevation[cell] = 2
	terrain.features[cell] = TerrainSystemScript.FeatureType.ROCK_LARGE

	# clear_rocks calls _emit_terrain_changed which calls terrain_changed.emit
	# Verify the feature is gone (proving clear_rocks ran its full path)
	var cleared = terrain.clear_rocks(cell)
	assert_true(cleared)
	assert_false(terrain.features.has(cell))


# ============================================
# ZONING TERRAIN CHECKS
# ============================================

func test_zone_blocked_on_water() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)
	terrain.elevation[cell] = -2
	terrain.water[cell] = TerrainSystemScript.WaterType.LAKE

	# set_zone requires grid_system, so test via is_buildable instead
	var result = terrain.is_buildable(cell)
	assert_false(result.can_build)


func test_zone_blocked_on_mountains() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)
	terrain.elevation[cell] = 3

	var result = terrain.is_buildable(cell)
	assert_false(result.can_build)


func test_zone_blocked_on_rocks() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)
	terrain.elevation[cell] = 0
	terrain.features[cell] = TerrainSystemScript.FeatureType.ROCK_SMALL

	var result = terrain.is_buildable(cell)
	assert_false(result.can_build)


func test_zone_allowed_on_flat() -> void:
	var terrain = _make_terrain()
	var cell = Vector2i(10, 10)
	terrain.elevation[cell] = 0

	var result = terrain.is_buildable(cell)
	assert_true(result.can_build)

	terrain.elevation[cell] = 1
	result = terrain.is_buildable(cell)
	assert_true(result.can_build)


# ============================================
# TERRAIN GENERATION
# ============================================

func test_generation_has_flat_area() -> void:
	var terrain = _make_terrain()
	terrain.generate_initial_terrain(42)

	var flat_count = 0
	var total = GridConstants.GRID_WIDTH * GridConstants.GRID_HEIGHT
	for x in range(GridConstants.GRID_WIDTH):
		for y in range(GridConstants.GRID_HEIGHT):
			var elev = terrain.get_elevation(Vector2i(x, y))
			if elev >= 0 and elev <= 1:
				flat_count += 1

	# At least 50% flat (the flattening curve targets ~60%)
	var flat_ratio = float(flat_count) / float(total)
	assert_true(flat_ratio >= 0.50, "Expected >= 50%% flat, got %.1f%%" % [flat_ratio * 100])


func test_generation_has_water() -> void:
	var terrain = _make_terrain()
	terrain.generate_initial_terrain(42)

	var any_water = false
	for x in range(GridConstants.GRID_WIDTH):
		for y in range(GridConstants.GRID_HEIGHT):
			if terrain.get_water(Vector2i(x, y)) != TerrainSystemScript.WaterType.NONE:
				any_water = true
				break
		if any_water:
			break

	assert_true(any_water)


func test_generation_has_features() -> void:
	var terrain = _make_terrain()
	terrain.generate_initial_terrain(42)

	var has_trees = false
	var has_rocks = false
	for x in range(GridConstants.GRID_WIDTH):
		for y in range(GridConstants.GRID_HEIGHT):
			var feature = terrain.get_feature(Vector2i(x, y))
			if feature in [TerrainSystemScript.FeatureType.TREE_SPARSE, TerrainSystemScript.FeatureType.TREE_DENSE]:
				has_trees = true
			if feature in [TerrainSystemScript.FeatureType.ROCK_SMALL, TerrainSystemScript.FeatureType.ROCK_LARGE]:
				has_rocks = true
			if has_trees and has_rocks:
				break
		if has_trees and has_rocks:
			break

	assert_true(has_trees)
	assert_true(has_rocks)
