extends TestBase
## Unit tests for GridConstants

# =============================================================================
# CONSTANT VALUE TESTS
# =============================================================================

func test_cell_size() -> void:
	assert_eq(GridConstants.CELL_SIZE, 64)


func test_grid_dimensions() -> void:
	assert_eq(GridConstants.GRID_WIDTH, 128)
	assert_eq(GridConstants.GRID_HEIGHT, 128)


func test_world_dimensions() -> void:
	assert_eq(GridConstants.WORLD_WIDTH, 128 * 64)
	assert_eq(GridConstants.WORLD_HEIGHT, 128 * 64)


func test_half_cell() -> void:
	assert_eq(GridConstants.HALF_CELL, 32)


# =============================================================================
# COORDINATE CONVERSION TESTS
# =============================================================================

func test_world_to_grid_origin() -> void:
	var result = GridConstants.world_to_grid(Vector2(0, 0))
	assert_vector2i_eq(result, Vector2i(0, 0))


func test_world_to_grid_cell_boundary() -> void:
	# At exactly 64, should be cell 1
	var result = GridConstants.world_to_grid(Vector2(64, 64))
	assert_vector2i_eq(result, Vector2i(1, 1))


func test_world_to_grid_just_before_boundary() -> void:
	# At 63.9, should still be cell 0
	var result = GridConstants.world_to_grid(Vector2(63.9, 63.9))
	assert_vector2i_eq(result, Vector2i(0, 0))


func test_grid_to_world() -> void:
	var result = GridConstants.grid_to_world(Vector2i(5, 10))
	assert_eq(result, Vector2(320, 640))


func test_grid_to_world_center() -> void:
	var result = GridConstants.grid_to_world_center(Vector2i(0, 0))
	assert_eq(result, Vector2(32, 32))


func test_grid_to_world_center_offset() -> void:
	var result = GridConstants.grid_to_world_center(Vector2i(1, 1))
	assert_eq(result, Vector2(96, 96))  # 64 + 32


# =============================================================================
# CELL VALIDATION TESTS
# =============================================================================

func test_is_valid_cell_valid() -> void:
	assert_true(GridConstants.is_valid_cell(Vector2i(0, 0)))
	assert_true(GridConstants.is_valid_cell(Vector2i(64, 64)))
	assert_true(GridConstants.is_valid_cell(Vector2i(127, 127)))


func test_is_valid_cell_invalid_negative() -> void:
	assert_false(GridConstants.is_valid_cell(Vector2i(-1, 0)))
	assert_false(GridConstants.is_valid_cell(Vector2i(0, -1)))
	assert_false(GridConstants.is_valid_cell(Vector2i(-5, -5)))


func test_is_valid_cell_invalid_too_large() -> void:
	assert_false(GridConstants.is_valid_cell(Vector2i(128, 0)))
	assert_false(GridConstants.is_valid_cell(Vector2i(0, 128)))
	assert_false(GridConstants.is_valid_cell(Vector2i(200, 200)))


func test_clamp_cell() -> void:
	assert_vector2i_eq(GridConstants.clamp_cell(Vector2i(-5, -5)), Vector2i(0, 0))
	assert_vector2i_eq(GridConstants.clamp_cell(Vector2i(200, 200)), Vector2i(127, 127))
	assert_vector2i_eq(GridConstants.clamp_cell(Vector2i(50, 50)), Vector2i(50, 50))


# =============================================================================
# ADJACENT CELLS TESTS
# =============================================================================

func test_get_adjacent_cells_interior() -> void:
	var adjacent = GridConstants.get_adjacent_cells(Vector2i(64, 64))
	assert_size(adjacent, 4)
	assert_in(Vector2i(65, 64), adjacent)
	assert_in(Vector2i(63, 64), adjacent)
	assert_in(Vector2i(64, 65), adjacent)
	assert_in(Vector2i(64, 63), adjacent)


