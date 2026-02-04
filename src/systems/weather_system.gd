extends Node
class_name WeatherSystem
## Advanced weather simulation with pressure systems, fronts, humidity, and realistic forecasting

# Current biome reference
var current_biome: BiomePreset = null

# Forecast data class
const DailyForecast = preload("res://src/systems/daily_forecast.gd")



# ============================================
# FORECAST STORAGE
# ============================================

const FORECAST_DAYS: int = 10
var forecast: Array[DailyForecast] = []
var current_day_in_month: int = 1

# Current conditions (from today's forecast, interpolated for time of day)
var current_temperature: float = 20.0
var current_conditions: String = "Clear"
var current_cloud_cover: float = 0.0
var current_wind_speed: float = 10.0
var current_wind_gusts: float = 15.0
var current_wind_direction: float = 180.0
var current_pressure: float = 1013.0
var current_humidity: float = 0.5
var current_dew_point: float = 10.0

# Active weather states
var is_storming: bool = false
var storm_duration: int = 0
var flood_active: bool = false
var heat_wave_active: bool = false
var cold_snap_active: bool = false

# ============================================
# DROUGHT SYSTEM
# ============================================

var drought_active: bool = false
var drought_severity: float = 0.0  # 0-1, how severe
var drought_duration: int = 0  # Months in drought
var precipitation_deficit: float = 0.0  # Accumulated precipitation deficit
var drought_water_reduction: float = 1.0  # Multiplier on water supply

# Precipitation tracking for drought detection
var monthly_precipitation: Array[float] = []  # Last 6 months
const DROUGHT_PRECIP_THRESHOLD: float = 0.3  # Below 30% normal = drought building
const DROUGHT_MONTHS_TO_START: int = 3  # Consecutive dry months to trigger
const DROUGHT_MAX_WATER_REDUCTION: float = 0.4  # Max 60% water reduction in severe drought

# ============================================
# SYNOPTIC SCALE PRESSURE SYSTEM
# ============================================

# Pressure systems are modeled as waves passing through
var pressure_base: float = 1013.0  # Seasonal/biome baseline
var pressure_long_wave_phase: float = 0.0  # 7-10 day Rossby wave
var pressure_long_wave_period: float = 8.0  # days
var pressure_long_wave_amplitude: float = 15.0  # mb

var pressure_short_wave_phase: float = 0.0  # 2-4 day disturbances
var pressure_short_wave_period: float = 3.0
var pressure_short_wave_amplitude: float = 8.0

# Frontal system tracking
var active_front: String = "none"  # Currently affecting weather
var front_position: float = 0.0  # 0 = approaching, 1 = passed
var next_front_type: String = "none"
var days_until_front: int = -1

# ============================================
# YEARLY VARIATION
# ============================================

var year_temp_offset: float = 0.0
var year_precip_modifier: float = 1.0
var year_storm_modifier: float = 1.0
var year_humidity_offset: float = 0.0  # Dew point offset

# ============================================
# CLIMATE CHANGE
# ============================================

var game_start_year: int = 2024
var climate_warming_rate: float = 0.03  # °C per year
var climate_extreme_increase: float = 0.01  # 1% more extremes per year

# ============================================
# SIGNALS
# ============================================

signal weather_changed(temperature: float, conditions: String)
signal forecast_updated(forecast: Array)
signal pressure_system_changed(pressure: float, trend: String)
signal front_approaching(front_type: String, days: int)
signal front_passage(front_type: String)
signal storm_started()
signal storm_ended()
signal flood_started()
signal flood_ended()
signal heat_wave_started()
signal heat_wave_ended()
signal cold_snap_started()
signal cold_snap_ended()
signal drought_started()
signal drought_ended()
signal drought_worsening(severity: float)


func _ready() -> void:
	Events.month_tick.connect(_on_month_tick)
	Events.year_tick.connect(_on_year_tick)
	game_start_year = GameState.current_year
	_initialize_pressure_system()
	_initialize_forecast()


func set_biome(biome: BiomePreset) -> void:
	current_biome = biome
	_generate_yearly_modifiers()
	_initialize_pressure_system()
	_regenerate_full_forecast()
	_apply_today_weather()


func get_biome() -> BiomePreset:
	return current_biome


# ============================================
# PRESSURE SYSTEM INITIALIZATION
# ============================================

func _initialize_pressure_system() -> void:
	# Randomize initial wave phases
	pressure_long_wave_phase = randf() * TAU
	pressure_short_wave_phase = randf() * TAU

	# Randomize wave characteristics for variety
	pressure_long_wave_period = randf_range(7.0, 11.0)
	pressure_long_wave_amplitude = randf_range(12.0, 20.0)
	pressure_short_wave_period = randf_range(2.5, 4.5)
	pressure_short_wave_amplitude = randf_range(5.0, 12.0)

	# Set base pressure from biome
	if current_biome:
		# Tropical = lower average pressure, polar = higher
		pressure_base = 1013.0 + (current_biome.avg_temperature - 20) * -0.3
	else:
		pressure_base = 1013.0

	# Initialize frontal system
	_schedule_next_front()


func _calculate_pressure_for_day(day_offset: int) -> float:
	var day_fraction = float(day_offset)

	# Long wave (synoptic scale, 7-10 days)
	var long_phase = pressure_long_wave_phase + (day_fraction / pressure_long_wave_period) * TAU
	var long_wave = sin(long_phase) * pressure_long_wave_amplitude

	# Short wave (disturbances, 2-4 days)
	var short_phase = pressure_short_wave_phase + (day_fraction / pressure_short_wave_period) * TAU
	var short_wave = sin(short_phase) * pressure_short_wave_amplitude

	# Add some noise for realism
	var noise = randf_range(-2.0, 2.0) if day_offset > 2 else randf_range(-1.0, 1.0)

	var pressure = pressure_base + long_wave + short_wave + noise
	return clampf(pressure, 965.0, 1045.0)


func _advance_pressure_waves() -> void:
	# Advance phases by one day
	pressure_long_wave_phase += TAU / pressure_long_wave_period
	pressure_short_wave_phase += TAU / pressure_short_wave_period

	# Occasionally perturb the waves (weather is chaotic)
	if randf() < 0.1:
		pressure_short_wave_amplitude += randf_range(-3.0, 3.0)
		pressure_short_wave_amplitude = clampf(pressure_short_wave_amplitude, 4.0, 15.0)


# ============================================
# FRONTAL SYSTEM
# ============================================

