extends Node
class_name PollutionSystem
## Manages pollution from buildings and its effects on land value and happiness
## Integrates with weather system for wind dispersion, rain settling, and temperature inversions

var grid_system = null
var weather_system = null
var traffic_system = null

# Pollution map: {Vector2i: pollution_level (0.0 to 1.0)}
var pollution_map: Dictionary = {}

# Traffic-based pollution tracking
var traffic_pollution_map: Dictionary = {}  # Vector2i -> float

# Green infrastructure pollution absorption
var green_infrastructure_cells: Dictionary = {}  # Vector2i -> absorption_rate

# Background pollution from weather effects (separate from source pollution)
var ambient_pollution: Dictionary = {}  # Vector2i -> float

# Buildings that produce pollution
var polluters: Array[Node2D] = []

# Air quality state
var current_aqi: float = 0.0  # 0-500 scale (EPA standard)
var air_quality_category: String = "Good"
var smog_alert_active: bool = false

# Temperature inversion tracking
var inversion_active: bool = false
var inversion_strength: float = 0.0  # 0-1, how severe the inversion

# Weather effect accumulators (reset each month)
var rain_accumulation: float = 0.0  # How much rain has fallen
var wind_dispersion_factor: float = 1.0  # How much wind is dispersing pollution

# ============================================
# CONFIGURATION (from GameConfig)
# ============================================

func _get_wind_dispersion_base() -> float:
	return GameConfig.pollution_wind_dispersion_base if GameConfig else 0.02


func _get_rain_settling_rate() -> float:
	return GameConfig.pollution_rain_settling_rate if GameConfig else 0.15


func _get_inversion_trap_mult() -> float:
	return GameConfig.pollution_inversion_trap_mult if GameConfig else 1.5


func _get_max_ambient_pollution() -> float:
	return GameConfig.pollution_max_ambient if GameConfig else 0.6


func _get_pollution_decay_rate() -> float:
	return GameConfig.pollution_decay_rate if GameConfig else 0.05

# ============================================
# WILDFIRE SMOKE SYSTEM
# ============================================

# Wildfire tracking
var wildfire_active: bool = false
var wildfire_intensity: float = 0.0  # 0-1 scale
var wildfire_duration: int = 0  # Months active
var wildfire_smoke_contribution: float = 0.0  # Extra AQI from smoke

func _get_wildfire_base_risk() -> float:
	return GameConfig.wildfire_base_risk if GameConfig else 0.02


func _get_wildfire_temp_threshold() -> float:
	return GameConfig.wildfire_temp_threshold if GameConfig else 30.0


func _get_wildfire_humidity_threshold() -> float:
	return GameConfig.wildfire_humidity_threshold if GameConfig else 0.3


func _get_wildfire_max_duration() -> int:
	return GameConfig.wildfire_max_duration if GameConfig else 3


func _ready() -> void:
	Events.building_placed.connect(_on_building_placed)
	Events.building_removed.connect(_on_building_removed)
	Events.month_tick.connect(_on_month_tick)


func set_grid_system(system) -> void:
	grid_system = system


func set_weather_system(system) -> void:
	weather_system = system


func set_traffic_system(system) -> void:
	traffic_system = system


func _on_building_placed(_cell: Vector2i, building: Node2D) -> void:
	if not building.building_data:
		return

	var data = building.building_data
	if data.pollution_radius > 0:
		polluters.append(building)
		_update_pollution_map()


func _on_building_removed(_cell: Vector2i, building: Node2D) -> void:
	if not building or not building.building_data:
		return

	polluters.erase(building)
	_update_pollution_map()


func _update_pollution_map() -> void:
	pollution_map.clear()

	for polluter in polluters:
		if not is_instance_valid(polluter):
			continue

		# Only operational buildings produce pollution
		if not polluter.is_operational:
			continue

		var data = polluter.building_data
		var center = polluter.grid_cell
		var radius = data.pollution_radius

		# Use pre-computed coverage mask for O(r²) instead of O(r²) with sqrt
		var mask = SpatialHash.get_coverage_mask_with_strength(radius)
		for entry in mask:
			var cell = center + entry.offset
			# Pollution strength decreases with distance
			var strength = entry.strength * 0.8  # Max pollution is 0.8

			# Accumulate pollution from multiple sources
			if pollution_map.has(cell):
				pollution_map[cell] = minf(1.0, pollution_map[cell] + strength)
			else:
				pollution_map[cell] = strength

	Events.pollution_updated.emit()


