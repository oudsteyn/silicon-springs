extends Node
## Central game state management - tracks all core game variables

# Legacy constants (kept for compatibility, use GameConfig instead)
const STARTING_BUDGET: int = 100000
const STARTING_POPULATION: int = 0
const BASE_TAX_RATE: float = 0.1
const RESIDENTIAL_TAX_PER_POP: float = 25.0
const COMMERCIAL_TAX_PER_BUILDING: float = 150.0

## Get starting budget from GameConfig
func get_starting_budget() -> int:
	return GameConfig.starting_budget if GameConfig else STARTING_BUDGET

## Get residential tax per pop from GameConfig
func get_residential_tax_per_pop() -> float:
	return GameConfig.residential_tax_per_pop if GameConfig else RESIDENTIAL_TAX_PER_POP

## Get commercial tax per building from GameConfig
func get_commercial_tax_per_building() -> float:
	return GameConfig.commercial_tax_per_building if GameConfig else COMMERCIAL_TAX_PER_BUILDING

# Batch update support - prevents signal spam during monthly ticks
var _batch_mode: bool = false
var _pending_signals: Array[Callable] = []

# Adjustable tax rate (default matches BASE_TAX_RATE)
var tax_rate: float = 0.1:
	set(value):
		tax_rate = clamp(value, 0.05, 0.2)  # 5% to 20%

# Budget
var budget: int = STARTING_BUDGET:
	set(value):
		budget = value
		_emit_or_queue(func(): Events.budget_updated.emit(budget, monthly_income, monthly_expenses))

var monthly_income: int = 0
var monthly_expenses: int = 0

# Population
var population: int = STARTING_POPULATION:
	set(value):
		var delta = value - population
		population = max(0, value)
		var pop = population  # Capture for closure
		_emit_or_queue(func(): Events.population_changed.emit(pop, delta))

var educated_population: int = 0
var education_rate: float = 0.0:
	set(value):
		education_rate = clamp(value, 0.0, 1.0)
		var rate = education_rate  # Capture for closure
		_emit_or_queue(func(): Events.education_changed.emit(rate))

# Happiness (0.0 to 1.0)
var happiness: float = 0.5:
	set(value):
		happiness = clamp(value, 0.0, 1.0)
		var h = happiness  # Capture for closure
		_emit_or_queue(func(): Events.happiness_changed.emit(h))

# Resources
var power_supply: float = 0.0
var power_demand: float = 0.0
var water_supply: float = 0.0
var water_demand: float = 0.0

# Time tracking
var current_month: int = 1
var current_year: int = 2024
var total_months: int = 0

# Score
var score: int = 0:
	set(value):
		var delta = value - score
		score = max(0, value)
		var s = score  # Capture for closure
		_emit_or_queue(func(): Events.score_updated.emit(s, delta))

# Data centers placed
var data_centers_by_tier: Dictionary = {1: 0, 2: 0, 3: 0}

# Building counts by type
var building_counts: Dictionary = {}

# Zones
var residential_zones: int = 0
var commercial_zones: int = 0

# Employment
var jobs_available: int = 0
var skilled_jobs_available: int = 0
var unskilled_jobs_available: int = 0
var employed_population: int = 0
var skilled_employed: int = 0
var unskilled_employed: int = 0
var unemployment_rate: float = 0.0:
	set(value):
		unemployment_rate = clamp(value, 0.0, 1.0)

# Demand indicators (-1.0 to 1.0, positive = high demand)
var residential_demand: float = 0.0
var commercial_demand: float = 0.0
var industrial_demand: float = 0.0

# Industrial tracking
var industrial_zones: int = 0

# Traffic tracking (0.0 = no congestion, 1.0 = gridlock)
var city_traffic_congestion: float = 0.0

# Crime tracking (0.0 = no crime, 1.0 = high crime)
var city_crime_rate: float = 0.0

# Current biome
var current_biome_id: String = ""
var current_biome: Resource = null  # BiomePreset

# Bankruptcy
var months_in_debt: int = 0
const BANKRUPTCY_THRESHOLD: int = 12  # Legacy constant, use GameConfig.bankruptcy_threshold

## Get bankruptcy threshold from GameConfig
func get_bankruptcy_threshold() -> int:
	return GameConfig.bankruptcy_threshold if GameConfig else BANKRUPTCY_THRESHOLD

# Landmark unlocks - population thresholds
const LANDMARK_UNLOCKS: Dictionary = {
	"mayors_house": 1000,
	"city_hall": 5000,
	"stadium": 10000,
	"university": 15000
}
var unlocked_landmarks: Dictionary = {}  # {landmark_id: true}


func _ready() -> void:
	reset_game()


## Start batch mode - signals will be queued instead of emitted immediately
func begin_batch() -> void:
	_batch_mode = true


## End batch mode - emit all queued signals
func end_batch() -> void:
	_batch_mode = false
	for signal_call in _pending_signals:
		signal_call.call()
	_pending_signals.clear()


## Helper to emit signal immediately or queue it in batch mode
func _emit_or_queue(signal_callable: Callable) -> void:
	if _batch_mode:
		_pending_signals.append(signal_callable)
	else:
		signal_callable.call()


