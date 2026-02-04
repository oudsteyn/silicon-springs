extends Node
class_name CommuteSystem
## Tracks commute quality, jobs-housing balance, and walkability

var grid_system = null
var traffic_system = null

# Commute metrics
var average_commute_distance: float = 0.0
var commute_mode_split: Dictionary = {
	"car": 0.0,
	"transit": 0.0,
	"walk": 0.0
}
var jobs_housing_balance: Dictionary = {}  # {region: balance_ratio}
var walkability_scores: Dictionary = {}  # {Vector2i: score}

# Walkability parameters
const WALKABLE_DISTANCE: int = 5  # Tiles considered walkable
const TRANSIT_WALK_DISTANCE: int = 3  # Walking distance to transit

# Jobs-housing balance target
const IDEAL_JOBS_HOUSING_RATIO: float = 1.0  # 1 job per resident


func _ready() -> void:
	Events.building_placed.connect(_on_building_changed)
	Events.building_removed.connect(_on_building_changed)


func set_grid_system(system) -> void:
	grid_system = system


func set_traffic_system(traffic) -> void:
	traffic_system = traffic


func _on_building_changed(_cell: Vector2i, _building: Node2D) -> void:
	# Recalculate on next monthly tick
	pass


func update_monthly() -> void:
	_calculate_commute_distances()
	_calculate_mode_split()
	_calculate_jobs_housing_balance()
	_calculate_walkability()


func _calculate_commute_distances() -> void:
	if not grid_system:
		average_commute_distance = 0.0
		return

	var residential_cells: Array[Vector2i] = []
	var job_cells: Array[Vector2i] = []
	var counted = {}

	# Collect residential and job locations
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data or not building.is_operational:
			continue

		if building.building_data.building_type in ["residential", "mixed_use"]:
			residential_cells.append(cell)

		if building.building_data.jobs_provided > 0:
			job_cells.append(cell)

	if residential_cells.size() == 0 or job_cells.size() == 0:
		average_commute_distance = 0.0
		return

	# Calculate average distance from residential to nearest job
	var total_distance = 0.0
	for res_cell in residential_cells:
		var min_distance = 999.0
		for job_cell in job_cells:
			var dx = res_cell.x - job_cell.x
			var dy = res_cell.y - job_cell.y
			var distance = sqrt(dx * dx + dy * dy)
			min_distance = min(min_distance, distance)
		total_distance += min_distance

	average_commute_distance = total_distance / residential_cells.size()


func _calculate_mode_split() -> void:
	if not grid_system or not traffic_system:
		commute_mode_split = {"car": 1.0, "transit": 0.0, "walk": 0.0}
		return

	var walk_count = 0
	var transit_count = 0
	var car_count = 0
	var counted = {}

	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data:
			continue

		if building.building_data.building_type in ["residential", "mixed_use"]:
			var walkability = get_walkability_at(cell)
			var transit_access = traffic_system.get_transit_coverage_at(cell)

			if walkability > 0.6:
				# High walkability = walking commute
				walk_count += 1
			elif transit_access > 0.3:
				# Good transit = transit commute
				transit_count += 1
			else:
				# Default to car
				car_count += 1

	var total = walk_count + transit_count + car_count
	if total > 0:
		commute_mode_split["walk"] = float(walk_count) / total
		commute_mode_split["transit"] = float(transit_count) / total
		commute_mode_split["car"] = float(car_count) / total
	else:
		commute_mode_split = {"car": 1.0, "transit": 0.0, "walk": 0.0}


func _calculate_jobs_housing_balance() -> void:
	jobs_housing_balance.clear()

	if not grid_system:
		return

	# Divide city into quadrants for balance analysis
	var quadrants = {
		"NW": {"jobs": 0, "housing": 0, "center": Vector2i(25, 25)},
		"NE": {"jobs": 0, "housing": 0, "center": Vector2i(75, 25)},
		"SW": {"jobs": 0, "housing": 0, "center": Vector2i(25, 75)},
		"SE": {"jobs": 0, "housing": 0, "center": Vector2i(75, 75)}
	}

	var counted = {}
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data or not building.is_operational:
			continue

		# Determine quadrant
		var quadrant = ""
		if cell.x < 50:
			quadrant = "NW" if cell.y < 50 else "SW"
		else:
			quadrant = "NE" if cell.y < 50 else "SE"

		# Count jobs and housing
		if building.building_data.jobs_provided > 0:
			var jobs = building.get_effective_jobs() if building.has_method("get_effective_jobs") else building.building_data.jobs_provided
			quadrants[quadrant]["jobs"] += jobs

		if building.building_data.population_capacity > 0:
			var pop = building.get_effective_capacity() if building.has_method("get_effective_capacity") else building.building_data.population_capacity
			quadrants[quadrant]["housing"] += pop

	# Calculate balance for each quadrant
	for quadrant in quadrants:
		var jobs = quadrants[quadrant]["jobs"]
		var housing = quadrants[quadrant]["housing"]
		if housing > 0:
			jobs_housing_balance[quadrant] = float(jobs) / float(housing)
		else:
			jobs_housing_balance[quadrant] = 0.0