func _schedule_next_front() -> void:
	# Fronts pass through every 3-7 days typically
	days_until_front = randi_range(3, 7)

	# Front type based on season and randomness
	var month = GameState.current_month
	var roll = randf()

	if month in [11, 12, 1, 2]:  # Winter - more cold fronts
		if roll < 0.6:
			next_front_type = "cold"
		elif roll < 0.8:
			next_front_type = "warm"
		else:
			next_front_type = "occluded"
	elif month in [5, 6, 7, 8]:  # Summer - mixed
		if roll < 0.4:
			next_front_type = "cold"
		elif roll < 0.7:
			next_front_type = "warm"
		elif roll < 0.85:
			next_front_type = "stationary"
		else:
			next_front_type = "none"  # High pressure dominance
	else:  # Spring/Fall - active fronts
		if roll < 0.45:
			next_front_type = "cold"
		elif roll < 0.75:
			next_front_type = "warm"
		else:
			next_front_type = "occluded"


func _process_frontal_passage() -> void:
	if days_until_front > 0:
		days_until_front -= 1
		if days_until_front == 2:
			front_approaching.emit(next_front_type, days_until_front)
	elif days_until_front == 0:
		active_front = next_front_type
		front_position = 0.0
		front_passage.emit(active_front)
		Events.simulation_event.emit("front_passage", {"type": active_front})
		_schedule_next_front()


func _get_front_effects(front_type: String, position: float) -> Dictionary:
	## Returns weather modifications based on front type and position
	## position: 0 = front arriving, 0.5 = passing, 1.0 = departed

	var effects = {
		"temp_change": 0.0,
		"pressure_change": 0.0,
		"cloud_change": 0.0,
		"precip_mult": 1.0,
		"wind_mult": 1.0,
		"wind_shift": 0.0
	}

	match front_type:
		"cold":
			# Cold front: sharp temp drop, brief intense precip, clearing after
			if position < 0.3:  # Approaching
				effects.temp_change = 2.0  # Warm sector ahead
				effects.cloud_change = 0.3
				effects.wind_mult = 1.3
			elif position < 0.6:  # Passing
				effects.temp_change = -3.0
				effects.pressure_change = -8.0
				effects.cloud_change = 0.6
				effects.precip_mult = 2.5
				effects.wind_mult = 2.0
				effects.wind_shift = 45.0  # Wind veers
			else:  # Passed
				effects.temp_change = -8.0
				effects.pressure_change = 5.0
				effects.cloud_change = -0.3
				effects.wind_mult = 1.5
				effects.wind_shift = 90.0

		"warm":
			# Warm front: gradual warming, prolonged light precip before
			if position < 0.4:  # Approaching - extensive cloud/precip
				effects.cloud_change = 0.5
				effects.precip_mult = 1.8
				effects.pressure_change = -5.0
			elif position < 0.7:  # Passing
				effects.temp_change = 3.0
				effects.cloud_change = 0.4
				effects.precip_mult = 1.5
			else:  # Passed - warm sector
				effects.temp_change = 6.0
				effects.cloud_change = -0.1
				effects.pressure_change = 2.0

		"stationary":
			# Prolonged unsettled weather
			effects.cloud_change = 0.4
			effects.precip_mult = 1.5
			effects.pressure_change = -3.0

		"occluded":
			# Mix of cold and warm front characteristics
			if position < 0.5:
				effects.cloud_change = 0.5
				effects.precip_mult = 2.0
				effects.pressure_change = -6.0
				effects.wind_mult = 1.5
			else:
				effects.temp_change = -4.0
				effects.cloud_change = 0.2
				effects.pressure_change = 3.0

	return effects


# ============================================
# HUMIDITY AND DEW POINT
# ============================================

func _calculate_dew_point_for_day(base_temp: float, month: int) -> float:
	## Calculate dew point based on biome humidity and temperature

	var base_dew_point: float

	if current_biome:
		# Humid biomes have dew points closer to temperature
		# Arid biomes have large temp-dewpoint spread
		var humidity_factor = current_biome.precipitation  # Use precip as humidity proxy

		# Dew point depression (temp - dew point) ranges from 2-3°C (very humid) to 20-30°C (arid)
		var max_depression = lerp(25.0, 5.0, humidity_factor)
		var min_depression = lerp(15.0, 2.0, humidity_factor)
		var depression = randf_range(min_depression, max_depression)

		base_dew_point = base_temp - depression
	else:
		base_dew_point = base_temp - 10.0

	# Seasonal adjustment - summer has higher absolute humidity
	var seasonal_adj = sin((month - 1) / 12.0 * TAU - PI/2) * 3.0
	base_dew_point += seasonal_adj

	# Yearly variation
	base_dew_point += year_humidity_offset

	# Dew point can't exceed temperature
	base_dew_point = minf(base_dew_point, base_temp - 1.0)

	# Physical limits
	return clampf(base_dew_point, -30.0, 28.0)


func _calculate_fog_chance(temp: float, dew_point: float, wind_speed: float, cloud_cover: float) -> float:
	## Fog forms when temp approaches dew point with light winds and clear skies

	var depression = temp - dew_point

	# Fog unlikely if depression > 5°C
	if depression > 5.0:
		return 0.0

	# Base chance from temp-dewpoint spread
	var base_chance = (5.0 - depression) / 5.0 * 0.6

	# Light winds favor fog
	if wind_speed < 5:
		base_chance *= 1.5
	elif wind_speed > 15:
		base_chance *= 0.3

	# Clear skies at night favor radiation fog
	if cloud_cover < 0.3:
		base_chance *= 1.3
	elif cloud_cover > 0.7:
		base_chance *= 0.5

	return clampf(base_chance, 0.0, 0.8)


# ============================================
# STORM LIFECYCLE
# ============================================

func _update_storm_lifecycle(day: DailyForecast) -> void:
	## Model storm development through phases

	# Check if conditions support storm development
	var storm_potential = 0.0

	# Low pressure favors storms
	if day.pressure < 1000:
		storm_potential += 0.4
	elif day.pressure < 1010:
		storm_potential += 0.2

	# High moisture (high dew point) provides fuel
	if day.dew_point > 15:
		storm_potential += 0.3
	elif day.dew_point > 10:
		storm_potential += 0.15

	# Fronts trigger storms
	if day.front_passage:
		storm_potential += 0.4

	# Apply yearly storm modifier
	storm_potential *= year_storm_modifier

	# Determine storm phase
	match day.storm_phase:
		"none":
			if storm_potential > 0.5 and randf() < storm_potential * 0.5:
				day.storm_phase = "developing"
				day.storm_intensity = randf_range(0.1, 0.3)

		"developing":
			if randf() < 0.7:  # Usually progresses to mature
				day.storm_phase = "mature"
				day.storm_intensity = randf_range(0.6, 1.0)
			else:  # Sometimes fizzles
				day.storm_phase = "dissipating"
				day.storm_intensity *= 0.5

		"mature":
			# Mature storms always dissipate next
			day.storm_phase = "dissipating"
			day.storm_intensity *= 0.6

		"dissipating":
			day.storm_intensity *= 0.3
			if day.storm_intensity < 0.1:
				day.storm_phase = "none"
				day.storm_intensity = 0.0


