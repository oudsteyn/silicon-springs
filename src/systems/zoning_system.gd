extends Node
class_name ZoningSystem
## SimCity 4 style zoning - paint zones and buildings grow automatically

signal zone_changed(cell: Vector2i, zone_type: String)
signal building_spawned(cell: Vector2i, building_type: String)
signal building_upgraded(cell: Vector2i, new_level: int)

var grid_system: Node = null
var service_coverage: Node = null
var land_value_system: Node = null
var terrain_system: Node = null

# Zone data: {Vector2i: ZoneData}
var zones: Dictionary = {}

# Zone types
enum ZoneType { NONE, RESIDENTIAL_LOW, RESIDENTIAL_MED, RESIDENTIAL_HIGH,
				COMMERCIAL_LOW, COMMERCIAL_MED, COMMERCIAL_HIGH,
				INDUSTRIAL_LOW, INDUSTRIAL_MED, INDUSTRIAL_HIGH,
				AGRICULTURAL }

# Zone colors for visualization
# Normalized brightness across density levels for visual consistency
const ZONE_COLORS = {
	ZoneType.NONE: Color(0, 0, 0, 0),
	# Residential: Green family - consistent brightness progression
	ZoneType.RESIDENTIAL_LOW: Color(0.45, 0.75, 0.45, 0.4),   # Light green
	ZoneType.RESIDENTIAL_MED: Color(0.30, 0.60, 0.30, 0.4),   # Medium green
	ZoneType.RESIDENTIAL_HIGH: Color(0.18, 0.45, 0.18, 0.4),  # Dark green
	# Commercial: Blue family - consistent brightness progression
	ZoneType.COMMERCIAL_LOW: Color(0.45, 0.45, 0.80, 0.4),    # Light blue
	ZoneType.COMMERCIAL_MED: Color(0.30, 0.30, 0.65, 0.4),    # Medium blue
	ZoneType.COMMERCIAL_HIGH: Color(0.18, 0.18, 0.50, 0.4),   # Dark blue
	# Industrial: Yellow/amber family - consistent brightness progression
	ZoneType.INDUSTRIAL_LOW: Color(0.80, 0.70, 0.35, 0.4),    # Light amber
	ZoneType.INDUSTRIAL_MED: Color(0.65, 0.55, 0.22, 0.4),    # Medium amber
	ZoneType.INDUSTRIAL_HIGH: Color(0.50, 0.42, 0.15, 0.4),   # Dark amber
	# Agricultural: Earth tone
	ZoneType.AGRICULTURAL: Color(0.55, 0.48, 0.28, 0.4)       # Brown
}

# Zone capacity by density
const ZONE_CAPACITY = {
	ZoneType.RESIDENTIAL_LOW: {"pop": 20, "jobs": 0, "size": 1},
	ZoneType.RESIDENTIAL_MED: {"pop": 80, "jobs": 0, "size": 2},
	ZoneType.RESIDENTIAL_HIGH: {"pop": 200, "jobs": 0, "size": 3},
	ZoneType.COMMERCIAL_LOW: {"pop": 0, "jobs": 10, "size": 1},
	ZoneType.COMMERCIAL_MED: {"pop": 0, "jobs": 40, "size": 2},
	ZoneType.COMMERCIAL_HIGH: {"pop": 0, "jobs": 100, "size": 3},
	ZoneType.INDUSTRIAL_LOW: {"pop": 0, "jobs": 15, "size": 1},
	ZoneType.INDUSTRIAL_MED: {"pop": 0, "jobs": 60, "size": 2},
	ZoneType.INDUSTRIAL_HIGH: {"pop": 0, "jobs": 150, "size": 3},
	ZoneType.AGRICULTURAL: {"pop": 0, "jobs": 0.25, "size": 1}
}

