extends Node
## Simulation tick manager - handles monthly updates and game speed

# Speed settings (seconds per month)
const SPEED_SETTINGS: Array[float] = [0.0, 10.0, 5.0, 2.0]  # Paused, Slow, Normal, Fast
const SPEED_NAMES: Array[String] = ["Paused", "Slow", "Normal", "Fast"]
const SimulationClockScript = preload("res://src/systems/simulation_clock.gd")

var _clock: SimulationClock = SimulationClockScript.new(SPEED_SETTINGS, SPEED_NAMES, 1)

var current_speed: int:
	get: return _clock.current_speed
	set(value): _clock.set_speed(value)

var is_paused: bool:
	get: return _clock.is_paused
	set(value): _clock.is_paused = value

var tick_timer: float:
	get: return _clock.tick_timer
	set(value): _clock.tick_timer = value

# SystemManager reference for dependency-injected system access
var _system_manager: Node = null

# System cache - lazily populated from SystemManager
var _system_cache: Dictionary = {}

# Last happiness calculation result (for UI transparency)
var last_happiness_result: HappinessCalculator.HappinessResult = null

# Last expense breakdown (for domain events)
var _last_expense_breakdown: Dictionary = {}

## Set the SystemManager for dependency-injected system access
func set_system_manager(manager: Node) -> void:
	_system_manager = manager
	_system_cache.clear()  # Invalidate cache

## Get a system by ID, using cache for performance
func _get_system(system_id: String) -> Node:
	if _system_cache.has(system_id):
		return _system_cache[system_id]

	if _system_manager and _system_manager.has_method("get_system"):
		var system = _system_manager.get_system(system_id)
		_system_cache[system_id] = system
		return system

	return null

# System accessors - use these instead of direct references
var grid_system: Node:
	get: return _get_system("grid")
	set(value): _system_cache["grid"] = value

var power_system: Node:
	get: return _get_system("power")
	set(value): _system_cache["power"] = value

var water_system: Node:
	get: return _get_system("water")
	set(value): _system_cache["water"] = value

var service_coverage: Node:
	get: return _get_system("service_coverage")
	set(value): _system_cache["service_coverage"] = value

var pollution_system: Node:
	get: return _get_system("pollution")
	set(value): _system_cache["pollution"] = value

var land_value_system: Node:
	get: return _get_system("land_value")
	set(value): _system_cache["land_value"] = value

var traffic_system: Node:
	get: return _get_system("traffic")
	set(value): _system_cache["traffic"] = value

var zoning_system: Node:
	get: return _get_system("zoning")
	set(value): _system_cache["zoning"] = value

var weather_system: Node:
	get: return _get_system("weather")
	set(value): _system_cache["weather"] = value

var infrastructure_age_system: Node:
	get: return _get_system("infrastructure_age")
	set(value): _system_cache["infrastructure_age"] = value

# Random event chances (per month, when not covered) - Legacy constants, use GameConfig
const FIRE_CHANCE_UNCOVERED: float = 0.05
const CRIME_CHANCE_UNCOVERED: float = 0.03

# Population growth settings - Legacy constants, use GameConfig
const BASE_GROWTH_RATE: float = 0.02
const MAX_GROWTH_RATE: float = 0.10
const MIN_GROWTH_RATE: float = -0.05

## Get fire chance from GameConfig
func _get_fire_chance() -> float:
	return GameConfig.fire_chance_uncovered if GameConfig else FIRE_CHANCE_UNCOVERED

## Get crime chance from GameConfig
func _get_crime_chance() -> float:
	return GameConfig.crime_chance_uncovered if GameConfig else CRIME_CHANCE_UNCOVERED

## Get growth rate bounds from GameConfig
func _get_growth_bounds() -> Dictionary:
	if GameConfig:
		return {
			"base": GameConfig.base_growth_rate,
			"max": GameConfig.max_growth_rate,
			"min": GameConfig.min_growth_rate
		}
	return {"base": BASE_GROWTH_RATE, "max": MAX_GROWTH_RATE, "min": MIN_GROWTH_RATE}


func _ready() -> void:
	Events.simulation_speed_changed.connect(_on_speed_changed)
	Events.simulation_paused.connect(_on_paused_changed)


func _process(delta: float) -> void:
	if _clock.advance(delta):
		_process_monthly_tick()