# ============================================
# FORECAST GENERATION
# ============================================

func _initialize_forecast() -> void:
	forecast.clear()
	for i in range(FORECAST_DAYS):
		var day = DailyForecast.new()
		day.day_index = i
		forecast.append(day)

	if current_biome:
		_regenerate_full_forecast()


func _regenerate_full_forecast() -> void:
	if not current_biome:
		return

	# Generate pressure pattern first (drives everything else)
	for i in range(FORECAST_DAYS):
		forecast[i].pressure = _calculate_pressure_for_day(i)

	# Calculate pressure trends
	for i in range(FORECAST_DAYS):
		if i > 0:
			forecast[i].pressure_change = forecast[i].pressure - forecast[i-1].pressure
			if forecast[i].pressure_change > 2:
				forecast[i].pressure_trend = "rising"
			elif forecast[i].pressure_change < -2:
				forecast[i].pressure_trend = "falling"
			else:
				forecast[i].pressure_trend = "steady"

	# Generate each day's weather
	for i in range(FORECAST_DAYS):
		_generate_day_forecast(i)

	_apply_today_weather()
	forecast_updated.emit(forecast)


func _advance_forecast() -> void:
	forecast.remove_at(0)

	var new_day = DailyForecast.new()
	new_day.day_index = FORECAST_DAYS - 1
	forecast.append(new_day)

	# Advance pressure system
	_advance_pressure_waves()
	new_day.pressure = _calculate_pressure_for_day(FORECAST_DAYS - 1)

	# Update pressure trends
	if forecast.size() >= 2:
		new_day.pressure_change = new_day.pressure - forecast[FORECAST_DAYS - 2].pressure
		if new_day.pressure_change > 2:
			new_day.pressure_trend = "rising"
		elif new_day.pressure_change < -2:
			new_day.pressure_trend = "falling"
		else:
			new_day.pressure_trend = "steady"

	_generate_day_forecast(FORECAST_DAYS - 1)

	# Update indices
	for i in range(FORECAST_DAYS):
		forecast[i].day_index = i

	_apply_today_weather()
	forecast_updated.emit(forecast)


func _generate_day_forecast(day_index: int) -> void:
	if not current_biome or day_index >= forecast.size():
		return

	var day = forecast[day_index]
	var month = GameState.current_month

	# Calculate future month if needed
	var future_day = current_day_in_month + day_index
	var future_month = month
	while future_day > 30:
		future_day -= 30
		future_month = (future_month % 12) + 1

	# ---- FORECAST UNCERTAINTY ----
	# Uncertainty grows with forecast distance
	day.temp_uncertainty = 1.0 + day_index * 0.5

	# ---- BASE TEMPERATURE ----
	var seasonal_temp = current_biome.get_temperature_for_month(future_month)

	# Climate change warming
	var years_elapsed = GameState.current_year - game_start_year
	seasonal_temp += years_elapsed * climate_warming_rate

	# Yearly variation
	seasonal_temp += year_temp_offset

	# ---- PRESSURE-BASED TEMPERATURE MODIFICATION ----
	# High pressure = warmer in summer, colder in winter (clear skies)
	# Low pressure = moderate temperatures
	var pressure_anomaly = day.pressure - 1013.0
	var is_warm_season = future_month in [4, 5, 6, 7, 8, 9]

	if pressure_anomaly > 10:  # High pressure
		if is_warm_season:
			seasonal_temp += 2.0  # Clear skies = warmer
		else:
			seasonal_temp -= 2.0  # Clear winter nights = colder
	elif pressure_anomaly < -10:  # Low pressure
		seasonal_temp += 0.0  # Clouds moderate temperature

	# ---- FRONTAL TEMPERATURE EFFECTS ----
	# Check if a front affects this day
	var days_to_front = days_until_front - day_index
	if days_to_front >= 0 and days_to_front <= 2:
		day.front_type = next_front_type
		if days_to_front == 0:
			day.front_passage = true
			day.front_timing = ["morning", "afternoon", "evening", "overnight"][randi() % 4]

		var position = 1.0 - (days_to_front / 2.0)
		var effects = _get_front_effects(next_front_type, position)
		seasonal_temp += effects.temp_change
	elif active_front != "none" and day_index < 2:
		# Still feeling effects of recent front
		var position = 0.7 + day_index * 0.15
		var effects = _get_front_effects(active_front, position)
		seasonal_temp += effects.temp_change * 0.5

	# ---- PERSISTENCE WITH PREVIOUS DAY ----
	if day_index > 0:
		var prev_day = forecast[day_index - 1]
		var prev_avg = prev_day.get_avg_temp()
		# 60% persistence for nearby days, less for distant
		var persistence = 0.6 - day_index * 0.03
		persistence = maxf(persistence, 0.3)
		seasonal_temp = lerp(seasonal_temp, prev_avg, persistence)

	# Add daily random variation (more for distant forecasts)
	var variation_scale = 1.0 + day_index * 0.1
	seasonal_temp += randf_range(-2.0, 2.0) * variation_scale

	# ---- DEW POINT AND HUMIDITY ----
	day.dew_point = _calculate_dew_point_for_day(seasonal_temp, future_month)

	# ---- DIURNAL RANGE (Wind-Cloud-Temperature Coupling) ----
	# Clear, calm conditions = large range
	# Cloudy, windy = small range
	var base_range = 10.0

	# Clouds insulate - reduce range
	# We need to calculate clouds first, but they depend on pressure...
	# So estimate cloud cover from pressure
	var estimated_clouds = 0.3
	if day.pressure < 1005:
		estimated_clouds = 0.7
	elif day.pressure < 1015:
		estimated_clouds = 0.5
	elif day.pressure > 1025:
		estimated_clouds = 0.15

	var cloud_reduction = estimated_clouds * 4.0  # Up to 4°C reduction

	# Wind mixes air - reduces range
	var estimated_wind = 15.0  # Will calculate properly later
	var wind_reduction = minf(estimated_wind / 10.0, 2.0)  # Up to 2°C reduction

	# Humidity reduces range (moist air has higher heat capacity)
	var humidity_reduction = (day.dew_point / seasonal_temp) * 2.0 if seasonal_temp > 0 else 0.0
	humidity_reduction = clampf(humidity_reduction, 0.0, 2.0)

	var diurnal_range = base_range - cloud_reduction - wind_reduction - humidity_reduction
	diurnal_range = clampf(diurnal_range, 3.0, 18.0)
	diurnal_range += randf_range(-1.0, 1.0)

	day.high_temp = seasonal_temp + diurnal_range / 2.0
	day.low_temp = seasonal_temp - diurnal_range / 2.0

	# ---- CLOUD COVER ----
	_generate_clouds_and_precip(day, future_month)

	# ---- WIND ----
	_generate_wind(day, future_month)

	# ---- FOG ----
	day.fog_chance = _calculate_fog_chance(day.low_temp, day.dew_point, day.wind_speed, day.cloud_cover)

	# ---- STORM LIFECYCLE ----
	if day_index > 0:
		# Inherit storm phase from previous day and evolve
		day.storm_phase = forecast[day_index - 1].storm_phase
		day.storm_intensity = forecast[day_index - 1].storm_intensity
	_update_storm_lifecycle(day)

	# ---- FINAL CONDITIONS STRING ----
	_determine_conditions(day)

	# ---- UPDATE HUMIDITY ----
	day.update_humidity()


