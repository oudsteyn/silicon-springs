extends Node
class_name WaterSystem
## Manages water supply, distribution, and consumption with dynamic pressure modeling

var grid_system = null  # GridSystem
var weather_system = null  # WeatherSystem
var infrastructure_age_system = null  # InfrastructureAgeSystem

# Water network tracking
var water_sources: Array[Node2D] = []  # Buildings that produce water
var water_consumers: Array[Node2D] = []  # Buildings that consume water
var watered_cells: Dictionary = {}  # {Vector2i: bool}

# Water pipe connectivity
var water_pipe_cells: Dictionary = {}  # {Vector2i: true}
var road_cells: Dictionary = {}  # {Vector2i: true} - roads conduct water

# Distance from water source tracking for efficiency penalties
var distance_from_source: Dictionary = {}  # {Vector2i: int}

# ============================================
# CONFIGURATION (from GameConfig)
# ============================================

func _get_max_efficient_distance() -> int:
	return GameConfig.water_max_efficient_distance if GameConfig else 25


func _get_efficiency_falloff() -> float:
	return GameConfig.water_efficiency_falloff if GameConfig else 0.025


func _get_min_efficiency() -> float:
	return GameConfig.water_min_efficiency if GameConfig else 0.5

# System-wide pressure tracking
var system_pressure: float = 1.0  # 0.0 to 1.0, where 1.0 is optimal pressure
var pressure_ratio: float = 1.0  # supply/demand ratio
const PRESSURE_WARNING_THRESHOLD: float = 0.85  # Warn when pressure drops below this
const PRESSURE_CRITICAL_THRESHOLD: float = 0.6  # Critical when below this
const PRESSURE_FAILURE_THRESHOLD: float = 0.4  # Distant buildings lose water below this

# Pressure infrastructure
var water_towers: Array[Node2D] = []  # Provide storage buffer and pressure head
var pumping_stations: Array[Node2D] = []  # Boost pressure in the network
var pressure_boost: float = 0.0  # Total boost from infrastructure

# Infrastructure constants
const WATER_TOWER_PRESSURE_BOOST: float = 0.15  # Each tower adds 15% pressure buffer
const WATER_TOWER_STORAGE_BUFFER: float = 0.1  # Each tower provides 10% demand buffer
const PUMPING_STATION_BOOST: float = 0.1  # Each station adds 10% pressure boost
const MAX_INFRASTRUCTURE_BOOST: float = 0.4  # Cap on total infrastructure boost


func _ready() -> void:
	Events.building_placed.connect(_on_building_placed)
	Events.building_removed.connect(_on_building_removed)


func set_grid_system(system) -> void:
	grid_system = system


func set_weather_system(system) -> void:
	weather_system = system


func set_infrastructure_age_system(system) -> void:
	infrastructure_age_system = system


func _on_building_placed(cell: Vector2i, building: Node2D) -> void:
	if not building.building_data:
		return

	var data = building.building_data

	# Track water sources
	if data.water_production > 0:
		water_sources.append(building)

	# Track water consumers
	if data.water_consumption > 0 or data.requires_water:
		water_consumers.append(building)

	# Track pressure infrastructure
	if data.building_type == "water_tower":
		water_towers.append(building)
		_recalculate_pressure_boost()
	if data.building_type == "pumping_station":
		pumping_stations.append(building)
		_recalculate_pressure_boost()

	# Track water pipes
	if GridConstants.is_water_type(data.building_type):
		water_pipe_cells[cell] = true

	# Track roads (roads conduct water between adjacent buildings)
	if GridConstants.is_road_type(data.building_type):
		road_cells[cell] = true

	# Recalculate network and immediately update water status
	_update_water_network()
	_update_building_water_status()


func _on_building_removed(cell: Vector2i, building: Node2D) -> void:
	if not building or not building.building_data:
		return

	var data = building.building_data

	# Remove from tracking
	water_sources.erase(building)
	water_consumers.erase(building)
	water_towers.erase(building)
	pumping_stations.erase(building)

	if data.building_type in ["water_tower", "pumping_station"]:
		_recalculate_pressure_boost()

	if GridConstants.is_water_type(data.building_type):
		water_pipe_cells.erase(cell)

	if GridConstants.is_road_type(data.building_type):
		road_cells.erase(cell)

	_update_water_network()
	_update_building_water_status()


