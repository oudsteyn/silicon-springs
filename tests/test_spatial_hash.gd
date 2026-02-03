extends TestBase
## Unit tests for SpatialHash

var spatial_hash: SpatialHash


func before_each() -> void:
	spatial_hash = SpatialHash.new()


func after_each() -> void:
	spatial_hash = null


# =============================================================================
# BASIC INSERTION TESTS
# =============================================================================

func test_insert_single() -> void:
	spatial_hash.insert(1, Vector2i(10, 10), "test_data")
	assert_true(spatial_hash.has_entity(1))
	assert_eq(spatial_hash.size(), 1)


func test_insert_multiple() -> void:
	spatial_hash.insert(1, Vector2i(10, 10))
	spatial_hash.insert(2, Vector2i(20, 20))
	spatial_hash.insert(3, Vector2i(30, 30))
	assert_eq(spatial_hash.size(), 3)


func test_insert_same_cell() -> void:
	# Multiple entities can occupy same cell
	spatial_hash.insert(1, Vector2i(10, 10))
	spatial_hash.insert(2, Vector2i(10, 10))
	assert_eq(spatial_hash.size(), 2)


# =============================================================================
# MULTI-CELL INSERTION TESTS
# =============================================================================

func test_insert_multi() -> void:
	var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5), Vector2i(5, 6), Vector2i(6, 6)]
	spatial_hash.insert_multi(1, cells, "2x2 building")
	assert_true(spatial_hash.has_entity(1))
	assert_eq(spatial_hash.size(), 1)


func test_insert_multi_queryable_from_any_cell() -> void:
	var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5)]
	spatial_hash.insert_multi(1, cells, "data")

	# Should find the entity when querying near any of its cells
	var result1 = spatial_hash.query_radius(Vector2i(5, 5), 1)
	var result2 = spatial_hash.query_radius(Vector2i(6, 5), 1)

	assert_not_empty(result1)
	assert_not_empty(result2)


# =============================================================================
# REMOVAL TESTS
# =============================================================================

func test_remove() -> void:
	spatial_hash.insert(1, Vector2i(10, 10))
	spatial_hash.remove(1)
	assert_false(spatial_hash.has_entity(1))
	assert_eq(spatial_hash.size(), 0)


func test_remove_nonexistent() -> void:
	# Should not error when removing nonexistent entity
	spatial_hash.remove(999)
	assert_eq(spatial_hash.size(), 0)


func test_remove_multi() -> void:
	var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5)]
	spatial_hash.insert_multi(1, cells)
	spatial_hash.remove(1)
	assert_false(spatial_hash.has_entity(1))


# =============================================================================
# UPDATE TESTS
# =============================================================================

func test_update_position() -> void:
	spatial_hash.insert(1, Vector2i(10, 10), "data")
	spatial_hash.update(1, Vector2i(50, 50), "updated_data")

	# Should not find at old position
	var old_result = spatial_hash.query_radius(Vector2i(10, 10), 1)
	var has_entity_at_old = false
	for entry in old_result:
		if entry.id == 1:
			has_entity_at_old = true
	assert_false(has_entity_at_old)

	# Should find at new position
	var new_result = spatial_hash.query_radius(Vector2i(50, 50), 1)
	var has_entity_at_new = false
	for entry in new_result:
		if entry.id == 1:
			has_entity_at_new = true
	assert_true(has_entity_at_new)


# =============================================================================
# RADIUS QUERY TESTS
# =============================================================================

func test_query_radius_empty() -> void:
	var result = spatial_hash.query_radius(Vector2i(50, 50), 10)
	assert_empty(result)


func test_query_radius_finds_entity() -> void:
	spatial_hash.insert(1, Vector2i(50, 50), "data")
	var result = spatial_hash.query_radius(Vector2i(50, 50), 5)
	assert_not_empty(result)
	assert_eq(result[0].id, 1)


func test_query_radius_respects_distance() -> void:
	spatial_hash.insert(1, Vector2i(50, 50))
	spatial_hash.insert(2, Vector2i(60, 50))  # 10 units away

	# Query with radius 5 should only find first entity
	var result = spatial_hash.query_radius(Vector2i(50, 50), 5)
	assert_size(result, 1)
	assert_eq(result[0].id, 1)

	# Query with radius 15 should find both
	var result_wider = spatial_hash.query_radius(Vector2i(50, 50), 15)
	assert_size(result_wider, 2)


