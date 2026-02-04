extends Node
class_name HousingSystem
## Manages housing affordability, income brackets, and gentrification

var grid_system = null
var land_value_system = null

# Income brackets (percentage of population)
const INCOME_BRACKETS: Dictionary = {
	"low": 0.30,      # 30% low income
	"medium": 0.50,   # 50% medium income
	"high": 0.20      # 20% high income
}

# Housing affordability thresholds (land value limits for each bracket)
const AFFORDABILITY_THRESHOLDS: Dictionary = {
	"low": 0.4,       # Low income can only afford land value < 0.4
	"medium": 0.7,    # Medium income can afford < 0.7
	"high": 1.0       # High income can afford anything
}

# Housing capacity by bracket: {bracket: capacity}
var housing_capacity: Dictionary = {
	"low": 0,
	"medium": 0,
	"high": 0
}

# Population by bracket: {bracket: population}
var population_by_bracket: Dictionary = {
	"low": 0,
	"medium": 0,
	"high": 0
}

# Displacement tracking (gentrification)
var displaced_residents: int = 0
var displacement_history: Array[int] = []  # Last 12 months


func _ready() -> void:
	Events.building_placed.connect(_on_building_changed)
	Events.building_removed.connect(_on_building_changed)


func set_grid_system(system) -> void:
	grid_system = system


func set_land_value_system(land_value) -> void:
	land_value_system = land_value


func _on_building_changed(_cell: Vector2i, _building: Node2D) -> void:
	_update_housing_capacity()


func update_monthly() -> void:
	_update_housing_capacity()
	_update_population_distribution()
	_process_gentrification()
	_update_displacement_history()


func _update_housing_capacity() -> void:
	housing_capacity = {"low": 0, "medium": 0, "high": 0}

	if not grid_system or not land_value_system:
		return

	var counted = {}
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data:
			continue

		if building.building_data.building_type in ["residential", "mixed_use"]:
			if not building.is_operational:
				continue

			var capacity = 0
			if building.has_method("get_effective_capacity"):
				capacity = building.get_effective_capacity()
			else:
				capacity = building.building_data.population_capacity

			# Determine affordability based on land value
			var land_value = land_value_system.get_land_value_at(building.grid_cell)

			if land_value < AFFORDABILITY_THRESHOLDS["low"]:
				housing_capacity["low"] += capacity
			elif land_value < AFFORDABILITY_THRESHOLDS["medium"]:
				housing_capacity["medium"] += capacity
			else:
				housing_capacity["high"] += capacity


func _update_population_distribution() -> void:
	var total_pop = GameState.population

	# Calculate ideal distribution
	var ideal_low = int(total_pop * INCOME_BRACKETS["low"])
	var ideal_medium = int(total_pop * INCOME_BRACKETS["medium"])
	var ideal_high = total_pop - ideal_low - ideal_medium

	# Distribute based on available housing
	population_by_bracket["low"] = min(ideal_low, housing_capacity["low"])
	population_by_bracket["medium"] = min(ideal_medium, housing_capacity["medium"])
	population_by_bracket["high"] = min(ideal_high, housing_capacity["high"])

	# Overflow handling - if one bracket is full, overflow to adjacent
	var low_overflow = ideal_low - population_by_bracket["low"]
	var medium_overflow = ideal_medium - population_by_bracket["medium"]

	# Low income overflow to medium
	if low_overflow > 0:
		var available = housing_capacity["medium"] - population_by_bracket["medium"]
		var absorbed = min(low_overflow, available)
		population_by_bracket["medium"] += absorbed

	# Medium overflow to high
	if medium_overflow > 0:
		var available = housing_capacity["high"] - population_by_bracket["high"]
		var absorbed = min(medium_overflow, available)
		population_by_bracket["high"] += absorbed


func _process_gentrification() -> void:
	displaced_residents = 0

	if not grid_system or not land_value_system:
		return

	# Check for rising land values displacing low-income residents
	var counted = {}
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data:
			continue

		if building.building_data.building_type in ["residential", "mixed_use"]:
			var land_value = land_value_system.get_land_value_at(building.grid_cell)

			# High land value areas displace low-income residents
			if land_value > 0.7:
				var capacity = building.building_data.population_capacity
				# Assume 30% of capacity was low-income who get displaced
				displaced_residents += int(capacity * 0.3 * (land_value - 0.7))


func _update_displacement_history() -> void:
	displacement_history.append(displaced_residents)
	if displacement_history.size() > 12:
		displacement_history.pop_front()


func get_affordable_housing_shortage() -> int:
	var ideal_low = int(GameState.population * INCOME_BRACKETS["low"])
	var shortage = max(0, ideal_low - housing_capacity["low"])
	return shortage


func get_housing_affordability_score() -> float:
	# 1.0 = perfect balance, 0.0 = severe crisis
	var total_capacity = housing_capacity["low"] + housing_capacity["medium"] + housing_capacity["high"]
	if total_capacity == 0:
		return 0.5

	# Check if each bracket has adequate housing
	var low_ratio = float(housing_capacity["low"]) / float(max(1, total_capacity))
	var target_low_ratio = INCOME_BRACKETS["low"]

	# Score based on how close we are to ideal distribution
	var score = 1.0 - abs(low_ratio - target_low_ratio)
	return clamp(score, 0.0, 1.0)


func get_gentrification_rate() -> float:
	# Average monthly displacement rate
	if displacement_history.size() == 0:
		return 0.0

	var total = 0
	for d in displacement_history:
		total += d
	return float(total) / float(displacement_history.size())


func get_affordability_happiness_modifier() -> float:
	var shortage = get_affordable_housing_shortage()
	if shortage == 0:
		return 0.02  # Bonus for good affordability

	# Penalty scales with shortage
	if shortage < 50:
		return 0.0
	elif shortage < 200:
		return -0.03
	elif shortage < 500:
		return -0.06
	else:
		return -0.10


func get_income_diversity_bonus() -> float:
	# Bonus for having diverse income levels (mixed neighborhoods)
	var total = housing_capacity["low"] + housing_capacity["medium"] + housing_capacity["high"]
	if total == 0:
		return 0.0

	var low_pct = float(housing_capacity["low"]) / total
	var med_pct = float(housing_capacity["medium"]) / total
	var high_pct = float(housing_capacity["high"]) / total

	# Best score when all three are roughly equal
	var min_pct = min(low_pct, min(med_pct, high_pct))
	return min_pct * 0.1  # Up to 3.3% bonus for perfect balance


func get_population_by_bracket() -> Dictionary:
	return population_by_bracket.duplicate()


func get_housing_capacity_by_bracket() -> Dictionary:
	return housing_capacity.duplicate()