func _update_traffic_pollution() -> void:
	## Add pollution from traffic congestion
	## Heavy traffic on roads generates vehicle emissions
	if not traffic_system or not grid_system:
		return

	traffic_pollution_map.clear()

	# Get all road cells and their congestion levels
	for cell in grid_system.road_cells:
		var congestion = traffic_system.get_congestion_at(cell) if traffic_system.has_method("get_congestion_at") else 0.0

		# Only significant traffic generates noticeable pollution
		if congestion < 0.3:
			continue

		# Congestion-based pollution (gridlock = more idling = more emissions)
		var traffic_emission = congestion * 0.3  # Max 30% pollution from traffic

		# Heavy congestion (60%+) causes even more pollution from stop-and-go
		if congestion > 0.6:
			traffic_emission += (congestion - 0.6) * 0.2

		traffic_pollution_map[cell] = traffic_emission

		# Traffic pollution spreads to adjacent cells (exhaust disperses)
		var neighbors = [
			cell + Vector2i(1, 0),
			cell + Vector2i(-1, 0),
			cell + Vector2i(0, 1),
			cell + Vector2i(0, -1)
		]

		for neighbor in neighbors:
			var spread_amount = traffic_emission * 0.3  # 30% spreads to neighbors
			if traffic_pollution_map.has(neighbor):
				traffic_pollution_map[neighbor] = maxf(traffic_pollution_map[neighbor], spread_amount)
			else:
				traffic_pollution_map[neighbor] = spread_amount

	# Merge traffic pollution into main pollution map
	for cell in traffic_pollution_map:
		var current = pollution_map.get(cell, 0.0)
		pollution_map[cell] = minf(1.0, current + traffic_pollution_map[cell])


func _apply_green_infrastructure() -> void:
	## Parks, trees, and green buildings absorb pollution
	## This reduces pollution in nearby cells
	if not grid_system:
		return

	green_infrastructure_cells.clear()

	# Find all green infrastructure
	var counted = {}
	for cell in grid_system.buildings:
		var building = grid_system.buildings[cell]
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data or not building.is_operational:
			continue

		var absorption_rate = 0.0

		# Parks absorb pollution
		if building.building_data.building_type in ["park", "garden", "plaza"]:
			absorption_rate = 0.15  # 15% pollution reduction

		# Trees in parks are more effective
		if building.building_data.happiness_modifier > 0:
			absorption_rate += building.building_data.happiness_modifier * 0.1

		# Eco-friendly buildings
		if building.building_data.get("eco_friendly"):
			absorption_rate = 0.05

		if absorption_rate > 0:
			# Mark all cells of this building as green infrastructure
			var size = building.building_data.size
			for x in range(size.x):
				for y in range(size.y):
					var bc = building.grid_cell + Vector2i(x, y)
					green_infrastructure_cells[bc] = absorption_rate

	# Apply pollution absorption from green infrastructure
	# Use pre-computed mask for radius 2
	var green_mask = SpatialHash.get_coverage_mask_with_strength(2)

	for green_cell in green_infrastructure_cells:
		var absorption = green_infrastructure_cells[green_cell]

		# Reduce pollution in this cell and nearby cells using pre-computed mask
		for entry in green_mask:
			var target = green_cell + entry.offset
			if not pollution_map.has(target):
				continue

			var effectiveness = absorption * entry.strength
			pollution_map[target] = maxf(0.0, pollution_map[target] - effectiveness)

			# Also reduce ambient pollution
			if ambient_pollution.has(target):
				ambient_pollution[target] = maxf(0.0, ambient_pollution[target] - effectiveness * 0.5)