func test_query_radius_includes_distance() -> void:
	spatial_hash.insert(1, Vector2i(50, 50))
	var result = spatial_hash.query_radius(Vector2i(53, 54), 10)
	assert_not_empty(result)
	# distance_sq should be 3^2 + 4^2 = 25
	assert_eq(result[0].distance_sq, 25)


func test_query_radius_multi_cell_building() -> void:
	# Insert a 2x2 building
	var cells: Array[Vector2i] = [Vector2i(50, 50), Vector2i(51, 50), Vector2i(50, 51), Vector2i(51, 51)]
	spatial_hash.insert_multi(1, cells, "2x2")

	# Query near any corner should find it
	var result = spatial_hash.query_radius(Vector2i(51, 51), 2)
	assert_not_empty(result)
	assert_eq(result[0].id, 1)


# =============================================================================
# RECT QUERY TESTS
# =============================================================================

func test_query_rect_empty() -> void:
	var result = spatial_hash.query_rect(Vector2i(0, 0), Vector2i(100, 100))
	assert_empty(result)


func test_query_rect_finds_entity() -> void:
	spatial_hash.insert(1, Vector2i(50, 50))
	var result = spatial_hash.query_rect(Vector2i(40, 40), Vector2i(60, 60))
	assert_not_empty(result)


func test_query_rect_boundary() -> void:
	spatial_hash.insert(1, Vector2i(50, 50))

	# Entity at exact boundary should be included
	var result = spatial_hash.query_rect(Vector2i(50, 50), Vector2i(50, 50))
	assert_not_empty(result)


func test_query_rect_excludes_outside() -> void:
	spatial_hash.insert(1, Vector2i(100, 100))
	var result = spatial_hash.query_rect(Vector2i(0, 0), Vector2i(50, 50))
	assert_empty(result)


func test_query_rect_multi_cell_building() -> void:
	# Insert a building spanning cells 50-51, 50-51
	var cells: Array[Vector2i] = [Vector2i(50, 50), Vector2i(51, 50), Vector2i(50, 51), Vector2i(51, 51)]
	spatial_hash.insert_multi(1, cells, "2x2")

	# Query that includes only one cell should still find building
	var result = spatial_hash.query_rect(Vector2i(51, 51), Vector2i(55, 55))
	assert_not_empty(result)


# =============================================================================
# CLEAR TESTS
# =============================================================================

func test_clear() -> void:
	spatial_hash.insert(1, Vector2i(10, 10))
	spatial_hash.insert(2, Vector2i(20, 20))
	spatial_hash.clear()
	assert_eq(spatial_hash.size(), 0)
	assert_false(spatial_hash.has_entity(1))
	assert_false(spatial_hash.has_entity(2))


# =============================================================================
# COVERAGE MASK TESTS
# =============================================================================

func test_coverage_mask_generation() -> void:
	var mask = SpatialHash.get_coverage_mask(5)
	assert_not_empty(mask)
	# Center should be included
	assert_in(Vector2i(0, 0), mask)


func test_coverage_mask_radius() -> void:
	var mask = SpatialHash.get_coverage_mask(3)
	# All points should be within radius 3
	for offset in mask:
		var dist = sqrt(offset.x * offset.x + offset.y * offset.y)
		assert_lte(dist, 3.0)


func test_coverage_mask_caching() -> void:
	# Calling twice should return same array
	var mask1 = SpatialHash.get_coverage_mask(10)
	var mask2 = SpatialHash.get_coverage_mask(10)
	assert_eq(mask1.size(), mask2.size())


func test_coverage_mask_with_strength() -> void:
	var mask = SpatialHash.get_coverage_mask_with_strength(5)
	assert_not_empty(mask)
	# Center should have strength 1.0
	for entry in mask:
		if entry.offset == Vector2i(0, 0):
			assert_approx(entry.strength, 1.0)
			break


func test_initialize_coverage_masks() -> void:
	SpatialHash.initialize_coverage_masks(10)
	# Should have masks pre-computed for radii 1-10
	var mask5 = SpatialHash.get_coverage_mask(5)
	var mask10 = SpatialHash.get_coverage_mask(10)
	assert_not_empty(mask5)
	assert_not_empty(mask10)
