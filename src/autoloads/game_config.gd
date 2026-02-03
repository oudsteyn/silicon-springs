extends Node
class_name GameConfigClass
## Centralized game configuration with difficulty presets
## All tunable game constants live here for easy balancing and difficulty adjustment

signal difficulty_changed(difficulty: Difficulty)
signal config_changed()

# ============================================
# DIFFICULTY PRESETS
# ============================================

enum Difficulty { EASY, NORMAL, HARD, SANDBOX }

var current_difficulty: Difficulty = Difficulty.NORMAL

# ============================================
# ECONOMY SETTINGS
# ============================================

## Starting funds for new game
var starting_budget: int = 100000

## Base tax rate (10% = 0.1)
var base_tax_rate: float = 0.1

## Tax rate bounds
var tax_rate_min: float = 0.05
var tax_rate_max: float = 0.20

## Per-capita residential tax (dollars per employed person per month)
var residential_tax_per_pop: float = 25.0

## Per-building commercial tax (dollars per commercial zone per month)
var commercial_tax_per_building: float = 150.0

## Per-building industrial tax
var industrial_tax_per_building: float = 75.0

## Data center income per tier
var data_center_income: Dictionary = {1: 500, 2: 2000, 3: 5000}

## Months in debt before bankruptcy effects
var bankruptcy_threshold: int = 12

## Maintenance cost multiplier (1.0 = normal)
var maintenance_multiplier: float = 1.0

# ============================================
# POPULATION SETTINGS
# ============================================

## Base population growth rate per month
var base_growth_rate: float = 0.02

## Maximum population growth rate (with high happiness)
var max_growth_rate: float = 0.10

## Minimum population growth rate (can be negative for decline)
var min_growth_rate: float = -0.05

## Initial population for new cities
var starting_population: int = 0

## Job attraction bonus cap (max extra growth from available jobs)
var job_attraction_bonus: float = 0.05

## Resource shortage growth penalty multiplier
var resource_shortage_penalty: float = 0.5

# ============================================
# ZONE DEVELOPMENT SETTINGS
# ============================================

## Base chance for a zone to spawn its first building (per month)
var zone_spawn_chance: float = 0.15

## Base chance for a zone building to upgrade (per month)
var zone_upgrade_chance: float = 0.08

## Base development progress per month
var zone_development_rate: float = 5.0

## Zone capacities (population/jobs)
var zone_capacity: Dictionary = {
	"residential_low": {"pop": 20, "jobs": 0},
	"residential_med": {"pop": 80, "jobs": 0},
	"residential_high": {"pop": 200, "jobs": 0},
	"commercial_low": {"pop": 0, "jobs": 10},
	"commercial_med": {"pop": 0, "jobs": 40},
	"commercial_high": {"pop": 0, "jobs": 100},
	"industrial_low": {"pop": 0, "jobs": 15},
	"industrial_med": {"pop": 0, "jobs": 60},
	"industrial_high": {"pop": 0, "jobs": 150},
	"agricultural": {"pop": 0, "jobs": 10}
}

## Power demand per zone type
var zone_power_demand: Dictionary = {
	"residential": 2.0,  # MW per zone
	"commercial": 5.0
}

# ============================================
# RANDOM EVENT SETTINGS
# ============================================

## Fire chance per month for uncovered buildings
var fire_chance_uncovered: float = 0.05

## Crime chance per month for uncovered buildings
var crime_chance_uncovered: float = 0.03

## Whether disasters are enabled
var disasters_enabled: bool = true

## Base disaster chance per year (scales with population)
var disaster_chance_base: float = 0.05

## Maximum disaster chance per year
var disaster_chance_max: float = 0.15

## Disaster damage multipliers
var earthquake_damage_chance: float = 0.3
var tornado_path_length: int = 15
var flood_duration: int = 3
var meteor_radius: int = 3

# ============================================
# HAPPINESS SETTINGS
# ============================================

## Happiness smoothing factor (how fast happiness changes)
var happiness_lerp_rate: float = 0.3

## Starting happiness for new cities
var starting_happiness: float = 0.5

## Zoning incompatibility penalty per violation
var zoning_incompatibility_penalty: float = 0.03

## Maximum park happiness bonus
var park_bonus_cap: float = 0.5

## Crime incident happiness penalty
var crime_happiness_penalty: float = 0.02

## Crime decay rate per month
var crime_decay_rate: float = 0.7