func update_pollution() -> void:
	_update_pollution_map()
	_update_traffic_pollution()
	_apply_green_infrastructure()


func get_pollution_at(cell: Vector2i) -> float:
	return pollution_map.get(cell, 0.0)


func has_pollution(cell: Vector2i) -> bool:
	return pollution_map.has(cell) and pollution_map[cell] > 0.1


func get_average_pollution() -> float:
	if pollution_map.size() == 0:
		return 0.0

	var total = 0.0
	for cell in pollution_map:
		total += pollution_map[cell]
	return total / pollution_map.size()


func get_city_pollution_score() -> float:
	# Returns 0-1 score where 0 = heavily polluted, 1 = clean
	if not grid_system:
		return 1.0

	var total_pollution = 0.0
	var cell_count = 0

	# Check pollution at residential and commercial zones
	for cell in grid_system.buildings:
		var building = grid_system.buildings[cell]
		if not is_instance_valid(building):
			continue

		var data = building.building_data
		if data and data.building_type in ["residential", "commercial"]:
			total_pollution += get_pollution_at(cell)
			cell_count += 1

	if cell_count == 0:
		return 1.0

	var avg_pollution = total_pollution / cell_count
	return 1.0 - avg_pollution


func get_pollution_map() -> Dictionary:
	return pollution_map


func get_residential_pollution_score() -> float:
	# Returns 0-1 score where 0 = heavily polluted residences, 1 = clean
	if not grid_system:
		return 1.0

	var total_pollution = 0.0
	var residential_count = 0
	var counted = {}

	for cell in grid_system.buildings:
		var building = grid_system.buildings[cell]
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		var data = building.building_data
		if data and data.building_type == "residential":
			total_pollution += get_pollution_at(cell)
			residential_count += 1

	if residential_count == 0:
		return 1.0

	var avg_pollution = total_pollution / residential_count
	return 1.0 - avg_pollution


func get_polluted_residential_count() -> int:
	# Count residential zones with significant pollution
	if not grid_system:
		return 0

	var count = 0
	var counted = {}

	for cell in grid_system.buildings:
		var building = grid_system.buildings[cell]
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		var data = building.building_data
		if data and data.building_type == "residential":
			if get_pollution_at(cell) > 0.3:  # Significant pollution
				count += 1

	return count


# ============================================
# WEATHER INTERACTION
# ============================================

func _on_month_tick() -> void:
	if weather_system:
		_process_weather_effects()
		_process_wildfire_risk()
	_update_air_quality()
	_check_smog_alert()


func _process_weather_effects() -> void:
	## Apply weather effects to pollution each month tick
	if not weather_system:
		return

	# Get current weather conditions
	var wind_speed = weather_system.get_wind_speed()
	var wind_direction = weather_system.get_wind_direction()
	var temperature = weather_system.get_temperature()
	var is_raining = weather_system.current_conditions in ["Rain", "Heavy Rain", "Storm"]
	var precipitation_intensity = 0.0

	if weather_system.forecast.size() > 0:
		precipitation_intensity = weather_system.forecast[0].precipitation_intensity

	# Check for temperature inversion
	_check_temperature_inversion(temperature, wind_speed)

	# Apply wind dispersion
	_apply_wind_dispersion(wind_speed, wind_direction)

	# Apply rain settling
	if is_raining:
		_apply_rain_settling(precipitation_intensity)

	# Natural decay (pollution dissipates over time)
	_apply_natural_decay()

	# If inversion is active, pollution accumulates
	if inversion_active:
		_apply_inversion_effect()

	Events.pollution_updated.emit()


