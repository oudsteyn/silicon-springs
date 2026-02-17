extends Node
class_name ParkingSystem
## Manages parking requirements and their impact on development
##
## Tracks parking supply (from garages, lots, on-street) and demand (from jobs, residents).
## Transit reduces parking requirements (TOD principle).
## Parking shortages affect development speed and happiness.

signal parking_updated()

var grid_system = null
var traffic_system = null

# Parking requirements per job/resident (when not explicitly set in building data)
const PARKING_PER_COMMERCIAL_JOB: float = 0.33  # 1 space per 3 jobs
const PARKING_PER_INDUSTRIAL_JOB: float = 0.2   # 1 space per 5 jobs
const PARKING_PER_RESIDENT: float = 0.5         # 1 space per 2 residents

# Base parking provided per tile (for buildings without explicit parking)
const BASE_PARKING_PER_TILE: float = 5.0

# Transit reduction for parking requirements
const TRANSIT_PARKING_REDUCTIONS: Dictionary = {
	"subway_station": 0.40,   # 40% reduction
	"rail_station": 0.35,     # 35% reduction
	"bus_depot": 0.25,        # 25% reduction
	"bus_stop": 0.15,         # 15% reduction
}

# Parking search radius (how far people will walk)
const PARKING_SEARCH_RADIUS: int = 4

# Bucket size for area-based parking tracking
const PARKING_BUCKET_SIZE: int = 8

# Supply tracking: {Vector2i: spaces}
var parking_supply: Dictionary = {}

# Demand tracking: {Vector2i: spaces}
var parking_demand: Dictionary = {}

# Bucket-based totals for efficient area queries
var _parking_buckets: Dictionary = {}  # {bucket_key: {supply: int, demand: int}}

# Parking deficit tracking: {Vector2i: deficit_amount}
var parking_deficit: Dictionary = {}


func _ready() -> void:
	Events.building_placed.connect(_on_building_placed)
	Events.building_removed.connect(_on_building_removed)
	Events.month_tick.connect(_on_month_tick)


func _on_month_tick() -> void:
	_update_parking_requirements()
	parking_updated.emit()


func set_grid_system(system) -> void:
	grid_system = system


func set_traffic_system(traffic) -> void:
	traffic_system = traffic


func _on_building_placed(cell: Vector2i, building: Node2D) -> void:
	if not building or not building.building_data:
		return

	# Track parking supply from this building
	var supply = _get_building_parking_supply(building)
	if supply > 0:
		parking_supply[cell] = supply
		_update_bucket(cell, supply, 0)

	# Track parking demand from this building
	var demand = _calculate_parking_required(building)
	if demand > 0:
		parking_demand[cell] = demand
		_update_bucket(cell, 0, demand)

	_update_parking_requirements()


func _on_building_removed(cell: Vector2i, _building: Node2D) -> void:
	# Remove supply
	if parking_supply.has(cell):
		var supply = parking_supply[cell]
		_update_bucket(cell, -supply, 0)
		parking_supply.erase(cell)

	# Remove demand
	if parking_demand.has(cell):
		var demand = parking_demand[cell]
		_update_bucket(cell, 0, -demand)
		parking_demand.erase(cell)

	_update_parking_requirements()


func _on_building_changed(_cell: Vector2i, _building: Node2D) -> void:
	# Legacy handler - redirect to specific handlers
	pass


func _update_parking_requirements() -> void:
	parking_deficit.clear()

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

		var required = _calculate_parking_required(building)
		var provided = _calculate_parking_provided(building)

		if required > provided:
			parking_deficit[building.grid_cell] = required - provided


func _calculate_parking_required(building: Node2D) -> float:
	var data = building.building_data

	# Use building's explicit parking requirement if specified
	if data.parking_spaces_required > 0:
		var base_required = float(data.parking_spaces_required)
		# Still apply transit reduction
		var explicit_transit_reduction = _get_transit_parking_reduction(building.grid_cell)
		return base_required * (1.0 - explicit_transit_reduction)

	var required = 0.0

	# Calculate base requirement from jobs/population
	match data.building_type:
		"commercial":
			var jobs = building.get_effective_jobs() if building.has_method("get_effective_jobs") else data.jobs_provided
			required = jobs * PARKING_PER_COMMERCIAL_JOB
		"industrial", "heavy_industrial":
			var jobs = building.get_effective_jobs() if building.has_method("get_effective_jobs") else data.jobs_provided
			required = jobs * PARKING_PER_INDUSTRIAL_JOB
		"residential":
			var pop = building.get_effective_capacity() if building.has_method("get_effective_capacity") else data.population_capacity
			required = pop * PARKING_PER_RESIDENT
		"mixed_use":
			var jobs = building.get_effective_jobs() if building.has_method("get_effective_jobs") else data.jobs_provided
			var pop = building.get_effective_capacity() if building.has_method("get_effective_capacity") else data.population_capacity
			required = (jobs * PARKING_PER_COMMERCIAL_JOB) + (pop * PARKING_PER_RESIDENT * 0.5)

	# Apply transit-oriented development reduction
	var transit_reduction = _get_transit_parking_reduction(building.grid_cell)
	required *= (1.0 - transit_reduction)

	return required