func _process_monthly_tick() -> void:
	# Use batch mode to reduce signal spam during monthly updates
	GameState.begin_batch()

	# 1. Calculate power generation vs demand
	if power_system:
		power_system.calculate_power()

	# 2. Calculate water supply vs demand
	if water_system:
		water_system.calculate_water()

	# 3. Update service coverage maps
	if service_coverage:
		service_coverage.update_all_coverage()

	# 3b. Update pollution
	if pollution_system:
		pollution_system.update_pollution()

	# 3c. Update traffic
	if traffic_system:
		traffic_system.update_traffic()

	# 4. Calculate jobs and employment
	_update_employment()

	# 5. Check for random events
	_process_random_events()

	# 5b. Calculate crime rate
	_calculate_crime_rate()

	# 5c. Process building abandonment
	_process_abandonment()

	# 6. Calculate citizen happiness
	_calculate_happiness()

	# 7. Update population
	_update_population()

	# 7b. Check for landmark unlocks
	GameState.check_landmark_unlocks()

	# 8. Update education rate
	_update_education()

	# 9. Update traffic congestion metric
	if traffic_system:
		GameState.city_traffic_congestion = traffic_system.get_average_congestion()

	# 9b. Update demand indicators
	GameState.update_demand()

	# 9b. Process construction
	_process_construction()

	# 9c. Process zone development
	_process_zone_development()

	# 9d. Process infrastructure aging
	_process_infrastructure_aging()

	# 10. Collect taxes, pay maintenance
	_process_finances()

	# End batch mode - emit all queued signals at once
	GameState.end_batch()

	# 11. Advance the calendar (outside batch so month_tick fires immediately)
	GameState.advance_month()


func _update_employment() -> void:
	if not grid_system:
		return

	var total_jobs: float = 0.0
	var skilled_jobs: float = 0.0
	var unskilled_jobs: float = 0.0

	# Count jobs from all buildings
	var counted_buildings = {}
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted_buildings.has(building):
			continue
		counted_buildings[building] = true

		if not building.building_data:
			continue

		# Only count jobs from operational buildings
		if building.is_operational:
			var jobs = 0
			# Use effective jobs if available (zones with development levels)
			if building.has_method("get_effective_jobs"):
				var effective = building.get_effective_jobs()
				if effective > 0:
					jobs = effective
				else:
					jobs = building.building_data.jobs_provided
			else:
				jobs = building.building_data.jobs_provided

			total_jobs += jobs

			# Split by skill requirement
			var skill_ratio = building.building_data.skilled_jobs_ratio if building.building_data.get("skilled_jobs_ratio") != null else 0.0
			skilled_jobs += jobs * skill_ratio
			unskilled_jobs += jobs * (1.0 - skill_ratio)

	GameState.update_employment(total_jobs, skilled_jobs, unskilled_jobs)


func _process_random_events() -> void:
	if not grid_system or not service_coverage:
		return

	var checked_buildings = {}  # Avoid checking same building multiple times

	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building):
			continue

		# Skip if already checked this building (multi-cell buildings)
		if checked_buildings.has(building):
			continue
		checked_buildings[building] = true

		var building_data = building.building_data
		if not building_data:
			continue

		# Skip infrastructure (roads, power lines, water pipes don't burn)
		if building_data.category == "infrastructure":
			continue

		# Skip agricultural buildings (crop plots don't catch fire)
		if building_data.building_type == "agricultural":
			continue

		# Check fire risk for burnable buildings (zones, services, power, water, data centers)
		if not service_coverage.has_fire_coverage(cell):
			if randf() < _get_fire_chance():
				_start_fire(cell, building)

		# Check crime risk (only for residential/commercial)
		if building_data.category in ["residential", "commercial"]:
			if not service_coverage.has_police_coverage(cell):
				if randf() < _get_crime_chance():
					_trigger_crime(cell)


func _start_fire(cell: Vector2i, building: Node2D) -> void:
	Events.fire_started.emit(cell)
	Events.random_event_occurred.emit("fire", cell)
	Events.simulation_event.emit("disaster_fire", {"cell": cell})

	# Fire damages building (reduce effectiveness or destroy)
	if building.has_method("take_damage"):
		building.take_damage(50)


func _trigger_crime(cell: Vector2i) -> void:
	Events.crime_occurred.emit(cell)
	Events.random_event_occurred.emit("crime", cell)

	# Crime reduces happiness (use GameConfig penalty)
	var penalty = GameConfig.crime_happiness_penalty if GameConfig else 0.02
	GameState.happiness -= penalty

	# Track crime incident for crime rate calculation
	_crime_incidents += 1


