extends Node
class_name PowerSystem
## Manages power generation, distribution, consumption, storage, and grid stability
## Facade that delegates to focused subsystems for maintainability

var grid_system = null  # GridSystem
var weather_system = null  # WeatherSystem
var infrastructure_age_system = null  # InfrastructureAgeSystem

# Subsystems
var _network: PowerNetwork = PowerNetwork.new()
var _storage: PowerStorage = PowerStorage.new()
var _stability: GridStability = GridStability.new()
var _storm_damage: StormDamageSystem = StormDamageSystem.new()

# Power sources and consumers tracking
var power_sources: Array[Node2D] = []  # Buildings that produce power
var power_consumers: Array[Node2D] = []  # Buildings that consume power

# ============================================
# SIGNALS (forwarded from subsystems)
# ============================================

signal grid_stability_changed(stability: float, status: String)
signal brownout_started(severity: float)
signal brownout_ended()
signal blackout_started(affected_cells: int)
signal blackout_ended()
signal storage_state_changed(stored: float, capacity: float, delta: float)
signal storm_outage_started(severity: float, affected_cells: int)
signal storm_outage_progress(restoration_pct: float, remaining_cells: int)
signal storm_outage_ended()


func _ready() -> void:
	Events.building_placed.connect(_on_building_placed)
	Events.building_removed.connect(_on_building_removed)
	Events.month_tick.connect(_on_month_tick)

	# Connect subsystem signals to our signals
	_stability.stability_changed.connect(func(s, st): grid_stability_changed.emit(s, st))
	_stability.brownout_started.connect(func(sev): brownout_started.emit(sev))
	_stability.brownout_ended.connect(func(): brownout_ended.emit())
	_stability.blackout_started.connect(func(cells): blackout_started.emit(cells))
	_stability.blackout_ended.connect(func(): blackout_ended.emit())

	_storm_damage.storm_outage_started.connect(func(sev, cells): storm_outage_started.emit(sev, cells))
	_storm_damage.storm_outage_progress.connect(func(pct, rem): storm_outage_progress.emit(pct, rem))
	_storm_damage.storm_outage_ended.connect(func(): storm_outage_ended.emit())


# ============================================
# CONFIGURATION
# ============================================

func _get_max_efficient_distance() -> int:
	return GameConfig.power_max_efficient_distance if GameConfig else 30


func _get_efficiency_falloff() -> float:
	return GameConfig.power_efficiency_falloff if GameConfig else 0.02


func _get_min_efficiency() -> float:
	return GameConfig.power_min_efficiency if GameConfig else 0.5


func set_grid_system(system) -> void:
	grid_system = system


func set_weather_system(system) -> void:
	weather_system = system


func set_infrastructure_age_system(system) -> void:
	infrastructure_age_system = system


# ============================================
# BUILDING TRACKING
# ============================================

func _on_building_placed(cell: Vector2i, building: Node2D) -> void:
	if not building.building_data:
		return

	var data = building.building_data

	# Track power sources (generators, not storage)
	if data.power_production > 0 and data.energy_storage_capacity == 0:
		power_sources.append(building)

	# Track power consumers
	if data.power_consumption > 0 or data.requires_power:
		power_consumers.append(building)

	# Track energy storage buildings
	if data.energy_storage_capacity > 0:
		_storage.add_storage_building(building)

	# Track power lines in network
	if GridConstants.is_power_type(data.building_type):
		_network.add_power_line(cell)

	# Track roads in network (power follows roads)
	if GridConstants.is_road_type(data.building_type):
		_network.add_road(cell)

	_update_power_network()
	_update_building_power_status()


func _on_building_removed(cell: Vector2i, building: Node2D) -> void:
	if not building or not building.building_data:
		return

	var data = building.building_data

	power_sources.erase(building)
	power_consumers.erase(building)

	if _storage.has_building(building):
		_storage.remove_storage_building(building)

	if GridConstants.is_power_type(data.building_type):
		_network.remove_power_line(cell)

	if GridConstants.is_road_type(data.building_type):
		_network.remove_road(cell)

	_update_power_network()
	_update_building_power_status()