func _recalculate_pressure_boost() -> void:
	## Calculate total pressure boost from water towers and pumping stations
	pressure_boost = 0.0

	# Water towers provide pressure through elevation (gravity head)
	for tower in water_towers:
		if is_instance_valid(tower) and tower.is_operational:
			pressure_boost += WATER_TOWER_PRESSURE_BOOST

	# Pumping stations actively boost pressure
	for station in pumping_stations:
		if is_instance_valid(station) and station.is_operational:
			pressure_boost += PUMPING_STATION_BOOST

	# Cap the boost
	pressure_boost = minf(pressure_boost, MAX_INFRASTRUCTURE_BOOST)


func calculate_water() -> void:
	var total_supply = 0.0
	var total_demand = 0.0

	# Get weather multipliers
	var water_supply_mult = 1.0  # Biome scarcity affects supply
	var water_demand_mult = 1.0  # Temperature affects demand
	var drought_mult = 1.0  # Drought reduces groundwater availability
	if weather_system:
		if weather_system.has_method("get_water_multiplier"):
			water_supply_mult = weather_system.get_water_multiplier()
		if weather_system.has_method("get_water_demand_multiplier"):
			water_demand_mult = weather_system.get_water_demand_multiplier()
		if weather_system.has_method("get_drought_water_multiplier"):
			drought_mult = weather_system.get_drought_water_multiplier()

	# Combine supply multipliers (biome scarcity + drought)
	water_supply_mult *= drought_mult

	# Calculate total supply from working water sources
	for source in water_sources:
		if is_instance_valid(source) and source.is_operational:
			var production = source.building_data.water_production

			# Apply biome water scarcity multiplier
			production *= water_supply_mult

			total_supply += production

	# Calculate base demand (before pressure effects)
	var base_building_demand = 0.0
	for consumer in water_consumers:
		if is_instance_valid(consumer):
			base_building_demand += consumer.building_data.water_consumption

	# Population water demand (10 ML per 100 population)
	# Weather affects population water usage (cooling, drinking, irrigation)
	var population_demand = (GameState.population / 100.0) * 10.0 * water_demand_mult

	# Commercial water demand (also affected by weather)
	var commercial_demand = GameState.commercial_zones * 20.0 * water_demand_mult

	# Industrial water demand is less affected by weather (process water)
	var industrial_weather_mult = 1.0 + (water_demand_mult - 1.0) * 0.3  # Only 30% of weather effect
	var industrial_demand = GameState.industrial_zones * 15.0 * industrial_weather_mult

	# Calculate raw demand before efficiency losses
	var raw_demand = base_building_demand + population_demand + commercial_demand + industrial_demand

	# Add neighbor deal effects to supply
	total_supply += NeighborDeals.get_effective_water_bought()
	total_supply -= NeighborDeals.get_effective_water_sold()

	# Calculate water tower storage buffer
	# Water towers can cover short-term demand spikes
	var storage_buffer = 0.0
	for tower in water_towers:
		if is_instance_valid(tower) and tower.is_operational:
			storage_buffer += WATER_TOWER_STORAGE_BUFFER

	# Effective supply includes storage buffer as percentage of demand
	var effective_supply = total_supply + (raw_demand * storage_buffer)

	# Infrastructure aging causes water leaks from degraded pipes
	if infrastructure_age_system:
		var leak_rate = infrastructure_age_system.get_water_leak_rate()
		if leak_rate > 0:
			# Leaking pipes reduce effective supply
			var water_lost = effective_supply * leak_rate
			effective_supply -= water_lost
			# Emit warning if losses are significant
			if leak_rate > 0.1:
				Events.simulation_event.emit("water_pipe_leaks", {
					"loss_rate": int(leak_rate * 100),
					"message": "Aging pipes leaking %d%% of water supply" % int(leak_rate * 100)
				})

	# Calculate system-wide pressure based on supply/demand ratio
	# This affects how well water reaches distant buildings
	var previous_pressure = system_pressure
	if raw_demand > 0:
		pressure_ratio = effective_supply / raw_demand
	else:
		pressure_ratio = 1.0

	# Base system pressure from supply/demand balance
	# pressure_ratio of 1.0 = balanced, >1.0 = surplus, <1.0 = deficit
	var base_pressure: float
	if pressure_ratio >= 1.2:
		base_pressure = 1.0  # Plenty of headroom
	elif pressure_ratio >= 1.0:
		base_pressure = 0.9 + (pressure_ratio - 1.0) * 0.5  # 0.9 to 1.0
	elif pressure_ratio >= 0.8:
		base_pressure = 0.7 + (pressure_ratio - 0.8) * 1.0  # 0.7 to 0.9
	elif pressure_ratio >= 0.5:
		base_pressure = 0.3 + (pressure_ratio - 0.5) * 1.33  # 0.3 to 0.7
	else:
		base_pressure = pressure_ratio * 0.6  # 0.0 to 0.3

	# Apply infrastructure pressure boost
	# Towers and pumping stations help maintain pressure even under high demand
	_recalculate_pressure_boost()
	system_pressure = base_pressure + pressure_boost

	system_pressure = clampf(system_pressure, 0.0, 1.0)

	# Emit pressure warnings
	_check_pressure_warnings(previous_pressure)

	# Now calculate actual demand with pressure-adjusted efficiency
	total_demand = 0.0
	for consumer in water_consumers:
		if is_instance_valid(consumer):
			var base_consumption = consumer.building_data.water_consumption
			var efficiency = get_water_efficiency_at(consumer.grid_cell)
			# Lower efficiency means more water needed due to pressure loss
			total_demand += base_consumption / efficiency

	# Add zone demands
	total_demand += population_demand + commercial_demand + industrial_demand

	# Add pipeline loss from distance (also affected by system pressure)
	total_demand += get_total_efficiency_loss()

	GameState.update_water(total_supply, total_demand)

	# Emit domain event with complete water state
	var drought_active = false
	var drought_severity = 0.0
	if weather_system and weather_system.has_method("is_drought_active"):
		drought_active = weather_system.is_drought_active()
	if weather_system and weather_system.has_method("get_drought_severity"):
		drought_severity = weather_system.get_drought_severity()

	var water_event = DomainEvents.WaterStateChanged.new({
		"supply": total_supply,
		"demand": total_demand,
		"pressure": system_pressure,
		"pressure_status": get_pressure_status(),
		"has_shortage": total_demand > total_supply,
		"drought_active": drought_active,
		"drought_severity": drought_severity
	})
	Events.water_state_changed.emit(water_event)

	# Emit legacy signal for backward compatibility
	Events.water_updated.emit(total_supply, total_demand)

	# Update building operational status based on water AND pressure
	_update_building_water_status()