func _calculate_walkability() -> void:
	walkability_scores.clear()

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

		# Calculate walkability for zones
		if building.building_data.category == "zone":
			walkability_scores[cell] = _calculate_cell_walkability(cell)


func _calculate_cell_walkability(cell: Vector2i) -> float:
	if not grid_system:
		return 0.0

	var score = 0.0
	var nearby_amenities = 0
	var nearby_jobs = 0
	var nearby_shops = 0

	# Check for nearby amenities within walking distance
	for x in range(-WALKABLE_DISTANCE, WALKABLE_DISTANCE + 1):
		for y in range(-WALKABLE_DISTANCE, WALKABLE_DISTANCE + 1):
			var distance = sqrt(x * x + y * y)
			if distance > WALKABLE_DISTANCE:
				continue

			var check_cell = cell + Vector2i(x, y)
			if not grid_system.has_building_at(check_cell):
				continue

			var building = grid_system.get_building_at(check_cell)
			if not is_instance_valid(building) or not building.building_data:
				continue

			var data = building.building_data

			# Parks and amenities
			if data.service_type in ["recreation", "park"] or data.happiness_modifier > 0:
				nearby_amenities += 1

			# Jobs (commercial/industrial within walking distance)
			if data.building_type in ["commercial", "mixed_use"] and data.jobs_provided > 0:
				nearby_jobs += data.jobs_provided

			# Shops (commercial)
			if data.building_type == "commercial":
				nearby_shops += 1

	# Calculate walkability score (0-1)
	# Based on: amenities, jobs, shops accessibility
	score += min(0.3, nearby_amenities * 0.1)  # Up to 0.3 for amenities
	score += min(0.4, nearby_jobs / 20.0 * 0.4)  # Up to 0.4 for jobs
	score += min(0.3, nearby_shops * 0.1)  # Up to 0.3 for shops

	return min(1.0, score)


func get_walkability_at(cell: Vector2i) -> float:
	if walkability_scores.has(cell):
		return walkability_scores[cell]
	return _calculate_cell_walkability(cell)


func get_average_walkability() -> float:
	if walkability_scores.size() == 0:
		return 0.0

	var total = 0.0
	for cell in walkability_scores:
		total += walkability_scores[cell]
	return total / walkability_scores.size()


func get_commute_quality_score() -> float:
	# Overall commute quality (0-1, higher = better)
	var score = 0.0

	# Short commutes are good
	if average_commute_distance < 5:
		score += 0.3
	elif average_commute_distance < 10:
		score += 0.2
	elif average_commute_distance < 20:
		score += 0.1

	# Low car dependence is good
	var car_ratio = commute_mode_split.get("car", 1.0)
	score += (1.0 - car_ratio) * 0.4

	# Good walkability is good
	score += get_average_walkability() * 0.3

	return min(1.0, score)


func get_jobs_housing_imbalance() -> float:
	# Returns how imbalanced the city is (0 = balanced, 1 = severely imbalanced)
	if jobs_housing_balance.size() == 0:
		return 0.0

	var total_deviation = 0.0
	for quadrant in jobs_housing_balance:
		var ratio = jobs_housing_balance[quadrant]
		var deviation = abs(ratio - IDEAL_JOBS_HOUSING_RATIO)
		total_deviation += deviation

	return min(1.0, total_deviation / jobs_housing_balance.size())


func get_commute_happiness_modifier() -> float:
	var quality = get_commute_quality_score()

	if quality > 0.7:
		return 0.05  # Good commutes = happy residents
	elif quality > 0.4:
		return 0.0   # Average
	elif quality > 0.2:
		return -0.03  # Poor commutes
	else:
		return -0.08  # Terrible commutes


func get_mode_split() -> Dictionary:
	return commute_mode_split.duplicate()


func get_average_commute_distance() -> float:
	return average_commute_distance


func get_walkable_zone_count() -> int:
	var count = 0
	for cell in walkability_scores:
		if walkability_scores[cell] > 0.5:
			count += 1
	return count