func _on_month_tick() -> void:
	# Reset peak demand tracking monthly
	_stability.reset_peak_demand()

	# Storage degradation over time
	_storage.apply_monthly_degradation()

	# Process storm outage repairs
	if _storm_damage.storm_outage_active:
		_storm_damage.process_repairs(weather_system, _network.powered_cells.size())
		_emit_storm_outage_event()

	# Check for new storm damage
	if weather_system:
		_storm_damage.check_storm_damage(weather_system, _network.powered_cells, _network.distance_from_source)
		if _storm_damage.storm_outage_active:
			_emit_storm_outage_event()


## Emit storm outage domain event
func _emit_storm_outage_event() -> void:
	var storm_event = DomainEvents.StormOutageEvent.new({
		"active": _storm_damage.storm_outage_active,
		"severity": _storm_damage.storm_outage_severity,
		"affected_cells": _storm_damage.storm_damaged_cells.size(),
		"restoration_progress": _storm_damage.outage_restoration_progress,
		"repair_rate": _storm_damage.storm_repair_rate
	})
	Events.storm_outage_changed.emit(storm_event)


# ============================================
# MAIN POWER CALCULATION
# ============================================

func calculate_power() -> void:
	var base_supply = 0.0
	var total_demand = 0.0

	# Get weather multipliers
	var solar_mult = 1.0
	var wind_mult = 1.0
	if weather_system:
		if weather_system.has_method("get_solar_multiplier"):
			solar_mult = weather_system.get_solar_multiplier()
		if weather_system.has_method("get_wind_multiplier"):
			wind_mult = weather_system.get_wind_multiplier()

	# Calculate base supply from generators
	for source in power_sources:
		if is_instance_valid(source) and source.is_operational:
			var production = source.building_data.power_production

			# Apply weather multipliers to renewable sources
			var building_type = source.building_data.building_type
			if building_type in ["solar_plant", "solar_farm"]:
				production *= solar_mult
			elif building_type in ["wind_turbine", "wind_farm"]:
				production *= wind_mult

			base_supply += production

	# Calculate total demand
	for consumer in power_consumers:
		if is_instance_valid(consumer):
			var base_consumption = consumer.building_data.power_consumption
			var efficiency = get_power_efficiency_at(consumer.grid_cell)
			total_demand += base_consumption / efficiency

	# Zone demand
	var zone_power = GameConfig.zone_power_demand if GameConfig else {"residential": 2.0, "commercial": 5.0}
	total_demand += GameState.residential_zones * zone_power.get("residential", 2.0)
	total_demand += GameState.commercial_zones * zone_power.get("commercial", 5.0)

	# Transmission losses
	total_demand += _network.get_total_efficiency_loss(grid_system)

	# Infrastructure aging losses
	if infrastructure_age_system:
		var aging_loss_rate = infrastructure_age_system.get_power_loss_rate()
		if aging_loss_rate > 0:
			var aging_loss = base_supply * aging_loss_rate
			base_supply -= aging_loss
			if aging_loss_rate > 0.1:
				Events.simulation_event.emit("power_line_degradation", {
					"loss_rate": int(aging_loss_rate * 100),
					"message": "Degraded power lines losing %d%% of power" % int(aging_loss_rate * 100)
				})

	# Track peak demand
	_stability.update_peak_demand(total_demand)

	# Neighbor deals
	base_supply += NeighborDeals.get_effective_power_bought()
	base_supply -= NeighborDeals.get_effective_power_sold()

	# ---- STORAGE LOGIC ----
	_storage.recalculate_storage_totals()
	var storage_contribution = 0.0

	if base_supply > total_demand:
		# Surplus - charge storage
		var surplus = base_supply - total_demand
		var charged = _storage.charge(surplus)
		base_supply -= charged
	elif base_supply < total_demand:
		# Deficit - discharge storage
		var deficit = total_demand - base_supply
		storage_contribution = _storage.discharge(deficit)

	# Final supply includes storage discharge
	var total_supply = base_supply + storage_contribution

	# Calculate grid stability
	var storage_ratio = 0.0
	if _storage.total_storage_capacity > 0:
		storage_ratio = _storage.total_stored_energy / _storage.total_storage_capacity
	_stability.calculate_stability(total_supply, total_demand, weather_system, storage_ratio)

	# Update rolling blackouts if in brownout
	if _stability.is_brownout:
		_stability.update_rolling_blackouts(_network.powered_cells, _network.distance_from_source)

	# Apply brownout efficiency penalty
	if _stability.is_brownout:
		total_supply *= _stability.brownout_efficiency

	# Update game state
	GameState.update_power(total_supply, total_demand)

	# Update storage state signal
	storage_state_changed.emit(_storage.total_stored_energy, _storage.total_storage_capacity, _storage.last_storage_delta)

	# Emit domain event with complete power state
	var power_event = DomainEvents.PowerStateChanged.new({
		"supply": total_supply,
		"demand": total_demand,
		"grid_stability": _stability.grid_stability,
		"stability_status": _stability.get_stability_status(),
		"grid_frequency": _stability.grid_frequency,
		"is_brownout": _stability.is_brownout,
		"brownout_severity": _stability.brownout_severity,
		"storage_percent": _storage.get_charge_percent(),
		"storage_charging": _storage.last_storage_delta > 0,
		"has_shortage": total_demand > total_supply,
		"blackout_cells": _stability.blackout_zones.size()
	})
	Events.power_state_changed.emit(power_event)

	# Emit legacy signal for backward compatibility
	Events.power_updated.emit(total_supply, total_demand)

	# Update building power status
	_update_building_power_status()


