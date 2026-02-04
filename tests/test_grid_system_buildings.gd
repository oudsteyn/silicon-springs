extends TestBase
## Building placement/removal behavior tests for GridSystem

var grid_system: GridSystem


func before_each() -> void:
	GameState.reset_game()
	grid_system = GridSystem.new()
	grid_system._building_registry.load_registry()
	add_child(grid_system)


func after_each() -> void:
	if grid_system:
		grid_system.free()
		grid_system = null


func _find_road_building_with_size(size: Vector2i) -> Resource:
	for data in grid_system.get_all_building_data().values():
		var building_type = data.building_type if data.get("building_type") else ""
		if GridConstants.is_road_type(building_type) and data.size == size:
			return data
	return null


func _find_any_multicell_road() -> Resource:
	for data in grid_system.get_all_building_data().values():
		var building_type = data.building_type if data.get("building_type") else ""
		if GridConstants.is_road_type(building_type) and (data.size.x > 1 or data.size.y > 1):
			return data
	return null


func _find_utility_building() -> Resource:
	for data in grid_system.get_all_building_data().values():
		var building_type = data.building_type if data.get("building_type") else ""
		if GridConstants.is_utility_type(building_type) and data.size == Vector2i(1, 1):
			return data
	return null


func test_multicell_roads_register_all_cells() -> void:
	var road_data = _find_any_multicell_road()
	assert_not_null(road_data, "Expected at least one multi-cell road (e.g., highway).")

	var origin = Vector2i(20, 20)
	var placed = grid_system.place_building(origin, road_data)
	assert_not_null(placed, "Road placement should succeed.")

	for occupied_cell in GridConstants.get_building_cells(origin, road_data.size):
		assert_true(grid_system.road_cells.has(occupied_cell), "Road cell should be registered: " + str(occupied_cell))

	var removed = grid_system.remove_building(origin)
	assert_true(removed, "Road removal should succeed.")

	for occupied_cell in GridConstants.get_building_cells(origin, road_data.size):
		assert_false(grid_system.road_cells.has(occupied_cell), "Road cell should be removed: " + str(occupied_cell))


func test_removing_road_removes_overlays_and_updates_counts() -> void:
	var road_data = _find_road_building_with_size(Vector2i(1, 1))
	var utility_data = _find_utility_building()
	assert_not_null(road_data, "Expected a 1x1 road for overlay test.")
	assert_not_null(utility_data, "Expected a 1x1 utility (overlay) for test.")

	var origin = Vector2i(30, 30)
	var road = grid_system.place_building(origin, road_data)
	assert_not_null(road, "Road placement should succeed.")

	var overlay = grid_system.place_building(origin, utility_data)
	assert_not_null(overlay, "Overlay placement should succeed on road.")

	assert_eq(GameState.get_building_count(utility_data.id), 1, "Overlay should increment building count.")
	assert_true(grid_system.utility_overlays.has(origin), "Overlay should be registered.")

	var removed = grid_system.remove_building(origin)
	assert_true(removed, "Road removal should succeed.")

	assert_false(grid_system.utility_overlays.has(origin), "Overlay should be removed when base road is removed.")
	assert_eq(GameState.get_building_count(utility_data.id), 0, "Overlay removal should decrement building count.")


func test_overlay_placement_registers_overlay_only() -> void:
	var road_data = _find_road_building_with_size(Vector2i(1, 1))
	var utility_data = _find_utility_building()
	assert_not_null(road_data, "Expected a 1x1 road for overlay test.")
	assert_not_null(utility_data, "Expected a 1x1 utility (overlay) for test.")

	var origin = Vector2i(40, 40)
	var road = grid_system.place_building(origin, road_data)
	assert_not_null(road, "Road placement should succeed.")

	var overlay = grid_system.place_building(origin, utility_data)
	assert_not_null(overlay, "Overlay placement should succeed on road.")

	assert_eq(grid_system.buildings.get(origin), road, "Base road should remain in buildings grid.")
	assert_true(grid_system.utility_overlays.has(origin), "Overlay should be registered separately.")


func test_remove_overlay_keeps_road() -> void:
	var road_data = _find_road_building_with_size(Vector2i(1, 1))
	var utility_data = _find_utility_building()
	assert_not_null(road_data, "Expected a 1x1 road for overlay test.")
	assert_not_null(utility_data, "Expected a 1x1 utility (overlay) for test.")

	var origin = Vector2i(42, 42)
	var road = grid_system.place_building(origin, road_data)
	assert_not_null(road, "Road placement should succeed.")
	var overlay = grid_system.place_building(origin, utility_data)
	assert_not_null(overlay, "Overlay placement should succeed on road.")

	var removed_overlay = grid_system.remove_building(origin)
	assert_true(removed_overlay, "Removing at cell should remove overlay first.")
	assert_eq(grid_system.buildings.get(origin), road, "Road should remain after overlay removal.")
	assert_false(grid_system.utility_overlays.has(origin), "Overlay should be removed.")