func _generate_clouds_and_precip(day: DailyForecast, month: int) -> void:
	if not current_biome:
		day.cloud_cover = 0.3
		day.precipitation_chance = 0.1
		return

	# ---- CLOUD COVER FROM PRESSURE ----
	# Low pressure = rising air = clouds
	# High pressure = sinking air = clear
	var pressure_cloud_factor = (1020.0 - day.pressure) / 40.0  # -0.25 to +0.75
	pressure_cloud_factor = clampf(pressure_cloud_factor, -0.2, 0.8)

	var base_clouds = 0.3 + pressure_cloud_factor

	# Frontal effects on clouds
	if day.front_type != "none":
		var position = 0.5 if day.front_passage else 0.2
		var effects = _get_front_effects(day.front_type, position)
		base_clouds += effects.cloud_change

	# Storm phase affects clouds
	match day.storm_phase:
		"developing":
			base_clouds = maxf(base_clouds, 0.5)
		"mature":
			base_clouds = maxf(base_clouds, 0.85)
		"dissipating":
			base_clouds = maxf(base_clouds, 0.6)

	# Add randomness
	base_clouds += randf_range(-0.1, 0.1)
	day.cloud_cover = clampf(base_clouds, 0.0, 1.0)

	# ---- PRECIPITATION ----
	var base_precip = current_biome.precipitation

	# Clouds required for precipitation
	if day.cloud_cover < 0.4:
		base_precip *= 0.1  # Very unlikely without clouds
	elif day.cloud_cover < 0.6:
		base_precip *= 0.5

	# Pressure effects
	if day.pressure < 1000:
		base_precip *= 1.8
	elif day.pressure < 1010:
		base_precip *= 1.3
	elif day.pressure > 1025:
		base_precip *= 0.3

	# Frontal effects
	if day.front_type != "none":
		var position = 0.5 if day.front_passage else 0.3
		var effects = _get_front_effects(day.front_type, position)
		base_precip *= effects.precip_mult

	# Storm intensity
	if day.storm_phase == "mature":
		base_precip = maxf(base_precip, 0.8)
	elif day.storm_phase == "developing":
		base_precip = maxf(base_precip, 0.5)

	# Seasonal variation
	if month in [3, 4, 10, 11]:  # Spring/fall
		base_precip *= 1.2

	# Yearly modifier
	base_precip *= year_precip_modifier

	day.precipitation_chance = clampf(base_precip, 0.0, 0.95)

	# ---- PRECIPITATION TYPE ----
	var avg_temp = day.get_avg_temp()
	var will_precipitate = day.precipitation_chance > 0.3

	if will_precipitate:
		if avg_temp < -2:
			day.precipitation_type = "snow"
		elif avg_temp < 2:
			# Marginal - could be mixed
			if day.high_temp > 3 and day.low_temp < 0:
				day.precipitation_type = "sleet"
			elif day.dew_point < -5:
				day.precipitation_type = "snow"  # Dry snow even near freezing
			else:
				day.precipitation_type = "freezing_rain" if randf() < 0.3 else "sleet"
		elif avg_temp < 5:
			day.precipitation_type = "rain" if randf() > 0.2 else "sleet"
		else:
			day.precipitation_type = "rain"

		# Intensity based on various factors
		day.precipitation_intensity = day.precipitation_chance * day.cloud_cover
		if day.storm_phase == "mature":
			day.precipitation_intensity = maxf(day.precipitation_intensity, 0.7)
	else:
		day.precipitation_type = "none"
		day.precipitation_intensity = 0.0

	# ---- ENFORCE CLOUD-PRECIP COUPLING ----
	# Rain requires clouds
	if day.precipitation_chance > 0.3:
		day.cloud_cover = maxf(day.cloud_cover, 0.5)
	if day.precipitation_chance > 0.6:
		day.cloud_cover = maxf(day.cloud_cover, 0.7)