func test_get_adjacent_cells_corner() -> void:
	var adjacent = GridConstants.get_adjacent_cells(Vector2i(0, 0))
	assert_size(adjacent, 2)
	assert_in(Vector2i(1, 0), adjacent)
	assert_in(Vector2i(0, 1), adjacent)


func test_get_surrounding_cells_interior() -> void:
	var surrounding = GridConstants.get_surrounding_cells(Vector2i(64, 64))
	assert_size(surrounding, 8)  # All 8 neighbors


func test_get_surrounding_cells_corner() -> void:
	var surrounding = GridConstants.get_surrounding_cells(Vector2i(0, 0))
	assert_size(surrounding, 3)  # Only 3 valid neighbors


# =============================================================================
# DISTANCE TESTS
# =============================================================================

func test_manhattan_distance() -> void:
	assert_eq(GridConstants.manhattan_distance(Vector2i(0, 0), Vector2i(0, 0)), 0)
	assert_eq(GridConstants.manhattan_distance(Vector2i(0, 0), Vector2i(5, 0)), 5)
	assert_eq(GridConstants.manhattan_distance(Vector2i(0, 0), Vector2i(3, 4)), 7)


func test_chebyshev_distance() -> void:
	assert_eq(GridConstants.chebyshev_distance(Vector2i(0, 0), Vector2i(0, 0)), 0)
	assert_eq(GridConstants.chebyshev_distance(Vector2i(0, 0), Vector2i(5, 3)), 5)
	assert_eq(GridConstants.chebyshev_distance(Vector2i(0, 0), Vector2i(3, 3)), 3)


func test_euclidean_distance() -> void:
	assert_approx(GridConstants.euclidean_distance(Vector2i(0, 0), Vector2i(0, 0)), 0.0)
	assert_approx(GridConstants.euclidean_distance(Vector2i(0, 0), Vector2i(3, 4)), 5.0)


# =============================================================================
# RECT UTILITIES TESTS
# =============================================================================

func test_rect_from_cells() -> void:
	var rect = GridConstants.rect_from_cells(Vector2i(5, 5), Vector2i(10, 10))
	assert_eq(rect.position, Vector2i(5, 5))
	assert_eq(rect.size, Vector2i(6, 6))


func test_rect_from_cells_reversed() -> void:
	# Should handle corners in any order
	var rect = GridConstants.rect_from_cells(Vector2i(10, 10), Vector2i(5, 5))
	assert_eq(rect.position, Vector2i(5, 5))
	assert_eq(rect.size, Vector2i(6, 6))


# =============================================================================
# TYPE CHECKING TESTS
# =============================================================================

func test_is_road_type() -> void:
	assert_true(GridConstants.is_road_type("road"))
	assert_true(GridConstants.is_road_type("collector"))
	assert_true(GridConstants.is_road_type("arterial"))
	assert_true(GridConstants.is_road_type("highway"))
	assert_false(GridConstants.is_road_type("power_line"))
	assert_false(GridConstants.is_road_type("building"))


func test_is_utility_type() -> void:
	assert_true(GridConstants.is_utility_type("power_line"))
	assert_true(GridConstants.is_utility_type("water_pipe"))
	assert_false(GridConstants.is_utility_type("road"))


func test_is_power_type() -> void:
	assert_true(GridConstants.is_power_type("power_line"))
	assert_true(GridConstants.is_power_type("power_pole"))
	assert_false(GridConstants.is_power_type("water_pipe"))


func test_is_water_type() -> void:
	assert_true(GridConstants.is_water_type("water_pipe"))
	assert_true(GridConstants.is_water_type("large_water_pipe"))
	assert_false(GridConstants.is_water_type("power_line"))


func test_is_linear_infrastructure() -> void:
	assert_true(GridConstants.is_linear_infrastructure("road"))
	assert_true(GridConstants.is_linear_infrastructure("power_line"))
	assert_true(GridConstants.is_linear_infrastructure("water_pipe"))
	assert_false(GridConstants.is_linear_infrastructure("coal_plant"))
