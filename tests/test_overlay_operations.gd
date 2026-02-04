extends TestBase
## Tests for overlay operations helper.

const OverlayOperations = preload("res://src/systems/overlay_operations.gd")


class DummyOverlay extends Node2D:
	var building_data: Resource
	var grid_cell: Vector2i

	func _init(data: Resource, cell: Vector2i) -> void:
		building_data = data
		grid_cell = cell


func test_remove_overlay_instance_clears_state_and_counts() -> void:
	GameState.reset_game()

	var overlay_data: Resource = load("res://src/data/water_pipe.tres")
	assert_not_null(overlay_data)

	var overlay = DummyOverlay.new(overlay_data, Vector2i(5, 5))
	var utility_overlays: Dictionary = {}
	for cell in GridConstants.get_building_cells(overlay.grid_cell, overlay_data.size):
		utility_overlays[cell] = overlay

	var unique_buildings: Dictionary = {overlay.get_instance_id(): overlay}
	GameState.increment_building_count(overlay_data.id)

	var result = OverlayOperations.remove_overlay_instance(overlay, utility_overlays, unique_buildings, 0.5)

	assert_true(result.success)
	assert_true(result.was_overlay)
	assert_eq(GameState.get_building_count(overlay_data.id), 0)
	assert_eq(unique_buildings.size(), 0)
	assert_eq(utility_overlays.size(), 0)
