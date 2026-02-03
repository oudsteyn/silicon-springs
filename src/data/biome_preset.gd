extends Resource
class_name BiomePreset
## Biome configuration resource defining terrain generation and gameplay effects

# Identity
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""

# Terrain generation parameters
@export_group("Terrain Generation")
@export var base_elevation: int = 0
@export_range(0.0, 1.0) var elevation_variation: float = 0.5
@export_range(0.0, 0.5) var water_coverage: float = 0.15
@export_range(0.0, 0.5) var tree_density: float = 0.2
@export_range(0.0, 0.3) var rock_density: float = 0.1

# Color palette (optional overrides)
@export_group("Visual Style")
@export var ground_color: Color = Color(0.25, 0.45, 0.25)
@export var water_color: Color = Color(0.2, 0.4, 0.7)
@export var vegetation_tint: Color = Color(0.15, 0.35, 0.15)
@export var sky_tint: Color = Color(1.0, 1.0, 1.0)  # Applied to day/night

# Weather effects
@export_group("Weather")
@export var avg_temperature: float = 20.0  # Celsius
@export var temp_variation: float = 15.0   # Seasonal swing +/-
@export_range(0.0, 1.0) var precipitation: float = 0.5  # Annual rainfall 0-1
@export_range(0.0, 1.0) var base_humidity: float = 0.5  # Average relative humidity
@export_range(0.0, 1.0) var storm_chance: float = 0.1   # Monthly probability
@export_range(0.0, 1.0) var flood_risk: float = 0.0     # Annual flood probability
@export var typical_pressure: float = 1013.0  # Average sea-level pressure (mb)

# Sunlight/day cycle
@export_group("Sunlight")
@export var summer_daylight_hours: float = 14.0  # Hours of daylight in summer
@export var winter_daylight_hours: float = 10.0  # Hours of daylight in winter
@export_range(0.5, 1.5) var sun_intensity: float = 1.0  # Solar power multiplier

# Gameplay modifiers
@export_group("Gameplay Effects")
@export_range(0.5, 2.0) var heating_cost_mult: float = 1.0
@export_range(0.5, 2.0) var cooling_cost_mult: float = 1.0
@export_range(0.5, 2.0) var water_scarcity: float = 1.0  # Water output multiplier
@export_range(0.5, 2.0) var construction_cost_mult: float = 1.0
@export_range(0.5, 2.0) var storm_damage_mult: float = 1.0

# Starting conditions
@export_group("Starting Conditions")
@export var starting_budget_modifier: int = 0  # Added to base starting budget
@export var starting_population_modifier: int = 0


# Get current temperature based on month (1-12)
func get_temperature_for_month(month: int) -> float:
	# Simple sine wave for seasonal variation
	# Month 7 (July) is hottest, Month 1 (January) is coldest
	var t = (month - 1) / 12.0 * TAU
	var seasonal_factor = sin(t - PI / 2)  # -1 at month 1, +1 at month 7
	return avg_temperature + (temp_variation * seasonal_factor)


# Get daylight hours based on month (1-12)
func get_daylight_hours_for_month(month: int) -> float:
	# Sine wave: longest days in summer (month 6-7), shortest in winter (month 12-1)
	var t = (month - 1) / 12.0 * TAU
	var seasonal_factor = sin(t - PI / 2)  # -1 in winter, +1 in summer
	var range_hours = summer_daylight_hours - winter_daylight_hours
	var mid_hours = (summer_daylight_hours + winter_daylight_hours) / 2
	return mid_hours + (range_hours / 2 * seasonal_factor)


# Get solar multiplier accounting for weather and season
func get_solar_multiplier(month: int, cloud_cover: float = 0.0) -> float:
	var daylight = get_daylight_hours_for_month(month)
	var daylight_factor = daylight / 12.0  # Normalized to 12h baseline
	var weather_factor = 1.0 - (cloud_cover * 0.7)  # Clouds reduce by up to 70%
	return sun_intensity * daylight_factor * weather_factor


# Get heating modifier based on current temperature
func get_heating_modifier(temperature: float) -> float:
	if temperature < 10:
		# Cold temps increase heating costs
		return heating_cost_mult * (1.0 + (10 - temperature) * 0.05)
	return 1.0


# Get cooling modifier based on current temperature
func get_cooling_modifier(temperature: float) -> float:
	if temperature > 25:
		# Hot temps increase cooling costs
		return cooling_cost_mult * (1.0 + (temperature - 25) * 0.03)
	return 1.0


# Get water output multiplier (water scarcity affects pump output)
func get_water_multiplier() -> float:
	return 1.0 / water_scarcity  # Higher scarcity = lower output


# Check if a storm should occur this month
func should_storm_occur() -> bool:
	return randf() < storm_chance


# Check if flooding should occur this year
func should_flood_occur() -> bool:
	return randf() < flood_risk


# Get a summary string for UI display
func get_summary() -> String:
	var summary = ""

	# Temperature
	if avg_temperature < 10:
		summary += "Cold climate. "
	elif avg_temperature > 25:
		summary += "Hot climate. "
	else:
		summary += "Temperate climate. "

	# Precipitation
	if precipitation < 0.2:
		summary += "Arid. "
	elif precipitation > 0.6:
		summary += "Wet. "

	# Special conditions
	if water_scarcity > 1.2:
		summary += "Water scarce. "
	if storm_chance > 0.15:
		summary += "Storm-prone. "
	if flood_risk > 0.1:
		summary += "Flood risk. "
	if sun_intensity > 1.1:
		summary += "High solar potential. "

	return summary.strip_edges()