func _update_power_network() -> void:
	# Configure network settings
	_network.max_efficient_distance = _get_max_efficient_distance()
	_network.efficiency_falloff = _get_efficiency_falloff()
	_network.min_efficiency = _get_min_efficiency()

	# Update network connectivity
	_network.update_network(power_sources, _storage.storage_buildings, grid_system)


func _update_building_power_status() -> void:
	var power_available = not GameState.has_power_shortage()

	if grid_system:
		var updated_buildings = {}
		for cell in grid_system.get_building_cells():
			var building = grid_system.get_building_at(cell)
			if not is_instance_valid(building) or updated_buildings.has(building):
				continue
			updated_buildings[building] = true

			if not building.building_data:
				continue

			if not building.building_data.requires_power:
				building.set_powered(true)
				continue

			var has_power_connection = is_cell_powered(building.grid_cell)
			var is_blacked_out = _stability.is_cell_blacked_out(building.grid_cell)
			var is_storm_damaged = _storm_damage.is_cell_storm_damaged(building.grid_cell)

			building.set_powered(has_power_connection and power_available and not is_blacked_out and not is_storm_damaged)


# ============================================
# QUERY FUNCTIONS (Public API)
# ============================================

func is_cell_powered(cell: Vector2i) -> bool:
	return _network.is_cell_powered(cell)


func get_power_at_cell(cell: Vector2i) -> float:
	if not is_cell_powered(cell):
		return 0.0
	return GameState.get_available_power()


func get_powered_cells() -> Dictionary:
	return _network.powered_cells


func get_power_efficiency_at(cell: Vector2i) -> float:
	return _network.get_efficiency_at(cell)


func get_distance_from_source(cell: Vector2i) -> int:
	return _network.get_distance_from_source(cell)


func get_total_efficiency_loss() -> float:
	return _network.get_total_efficiency_loss(grid_system)


# ============================================
# STORAGE QUERY FUNCTIONS
# ============================================

func get_storage_info() -> Dictionary:
	return _storage.get_storage_info()


func get_storage_by_building(building: Node2D) -> Dictionary:
	return _storage.get_storage_by_building(building)


# ============================================
# GRID STABILITY QUERY FUNCTIONS
# ============================================

func get_grid_stability() -> float:
	return _stability.grid_stability


func get_grid_frequency() -> float:
	return _stability.grid_frequency


func get_stability_status() -> String:
	return _stability.get_stability_status()


func is_grid_stable() -> bool:
	return _stability.is_grid_stable()


func get_brownout_info() -> Dictionary:
	return _stability.get_brownout_info()


