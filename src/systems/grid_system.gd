extends Node2D
class_name GridSystem
## Manages the game grid, building placement, and tile-to-world conversions
##
## This is the core system for all grid-based operations. It handles:
## - Building placement and removal
## - Coordinate conversions (delegated to GridConstants)
## - Road network management with AStar pathfinding
## - Spatial indexing for efficient range queries
## - Utility overlay management (power/water on roads)

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
# ROAD NETWORK
# =============================================================================

## Cells that contain roads: {Vector2i: true}
var road_cells: Dictionary = {}

## AStar pathfinding for road connectivity
var astar: AStar2D = AStar2D.new()

## Maps cell positions to AStar point IDs: {Vector2i: point_id}
## Uses cell-based IDs: cell.x + cell.y * GRID_WIDTH
var _astar_cells: Dictionary = {}  # Tracks which cells have AStar points


# =============================================================================
# SYSTEM REFERENCES
# =============================================================================

## Terrain system reference for buildability checks
var terrain_system: Node = null

## Weather system reference for construction cost multiplier
var weather_system: Node = null


# =============================================================================
# BUILDING REGISTRY
# =============================================================================

## Building scene template
var building_scene: PackedScene = preload("res://src/entities/building.tscn")

## Building data registry: {id: BuildingData}
var building_registry: Dictionary = {}


# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	_load_building_registry()
	Events.building_placed.connect(_on_building_placed)
	Events.building_removed.connect(_on_building_removed)