func _generate_wind(day: DailyForecast, month: int) -> void:
	# ---- BASE WIND FROM PRESSURE GRADIENT ----
	# Steeper pressure changes = stronger winds
	var gradient_wind = absf(day.pressure_change) * 2.0

	# Low pressure systems are windier
	var pressure_wind = maxf(0.0, (1015.0 - day.pressure) * 0.5)

	var base_wind = 8.0 + gradient_wind + pressure_wind + randf_range(-3.0, 3.0)

	# ---- SEASONAL VARIATION ----
	if month in [3, 4, 10, 11]:  # Transition seasons - windier
		base_wind *= randf_range(1.2, 1.5)
	elif month in [6, 7, 8]:  # Summer often calmer
		base_wind *= randf_range(0.7, 1.0)

	# ---- FRONTAL EFFECTS ----
	if day.front_type != "none":
		var position = 0.5 if day.front_passage else 0.3
		var effects = _get_front_effects(day.front_type, position)
		base_wind *= effects.wind_mult
		day.wind_direction += effects.wind_shift

	# ---- STORM EFFECTS ----
	match day.storm_phase:
		"developing":
			base_wind *= 1.3
		"mature":
			base_wind = maxf(base_wind, 40.0)
			base_wind *= randf_range(1.5, 2.0)
		"dissipating":
			base_wind *= 1.2

	# ---- BIOME EFFECTS ----
	if current_biome and current_biome.id in ["coastal_shelf", "tundra_plateau"]:
		base_wind *= 1.25

	day.wind_speed = clampf(base_wind, 0.0, 120.0)

	# ---- GUSTS ----
	# Gusts are 30-70% higher than sustained, more in unstable conditions
	var gust_factor = randf_range(1.3, 1.5)
	if day.storm_phase in ["developing", "mature"]:
		gust_factor = randf_range(1.5, 1.8)
	if day.front_passage:
		gust_factor = randf_range(1.4, 1.7)

	day.wind_gusts = day.wind_speed * gust_factor

	# ---- WIND DIRECTION ----
	# Generally westerly in mid-latitudes, varies with pressure systems
	if day.day_index == 0 or day.front_passage:
		# Set new base direction
		day.wind_direction = randf_range(180.0, 300.0)  # SW to NW
	elif forecast.size() > 0 and day.day_index > 0:
		# Persist from previous day with some variation
		var prev_dir = forecast[day.day_index - 1].wind_direction
		day.wind_direction = prev_dir + randf_range(-20.0, 20.0)

	day.wind_direction = fmod(day.wind_direction + 360.0, 360.0)

	# ---- WIND-TEMPERATURE COUPLING ----
	# Light winds allow temperature extremes
	if day.wind_speed < 8:
		day.high_temp += randf_range(0.0, 2.0)
		day.low_temp -= randf_range(0.0, 3.0)
	# Strong winds moderate temperatures
	elif day.wind_speed > 35:
		var avg = day.get_avg_temp()
		day.high_temp = lerp(day.high_temp, avg, 0.15)
		day.low_temp = lerp(day.low_temp, avg, 0.15)


func _determine_conditions(day: DailyForecast) -> void:
	var avg_temp = day.get_avg_temp()

	# ---- SEVERE WEATHER CHECK ----
	if day.storm_phase == "mature":
		day.is_severe = true
		if avg_temp < 0:
			day.conditions = "Blizzard"
		else:
			day.conditions = "Storm"
		return

	if day.storm_phase == "developing":
		if avg_temp < 0:
			day.conditions = "Snow"
		else:
			day.conditions = "Storm"
		day.is_severe = day.wind_gusts > 70
		return

	# ---- PRECIPITATION CONDITIONS ----
	var will_precipitate = randf() < day.precipitation_chance

	if will_precipitate and day.precipitation_intensity > 0.3:
		match day.precipitation_type:
			"snow":
				day.conditions = "Snow"
			"sleet":
				day.conditions = "Sleet"
			"freezing_rain":
				day.conditions = "Ice"
				day.is_severe = true
			"rain":
				if day.precipitation_intensity > 0.6:
					day.conditions = "Heavy Rain"
				else:
					day.conditions = "Rain"
		return

	# ---- CLOUD-BASED CONDITIONS ----
	if day.cloud_cover > 0.85:
		day.conditions = "Overcast"
	elif day.cloud_cover > 0.6:
		day.conditions = "Cloudy"
	elif day.cloud_cover > 0.3:
		day.conditions = "Partly Cloudy"
	elif avg_temp > 35:
		day.conditions = "Hot"
		day.is_severe = avg_temp > 40
	elif avg_temp < -15:
		day.conditions = "Cold"
		day.is_severe = avg_temp < -25
	else:
		day.conditions = "Clear"

	# Check for heat wave / cold snap severe marking
	if heat_wave_active and avg_temp > 32:
		day.is_severe = true
	if cold_snap_active and avg_temp < -10:
		day.is_severe = true


func _apply_today_weather() -> void:
	if forecast.size() == 0:
		return

	var today = forecast[0]

	current_temperature = today.get_avg_temp()
	current_conditions = today.conditions
	current_cloud_cover = today.cloud_cover
	current_wind_speed = today.wind_speed
	current_wind_gusts = today.wind_gusts
	current_wind_direction = today.wind_direction
	current_pressure = today.pressure
	current_dew_point = today.dew_point
	current_humidity = today.humidity

	# Update storm status
	var was_storming = is_storming
	is_storming = today.storm_phase in ["developing", "mature"]

	if is_storming and not was_storming:
		_start_storm()
	elif not is_storming and was_storming:
		_end_storm()

	# Check for extreme events
	_check_extreme_events(today)

	weather_changed.emit(current_temperature, current_conditions)
	Events.weather_changed.emit(current_temperature, current_conditions)
	pressure_system_changed.emit(current_pressure, today.pressure_trend)


func _check_extreme_events(today: DailyForecast) -> void:
	var avg_temp = today.get_avg_temp()

	# Heat wave detection (3+ days of very high temps)
	if avg_temp > 35 and current_biome and current_biome.avg_temperature < 30:
		if not heat_wave_active:
			heat_wave_active = true
			heat_wave_started.emit()
			Events.heat_wave_started.emit()
			Events.simulation_event.emit("heat_wave_started", {"temp": avg_temp})
	elif heat_wave_active and avg_temp < 30:
		heat_wave_active = false
		heat_wave_ended.emit()
		Events.heat_wave_ended.emit()
		Events.simulation_event.emit("heat_wave_ended", {})

	# Cold snap detection
	if avg_temp < -10 and current_biome and current_biome.avg_temperature > 0:
		if not cold_snap_active:
			cold_snap_active = true
			cold_snap_started.emit()
			Events.cold_snap_started.emit()
			Events.simulation_event.emit("cold_snap_started", {"temp": avg_temp})
	elif cold_snap_active and avg_temp > -5:
		cold_snap_active = false
		cold_snap_ended.emit()
		Events.cold_snap_ended.emit()
		Events.simulation_event.emit("cold_snap_ended", {})


# ============================================
# YEARLY MODIFIERS
# ============================================

func _generate_yearly_modifiers() -> void:
	year_temp_offset = randf_range(-3.0, 3.0)
	year_precip_modifier = randf_range(0.7, 1.3)
	year_storm_modifier = randf_range(0.6, 1.4)
	year_humidity_offset = randf_range(-3.0, 3.0)

	# Climate change amplifies extremes
	var years_elapsed = GameState.current_year - game_start_year
	var extreme_modifier = 1.0 + years_elapsed * climate_extreme_increase

	year_temp_offset *= extreme_modifier
	if randf() < 0.25 * extreme_modifier:
		year_precip_modifier *= extreme_modifier
	if randf() < 0.2 * extreme_modifier:
		year_storm_modifier *= extreme_modifier


