extends Node
class_name UnlockSystemClass
## Manages progressive building unlocks based on population milestones
## Provides a learning curve by revealing buildings gradually

signal building_unlocked(building_id: String, tier: int)
signal tier_unlocked(tier: int, tier_name: String)
signal all_unlocked()

# Unlock tiers with population thresholds and building lists
# Buildings not in any tier are always available (like basic roads)
const UNLOCK_TIERS: Dictionary = {
	0: {
		"name": "Starter",
		"population": 0,
		"description": "Basic infrastructure to get your city started",
		"buildings": [
			# Infrastructure
			"dirt_road", "road", "power_line", "water_pipe",
			# Power
			"coal_plant", "windmill",
			# Water
			"water_pump", "water_tower", "well",
			# Zones (low density)
			"residential_low", "commercial_low", "industrial_low",
			# Agriculture
			"farm",
			# Basic service
			"small_park"
		]
	},
	1: {
		"name": "Village",
		"population": 100,
		"description": "Your settlement is growing! New options available.",
		"buildings": [
			# Medium density zones
			"residential_zone", "commercial_zone", "industrial_zone",
			# Services
			"fire_station",
			# Transit
			"bus_stop",
			# Parks
			"large_park"
		]
	},
	2: {
		"name": "Town",
		"population": 500,
		"description": "A proper town needs proper services!",
		"buildings": [
			# Power
			"gas_plant",
			# Water
			"large_water_pump", "sewage_treatment",
			# Services
			"police_station", "school",
			# Roads
			"street",
			# Transit
			"bus_depot"
		]
	},
	3: {
		"name": "Small City",
		"population": 1000,
		"description": "Your city is taking shape. Green energy and high density unlocked!",
		"buildings": [
			# High density zones
			"residential_high", "commercial_high", "industrial_high",
			# Green power
			"solar_plant", "wind_turbine",
			# Services
			"hospital", "library",
			# Transit
			"subway_station",
			# Water
			"treatment_plant"
		]
	},
	4: {
		"name": "Growing City",
		"population": 2500,
		"description": "Higher education and data infrastructure are now possible!",
		"buildings": [
			# Power
			"solar_farm", "wind_farm", "battery_farm",
			# Services
			"university", "community_center",
			# Roads
			"avenue", "boulevard",
			# Data Centers
			"data_center_tier1",
			# Water
			"water_recycling"
		]
	},
	5: {
		"name": "City",
		"population": 5000,
		"description": "A true city! Advanced power and transportation unlocked.",
		"buildings": [
			# Power
			"nuclear_plant", "oil_plant",
			# Transit
			"rail_station", "airport",
			# Data Centers
			"data_center_tier2",
			# Water
			"desalination_plant", "large_sewage_treatment"
		]
	},
	6: {
		"name": "Metropolis",
		"population": 10000,
		"description": "Your metropolis can handle the biggest infrastructure!",
		"buildings": [
			# Roads
			"highway", "parkway", "streetcar_parkway",
			# Transit
			"seaport",
			# Data Centers
			"data_center_tier3",
			# Special zones
			"mixed_use_zone", "heavy_industrial_zone"
		]
	},
	7: {
		"name": "Major City",
		"population": 25000,
		"description": "Prestigious landmarks are now available!",
		"buildings": [
			# Landmarks
			"mayors_house", "city_hall", "stadium"
		]
	}
}

# Track unlocked state
var _unlocked_tiers: Array[int] = []
var _unlocked_buildings: Dictionary = {}  # building_id: true
var _building_to_tier: Dictionary = {}  # building_id: tier_number

# Whether unlock system is enabled (disabled in Sandbox mode)
var _enabled: bool = true


func _ready() -> void:
	# Build reverse lookup
	_build_tier_lookup()

	# Connect to population changes
	Events.population_changed.connect(_on_population_changed)

	# Connect to difficulty changes
	if GameConfig:
		GameConfig.difficulty_changed.connect(_on_difficulty_changed)

	# Initialize unlocks based on current population
	call_deferred("_check_unlocks")


func _build_tier_lookup() -> void:
	_building_to_tier.clear()
	for tier in UNLOCK_TIERS:
		var tier_data = UNLOCK_TIERS[tier]
		for building_id in tier_data.buildings:
			_building_to_tier[building_id] = tier


func _on_difficulty_changed(difficulty: GameConfigClass.Difficulty) -> void:
	# Sandbox mode unlocks everything
	if difficulty == GameConfigClass.Difficulty.SANDBOX:
		_enabled = false
		_unlock_all()
	else:
		_enabled = true
		# Re-check unlocks based on current population
		_unlocked_tiers.clear()
		_unlocked_buildings.clear()
		_check_unlocks()


func _on_population_changed(population: int, _delta: int) -> void:
	if not _enabled:
		return
	_check_unlocks_for_population(population)


func _check_unlocks() -> void:
	_check_unlocks_for_population(GameState.population)