# FAR (Floor Area Ratio) limits by zone type
# FAR = total floor area / lot area
# Low density = suburban, High density = downtown
const ZONE_FAR_LIMITS = {
	ZoneType.NONE: 0.0,
	ZoneType.RESIDENTIAL_LOW: 0.5,    # Single family homes, 1-2 floors
	ZoneType.RESIDENTIAL_MED: 1.5,    # Townhouses, small apartments, 2-4 floors
	ZoneType.RESIDENTIAL_HIGH: 4.0,   # High-rise apartments, 8-15 floors
	ZoneType.COMMERCIAL_LOW: 0.5,     # Strip malls, small retail
	ZoneType.COMMERCIAL_MED: 2.0,     # Office parks, mid-rise
	ZoneType.COMMERCIAL_HIGH: 6.0,    # Downtown office towers, 15-25 floors
	ZoneType.INDUSTRIAL_LOW: 0.4,     # Warehouses, light manufacturing
	ZoneType.INDUSTRIAL_MED: 0.6,     # Medium industrial
	ZoneType.INDUSTRIAL_HIGH: 0.8,    # Heavy industrial (typically low-rise but dense)
	ZoneType.AGRICULTURAL: 0.0,       # No FAR limit for farmland
}

# Building spawn chance per month (when conditions are met) - Legacy constants, use GameConfig
const BASE_SPAWN_CHANCE: float = 0.15
const BASE_UPGRADE_CHANCE: float = 0.08

## Get spawn chance from GameConfig
func _get_spawn_chance() -> float:
	return GameConfig.zone_spawn_chance if GameConfig else BASE_SPAWN_CHANCE

## Get upgrade chance from GameConfig
func _get_upgrade_chance() -> float:
	return GameConfig.zone_upgrade_chance if GameConfig else BASE_UPGRADE_CHANCE

# Zoning compatibility matrix
# Values: 1.0 = fully compatible, 0.5 = needs buffer, 0.0 = incompatible
const COMPATIBILITY: Dictionary = {
	"residential": {
		"residential": 1.0,
		"commercial": 0.8,
		"industrial": 0.3,
		"heavy_industrial": 0.0,
		"mixed_use": 1.0,
		"park": 1.0,
		"data_center": 0.5,
	},
	"commercial": {
		"residential": 0.8,
		"commercial": 1.0,
		"industrial": 0.6,
		"heavy_industrial": 0.3,
		"mixed_use": 1.0,
		"park": 1.0,
		"data_center": 0.8,
	},
	"industrial": {
		"residential": 0.3,
		"commercial": 0.6,
		"industrial": 1.0,
		"heavy_industrial": 0.8,
		"mixed_use": 0.4,
		"park": 0.5,
		"data_center": 0.7,
	},
	"heavy_industrial": {
		"residential": 0.0,
		"commercial": 0.3,
		"industrial": 0.8,
		"heavy_industrial": 1.0,
		"mixed_use": 0.1,
		"park": 0.3,
		"data_center": 0.5,
	},
	"mixed_use": {
		"residential": 1.0,
		"commercial": 1.0,
		"industrial": 0.4,
		"heavy_industrial": 0.1,
		"mixed_use": 1.0,
		"park": 1.0,
		"data_center": 0.6,
	},
}

# Buffer requirements (tiles needed between incompatible zones)
const BUFFER_REQUIREMENTS: Dictionary = {
	"residential_industrial": 2,
	"residential_heavy_industrial": 4,
	"commercial_heavy_industrial": 2,
	"mixed_use_industrial": 2,
	"mixed_use_heavy_industrial": 3,
}

# Happiness penalty for incompatible adjacency - Legacy constant, use GameConfig
const INCOMPATIBILITY_HAPPINESS_PENALTY: float = 0.03

## Get incompatibility penalty from GameConfig
func _get_incompatibility_penalty() -> float:
	return GameConfig.zoning_incompatibility_penalty if GameConfig else INCOMPATIBILITY_HAPPINESS_PENALTY


class ZoneData:
	var type: int = ZoneType.NONE
	var developed: bool = false
	var development_level: int = 0  # 0=empty, 1=small, 2=medium, 3=large
	var development_progress: float = 0.0
	var building_id: String = ""  # ID of spawned building if any


func _ready() -> void:
	Events.month_tick.connect(_on_month_tick)
	Events.building_removed.connect(_on_building_removed)


