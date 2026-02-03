extends Node
class_name InfrastructureAgeSystem
## Tracks infrastructure age and degradation, requiring maintenance/replacement

var grid_system = null
var traffic_system = null

# Age tracking: {building_instance_id: {age: months, condition: 0-100}}
var infrastructure_age: Dictionary = {}

# Degradation rates per month - Legacy constants, use GameConfig
const DEGRADATION_RATES: Dictionary = {
	"road": 0.5,           # Roads degrade slowly
	"collector": 0.6,      # Collector roads slightly faster
	"arterial": 0.8,       # Arterials faster due to heavy use
	"highway": 1.0,        # Highways fastest
	"power_line": 0.2,     # Power lines last long
	"water_pipe": 0.3,     # Pipes degrade
	"default": 0.1         # Other buildings
}

# Traffic impact on road degradation - Legacy constant
const TRAFFIC_DEGRADATION_MULTIPLIER: float = 2.0

# Condition thresholds - Legacy constants
const CONDITION_GOOD: float = 70.0
const CONDITION_FAIR: float = 40.0
const CONDITION_POOR: float = 20.0

# Maintenance cost multipliers based on condition - Legacy constant
const MAINTENANCE_MULTIPLIERS: Dictionary = {
	"good": 1.0,
	"fair": 1.5,
	"poor": 2.5,
	"critical": 4.0
}

# Repair costs (percentage of build cost) - Legacy constant
const REPAIR_COST_PERCENT: float = 0.3

## Get degradation rates from GameConfig
func _get_degradation_rates() -> Dictionary:
	return GameConfig.degradation_rates if GameConfig else DEGRADATION_RATES

## Get traffic degradation multiplier from GameConfig
func _get_traffic_degradation_multiplier() -> float:
	return GameConfig.traffic_degradation_multiplier if GameConfig else TRAFFIC_DEGRADATION_MULTIPLIER

## Get condition thresholds from GameConfig
func _get_condition_good() -> float:
	return GameConfig.condition_good if GameConfig else CONDITION_GOOD

func _get_condition_fair() -> float:
	return GameConfig.condition_fair if GameConfig else CONDITION_FAIR

func _get_condition_poor() -> float:
	return GameConfig.condition_poor if GameConfig else CONDITION_POOR

## Get maintenance multipliers from GameConfig
func _get_maintenance_multipliers() -> Dictionary:
	return GameConfig.maintenance_condition_multipliers if GameConfig else MAINTENANCE_MULTIPLIERS

## Get repair cost percent from GameConfig
func _get_repair_cost_percent() -> float:
	return GameConfig.repair_cost_percent if GameConfig else REPAIR_COST_PERCENT


func _ready() -> void:
	Events.building_placed.connect(_on_building_placed)
	Events.building_removed.connect(_on_building_removed)


func set_grid_system(system) -> void:
	grid_system = system


func set_traffic_system(traffic) -> void:
	traffic_system = traffic


func _on_building_placed(cell: Vector2i, building: Node2D) -> void:
	if not building or not building.building_data:
		return

	# Track new infrastructure
	var building_id = building.get_instance_id()
	infrastructure_age[building_id] = {
		"age": 0,
		"condition": 100.0,
		"cell": cell,
		"type": building.building_data.building_type
	}


func _on_building_removed(_cell: Vector2i, building: Node2D) -> void:
	if building:
		var building_id = building.get_instance_id()
		infrastructure_age.erase(building_id)


func process_monthly_aging() -> void:
	var _buildings_to_remove = []  # Reserved for future use

	# Get degradation rates from GameConfig
	var deg_rates = _get_degradation_rates()
	var traffic_mult = _get_traffic_degradation_multiplier()

	for building_id in infrastructure_age:
		var data = infrastructure_age[building_id]
		data["age"] += 1

		# Calculate degradation
		var base_rate = deg_rates.get(data["type"], deg_rates.get("default", 0.1))
		var degradation = base_rate

		# Roads degrade faster with heavy traffic
		if data["type"] in ["road", "collector", "arterial", "highway"]:
			if traffic_system:
				var congestion = traffic_system.get_congestion_at(data["cell"])
				if congestion > 0.5:
					degradation *= (1.0 + (congestion - 0.5) * traffic_mult)

		# Apply degradation
		data["condition"] = max(0.0, data["condition"] - degradation)

		# Update building visual with new condition
		_sync_condition_to_building(building_id, data["condition"])

		# Check for critical failure
		if data["condition"] <= 0:
			# Infrastructure fails - needs replacement
			_trigger_infrastructure_failure(building_id, data)


## Sync condition value to building entity for visual updates
func _sync_condition_to_building(building_id: int, condition: float) -> void:
	# Find the building instance by ID
	var building = instance_from_id(building_id)
	if building and is_instance_valid(building) and building.has_method("set_infrastructure_condition"):
		building.set_infrastructure_condition(condition)