func _check_temperature_inversion(_temperature: float, wind_speed: float) -> void:
	## Temperature inversions occur when:
	## - Low wind speeds (stagnant air)
	## - Clear nights in winter/fall (ground cools faster than air above)
	## - High pressure systems

	var was_active = inversion_active
	inversion_strength = 0.0

	if not weather_system:
		inversion_active = false
		return

	var pressure = weather_system.get_pressure()
	var cloud_cover = weather_system.get_cloud_cover()
	var month = GameState.current_month if GameState else 1

	# Conditions that favor inversions:
	# 1. High pressure (sinking air traps pollution)
	var pressure_factor = 0.0
	if pressure > 1025:
		pressure_factor = 0.4
	elif pressure > 1020:
		pressure_factor = 0.2

	# 2. Light winds (no mixing)
	var wind_factor = 0.0
	if wind_speed < 5:
		wind_factor = 0.4
	elif wind_speed < 10:
		wind_factor = 0.2
	elif wind_speed > 20:
		wind_factor = -0.2  # Strong winds break inversions

	# 3. Clear skies (especially at night - radiative cooling)
	var sky_factor = 0.0
	if cloud_cover < 0.2:
		sky_factor = 0.3
	elif cloud_cover < 0.4:
		sky_factor = 0.15

	# 4. Cold season (fall/winter inversions more common)
	var season_factor = 0.0
	if month in [10, 11, 12, 1, 2]:
		season_factor = 0.2
	elif month in [3, 9]:
		season_factor = 0.1

	# Calculate total inversion potential
	inversion_strength = pressure_factor + wind_factor + sky_factor + season_factor
	inversion_strength = clampf(inversion_strength, 0.0, 1.0)

	# Inversion is active if strength exceeds threshold
	inversion_active = inversion_strength > 0.5

	# Emit events on state change
	if inversion_active and not was_active:
		Events.simulation_event.emit("inversion_started", {
			"strength": inversion_strength,
			"pressure": pressure,
			"wind_speed": wind_speed
		})
	elif not inversion_active and was_active:
		Events.simulation_event.emit("inversion_ended", {})


func _apply_wind_dispersion(wind_speed: float, wind_direction: float) -> void:
	## Wind disperses pollution by:
	## 1. Reducing pollution intensity (dilution)
	## 2. Spreading pollution downwind

	if pollution_map.size() == 0:
		return

	# Calculate dispersion factor based on wind speed
	# Calm (<5 km/h) = minimal dispersion
	# Moderate (10-25 km/h) = good dispersion
	# Strong (>40 km/h) = excellent dispersion
	var dispersion = 0.0
	if wind_speed < 5:
		dispersion = 0.01
	elif wind_speed < 15:
		dispersion = _get_wind_dispersion_base() * wind_speed
	elif wind_speed < 40:
		dispersion = 0.3 + (wind_speed - 15) * 0.01
	else:
		dispersion = 0.5 + (wind_speed - 40) * 0.005

	dispersion = clampf(dispersion, 0.0, 0.7)
	wind_dispersion_factor = dispersion

	# Reduce pollution levels based on dispersion
	var cells_to_update: Array[Vector2i] = []
	var new_values: Array[float] = []

	for cell in pollution_map:
		var current = pollution_map[cell]
		var reduction = current * dispersion
		var new_value = current - reduction

		cells_to_update.append(cell)
		new_values.append(maxf(0.0, new_value))

	# Apply reductions
	for i in range(cells_to_update.size()):
		if new_values[i] < 0.01:
			pollution_map.erase(cells_to_update[i])
		else:
			pollution_map[cells_to_update[i]] = new_values[i]

	# Spread pollution downwind (create ambient pollution in downwind cells)
	_spread_pollution_downwind(wind_direction, dispersion * 0.5)


func _spread_pollution_downwind(wind_direction: float, spread_factor: float) -> void:
	## Move some pollution to cells downwind of the source
	## Wind direction is where wind comes FROM, so we spread in opposite direction

	if spread_factor < 0.05 or pollution_map.size() == 0:
		return

	# Convert wind direction (from) to spread direction (to)
	var spread_direction = fmod(wind_direction + 180.0, 360.0)

	# Calculate offset vector (how many cells downwind)
	var rad = deg_to_rad(spread_direction)
	var offset_x = round(cos(rad))  # East/West component
	var offset_y = round(sin(rad))  # North/South component
	var offset = Vector2i(int(offset_x), int(offset_y))

	if offset == Vector2i.ZERO:
		return

	# Spread pollution to adjacent downwind cells
	var additions: Dictionary = {}

	for cell in pollution_map:
		var amount = pollution_map[cell] * spread_factor * 0.3
		if amount < 0.02:
			continue

		# Spread to 1-2 cells downwind
		var target1 = cell + offset
		var target2 = cell + offset * 2

		if not additions.has(target1):
			additions[target1] = 0.0
		additions[target1] += amount

		if not additions.has(target2):
			additions[target2] = 0.0
		additions[target2] += amount * 0.3  # Less at greater distance

	# Add ambient pollution
	for cell in additions:
		var current = ambient_pollution.get(cell, 0.0)
		ambient_pollution[cell] = minf(_get_max_ambient_pollution(), current + additions[cell])