# Crime tracking
var _crime_incidents: int = 0

func _calculate_crime_rate() -> void:
	# Base crime rate from recent incidents
	var incident_rate = min(1.0, _crime_incidents * 0.05)  # Each incident adds 5%, cap at 100%

	# Unemployment increases crime
	var unemployment_factor = GameState.unemployment_rate * 0.3  # Up to 30% from unemployment

	# Police coverage reduces crime
	var coverage_reduction = 0.0
	if service_coverage:
		var avg_coverage = service_coverage.get_average_coverage()
		coverage_reduction = avg_coverage * 0.5  # Good coverage reduces up to 50%

	# Calculate final crime rate
	var base_crime = incident_rate + unemployment_factor
	GameState.city_crime_rate = clamp(base_crime - coverage_reduction, 0.0, 1.0)

	# Decay crime incidents over time (use GameConfig decay rate)
	var decay_rate = GameConfig.crime_decay_rate if GameConfig else 0.7
	_crime_incidents = int(_crime_incidents * decay_rate)


func _calculate_happiness() -> void:
	# Build input data for the calculator
	var input = HappinessCalculator.HappinessInput.new()

	# Power and water ratios
	input.power_ratio = GameState.get_power_ratio()
	input.water_ratio = GameState.get_water_ratio()

	# Service coverage
	if service_coverage:
		input.service_coverage = service_coverage.get_average_coverage()
	else:
		input.service_coverage = 0.5

	# Employment
	input.employment_ratio = GameState.get_employment_ratio()

	# Budget
	input.budget = GameState.budget

	# Pollution
	if pollution_system:
		input.pollution_score = pollution_system.get_residential_pollution_score()
		input.polluted_residential_count = pollution_system.get_polluted_residential_count()
	else:
		input.pollution_score = 1.0
		input.polluted_residential_count = 0

	# Parks
	input.park_bonus = _calculate_park_bonus()
	input.park_effectiveness_modifier = 1.0 + Ordinances.get_effect("park_effectiveness")

	# Ordinances
	input.ordinance_happiness_bonus = Ordinances.get_effect("happiness")

	# Traffic
	if traffic_system:
		input.traffic_score = traffic_system.get_city_traffic_score()
		input.noise_penalty = traffic_system.get_residential_noise_penalty()
	else:
		input.traffic_score = 1.0
		input.noise_penalty = 0.0

	# Zoning
	if zoning_system:
		input.zoning_penalty = zoning_system.get_incompatibility_happiness_penalty()
	else:
		input.zoning_penalty = 0.0

	# Natural environment (trees, water proximity)
	if land_value_system:
		input.natural_environment_score = _calculate_natural_environment_score()
	else:
		input.natural_environment_score = 0.5

	# Climate comfort (based on temperature extremes)
	if weather_system:
		input.climate_comfort = _calculate_climate_comfort()
	else:
		input.climate_comfort = 1.0

	# Air Quality Index for health impacts
	if pollution_system:
		input.aqi = pollution_system.get_air_quality_index()
	else:
		input.aqi = 0.0

	# Weather comfort for seasonal happiness
	if weather_system:
		input.weather_comfort = _calculate_weather_comfort()
	else:
		input.weather_comfort = 1.0

	# Drought status
	if weather_system and weather_system.has_method("is_drought_active"):
		input.is_drought = weather_system.is_drought_active()
	else:
		input.is_drought = false

	# Power outage severity
	if power_system and power_system.has_method("get_outage_severity"):
		input.power_outage_severity = power_system.get_outage_severity()
	else:
		input.power_outage_severity = 0.0

	# Calculate using the pure function
	var lerp_rate = GameConfig.happiness_lerp_rate if GameConfig else 0.3
	last_happiness_result = HappinessCalculator.calculate_smoothed(input, GameState.happiness, lerp_rate)

	# Update game state
	GameState.happiness = last_happiness_result.happiness