func _trigger_infrastructure_failure(_building_id: int, data: Dictionary) -> void:
	# Notify about infrastructure failure
	var type_name = data["type"].replace("_", " ").capitalize()
	Events.simulation_event.emit("infrastructure_failure", {
		"type": type_name,
		"cell": data["cell"]
	})

	# Set condition to minimum (not zero, so it still functions but poorly)
	data["condition"] = 5.0


func get_condition(building: Node2D) -> float:
	if not building:
		return 100.0

	var building_id = building.get_instance_id()
	if infrastructure_age.has(building_id):
		return infrastructure_age[building_id]["condition"]
	return 100.0


func get_condition_status(building: Node2D) -> String:
	var condition = get_condition(building)
	if condition >= _get_condition_good():
		return "good"
	elif condition >= _get_condition_fair():
		return "fair"
	elif condition >= _get_condition_poor():
		return "poor"
	else:
		return "critical"


func get_maintenance_multiplier(building: Node2D) -> float:
	var status = get_condition_status(building)
	var multipliers = _get_maintenance_multipliers()
	return multipliers.get(status, 1.0)


func get_repair_cost(building: Node2D) -> int:
	if not building or not building.building_data:
		return 0

	var condition = get_condition(building)
	if condition >= _get_condition_good():
		return 0  # No repair needed

	# Repair cost based on how much condition is lost
	var damage_percent = (100.0 - condition) / 100.0
	var base_cost = building.building_data.build_cost * _get_repair_cost_percent()
	return int(base_cost * damage_percent)


func repair_building(building: Node2D) -> bool:
	if not building:
		return false

	var cost = get_repair_cost(building)
	if cost <= 0:
		return true  # Already in good condition

	if not GameState.can_afford(cost):
		Events.simulation_event.emit("insufficient_funds", {"cost": cost})
		return false

	GameState.spend(cost)

	# Restore condition
	var building_id = building.get_instance_id()
	if infrastructure_age.has(building_id):
		infrastructure_age[building_id]["condition"] = 100.0

	Events.simulation_event.emit("infrastructure_repaired", {
		"name": building.building_data.display_name,
		"cost": cost
	})
	return true


func get_average_road_condition() -> float:
	var total = 0.0
	var count = 0

	for building_id in infrastructure_age:
		var data = infrastructure_age[building_id]
		if data["type"] in ["road", "collector", "arterial", "highway"]:
			total += data["condition"]
			count += 1

	if count == 0:
		return 100.0

	return total / count


func get_average_utility_condition() -> float:
	var total = 0.0
	var count = 0

	for building_id in infrastructure_age:
		var data = infrastructure_age[building_id]
		if data["type"] in ["power_line", "water_pipe"]:
			total += data["condition"]
			count += 1

	if count == 0:
		return 100.0

	return total / count


func get_infrastructure_in_poor_condition() -> int:
	var count = 0
	var fair_threshold = _get_condition_fair()
	for building_id in infrastructure_age:
		if infrastructure_age[building_id]["condition"] < fair_threshold:
			count += 1
	return count


func get_total_deferred_maintenance() -> int:
	# Total cost to bring all infrastructure to good condition
	var total = 0

	if not grid_system:
		return 0

	var good_threshold = _get_condition_good()
	for building_id in infrastructure_age:
		var data = infrastructure_age[building_id]
		if data["condition"] < good_threshold:
			# Find the building
			var cell = data["cell"]
			if grid_system.buildings.has(cell):
				var building = grid_system.buildings[cell]
				if is_instance_valid(building):
					total += get_repair_cost(building)

	return total


func get_infrastructure_efficiency(building: Node2D) -> float:
	# Poor condition reduces building efficiency
	var condition = get_condition(building)

	if condition >= _get_condition_good():
		return 1.0
	elif condition >= _get_condition_fair():
		return 0.9
	elif condition >= _get_condition_poor():
		return 0.7
	else:
		return 0.5  # Critical condition = 50% efficiency


func get_water_leak_rate() -> float:
	# Poor condition pipes leak water
	var avg_condition = get_average_utility_condition()
	if avg_condition >= _get_condition_good():
		return 0.0

	# Up to 20% water loss from poor pipes
	return (100.0 - avg_condition) / 100.0 * 0.2


func get_power_loss_rate() -> float:
	# Poor condition lines lose power
	var avg_condition = get_average_utility_condition()
	if avg_condition >= _get_condition_good():
		return 0.0

	# Up to 15% power loss from poor lines
	return (100.0 - avg_condition) / 100.0 * 0.15


# Alias methods for UI compatibility
func get_power_loss_from_age() -> float:
	return get_power_loss_rate()


func get_water_loss_from_age() -> float:
	return get_water_leak_rate()


func get_all_tracked_buildings() -> Array[Node2D]:
	# Returns all buildings being tracked by this system
	var buildings: Array[Node2D] = []

	if not grid_system:
		return buildings

	for building_id in infrastructure_age:
		var data = infrastructure_age[building_id]
		var cell = data["cell"]
		if grid_system.buildings.has(cell):
			var building = grid_system.buildings[cell]
			if is_instance_valid(building):
				buildings.append(building)

	return buildings