func _check_pressure_warnings(previous_pressure: float) -> void:
	# Warn when pressure drops to concerning levels
	if system_pressure < PRESSURE_CRITICAL_THRESHOLD and previous_pressure >= PRESSURE_CRITICAL_THRESHOLD:
		Events.simulation_event.emit("water_pressure_critical", {
			"pressure": int(system_pressure * 100),
			"message": "Critical water pressure! Distant buildings losing service."
		})
	elif system_pressure < PRESSURE_WARNING_THRESHOLD and previous_pressure >= PRESSURE_WARNING_THRESHOLD:
		Events.simulation_event.emit("water_pressure_low", {
			"pressure": int(system_pressure * 100),
			"message": "Water pressure dropping. Consider expanding water infrastructure."
		})

	# Notify when pressure is restored
	if system_pressure >= PRESSURE_WARNING_THRESHOLD and previous_pressure < PRESSURE_WARNING_THRESHOLD:
		Events.simulation_event.emit("water_pressure_restored", {
			"pressure": int(system_pressure * 100)
		})


func _update_water_network() -> void:
	watered_cells.clear()
	distance_from_source.clear()

	if not grid_system:
		return

	# Sync road cells from grid system
	road_cells = grid_system.road_cells.duplicate()

	# Start from each water source and flood-fill through water pipes
	for source in water_sources:
		if is_instance_valid(source):
			_flood_fill_water(source.grid_cell)