func _apply_rain_settling(intensity: float) -> void:
	## Rain washes pollution out of the air
	## Heavier rain = more effective settling

	var settling_rate = _get_rain_settling_rate() * intensity
	rain_accumulation += intensity

	# Reduce both source pollution and ambient pollution
	var cells_to_remove: Array[Vector2i] = []

	for cell in pollution_map:
		pollution_map[cell] *= (1.0 - settling_rate)
		if pollution_map[cell] < 0.01:
			cells_to_remove.append(cell)

	for cell in cells_to_remove:
		pollution_map.erase(cell)

	# Clear ambient pollution more effectively
	cells_to_remove.clear()
	for cell in ambient_pollution:
		ambient_pollution[cell] *= (1.0 - settling_rate * 1.5)
		if ambient_pollution[cell] < 0.01:
			cells_to_remove.append(cell)

	for cell in cells_to_remove:
		ambient_pollution.erase(cell)

	# Emit notification for significant rain clearing
	if intensity > 0.5 and pollution_map.size() > 0:
		Events.simulation_event.emit("rain_clearing_pollution", {
			"intensity": intensity,
			"reduction": settling_rate * 100
		})


func _apply_natural_decay() -> void:
	## Pollution naturally decays over time (atmospheric dilution)

	var cells_to_remove: Array[Vector2i] = []

	for cell in ambient_pollution:
		ambient_pollution[cell] *= (1.0 - _get_pollution_decay_rate())
		if ambient_pollution[cell] < 0.01:
			cells_to_remove.append(cell)

	for cell in cells_to_remove:
		ambient_pollution.erase(cell)


func _apply_inversion_effect() -> void:
	## During inversions, pollution accumulates instead of dispersing

	# Boost all pollution levels slightly
	var boost = 0.05 * inversion_strength

	for cell in pollution_map:
		pollution_map[cell] = minf(1.0, pollution_map[cell] * (1.0 + boost))

	# Ambient pollution also builds up
	for cell in ambient_pollution:
		ambient_pollution[cell] = minf(_get_max_ambient_pollution(),
			ambient_pollution[cell] * (1.0 + boost * 0.5))


# ============================================
# WILDFIRE PROCESSING
# ============================================

func _process_wildfire_risk() -> void:
	## Calculate wildfire risk and manage active wildfires
	## Wildfires are more common in hot, dry summer months

	if not weather_system:
		return

	var month = GameState.current_month if GameState else 6
	var temperature = weather_system.get_temperature() if weather_system.has_method("get_temperature") else 20.0
	var humidity = weather_system.get_humidity() if weather_system.has_method("get_humidity") else 0.5
	var wind_speed = weather_system.get_wind_speed() if weather_system.has_method("get_wind_speed") else 10.0
	var is_raining = false

	if weather_system.has_method("get_conditions"):
		var conditions = weather_system.get_conditions()
		is_raining = conditions in ["Rain", "Heavy Rain", "Storm", "Snow"]

	# Process existing wildfire
	if wildfire_active:
		_process_active_wildfire(is_raining, humidity, wind_speed)
		return

	# Check for new wildfire - only in fire season (May-October in Northern Hemisphere)
	var is_fire_season = month in [5, 6, 7, 8, 9, 10]
	if not is_fire_season:
		return

	# Calculate fire risk
	var fire_risk = _calculate_wildfire_risk(temperature, humidity, wind_speed, month, is_raining)

	# Roll for wildfire
	if randf() < fire_risk:
		_start_wildfire(temperature, humidity, wind_speed)