func _load_building_registry() -> void:
	var data_path = "res://src/data/"
	var dir = DirAccess.open(data_path)
	if not dir:
		push_error("GridSystem: Cannot open building data directory: " + data_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource = load(data_path + file_name)
			# Only process BuildingData resources, skip other resource types
			if resource and resource.get_script() and resource.get_script().get_global_name() == "BuildingData":
				if _validate_building_data(resource):
					building_registry[resource.id] = resource
				else:
					push_warning("GridSystem: Invalid building data in " + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


## Validate building data has required fields
func _validate_building_data(data) -> bool:
	if data.get("id") == null or data.id == "":
		return false
	if not data.get("size") is Vector2i:
		return false
	if data.size.x <= 0 or data.size.y <= 0:
		return false
	if not data.get("build_cost") is int:
		return false
	if data.build_cost < 0:
		return false
	if data.get("display_name") == null:
		return false
	return true


# =============================================================================
# BUILDING REGISTRY ACCESS
# =============================================================================

## Returns BuildingData resource or null if not found
func get_building_data(id: String) -> Resource:
	return building_registry.get(id, null)


## Returns full building registry dictionary
func get_all_building_data() -> Dictionary:
	return building_registry


## Returns array of BuildingData resources matching category
func get_buildings_by_category(category: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for id in building_registry:
		var data: Resource = building_registry[id]
		if data.category == category:
			result.append(data)
	return result


# =============================================================================
# SYSTEM SETTERS
# =============================================================================

func set_terrain_system(ts: Node) -> void:
	terrain_system = ts


func set_weather_system(ws: Node) -> void:
	weather_system = ws


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
	var result: Dictionary = {
		"can_place": true,
		"reasons": [] as Array[String]
	}

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

	# Get zoning system reference
	var game_world = get_tree().get_first_node_in_group("game_world")
	if not game_world or not game_world.get("zoning_system"):
		return {"compliant": true, "reason": ""}

	var zoning_system = game_world.zoning_system
	if not zoning_system or not zoning_system.has_method("is_far_compliant"):
		return {"compliant": true, "reason": ""}

	return zoning_system.is_far_compliant(cell, building_data)


# =============================================================================
# BUILDING PLACEMENT
# =============================================================================

## Place a building at the specified cell. Returns the Building node or null on failure.
func place_building(cell: Vector2i, building_data: Resource) -> Node2D:
	var check = can_place_building(cell, building_data)
	if not check.can_place:
		return null

	# Calculate effective build cost (apply weather multiplier)
	var effective_cost = building_data.build_cost
	if weather_system and weather_system.has_method("get_construction_cost_multiplier"):
		effective_cost = int(effective_cost * weather_system.get_construction_cost_multiplier())

	# Check if player can afford it
	if not GameState.can_afford(effective_cost):
		Events.simulation_event.emit("insufficient_funds", {"cost": effective_cost})
		return null

	# Spend the money
	GameState.spend(effective_cost)

	# Create building instance
	var building = building_scene.instantiate()
	building.position = grid_to_world(cell)
	add_child(building)
	building.initialize(building_data, cell)

	# Determine if this is an overlay situation
	var building_type = building_data.building_type if building_data.get("building_type") else ""
	var is_utility = GridConstants.is_utility_type(building_type)
	var is_overlay = false

	# Register in all occupied cells
	for x in range(building_data.size.x):
		for y in range(building_data.size.y):
			var occupied_cell = cell + Vector2i(x, y)

			# Check if placing utility on existing road
			if is_utility and buildings.has(occupied_cell):
				var existing = buildings[occupied_cell]
				if existing.building_data and GridConstants.is_road_type(existing.building_data.building_type):
					utility_overlays[occupied_cell] = building
					is_overlay = true
					continue

			buildings[occupied_cell] = building

	# Add to unique buildings cache
	_unique_buildings[building.get_instance_id()] = building

	# Track special building types
	if GridConstants.is_road_type(building_type):
		_add_road(cell)
	elif GridConstants.is_water_type(building_type):
		_emit_water_pipe_changed(cell, true)
	elif GridConstants.is_power_type(building_type):
		_emit_power_line_changed(cell, true)

	# Emit network changes for buildings that produce/consume utilities
	# This triggers adjacent pipes to update their visuals
	if building_data.water_production > 0 or building_data.water_consumption > 0:
		# Emit for all cells of multi-cell buildings to update all adjacent pipes
		for x in range(building_data.size.x):
			for y in range(building_data.size.y):
				_emit_water_pipe_changed(cell + Vector2i(x, y), true)
	if building_data.power_production > 0 or building_data.power_consumption > 0:
		for x in range(building_data.size.x):
			for y in range(building_data.size.y):
				_emit_power_line_changed(cell + Vector2i(x, y), true)
	# Zone counting is handled by ZoningSystem via building events

	# Update building counts
	GameState.increment_building_count(building_data.id)

	# Add to spatial index
	if not is_overlay:
		var building_cells: Array[Vector2i] = []
		for x in range(building_data.size.x):
			for y in range(building_data.size.y):
				building_cells.append(cell + Vector2i(x, y))
		_building_spatial_index.insert_multi(building.get_instance_id(), building_cells, building)

	Events.building_placed.emit(cell, building)
	return building


# =============================================================================
# BUILDING REMOVAL
# =============================================================================

func remove_building(cell: Vector2i) -> bool:
	# First check if there's a utility overlay at this cell (remove overlay first)
	if utility_overlays.has(cell):
		var overlay = utility_overlays[cell]
		if is_instance_valid(overlay):
			var overlay_data = overlay.building_data
			var overlay_origin = overlay.grid_cell

			# Remove overlay from all its cells
			for x in range(overlay_data.size.x):
				for y in range(overlay_data.size.y):
					var occupied_cell = overlay_origin + Vector2i(x, y)
					utility_overlays.erase(occupied_cell)

			# Update adjacent infrastructure if this was a utility
			if GridConstants.is_water_type(overlay_data.building_type):
				_emit_water_pipe_changed(overlay_origin, false)
			elif GridConstants.is_power_type(overlay_data.building_type):
				_emit_power_line_changed(overlay_origin, false)

			# Refund and cleanup
			var overlay_refund = int(overlay_data.build_cost * 0.5)
			GameState.earn(overlay_refund)
			GameState.decrement_building_count(overlay_data.id)

			# Remove from unique buildings cache
			_unique_buildings.erase(overlay.get_instance_id())

			Events.building_removed.emit(overlay_origin, overlay)
			overlay.queue_free()
			return true
		else:
			utility_overlays.erase(cell)

	if not buildings.has(cell):
		return false

	var building = buildings[cell]
	if not is_instance_valid(building):
		buildings.erase(cell)
		return false

	var building_data = building.building_data
	var origin_cell = building.grid_cell

	# Remove from all occupied cells
	for x in range(building_data.size.x):
		for y in range(building_data.size.y):
			var occupied_cell = origin_cell + Vector2i(x, y)
			buildings.erase(occupied_cell)
			# Also remove any overlays on this building
			if utility_overlays.has(occupied_cell):
				var overlay = utility_overlays[occupied_cell]
				if is_instance_valid(overlay):
					_unique_buildings.erase(overlay.get_instance_id())
					overlay.queue_free()
				utility_overlays.erase(occupied_cell)

	# Handle special building type removal
	var building_type = building_data.building_type if building_data.get("building_type") else ""
	if GridConstants.is_road_type(building_type):
		_remove_road(origin_cell)
	elif GridConstants.is_water_type(building_type):
		_emit_water_pipe_changed(origin_cell, false)
	elif GridConstants.is_power_type(building_type):
		_emit_power_line_changed(origin_cell, false)

	# Emit network changes for buildings that produce/consume utilities
	# This triggers adjacent pipes to update their visuals
	if building_data.water_production > 0 or building_data.water_consumption > 0:
		for x in range(building_data.size.x):
			for y in range(building_data.size.y):
				_emit_water_pipe_changed(origin_cell + Vector2i(x, y), false)
	if building_data.power_production > 0 or building_data.power_consumption > 0:
		for x in range(building_data.size.x):
			for y in range(building_data.size.y):
				_emit_power_line_changed(origin_cell + Vector2i(x, y), false)
	# Zone counting is handled by ZoningSystem via building events

	# Refund partial cost (50%)
	var refund = int(building_data.build_cost * 0.5)
	GameState.earn(refund)

	# Update building counts
	GameState.decrement_building_count(building_data.id)

	# Remove from caches
	_unique_buildings.erase(building.get_instance_id())
	_building_spatial_index.remove(building.get_instance_id())

	Events.building_removed.emit(origin_cell, building)
	building.queue_free()
	return true


# =============================================================================
# BUILDING QUERIES
# =============================================================================

func get_building_at(cell: Vector2i) -> Node2D:
	return buildings.get(cell)


func get_all_buildings() -> Dictionary:
	return buildings


## Get all unique buildings (O(1) - uses cache)
func get_all_unique_buildings() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for building in _unique_buildings.values():
		if is_instance_valid(building):
			result.append(building)
	return result


## Get buildings of a specific type (uses unique cache for efficiency)
func get_buildings_of_type(building_type: String) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for building in _unique_buildings.values():
		if is_instance_valid(building) and building.building_data:
			if building.building_data.building_type == building_type:
				result.append(building)
	return result


## Get total maintenance cost for all buildings
func get_total_maintenance(traffic_system: Node = null) -> int:
	var total = 0
	for building in _unique_buildings.values():
		if not is_instance_valid(building) or not building.building_data:
			continue

		var base_maintenance = building.building_data.monthly_maintenance

		# Roads have additional maintenance based on traffic
		if GridConstants.is_road_type(building.building_data.building_type) and traffic_system:
			var cell = building.grid_cell
			var congestion = traffic_system.get_congestion_at(cell)
			if congestion > 0.5:
				var traffic_multiplier = 1.0 + (congestion - 0.5) * 2.0
				base_maintenance = int(base_maintenance * traffic_multiplier)
				base_maintenance = max(base_maintenance, int(5 * congestion))

		total += base_maintenance
	return total


# =============================================================================
# ROAD NETWORK MANAGEMENT
# =============================================================================

## Convert cell to AStar point ID (deterministic, based on position)
func _cell_to_astar_id(cell: Vector2i) -> int:
	return cell.x + cell.y * GridConstants.GRID_WIDTH


func _add_road(cell: Vector2i) -> void:
	road_cells[cell] = true

	# Add to AStar pathfinding using cell-based ID
	var point_id = _cell_to_astar_id(cell)

	if not astar.has_point(point_id):
		astar.add_point(point_id, Vector2(cell.x, cell.y))
		_astar_cells[cell] = true

	# Connect to adjacent road cells
	var neighbors = GridConstants.get_adjacent_cells(cell)
	for neighbor in neighbors:
		if road_cells.has(neighbor):
			var neighbor_id = _cell_to_astar_id(neighbor)
			if astar.has_point(neighbor_id) and not astar.are_points_connected(point_id, neighbor_id):
				astar.connect_points(point_id, neighbor_id)

	# Emit event for decoupled visual updates (buildings listen and update themselves)
	Events.road_network_changed.emit(cell, true)


func _remove_road(cell: Vector2i) -> void:
	road_cells.erase(cell)

	var point_id = _cell_to_astar_id(cell)
	if astar.has_point(point_id):
		astar.remove_point(point_id)
		_astar_cells.erase(cell)

	# Emit event for decoupled visual updates
	Events.road_network_changed.emit(cell, false)


## DEPRECATED: Visual updates now handled via events
## Kept for backward compatibility - will be removed in future version
func _update_adjacent_road_visuals(_cell: Vector2i) -> void:
	# Visual updates are now decoupled via Events.road_network_changed
	# Buildings subscribe to this event and update themselves
	pass


## Emit water pipe network change event
func _emit_water_pipe_changed(cell: Vector2i, added: bool) -> void:
	Events.water_pipe_network_changed.emit(cell, added)


## Emit power line network change event
func _emit_power_line_changed(cell: Vector2i, added: bool) -> void:
	Events.power_line_network_changed.emit(cell, added)


func has_road_at(cell: Vector2i) -> bool:
	return road_cells.has(cell)


func is_connected_by_road(from: Vector2i, to: Vector2i) -> bool:
	var from_id = _cell_to_astar_id(from)
	var to_id = _cell_to_astar_id(to)

	if not astar.has_point(from_id) or not astar.has_point(to_id):
		return false

	var path = astar.get_id_path(from_id, to_id)
	return path.size() > 0


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