func initialize(grid: Node, coverage: Node, land_value: Node, terrain: Node = null) -> void:
	grid_system = grid
	service_coverage = coverage
	land_value_system = land_value
	terrain_system = terrain


## Get FAR limit for a zone type
func get_far_limit(zone_type: int) -> float:
	return ZONE_FAR_LIMITS.get(zone_type, 0.0)


## Get FAR limit at a specific cell (considers transit bonuses)
func get_effective_far_limit(cell: Vector2i) -> float:
	if not zones.has(cell):
		return 0.0

	var base_limit = get_far_limit(zones[cell].type)

	# Apply transit-oriented development bonus
	var transit_bonus = _get_transit_far_bonus(cell)

	return base_limit * (1.0 + transit_bonus)


## Check if a building's FAR is within zone limits
func is_far_compliant(cell: Vector2i, building_data: Resource) -> Dictionary:
	var result = {"compliant": true, "reason": ""}

	if not zones.has(cell):
		# Not a zoned area - no FAR restrictions
		return result

	var _zone_data = zones[cell]  # Zone data available for future FAR calculations
	var far_limit = get_effective_far_limit(cell)

	if far_limit <= 0:
		return result

	var building_far: float
	if building_data.has_method("get_far"):
		building_far = building_data.get_far()
	else:
		building_far = float(building_data.floors) if building_data.floors > 0 else 1.0

	if building_far > far_limit:
		result.compliant = false
		result.reason = "Exceeds FAR limit (%.1f > %.1f)" % [building_far, far_limit]

	return result


## Get transit-oriented development FAR bonus at a cell
## Returns bonus multiplier (0.0 = no bonus, 0.5 = 50% more FAR allowed)
func _get_transit_far_bonus(cell: Vector2i) -> float:
	if not grid_system:
		return 0.0

	# Check for nearby transit stations
	var transit_types = ["subway_station", "rail_station", "bus_depot"]
	var max_bonus: float = 0.0

	for transit_type in transit_types:
		var stations = grid_system.get_buildings_of_type(transit_type)
		for station in stations:
			if not is_instance_valid(station):
				continue
			var distance = GridConstants.manhattan_distance(cell, station.grid_cell)

			# Transit bonus decreases with distance
			var bonus: float = 0.0
			match transit_type:
				"subway_station":
					if distance <= 8:
						bonus = 0.5 * (1.0 - distance / 8.0)  # Up to 50% bonus
				"rail_station":
					if distance <= 6:
						bonus = 0.4 * (1.0 - distance / 6.0)  # Up to 40% bonus
				"bus_depot":
					if distance <= 4:
						bonus = 0.2 * (1.0 - distance / 4.0)  # Up to 20% bonus

			max_bonus = maxf(max_bonus, bonus)

	return max_bonus


func set_zone(cell: Vector2i, zone_type: int) -> bool:
	if not grid_system:
		return false

	# Check if cell is valid
	if not grid_system.is_valid_cell(cell):
		return false

	# Check terrain buildability (skip for zone removal)
	if terrain_system and zone_type != ZoneType.NONE:
		var terrain_check = terrain_system.is_buildable(cell)
		if not terrain_check.can_build:
			return false

	# Can't zone on existing buildings (except other zones)
	if grid_system.has_building_at(cell):
		var existing = grid_system.get_building_at(cell)
		if existing and existing.building_data:
			# Allow rezoning existing zones
			if existing.building_data.category != "zone":
				return false

	# Must be adjacent to road (agricultural zones exempt)
	if zone_type != ZoneType.NONE and zone_type != ZoneType.AGRICULTURAL and not _has_adjacent_road(cell):
		return false

	# Create or update zone
	if zone_type == ZoneType.NONE:
		if zones.has(cell):
			# Remove zone - decrement count before erasing
			var zone_data = zones[cell]
			if zone_data.developed:
				_update_zone_counts(zone_data.type, -1)
				if grid_system.has_building_at(cell):
					grid_system.remove_building(cell)
			zones.erase(cell)
			zone_changed.emit(cell, "none")
	else:
		if not zones.has(cell):
			zones[cell] = ZoneData.new()
		zones[cell].type = zone_type
		zones[cell].developed = false
		zones[cell].development_level = 0
		zone_changed.emit(cell, get_zone_name(zone_type))

	return true