func reset_game() -> void:
	budget = get_starting_budget()
	monthly_income = 0
	monthly_expenses = 0
	population = GameConfig.starting_population if GameConfig else STARTING_POPULATION
	educated_population = 0
	education_rate = 0.0
	happiness = GameConfig.starting_happiness if GameConfig else 0.5
	power_supply = 0.0
	power_demand = 0.0
	water_supply = 0.0
	water_demand = 0.0
	current_month = 1
	current_year = 2024
	total_months = 0
	score = 0
	data_centers_by_tier = {1: 0, 2: 0, 3: 0}
	building_counts = {}
	residential_zones = 0
	commercial_zones = 0
	jobs_available = 0
	employed_population = 0
	unemployment_rate = 0.0
	residential_demand = 0.0
	commercial_demand = 0.0
	industrial_demand = 0.0
	industrial_zones = 0
	months_in_debt = 0
	unlocked_landmarks = {}
	current_biome_id = ""
	current_biome = null


func advance_month() -> void:
	current_month += 1
	total_months += 1
	if current_month > 12:
		current_month = 1
		current_year += 1
		Events.year_tick.emit()
	Events.month_tick.emit()


func get_date_string() -> String:
	var month_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%s %d" % [month_names[current_month - 1], current_year]


func can_afford(amount: int) -> bool:
	return budget >= amount


func spend(amount: int) -> bool:
	if can_afford(amount):
		budget -= amount
		return true
	return false


func earn(amount: int) -> void:
	budget += amount


func update_power(supply: float, demand: float) -> void:
	power_supply = supply
	power_demand = demand
	Events.power_updated.emit(supply, demand)


func update_water(supply: float, demand: float) -> void:
	water_supply = supply
	water_demand = demand
	Events.water_updated.emit(supply, demand)


func get_power_ratio() -> float:
	if power_demand <= 0:
		return 1.0
	return min(power_supply / power_demand, 1.0)


func get_water_ratio() -> float:
	if water_demand <= 0:
		return 1.0
	return min(water_supply / water_demand, 1.0)


func has_power_shortage() -> bool:
	return power_demand > power_supply


func has_water_shortage() -> bool:
	return water_demand > water_supply


func get_available_power() -> float:
	return max(0, power_supply - power_demand)


func get_available_water() -> float:
	return max(0, water_supply - water_demand)


func increment_building_count(building_id: String) -> void:
	building_counts[building_id] = building_counts.get(building_id, 0) + 1


func decrement_building_count(building_id: String) -> void:
	building_counts[building_id] = max(0, building_counts.get(building_id, 0) - 1)


func get_building_count(building_id: String) -> int:
	return building_counts.get(building_id, 0)


func add_data_center(tier: int) -> void:
	data_centers_by_tier[tier] = data_centers_by_tier.get(tier, 0) + 1


func remove_data_center(tier: int) -> void:
	data_centers_by_tier[tier] = max(0, data_centers_by_tier.get(tier, 0) - 1)


func get_total_data_centers() -> int:
	var total = 0
	for tier in data_centers_by_tier:
		total += data_centers_by_tier[tier]
	return total


func update_employment(total_jobs: int, skilled: int = 0, unskilled: int = 0) -> void:
	jobs_available = total_jobs
	skilled_jobs_available = skilled
	unskilled_jobs_available = unskilled

	# Match workers to jobs by skill level
	# Educated workers can take any job, uneducated only take unskilled jobs
	var uneducated_pop = population - educated_population

	# Uneducated workers fill unskilled jobs first
	unskilled_employed = min(uneducated_pop, unskilled_jobs_available)
	var remaining_unskilled_jobs = unskilled_jobs_available - unskilled_employed

	# Educated workers fill skilled jobs, then remaining unskilled jobs
	skilled_employed = min(educated_population, skilled_jobs_available)
	var educated_in_unskilled = min(educated_population - skilled_employed, remaining_unskilled_jobs)

	employed_population = unskilled_employed + skilled_employed + educated_in_unskilled

	if population > 0:
		unemployment_rate = 1.0 - (float(employed_population) / float(population))
	else:
		unemployment_rate = 0.0

	Events.employment_updated.emit(jobs_available, employed_population, unemployment_rate)


func update_demand() -> void:
	# Use DemandCalculator for pure calculation logic
	var demand = DemandCalculator.calculate(
		population,
		jobs_available,
		commercial_zones,
		industrial_zones,
		educated_population,
		has_power_shortage(),
		has_water_shortage(),
		city_traffic_congestion,
		city_crime_rate
	)

	residential_demand = demand.residential
	commercial_demand = demand.commercial
	industrial_demand = demand.industrial

	Events.demand_updated.emit(residential_demand, commercial_demand, industrial_demand)


func get_employment_ratio() -> float:
	if population == 0:
		return 1.0
	return float(employed_population) / float(population)


func check_landmark_unlocks() -> void:
	for landmark_id in LANDMARK_UNLOCKS:
		if not unlocked_landmarks.has(landmark_id):
			var required_pop = LANDMARK_UNLOCKS[landmark_id]
			if population >= required_pop:
				unlocked_landmarks[landmark_id] = true
				Events.landmark_unlocked.emit(landmark_id, required_pop)


func is_landmark_unlocked(landmark_id: String) -> bool:
	# If not in unlock list, it's always available
	if not LANDMARK_UNLOCKS.has(landmark_id):
		return true
	return unlocked_landmarks.has(landmark_id)


func get_landmark_requirement(landmark_id: String) -> int:
	return LANDMARK_UNLOCKS.get(landmark_id, 0)


func set_biome(biome: Resource) -> void:
	current_biome = biome
	if biome and biome.get("id"):
		current_biome_id = biome.id
		Events.biome_selected.emit(biome.id)
	else:
		current_biome_id = ""


func get_biome() -> Resource:
	return current_biome


func get_biome_id() -> String:
	return current_biome_id
