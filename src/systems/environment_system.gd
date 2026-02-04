extends Node
class_name EnvironmentSystem
## Manages environmental sustainability features

var grid_system = null
var pollution_system = null

# Urban heat island effect
var heat_island_map: Dictionary = {}  # {Vector2i: temperature_modifier}

# Tree coverage
var tree_coverage_map: Dictionary = {}  # {Vector2i: tree_count}

# Watershed protection zones
var watershed_zones: Dictionary = {}  # {Vector2i: true}

# Green building tracking
var green_buildings: Array[Node2D] = []

# Constants
const HEAT_ISLAND_BASE: float = 0.0
const HEAT_ISLAND_INDUSTRIAL: float = 0.3
const HEAT_ISLAND_COMMERCIAL: float = 0.2
const HEAT_ISLAND_RESIDENTIAL: float = 0.1
const TREE_COOLING_FACTOR: float = 0.05  # Each tree reduces heat by 5%
const PARK_COOLING_RADIUS: int = 5


func _ready() -> void:
	Events.building_placed.connect(_on_building_changed)
	Events.building_removed.connect(_on_building_changed)


func set_grid_system(system) -> void:
	grid_system = system


func set_pollution_system(pollution) -> void:
	pollution_system = pollution


func _on_building_changed(_cell: Vector2i, building: Node2D) -> void:
	# Track green buildings
	if building and building.building_data:
		if building.building_data.get("is_green_building"):
			if not green_buildings.has(building):
				green_buildings.append(building)

	# Clean up invalid buildings
	green_buildings = green_buildings.filter(func(b): return is_instance_valid(b))

	_update_environmental_maps()


func _update_environmental_maps() -> void:
	_update_heat_island()
	_update_tree_coverage()


func _update_heat_island() -> void:
	heat_island_map.clear()

	if not grid_system:
		return

	var counted = {}
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data:
			continue

		var heat = HEAT_ISLAND_BASE

		# Building type contributes to heat
		match building.building_data.building_type:
			"industrial", "heavy_industrial":
				heat += HEAT_ISLAND_INDUSTRIAL
			"commercial":
				heat += HEAT_ISLAND_COMMERCIAL
			"residential", "mixed_use":
				heat += HEAT_ISLAND_RESIDENTIAL

		# Larger buildings = more heat
		var size = building.building_data.size.x * building.building_data.size.y
		heat *= (1.0 + size * 0.1)

		# Green buildings reduce heat
		if building.building_data.get("is_green_building"):
			heat *= 0.5

		# Apply heat to cell and nearby
		_add_heat_to_area(building.grid_cell, building.building_data.size, heat)


func _add_heat_to_area(origin: Vector2i, size: Vector2i, heat: float) -> void:
	for x in range(size.x):
		for y in range(size.y):
			var cell = origin + Vector2i(x, y)
			if heat_island_map.has(cell):
				heat_island_map[cell] = max(heat_island_map[cell], heat)
			else:
				heat_island_map[cell] = heat


func _update_tree_coverage() -> void:
	tree_coverage_map.clear()

	if not grid_system:
		return

	var counted = {}
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data:
			continue

		# Parks and buildings with trees
		var trees = building.building_data.get("tree_coverage")
		if trees and trees > 0:
			_add_tree_cooling(building.grid_cell, trees, building.building_data.size)


func _add_tree_cooling(origin: Vector2i, trees: int, size: Vector2i) -> void:
	var cooling_radius = PARK_COOLING_RADIUS

	for x in range(-cooling_radius, size.x + cooling_radius):
		for y in range(-cooling_radius, size.y + cooling_radius):
			var cell = origin + Vector2i(x, y)

			# Calculate distance to park edge
			var dist_x = 0
			var dist_y = 0
			if x < 0:
				dist_x = -x
			elif x >= size.x:
				dist_x = x - size.x + 1
			if y < 0:
				dist_y = -y
			elif y >= size.y:
				dist_y = y - size.y + 1

			var distance = sqrt(dist_x * dist_x + dist_y * dist_y)
			if distance <= cooling_radius:
				var tree_effect = trees * (1.0 - distance / cooling_radius)
				if tree_coverage_map.has(cell):
					tree_coverage_map[cell] += tree_effect
				else:
					tree_coverage_map[cell] = tree_effect


