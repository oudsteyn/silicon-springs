class_name GridStability
extends RefCounted
## Calculates grid stability from supply/demand ratio
## Manages brownout and blackout states

signal stability_changed(stability: float, status: String)
signal brownout_started(severity: float)
signal brownout_ended()
signal blackout_started(affected_cells: int)
signal blackout_ended()

# Grid stability thresholds
const STABILITY_OPTIMAL: float = 0.95
const STABILITY_WARNING: float = 0.8
const STABILITY_CRITICAL: float = 0.6
const STABILITY_BLACKOUT: float = 0.3

# State
var grid_stability: float = 1.0  # 0.0 to 1.0
var grid_frequency: float = 60.0  # Hz, nominal is 60.0
var supply_demand_ratio: float = 1.0

# Brownout tracking
var is_brownout: bool = false
var brownout_severity: float = 0.0  # 0.0 to 1.0
var blackout_zones: Array[Vector2i] = []  # Cells affected by rolling blackout
var brownout_efficiency: float = 1.0  # Efficiency multiplier during brownout

# Peak demand tracking
var peak_demand_today: float = 0.0


## Calculate grid stability based on supply and demand
func calculate_stability(supply: float, demand: float, weather_system, storage_ratio: float) -> void:
	var previous_stability = grid_stability

	if demand <= 0:
		supply_demand_ratio = 2.0
		grid_stability = 1.0
		grid_frequency = 60.0
		return

	supply_demand_ratio = supply / demand

	# Grid stability based on supply/demand balance
	if supply_demand_ratio >= 1.0 and supply_demand_ratio <= 1.2:
		# Healthy surplus
		grid_stability = 1.0
	elif supply_demand_ratio > 1.2:
		# Too much surplus can destabilize (oversupply)
		var excess = supply_demand_ratio - 1.2
		grid_stability = 1.0 - (excess * 0.2)
	elif supply_demand_ratio >= 0.95:
		# Slight deficit - manageable
		grid_stability = 0.9 + (supply_demand_ratio - 0.95) * 2.0
	elif supply_demand_ratio >= 0.8:
		# Moderate deficit - concerning
		grid_stability = 0.6 + (supply_demand_ratio - 0.8) * 2.0
	elif supply_demand_ratio >= 0.5:
		# Severe deficit - critical
		grid_stability = 0.3 + (supply_demand_ratio - 0.5) * 1.0
	else:
		# Catastrophic deficit
		grid_stability = supply_demand_ratio * 0.6

	grid_stability = clampf(grid_stability, 0.0, 1.0)

	# Renewable intermittency affects stability
	if weather_system:
		var solar_mult = 1.0
		var wind_mult = 1.0
		if weather_system.has_method("get_solar_multiplier"):
			solar_mult = weather_system.get_solar_multiplier()
		if weather_system.has_method("get_wind_multiplier"):
			wind_mult = weather_system.get_wind_multiplier()

		# High renewable variability reduces stability slightly
		var renewable_stability_impact = (solar_mult + wind_mult) / 2.0
		if renewable_stability_impact < 0.7:
			grid_stability *= 0.95

	# Storage provides stability buffer
	if storage_ratio > 0:
		grid_stability += storage_ratio * 0.1 * (1.0 - grid_stability)

	grid_stability = clampf(grid_stability, 0.0, 1.0)

	# Calculate grid frequency (visual indicator)
	grid_frequency = 60.0 + (supply_demand_ratio - 1.0) * 2.0
	grid_frequency = clampf(grid_frequency, 57.0, 63.0)

	# Check for brownout/blackout transitions
	_update_brownout_status(previous_stability)

	# Emit stability change
	stability_changed.emit(grid_stability, get_stability_status())