# ============================================
# EVENT HANDLERS
# ============================================

func _on_month_tick() -> void:
	# Advance 3 days per month tick
	for i in range(3):
		_advance_forecast()
		_process_frontal_passage()

	current_day_in_month += 3
	if current_day_in_month > 30:
		current_day_in_month = 1

	_check_flood()
	_process_drought()
	_apply_weather_effects()


func _on_year_tick() -> void:
	_generate_yearly_modifiers()

	# Climate report every 10 years
	var years_elapsed = GameState.current_year - game_start_year
	if years_elapsed > 0 and years_elapsed % 10 == 0:
		var total_warming = years_elapsed * climate_warming_rate
		Events.simulation_event.emit("climate_report", {
			"years": years_elapsed,
			"warming": total_warming
		})


func _check_flood() -> void:
	if flood_active:
		if randf() < 0.3:
			_end_flood()
	elif current_biome:
		var flood_chance = current_biome.flood_risk * year_precip_modifier
		var years_elapsed = GameState.current_year - game_start_year
		flood_chance *= (1.0 + years_elapsed * climate_extreme_increase)

		if is_storming:
			flood_chance *= 2.0

		if randf() < flood_chance:
			_start_flood()


func _start_storm() -> void:
	storm_duration = randi_range(1, 3)
	storm_started.emit()
	Events.storm_started.emit()
	Events.simulation_event.emit("storm_started", {
		"biome": current_biome.display_name if current_biome else "Unknown",
		"intensity": forecast[0].storm_intensity if forecast.size() > 0 else 0.5
	})


func _end_storm() -> void:
	storm_duration = 0
	storm_ended.emit()
	Events.storm_ended.emit()
	Events.simulation_event.emit("storm_ended", {})


func _start_flood() -> void:
	flood_active = true
	flood_started.emit()
	Events.flood_started.emit()
	Events.simulation_event.emit("flood_started", {})


func _end_flood() -> void:
	flood_active = false
	flood_ended.emit()
	Events.flood_ended.emit()
	Events.simulation_event.emit("flood_ended", {})


# ============================================
# DROUGHT MANAGEMENT
# ============================================

func _process_drought() -> void:
	## Track precipitation and manage drought conditions

	# Get this month's precipitation
	var month_precip = 0.0
	if forecast.size() > 0:
		# Average precipitation from recent days
		var total = 0.0
		var count = 0
		for day in forecast:
			if day.precipitation_chance > 0.3:
				total += day.precipitation_intensity
				count += 1
		if count > 0:
			month_precip = total / count
		else:
			month_precip = 0.0

	# Track precipitation history
	monthly_precipitation.append(month_precip)
	if monthly_precipitation.size() > 6:
		monthly_precipitation.remove_at(0)

	# Calculate precipitation deficit
	# Compare to expected precipitation from biome
	var expected_precip = 0.5  # Default
	if current_biome:
		expected_precip = current_biome.precipitation

	# Calculate average recent precipitation
	var avg_recent_precip = 0.0
	if monthly_precipitation.size() > 0:
		var total = 0.0
		for p in monthly_precipitation:
			total += p
		avg_recent_precip = total / monthly_precipitation.size()

	# Precipitation ratio (how much we're getting vs expected)
	var precip_ratio = avg_recent_precip / maxf(expected_precip, 0.1)

	# Heat intensifies drought conditions
	var heat_factor = 1.0
	if current_temperature > 30:
		heat_factor = 1.0 + (current_temperature - 30) * 0.05
	if heat_wave_active:
		heat_factor *= 1.5

	# Calculate drought pressure
	if precip_ratio < DROUGHT_PRECIP_THRESHOLD:
		# Dry conditions - accumulate deficit
		precipitation_deficit += (DROUGHT_PRECIP_THRESHOLD - precip_ratio) * heat_factor

		if not drought_active:
			# Check if we've had enough consecutive dry months
			var dry_months = 0
			for p in monthly_precipitation:
				if p / expected_precip < DROUGHT_PRECIP_THRESHOLD:
					dry_months += 1

			if dry_months >= DROUGHT_MONTHS_TO_START or precipitation_deficit > 1.0:
				_start_drought()
		else:
			# Drought getting worse
			var new_severity = minf(1.0, precipitation_deficit / 3.0)
			if new_severity > drought_severity + 0.2:
				drought_severity = new_severity
				drought_worsening.emit(drought_severity)
				Events.simulation_event.emit("drought_worsening", {
					"severity": int(drought_severity * 100),
					"duration": drought_duration
				})
	else:
		# Getting rain - reduce deficit
		precipitation_deficit = maxf(0.0, precipitation_deficit - precip_ratio * 0.5)

		if drought_active:
			drought_severity = maxf(0.0, drought_severity - 0.1)
			if drought_severity < 0.1 and precipitation_deficit < 0.3:
				_end_drought()

	# Update water reduction based on drought severity
	if drought_active:
		drought_duration += 1
		drought_water_reduction = 1.0 - (drought_severity * DROUGHT_MAX_WATER_REDUCTION)
	else:
		drought_water_reduction = 1.0


func _start_drought() -> void:
	drought_active = true
	drought_duration = 1
	drought_severity = 0.3 + precipitation_deficit * 0.2
	drought_severity = minf(drought_severity, 1.0)

	drought_started.emit()
	Events.simulation_event.emit("drought_started", {
		"severity": int(drought_severity * 100)
	})


func _end_drought() -> void:
	drought_active = false
	drought_duration = 0
	drought_severity = 0.0
	drought_water_reduction = 1.0
	precipitation_deficit = 0.0

	drought_ended.emit()
	Events.simulation_event.emit("drought_ended", {})


func is_drought_active() -> bool:
	return drought_active


func get_drought_severity() -> float:
	return drought_severity


func get_drought_duration() -> int:
	return drought_duration


func get_drought_water_multiplier() -> float:
	## Returns water supply multiplier affected by drought
	## This stacks with the biome's base water multiplier
	return drought_water_reduction


func get_drought_info() -> Dictionary:
	return {
		"active": drought_active,
		"severity": drought_severity,
		"severity_pct": int(drought_severity * 100),
		"duration": drought_duration,
		"water_reduction": int((1.0 - drought_water_reduction) * 100),
		"precipitation_deficit": precipitation_deficit
	}