func _update_population() -> void:
	if GameState.residential_zones == 0:
		return

	# Max population based on residential zones with development levels
	var max_pop = _calculate_max_population()
	if max_pop == 0:
		max_pop = GameState.residential_zones * 50  # Fallback

	# Get growth rate bounds from GameConfig
	var bounds = _get_growth_bounds()

	# Base growth rate based on happiness
	var growth_rate = lerp(bounds["min"], bounds["max"], GameState.happiness)

	# CRITICAL: No growth without jobs available
	# People won't move to a city without employment
	var job_capacity = int(GameState.jobs_available)
	if GameState.population >= job_capacity and growth_rate > 0:
		# Can't grow beyond job capacity
		max_pop = mini(max_pop, job_capacity)

	# Jobs attract workers - if jobs > population, faster growth
	var job_bonus = GameConfig.job_attraction_bonus if GameConfig else 0.05
	if int(GameState.jobs_available) > GameState.population and GameState.population > 0:
		var job_attraction = float(job_capacity - GameState.population) / float(GameState.population)
		growth_rate += min(job_bonus, job_attraction * 0.1)

	# Apply resource shortages (use GameConfig penalty)
	var shortage_penalty = GameConfig.resource_shortage_penalty if GameConfig else 0.5
	if GameState.has_power_shortage():
		growth_rate *= shortage_penalty
	if GameState.has_water_shortage():
		growth_rate *= shortage_penalty

	# No growth if budget is negative
	if GameState.budget < 0:
		growth_rate = min(growth_rate, 0.0)

	# Calculate growth
	var current_pop = GameState.population
	if current_pop < max_pop and growth_rate > 0:
		var growth = int(max(1, current_pop * growth_rate))
		# Initial population boost if we have housing and jobs but no people
		if current_pop == 0 and job_capacity > 0:
			growth = mini(10, job_capacity)  # Start with 10 people or job capacity
		GameState.population = min(max_pop, current_pop + growth)
	elif current_pop > max_pop or growth_rate < 0:
		# Population decline if over capacity or unhappy
		var decline_rate = abs(growth_rate) if growth_rate < 0 else 0.1
		var decline = int(max(1, current_pop * decline_rate))
		GameState.population = max(0, current_pop - decline)


func _calculate_max_population() -> int:
	if not grid_system:
		return GameState.residential_zones * 50

	var total_capacity = 0
	var counted = {}

	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data:
			continue

		if building.building_data.building_type in ["residential", "mixed_use"] and building.is_operational:
			if building.has_method("get_effective_capacity"):
				var effective = building.get_effective_capacity()
				if effective > 0:
					total_capacity += effective
				else:
					total_capacity += building.building_data.population_capacity
			else:
				total_capacity += building.building_data.population_capacity

	return total_capacity if total_capacity > 0 else GameState.residential_zones * 50


func _update_education() -> void:
	if GameState.population == 0:
		GameState.education_rate = 0.0
		return

	if not service_coverage:
		return

	# Education rate based on school coverage of residential areas
	var educated_pop = service_coverage.get_educated_population_estimate()
	GameState.educated_population = educated_pop
	GameState.education_rate = float(educated_pop) / float(GameState.population)


