extends Node2D
class_name GridSystem
## Manages the game grid, building placement, and tile-to-world conversions
##
## This is the core system for all grid-based operations. It coordinates:
## - Building placement and removal
## - Road network management (delegated to RoadNetworkManager)
## - Building data registry (delegated to BuildingRegistry)
## - Spatial indexing for efficient range queries
## - Utility overlay management (power/water on roads)

# =============================================================================
# SUBSYSTEMS (Extracted for better separation of concerns)
# =============================================================================

## Building data registry - handles loading and querying building definitions
var _building_registry: BuildingRegistry = BuildingRegistry.new()

## Road network manager - handles road cells and pathfinding
var _road_network: RoadNetworkManager = RoadNetworkManager.new()


# =============================================================================
# BUILDING STORAGE
# =============================================================================

## Primary building storage: {Vector2i: Building node}
## Multi-cell buildings are stored at each cell they occupy
var buildings: Dictionary = {}

## Unique buildings cache for O(1) iteration (avoids deduplication)
## {instance_id: Building node}
var _unique_buildings: Dictionary = {}

## Spatial index for efficient range queries
var _building_spatial_index: SpatialHash = SpatialHash.new()

## Utility overlays (power lines/water pipes on roads): {Vector2i: Building node}
var utility_overlays: Dictionary = {}


# =============================================================================
# BACKWARD COMPATIBILITY: Road network data exposed via RoadNetworkManager
# =============================================================================

## Cells that contain roads: {Vector2i: true}
## NOTE: Now backed by _road_network.road_cells for backward compatibility
var road_cells: Dictionary:
	get: return _road_network.road_cells
	set(value): _road_network.load_roads(value)

## AStar pathfinding for road connectivity (exposed for backward compatibility)
var astar: AStar2D:
	get: return _road_network._astar

## AStar cell tracking (exposed for backward compatibility)
var _astar_cells: Dictionary:
	get: return _road_network._astar_cells


# =============================================================================
# SYSTEM REFERENCES
# =============================================================================

## Terrain system reference for buildability checks
var terrain_system: Node = null

## Weather system reference for construction cost multiplier
var weather_system: Node = null

## Zoning system reference for FAR compliance (optional injection)
var zoning_system: Node = null


# =============================================================================
# BACKWARD COMPATIBILITY: Building registry exposed via BuildingRegistry
# =============================================================================

## Building scene template (delegated to registry)
var building_scene: PackedScene:
	get: return _building_registry.get_building_scene()

## Building data registry: {id: BuildingData} (delegated to registry)
var building_registry: Dictionary:
	get: return _building_registry.get_all_building_data()


# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_building_registry.load_registry()
	var events = _get_events()
	if events:
		events.building_placed.connect(_on_building_placed)
		events.building_removed.connect(_on_building_removed)


func _get_events() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return loop.root.get_node_or_null("Events")
	return null


# =============================================================================
# BUILDING REGISTRY ACCESS (Delegated to BuildingRegistry)
# =============================================================================

## Returns BuildingData resource or null if not found
func get_building_data(id: String) -> Resource:
	return _building_registry.get_building_data(id)


## Returns full building registry dictionary
func get_all_building_data() -> Dictionary:
	return _building_registry.get_all_building_data()


## Returns array of BuildingData resources matching category
func get_buildings_by_category(category: String) -> Array[Resource]:
	return _building_registry.get_buildings_by_category(category)


# =============================================================================
# SYSTEM SETTERS
# =============================================================================

func set_terrain_system(ts: Node) -> void:
	terrain_system = ts


func set_weather_system(ws: Node) -> void:
	weather_system = ws


func set_zoning_system(zs: Node) -> void:
	zoning_system = zs


# =============================================================================
# COORDINATE CONVERSIONS (Delegated to GridConstants)
# =============================================================================

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return GridConstants.world_to_grid(world_pos)


func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return GridConstants.grid_to_world(grid_pos)


func grid_to_world_center(grid_pos: Vector2i) -> Vector2:
	return GridConstants.grid_to_world_center(grid_pos)


