class_name BuildingOperations
extends RefCounted
## Handles building placement and removal operations
##
## Extracted from GridSystem to reduce complexity and improve testability.
## Manages: instantiation, registration, overlays, network events, financial transactions.

## Refund percentage when demolishing buildings
const REFUND_PERCENTAGE: float = 0.5


## Result of a placement operation
class PlacementResult:
	var success: bool = false
	var building: Node2D = null
	var error: String = ""
	var cost: int = 0

	static func succeeded(placed_building: Node2D, total_cost: int) -> PlacementResult:
		var result = PlacementResult.new()
		result.success = true
		result.building = placed_building
		result.cost = total_cost
		return result

	static func failed(reason: String) -> PlacementResult:
		var result = PlacementResult.new()
		result.success = false
		result.error = reason
		return result


## Result of a removal operation
class RemovalResult:
	var success: bool = false
	var refund: int = 0
	var was_overlay: bool = false
	var error: String = ""

	static func succeeded(refund_amount: int, overlay: bool = false) -> RemovalResult:
		var result = RemovalResult.new()
		result.success = true
		result.refund = refund_amount
		result.was_overlay = overlay
		return result

	static func failed(reason: String) -> RemovalResult:
		var result = RemovalResult.new()
		result.success = false
		result.error = reason
		return result


## Place a building at the specified cell
## Returns PlacementResult with success status and placed building
static func place_building(
	cell: Vector2i,
	building_data: Resource,
	buildings: Dictionary,
	unique_buildings: Dictionary,
	utility_overlays: Dictionary,
	spatial_index,
	road_network: RoadNetworkManager,
	building_scene: PackedScene,
	parent_node: Node2D,
	weather_system: Node = null
) -> PlacementResult:

	# Calculate effective cost with weather multiplier
	var effective_cost = building_data.build_cost
	if weather_system and weather_system.has_method("get_construction_cost_multiplier"):
		effective_cost = int(effective_cost * weather_system.get_construction_cost_multiplier())

	# Check affordability
	if not GameState.can_afford(effective_cost):
		Events.simulation_event.emit("insufficient_funds", {"cost": effective_cost})
		return PlacementResult.failed("Insufficient funds")

	# Spend the money
	GameState.spend(effective_cost)

	# Create and initialize building instance
	var building = building_scene.instantiate()
	building.position = GridConstants.grid_to_world(cell)
	parent_node.add_child(building)
	building.initialize(building_data, cell)

	# Register building in grid
	var registration = _register_building(
		cell, building, building_data,
		buildings, unique_buildings, utility_overlays, spatial_index
	)

	# Handle road network
	var building_type = building_data.building_type if building_data.get("building_type") else ""
	if GridConstants.is_road_type(building_type):
		for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
			road_network.add_road(occupied_cell)

	# Emit network change events
	_emit_placement_network_events(cell, building_data)

	# Update game state
	GameState.increment_building_count(building_data.id)

	# Emit building placed event
	Events.building_placed.emit(cell, building)

	return PlacementResult.succeeded(building, effective_cost)


## Place a building during load without validation or cost checks.
## Still registers, updates game state, and emits events by default.
static func place_building_for_load(
	cell: Vector2i,
	building_data: Resource,
	buildings: Dictionary,
	unique_buildings: Dictionary,
	utility_overlays: Dictionary,
	spatial_index,
	road_network: RoadNetworkManager,
	building_scene: PackedScene,
	parent_node: Node2D,
	emit_events: bool = true
) -> PlacementResult:

	# Create and initialize building instance
	var building = building_scene.instantiate()
	building.position = GridConstants.grid_to_world(cell)
	parent_node.add_child(building)
	building.initialize(building_data, cell)

	# Register building in grid
	_register_building(
		cell, building, building_data,
		buildings, unique_buildings, utility_overlays, spatial_index
	)

	# Handle road network
	var building_type = building_data.building_type if building_data.get("building_type") else ""
	if GridConstants.is_road_type(building_type):
		for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
			road_network.add_road(occupied_cell)

	# Update game state
	GameState.increment_building_count(building_data.id)

	# Emit network change events and building placed event
	if emit_events:
		_emit_placement_network_events(cell, building_data)
		Events.building_placed.emit(cell, building)

	return PlacementResult.succeeded(building, 0)


## Register a building in the grid data structures
static func _register_building(
	cell: Vector2i,
	building: Node2D,
	building_data: Resource,
	buildings: Dictionary,
	unique_buildings: Dictionary,
	utility_overlays: Dictionary,
	spatial_index
) -> Dictionary:
	var building_type = building_data.building_type if building_data.get("building_type") else ""
	var is_utility = GridConstants.is_utility_type(building_type)
	var is_overlay = false
	var registered_cells: Array[Vector2i] = []

	# Register in all occupied cells
	for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
		# Check if placing utility on existing road
		if is_utility and buildings.has(occupied_cell):
			var existing = buildings[occupied_cell]
			if existing.building_data and GridConstants.is_road_type(existing.building_data.building_type):
				utility_overlays[occupied_cell] = building
				is_overlay = true
				continue

		buildings[occupied_cell] = building
		registered_cells.append(occupied_cell)

	# Add to unique buildings cache
	unique_buildings[building.get_instance_id()] = building

	# Add to spatial index (unless pure overlay)
	if not is_overlay and spatial_index:
		spatial_index.insert_multi(building.get_instance_id(), registered_cells, building)

	return {"is_overlay": is_overlay, "registered_cells": registered_cells}