func _process_finances() -> void:
	# Calculate income
	var tax_income = 0

	# Get average land value multiplier
	var land_multiplier = 1.0
	if land_value_system:
		land_multiplier = 0.5 + land_value_system.get_average_land_value()  # 0.5x to 1.5x

	# Tax rate multiplier (relative to base)
	var base_tax = GameConfig.base_tax_rate if GameConfig else GameState.BASE_TAX_RATE
	var tax_multiplier = GameState.tax_rate / base_tax

	# Get tax rates from GameConfig
	var res_tax_per_pop = GameState.get_residential_tax_per_pop()
	var com_tax_per_building = GameState.get_commercial_tax_per_building()
	var ind_tax_per_building = GameConfig.industrial_tax_per_building if GameConfig else 75.0

	# Calculate weather economic modifier (affects commercial activity)
	var weather_economic_mult = 1.0
	if weather_system:
		weather_economic_mult = _calculate_weather_economic_multiplier()

	# Residential tax (only from employed population, modified by land value and tax rate)
	tax_income += int(GameState.employed_population * res_tax_per_pop * land_multiplier * tax_multiplier)

	# Commercial tax (affected by weather - bad weather = less shopping/tourism)
	var operational_commercial = _count_operational_zones("commercial")
	var commercial_income = operational_commercial * com_tax_per_building * land_multiplier * tax_multiplier
	commercial_income *= weather_economic_mult
	tax_income += int(commercial_income)

	# Industrial tax (less affected by weather - factories run rain or shine)
	var operational_industrial = _count_operational_zones("industrial")
	var industrial_weather_mult = 1.0 + (weather_economic_mult - 1.0) * 0.3  # Only 30% of weather effect
	tax_income += int(operational_industrial * ind_tax_per_building * tax_multiplier * industrial_weather_mult)

	# Data center income (use GameConfig values)
	var dc_income = GameConfig.data_center_income if GameConfig else {1: 500, 2: 2000, 3: 5000}
	tax_income += GameState.data_centers_by_tier.get(1, 0) * dc_income.get(1, 500)
	tax_income += GameState.data_centers_by_tier.get(2, 0) * dc_income.get(2, 2000)
	tax_income += GameState.data_centers_by_tier.get(3, 0) * dc_income.get(3, 5000)

	# Calculate expenses (maintenance with GameConfig multiplier)
	var maintenance = 0
	_last_expense_breakdown = {}
	if grid_system:
		maintenance = grid_system.get_total_maintenance(traffic_system)
		# Build expense breakdown by category
		_last_expense_breakdown = grid_system.get_maintenance_by_category() if grid_system.has_method("get_maintenance_by_category") else {}

	# Apply maintenance multiplier from GameConfig
	var maint_multiplier = GameConfig.maintenance_multiplier if GameConfig else 1.0
	maintenance = int(maintenance * maint_multiplier)

	# Apply weather-based heating/cooling modifiers
	# These simulate increased HVAC costs based on biome temperature
	if weather_system:
		var heating_mod = weather_system.get_heating_modifier() if weather_system.has_method("get_heating_modifier") else 1.0
		var cooling_mod = weather_system.get_cooling_modifier() if weather_system.has_method("get_cooling_modifier") else 1.0
		# Combine modifiers - only the relevant one will be > 1.0
		var climate_modifier = max(heating_mod, cooling_mod)
		maintenance = int(maintenance * climate_modifier)

	# Store for display
	GameState.monthly_income = tax_income
	GameState.monthly_expenses = maintenance

	# Apply to budget
	var net = tax_income - maintenance
	GameState.budget += net

	# Check for bankruptcy (use GameConfig threshold)
	var bankruptcy_threshold = GameState.get_bankruptcy_threshold()
	if GameState.budget < 0:
		GameState.months_in_debt += 1
		Events.bankruptcy_warning.emit(GameState.months_in_debt)

		if GameState.months_in_debt == 1:
			Events.simulation_event.emit("budget_warning", {})
		elif GameState.months_in_debt == 2:
			Events.simulation_event.emit("budget_critical", {})
		elif GameState.months_in_debt >= bankruptcy_threshold:
			Events.simulation_event.emit("bankruptcy", {})
			# Services start failing at bankruptcy
			GameState.happiness *= 0.8
	else:
		GameState.months_in_debt = 0

	# Emit domain event with complete budget state
	var budget_event = DomainEvents.BudgetTickEvent.new({
		"balance": GameState.budget,
		"income": tax_income,
		"expenses": maintenance,
		"net_change": net,
		"breakdown": _last_expense_breakdown,
		"months_in_debt": GameState.months_in_debt
	})
	Events.budget_tick.emit(budget_event)


func _process_construction() -> void:
	if not grid_system:
		return

	var counted = {}
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		# Only process buildings under construction
		if not building.is_under_construction:
			continue

		# Construction progress based on conditions
		var progress = _calculate_construction_progress(building)
		if progress > 0:
			building.add_construction_progress(progress)


func _calculate_construction_progress(building: Node2D) -> float:
	var base_progress = building.CONSTRUCTION_RATE  # 25 per month by default

	# Apply GameConfig construction speed multiplier
	var speed_mult = GameConfig.construction_speed if GameConfig else 1.0
	base_progress *= speed_mult

	# Get penalty values from GameConfig
	var happiness_min = GameConfig.construction_happiness_min if GameConfig else 0.5
	var debt_penalty = GameConfig.construction_debt_penalty if GameConfig else 0.5
	var labor_penalty = GameConfig.construction_labor_shortage_penalty if GameConfig else 0.7

	# Faster construction with good happiness (workers motivated)
	base_progress *= (happiness_min + GameState.happiness * (1.0 - happiness_min))

	# Slower construction during budget crisis
	if GameState.budget < 0:
		base_progress *= debt_penalty

	# Slower construction if workforce is limited
	var unemployment = GameState.unemployment_rate
	if unemployment < 0.05:
		# Very low unemployment = hard to find construction workers
		base_progress *= labor_penalty

	return base_progress


