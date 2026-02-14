class_name BuildingOperations
extends RefCounted
## Handles building placement and removal operations
##
## Extracted from GridSystem to reduce complexity and improve testability.
## Manages: instantiation, registration, overlays, network events, financial transactions.

## Refund percentage when demolishing buildings
const REFUND_PERCENTAGE: float = 0.5
const OverlayOperationsScript = preload("res://src/systems/overlay_operations.gd")


static func _get_events() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return loop.root.get_node_or_null("Events")
	return null


static func _get_game_state() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return loop.root.get_node_or_null("GameState")
	return null


## Result of a placement operation
class BuildPlacementResult:
	var success: bool = false
	var building: Node2D = null
	var error: String = ""
	var cost: int = 0

	static func succeeded(placed_building: Node2D, total_cost: int) -> BuildPlacementResult:
		var result = BuildPlacementResult.new()
		result.success = true
		result.building = placed_building
		result.cost = total_cost
		return result

	static func failed(reason: String) -> BuildPlacementResult:
		var result = BuildPlacementResult.new()
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
) -> BuildPlacementResult:

	# Calculate effective cost with weather multiplier
	var effective_cost = building_data.build_cost
	if weather_system and weather_system.has_method("get_construction_cost_multiplier"):
		effective_cost = int(effective_cost * weather_system.get_construction_cost_multiplier())

	var game_state = _get_game_state()
	# Check affordability
	if game_state and not game_state.can_afford(effective_cost):
		var events = _get_events()
		if events:
			events.simulation_event.emit("insufficient_funds", {"cost": effective_cost})
		return BuildPlacementResult.failed("Insufficient funds")

	# Spend the money
	if game_state:
		game_state.spend(effective_cost)

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
		road_network.begin_batch()
		for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
			road_network.add_road(occupied_cell)
		road_network.end_batch()

	# Emit network change events
	_emit_placement_network_events(cell, building_data)

	# Update game state
	if game_state:
		game_state.increment_building_count(building_data.id)

	# Emit building placed event
	var events = _get_events()
	if events:
		events.building_placed.emit(cell, building)

	return BuildPlacementResult.succeeded(building, effective_cost)


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
) -> BuildPlacementResult:

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
		road_network.begin_batch()
		for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
			road_network.add_road(occupied_cell)
		road_network.end_batch()

	# Update game state
	var game_state = _get_game_state()
	if game_state:
		game_state.increment_building_count(building_data.id)

	# Emit network change events and building placed event
	if emit_events:
		_emit_placement_network_events(cell, building_data)
		var events = _get_events()
		if events:
			events.building_placed.emit(cell, building)

	return BuildPlacementResult.succeeded(building, 0)


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

	var is_road = GridConstants.is_road_type(building_type)

	# Register in all occupied cells
	for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
		# Check if placing utility on existing road
		if is_utility and buildings.has(occupied_cell):
			var existing = buildings[occupied_cell]
			if existing.building_data and GridConstants.is_road_type(existing.building_data.building_type):
				OverlayOperationsScript.add_overlay(occupied_cell, building, utility_overlays)
				is_overlay = true
				continue

		# Check if placing road on existing utility — move utility to overlay
		if is_road and buildings.has(occupied_cell):
			var existing = buildings[occupied_cell]
			if existing.building_data and GridConstants.is_utility_type(existing.building_data.building_type):
				OverlayOperationsScript.add_overlay(occupied_cell, existing, utility_overlays)
				is_overlay = false  # The road is the base, not an overlay

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
		var events = _get_events()
		if events:
			events.water_pipe_network_changed.emit(cell, true)
	elif GridConstants.is_power_type(building_type):
		var events = _get_events()
		if events:
			events.power_line_network_changed.emit(cell, true)

	# Utility producer/consumer events (triggers adjacent pipe visual updates)
	if building_data.water_production > 0 or building_data.water_consumption > 0:
		for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
			var events = _get_events()
			if events:
				events.water_pipe_network_changed.emit(occupied_cell, true)

	if building_data.power_production > 0 or building_data.power_consumption > 0:
		for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
			var events = _get_events()
			if events:
				events.power_line_network_changed.emit(occupied_cell, true)


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
		var overlay_result = OverlayOperationsScript.remove_overlay_at(
			cell,
			utility_overlays,
			unique_buildings,
			REFUND_PERCENTAGE
		)
		if overlay_result.success:
			return RemovalResult.succeeded(overlay_result.refund, true)
		# Stale overlay entries should not block base building removal.
		if overlay_result.error == "Invalid overlay reference" and not utility_overlays.has(cell):
			pass
		else:
			return RemovalResult.failed(overlay_result.error)

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
		road_network.begin_batch()
		for occupied_cell in GridConstants.get_building_cells(origin_cell, building_data.size):
			road_network.remove_road(occupied_cell)
		road_network.end_batch()

	# Emit network change events
	_emit_removal_network_events(origin_cell, building_data)

	# Calculate and apply refund
	var refund = int(building_data.build_cost * REFUND_PERCENTAGE)
	var game_state = _get_game_state()
	if game_state:
		game_state.earn(refund)

	# Update game state
	if game_state:
		game_state.decrement_building_count(building_data.id)

	# Remove from spatial index
	if spatial_index:
		spatial_index.remove(building.get_instance_id())

	# Emit building removed event
	var events = _get_events()
	if events:
		events.building_removed.emit(origin_cell, building)

	# Queue building for deletion
	building.queue_free()

	return RemovalResult.succeeded(refund)


## Remove a utility overlay
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
			if not is_instance_valid(overlay):
				utility_overlays.erase(occupied_cell)
				continue
			var overlay_id = overlay.get_instance_id()
			if not removed_overlays.has(overlay_id):
				removed_overlays[overlay_id] = true
				OverlayOperationsScript.remove_overlay_at(
					occupied_cell,
					utility_overlays,
					unique_buildings,
					REFUND_PERCENTAGE
				)

	# Remove from unique buildings cache
	unique_buildings.erase(building.get_instance_id())


## Emit network change events for building removal
static func _emit_removal_network_events(origin_cell: Vector2i, building_data: Resource) -> void:
	var building_type = building_data.building_type if building_data.get("building_type") else ""

	# Infrastructure type events
	if GridConstants.is_water_type(building_type):
		var events = _get_events()
		if events:
			events.water_pipe_network_changed.emit(origin_cell, false)
	elif GridConstants.is_power_type(building_type):
		var events = _get_events()
		if events:
			events.power_line_network_changed.emit(origin_cell, false)

	# Utility producer/consumer events
	if building_data.water_production > 0 or building_data.water_consumption > 0:
		for occupied_cell in GridConstants.get_building_cells(origin_cell, building_data.size):
			var events = _get_events()
			if events:
				events.water_pipe_network_changed.emit(occupied_cell, false)

	if building_data.power_production > 0 or building_data.power_consumption > 0:
		for occupied_cell in GridConstants.get_building_cells(origin_cell, building_data.size):
			var events = _get_events()
			if events:
				events.power_line_network_changed.emit(occupied_cell, false)