func _calculate_wildfire_risk(temp: float, humidity: float, wind_speed: float, month: int, is_raining: bool) -> float:
	## Calculate the monthly wildfire risk based on conditions

	# No fire risk if raining
	if is_raining:
		return 0.0

	# Base risk
	var risk = _get_wildfire_base_risk()

	# Temperature factor - risk increases dramatically above 30°C
	if temp > _get_wildfire_temp_threshold():
		var temp_excess = temp - _get_wildfire_temp_threshold()
		risk += temp_excess * 0.01  # +1% per degree above threshold
		if temp > 38:
			risk += (temp - 38) * 0.02  # Extra +2% per degree above 38°C

	# Humidity factor - dry air increases risk
	if humidity < _get_wildfire_humidity_threshold():
		var humidity_deficit = _get_wildfire_humidity_threshold() - humidity
		risk += humidity_deficit * 0.15  # Up to +4.5% for very dry air

	# Peak fire season (July-August)
	if month in [7, 8]:
		risk *= 1.5  # 50% higher in peak summer

	# Wind factor - moderate winds spread fires, but don't start them
	# Very low humidity + wind is dangerous
	if humidity < 0.2 and wind_speed > 20:
		risk *= 1.3

	# Heat wave effect - extended heat greatly increases risk
	if weather_system and weather_system.get("heat_wave_active"):
		risk *= 2.0  # Double risk during heat waves

	return clampf(risk, 0.0, 0.3)  # Cap at 30% monthly risk


func _start_wildfire(temp: float, humidity: float, wind_speed: float) -> void:
	## Start a regional wildfire that affects air quality
	wildfire_active = true
	wildfire_duration = 1

	# Intensity based on conditions
	var base_intensity = 0.3

	# Hot and dry = more intense
	if temp > 35:
		base_intensity += 0.2
	if humidity < 0.2:
		base_intensity += 0.2

	# Wind spreads fire
	if wind_speed > 30:
		base_intensity += 0.15

	wildfire_intensity = clampf(base_intensity, 0.3, 1.0)

	# Calculate initial smoke contribution
	_update_wildfire_smoke()

	Events.simulation_event.emit("wildfire_started", {
		"intensity": int(wildfire_intensity * 100),
		"temperature": int(temp),
		"humidity": int(humidity * 100)
	})


func _process_active_wildfire(is_raining: bool, humidity: float, wind_speed: float) -> void:
	## Process an ongoing wildfire

	wildfire_duration += 1

	# Rain can extinguish fires
	if is_raining and humidity > 0.6:
		# High chance of ending with heavy rain
		if randf() < 0.7:
			_end_wildfire("rain")
			return

	# Natural end after max duration
	if wildfire_duration >= _get_wildfire_max_duration():
		# Fires usually die down naturally
		if randf() < 0.5 + humidity * 0.5:
			_end_wildfire("natural")
			return

	# Wind can intensify or spread the fire
	if wind_speed > 40:
		wildfire_intensity = minf(1.0, wildfire_intensity * 1.1)
	elif wind_speed < 10:
		# Calm winds let fires burn out slowly
		wildfire_intensity *= 0.9

	# Update smoke contribution
	_update_wildfire_smoke()

	# Extended fires emit periodic warnings
	if wildfire_duration >= 2:
		Events.simulation_event.emit("wildfire_ongoing", {
			"duration": wildfire_duration,
			"intensity": int(wildfire_intensity * 100)
		})