## Update brownout status based on stability changes
func _update_brownout_status(_previous_stability: float) -> void:
	# Enter brownout
	if grid_stability < STABILITY_WARNING and not is_brownout:
		is_brownout = true
		brownout_severity = 1.0 - (grid_stability / STABILITY_WARNING)
		brownout_efficiency = 0.7 + grid_stability * 0.3
		brownout_started.emit(brownout_severity)
		Events.simulation_event.emit("brownout_started", {
			"severity": int(brownout_severity * 100),
			"message": "Power brownout! Grid operating at reduced capacity."
		})

	# Exit brownout
	elif grid_stability >= STABILITY_OPTIMAL and is_brownout:
		is_brownout = false
		brownout_severity = 0.0
		brownout_efficiency = 1.0
		blackout_zones.clear()
		brownout_ended.emit()
		Events.simulation_event.emit("brownout_ended", {})

	# Update brownout severity
	elif is_brownout:
		brownout_severity = 1.0 - (grid_stability / STABILITY_WARNING)
		brownout_efficiency = 0.7 + grid_stability * 0.3


## Update rolling blackouts based on stability and powered cells
func update_rolling_blackouts(powered_cells: Dictionary, distance_from_source: Dictionary) -> void:
	if not is_brownout or grid_stability >= STABILITY_CRITICAL:
		if blackout_zones.size() > 0:
			blackout_zones.clear()
			blackout_ended.emit()
		return

	# Determine how many cells need to be blacked out
	var blackout_ratio = 1.0 - (grid_stability / STABILITY_CRITICAL)
	var cells_to_blackout = int(powered_cells.size() * blackout_ratio * 0.3)

	# Prioritize blacking out distant cells first
	var sorted_cells: Array = []
	for cell in powered_cells:
		var dist = distance_from_source.get(cell, 0)
		sorted_cells.append({"cell": cell, "dist": dist})

	sorted_cells.sort_custom(func(a, b): return a.dist > b.dist)

	var previous_count = blackout_zones.size()
	blackout_zones.clear()

	for i in range(mini(cells_to_blackout, sorted_cells.size())):
		blackout_zones.append(sorted_cells[i].cell)

	if blackout_zones.size() > 0 and previous_count == 0:
		blackout_started.emit(blackout_zones.size())
		Events.simulation_event.emit("rolling_blackout", {
			"cells": blackout_zones.size(),
			"message": "Rolling blackouts affecting %d areas!" % blackout_zones.size()
		})


## Get stability status string
func get_stability_status() -> String:
	if grid_stability >= STABILITY_OPTIMAL:
		return "Stable"
	elif grid_stability >= STABILITY_WARNING:
		return "Strained"
	elif grid_stability >= STABILITY_CRITICAL:
		return "Unstable"
	elif grid_stability >= STABILITY_BLACKOUT:
		return "Critical"
	else:
		return "Failing"


## Check if grid is stable
func is_grid_stable() -> bool:
	return grid_stability >= STABILITY_WARNING


## Check if a cell is in a blackout zone
func is_cell_blacked_out(cell: Vector2i) -> bool:
	return cell in blackout_zones


## Get brownout info dictionary
func get_brownout_info() -> Dictionary:
	return {
		"is_brownout": is_brownout,
		"severity": brownout_severity,
		"efficiency": brownout_efficiency,
		"blackout_zones": blackout_zones.size(),
		"supply_demand_ratio": supply_demand_ratio
	}


## Get full grid info dictionary
func get_grid_info() -> Dictionary:
	return {
		"stability": grid_stability,
		"stability_pct": int(grid_stability * 100),
		"status": get_stability_status(),
		"frequency": grid_frequency,
		"is_brownout": is_brownout,
		"brownout_severity": brownout_severity,
		"blackout_cells": blackout_zones.size(),
		"supply_demand_ratio": supply_demand_ratio,
		"peak_demand": peak_demand_today
	}


## Reset peak demand (called monthly)
func reset_peak_demand() -> void:
	peak_demand_today = 0.0


## Update peak demand
func update_peak_demand(demand: float) -> void:
	peak_demand_today = maxf(peak_demand_today, demand)