func is_valid_cell(cell: Vector2i) -> bool:
	return GridConstants.is_valid_cell(cell)


# =============================================================================
# BUILDING PLACEMENT VALIDATION
# =============================================================================

## Check if a building can be placed at the specified cell.
## Returns Dictionary with "can_place": bool and "reasons": Array[String]
func can_place_building(cell: Vector2i, building_data: Resource) -> Dictionary:
	var plan = plan_building_placement(cell, building_data)
	return {
		"can_place": plan.can_place,
		"reasons": plan.reasons
	}


## Build a placement plan with validation details and occupied/overlay cells.
## Returns {can_place: bool, reasons: Array[String], occupied_cells: Array[Vector2i], overlay_cells: Array[Vector2i]}
func plan_building_placement(cell: Vector2i, building_data: Resource) -> Dictionary:
	var result: Dictionary = {
		"can_place": true,
		"reasons": [] as Array[String],
		"occupied_cells": [] as Array[Vector2i],
		"overlay_cells": [] as Array[Vector2i]
	}

	if not building_data:
		result.can_place = false
		result.reasons.append("Unknown building")
		return result

	# Check if cell is valid
	if not is_valid_cell(cell):
		result.can_place = false
		result.reasons.append("Outside map bounds")
		return result

	# Determine building type characteristics
	var building_type = building_data.building_type if building_data.get("building_type") else ""
	var is_utility = GridConstants.is_utility_type(building_type)
	var is_road = GridConstants.is_road_type(building_type)

	# Check all cells the building occupies
	for x in range(building_data.size.x):
		for y in range(building_data.size.y):
			var check_cell = cell + Vector2i(x, y)
			result.occupied_cells.append(check_cell)

			if not is_valid_cell(check_cell):
				result.can_place = false
				result.reasons.append("Building extends outside map")
				return result

			if buildings.has(check_cell):
				var existing = buildings[check_cell]
				var existing_type = existing.building_data.building_type if existing.building_data else ""

				# Allow utilities on roads (and vice versa)
				var can_overlay = false
				if is_utility and GridConstants.is_road_type(existing_type):
					can_overlay = true
				elif is_road and GridConstants.is_utility_type(existing_type):
					can_overlay = true

				# Check if there's already an overlay at this cell
				if can_overlay and utility_overlays.has(check_cell):
					can_overlay = false  # Already has an overlay

				if not can_overlay:
					result.can_place = false
					result.reasons.append("Cell already occupied")
					return result

				# Track overlay cells for utility-on-road placement
				if is_utility and GridConstants.is_road_type(existing_type):
					result.overlay_cells.append(check_cell)

			# Check terrain constraints
			if terrain_system and terrain_system.has_method("is_buildable"):
				var terrain_check = terrain_system.is_buildable(check_cell, building_data)
				if not terrain_check.can_build:
					result.can_place = false
					result.reasons.append(terrain_check.reason)
					return result

	# Check road adjacency requirement (must have access road, not highway/arterial)
	if building_data.requires_road_adjacent:
		var road_check = _check_road_access(cell, building_data.size)
		if not road_check.has_access:
			result.can_place = false
			result.reasons.append(road_check.reason)

	# Check FAR (Floor Area Ratio) compliance for zoned areas
	var far_check = _check_far_compliance(cell, building_data)
	if not far_check.compliant:
		result.can_place = false
		result.reasons.append(far_check.reason)

	return result


## Check if building has adjacent road with proper access
## Returns {has_access: bool, reason: String}
func _check_road_access(cell: Vector2i, size: Vector2i) -> Dictionary:
	var has_any_road = false
	var has_access_road = false

	# Check all cells around the building perimeter
	for x in range(-1, size.x + 1):
		for y in range(-1, size.y + 1):
			# Skip interior cells
			if x >= 0 and x < size.x and y >= 0 and y < size.y:
				continue
			var check_cell = cell + Vector2i(x, y)
			if road_cells.has(check_cell):
				has_any_road = true
				# Check if this road type allows direct access
				var road_building = buildings.get(check_cell)
				if road_building and road_building.building_data:
					var road_type = road_building.building_data.building_type
					# Check allows_direct_access property (defaults to true if not set)
					var allows_access = road_building.building_data.allows_direct_access
					if allows_access and GridConstants.road_allows_access(road_type):
						has_access_road = true

	if has_access_road:
		return {"has_access": true, "reason": ""}
	elif has_any_road:
		return {"has_access": false, "reason": "Adjacent roads don't allow direct access (use local roads or collectors)"}
	else:
		return {"has_access": false, "reason": "Must be adjacent to a road"}


