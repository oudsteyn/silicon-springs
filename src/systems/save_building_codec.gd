class_name SaveBuildingCodec
extends RefCounted
## Serialization helpers for building save/load


static func serialize_buildings(grid_system: Node) -> Array:
	var buildings_data: Array = []
	var serialized_buildings: Dictionary = {}  # Track already serialized buildings

	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building):
			continue

		# Skip if already serialized (multi-cell buildings)
		if serialized_buildings.has(building):
			continue
		serialized_buildings[building] = true

		if not building.building_data:
			continue

		var building_dict = {
			"id": building.building_data.id,
			"cell_x": building.grid_cell.x,
			"cell_y": building.grid_cell.y,
			"development_level": building.development_level if building.has_method("get") else 0,
			"development_progress": building.development_progress if building.has_method("get") else 0.0,
			"health": building.health if building.has_method("get") else 100
		}
		buildings_data.append(building_dict)

	# Also serialize utility overlays
	for cell in grid_system.get_overlay_cells():
		var overlay = grid_system.get_overlay_at(cell)
		if not is_instance_valid(overlay):
			continue

		if serialized_buildings.has(overlay):
			continue
		serialized_buildings[overlay] = true

		if not overlay.building_data:
			continue

		var overlay_dict = {
			"id": overlay.building_data.id,
			"cell_x": overlay.grid_cell.x,
			"cell_y": overlay.grid_cell.y,
			"is_overlay": true
		}
		buildings_data.append(overlay_dict)

	return buildings_data


static func restore_building(grid_system: Node, data: Dictionary) -> void:
	if not grid_system:
		return

	var building_id = data.get("id", "")
	var cell = Vector2i(data.get("cell_x", 0), data.get("cell_y", 0))

	var building_data = grid_system.get_building_data(building_id)
	if not building_data:
		return

	# Hard safety: ensure all occupied cells are within bounds
	for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
		if not grid_system.is_valid_cell(occupied_cell):
			return

	# Respect overlays: only restore if underlying roads exist
	var is_overlay = data.get("is_overlay", false)
	if is_overlay:
		for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
			if not grid_system.has_road_at(occupied_cell):
				return

	var building = grid_system.place_building_for_load(cell, building_data, is_overlay)

	if building and is_instance_valid(building):
		# Restore building state
		if building.has_method("set"):
			building.development_level = data.get("development_level", 0)
			building.development_progress = data.get("development_progress", 0.0)
			building.health = data.get("health", 100)
		building._update_visual()