func _check_unlocks_for_population(population: int) -> void:
	var newly_unlocked_tiers: Array[int] = []
	var newly_unlocked_buildings: Array[String] = []

	for tier in UNLOCK_TIERS:
		var tier_data = UNLOCK_TIERS[tier]
		var required_pop = tier_data.population

		if population >= required_pop and tier not in _unlocked_tiers:
			_unlocked_tiers.append(tier)
			newly_unlocked_tiers.append(tier)

			# Unlock all buildings in this tier
			for building_id in tier_data.buildings:
				if not _unlocked_buildings.has(building_id):
					_unlocked_buildings[building_id] = true
					newly_unlocked_buildings.append(building_id)

	# Emit signals for newly unlocked items
	for tier in newly_unlocked_tiers:
		var tier_data = UNLOCK_TIERS[tier]
		tier_unlocked.emit(tier, tier_data.name)

		# Only notify for tiers > 0 (don't notify for starting tier)
		if tier > 0:
			Events.simulation_event.emit("tier_unlocked", {
				"tier": tier,
				"name": tier_data.name,
				"description": tier_data.description,
				"buildings": tier_data.buildings
			})

	for building_id in newly_unlocked_buildings:
		building_unlocked.emit(building_id, _building_to_tier.get(building_id, 0))

	# Check if all tiers are unlocked
	if _unlocked_tiers.size() == UNLOCK_TIERS.size():
		all_unlocked.emit()


func _unlock_all() -> void:
	for tier in UNLOCK_TIERS:
		if tier not in _unlocked_tiers:
			_unlocked_tiers.append(tier)
			for building_id in UNLOCK_TIERS[tier].buildings:
				_unlocked_buildings[building_id] = true

	all_unlocked.emit()


## Check if a building is unlocked
func is_building_unlocked(building_id: String) -> bool:
	if not _enabled:
		return true  # Everything unlocked when system disabled

	# If not in any tier, it's always available
	if not _building_to_tier.has(building_id):
		return true

	return _unlocked_buildings.has(building_id)


## Get the tier a building belongs to (returns -1 if not in any tier)
func get_building_tier(building_id: String) -> int:
	return _building_to_tier.get(building_id, -1)


## Get the population required to unlock a building
func get_unlock_population(building_id: String) -> int:
	var tier = _building_to_tier.get(building_id, -1)
	if tier < 0:
		return 0  # Not tier-locked

	return UNLOCK_TIERS[tier].population


## Get tier info for a building
func get_building_tier_info(building_id: String) -> Dictionary:
	var tier = _building_to_tier.get(building_id, -1)
	if tier < 0:
		return {}

	return UNLOCK_TIERS[tier]


## Get the next unlock milestone (returns -1 if all unlocked)
func get_next_unlock_population() -> int:
	for tier in UNLOCK_TIERS:
		if tier not in _unlocked_tiers:
			return UNLOCK_TIERS[tier].population
	return -1


## Get the next tier info (returns empty if all unlocked)
func get_next_tier_info() -> Dictionary:
	for tier in UNLOCK_TIERS:
		if tier not in _unlocked_tiers:
			return UNLOCK_TIERS[tier]
	return {}


## Get all buildings that will unlock at the next tier
func get_next_tier_buildings() -> Array:
	var next_tier = get_next_tier_info()
	if next_tier.is_empty():
		return []
	return next_tier.buildings


## Get the current tier number
func get_current_tier() -> int:
	var max_tier = -1
	for tier in _unlocked_tiers:
		max_tier = max(max_tier, tier)
	return max_tier


## Get the current tier name
func get_current_tier_name() -> String:
	var tier = get_current_tier()
	if tier < 0:
		return "None"
	return UNLOCK_TIERS[tier].name


## Get progress to next tier (0.0 to 1.0)
func get_progress_to_next_tier() -> float:
	var current_tier = get_current_tier()
	var next_tier = current_tier + 1

	if not UNLOCK_TIERS.has(next_tier):
		return 1.0  # All unlocked

	var current_pop = GameState.population
	var current_threshold = UNLOCK_TIERS[current_tier].population if current_tier >= 0 else 0
	var next_threshold = UNLOCK_TIERS[next_tier].population

	var range_size = next_threshold - current_threshold
	if range_size <= 0:
		return 1.0

	var progress = float(current_pop - current_threshold) / float(range_size)
	return clampf(progress, 0.0, 1.0)


## Get all unlocked building IDs
func get_unlocked_buildings() -> Array:
	return _unlocked_buildings.keys()


## Get all locked building IDs
func get_locked_buildings() -> Array:
	var locked: Array = []
	for building_id in _building_to_tier:
		if not _unlocked_buildings.has(building_id):
			locked.append(building_id)
	return locked


## Force unlock a specific building (for cheats/debug)
func force_unlock_building(building_id: String) -> void:
	if not _unlocked_buildings.has(building_id):
		_unlocked_buildings[building_id] = true
		building_unlocked.emit(building_id, _building_to_tier.get(building_id, 0))


## Force unlock a tier (for cheats/debug)
func force_unlock_tier(tier: int) -> void:
	if tier in UNLOCK_TIERS and tier not in _unlocked_tiers:
		_unlocked_tiers.append(tier)
		for building_id in UNLOCK_TIERS[tier].buildings:
			if not _unlocked_buildings.has(building_id):
				_unlocked_buildings[building_id] = true
				building_unlocked.emit(building_id, tier)
		tier_unlocked.emit(tier, UNLOCK_TIERS[tier].name)


## Reset all unlocks (for new game)
func reset_unlocks() -> void:
	_unlocked_tiers.clear()
	_unlocked_buildings.clear()
	_check_unlocks()


## Check if the unlock system is enabled
func is_enabled() -> bool:
	return _enabled