func _process_zone_development() -> void:
	if not grid_system:
		return

	var counted = {}
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data or building.building_data.category != "zone":
			continue

		# Skip buildings under construction
		if building.is_under_construction:
			continue

		if not building.is_operational:
			continue

		if building.development_level >= 3:
			continue  # Max level

		# Calculate development progress based on conditions
		var progress = _calculate_zone_development(building)
		if progress > 0:
			building.add_development_progress(progress)


func _calculate_zone_development(building: Node2D) -> float:
	# Base monthly progress (use GameConfig value)
	var base_progress = GameConfig.zone_development_rate if GameConfig else 5.0

	# Demand multiplier
	var demand = 0.0
	match building.building_data.building_type:
		"residential":
			demand = GameState.residential_demand
		"commercial":
			demand = GameState.commercial_demand
		"industrial":
			demand = GameState.industrial_demand
		"mixed_use":
			# Mixed-use benefits from both residential and commercial demand
			demand = (GameState.residential_demand + GameState.commercial_demand) / 2.0

	if demand <= 0:
		return 0.0  # No growth without demand

	base_progress *= (1.0 + demand)  # Up to 2x with full demand

	# Land value multiplier
	if land_value_system:
		var land_value = land_value_system.get_land_value_at(building.grid_cell)
		base_progress *= (0.5 + land_value)  # 0.5x to 1.5x based on land value

	# Service coverage bonus
	if service_coverage:
		if service_coverage.has_fire_coverage(building.grid_cell):
			base_progress *= 1.1
		if service_coverage.has_police_coverage(building.grid_cell):
			base_progress *= 1.1

	# Traffic congestion penalty - heavy traffic slows commercial/industrial development
	if traffic_system and building.building_data.building_type in ["commercial", "industrial"]:
		var congestion = traffic_system.get_congestion_at(building.grid_cell)
		if congestion > 0.6:
			# 60%+ congestion starts hurting development (up to 40% reduction)
			base_progress *= (1.0 - (congestion - 0.6) * 1.0)

	# Pollution penalty - residential zones develop much slower in polluted areas
	if pollution_system and building.building_data.building_type == "residential":
		var pollution = pollution_system.get_pollution_at(building.grid_cell)
		if pollution > 0.2:
			# 20%+ pollution starts hurting residential development severely
			# People don't want to move to polluted areas
			base_progress *= (1.0 - pollution * 0.8)  # Up to 80% reduction

	# Crime penalty - commercial zones suffer in high crime areas
	if building.building_data.building_type == "commercial":
		var crime_rate = GameState.city_crime_rate
		if crime_rate > 0.2:
			# 20%+ crime starts hurting commercial development
			# Businesses don't want to operate in unsafe areas
			base_progress *= (1.0 - (crime_rate - 0.2) * 0.6)  # Up to 48% reduction

	# Happiness modifier
	base_progress *= GameState.happiness

	# Zoning compatibility modifier - incompatible neighbors slow development
	if zoning_system:
		var compat_modifier = zoning_system.get_development_compatibility_modifier(building.grid_cell)
		base_progress *= compat_modifier

	return base_progress


func _calculate_park_bonus() -> float:
	if not grid_system:
		return 0.0

	var total_bonus = 0.0
	var counted = {}

	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if building.building_data and building.building_data.happiness_modifier > 0:
			if building.is_operational:
				total_bonus += building.building_data.happiness_modifier

	# Cap at configured park bonus maximum
	var bonus_cap = GameConfig.park_bonus_cap if GameConfig else 0.5
	return min(bonus_cap, total_bonus)


## Calculate natural environment score based on terrain features near residential areas
func _calculate_natural_environment_score() -> float:
	if not grid_system or not land_value_system:
		return 0.5

	var total_score = 0.0
	var residential_count = 0

	var counted = {}
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		# Only count residential buildings
		if not building.building_data or building.building_data.building_type != "residential":
			continue

		residential_count += 1

		# Get terrain bonuses at this cell
		var terrain_bonus = land_value_system.get_terrain_bonus_at(cell)
		var cell_nature = 0.3  # Base score

		# Add bonuses from terrain features
		cell_nature += terrain_bonus.get("water_proximity", 0.0) * 2.0  # Water is highly valued
		cell_nature += terrain_bonus.get("nature_nearby", 0.0) * 1.5    # Trees are valued
		cell_nature += terrain_bonus.get("elevation_view", 0.0) * 1.0   # Views add value

		total_score += clampf(cell_nature, 0.0, 1.0)

	if residential_count == 0:
		return 0.5

	return total_score / residential_count


