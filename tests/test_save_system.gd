extends TestBase
## Tests for SaveSystem load behavior and load-safe placement

var grid_system: GridSystem
var save_system: SaveSystem


func before_each() -> void:
	grid_system = GridSystem.new()
	save_system = SaveSystem.new()
	add_child(grid_system)
	add_child(save_system)
	save_system.set_grid_system(grid_system)
	# Wait for _ready to complete (registry load, save dir setup)
	await get_tree().process_frame


func after_each() -> void:
	if save_system:
		save_system.free()
		save_system = null
	if grid_system:
		grid_system.free()
		grid_system = null


func _base_save_data() -> Dictionary:
	return {
		"version": 3,
		"buildings": []
	}


func _find_road_building() -> Resource:
	for data in grid_system.get_all_building_data().values():
		var building_type = data.building_type if data.get("building_type") else ""
		if GridConstants.is_road_type(building_type):
			return data
	return null


func _find_utility_building(size: Vector2i = Vector2i(1, 1)) -> Resource:
	for data in grid_system.get_all_building_data().values():
		var building_type = data.building_type if data.get("building_type") else ""
		if GridConstants.is_utility_type(building_type) and data.size == size:
			return data
	return null


func _find_requires_road_adjacent() -> Resource:
	for data in grid_system.get_all_building_data().values():
		var building_type = data.building_type if data.get("building_type") else ""
		if data.get("requires_road_adjacent") and not GridConstants.is_road_type(building_type):
			return data
	return null


func test_load_bypasses_road_adjacency_validation() -> void:
	var target = _find_requires_road_adjacent()
	assert_not_null(target, "Expected a building requiring road adjacency for this test.")

	var cell = Vector2i(10, 10)
	var save_data = _base_save_data()
	save_data.buildings = [{
		"id": target.id,
		"cell_x": cell.x,
		"cell_y": cell.y
	}]

	var ok = save_system._apply_save_data(save_data)
	assert_true(ok)

	var restored = grid_system.get_building_at(cell)
	assert_not_null(restored, "Load should restore building even without roads.")


func test_load_overlay_requires_road_presence() -> void:
	var utility = _find_utility_building()
	assert_not_null(utility, "Expected a 1x1 utility for overlay test.")

	var cell = Vector2i(12, 12)
	var save_data = _base_save_data()
	save_data.buildings = [{
		"id": utility.id,
		"cell_x": cell.x,
		"cell_y": cell.y,
		"is_overlay": true
	}]

	var ok = save_system._apply_save_data(save_data)
	assert_true(ok)

	assert_false(grid_system.utility_overlays.has(cell), "Overlay should be skipped without underlying roads.")
	assert_null(grid_system.get_building_at(cell), "No building should be placed for invalid overlay.")


func test_load_orders_roads_before_overlays() -> void:
	var road = _find_road_building()
	var utility = _find_utility_building()
	assert_not_null(road, "Expected at least one road building.")
	assert_not_null(utility, "Expected a 1x1 utility for overlay test.")

	var cell = Vector2i(20, 20)
	var save_data = _base_save_data()
	# Intentionally place overlay before road in the save data.
	save_data.buildings = [
		{
			"id": utility.id,
			"cell_x": cell.x,
			"cell_y": cell.y,
			"is_overlay": true
		},
		{
			"id": road.id,
			"cell_x": cell.x,
			"cell_y": cell.y
		}
	]

	var ok = save_system._apply_save_data(save_data)
	assert_true(ok)

	assert_true(grid_system.road_cells.has(cell), "Road should be restored before overlay placement.")
	assert_true(grid_system.utility_overlays.has(cell), "Overlay should restore once road is present.")