func paint_zone(start_cell: Vector2i, end_cell: Vector2i, zone_type: int) -> int:
	# Paint zones in a rectangle
	var count = 0
	var min_x = min(start_cell.x, end_cell.x)
	var max_x = max(start_cell.x, end_cell.x)
	var min_y = min(start_cell.y, end_cell.y)
	var max_y = max(start_cell.y, end_cell.y)

	for x in range(min_x, max_x + 1):
		for y in range(min_y, max_y + 1):
			if set_zone(Vector2i(x, y), zone_type):
				count += 1

	return count


func _has_adjacent_road(cell: Vector2i) -> bool:
	if not grid_system:
		return false

	var neighbors = [
		cell + Vector2i(1, 0), cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1), cell + Vector2i(0, -1)
	]

	for neighbor in neighbors:
		if grid_system.has_road_at(neighbor):
			return true
	return false


func _on_month_tick() -> void:
	_process_zone_development()


func _process_zone_development() -> void:
	if not grid_system:
		return

	for cell in zones:
		var zone_data = zones[cell]
		if zone_data.type == ZoneType.NONE:
			continue

		# Check if zone can develop
		if not _can_zone_develop(cell, zone_data):
			continue

		var demand = _get_zone_demand(zone_data.type)
		if demand <= 0:
			continue

		if not zone_data.developed:
			# Try to spawn initial building (use GameConfig spawn chance)
			var spawn_chance = _get_spawn_chance() * (1.0 + demand)
			if randf() < spawn_chance:
				_spawn_building(cell, zone_data)
		else:
			# Try to upgrade existing building
			if zone_data.development_level < 3:
				zone_data.development_progress += _calculate_growth_rate(cell, zone_data, demand)
				if zone_data.development_progress >= 100.0:
					_upgrade_building(cell, zone_data)


func _can_zone_develop(cell: Vector2i, _zone_data: ZoneData) -> bool:
	# Check terrain buildability
	if terrain_system:
		var terrain_check = terrain_system.is_buildable(cell)
		if not terrain_check.can_build:
			return false

	# Agricultural zones are self-sufficient — skip power, water, and road checks
	if _zone_data.type == ZoneType.AGRICULTURAL:
		return true

	# Check power
	if GameState.has_power_shortage():
		return false

	# Check water
	if GameState.has_water_shortage():
		return false

	# Check road access
	if not _has_adjacent_road(cell):
		return false

	return true


func _get_zone_demand(zone_type: int) -> float:
	match zone_type:
		ZoneType.RESIDENTIAL_LOW, ZoneType.RESIDENTIAL_MED, ZoneType.RESIDENTIAL_HIGH:
			return GameState.residential_demand
		ZoneType.COMMERCIAL_LOW, ZoneType.COMMERCIAL_MED, ZoneType.COMMERCIAL_HIGH:
			return GameState.commercial_demand
		ZoneType.INDUSTRIAL_LOW, ZoneType.INDUSTRIAL_MED, ZoneType.INDUSTRIAL_HIGH:
			return GameState.industrial_demand
		ZoneType.AGRICULTURAL:
			# Cap: ~1 agricultural tile per person, minimum 9 plots
			var ag_limit = maxi(9, int(GameState.population * 0.9))
			if _count_developed_zones(ZoneType.AGRICULTURAL) >= ag_limit:
				return 0.0
			return max(0.2, GameState.industrial_demand)
	return 0.0


func _count_developed_zones(zone_type: int) -> int:
	var count: int = 0
	for cell in zones:
		var zd = zones[cell]
		if zd.type == zone_type and zd.developed:
			count += 1
	return count