## Calculate climate comfort based on current temperature
func _calculate_climate_comfort() -> float:
	if not weather_system or not weather_system.has_method("get_temperature"):
		return 1.0

	var temp = weather_system.get_temperature()

	# Comfort zone is 15-25°C
	# Discomfort increases outside this range
	if temp >= 15 and temp <= 25:
		return 1.0
	elif temp < 15:
		# Cold discomfort
		var cold_factor = (15 - temp) / 30.0  # Full discomfort at -15°C
		return clampf(1.0 - cold_factor, 0.3, 1.0)
	else:
		# Heat discomfort
		var heat_factor = (temp - 25) / 20.0  # Full discomfort at 45°C
		return clampf(1.0 - heat_factor, 0.3, 1.0)


## Calculate how weather affects economic activity
## Good weather boosts commercial activity, bad weather reduces it
func _calculate_weather_economic_multiplier() -> float:
	if not weather_system:
		return 1.0

	var mult = 1.0

	# Get current conditions
	var conditions = ""
	if weather_system.has_method("get_conditions"):
		conditions = weather_system.get_conditions()
	elif weather_system.get("current_conditions"):
		conditions = weather_system.current_conditions

	# Weather condition effects on commerce
	match conditions:
		"Clear", "Sunny":
			mult = 1.1  # Nice weather boosts shopping, outdoor dining
		"Partly Cloudy", "Fair":
			mult = 1.05  # Still pleasant
		"Cloudy", "Overcast":
			mult = 0.95  # Slightly dampened activity
		"Light Rain", "Drizzle":
			mult = 0.85  # Some people stay in
		"Rain":
			mult = 0.75  # Reduced foot traffic
		"Heavy Rain":
			mult = 0.6  # Major reduction in shopping
		"Storm", "Thunderstorm":
			mult = 0.4  # People stay home, shops may close
		"Snow":
			mult = 0.7  # Holiday shopping offsets some reduction
		"Blizzard":
			mult = 0.3  # Severe weather, many businesses closed
		"Fog":
			mult = 0.9  # Minor impact
		_:
			mult = 0.95

	# Heat waves and cold snaps hurt business
	var is_heat_wave = weather_system.heat_wave_active if weather_system.get("heat_wave_active") else false
	var is_cold_snap = weather_system.cold_snap_active if weather_system.get("cold_snap_active") else false

	if is_heat_wave:
		mult *= 0.8  # People avoid going out in extreme heat
	if is_cold_snap:
		mult *= 0.7  # Harsh cold keeps people home

	# Storms cause business interruptions
	var is_storming = weather_system.is_storming if weather_system.get("is_storming") else false
	if is_storming:
		mult *= 0.7

	# Flooding severely impacts commerce
	var is_flooding = weather_system.flood_active if weather_system.get("flood_active") else false
	if is_flooding:
		mult *= 0.5  # Major disruption

	# Seasonal bonus for holiday shopping (November-December)
	var month = GameState.current_month if GameState else 1
	if month in [11, 12]:
		mult *= 1.15  # Holiday season boost

	# Spring/Summer outdoor activity bonus
	if month in [5, 6, 7, 8] and conditions in ["Clear", "Sunny", "Partly Cloudy"]:
		mult *= 1.05

	return clampf(mult, 0.2, 1.3)