func _update_wildfire_smoke() -> void:
	## Calculate smoke contribution to air quality from wildfire

	if not wildfire_active:
		wildfire_smoke_contribution = 0.0
		return

	# Base smoke contribution from intensity
	var base_smoke = wildfire_intensity * 150.0  # Up to 150 AQI from intense fire

	# Wind direction affects how much smoke reaches the city
	var wind_factor = 0.7  # Base assumption: some smoke reaches city
	if weather_system:
		var wind_speed = weather_system.get_wind_speed() if weather_system.has_method("get_wind_speed") else 10.0
		# Strong winds can either bring more smoke or blow it away
		# For simplicity, moderate winds bring more smoke
		if wind_speed > 20 and wind_speed < 50:
			wind_factor = 0.9
		elif wind_speed > 50:
			wind_factor = 0.5  # Very strong winds disperse smoke

	# Inversions trap smoke near ground
	if inversion_active:
		wind_factor *= 1.3

	wildfire_smoke_contribution = base_smoke * wind_factor


func _end_wildfire(reason: String) -> void:
	## End the active wildfire

	wildfire_active = false
	wildfire_intensity = 0.0
	wildfire_duration = 0
	wildfire_smoke_contribution = 0.0

	var reason_text = "Rain has extinguished" if reason == "rain" else "Natural containment of"
	Events.simulation_event.emit("wildfire_ended", {
		"reason": reason,
		"message": "%s the regional wildfire. Air quality improving." % reason_text
	})


# ============================================
# AIR QUALITY INDEX
# ============================================

func _update_air_quality() -> void:
	## Calculate Air Quality Index (AQI) on EPA 0-500 scale
	## 0-50: Good
	## 51-100: Moderate
	## 101-150: Unhealthy for Sensitive Groups
	## 151-200: Unhealthy
	## 201-300: Very Unhealthy
	## 301-500: Hazardous

	var total_pollution = 0.0
	var cell_count = 0

	# Include both source and ambient pollution
	var all_cells: Dictionary = {}

	for cell in pollution_map:
		all_cells[cell] = pollution_map[cell]

	for cell in ambient_pollution:
		if all_cells.has(cell):
			all_cells[cell] = maxf(all_cells[cell], ambient_pollution[cell])
		else:
			all_cells[cell] = ambient_pollution[cell]

	for cell in all_cells:
		total_pollution += all_cells[cell]
		cell_count += 1

	# Calculate average pollution (0-1 scale)
	var avg_pollution = 0.0
	if cell_count > 0:
		avg_pollution = total_pollution / cell_count

	# Add inversion effect to AQI
	if inversion_active:
		avg_pollution *= (1.0 + inversion_strength * 0.5)

	# Convert to AQI (0-1 pollution maps roughly to 0-300 AQI)
	# With severe conditions, can exceed 300
	current_aqi = avg_pollution * 300.0

	# Adjust based on total pollution sources
	var source_count = polluters.size()
	if source_count > 5:
		current_aqi *= (1.0 + (source_count - 5) * 0.05)

	# Add wildfire smoke contribution
	# Wildfires can dramatically increase AQI
	if wildfire_active:
		current_aqi += wildfire_smoke_contribution

	current_aqi = clampf(current_aqi, 0.0, 500.0)

	# Determine category
	var old_category = air_quality_category
	if current_aqi <= 50:
		air_quality_category = "Good"
	elif current_aqi <= 100:
		air_quality_category = "Moderate"
	elif current_aqi <= 150:
		air_quality_category = "Unhealthy for Sensitive Groups"
	elif current_aqi <= 200:
		air_quality_category = "Unhealthy"
	elif current_aqi <= 300:
		air_quality_category = "Very Unhealthy"
	else:
		air_quality_category = "Hazardous"

	# Emit event if category changed
	if old_category != air_quality_category:
		Events.simulation_event.emit("air_quality_changed", {
			"aqi": current_aqi,
			"category": air_quality_category,
			"previous": old_category
		})


func _check_smog_alert() -> void:
	## Issue smog alerts when AQI is unhealthy and conditions favor smog formation

	var was_active = smog_alert_active

	# Smog alert conditions:
	# - AQI above moderate
	# - Temperature inversion active OR very high AQI
	smog_alert_active = current_aqi > 100 and (inversion_active or current_aqi > 150)

	if smog_alert_active and not was_active:
		Events.simulation_event.emit("smog_alert_started", {
			"aqi": current_aqi,
			"category": air_quality_category,
			"inversion": inversion_active
		})
	elif not smog_alert_active and was_active:
		Events.simulation_event.emit("smog_alert_ended", {
			"aqi": current_aqi,
			"category": air_quality_category
		})