func get_heat_at(cell: Vector2i) -> float:
	var base_heat = heat_island_map.get(cell, 0.0)

	# Trees reduce heat
	var trees = tree_coverage_map.get(cell, 0.0)
	var cooling = trees * TREE_COOLING_FACTOR

	return max(0.0, base_heat - cooling)


func get_average_heat() -> float:
	if heat_island_map.size() == 0:
		return 0.0

	var total = 0.0
	for cell in heat_island_map:
		total += get_heat_at(cell)
	return total / heat_island_map.size()


func get_city_temperature_modifier() -> float:
	# Returns how much hotter the city is due to urban heat island
	return get_average_heat()


func get_tree_coverage_ratio() -> float:
	# Ratio of cells with tree coverage
	if not grid_system:
		return 0.0

	var covered = tree_coverage_map.size()
	var total = grid_system.get_building_count()

	if total == 0:
		return 0.0

	return min(1.0, float(covered) / float(total))


func get_green_building_ratio() -> float:
	if not grid_system:
		return 0.0

	var total_buildings = 0
	var counted = {}
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if counted.has(building):
			continue
		counted[building] = true
		total_buildings += 1

	if total_buildings == 0:
		return 0.0

	return float(green_buildings.size()) / float(total_buildings)


func get_green_building_savings() -> Dictionary:
	# Calculate resource savings from green buildings
	var power_saved = 0.0
	var water_saved = 0.0

	for building in green_buildings:
		if not is_instance_valid(building) or not building.building_data:
			continue

		# Green buildings use 20% less resources
		power_saved += building.building_data.power_consumption * 0.2
		water_saved += building.building_data.water_consumption * 0.2

	return {
		"power": power_saved,
		"water": water_saved
	}


func designate_watershed(center: Vector2i, radius: int) -> int:
	# Designate watershed protection zone
	var cells_protected = 0

	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var distance = sqrt(x * x + y * y)
			if distance <= radius:
				var cell = center + Vector2i(x, y)
				if not watershed_zones.has(cell):
					watershed_zones[cell] = true
					cells_protected += 1

	return cells_protected


func is_watershed(cell: Vector2i) -> bool:
	return watershed_zones.has(cell)


func get_watershed_pollution_penalty(cell: Vector2i) -> float:
	# Development in watershed zones causes extra pollution
	if not watershed_zones.has(cell):
		return 0.0

	if not grid_system or not grid_system.has_building_at(cell):
		return 0.0

	var building = grid_system.get_building_at(cell)
	if not building or not building.building_data:
		return 0.0

	# Industrial in watershed is very bad
	if building.building_data.building_type in ["industrial", "heavy_industrial"]:
		return 0.5
	elif building.building_data.building_type == "commercial":
		return 0.2
	elif building.building_data.building_type == "residential":
		return 0.1

	return 0.0


func get_environmental_score() -> float:
	# Overall environmental health score (0-1)
	var score = 0.5  # Base score

	# Tree coverage bonus
	score += get_tree_coverage_ratio() * 0.2

	# Green building bonus
	score += get_green_building_ratio() * 0.2

	# Heat island penalty
	score -= get_city_temperature_modifier() * 0.3

	# Pollution penalty (if pollution system available)
	if pollution_system:
		var avg_pollution = pollution_system.get_average_pollution()
		score -= avg_pollution * 0.3

	return clamp(score, 0.0, 1.0)


func get_environmental_happiness_modifier() -> float:
	var score = get_environmental_score()

	if score > 0.7:
		return 0.05  # Good environment = happy residents
	elif score > 0.4:
		return 0.0
	elif score > 0.2:
		return -0.03
	else:
		return -0.08