## Calculate weather comfort based on current conditions
## This reflects how weather affects daily mood/activities (separate from climate extremes)
func _calculate_weather_comfort() -> float:
	if not weather_system:
		return 1.0

	var comfort = 1.0

	# Check current weather conditions
	var conditions = ""
	if weather_system.has_method("get_conditions"):
		conditions = weather_system.get_conditions()
	elif weather_system.get("current_conditions"):
		conditions = weather_system.current_conditions

	# Weather condition effects
	match conditions:
		"Clear", "Sunny":
			comfort = 1.0  # People love sunny days
		"Partly Cloudy", "Fair":
			comfort = 0.95  # Still pleasant
		"Cloudy", "Overcast":
			comfort = 0.85  # Bit gloomy
		"Light Rain", "Drizzle":
			comfort = 0.75  # Minor inconvenience
		"Rain":
			comfort = 0.65  # Unpleasant
		"Heavy Rain":
			comfort = 0.5  # Stay indoors
		"Storm", "Thunderstorm":
			comfort = 0.35  # Stressful
		"Snow":
			comfort = 0.7  # Some like it, some don't
		"Blizzard":
			comfort = 0.3  # Dangerous conditions
		"Fog":
			comfort = 0.8  # Gloomy but not terrible
		"Heatwave":
			comfort = 0.4  # Very uncomfortable
		"Cold Snap":
			comfort = 0.45  # Dangerous cold
		_:
			comfort = 0.9  # Default for unknown conditions

	# Seasonal bonus - nice weather in spring/summer feels better
	var month = GameState.current_month if GameState else 6
	if month in [4, 5, 9, 10] and conditions in ["Clear", "Sunny", "Partly Cloudy"]:
		# Perfect spring/fall weather
		comfort = minf(1.0, comfort + 0.05)
	elif month in [6, 7, 8] and conditions in ["Clear", "Partly Cloudy"]:
		# Summer days
		comfort = minf(1.0, comfort + 0.03)

	return comfort


func _count_operational_zones(zone_type: String) -> int:
	if not grid_system:
		return 0

	var count = 0
	var counted = {}
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if building.building_data and building.building_data.building_type == zone_type:
			if building.is_operational:
				count += 1
	return count


func set_speed(speed: int) -> void:
	_clock.set_speed(speed)
	Events.simulation_speed_changed.emit(_clock.current_speed)


func toggle_pause() -> void:
	_clock.toggle_pause()
	Events.simulation_paused.emit(_clock.is_paused)


func get_speed_name() -> String:
	return _clock.get_speed_name()


func _on_speed_changed(speed: int) -> void:
	_clock.set_speed(speed)


func _on_paused_changed(paused: bool) -> void:
	_clock.is_paused = paused


func _process_abandonment() -> void:
	if not grid_system:
		return

	var counted = {}
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if building.has_method("process_monthly_abandonment"):
			building.process_monthly_abandonment()


## Get the latest happiness calculation result for UI transparency
func get_happiness_breakdown() -> HappinessCalculator.HappinessResult:
	return last_happiness_result


## Get human-readable summary of happiness issues
func get_happiness_issues() -> String:
	if last_happiness_result:
		return HappinessCalculator.get_issues_summary(last_happiness_result)
	return "No data available yet"


## Get advice for improving a specific happiness factor
func get_happiness_advice(factor_id: String) -> String:
	return HappinessCalculator.get_factor_advice(factor_id)


func _process_infrastructure_aging() -> void:
	if not infrastructure_age_system:
		return

	# Process monthly aging
	infrastructure_age_system.process_monthly_aging()

	# Apply weather effects to degradation
	if weather_system:
		_apply_weather_degradation()

	# Report degraded infrastructure
	var poor_count = infrastructure_age_system.get_infrastructure_in_poor_condition()
	if poor_count > 5:
		Events.simulation_event.emit("infrastructure_degraded", {"count": poor_count})


func _apply_weather_degradation() -> void:
	## Weather conditions accelerate infrastructure degradation
	if not weather_system or not infrastructure_age_system:
		return

	var temp = weather_system.get_temperature() if weather_system.has_method("get_temperature") else 20.0
	var is_storming = weather_system.is_storming if weather_system.get("is_storming") else false
	var humidity = weather_system.get_humidity() if weather_system.has_method("get_humidity") else 0.5

	# Extreme temperatures accelerate degradation
	var temp_penalty = 0.0
	if temp > 35:  # Hot weather stresses infrastructure
		temp_penalty = (temp - 35) * 0.02  # 2% extra per degree above 35
	elif temp < -10:  # Freeze-thaw cycles damage roads
		temp_penalty = (-10 - temp) * 0.03  # 3% extra per degree below -10

	# Storms cause direct damage
	var storm_penalty = 0.3 if is_storming else 0.0

	# High humidity accelerates corrosion
	var humidity_penalty = 0.0
	if humidity > 0.8:
		humidity_penalty = 0.1  # 10% extra in very humid conditions

	# Apply extra degradation to all tracked infrastructure
	var total_penalty = temp_penalty + storm_penalty + humidity_penalty
	if total_penalty > 0:
		for building_id in infrastructure_age_system.infrastructure_age:
			var data = infrastructure_age_system.infrastructure_age[building_id]
			data["condition"] = maxf(0.0, data["condition"] - total_penalty)