# ============================================
# INFRASTRUCTURE SETTINGS
# ============================================

## Power transmission efficiency settings
var power_max_efficient_distance: int = 30
var power_efficiency_falloff: float = 0.02
var power_min_efficiency: float = 0.5

## Water transmission efficiency settings
var water_max_efficient_distance: int = 25
var water_efficiency_falloff: float = 0.025
var water_min_efficiency: float = 0.5

## Infrastructure degradation rates per month
var degradation_rates: Dictionary = {
	"road": 0.5,
	"collector": 0.6,
	"arterial": 0.8,
	"highway": 1.0,
	"power_line": 0.2,
	"water_pipe": 0.3,
	"default": 0.1
}

## Traffic impact on road degradation
var traffic_degradation_multiplier: float = 2.0

## Maintenance cost multipliers by condition
var maintenance_condition_multipliers: Dictionary = {
	"good": 1.0,
	"fair": 1.5,
	"poor": 2.5,
	"critical": 4.0
}

## Repair cost as percentage of build cost
var repair_cost_percent: float = 0.3

## Condition thresholds
var condition_good: float = 70.0
var condition_fair: float = 40.0
var condition_poor: float = 20.0

# ============================================
# POLLUTION SETTINGS
# ============================================

## Natural pollution decay rate per tick
var pollution_decay_rate: float = 0.05

## Wind dispersion base (per km/h of wind speed)
var pollution_wind_dispersion_base: float = 0.02

## Rain settling rate (pollution reduction per rain intensity)
var pollution_rain_settling_rate: float = 0.15

## Inversion trap multiplier (pollution buildup during inversions)
var pollution_inversion_trap_mult: float = 1.5

## Maximum ambient pollution level
var pollution_max_ambient: float = 0.6

# ============================================
# WILDFIRE SETTINGS
# ============================================

## Base monthly wildfire chance in fire season
var wildfire_base_risk: float = 0.02

## Temperature threshold above which wildfire risk increases
var wildfire_temp_threshold: float = 30.0

## Humidity threshold below which wildfire risk increases
var wildfire_humidity_threshold: float = 0.3

## Maximum wildfire duration in months
var wildfire_max_duration: int = 3

# ============================================
# CONSTRUCTION SETTINGS
# ============================================

## Base construction progress per month
var construction_rate: float = 25.0

## Construction speed multiplier
var construction_speed: float = 1.0

## Happiness impact on construction speed (min multiplier)
var construction_happiness_min: float = 0.5

## Budget crisis construction penalty
var construction_debt_penalty: float = 0.5

## Low unemployment construction penalty
var construction_labor_shortage_penalty: float = 0.7

# ============================================
# LANDMARK UNLOCKS
# ============================================

var landmark_unlocks: Dictionary = {
	"mayors_house": 1000,
	"city_hall": 5000,
	"stadium": 10000,
	"university": 15000
}

# ============================================
# DIFFICULTY PRESET DEFINITIONS
# ============================================

