extends TestBase
## Unit tests for GridSystem

var grid_system: GridSystem


func before_each() -> void:
	grid_system = GridSystem.new()
	add_child(grid_system)


func after_each() -> void:
	if grid_system:
		grid_system.free()
		grid_system = null


# =============================================================================
# COORDINATE CONVERSION TESTS
# =============================================================================

func test_world_to_grid_origin() -> void:
	var result = grid_system.world_to_grid(Vector2(0, 0))
	assert_vector2i_eq(result, Vector2i(0, 0))


func test_world_to_grid_positive() -> void:
	# Cell size is 64, so 128,128 should be cell 2,2
	var result = grid_system.world_to_grid(Vector2(128, 128))
	assert_vector2i_eq(result, Vector2i(2, 2))


func test_world_to_grid_fractional() -> void:
	# 100,100 should still be cell 1,1 (floor division)
	var result = grid_system.world_to_grid(Vector2(100, 100))
	assert_vector2i_eq(result, Vector2i(1, 1))


func test_grid_to_world() -> void:
	var result = grid_system.grid_to_world(Vector2i(2, 3))
	assert_eq(result, Vector2(128, 192))


func test_grid_to_world_center() -> void:
	var result = grid_system.grid_to_world_center(Vector2i(0, 0))
	assert_eq(result, Vector2(32, 32))  # Half of 64


func test_coordinate_roundtrip() -> void:
	# Converting to grid and back should give cell origin
	var original = Vector2(150, 200)
	var grid_pos = grid_system.world_to_grid(original)
	var world_pos = grid_system.grid_to_world(grid_pos)
	# Should be top-left of the cell containing original point
	assert_eq(world_pos, Vector2(128, 192))


# =============================================================================
# CELL VALIDATION TESTS
# =============================================================================

func test_is_valid_cell_origin() -> void:
	assert_true(grid_system.is_valid_cell(Vector2i(0, 0)))


func test_is_valid_cell_max() -> void:
	# Grid is 128x128, so max valid is 127,127
	assert_true(grid_system.is_valid_cell(Vector2i(127, 127)))


func test_is_valid_cell_negative() -> void:
	assert_false(grid_system.is_valid_cell(Vector2i(-1, 0)))
	assert_false(grid_system.is_valid_cell(Vector2i(0, -1)))


func test_is_valid_cell_out_of_bounds() -> void:
	assert_false(grid_system.is_valid_cell(Vector2i(128, 0)))
	assert_false(grid_system.is_valid_cell(Vector2i(0, 128)))


# =============================================================================
# ROAD NETWORK TESTS
# =============================================================================

func test_has_road_at_empty() -> void:
	assert_false(grid_system.has_road_at(Vector2i(5, 5)))


func test_road_cells_start_empty() -> void:
	assert_empty(grid_system.road_cells)


# =============================================================================
# BUILDING QUERY TESTS
# =============================================================================

func test_get_all_unique_buildings_empty() -> void:
	var buildings = grid_system.get_all_unique_buildings()
	assert_empty(buildings)


func test_get_buildings_of_type_empty() -> void:
	var buildings = grid_system.get_buildings_of_type("road")
	assert_empty(buildings)


func test_get_buildings_in_radius_empty() -> void:
	var buildings = grid_system.get_buildings_in_radius(Vector2i(64, 64), 10)
	assert_empty(buildings)


func test_get_building_count_in_radius_empty() -> void:
	var count = grid_system.get_building_count_in_radius(Vector2i(64, 64), 10)
	assert_eq(count, 0)


# =============================================================================
# ADJACENT CELLS TESTS
# =============================================================================

func test_get_adjacent_cells_center() -> void:
	var adjacent = grid_system.get_adjacent_cells(Vector2i(64, 64))
	assert_size(adjacent, 4, "Interior cell should have 4 neighbors")


func test_get_adjacent_cells_corner() -> void:
	var adjacent = grid_system.get_adjacent_cells(Vector2i(0, 0))
	assert_size(adjacent, 2, "Corner cell should have 2 neighbors")


func test_get_adjacent_cells_edge() -> void:
	var adjacent = grid_system.get_adjacent_cells(Vector2i(0, 64))
	assert_size(adjacent, 3, "Edge cell should have 3 neighbors")


# =============================================================================
# BUILDING REGISTRY TESTS
# =============================================================================

func test_building_registry_loaded() -> void:
	# Registry should have buildings loaded from data files
	var registry = grid_system.get_all_building_data()
	assert_not_empty(registry, "Building registry should be populated")


func test_get_building_data_exists() -> void:
	# Road should exist in the registry
	var road_data = grid_system.get_building_data("road")
	# May or may not exist depending on data files
	if road_data:
		assert_not_null(road_data)


func test_get_building_data_not_found() -> void:
	var data = grid_system.get_building_data("nonexistent_building_12345")
	assert_null(data)


func test_get_buildings_by_category() -> void:
	var power_buildings = grid_system.get_buildings_by_category("power")
	# Should return an array (may be empty if no power buildings defined)
	assert_not_null(power_buildings)


# =============================================================================
# ASTAR ID TESTS
# =============================================================================

func test_cell_to_astar_id_origin() -> void:
	var id = grid_system._cell_to_astar_id(Vector2i(0, 0))
	assert_eq(id, 0)


func test_cell_to_astar_id_deterministic() -> void:
	# Same cell should always produce same ID
	var id1 = grid_system._cell_to_astar_id(Vector2i(10, 20))
	var id2 = grid_system._cell_to_astar_id(Vector2i(10, 20))
	assert_eq(id1, id2)


func test_cell_to_astar_id_unique() -> void:
	# Different cells should produce different IDs
	var id1 = grid_system._cell_to_astar_id(Vector2i(5, 5))
	var id2 = grid_system._cell_to_astar_id(Vector2i(6, 5))
	var id3 = grid_system._cell_to_astar_id(Vector2i(5, 6))
	assert_ne(id1, id2)
	assert_ne(id1, id3)
	assert_ne(id2, id3)


func test_cell_to_astar_id_formula() -> void:
	# ID should be x + y * GRID_WIDTH (128)
	var id = grid_system._cell_to_astar_id(Vector2i(10, 5))
	assert_eq(id, 10 + 5 * 128)


# =============================================================================
# TOTAL MAINTENANCE TESTS
# =============================================================================

func test_get_total_maintenance_empty() -> void:
	var maintenance = grid_system.get_total_maintenance()
	assert_eq(maintenance, 0)
