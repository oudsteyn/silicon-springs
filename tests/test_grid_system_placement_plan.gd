extends TestBase
## Tests for placement planning/validation split

var grid_system: GridSystem


class FakeZoningSystem extends Node:
	func is_far_compliant(_cell: Vector2i, _building_data: Resource) -> Dictionary:
		return {"compliant": false, "reason": "FAR exceeded"}


func before_each() -> void:
	grid_system = GridSystem.new()
	grid_system._building_registry.load_registry()
	add_child(grid_system)


func after_each() -> void:
	if grid_system:
		grid_system.free()
		grid_system = null


func _find_building_with_size(min_cells: int) -> Resource:
	for data in grid_system.get_all_building_data().values():
		var size = data.size
		if size.x * size.y >= min_cells:
			return data
	return null


func _find_road_building() -> Resource:
	for data in grid_system.get_all_building_data().values():
		var building_type = data.building_type if data.get("building_type") else ""
		if GridConstants.is_road_type(building_type) and data.size == Vector2i(1, 1):
			return data
	return null


func _find_utility_building() -> Resource:
	for data in grid_system.get_all_building_data().values():
		var building_type = data.building_type if data.get("building_type") else ""
		if GridConstants.is_utility_type(building_type) and data.size == Vector2i(1, 1):
			return data
	return null


func test_plan_returns_occupied_cells_count() -> void:
	var building_data = _find_building_with_size(2)
	assert_not_null(building_data, "Expected a building with size >= 2 cells.")

	var cell = Vector2i(10, 10)
	var plan = grid_system.plan_building_placement(cell, building_data)
	var expected_count = building_data.size.x * building_data.size.y
	assert_eq(plan.occupied_cells.size(), expected_count)


func test_plan_utility_on_road_sets_overlay_cells() -> void:
	var road_data = _find_road_building()
	var utility_data = _find_utility_building()
	assert_not_null(road_data, "Expected a 1x1 road.")
	assert_not_null(utility_data, "Expected a 1x1 utility.")

	var cell = Vector2i(20, 20)
	var road = grid_system.place_building(cell, road_data)
	assert_not_null(road, "Road placement should succeed.")

	var plan = grid_system.plan_building_placement(cell, utility_data)
	assert_true(plan.can_place)
	assert_size(plan.overlay_cells, 1)
	assert_in(cell, plan.overlay_cells)


func test_plan_invalid_building_returns_error() -> void:
	var plan = grid_system.plan_building_placement(Vector2i(5, 5), null)
	assert_false(plan.can_place)
	assert_in("Unknown building", plan.reasons)


func test_plan_uses_injected_zoning_system() -> void:
	var zoning = FakeZoningSystem.new()
	grid_system.set_zoning_system(zoning)

	var building_data = _find_building_with_size(1)
	assert_not_null(building_data, "Expected a building resource for zoning test.")

	var plan = grid_system.plan_building_placement(Vector2i(6, 6), building_data)
	assert_false(plan.can_place)
	assert_in("FAR exceeded", plan.reasons)
	zoning.free()