func _apply_weather_effects() -> void:
	if is_storming and current_biome:
		var damage_mult = get_storm_damage_multiplier()
		if damage_mult > 1.0 and randf() < 0.1:
			Events.simulation_event.emit("storm_damage", {"severity": damage_mult})

	if flood_active:
		Events.simulation_event.emit("flood_damage", {"active": true})


# ============================================
# GETTERS FOR CURRENT CONDITIONS
# ============================================

func get_temperature() -> float:
	return current_temperature

func get_conditions() -> String:
	return current_conditions

func is_storm_active() -> bool:
	return is_storming

func is_flood_active() -> bool:
	return flood_active

func get_cloud_cover() -> float:
	return current_cloud_cover

func get_pressure() -> float:
	return current_pressure

func get_pressure_trend() -> String:
	if forecast.size() > 0:
		return forecast[0].pressure_trend
	return "steady"

func get_humidity() -> float:
	return current_humidity

func get_dew_point() -> float:
	return current_dew_point

func get_wind_speed() -> float:
	return current_wind_speed

func get_wind_gusts() -> float:
	return current_wind_gusts

func get_wind_direction() -> float:
	return current_wind_direction

func get_forecast() -> Array[DailyForecast]:
	return forecast

func get_today() -> DailyForecast:
	return forecast[0] if forecast.size() > 0 else null

func get_tomorrow() -> DailyForecast:
	return forecast[1] if forecast.size() > 1 else null


# ============================================
# GAMEPLAY EFFECT MULTIPLIERS
# ============================================

func get_solar_multiplier() -> float:
	# Cloud cover reduces solar output significantly
	var cloud_factor = 1.0 - (current_cloud_cover * 0.75)

	if current_biome:
		return current_biome.get_solar_multiplier(GameState.current_month, current_cloud_cover)

	return cloud_factor


func get_wind_multiplier() -> float:
	## Wind turbine power curve
	# Cut-in: 10 km/h
	# Optimal: 25-50 km/h
	# Cut-out: 90 km/h

	if current_wind_speed < 10.0:
		return 0.0
	if current_wind_speed > 90.0:
		return 0.0
	if current_wind_speed >= 25.0 and current_wind_speed <= 50.0:
		return 1.0
	if current_wind_speed < 25.0:
		return (current_wind_speed - 10.0) / 15.0
	return 1.0 - ((current_wind_speed - 50.0) / 80.0)


func get_heating_modifier() -> float:
	if not current_biome:
		return 1.0

	var base = current_biome.get_heating_modifier(current_temperature)

	# Wind chill increases heating needs
	if current_wind_speed > 20 and current_temperature < 10:
		base *= 1.0 + (current_wind_speed - 20) * 0.005

	return base


func get_cooling_modifier() -> float:
	if not current_biome:
		return 1.0

	var base = current_biome.get_cooling_modifier(current_temperature)

	# High humidity increases cooling needs (harder to cool)
	if current_humidity > 0.6 and current_temperature > 25:
		base *= 1.0 + (current_humidity - 0.6) * 0.5

	return base


func get_water_multiplier() -> float:
	## Returns water supply multiplier (biome scarcity affects pump output)
	if not current_biome:
		return 1.0
	return current_biome.get_water_multiplier()


func get_water_demand_multiplier() -> float:
	## Returns water demand multiplier based on temperature
	## Hot weather increases water usage for cooling, irrigation, drinking
	var mult = 1.0

	# Temperature-based demand increase
	# Base demand at 20°C, increases above that
	if current_temperature > 20:
		# +2% demand per degree above 20°C
		mult += (current_temperature - 20) * 0.02

	# Extreme heat dramatically increases demand
	if current_temperature > 30:
		# Additional +3% per degree above 30°C
		mult += (current_temperature - 30) * 0.03

	# Heat wave effect - sustained high temps mean even more water use
	if heat_wave_active:
		mult *= 1.25  # 25% extra during heat waves

	# High humidity slightly reduces water demand (less evaporation, less need to water plants)
	if current_humidity > 0.7:
		mult *= 0.95

	# Low humidity increases demand (more evaporation)
	if current_humidity < 0.3:
		mult *= 1.1

	# Cold weather slightly reduces demand
	if current_temperature < 10:
		mult *= 0.9
	if current_temperature < 0:
		mult *= 0.8  # Frozen pipes, less outdoor use

	return mult


func get_construction_cost_multiplier() -> float:
	if not current_biome:
		return 1.0

	var mult = current_biome.construction_cost_mult

	if is_storming:
		mult *= 1.25

	# Extreme temperatures slow construction
	if current_temperature < -5 or current_temperature > 38:
		mult *= 1.2
	elif current_temperature < 5 or current_temperature > 35:
		mult *= 1.1

	# Heavy rain slows construction
	if forecast.size() > 0 and forecast[0].precipitation_intensity > 0.5:
		mult *= 1.15

	return mult


func get_storm_damage_multiplier() -> float:
	if not current_biome:
		return 1.0

	var mult = current_biome.storm_damage_mult

	# Wind gusts are the main damage driver
	if current_wind_gusts > 80:
		mult *= 1.5
	elif current_wind_gusts > 60:
		mult *= 1.25

	# Climate change increases severity
	var years_elapsed = GameState.current_year - game_start_year
	mult *= (1.0 + years_elapsed * climate_extreme_increase * 0.5)

	return mult


# ============================================
# CLIMATE INFO
# ============================================

func get_climate_warming() -> float:
	return (GameState.current_year - game_start_year) * climate_warming_rate


func get_climate_extreme_factor() -> float:
	return 1.0 + (GameState.current_year - game_start_year) * climate_extreme_increase


func get_year_summary() -> String:
	var parts: PackedStringArray = []

	if year_temp_offset > 2.0:
		parts.append("Warmer than average")
	elif year_temp_offset < -2.0:
		parts.append("Cooler than average")

	if year_precip_modifier > 1.2:
		parts.append("Wet year")
	elif year_precip_modifier < 0.8:
		parts.append("Dry year")

	if year_storm_modifier > 1.3:
		parts.append("Storm-prone")

	if year_humidity_offset > 2.0:
		parts.append("Humid")
	elif year_humidity_offset < -2.0:
		parts.append("Low humidity")

	if parts.size() == 0:
		return "Normal conditions"

	return ", ".join(parts)


# ============================================
# UI/DISPLAY HELPERS
# ============================================

func get_temperature_string() -> String:
	return "%.0f C" % current_temperature


func get_temperature_string_f() -> String:
	return "%.0f F" % (current_temperature * 9.0 / 5.0 + 32.0)


