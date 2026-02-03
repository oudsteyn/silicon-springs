extends Node
class_name DistrictSystem
## Manages neighborhood districts with distinct characteristics

var grid_system = null

# District data
var districts: Dictionary = {}  # {district_id: DistrictData}
var cell_to_district: Dictionary = {}  # {Vector2i: district_id}

# District counter
var next_district_id: int = 1

# District overlay types
const OVERLAY_TYPES: Array = [
	"none",
	"historic",           # Limited demolition, tourism bonus
	"transit_oriented",   # Higher density, reduced parking
	"industrial",         # Industrial-only zoning
	"entertainment",      # Commercial/entertainment focus
	"residential",        # Residential-only
	"mixed_use"           # Encourages mixed-use development
]


class DistrictData:
	var id: int = 0
	var name: String = ""
	var cells: Array[Vector2i] = []
	var overlay: String = "none"
	var tax_modifier: float = 1.0  # Tax rate multiplier
	var metrics: Dictionary = {}   # Population, jobs, land value, etc.


func _ready() -> void:
	Events.building_placed.connect(_on_building_changed)
	Events.building_removed.connect(_on_building_changed)


func set_grid_system(system) -> void:
	grid_system = system


func _on_building_changed(_cell: Vector2i, _building: Node2D) -> void:
	_update_all_district_metrics()


func create_district(district_name: String, cells: Array[Vector2i]) -> int:
	var district = DistrictData.new()
	district.id = next_district_id
	district.name = district_name
	district.cells = cells

	districts[district.id] = district
	next_district_id += 1

	# Map cells to district
	for cell in cells:
		cell_to_district[cell] = district.id

	_update_district_metrics(district)

	Events.simulation_event.emit("district_created", {"name": name, "id": district.id})

	return district.id


func delete_district(district_id: int) -> bool:
	if not districts.has(district_id):
		return false

	var district = districts[district_id]

	# Remove cell mappings
	for cell in district.cells:
		cell_to_district.erase(cell)

	districts.erase(district_id)
	return true


func set_district_overlay(district_id: int, overlay: String) -> bool:
	if not districts.has(district_id):
		return false

	if overlay not in OVERLAY_TYPES:
		return false

	districts[district_id].overlay = overlay
	_update_district_metrics(districts[district_id])

	Events.simulation_event.emit("district_overlay_set", {
		"name": districts[district_id].name,
		"overlay": overlay
	})

	return true


func set_district_tax_modifier(district_id: int, modifier: float) -> bool:
	if not districts.has(district_id):
		return false

	# Limit tax modifier range
	modifier = clamp(modifier, 0.5, 2.0)
	districts[district_id].tax_modifier = modifier

	Events.simulation_event.emit("district_tax_changed", {
		"name": districts[district_id].name,
		"modifier": modifier
	})

	return true


func _update_all_district_metrics() -> void:
	for district_id in districts:
		_update_district_metrics(districts[district_id])


func _update_district_metrics(district: DistrictData) -> void:
	if not grid_system:
		return

	var metrics = {
		"population": 0,
		"jobs": 0,
		"buildings": 0,
		"land_value": 0.0,
		"residential_zones": 0,
		"commercial_zones": 0,
		"industrial_zones": 0
	}

	var counted = {}
	for cell in district.cells:
		if not grid_system.buildings.has(cell):
			continue

		var building = grid_system.buildings[cell]
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data:
			continue

		metrics["buildings"] += 1

		if building.building_data.population_capacity > 0:
			if building.has_method("get_effective_capacity"):
				metrics["population"] += building.get_effective_capacity()
			else:
				metrics["population"] += building.building_data.population_capacity

		if building.building_data.jobs_provided > 0:
			if building.has_method("get_effective_jobs"):
				metrics["jobs"] += building.get_effective_jobs()
			else:
				metrics["jobs"] += building.building_data.jobs_provided

		match building.building_data.building_type:
			"residential":
				metrics["residential_zones"] += 1
			"commercial":
				metrics["commercial_zones"] += 1
			"industrial", "heavy_industrial":
				metrics["industrial_zones"] += 1

	district.metrics = metrics


func get_district_at(cell: Vector2i) -> int:
	return cell_to_district.get(cell, 0)


func get_district(district_id: int) -> DistrictData:
	return districts.get(district_id)


func get_all_districts() -> Dictionary:
	return districts


func get_overlay_at(cell: Vector2i) -> String:
	var district_id = get_district_at(cell)
	if district_id == 0:
		return "none"
	return districts[district_id].overlay


func get_tax_modifier_at(cell: Vector2i) -> float:
	var district_id = get_district_at(cell)
	if district_id == 0:
		return 1.0
	return districts[district_id].tax_modifier


func get_development_modifier(cell: Vector2i) -> float:
	var overlay = get_overlay_at(cell)

	match overlay:
		"transit_oriented":
			return 1.3  # 30% faster development
		"historic":
			return 0.7  # 30% slower (preservation)
		"entertainment":
			return 1.2  # 20% faster for commercial
		_:
			return 1.0


func get_density_modifier(cell: Vector2i) -> float:
	var overlay = get_overlay_at(cell)

	match overlay:
		"transit_oriented":
			return 1.5  # 50% higher density allowed
		"historic":
			return 0.8  # 20% lower density
		_:
			return 1.0


func can_build_type(cell: Vector2i, building_type: String) -> bool:
	var overlay = get_overlay_at(cell)

	match overlay:
		"residential":
			return building_type in ["residential", "mixed_use", "park"]
		"industrial":
			return building_type in ["industrial", "heavy_industrial"]
		"historic":
			# Historic districts restrict certain buildings
			return building_type not in ["heavy_industrial", "highway"]
		_:
			return true


func can_demolish(cell: Vector2i) -> bool:
	var overlay = get_overlay_at(cell)

	# Historic districts have demolition restrictions
	if overlay == "historic":
		return false

	return true


func get_parking_modifier(cell: Vector2i) -> float:
	var overlay = get_overlay_at(cell)

	match overlay:
		"transit_oriented":
			return 0.5  # 50% less parking required
		_:
			return 1.0


func get_district_count() -> int:
	return districts.size()


func get_total_district_population() -> int:
	var total = 0
	for district_id in districts:
		total += districts[district_id].metrics.get("population", 0)
	return total


func get_overlay_happiness_bonus() -> float:
	# Historic and well-planned districts add happiness
	var bonus = 0.0

	for district_id in districts:
		var district = districts[district_id]
		match district.overlay:
			"historic":
				bonus += 0.02  # Tourism and pride
			"transit_oriented":
				bonus += 0.01  # Better commutes
			"entertainment":
				bonus += 0.02  # Fun activities

	return min(0.08, bonus)  # Cap at 8%
