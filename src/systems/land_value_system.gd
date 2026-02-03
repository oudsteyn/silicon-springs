extends Node
class_name LandValueSystem
## Calculates land value based on services, parks, pollution, traffic, and proximity to amenities

var grid_system = null
var service_coverage = null
var pollution_system = null
var traffic_system = null
var zoning_system = null
var terrain_system = null

# Land value map: {Vector2i: value (0.0 to 1.0)}
var land_value_map: Dictionary = {}

# Park boost locations: {Vector2i: boost_amount}
var park_boost_map: Dictionary = {}

# Transit premium map: {Vector2i: boost_amount}
# Transit-oriented development significantly increases land value
var transit_premium_map: Dictionary = {}

# Transit premium by station type (land value increase at station, decreases with distance)
const TRANSIT_LAND_VALUE_BONUS: Dictionary = {
	"subway_station": 0.25,   # 25% max bonus
	"rail_station": 0.20,     # 20% max bonus
	"bus_depot": 0.12,        # 12% max bonus
	"bus_stop": 0.05,         # 5% max bonus
}

# Water proximity bonus map
var water_proximity_map: Dictionary = {}

# Elevation view bonus map
var elevation_bonus_map: Dictionary = {}

# Natural features bonus map (trees nearby)
var nature_bonus_map: Dictionary = {}


func _ready() -> void:
	Events.building_placed.connect(_on_building_placed)
	Events.building_removed.connect(_on_building_removed)
	Events.coverage_updated.connect(_on_coverage_updated)
	Events.pollution_updated.connect(_on_pollution_updated)


func set_grid_system(system) -> void:
	grid_system = system


func set_service_coverage(coverage) -> void:
	service_coverage = coverage


func set_pollution_system(pollution) -> void:
	pollution_system = pollution


func set_traffic_system(traffic) -> void:
	traffic_system = traffic


func set_zoning_system(zoning) -> void:
	zoning_system = zoning


func set_terrain_system(terrain) -> void:
	terrain_system = terrain
	# Recalculate terrain bonuses when terrain system is set
	_update_terrain_bonuses()


func _on_building_placed(cell: Vector2i, building: Node2D) -> void:
	if not building.building_data:
		return

	# Check if it's a park
	if building.building_data.service_type == "park":
		_add_park_boost(cell, building.building_data.coverage_radius)
		_update_land_values()

	# Check if it's a transit station (TOD bonus)
	if building.building_data.building_type in TRANSIT_LAND_VALUE_BONUS:
		_add_transit_premium(cell, building.building_data)
		_update_land_values()


func _on_building_removed(cell: Vector2i, building: Node2D) -> void:
	if not building or not building.building_data:
		return

	if building.building_data.service_type == "park":
		_remove_park_boost(cell, building.building_data.coverage_radius)
		_update_land_values()

	if building.building_data.building_type in TRANSIT_LAND_VALUE_BONUS:
		_remove_transit_premium(cell, building.building_data)
		_update_land_values()


func _on_coverage_updated(_service_type: String) -> void:
	_update_land_values()


func _on_pollution_updated() -> void:
	_update_land_values()


func _add_park_boost(center: Vector2i, radius: int) -> void:
	# Use pre-computed coverage mask for efficiency
	var mask = SpatialHash.get_coverage_mask_with_strength(radius)
	for entry in mask:
		var cell = center + entry.offset
		var boost = 0.3 * entry.strength  # Up to 30% boost
		if park_boost_map.has(cell):
			park_boost_map[cell] = minf(0.5, park_boost_map[cell] + boost)
		else:
			park_boost_map[cell] = boost


func _remove_park_boost(_center: Vector2i, _radius: int) -> void:
	# Recalculate all park boosts (simpler than tracking individual parks)
	park_boost_map.clear()

	if not grid_system:
		return

	# Re-add boosts from all remaining parks
	var counted = {}
	for cell in grid_system.buildings:
		var building = grid_system.buildings[cell]
		if counted.has(building) or not is_instance_valid(building):
			continue
		counted[building] = true