## Emit network change events for building placement
static func _emit_placement_network_events(cell: Vector2i, building_data: Resource) -> void:
	var building_type = building_data.building_type if building_data.get("building_type") else ""

	# Infrastructure type events
	if GridConstants.is_water_type(building_type):
		Events.water_pipe_network_changed.emit(cell, true)
	elif GridConstants.is_power_type(building_type):
		Events.power_line_network_changed.emit(cell, true)

	# Utility producer/consumer events (triggers adjacent pipe visual updates)
	if building_data.water_production > 0 or building_data.water_consumption > 0:
		for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
			Events.water_pipe_network_changed.emit(occupied_cell, true)

	if building_data.power_production > 0 or building_data.power_consumption > 0:
		for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
			Events.power_line_network_changed.emit(occupied_cell, true)


## Remove a building at the specified cell
## Returns RemovalResult with success status and refund amount
static func remove_building(
	cell: Vector2i,
	buildings: Dictionary,
	unique_buildings: Dictionary,
	utility_overlays: Dictionary,
	spatial_index,
	road_network: RoadNetworkManager
) -> RemovalResult:

	# First check for utility overlay (remove overlay first)
	if utility_overlays.has(cell):
		return _remove_overlay(cell, utility_overlays, unique_buildings)

	# Check if building exists
	if not buildings.has(cell):
		return RemovalResult.failed("No building at cell")

	var building = buildings[cell]
	if not is_instance_valid(building):
		buildings.erase(cell)
		return RemovalResult.failed("Invalid building reference")

	var building_data = building.building_data
	var origin_cell = building.grid_cell

	# Remove from all occupied cells (including any overlays on this building)
	_deregister_building(origin_cell, building_data, buildings, unique_buildings, utility_overlays)

	# Handle road network
	var building_type = building_data.building_type if building_data.get("building_type") else ""
	if GridConstants.is_road_type(building_type):
		for occupied_cell in GridConstants.get_building_cells(origin_cell, building_data.size):
			road_network.remove_road(occupied_cell)

	# Emit network change events
	_emit_removal_network_events(origin_cell, building_data)

	# Calculate and apply refund
	var refund = int(building_data.build_cost * REFUND_PERCENTAGE)
	GameState.earn(refund)

	# Update game state
	GameState.decrement_building_count(building_data.id)

	# Remove from spatial index
	if spatial_index:
		spatial_index.remove(building.get_instance_id())

	# Emit building removed event
	Events.building_removed.emit(origin_cell, building)

	# Queue building for deletion
	building.queue_free()

	return RemovalResult.succeeded(refund)


## Remove a utility overlay
static func _remove_overlay(
	cell: Vector2i,
	utility_overlays: Dictionary,
	unique_buildings: Dictionary
) -> RemovalResult:
	var overlay = utility_overlays[cell]

	if not is_instance_valid(overlay):
		utility_overlays.erase(cell)
		return RemovalResult.failed("Invalid overlay reference")

	var overlay_data = overlay.building_data
	var overlay_origin = overlay.grid_cell

	# Remove overlay from all its cells
	for occupied_cell in GridConstants.get_building_cells(overlay_origin, overlay_data.size):
		utility_overlays.erase(occupied_cell)

	# Emit network change events
	var overlay_type = overlay_data.building_type if overlay_data.get("building_type") else ""
	if GridConstants.is_water_type(overlay_type):
		Events.water_pipe_network_changed.emit(overlay_origin, false)
	elif GridConstants.is_power_type(overlay_type):
		Events.power_line_network_changed.emit(overlay_origin, false)

	# Calculate and apply refund
	var refund = int(overlay_data.build_cost * REFUND_PERCENTAGE)
	GameState.earn(refund)
	GameState.decrement_building_count(overlay_data.id)

	# Remove from unique buildings cache
	unique_buildings.erase(overlay.get_instance_id())

	# Emit event and cleanup
	Events.building_removed.emit(overlay_origin, overlay)
	overlay.queue_free()

	return RemovalResult.succeeded(refund, true)


## Deregister a building from all its cells
static func _deregister_building(
	origin_cell: Vector2i,
	building_data: Resource,
	buildings: Dictionary,
	unique_buildings: Dictionary,
	utility_overlays: Dictionary
) -> void:
	var building = buildings.get(origin_cell)
	if not building:
		return

	var removed_overlays: Dictionary = {}
	for occupied_cell in GridConstants.get_building_cells(origin_cell, building_data.size):
		buildings.erase(occupied_cell)

		# Also remove any overlays on this building
		if utility_overlays.has(occupied_cell):
			var overlay = utility_overlays[occupied_cell]
			if overlay and not removed_overlays.has(overlay.get_instance_id()):
				removed_overlays[overlay.get_instance_id()] = true
				_remove_overlay(occupied_cell, utility_overlays, unique_buildings)

	# Remove from unique buildings cache
	unique_buildings.erase(building.get_instance_id())


## Emit network change events for building removal
static func _emit_removal_network_events(origin_cell: Vector2i, building_data: Resource) -> void:
	var building_type = building_data.building_type if building_data.get("building_type") else ""

	# Infrastructure type events
	if GridConstants.is_water_type(building_type):
		Events.water_pipe_network_changed.emit(origin_cell, false)
	elif GridConstants.is_power_type(building_type):
		Events.power_line_network_changed.emit(origin_cell, false)

	# Utility producer/consumer events
	if building_data.water_production > 0 or building_data.water_consumption > 0:
		for occupied_cell in GridConstants.get_building_cells(origin_cell, building_data.size):
			Events.water_pipe_network_changed.emit(occupied_cell, false)

	if building_data.power_production > 0 or building_data.power_consumption > 0:
		for occupied_cell in GridConstants.get_building_cells(origin_cell, building_data.size):
			Events.power_line_network_changed.emit(occupied_cell, false)