func _calculate_growth_rate(cell: Vector2i, _zone_data: ZoneData, demand: float) -> float:
	var rate = 5.0 * (1.0 + demand)

	# Land value bonus
	if land_value_system:
		var land_value = land_value_system.get_land_value_at(cell)
		rate *= (0.5 + land_value)

	# Service coverage bonus
	if service_coverage:
		if service_coverage.has_fire_coverage(cell):
			rate *= 1.1
		if service_coverage.has_police_coverage(cell):
			rate *= 1.1
		if service_coverage.has_education_coverage(cell):
			rate *= 1.15

	# Happiness bonus
	rate *= GameState.happiness

	return rate


func _spawn_building(cell: Vector2i, zone_data: ZoneData) -> void:
	# Determine building ID based on zone type
	var building_id = _get_building_for_zone(zone_data.type, 1)

	# Place the building
	var building_data = grid_system.get_building_data(building_id)
	if not building_data:
		return

	# Check that all cells the building would occupy are zoned the same type
	for x in range(building_data.size.x):
		for y in range(building_data.size.y):
			var check_cell = cell + Vector2i(x, y)
			if get_zone_at(check_cell) != zone_data.type:
				return

	# Temporarily make it free
	var original_cost = building_data.build_cost
	building_data.build_cost = 0
	var placed = grid_system.place_building(cell, building_data)
	building_data.build_cost = original_cost

	if not placed:
		return

	zone_data.developed = true
	zone_data.development_level = 1
	zone_data.development_progress = 0.0
	zone_data.building_id = building_id

	building_spawned.emit(cell, building_id)

	# Update zone counts
	_update_zone_counts(zone_data.type, 1)


func _upgrade_building(cell: Vector2i, zone_data: ZoneData) -> void:
	zone_data.development_level += 1
	zone_data.development_progress = 0.0

	# Get upgraded building
	var new_building_id = _get_building_for_zone(zone_data.type, zone_data.development_level)

	# Remove old building and place new one
	if grid_system.has_building_at(cell):
		# Store old data (for potential future use)
		var _old_building = grid_system.get_building_at(cell)
		grid_system.remove_building(cell)

		# Place upgraded building
		var building_data = grid_system.get_building_data(new_building_id)
		if building_data:
			var original_cost = building_data.build_cost
			building_data.build_cost = 0
			grid_system.place_building(cell, building_data)
			building_data.build_cost = original_cost

	zone_data.building_id = new_building_id
	building_upgraded.emit(cell, zone_data.development_level)


func _get_building_for_zone(zone_type: int, _level: int) -> String:
	match zone_type:
		ZoneType.RESIDENTIAL_LOW:
			return "residential_low"
		ZoneType.RESIDENTIAL_MED:
			return "residential_zone"  # Medium density
		ZoneType.RESIDENTIAL_HIGH:
			return "residential_high"
		ZoneType.COMMERCIAL_LOW:
			return "commercial_low"
		ZoneType.COMMERCIAL_MED:
			return "commercial_zone"
		ZoneType.COMMERCIAL_HIGH:
			return "commercial_high"
		ZoneType.INDUSTRIAL_LOW:
			return "industrial_low"
		ZoneType.INDUSTRIAL_MED:
			return "industrial_zone"
		ZoneType.INDUSTRIAL_HIGH:
			return "industrial_high"
		ZoneType.AGRICULTURAL:
			return "farm"
	return "residential_zone"


func _update_zone_counts(zone_type: int, delta: int) -> void:
	match zone_type:
		ZoneType.RESIDENTIAL_LOW, ZoneType.RESIDENTIAL_MED, ZoneType.RESIDENTIAL_HIGH:
			GameState.residential_zones += delta
		ZoneType.COMMERCIAL_LOW, ZoneType.COMMERCIAL_MED, ZoneType.COMMERCIAL_HIGH:
			GameState.commercial_zones += delta
		ZoneType.INDUSTRIAL_LOW, ZoneType.INDUSTRIAL_MED, ZoneType.INDUSTRIAL_HIGH, ZoneType.AGRICULTURAL:
			GameState.industrial_zones += delta


