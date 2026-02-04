extends TestBase
## Tests for SaveBuildingCodec serialization and restoration

const SaveBuildingCodec = preload("res://src/systems/save_building_codec.gd")

var grid_system: GridSystem


func before_each() -> void:
	grid_system = GridSystem.new()
	add_child(grid_system)
	await get_tree().process_frame


func after_each() -> void:
	if grid_system:
		grid_system.free()
		grid_system = null


func _find_road_building() -> Resource:
	for data in grid_system.get_all_building_data().values():
		var btype = data.building_type if data.get("building_type") else ""
		if GridConstants.is_road_type(btype) and data.size == Vector2i(1, 1):
			return data
	return null


func _find_utility_building() -> Resource:
	for data in grid_system.get_all_building_data().values():
		var btype = data.building_type if data.get("building_type") else ""
		if GridConstants.is_utility_type(btype) and data.size == Vector2i(1, 1):
			return data
	return null


func test_serialize_and_restore_buildings_with_overlay() -> void:
	var road = _find_road_building()
	var utility = _find_utility_building()
	assert_not_null(road, "Expected a 1x1 road.")
	assert_not_null(utility, "Expected a 1x1 utility.")

	var cell = Vector2i(10, 10)
	assert_not_null(grid_system.place_building(cell, road))
	assert_not_null(grid_system.place_building(cell, utility))

	var data = SaveBuildingCodec.serialize_buildings(grid_system)
	assert_size(data, 2, "Expected road + overlay entries.")

	var road_entry = null
	var overlay_entry = null
	for entry in data:
		if entry.get("is_overlay", false):
			overlay_entry = entry
		else:
			road_entry = entry

	assert_not_null(road_entry)
	assert_not_null(overlay_entry)

	grid_system.clear_all_buildings_state()

	SaveBuildingCodec.restore_building(grid_system, road_entry)
	SaveBuildingCodec.restore_building(grid_system, overlay_entry)

	assert_true(grid_system.road_cells.has(cell))
	assert_true(grid_system.utility_overlays.has(cell))
