class_name StormDamageSystem
extends RefCounted
## Handles storm detection, damage application, and repair tracking for power infrastructure

signal storm_outage_started(severity: float, affected_cells: int)
signal storm_outage_progress(restoration_pct: float, remaining_cells: int)
signal storm_outage_ended()

# Storm severity thresholds
const STORM_MINOR_THRESHOLD: float = 0.3
const STORM_MAJOR_THRESHOLD: float = 0.6
const STORM_SEVERE_THRESHOLD: float = 0.85

# Repair rates (cells restored per tick, based on available workforce)
const BASE_REPAIR_RATE: float = 5.0
const REPAIR_CREW_MULTIPLIER: float = 0.5

# Storm damage tracking
var storm_outage_active: bool = false
var storm_outage_severity: float = 0.0  # 0-1, how much of grid is down
var storm_damaged_cells: Dictionary = {}  # {Vector2i: repair_progress}
var storm_repair_rate: float = 0.0
var outage_restoration_progress: float = 0.0


## Check if current storm conditions cause power outages
func check_storm_damage(weather_system, powered_cells: Dictionary, distance_from_source: Dictionary) -> void:
	if not weather_system:
		return

	# Get storm intensity
	var is_storming = weather_system.is_storming if weather_system.get("is_storming") else false
	if not is_storming:
		return

	var storm_intensity = _calculate_storm_intensity(weather_system)

	# Only cause damage if storm is significant
	if storm_intensity < STORM_MINOR_THRESHOLD:
		return

	# Calculate and apply damage
	_apply_storm_damage(storm_intensity, powered_cells, distance_from_source)


## Calculate storm intensity from weather conditions
func _calculate_storm_intensity(weather_system) -> float:
	var storm_intensity = 0.0

	if weather_system.has_method("get_storm_intensity"):
		storm_intensity = weather_system.get_storm_intensity()
	else:
		# Estimate from conditions
		var conditions = weather_system.current_conditions if weather_system.get("current_conditions") else ""
		match conditions:
			"Storm", "Thunderstorm":
				storm_intensity = 0.5
			"Heavy Rain":
				storm_intensity = 0.3
			"Blizzard":
				storm_intensity = 0.7
			_:
				storm_intensity = 0.2

	# Get wind speed factor
	var wind_speed = 10.0
	if weather_system.has_method("get_wind_speed"):
		wind_speed = weather_system.get_wind_speed()

	# High winds cause more damage
	if wind_speed > 60:
		storm_intensity += 0.3
	elif wind_speed > 40:
		storm_intensity += 0.15
	elif wind_speed > 25:
		storm_intensity += 0.05

	return clampf(storm_intensity, 0.0, 1.0)


## Apply storm damage to power infrastructure
func _apply_storm_damage(intensity: float, powered_cells: Dictionary, distance_from_source: Dictionary) -> void:
	# Don't stack damage if already have significant outage
	if storm_outage_severity > 0.7:
		return

	# Determine how many cells are affected
	var damage_ratio = 0.0
	var repair_time_mult = 1.0

	if intensity >= STORM_SEVERE_THRESHOLD:
		damage_ratio = randf_range(0.4, 0.7)
		repair_time_mult = 3.0
		Events.simulation_event.emit("storm_power_outage", {
			"severity": "catastrophic",
			"message": "Catastrophic storm damage! Widespread power outages expected."
		})
	elif intensity >= STORM_MAJOR_THRESHOLD:
		damage_ratio = randf_range(0.15, 0.35)
		repair_time_mult = 2.0
		Events.simulation_event.emit("storm_power_outage", {
			"severity": "major",
			"message": "Major storm damage to power grid. Repairs underway."
		})
	elif intensity >= STORM_MINOR_THRESHOLD:
		damage_ratio = randf_range(0.05, 0.15)
		repair_time_mult = 1.0
		Events.simulation_event.emit("storm_power_outage", {
			"severity": "minor",
			"message": "Storm caused scattered power outages."
		})

	# Select cells to damage (prioritize distant/vulnerable cells)
	var cells_to_damage = int(powered_cells.size() * damage_ratio)
	if cells_to_damage == 0:
		return

	# Sort by distance (farther = more vulnerable)
	var sorted_cells: Array = []
	for cell in powered_cells:
		var dist = distance_from_source.get(cell, 0)
		sorted_cells.append({"cell": cell, "dist": dist})

	sorted_cells.sort_custom(func(a, b): return a.dist > b.dist)

	# Damage cells (with some randomness)
	var newly_damaged = 0
	for i in range(mini(cells_to_damage * 2, sorted_cells.size())):
		if newly_damaged >= cells_to_damage:
			break
		# Random chance to damage (higher for distant cells)
		var roll = randf()
		var damage_chance = 0.3 + (float(i) / sorted_cells.size()) * 0.5
		if roll < damage_chance:
			var cell = sorted_cells[i].cell
			if not storm_damaged_cells.has(cell):
				# Negative values mean more severe damage
				storm_damaged_cells[cell] = -repair_time_mult * randf_range(0.5, 1.0)
				newly_damaged += 1

	# Update outage state
	storm_outage_active = true
	storm_outage_severity = float(storm_damaged_cells.size()) / maxf(1.0, powered_cells.size())
	outage_restoration_progress = 0.0

	# Calculate repair rate based on employed population
	var employed = GameState.employed_population if GameState else 0
	storm_repair_rate = BASE_REPAIR_RATE + (employed / 1000.0) * REPAIR_CREW_MULTIPLIER

	storm_outage_started.emit(storm_outage_severity, storm_damaged_cells.size())


