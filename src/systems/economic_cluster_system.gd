extends Node
class_name EconomicClusterSystem
## Detects and rewards economic clusters (synergistic building groupings)

var grid_system = null

# Cluster definitions: {cluster_name: {buildings: [], radius: int, min_count: int, bonus: {}}}
const CLUSTER_TYPES: Dictionary = {
	"tech_hub": {
		"required": ["data_center_tier1", "data_center_tier2", "data_center_tier3"],
		"boosters": ["university", "commercial"],
		"radius": 10,
		"min_required": 1,
		"min_boosters": 2,
		"bonus": {
			"jobs": 0.2,       # 20% more jobs
			"tax": 0.15,       # 15% more tax revenue
			"development": 0.25  # 25% faster development
		}
	},
	"industrial_park": {
		"required": ["industrial", "heavy_industrial"],
		"boosters": ["rail_station", "seaport"],
		"radius": 8,
		"min_required": 3,
		"min_boosters": 0,
		"bonus": {
			"jobs": 0.15,
			"pollution": -0.1,  # Shared infrastructure reduces pollution
			"maintenance": -0.1  # Shared maintenance
		}
	},
	"medical_district": {
		"required": ["hospital"],
		"boosters": ["university", "commercial", "bus_stop", "subway_station"],
		"radius": 12,
		"min_required": 1,
		"min_boosters": 2,
		"bonus": {
			"health_coverage": 0.3,  # 30% extended health coverage
			"jobs": 0.25,
			"land_value": 0.1
		}
	},
	"education_campus": {
		"required": ["school", "university"],
		"boosters": ["library", "park", "bus_stop"],
		"radius": 15,
		"min_required": 2,
		"min_boosters": 1,
		"bonus": {
			"education": 0.2,  # 20% more educated population
			"happiness": 0.05,
			"land_value": 0.1
		}
	},
	"entertainment_district": {
		"required": ["commercial"],
		"boosters": ["park", "stadium", "bus_stop", "subway_station"],
		"radius": 8,
		"min_required": 3,
		"min_boosters": 2,
		"bonus": {
			"happiness": 0.08,
			"tax": 0.2,
			"land_value": 0.15
		}
	},
	"transit_hub": {
		"required": ["subway_station", "rail_station", "bus_depot"],
		"boosters": ["commercial", "mixed_use"],
		"radius": 6,
		"min_required": 2,
		"min_boosters": 2,
		"bonus": {
			"traffic_reduction": 0.15,
			"land_value": 0.2,
			"development": 0.3
		}
	}
}

# Active clusters: {cluster_name: [center_cells]}
var active_clusters: Dictionary = {}

# Cluster bonuses by cell: {Vector2i: {bonus_type: value}}
var cell_bonuses: Dictionary = {}


func _ready() -> void:
	Events.building_placed.connect(_on_building_changed)
	Events.building_removed.connect(_on_building_changed)


func set_grid_system(system) -> void:
	grid_system = system


func _on_building_changed(_cell: Vector2i, _building: Node2D) -> void:
	_detect_clusters()


func _detect_clusters() -> void:
	active_clusters.clear()
	cell_bonuses.clear()

	if not grid_system:
		return

	# Check each cluster type
	for cluster_name in CLUSTER_TYPES:
		var cluster_def = CLUSTER_TYPES[cluster_name]
		var centers = _find_cluster_centers(cluster_def)
		if centers.size() > 0:
			active_clusters[cluster_name] = centers
			_apply_cluster_bonuses(cluster_name, centers, cluster_def)


func _find_cluster_centers(cluster_def: Dictionary) -> Array[Vector2i]:
	var centers: Array[Vector2i] = []
	var required_types = cluster_def["required"]
	var booster_types = cluster_def["boosters"]
	var radius = cluster_def["radius"]
	var min_required = cluster_def["min_required"]
	var min_boosters = cluster_def["min_boosters"]

	var counted = {}

	# Find potential cluster centers (buildings of required type)
	for cell in grid_system.buildings:
		var building = grid_system.buildings[cell]
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data:
			continue

		if building.building_data.building_type in required_types:
			# Check if this could be a cluster center
			var nearby_required = _count_nearby_types(cell, required_types, radius)
			var nearby_boosters = _count_nearby_types(cell, booster_types, radius)

			if nearby_required >= min_required and nearby_boosters >= min_boosters:
				centers.append(cell)

	return centers


func _count_nearby_types(center: Vector2i, types: Array, radius: int) -> int:
	var count = 0
	var counted = {}

	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var distance = sqrt(x * x + y * y)
			if distance > radius:
				continue

			var cell = center + Vector2i(x, y)
			if not grid_system.buildings.has(cell):
				continue

			var building = grid_system.buildings[cell]
			if not is_instance_valid(building) or counted.has(building):
				continue
			counted[building] = true

			if building.building_data and building.building_data.building_type in types:
				count += 1

	return count


func _apply_cluster_bonuses(_cluster_name: String, centers: Array[Vector2i], cluster_def: Dictionary) -> void:
	var radius = cluster_def["radius"]
	var bonus = cluster_def["bonus"]

	for center in centers:
		# Apply bonuses to all buildings in cluster radius
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var distance = sqrt(x * x + y * y)
				if distance > radius:
					continue

				var cell = center + Vector2i(x, y)
				# Bonus strength decreases with distance
				var strength = 1.0 - (distance / float(radius)) * 0.5

				if not cell_bonuses.has(cell):
					cell_bonuses[cell] = {}

				for bonus_type in bonus:
					var bonus_value = bonus[bonus_type] * strength
					if cell_bonuses[cell].has(bonus_type):
						# Take the max bonus if multiple clusters overlap
						cell_bonuses[cell][bonus_type] = max(cell_bonuses[cell][bonus_type], bonus_value)
					else:
						cell_bonuses[cell][bonus_type] = bonus_value


func get_cluster_bonus(cell: Vector2i, bonus_type: String) -> float:
	if cell_bonuses.has(cell) and cell_bonuses[cell].has(bonus_type):
		return cell_bonuses[cell][bonus_type]
	return 0.0


func get_job_bonus(cell: Vector2i) -> float:
	return get_cluster_bonus(cell, "jobs")


func get_tax_bonus(cell: Vector2i) -> float:
	return get_cluster_bonus(cell, "tax")


func get_development_bonus(cell: Vector2i) -> float:
	return get_cluster_bonus(cell, "development")


func get_land_value_bonus(cell: Vector2i) -> float:
	return get_cluster_bonus(cell, "land_value")


func get_happiness_bonus() -> float:
	# Total happiness bonus from all clusters
	var total = 0.0
	for cluster_name in active_clusters:
		if active_clusters[cluster_name].size() > 0:
			var cluster_def = CLUSTER_TYPES[cluster_name]
			if cluster_def["bonus"].has("happiness"):
				total += cluster_def["bonus"]["happiness"]
	return min(0.15, total)  # Cap at 15%


func get_active_cluster_names() -> Array:
	var names = []
	for cluster_name in active_clusters:
		if active_clusters[cluster_name].size() > 0:
			names.append(cluster_name)
	return names


func get_cluster_count() -> int:
	var count = 0
	for cluster_name in active_clusters:
		count += active_clusters[cluster_name].size()
	return count


func is_in_cluster(cell: Vector2i) -> bool:
	return cell_bonuses.has(cell) and cell_bonuses[cell].size() > 0