func _flood_fill_water(start_cell: Vector2i) -> void:
	# Use a dictionary to track cells and their distances
	var to_visit: Array = [[start_cell, 0]]  # [cell, distance]
	var visited: Dictionary = {}

	while to_visit.size() > 0:
		var current = to_visit.pop_front()
		var cell: Vector2i = current[0]
		var distance: int = current[1]

		if visited.has(cell):
			continue
		visited[cell] = true
		watered_cells[cell] = true

		# Track minimum distance from any water source
		if not distance_from_source.has(cell) or distance < distance_from_source[cell]:
			distance_from_source[cell] = distance

		# If this cell has a building, mark ALL cells of that building as watered
		# and add them to visit queue so water spreads through buildings
		if grid_system and grid_system.buildings.has(cell):
			var building = grid_system.buildings[cell]
			if is_instance_valid(building) and building.building_data:
				var building_size = building.building_data.size
				var origin = building.grid_cell
				for bx in range(building_size.x):
					for by in range(building_size.y):
						var building_cell = origin + Vector2i(bx, by)
						watered_cells[building_cell] = true
						if not distance_from_source.has(building_cell) or distance < distance_from_source[building_cell]:
							distance_from_source[building_cell] = distance
						if not visited.has(building_cell):
							to_visit.append([building_cell, distance])

		# Check adjacent cells (distance increases by 1)
		var neighbors = [
			cell + Vector2i(1, 0),
			cell + Vector2i(-1, 0),
			cell + Vector2i(0, 1),
			cell + Vector2i(0, -1)
		]

		for neighbor in neighbors:
			if visited.has(neighbor):
				continue

			# Water flows through water pipes
			if water_pipe_cells.has(neighbor):
				to_visit.append([neighbor, distance + 1])
				continue

			# Water flows through roads
			if road_cells.has(neighbor):
				to_visit.append([neighbor, distance + 1])
				continue

			# Water flows through ANY adjacent building (SimCity-style)
			if grid_system:
				if grid_system.buildings.has(neighbor):
					to_visit.append([neighbor, distance + 1])
					continue
				# Also check utility overlays (power lines/water pipes on roads)
				if grid_system.utility_overlays.has(neighbor):
					var overlay = grid_system.utility_overlays[neighbor]
					if is_instance_valid(overlay) and overlay.building_data:
						# Water flows through water pipes on roads
						if GridConstants.is_water_type(overlay.building_data.building_type):
							to_visit.append([neighbor, distance + 1])


func _update_building_water_status() -> void:
	var water_available = not GameState.has_water_shortage()

	# Update ALL buildings, not just tracked consumers
	if grid_system:
		var updated_buildings = {}
		for cell in grid_system.buildings:
			var building = grid_system.buildings[cell]
			if not is_instance_valid(building) or updated_buildings.has(building):
				continue
			updated_buildings[building] = true

			if not building.building_data:
				continue

			# Skip buildings that don't require water
			if not building.building_data.requires_water:
				building.set_watered(true)
				continue

			# Building needs water connection AND sufficient supply AND adequate pressure
			var has_water_connection = is_cell_watered(building.grid_cell)

			if not has_water_connection:
				building.set_watered(false)
				continue

			# Check if pressure is adequate for this building
			var cell_pressure = get_pressure_at_cell(building.grid_cell)

			# Buildings need minimum pressure to function
			# Critical infrastructure (hospitals, fire stations) need higher pressure
			var min_pressure_needed = 0.3
			if building.building_data.building_type in ["hospital", "fire_station", "water_treatment"]:
				min_pressure_needed = 0.5

			var has_adequate_pressure = cell_pressure >= min_pressure_needed

			building.set_watered(water_available and has_adequate_pressure)


func is_cell_watered(cell: Vector2i) -> bool:
	# Direct water from adjacent pipe or water source
	if watered_cells.has(cell):
		return true

	# Check adjacent cells for water
	var neighbors = [
		cell + Vector2i(1, 0),
		cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(0, -1)
	]

	for neighbor in neighbors:
		if watered_cells.has(neighbor):
			return true

	return false


func get_water_at_cell(cell: Vector2i) -> float:
	if not is_cell_watered(cell):
		return 0.0
	return GameState.get_available_water()


func get_watered_cells() -> Dictionary:
	return watered_cells


