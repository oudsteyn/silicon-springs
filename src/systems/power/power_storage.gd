class_name PowerStorage
extends RefCounted
## Manages battery building storage - charging, discharging, and degradation

var storage_buildings: Array[Node2D] = []  # Buildings with energy_storage_capacity > 0
var storage_state: Dictionary = {}  # {building_instance_id: state_dict}

# Storage statistics
var total_storage_capacity: float = 0.0  # MWh
var total_stored_energy: float = 0.0  # MWh
var last_storage_delta: float = 0.0  # +charging, -discharging


## Initialize storage state for a new building
func add_storage_building(building: Node2D) -> void:
	if building in storage_buildings:
		return

	storage_buildings.append(building)
	var id = building.get_instance_id()
	var capacity = building.building_data.energy_storage_capacity

	storage_state[id] = {
		"charge": capacity * 0.5,  # Start at 50% charge
		"capacity": capacity,
		"max_charge_rate": building.building_data.storage_charge_rate,
		"max_discharge_rate": building.building_data.storage_discharge_rate,
		"efficiency": building.building_data.storage_efficiency,
		"cycles": 0  # Track charge/discharge cycles for degradation
	}

	_recalculate_totals()


## Remove a storage building
func remove_storage_building(building: Node2D) -> void:
	storage_buildings.erase(building)
	var id = building.get_instance_id()
	if storage_state.has(id):
		storage_state.erase(id)
	_recalculate_totals()


## Recalculate total storage capacity and stored energy
func _recalculate_totals() -> void:
	total_storage_capacity = 0.0
	total_stored_energy = 0.0

	for building in storage_buildings:
		if is_instance_valid(building) and building.is_operational:
			var id = building.get_instance_id()
			if storage_state.has(id):
				total_storage_capacity += storage_state[id].capacity
				total_stored_energy += storage_state[id].charge


## Recalculate totals (public interface)
func recalculate_storage_totals() -> void:
	_recalculate_totals()


## Charge storage buildings with surplus power
## Returns amount actually stored (input power consumed)
func charge(available_surplus: float) -> float:
	var total_charged = 0.0

	for building in storage_buildings:
		if not is_instance_valid(building) or not building.is_operational:
			continue

		var id = building.get_instance_id()
		if not storage_state.has(id):
			continue

		var state = storage_state[id]
		var space_available = state.capacity - state.charge
		var max_charge = state.max_charge_rate

		# How much can we actually charge?
		var charge_amount = minf(available_surplus - total_charged, max_charge)
		charge_amount = minf(charge_amount, space_available)
		charge_amount = maxf(charge_amount, 0.0)

		if charge_amount > 0:
			# Apply charging efficiency loss
			var actual_stored = charge_amount * state.efficiency
			state.charge += actual_stored
			total_charged += charge_amount
			state.cycles += charge_amount / state.capacity * 0.5  # Half cycle for charge

	last_storage_delta = total_charged
	_recalculate_totals()
	return total_charged


## Discharge storage to meet deficit
## Returns amount actually provided (usable power)
func discharge(deficit: float) -> float:
	var total_discharged = 0.0

	for building in storage_buildings:
		if not is_instance_valid(building) or not building.is_operational:
			continue

		var id = building.get_instance_id()
		if not storage_state.has(id):
			continue

		var state = storage_state[id]
		var max_discharge = state.max_discharge_rate

		# How much can we discharge?
		var discharge_amount = minf(deficit - total_discharged, max_discharge)
		discharge_amount = minf(discharge_amount, state.charge)
		discharge_amount = maxf(discharge_amount, 0.0)

		if discharge_amount > 0:
			state.charge -= discharge_amount
			# Apply discharge efficiency
			total_discharged += discharge_amount * state.efficiency
			state.cycles += discharge_amount / state.capacity * 0.5  # Half cycle for discharge

	last_storage_delta = -total_discharged
	_recalculate_totals()
	return total_discharged


## Apply monthly storage degradation (batteries lose capacity over time)
func apply_monthly_degradation() -> void:
	for id in storage_state:
		var state = storage_state[id]
		var cycle_degradation = state.cycles * 0.0001  # 0.01% per cycle
		var age_degradation = 0.001  # 0.1% per month base

		var total_degradation = 1.0 - (cycle_degradation + age_degradation)
		state.capacity *= clampf(total_degradation, 0.8, 1.0)  # Minimum 80% original capacity

		# Ensure charge doesn't exceed new capacity
		state.charge = minf(state.charge, state.capacity)

	_recalculate_totals()


## Get charge percentage (0-100)
func get_charge_percent() -> float:
	if total_storage_capacity > 0:
		return (total_stored_energy / total_storage_capacity) * 100
	return 0.0


## Get storage info dictionary
func get_storage_info() -> Dictionary:
	return {
		"total_capacity": total_storage_capacity,
		"total_stored": total_stored_energy,
		"charge_percent": get_charge_percent(),
		"last_delta": last_storage_delta,
		"is_charging": last_storage_delta > 0,
		"is_discharging": last_storage_delta < 0,
		"building_count": storage_buildings.size()
	}


## Get storage info for a specific building
func get_storage_by_building(building: Node2D) -> Dictionary:
	var id = building.get_instance_id()
	if storage_state.has(id):
		return storage_state[id].duplicate()
	return {}


## Check if building is a storage building
func has_building(building: Node2D) -> bool:
	return building in storage_buildings