const DIFFICULTY_PRESETS: Dictionary = {
	Difficulty.EASY: {
		"name": "Easy",
		"description": "Relaxed gameplay for learning. More starting funds, faster growth, no disasters.",
		"starting_budget": 200000,
		"base_growth_rate": 0.04,
		"max_growth_rate": 0.15,
		"zone_spawn_chance": 0.25,
		"zone_upgrade_chance": 0.12,
		"maintenance_multiplier": 0.6,
		"disasters_enabled": false,
		"fire_chance_uncovered": 0.02,
		"crime_chance_uncovered": 0.01,
		"resource_shortage_penalty": 0.7,
		"bankruptcy_threshold": 24,
		"construction_speed": 1.5,
		"pollution_decay_rate": 0.08,
		"wildfire_base_risk": 0.01,
	},
	Difficulty.NORMAL: {
		"name": "Normal",
		"description": "Balanced challenge. Standard economy and growth rates.",
		"starting_budget": 100000,
		"base_growth_rate": 0.02,
		"max_growth_rate": 0.10,
		"zone_spawn_chance": 0.15,
		"zone_upgrade_chance": 0.08,
		"maintenance_multiplier": 1.0,
		"disasters_enabled": true,
		"fire_chance_uncovered": 0.05,
		"crime_chance_uncovered": 0.03,
		"resource_shortage_penalty": 0.5,
		"bankruptcy_threshold": 12,
		"construction_speed": 1.0,
	},
	Difficulty.HARD: {
		"name": "Hard",
		"description": "For experienced players. Tight budget, slow growth, frequent disasters.",
		"starting_budget": 50000,
		"base_growth_rate": 0.01,
		"max_growth_rate": 0.06,
		"zone_spawn_chance": 0.10,
		"zone_upgrade_chance": 0.05,
		"maintenance_multiplier": 1.5,
		"disasters_enabled": true,
		"disaster_chance_base": 0.10,
		"disaster_chance_max": 0.25,
		"fire_chance_uncovered": 0.08,
		"crime_chance_uncovered": 0.05,
		"resource_shortage_penalty": 0.3,
		"bankruptcy_threshold": 6,
		"construction_speed": 0.7,
		"pollution_decay_rate": 0.03,
		"wildfire_base_risk": 0.04,
		"wildfire_max_duration": 4,
	},
	Difficulty.SANDBOX: {
		"name": "Sandbox",
		"description": "Unlimited funds, no disasters. Build freely and experiment.",
		"starting_budget": 10000000,
		"base_growth_rate": 0.05,
		"max_growth_rate": 0.20,
		"zone_spawn_chance": 0.30,
		"zone_upgrade_chance": 0.15,
		"maintenance_multiplier": 0.0,
		"disasters_enabled": false,
		"fire_chance_uncovered": 0.0,
		"crime_chance_uncovered": 0.0,
		"resource_shortage_penalty": 1.0,
		"bankruptcy_threshold": 999,
		"construction_speed": 3.0,
		"pollution_decay_rate": 0.15,
		"wildfire_base_risk": 0.0,
	}
}


func _ready() -> void:
	# Apply default difficulty
	apply_difficulty(Difficulty.NORMAL)


## Apply a difficulty preset
func apply_difficulty(difficulty: Difficulty) -> void:
	current_difficulty = difficulty

	var preset = DIFFICULTY_PRESETS.get(difficulty, DIFFICULTY_PRESETS[Difficulty.NORMAL])

	# Apply all preset values
	for key in preset:
		if key in ["name", "description"]:
			continue
		if has(key):
			set(key, preset[key])

	difficulty_changed.emit(difficulty)
	config_changed.emit()


## Get the name of the current difficulty
func get_difficulty_name() -> String:
	var preset = DIFFICULTY_PRESETS.get(current_difficulty, {})
	return preset.get("name", "Normal")


## Get the description of a difficulty level
func get_difficulty_description(difficulty: Difficulty) -> String:
	var preset = DIFFICULTY_PRESETS.get(difficulty, {})
	return preset.get("description", "")


## Check if a property exists
func has(property_name: String) -> bool:
	return property_name in self


## Reset to default values for current difficulty
func reset_to_defaults() -> void:
	apply_difficulty(current_difficulty)


## Get a configuration value with fallback
func get_value(key: String, default_value: Variant = null) -> Variant:
	if has(key):
		return get(key)
	return default_value


## Set a configuration value (for custom difficulty)
func set_value(key: String, value) -> void:
	if has(key):
		set(key, value)
		config_changed.emit()


## Get all configurable properties and their current values
func get_all_config() -> Dictionary:
	var config = {}

	# Economy
	config["starting_budget"] = starting_budget
	config["base_tax_rate"] = base_tax_rate
	config["maintenance_multiplier"] = maintenance_multiplier
	config["bankruptcy_threshold"] = bankruptcy_threshold

	# Population
	config["base_growth_rate"] = base_growth_rate
	config["max_growth_rate"] = max_growth_rate
	config["min_growth_rate"] = min_growth_rate

	# Zones
	config["zone_spawn_chance"] = zone_spawn_chance
	config["zone_upgrade_chance"] = zone_upgrade_chance

	# Events
	config["disasters_enabled"] = disasters_enabled
	config["fire_chance_uncovered"] = fire_chance_uncovered
	config["crime_chance_uncovered"] = crime_chance_uncovered

	# Construction
	config["construction_speed"] = construction_speed

	return config


## Export config for saving
func export_config() -> Dictionary:
	return {
		"difficulty": current_difficulty,
		"config": get_all_config()
	}


## Import config from save
func import_config(data: Dictionary) -> void:
	if data.has("difficulty"):
		apply_difficulty(data["difficulty"])

	if data.has("config"):
		for key in data["config"]:
			set_value(key, data["config"][key])
