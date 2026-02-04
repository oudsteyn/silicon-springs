extends Node
class_name ServiceCoverage
## Manages service coverage areas (fire, police, education)
## Uses spatial hashing and pre-computed coverage masks for O(1) lookups

var grid_system = null  # GridSystem

# Spatial index for service buildings
var _service_spatial: SpatialHash = SpatialHash.new()

# Service buildings by type
var fire_stations: Array[Node2D] = []
var police_stations: Array[Node2D] = []
var schools: Array[Node2D] = []

# Coverage maps: {Vector2i: coverage_strength}
var fire_coverage: Dictionary = {}
var police_coverage: Dictionary = {}
var education_coverage: Dictionary = {}

# Cache for expensive calculations
var _coverage_cache_valid: bool = false
var _average_coverage_cache: float = 0.5


func _ready() -> void:
	# Initialize coverage masks for all service radii up to max used by buildings
	SpatialHash.initialize_coverage_masks(GridConstants.MAX_COVERAGE_RADIUS)

	Events.building_placed.connect(_on_building_placed)
	Events.building_removed.connect(_on_building_removed)


func set_grid_system(system) -> void:
	grid_system = system


func _on_building_placed(_cell: Vector2i, building: Node2D) -> void:
	if not building.building_data:
		return

	var data = building.building_data

	match data.service_type:
		"fire":
			fire_stations.append(building)
			_service_spatial.insert(building.get_instance_id(), building.grid_cell, {
				"type": "fire",
				"building": building,
				"radius": data.coverage_radius
			})
			_update_fire_coverage()
		"police":
			police_stations.append(building)
			_service_spatial.insert(building.get_instance_id(), building.grid_cell, {
				"type": "police",
				"building": building,
				"radius": data.coverage_radius
			})
			_update_police_coverage()
		"education":
			schools.append(building)
			_service_spatial.insert(building.get_instance_id(), building.grid_cell, {
				"type": "education",
				"building": building,
				"radius": data.coverage_radius
			})
			_update_education_coverage()

	_coverage_cache_valid = false


func _on_building_removed(_cell: Vector2i, building: Node2D) -> void:
	if not building or not building.building_data:
		return

	var data = building.building_data
	_service_spatial.remove(building.get_instance_id())

	match data.service_type:
		"fire":
			fire_stations.erase(building)
			_update_fire_coverage()
		"police":
			police_stations.erase(building)
			_update_police_coverage()
		"education":
			schools.erase(building)
			_update_education_coverage()

	_coverage_cache_valid = false


func update_all_coverage() -> void:
	_update_fire_coverage()
	_update_police_coverage()
	_update_education_coverage()
	_coverage_cache_valid = false


func _update_fire_coverage() -> void:
	fire_coverage.clear()
	for station in fire_stations:
		if is_instance_valid(station) and station.is_operational:
			_add_coverage_radius_optimized(fire_coverage, station.grid_cell, station.building_data.coverage_radius)
	Events.coverage_updated.emit("fire")


func _update_police_coverage() -> void:
	police_coverage.clear()
	for station in police_stations:
		if is_instance_valid(station) and station.is_operational:
			_add_coverage_radius_optimized(police_coverage, station.grid_cell, station.building_data.coverage_radius)
	Events.coverage_updated.emit("police")


func _update_education_coverage() -> void:
	education_coverage.clear()
	for school in schools:
		if is_instance_valid(school) and school.is_operational:
			_add_coverage_radius_optimized(education_coverage, school.grid_cell, school.building_data.coverage_radius)
	Events.coverage_updated.emit("education")


## Optimized coverage calculation using pre-computed masks
func _add_coverage_radius_optimized(coverage_map: Dictionary, center: Vector2i, radius: int) -> void:
	var mask = SpatialHash.get_coverage_mask_with_strength(radius)

	for entry in mask:
		var cell = center + entry.offset
		var strength = entry.strength

		# Take maximum coverage if multiple sources
		if coverage_map.has(cell):
			coverage_map[cell] = max(coverage_map[cell], strength)
		else:
			coverage_map[cell] = strength