## Add transit-oriented development land value premium
func _add_transit_premium(center: Vector2i, building_data: Resource) -> void:
	var transit_type = building_data.building_type
	if not TRANSIT_LAND_VALUE_BONUS.has(transit_type):
		return

	var max_bonus = TRANSIT_LAND_VALUE_BONUS[transit_type]
	var radius = building_data.coverage_radius if building_data.coverage_radius > 0 else 10

	# Use pre-computed coverage mask for efficiency
	var mask = SpatialHash.get_coverage_mask_with_strength(radius)
	for entry in mask:
		var cell = center + entry.offset
		var bonus = max_bonus * entry.strength
		if transit_premium_map.has(cell):
			transit_premium_map[cell] = minf(0.35, transit_premium_map[cell] + bonus)
		else:
			transit_premium_map[cell] = bonus


## Remove transit premium (recalculate from remaining stations)
func _remove_transit_premium(_center: Vector2i, _building_data: Resource) -> void:
	transit_premium_map.clear()

	if not grid_system:
		return

	# Re-add premiums from all remaining transit stations
	var counted = {}
	for cell in grid_system.buildings:
		var building = grid_system.buildings[cell]
		if counted.has(building) or not is_instance_valid(building):
			continue
		counted[building] = true

		if building.building_data and building.building_data.building_type in TRANSIT_LAND_VALUE_BONUS:
			_add_transit_premium(building.grid_cell, building.building_data)

		if building.building_data and building.building_data.service_type == "park":
			_add_park_boost(building.grid_cell, building.building_data.coverage_radius)


func _update_land_values() -> void:
	land_value_map.clear()

	if not grid_system:
		return

	# Calculate land value for each cell with a building
	for cell in grid_system.buildings:
		land_value_map[cell] = _calculate_cell_value(cell)


func _calculate_cell_value(cell: Vector2i) -> float:
	var value = 0.5  # Base value

	# Service coverage boosts
	if service_coverage:
		if service_coverage.has_fire_coverage(cell):
			value += 0.1
		if service_coverage.has_police_coverage(cell):
			value += 0.1
		if service_coverage.has_education_coverage(cell):
			value += 0.15

	# Park boost
	if park_boost_map.has(cell):
		value += park_boost_map[cell]

	# Transit-oriented development premium (subway/rail stations significantly boost land value)
	if transit_premium_map.has(cell):
		value += transit_premium_map[cell]

	# Pollution penalty
	if pollution_system:
		var pollution = pollution_system.get_pollution_at(cell)
		value -= pollution * 0.5  # Up to 50% reduction from pollution

	# Traffic congestion penalty - affects nearby cells too
	if traffic_system:
		var traffic_penalty = _get_traffic_penalty(cell)
		value -= traffic_penalty

		# Additional transit coverage bonus (bus routes, etc.)
		var transit_coverage = traffic_system.get_transit_coverage_at(cell)
		if transit_coverage > 0:
			value += transit_coverage * 0.1  # Smaller bonus, main value is from transit_premium_map

	# Crime penalty - high crime reduces land value
	var crime_rate = GameState.city_crime_rate
	if crime_rate > 0.1:
		value -= (crime_rate - 0.1) * 0.3  # Up to 27% penalty at max crime

	# Buffer zone bonus - commercial zones buffering residential from industrial
	if zoning_system:
		var buffer_bonus = zoning_system.get_buffer_bonus(cell)
		value += buffer_bonus

	# Terrain-based bonuses
	# Water proximity bonus (waterfront property is valuable)
	if water_proximity_map.has(cell):
		value += water_proximity_map[cell]

	# Elevation view bonus (hills with views)
	if elevation_bonus_map.has(cell):
		value += elevation_bonus_map[cell]

	# Natural features nearby (trees increase appeal)
	if nature_bonus_map.has(cell):
		value += nature_bonus_map[cell]

	# Clamp to valid range
	return clamp(value, 0.1, 1.0)


func _get_traffic_penalty(cell: Vector2i) -> float:
	if not traffic_system:
		return 0.0

	var max_penalty = 0.0

	# Check this cell and adjacent cells for traffic
	var cells_to_check = [
		cell,
		cell + Vector2i(1, 0),
		cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(0, -1)
	]

	for check_cell in cells_to_check:
		var congestion = traffic_system.get_congestion_at(check_cell)
		# Heavy traffic (>50% congestion) starts affecting land value
		if congestion > 0.5:
			var penalty = (congestion - 0.5) * 0.4  # Up to 20% penalty at full congestion
			max_penalty = max(max_penalty, penalty)

	return max_penalty


func update_land_values() -> void:
	_update_land_values()