func get_save_data() -> Dictionary:
	var damaged_cells_data: Dictionary = {}
	for cell in storm_damaged_cells:
		damaged_cells_data["%d,%d" % [cell.x, cell.y]] = storm_damaged_cells[cell]

	var storage_data: Dictionary = {}
	if storage_state:
		for id in storage_state:
			storage_data[str(id)] = storage_state[id].duplicate()

	return {
		"storm_outage_active": storm_outage_active,
		"storm_outage_severity": storm_outage_severity,
		"storm_repair_rate": storm_repair_rate,
		"outage_restoration_progress": outage_restoration_progress,
		"storm_damaged_cells": damaged_cells_data,
		"grid_stability": grid_stability,
		"is_brownout": is_brownout,
		"brownout_severity": brownout_severity,
		"storage_state": storage_data,
		"total_stored_energy": total_stored_energy
	}


func load_save_data(data: Dictionary) -> void:
	storm_outage_active = data.get("storm_outage_active", false)
	storm_outage_severity = data.get("storm_outage_severity", 0.0)
	storm_repair_rate = data.get("storm_repair_rate", 0.0)
	outage_restoration_progress = data.get("outage_restoration_progress", 0.0)

	storm_damaged_cells.clear()
	var damaged_cells_data = data.get("storm_damaged_cells", {})
	for key in damaged_cells_data:
		var parts = key.split(",")
		if parts.size() == 2:
			var cell = Vector2i(int(parts[0]), int(parts[1]))
			storm_damaged_cells[cell] = damaged_cells_data[key]

	grid_stability = data.get("grid_stability", 1.0)
	is_brownout = data.get("is_brownout", false)
	brownout_severity = data.get("brownout_severity", 0.0)

	total_stored_energy = data.get("total_stored_energy", 0.0)
	var storage_data = data.get("storage_state", {})
	for id_str in storage_data:
		var id = int(id_str)
		if storage_state.has(id):
			var saved = storage_data[id_str]
			storage_state[id].charge = saved.get("charge", 0.0)
			storage_state[id].cycles = saved.get("cycles", 0)


func get_grid_info() -> Dictionary:
	return _stability.get_grid_info()


# ============================================
# STORM OUTAGE QUERY FUNCTIONS
# ============================================

func get_outage_severity() -> float:
	return _storm_damage.get_outage_severity()


func get_storm_outage_info() -> Dictionary:
	return _storm_damage.get_storm_outage_info()


func is_cell_storm_damaged(cell: Vector2i) -> bool:
	return _storm_damage.is_cell_storm_damaged(cell)


# ============================================
# BACKWARD COMPATIBILITY PROPERTIES
# ============================================

# Expose internal state for save/load compatibility
var powered_cells: Dictionary:
	get: return _network.powered_cells

var power_line_cells: Dictionary:
	get: return _network.power_line_cells
	set(value): _network.power_line_cells = value

var road_cells: Dictionary:
	get: return _network.road_cells
	set(value): _network.road_cells = value

var distance_from_source: Dictionary:
	get: return _network.distance_from_source

var storage_buildings: Array[Node2D]:
	get: return _storage.storage_buildings

var storage_state: Dictionary:
	get: return _storage.storage_state
	set(value): _storage.storage_state = value

var total_storage_capacity: float:
	get: return _storage.total_storage_capacity

var total_stored_energy: float:
	get: return _storage.total_stored_energy

var last_storage_delta: float:
	get: return _storage.last_storage_delta

var grid_stability: float:
	get: return _stability.grid_stability

var grid_frequency: float:
	get: return _stability.grid_frequency

var supply_demand_ratio: float:
	get: return _stability.supply_demand_ratio

var is_brownout: bool:
	get: return _stability.is_brownout

var brownout_severity: float:
	get: return _stability.brownout_severity

var blackout_zones: Array[Vector2i]:
	get: return _stability.blackout_zones

var brownout_efficiency: float:
	get: return _stability.brownout_efficiency

var peak_demand_today: float:
	get: return _stability.peak_demand_today

var storm_outage_active: bool:
	get: return _storm_damage.storm_outage_active

var storm_outage_severity: float:
	get: return _storm_damage.storm_outage_severity

var storm_damaged_cells: Dictionary:
	get: return _storm_damage.storm_damaged_cells
	set(value): _storm_damage.storm_damaged_cells = value

var storm_repair_rate: float:
	get: return _storm_damage.storm_repair_rate

var outage_restoration_progress: float:
	get: return _storm_damage.outage_restoration_progress