func _has_adjacent_road(cell: Vector2i, size: Vector2i) -> bool:
	# Legacy function - checks for any road (not access-restricted)
	for x in range(-1, size.x + 1):
		for y in range(-1, size.y + 1):
			if x >= 0 and x < size.x and y >= 0 and y < size.y:
				continue
			var check_cell = cell + Vector2i(x, y)
			if road_cells.has(check_cell):
				return true
	return false


## Check FAR compliance for zoned areas
func _check_far_compliance(cell: Vector2i, building_data: Resource) -> Dictionary:
	# Only check for zone buildings or buildings placed in zones
	if building_data.get("category") == "infrastructure":
		return {"compliant": true, "reason": ""}

	# Prefer injected zoning system
	if zoning_system and zoning_system.has_method("is_far_compliant"):
		return zoning_system.is_far_compliant(cell, building_data)

	# No injected zoning system; default to compliant.
	return {"compliant": true, "reason": ""}


# =============================================================================
# BUILDING PLACEMENT (Delegated to BuildingOperations)
# =============================================================================

## Place a building at the specified cell. Returns the Building node or null on failure.
func place_building(cell: Vector2i, building_data: Resource) -> Node2D:
	# Validate placement first
	var check = can_place_building(cell, building_data)
	if not check.can_place:
		return null

	# Delegate to BuildingOperations
	var result = BuildingOperations.place_building(
		cell,
		building_data,
		buildings,
		_unique_buildings,
		utility_overlays,
		_building_spatial_index,
		_road_network,
		_building_registry.get_building_scene(),
		self,
		weather_system
	)

	return result.building if result.success else null


## Place a building during load without validation or cost checks.
## Returns the Building node or null if skipped.
func place_building_for_load(cell: Vector2i, building_data: Resource, is_overlay: bool = false) -> Node2D:
	# Hard safety check: all occupied cells must be within bounds
	for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
		if not is_valid_cell(occupied_cell):
			return null

	# Overlays must sit on existing roads
	if is_overlay:
		for occupied_cell in GridConstants.get_building_cells(cell, building_data.size):
			if not road_cells.has(occupied_cell):
				return null

	# Delegate to BuildingOperations (no validation/cost)
	var result = BuildingOperations.place_building_for_load(
		cell,
		building_data,
		buildings,
		_unique_buildings,
		utility_overlays,
		_building_spatial_index,
		_road_network,
		_building_registry.get_building_scene(),
		self
	)

	return result.building if result.success else null


# =============================================================================
# BUILDING REMOVAL (Delegated to BuildingOperations)
# =============================================================================

## Remove a building at the specified cell. Returns true if successful.
func remove_building(cell: Vector2i) -> bool:
	var result = BuildingOperations.remove_building(
		cell,
		buildings,
		_unique_buildings,
		utility_overlays,
		_building_spatial_index,
		_road_network
	)

	return result.success


## Clear all building state and caches (for loading/reset)
func clear_all_buildings_state() -> void:
	buildings.clear()
	utility_overlays.clear()
	_unique_buildings.clear()
	_building_spatial_index.clear()
	_road_network.clear()


# =============================================================================
# BUILDING QUERIES (Some delegated to BuildingQueries static class)
# =============================================================================

## Get all unique buildings (O(1) - uses cache)
func get_all_unique_buildings() -> Array[Node2D]:
	return BuildingQueries.get_all_unique_buildings(_unique_buildings)


## Get buildings of a specific type (uses unique cache for efficiency)
func get_buildings_of_type(building_type: String) -> Array[Node2D]:
	return BuildingQueries.get_buildings_of_type(building_type, _unique_buildings)