## Process monthly repairs to storm-damaged infrastructure
func process_repairs(weather_system, powered_cells_count: int) -> void:
	if storm_damaged_cells.size() == 0:
		_end_storm_outage()
		return

	# Calculate repair capacity
	var employed = GameState.employed_population if GameState else 0
	storm_repair_rate = BASE_REPAIR_RATE + (employed / 1000.0) * REPAIR_CREW_MULTIPLIER

	# Weather affects repair speed
	if weather_system:
		var is_storming = weather_system.is_storming if weather_system.get("is_storming") else false
		if is_storming:
			storm_repair_rate *= 0.3

		var conditions = weather_system.current_conditions if weather_system.get("current_conditions") else ""
		if conditions in ["Rain", "Heavy Rain"]:
			storm_repair_rate *= 0.6
		elif conditions == "Snow":
			storm_repair_rate *= 0.5

	# Repair cells
	var repair_progress_per_cell = 0.3
	var cells_to_remove: Array[Vector2i] = []

	for cell in storm_damaged_cells:
		storm_damaged_cells[cell] += repair_progress_per_cell
		if storm_damaged_cells[cell] >= 1.0:
			cells_to_remove.append(cell)

	# Limit repairs by crew capacity
	var max_repairs_this_month = int(storm_repair_rate)
	cells_to_remove = cells_to_remove.slice(0, max_repairs_this_month)

	for cell in cells_to_remove:
		storm_damaged_cells.erase(cell)

	# Update progress
	var original_count = storm_damaged_cells.size() + cells_to_remove.size()
	outage_restoration_progress = 1.0 - (float(storm_damaged_cells.size()) / maxf(1.0, original_count))
	storm_outage_severity = float(storm_damaged_cells.size()) / maxf(1.0, powered_cells_count)

	if cells_to_remove.size() > 0:
		storm_outage_progress.emit(outage_restoration_progress * 100, storm_damaged_cells.size())
		Events.simulation_event.emit("power_restoration_progress", {
			"restored": cells_to_remove.size(),
			"remaining": storm_damaged_cells.size(),
			"message": "Power restored to %d areas. %d areas still without power." % [cells_to_remove.size(), storm_damaged_cells.size()]
		})

	if storm_damaged_cells.size() == 0:
		_end_storm_outage()


## Complete the storm outage restoration
func _end_storm_outage() -> void:
	if not storm_outage_active:
		return

	storm_outage_active = false
	storm_outage_severity = 0.0
	storm_damaged_cells.clear()
	outage_restoration_progress = 1.0

	storm_outage_ended.emit()
	Events.simulation_event.emit("power_fully_restored", {
		"message": "All storm-related power outages have been restored!"
	})


## Check if a cell is storm damaged
func is_cell_storm_damaged(cell: Vector2i) -> bool:
	return storm_damaged_cells.has(cell)


## Get outage severity for happiness calculation
func get_outage_severity() -> float:
	return storm_outage_severity


## Get storm outage info dictionary
func get_storm_outage_info() -> Dictionary:
	return {
		"active": storm_outage_active,
		"severity": storm_outage_severity,
		"severity_pct": int(storm_outage_severity * 100),
		"affected_cells": storm_damaged_cells.size(),
		"restoration_progress": outage_restoration_progress,
		"restoration_pct": int(outage_restoration_progress * 100),
		"repair_rate": storm_repair_rate
	}