func get_zone_name(zone_type: int) -> String:
	match zone_type:
		ZoneType.RESIDENTIAL_LOW: return "Residential (Low)"
		ZoneType.RESIDENTIAL_MED: return "Residential (Med)"
		ZoneType.RESIDENTIAL_HIGH: return "Residential (High)"
		ZoneType.COMMERCIAL_LOW: return "Commercial (Low)"
		ZoneType.COMMERCIAL_MED: return "Commercial (Med)"
		ZoneType.COMMERCIAL_HIGH: return "Commercial (High)"
		ZoneType.INDUSTRIAL_LOW: return "Industrial (Low)"
		ZoneType.INDUSTRIAL_MED: return "Industrial (Med)"
		ZoneType.INDUSTRIAL_HIGH: return "Industrial (High)"
		ZoneType.AGRICULTURAL: return "Agricultural"
	return "None"


func get_zone_at(cell: Vector2i) -> int:
	if zones.has(cell):
		return zones[cell].type
	return ZoneType.NONE


func get_zone_color(zone_type: int) -> Color:
	return ZONE_COLORS.get(zone_type, Color(0, 0, 0, 0))


func get_all_zones() -> Dictionary:
	return zones


func _on_building_removed(cell: Vector2i, _building: Node2D) -> void:
	# When a zone building is demolished (not de-zoned), decrement zone count
	# Note: If zone was cleared via set_zone(NONE), the zone won't exist here
	# and the count was already decremented in set_zone
	if not zones.has(cell):
		return

	var zone_data = zones[cell]
	if zone_data.developed:
		_update_zone_counts(zone_data.type, -1)
		zone_data.developed = false
		zone_data.development_level = 0
		zone_data.development_progress = 0.0
		zone_data.building_id = ""


func get_total_zone_capacity() -> Dictionary:
	var total = {"population": 0, "jobs": 0}

	for cell in zones:
		var zone_data = zones[cell]
		if zone_data.developed:
			var capacity = ZONE_CAPACITY.get(zone_data.type, {})
			total.population += capacity.get("pop", 0) * zone_data.development_level
			total.jobs += capacity.get("jobs", 0) * zone_data.development_level

	return total


# ============================================
# ZONING COMPATIBILITY SYSTEM
# ============================================

func get_building_zone_type(building_type: String) -> String:
	# Map building types to zone categories for compatibility checking
	match building_type:
		"residential", "residential_low", "residential_high":
			return "residential"
		"commercial", "commercial_low", "commercial_high":
			return "commercial"
		"industrial", "industrial_low", "industrial_high":
			return "industrial"
		"heavy_industrial":
			return "heavy_industrial"
		"mixed_use":
			return "mixed_use"
		"park", "small_park", "large_park":
			return "park"
		"data_center", "data_center_tier1", "data_center_tier2", "data_center_tier3":
			return "data_center"
		_:
			return ""  # Non-zone buildings


func get_compatibility(zone_a: String, zone_b: String) -> float:
	if zone_a == "" or zone_b == "":
		return 1.0  # Non-zones are always compatible

	if COMPATIBILITY.has(zone_a) and COMPATIBILITY[zone_a].has(zone_b):
		return COMPATIBILITY[zone_a][zone_b]

	return 1.0  # Default to compatible


func get_adjacency_compatibility(cell: Vector2i) -> float:
	# Returns the worst compatibility score for a cell based on adjacent zones
	if not grid_system:
		return 1.0

	var building = grid_system.get_building_at(cell)
	if not building or not building.building_data:
		return 1.0

	var zone_type = get_building_zone_type(building.building_data.building_type)
	if zone_type == "":
		return 1.0

	var worst_compatibility = 1.0
	var neighbors = _get_neighbor_cells(cell, building.building_data.size)

	for neighbor in neighbors:
		var neighbor_building = grid_system.get_building_at(neighbor)
		if neighbor_building and neighbor_building.building_data:
			var neighbor_zone = get_building_zone_type(neighbor_building.building_data.building_type)
			var compat = get_compatibility(zone_type, neighbor_zone)
			worst_compatibility = min(worst_compatibility, compat)

	return worst_compatibility