func get_apparent_temperature() -> float:
	if forecast.size() > 0:
		return forecast[0].get_apparent_high()
	return current_temperature


func get_apparent_temperature_string() -> String:
	return "%.0f C" % get_apparent_temperature()


func get_humidity_string() -> String:
	return "%d%%" % int(current_humidity * 100)


func get_pressure_string() -> String:
	return "%.0f mb" % current_pressure


func get_wind_description() -> String:
	if current_wind_speed < 5:
		return "Calm"
	elif current_wind_speed < 12:
		return "Light breeze"
	elif current_wind_speed < 25:
		return "Moderate wind"
	elif current_wind_speed < 40:
		return "Fresh wind"
	elif current_wind_speed < 55:
		return "Strong wind"
	elif current_wind_speed < 75:
		return "Gale"
	else:
		return "Storm force"


func get_wind_cardinal() -> String:
	var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var index = int(round(current_wind_direction / 45.0)) % 8
	return dirs[index]


func get_weather_icon() -> String:
	match current_conditions:
		"Clear": return "sun"
		"Partly Cloudy": return "partly_cloudy"
		"Cloudy", "Overcast": return "cloud"
		"Hot": return "sun"
		"Cold": return "snowflake"
		"Rain", "Heavy Rain": return "rain"
		"Sleet", "Ice": return "sleet"
		"Snow": return "snow"
		"Storm": return "storm"
		"Blizzard": return "blizzard"
		_: return "sun"


func get_weather_summary() -> String:
	var summary = "%s, %s" % [current_conditions, get_temperature_string()]

	if is_storming:
		summary += " (Storm)"
	if flood_active:
		summary += " [FLOOD]"
	if heat_wave_active:
		summary += " [HEAT WAVE]"
	if cold_snap_active:
		summary += " [COLD SNAP]"

	return summary


func get_forecast_summary(days: int = 5) -> String:
	var lines: PackedStringArray = []

	for i in range(mini(days, forecast.size())):
		var day = forecast[i]
		var day_name = "Today" if i == 0 else ("Tomorrow" if i == 1 else "Day %d" % (i + 1))
		var line = "%s: %s, %.0f/%.0f C" % [day_name, day.conditions, day.high_temp, day.low_temp]

		if day.temp_uncertainty > 2:
			line += " (±%.0f)" % day.temp_uncertainty
		if day.front_passage:
			line += " [%s front]" % day.front_type.capitalize()
		if day.is_severe:
			line += " (!)"

		lines.append(line)

	return "\n".join(lines)


# ============================================
# SERIALIZATION
# ============================================

func get_save_data() -> Dictionary:
	var forecast_data: Array = []
	for day in forecast:
		forecast_data.append(day.to_dict())

	return {
		"temperature": current_temperature,
		"conditions": current_conditions,
		"cloud_cover": current_cloud_cover,
		"wind_speed": current_wind_speed,
		"wind_gusts": current_wind_gusts,
		"wind_direction": current_wind_direction,
		"pressure": current_pressure,
		"humidity": current_humidity,
		"dew_point": current_dew_point,
		"is_storming": is_storming,
		"storm_duration": storm_duration,
		"flood_active": flood_active,
		"heat_wave_active": heat_wave_active,
		"cold_snap_active": cold_snap_active,
		"drought_active": drought_active,
		"drought_severity": drought_severity,
		"drought_duration": drought_duration,
		"precipitation_deficit": precipitation_deficit,
		"drought_water_reduction": drought_water_reduction,
		"monthly_precipitation": monthly_precipitation,
		"year_temp_offset": year_temp_offset,
		"year_precip_modifier": year_precip_modifier,
		"year_storm_modifier": year_storm_modifier,
		"year_humidity_offset": year_humidity_offset,
		"game_start_year": game_start_year,
		"current_day_in_month": current_day_in_month,
		"pressure_long_wave_phase": pressure_long_wave_phase,
		"pressure_short_wave_phase": pressure_short_wave_phase,
		"active_front": active_front,
		"front_position": front_position,
		"next_front_type": next_front_type,
		"days_until_front": days_until_front,
		"forecast": forecast_data
	}


func load_save_data(data: Dictionary) -> void:
	current_temperature = data.get("temperature", 20.0)
	current_conditions = data.get("conditions", "Clear")
	current_cloud_cover = data.get("cloud_cover", 0.3)
	current_wind_speed = data.get("wind_speed", 10.0)
	current_wind_gusts = data.get("wind_gusts", 15.0)
	current_wind_direction = data.get("wind_direction", 180.0)
	current_pressure = data.get("pressure", 1013.0)
	current_humidity = data.get("humidity", 0.5)
	current_dew_point = data.get("dew_point", 10.0)
	is_storming = data.get("is_storming", false)
	storm_duration = data.get("storm_duration", 0)
	flood_active = data.get("flood_active", false)
	heat_wave_active = data.get("heat_wave_active", false)
	cold_snap_active = data.get("cold_snap_active", false)
	drought_active = data.get("drought_active", false)
	drought_severity = data.get("drought_severity", 0.0)
	drought_duration = data.get("drought_duration", 0)
	precipitation_deficit = data.get("precipitation_deficit", 0.0)
	drought_water_reduction = data.get("drought_water_reduction", 1.0)
	monthly_precipitation.clear()
	for p in data.get("monthly_precipitation", []):
		monthly_precipitation.append(p)
	year_temp_offset = data.get("year_temp_offset", 0.0)
	year_precip_modifier = data.get("year_precip_modifier", 1.0)
	year_storm_modifier = data.get("year_storm_modifier", 1.0)
	year_humidity_offset = data.get("year_humidity_offset", 0.0)
	game_start_year = data.get("game_start_year", GameState.current_year)
	current_day_in_month = data.get("current_day_in_month", 1)
	pressure_long_wave_phase = data.get("pressure_long_wave_phase", 0.0)
	pressure_short_wave_phase = data.get("pressure_short_wave_phase", 0.0)
	active_front = data.get("active_front", "none")
	front_position = data.get("front_position", 0.0)
	next_front_type = data.get("next_front_type", "none")
	days_until_front = data.get("days_until_front", -1)

	forecast.clear()
	for day_data in data.get("forecast", []):
		forecast.append(DailyForecast.from_dict(day_data))

	while forecast.size() < FORECAST_DAYS:
		var day = DailyForecast.new()
		day.day_index = forecast.size()
		forecast.append(day)

	weather_changed.emit(current_temperature, current_conditions)
	forecast_updated.emit(forecast)