# ============================================
# GETTERS FOR WEATHER-AFFECTED POLLUTION
# ============================================

func get_total_pollution_at(cell: Vector2i) -> float:
	## Get combined source + ambient pollution at a cell
	var source = pollution_map.get(cell, 0.0)
	var ambient = ambient_pollution.get(cell, 0.0)
	return minf(1.0, source + ambient)


func get_air_quality_index() -> float:
	return current_aqi


func get_air_quality_category() -> String:
	return air_quality_category


func is_smog_alert() -> bool:
	return smog_alert_active


func is_inversion_active() -> bool:
	return inversion_active


func get_inversion_strength() -> float:
	return inversion_strength


func get_wind_dispersion() -> float:
	return wind_dispersion_factor


func get_air_quality_color() -> Color:
	## Returns color for AQI display
	if current_aqi <= 50:
		return Color(0.0, 0.8, 0.0)  # Green
	elif current_aqi <= 100:
		return Color(0.9, 0.9, 0.0)  # Yellow
	elif current_aqi <= 150:
		return Color(1.0, 0.6, 0.0)  # Orange
	elif current_aqi <= 200:
		return Color(0.9, 0.0, 0.0)  # Red
	elif current_aqi <= 300:
		return Color(0.6, 0.0, 0.3)  # Purple
	else:
		return Color(0.5, 0.0, 0.1)  # Maroon


func get_air_quality_summary() -> String:
	var summary = "%s (AQI: %d)" % [air_quality_category, int(current_aqi)]

	if wildfire_active:
		summary += " - Wildfire smoke affecting region"
	if inversion_active:
		summary += " - Inversion trapping pollution"
	if smog_alert_active:
		summary += " [SMOG ALERT]"

	return summary


func is_wildfire_active() -> bool:
	return wildfire_active


func get_wildfire_intensity() -> float:
	return wildfire_intensity


func get_wildfire_duration() -> int:
	return wildfire_duration


func get_wildfire_smoke_contribution() -> float:
	return wildfire_smoke_contribution


func get_wildfire_info() -> Dictionary:
	return {
		"active": wildfire_active,
		"intensity": wildfire_intensity,
		"intensity_pct": int(wildfire_intensity * 100),
		"duration": wildfire_duration,
		"smoke_aqi": int(wildfire_smoke_contribution),
		"max_duration": _get_wildfire_max_duration()
	}


# ============================================
# SAVE/LOAD
# ============================================

func get_save_data() -> Dictionary:
	return {
		"ambient_pollution": ambient_pollution.duplicate(),
		"current_aqi": current_aqi,
		"air_quality_category": air_quality_category,
		"smog_alert_active": smog_alert_active,
		"inversion_active": inversion_active,
		"inversion_strength": inversion_strength,
		"rain_accumulation": rain_accumulation,
		"wind_dispersion_factor": wind_dispersion_factor,
		"wildfire_active": wildfire_active,
		"wildfire_intensity": wildfire_intensity,
		"wildfire_duration": wildfire_duration,
		"wildfire_smoke_contribution": wildfire_smoke_contribution
	}


func load_save_data(data: Dictionary) -> void:
	ambient_pollution = data.get("ambient_pollution", {})
	current_aqi = data.get("current_aqi", 0.0)
	air_quality_category = data.get("air_quality_category", "Good")
	smog_alert_active = data.get("smog_alert_active", false)
	inversion_active = data.get("inversion_active", false)
	inversion_strength = data.get("inversion_strength", 0.0)
	rain_accumulation = data.get("rain_accumulation", 0.0)
	wind_dispersion_factor = data.get("wind_dispersion_factor", 1.0)
	wildfire_active = data.get("wildfire_active", false)
	wildfire_intensity = data.get("wildfire_intensity", 0.0)
	wildfire_duration = data.get("wildfire_duration", 0)
	wildfire_smoke_contribution = data.get("wildfire_smoke_contribution", 0.0)