func _get_neighbor_cells(cell: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var adjacent: Array[Vector2i] = []

	# Get all cells around the building perimeter
	for x in range(-1, size.x + 1):
		for y in range(-1, size.y + 1):
			# Skip interior cells
			if x >= 0 and x < size.x and y >= 0 and y < size.y:
				continue
			adjacent.append(cell + Vector2i(x, y))

	return adjacent


func has_buffer_violation(cell: Vector2i) -> bool:
	# Check if a zone violates buffer requirements
	if not grid_system:
		return false

	var building = grid_system.get_building_at(cell)
	if not building or not building.building_data:
		return false

	var zone_type = get_building_zone_type(building.building_data.building_type)
	if zone_type == "":
		return false

	# Check for each buffer requirement
	for buffer_key in BUFFER_REQUIREMENTS:
		var parts = buffer_key.split("_")
		if parts.size() < 2:
			continue

		var zone_a = parts[0]
		var zone_b = parts[1]
		if parts.size() > 2:
			zone_b = parts[1] + "_" + parts[2]

		var required_buffer = BUFFER_REQUIREMENTS[buffer_key]

		# Check if this zone is one of the incompatible types
		if zone_type == zone_a or zone_type == zone_b:
			var target_zone = zone_b if zone_type == zone_a else zone_a

			# Check all cells within buffer distance
			for x in range(-required_buffer, required_buffer + 1):
				for y in range(-required_buffer, required_buffer + 1):
					var check_cell = cell + Vector2i(x, y)
					var check_building = grid_system.get_building_at(check_cell)
					if check_building and check_building.building_data:
						var check_zone = get_building_zone_type(check_building.building_data.building_type)
						if check_zone == target_zone:
							return true

	return false


func get_incompatibility_happiness_penalty() -> float:
	# Calculate total happiness penalty from incompatible zones
	if not grid_system:
		return 0.0

	var total_penalty = 0.0
	var counted = {}

	# Get penalty value from GameConfig
	var base_penalty = _get_incompatibility_penalty()

	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data:
			continue

		var zone_type = get_building_zone_type(building.building_data.building_type)
		if zone_type == "residential" or zone_type == "mixed_use":
			var compat = get_adjacency_compatibility(building.grid_cell)
			if compat < 0.5:
				# Severe incompatibility
				total_penalty += base_penalty * 2
			elif compat < 0.8:
				# Moderate incompatibility
				total_penalty += base_penalty

	return min(0.15, total_penalty)  # Cap at 15% penalty


func get_development_compatibility_modifier(cell: Vector2i) -> float:
	# Returns a multiplier for zone development based on compatibility
	var compat = get_adjacency_compatibility(cell)

	if compat >= 0.8:
		return 1.0  # Full development speed
	elif compat >= 0.5:
		return 0.7  # Moderate slowdown
	elif compat >= 0.3:
		return 0.4  # Significant slowdown
	else:
		return 0.1  # Nearly stopped development


func is_commercial_buffer(cell: Vector2i) -> bool:
	# Check if this commercial zone is acting as a buffer between residential and industrial
	if not grid_system:
		return false

	var building = grid_system.get_building_at(cell)
	if not building or not building.building_data:
		return false

	if get_building_zone_type(building.building_data.building_type) != "commercial":
		return false

	var has_residential_neighbor = false
	var has_industrial_neighbor = false

	var neighbors = _get_neighbor_cells(cell, building.building_data.size)
	for neighbor in neighbors:
		var neighbor_building = grid_system.get_building_at(neighbor)
		if neighbor_building and neighbor_building.building_data:
			var zone = get_building_zone_type(neighbor_building.building_data.building_type)
			if zone == "residential":
				has_residential_neighbor = true
			elif zone == "industrial" or zone == "heavy_industrial":
				has_industrial_neighbor = true

	return has_residential_neighbor and has_industrial_neighbor


func get_buffer_bonus(cell: Vector2i) -> float:
	# Commercial zones acting as buffers get a land value bonus
	if is_commercial_buffer(cell):
		return 0.1  # 10% land value bonus
	return 0.0