func get_land_value_at(cell: Vector2i) -> float:
	if land_value_map.has(cell):
		return land_value_map[cell]
	return _calculate_cell_value(cell)


func get_average_land_value() -> float:
	if land_value_map.size() == 0:
		return 0.5

	var total = 0.0
	for cell in land_value_map:
		total += land_value_map[cell]
	return total / land_value_map.size()


func get_tax_multiplier_at(cell: Vector2i) -> float:
	# Higher land value = higher tax revenue
	var value = get_land_value_at(cell)
	return 0.5 + (value * 1.0)  # 0.5x to 1.5x multiplier


func get_land_value_map() -> Dictionary:
	return land_value_map


## Update terrain-based bonus maps
func _update_terrain_bonuses() -> void:
	water_proximity_map.clear()
	elevation_bonus_map.clear()
	nature_bonus_map.clear()

	if not terrain_system:
		return

	# Scan the grid for terrain features
	var grid_width = GridConstants.GRID_WIDTH
	var grid_height = GridConstants.GRID_HEIGHT

	# First pass: identify water cells and high elevation cells
	var water_cells: Array[Vector2i] = []
	var tree_cells: Array[Vector2i] = []

	for x in range(grid_width):
		for y in range(grid_height):
			var cell = Vector2i(x, y)

			# Check for water
			if terrain_system.has_method("get_water"):
				var water_type = terrain_system.get_water(cell)
				if water_type != 0:  # Not NONE
					water_cells.append(cell)

			# Check for trees
			if terrain_system.has_method("get_feature"):
				var feature = terrain_system.get_feature(cell)
				# TREE_SPARSE = 1, TREE_DENSE = 2
				if feature in [1, 2]:
					tree_cells.append(cell)

	# Calculate water proximity bonus (3-cell radius) using pre-computed mask
	var water_mask = SpatialHash.get_coverage_mask_with_strength(3)
	for water_cell in water_cells:
		for entry in water_mask:
			if entry.offset == Vector2i.ZERO:
				continue  # Skip water cells themselves
			var cell = water_cell + entry.offset
			if cell.x < 0 or cell.x >= grid_width or cell.y < 0 or cell.y >= grid_height:
				continue

			# Waterfront bonus: up to 25% for adjacent, falloff with distance
			var bonus = 0.25 * entry.strength
			if water_proximity_map.has(cell):
				water_proximity_map[cell] = minf(0.3, water_proximity_map[cell] + bonus)
			else:
				water_proximity_map[cell] = bonus

	# Calculate elevation view bonus
	for x in range(grid_width):
		for y in range(grid_height):
			var cell = Vector2i(x, y)
			if terrain_system.has_method("get_elevation"):
				var elevation = terrain_system.get_elevation(cell)
				# Hills (elevation 2-3) get view bonus
				if elevation >= 2 and elevation <= 3:
					elevation_bonus_map[cell] = 0.1  # 10% bonus
				# Mountain base (elevation 4) gets smaller bonus (less buildable)
				elif elevation == 4:
					elevation_bonus_map[cell] = 0.05  # 5% bonus

	# Calculate nature/tree proximity bonus (2-cell radius) using pre-computed mask
	var nature_mask = SpatialHash.get_coverage_mask_with_strength(2)
	for tree_cell in tree_cells:
		for entry in nature_mask:
			if entry.offset == Vector2i.ZERO:
				continue
			var cell = tree_cell + entry.offset
			if cell.x < 0 or cell.x >= grid_width or cell.y < 0 or cell.y >= grid_height:
				continue

			var bonus = 0.08 * entry.strength
			if nature_bonus_map.has(cell):
				nature_bonus_map[cell] = minf(0.15, nature_bonus_map[cell] + bonus)
			else:
				nature_bonus_map[cell] = bonus

	# Trigger land value recalculation
	_update_land_values()


## Call this when terrain changes significantly
func on_terrain_changed() -> void:
	_update_terrain_bonuses()


## Get terrain bonus breakdown for a cell (for UI)
func get_terrain_bonus_at(cell: Vector2i) -> Dictionary:
	return {
		"water_proximity": water_proximity_map.get(cell, 0.0),
		"elevation_view": elevation_bonus_map.get(cell, 0.0),
		"nature_nearby": nature_bonus_map.get(cell, 0.0)
	}