## Legacy method for backwards compatibility
func _add_coverage_radius(coverage_map: Dictionary, center: Vector2i, radius: int) -> void:
	_add_coverage_radius_optimized(coverage_map, center, radius)


func has_fire_coverage(cell: Vector2i) -> bool:
	return fire_coverage.has(cell)


func has_police_coverage(cell: Vector2i) -> bool:
	return police_coverage.has(cell)


func has_education_coverage(cell: Vector2i) -> bool:
	return education_coverage.has(cell)


func get_fire_coverage_strength(cell: Vector2i) -> float:
	return fire_coverage.get(cell, 0.0)


func get_police_coverage_strength(cell: Vector2i) -> float:
	return police_coverage.get(cell, 0.0)


func get_education_coverage_strength(cell: Vector2i) -> float:
	return education_coverage.get(cell, 0.0)


func get_average_coverage() -> float:
	if _coverage_cache_valid:
		return _average_coverage_cache

	if not grid_system:
		return 0.5

	# Calculate average coverage across all occupied cells
	var total_coverage = 0.0
	var cell_count = 0

	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building):
			continue

		# Only count zones and data centers
		var data = building.building_data
		if data and data.category in ["zone", "data_center"]:
			var fire = 1.0 if has_fire_coverage(cell) else 0.0
			var police = 1.0 if has_police_coverage(cell) else 0.0
			total_coverage += (fire + police) / 2.0
			cell_count += 1

	if cell_count == 0:
		_average_coverage_cache = 0.5
	else:
		_average_coverage_cache = total_coverage / cell_count

	_coverage_cache_valid = true
	return _average_coverage_cache


func get_educated_population_estimate() -> int:
	if not grid_system:
		return 0

	# Estimate educated population based on school coverage of residential zones
	var covered_residential = 0
	var total_residential = 0

	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building):
			continue

		var data = building.building_data
		if data and data.building_type == "residential":
			total_residential += 1
			if has_education_coverage(cell):
				covered_residential += 1

	if total_residential == 0:
		return 0

	var coverage_ratio = float(covered_residential) / float(total_residential)
	return int(GameState.population * coverage_ratio)


func get_coverage_at_cell(cell: Vector2i) -> Dictionary:
	return {
		"fire": has_fire_coverage(cell),
		"police": has_police_coverage(cell),
		"education": has_education_coverage(cell),
		"fire_strength": get_fire_coverage_strength(cell),
		"police_strength": get_police_coverage_strength(cell),
		"education_strength": get_education_coverage_strength(cell)
	}


func get_cells_without_fire_coverage() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not grid_system:
		return result

	for cell in grid_system.get_building_cells():
		if not has_fire_coverage(cell):
			result.append(cell)
	return result


func get_cells_without_police_coverage() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not grid_system:
		return result

	for cell in grid_system.get_building_cells():
		if not has_police_coverage(cell):
			result.append(cell)
	return result


## Find nearest service building of a given type to a cell
func find_nearest_service(cell: Vector2i, service_type: String, max_radius: int = 50) -> Dictionary:
	var stations: Array[Node2D]
	match service_type:
		"fire": stations = fire_stations
		"police": stations = police_stations
		"education": stations = schools
		_: return {"found": false}

	var nearest: Node2D = null
	var nearest_dist_sq: int = max_radius * max_radius

	for station in stations:
		if not is_instance_valid(station) or not station.is_operational:
			continue
		var delta = station.grid_cell - cell
		var dist_sq = delta.x * delta.x + delta.y * delta.y
		if dist_sq < nearest_dist_sq:
			nearest_dist_sq = dist_sq
			nearest = station

	if nearest:
		return {
			"found": true,
			"building": nearest,
			"distance": sqrt(nearest_dist_sq)
		}
	return {"found": false}
