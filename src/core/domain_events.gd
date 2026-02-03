class_name DomainEvents
extends RefCounted
## Rich domain event definitions that carry complete context
## Replaces multiple property-level signals with aggregated events

# ============================================
# POWER SYSTEM EVENTS
# ============================================

class PowerStateChanged extends RefCounted:
	var supply: float = 0.0
	var demand: float = 0.0
	var grid_stability: float = 1.0
	var stability_status: String = "Stable"
	var grid_frequency: float = 60.0
	var is_brownout: bool = false
	var brownout_severity: float = 0.0
	var storage_percent: float = 0.0
	var storage_charging: bool = false
	var has_shortage: bool = false
	var blackout_cells: int = 0

	func _init(data: Dictionary = {}) -> void:
		for key in data:
			if key in self:
				set(key, data[key])


class StormOutageEvent extends RefCounted:
	var active: bool = false
	var severity: float = 0.0
	var affected_cells: int = 0
	var restoration_progress: float = 0.0
	var repair_rate: float = 0.0

	func _init(data: Dictionary = {}) -> void:
		for key in data:
			if key in self:
				set(key, data[key])


# ============================================
# BUDGET/ECONOMY EVENTS
# ============================================

class BudgetTickEvent extends RefCounted:
	var balance: int = 0
	var income: int = 0
	var expenses: int = 0
	var net_change: int = 0
	var breakdown: Dictionary = {}  # {category: amount}
	var months_in_debt: int = 0

	func _init(data: Dictionary = {}) -> void:
		for key in data:
			if key in self:
				set(key, data[key])


# ============================================
# ZONE/DEVELOPMENT EVENTS
# ============================================

class ZoneStateChanged extends RefCounted:
	var zone_type: int = 0
	var cell: Vector2i = Vector2i.ZERO
	var development_level: int = 0
	var population_change: int = 0
	var demand_met: bool = false

	func _init(data: Dictionary = {}) -> void:
		for key in data:
			if key in self:
				set(key, data[key])


class DemandStateChanged extends RefCounted:
	var residential: float = 0.0
	var commercial: float = 0.0
	var industrial: float = 0.0
	var residential_met: float = 0.0
	var commercial_met: float = 0.0
	var industrial_met: float = 0.0

	func _init(data: Dictionary = {}) -> void:
		for key in data:
			if key in self:
				set(key, data[key])


# ============================================
# WATER SYSTEM EVENTS
# ============================================

class WaterStateChanged extends RefCounted:
	var supply: float = 0.0
	var demand: float = 0.0
	var pressure: float = 1.0
	var pressure_status: String = "Normal"
	var has_shortage: bool = false
	var drought_active: bool = false
	var drought_severity: float = 0.0

	func _init(data: Dictionary = {}) -> void:
		for key in data:
			if key in self:
				set(key, data[key])


# ============================================
# POPULATION EVENTS
# ============================================

class PopulationStateChanged extends RefCounted:
	var population: int = 0
	var delta: int = 0
	var happiness: float = 0.0
	var education_rate: float = 0.0
	var employment_rate: float = 0.0
	var jobs_available: int = 0
	var employed: int = 0

	func _init(data: Dictionary = {}) -> void:
		for key in data:
			if key in self:
				set(key, data[key])


# ============================================
# SERVICE EVENTS
# ============================================

class ServiceStateChanged extends RefCounted:
	var service_type: String = ""
	var coverage_percent: float = 0.0
	var buildings_count: int = 0
	var has_full_coverage: bool = false

	func _init(data: Dictionary = {}) -> void:
		for key in data:
			if key in self:
				set(key, data[key])


# ============================================
# WEATHER EVENTS
# ============================================

class WeatherStateChanged extends RefCounted:
	var temperature: float = 20.0
	var conditions: String = "Clear"
	var wind_speed: float = 10.0
	var is_storming: bool = false
	var storm_intensity: float = 0.0
	var solar_multiplier: float = 1.0
	var wind_multiplier: float = 1.0

	func _init(data: Dictionary = {}) -> void:
		for key in data:
			if key in self:
				set(key, data[key])


# ============================================
# DISASTER EVENTS
# ============================================

class DisasterEvent extends RefCounted:
	var disaster_type: int = 0
	var disaster_name: String = ""
	var severity: float = 0.0
	var origin_cell: Vector2i = Vector2i.ZERO
	var affected_cells: Array[Vector2i] = []
	var damage_estimate: int = 0
	var is_active: bool = false

	func _init(data: Dictionary = {}) -> void:
		for key in data:
			if key in self:
				set(key, data[key])