func get_water_efficiency_at(cell: Vector2i) -> float:
	# Returns efficiency multiplier (0.0 to 1.0) based on distance from water source
	# AND current system-wide pressure
	if not distance_from_source.has(cell):
		return 1.0  # Assume full efficiency if not tracked

	var distance = distance_from_source[cell]

	# Base efficiency from distance (pipe friction losses)
	var distance_efficiency = 1.0
	var max_dist = _get_max_efficient_distance()
	if distance > max_dist:
		var excess_distance = distance - max_dist
		distance_efficiency = 1.0 - (excess_distance * _get_efficiency_falloff())
		distance_efficiency = maxf(_get_min_efficiency(), distance_efficiency)

	# System pressure affects efficiency, especially for distant buildings
	# When system pressure is low, distant buildings suffer more
	var pressure_factor = 1.0
	if system_pressure < 1.0:
		# Distance amplifies pressure problems
		# Close buildings (distance < 10) barely affected
		# Distant buildings (distance > 30) heavily affected
		var distance_vulnerability = clampf((distance - 10.0) / 30.0, 0.0, 1.0)
		pressure_factor = lerp(1.0, system_pressure, distance_vulnerability)

	var total_efficiency = distance_efficiency * pressure_factor
	return maxf(0.2, total_efficiency)  # Minimum 20% efficiency


func get_pressure_at_cell(cell: Vector2i) -> float:
	## Returns the effective water pressure at a specific cell (0.0 to 1.0)
	if not distance_from_source.has(cell):
		return 0.0  # No water connection

	var distance = distance_from_source[cell]

	# Base pressure from system
	var pressure = system_pressure

	# Distance reduces pressure
	var max_dist = _get_max_efficient_distance()
	if distance > max_dist:
		var excess = distance - max_dist
		pressure -= excess * _get_efficiency_falloff()  # Pressure drop per tile beyond max

	# Very close to source maintains good pressure even when system is stressed
	if distance < 5:
		pressure = maxf(pressure, system_pressure * 1.1)

	return clampf(pressure, 0.0, 1.0)


func get_system_pressure() -> float:
	return system_pressure


func get_pressure_status() -> String:
	if system_pressure >= 0.95:
		return "Optimal"
	elif system_pressure >= PRESSURE_WARNING_THRESHOLD:
		return "Good"
	elif system_pressure >= PRESSURE_CRITICAL_THRESHOLD:
		return "Low"
	elif system_pressure >= PRESSURE_FAILURE_THRESHOLD:
		return "Critical"
	else:
		return "Failing"


func get_pressure_boost() -> float:
	return pressure_boost


func get_water_tower_count() -> int:
	var count = 0
	for tower in water_towers:
		if is_instance_valid(tower) and tower.is_operational:
			count += 1
	return count


func get_pumping_station_count() -> int:
	var count = 0
	for station in pumping_stations:
		if is_instance_valid(station) and station.is_operational:
			count += 1
	return count


func get_pressure_info() -> Dictionary:
	## Returns comprehensive pressure information for UI display
	return {
		"pressure": system_pressure,
		"pressure_pct": int(system_pressure * 100),
		"status": get_pressure_status(),
		"ratio": pressure_ratio,
		"boost": pressure_boost,
		"boost_pct": int(pressure_boost * 100),
		"towers": get_water_tower_count(),
		"pumps": get_pumping_station_count(),
		"is_critical": system_pressure < PRESSURE_CRITICAL_THRESHOLD,
		"is_warning": system_pressure < PRESSURE_WARNING_THRESHOLD
	}


func get_distance_from_source(cell: Vector2i) -> int:
	return distance_from_source.get(cell, -1)


func get_total_efficiency_loss() -> float:
	# Returns the total water lost to pipeline inefficiency
	if not grid_system or distance_from_source.size() == 0:
		return 0.0

	var total_loss = 0.0
	var counted = {}

	for cell in grid_system.buildings:
		var building = grid_system.buildings[cell]
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if building.building_data and building.building_data.water_consumption > 0:
			var efficiency = get_water_efficiency_at(building.grid_cell)
			if efficiency < 1.0:
				# Inefficiency means we need MORE water to deliver the same amount
				var extra_needed = building.building_data.water_consumption * (1.0 / efficiency - 1.0)
				total_loss += extra_needed

	return total_loss