## Get total maintenance cost for all buildings (delegated to BuildingQueries)
func get_total_maintenance(traffic_system: Node = null) -> int:
	return BuildingQueries.get_total_maintenance(_unique_buildings, traffic_system)


# =============================================================================
# BUILDING/OVERLAY/ROAD ACCESSORS
# =============================================================================

func get_building_at(cell: Vector2i) -> Node2D:
	return buildings.get(cell)


func has_building_at(cell: Vector2i) -> bool:
	return buildings.has(cell)


func get_building_cells() -> Array:
	return buildings.keys()


func get_building_count() -> int:
	return buildings.size()


func get_overlay_at(cell: Vector2i) -> Node2D:
	return utility_overlays.get(cell)


func has_overlay_at(cell: Vector2i) -> bool:
	return utility_overlays.has(cell)


func get_overlay_cells() -> Array:
	return utility_overlays.keys()


func get_overlay_count() -> int:
	return utility_overlays.size()


func get_road_cell_list() -> Array:
	return road_cells.keys()


func get_road_cell_map() -> Dictionary:
	return road_cells.duplicate()


# =============================================================================
# ROAD NETWORK MANAGEMENT (Delegated to RoadNetworkManager)
# =============================================================================

## Convert cell to AStar point ID (for backward compatibility)
func _cell_to_astar_id(cell: Vector2i) -> int:
	return _road_network._cell_to_astar_id(cell)


## Add a road cell (delegated to RoadNetworkManager)
func _add_road(cell: Vector2i) -> void:
	_road_network.add_road(cell)


## Remove a road cell (delegated to RoadNetworkManager)
func _remove_road(cell: Vector2i) -> void:
	_road_network.remove_road(cell)


## DEPRECATED: Visual updates now handled via events
func _update_adjacent_road_visuals(_cell: Vector2i) -> void:
	pass


## Emit water pipe network change event
func _emit_water_pipe_changed(cell: Vector2i, added: bool) -> void:
	var events = _get_events()
	if events:
		events.water_pipe_network_changed.emit(cell, added)


## Emit power line network change event
func _emit_power_line_changed(cell: Vector2i, added: bool) -> void:
	var events = _get_events()
	if events:
		events.power_line_network_changed.emit(cell, added)


## Check if a cell has a road (delegated to RoadNetworkManager)
func has_road_at(cell: Vector2i) -> bool:
	return _road_network.has_road_at(cell)


## Check if two cells are connected by road (delegated to RoadNetworkManager)
func is_connected_by_road(from: Vector2i, to: Vector2i) -> bool:
	return _road_network.is_connected_by_road(from, to)


func get_adjacent_cells(cell: Vector2i) -> Array[Vector2i]:
	return GridConstants.get_adjacent_cells(cell)


# =============================================================================
# SPATIAL QUERIES (O(1) lookups via spatial hash)
# =============================================================================

## Get all buildings within a radius of a center cell
func get_buildings_in_radius(center: Vector2i, radius: int) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var query_result = _building_spatial_index.query_radius(center, radius)

	for entry in query_result:
		var building = entry.get("data")
		if is_instance_valid(building):
			result.append(building)

	return result


## Get all buildings within a rectangular region
func get_buildings_in_region(min_cell: Vector2i, max_cell: Vector2i) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var query_result = _building_spatial_index.query_rect(min_cell, max_cell)

	for entry in query_result:
		var building = entry.get("data")
		if is_instance_valid(building):
			result.append(building)

	return result


## Get buildings of a specific type within a radius
func get_buildings_of_type_in_radius(center: Vector2i, radius: int, building_type: String) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var all_nearby = get_buildings_in_radius(center, radius)

	for building in all_nearby:
		if building.building_data and building.building_data.building_type == building_type:
			result.append(building)

	return result


## Get count of buildings in a radius
func get_building_count_in_radius(center: Vector2i, radius: int) -> int:
	return get_buildings_in_radius(center, radius).size()


# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_building_placed(_cell: Vector2i, _building: Node2D) -> void:
	pass


func _on_building_removed(_cell: Vector2i, _building: Node2D) -> void:
	pass