## Get transit-based parking reduction at a cell (0.0 to 0.5)
func _get_transit_parking_reduction(cell: Vector2i) -> float:
	if not grid_system:
		return 0.0

	var max_reduction: float = 0.0

	for transit_type in TRANSIT_PARKING_REDUCTIONS:
		var reduction_factor = TRANSIT_PARKING_REDUCTIONS[transit_type]
		var stations = grid_system.get_buildings_of_type(transit_type)

		for station in stations:
			if not is_instance_valid(station):
				continue
			var distance = GridConstants.manhattan_distance(cell, station.grid_cell)
			var coverage_radius = station.building_data.coverage_radius if station.building_data.coverage_radius > 0 else 10

			if distance <= coverage_radius:
				# Reduction decreases with distance from station
				var distance_factor = 1.0 - (float(distance) / float(coverage_radius))
				var effective_reduction = reduction_factor * distance_factor
				max_reduction = maxf(max_reduction, effective_reduction)

	return minf(max_reduction, 0.5)  # Cap at 50% reduction


## Get parking supply from a building (explicit or estimated)
func _get_building_parking_supply(building: Node2D) -> int:
	var data = building.building_data

	# Use explicit parking_spaces_provided if set
	if data.parking_spaces_provided > 0:
		return data.parking_spaces_provided

	# Estimate based on building type and size
	var tiles = data.size.x * data.size.y

	# Parking structures provide significant supply
	if data.building_type in ["parking_garage", "parking_lot"]:
		return tiles * 50  # 50 spaces per tile for dedicated parking

	# Regular buildings provide minimal on-site parking
	if data.category == "zone":
		return int(tiles * BASE_PARKING_PER_TILE * 0.5)

	# Infrastructure provides no parking
	if data.category == "infrastructure":
		return 0

	return int(tiles * BASE_PARKING_PER_TILE)


func _calculate_parking_provided(building: Node2D) -> float:
	return float(_get_building_parking_supply(building))


## Get bucket key for a cell
func _get_bucket_key(cell: Vector2i) -> Vector2i:
	return Vector2i(
		int(floor(float(cell.x) / PARKING_BUCKET_SIZE)),
		int(floor(float(cell.y) / PARKING_BUCKET_SIZE))
	)


## Update parking bucket totals
func _update_bucket(cell: Vector2i, supply_delta: int, demand_delta: int) -> void:
	var bucket_key = _get_bucket_key(cell)

	if not _parking_buckets.has(bucket_key):
		_parking_buckets[bucket_key] = {"supply": 0, "demand": 0}

	_parking_buckets[bucket_key].supply += supply_delta
	_parking_buckets[bucket_key].demand += demand_delta


## Get parking balance for an area around a cell
func get_parking_balance(cell: Vector2i, radius: int = PARKING_SEARCH_RADIUS) -> Dictionary:
	var total_supply: int = 0
	var total_demand: int = 0

	var min_bucket = _get_bucket_key(cell - Vector2i(radius, radius))
	var max_bucket = _get_bucket_key(cell + Vector2i(radius, radius))

	for bx in range(min_bucket.x, max_bucket.x + 1):
		for by in range(min_bucket.y, max_bucket.y + 1):
			var bucket_key = Vector2i(bx, by)
			if _parking_buckets.has(bucket_key):
				total_supply += _parking_buckets[bucket_key].supply
				total_demand += _parking_buckets[bucket_key].demand

	var balance = total_supply - total_demand
	var satisfaction = 1.0 if total_demand == 0 else minf(1.0, float(total_supply) / float(total_demand))

	return {
		"supply": total_supply,
		"demand": total_demand,
		"balance": balance,
		"satisfaction": satisfaction
	}


func get_parking_deficit_at(cell: Vector2i) -> float:
	return parking_deficit.get(cell, 0.0)


func has_parking_deficit(cell: Vector2i) -> bool:
	return parking_deficit.get(cell, 0.0) > 5.0  # More than 5 spaces deficit


func get_total_parking_deficit() -> float:
	var total = 0.0
	for cell in parking_deficit:
		total += parking_deficit[cell]
	return total


func get_parking_development_modifier(cell: Vector2i) -> float:
	# Parking deficit slows development
	var deficit = get_parking_deficit_at(cell)
	if deficit <= 0:
		return 1.0  # No deficit, full speed

	# Deficit reduces development speed
	if deficit < 10:
		return 0.9
	elif deficit < 25:
		return 0.7
	elif deficit < 50:
		return 0.5
	else:
		return 0.3


func get_parking_happiness_penalty() -> float:
	# Total city parking deficit affects happiness (frustrated drivers)
	var total_deficit = get_total_parking_deficit()

	if total_deficit < 50:
		return 0.0
	elif total_deficit < 200:
		return 0.02
	elif total_deficit < 500:
		return 0.05
	else:
		return 0.08


func get_zones_with_parking_issues() -> int:
	var count = 0
	for cell in parking_deficit:
		if parking_deficit[cell] > 10:
			count += 1
	return count
