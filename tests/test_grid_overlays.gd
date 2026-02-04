extends TestBase
## Tests for grid overlays using placement plans

class FakeGridSystem extends Node:
	var plan_valid: bool = false

	func plan_building_placement(cell: Vector2i, _building_data: Resource) -> Dictionary:
		return {
			"can_place": plan_valid,
			"reasons": [],
			"occupied_cells": [cell],
			"overlay_cells": []
		}

	func is_valid_cell(_cell: Vector2i) -> bool:
		return true

	func get_building_at(_cell: Vector2i) -> Node2D:
		return null


class FakeBuildingData extends Resource:
	var size: Vector2i = Vector2i(1, 1)
	var build_cost: int = 10
	var power_consumption: float = 0.0
	var water_consumption: float = 0.0
	var building_type: String = "road"


func _make_building_data():
	return FakeBuildingData.new()


func test_placement_preview_uses_plan_validity() -> void:
	var overlay = PlacementPreviewOverlay.new()
	var grid = FakeGridSystem.new()
	grid.plan_valid = false
	overlay.set_grid_system(grid)

	var building_data = _make_building_data()
	overlay.show_preview(Vector2i(1, 1), building_data, true)

	assert_false(overlay.is_valid(), "Preview should be invalid when plan is not placeable.")
	overlay.free()
	grid.free()


func test_path_preview_uses_plan_validity() -> void:
	var overlay = PathPreviewOverlay.new()
	var grid = FakeGridSystem.new()
	grid.plan_valid = false
	overlay.set_grid_system(grid)

	var building_data = _make_building_data()
	overlay.start_path(Vector2i(2, 2), building_data)

	assert_false(overlay._cell_validity.get(Vector2i(2, 2), true))
	overlay.free()
	grid.free()
