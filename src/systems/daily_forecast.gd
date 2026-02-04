extends RefCounted
class_name DailyForecast
## Forecast data container with helper methods for derived values.

var day_index: int = 0  # 0 = today, 1 = tomorrow, etc.

# Temperature
var high_temp: float = 20.0
var low_temp: float = 15.0
var temp_uncertainty: float = 1.0  # ± degrees, increases with forecast distance

# Conditions
var conditions: String = "Clear"
var precipitation_chance: float = 0.0  # 0.0 to 1.0
var precipitation_type: String = "none"  # "none", "rain", "snow", "sleet", "freezing_rain"
var precipitation_intensity: float = 0.0  # 0-1 scale
var is_severe: bool = false

# Clouds and visibility
var cloud_cover: float = 0.2  # 0.0 = clear, 1.0 = overcast
var fog_chance: float = 0.0  # Morning fog probability

# Wind
var wind_speed: float = 10.0  # km/h sustained
var wind_gusts: float = 15.0  # km/h peak
var wind_direction: float = 180.0  # degrees (0=N, 90=E, 180=S, 270=W)

# Pressure system
var pressure: float = 1013.0  # millibars/hPa
var pressure_trend: String = "steady"  # "rising", "falling", "steady"
var pressure_change: float = 0.0  # mb change from previous day

# Humidity
var dew_point: float = 10.0  # Celsius - more stable than RH
var humidity: float = 0.5  # Relative humidity 0-1 (calculated from temp and dew point)

# Frontal systems
var front_type: String = "none"  # "cold", "warm", "stationary", "occluded", "none"
var front_passage: bool = false  # Does a front pass through on this day?
var front_timing: String = ""  # "morning", "afternoon", "evening", "overnight"

# Storm lifecycle
var storm_phase: String = "none"  # "developing", "mature", "dissipating", "none"
var storm_intensity: float = 0.0  # 0-1, peaks during mature phase


func get_avg_temp() -> float:
	return (high_temp + low_temp) / 2.0


func get_diurnal_range() -> float:
	return high_temp - low_temp


func get_apparent_high() -> float:
	## Heat index / wind chill adjusted temperature
	return _calculate_apparent_temp(high_temp, humidity, wind_speed)


func get_apparent_low() -> float:
	return _calculate_apparent_temp(low_temp, humidity * 1.2, wind_speed * 0.3)


func _calculate_apparent_temp(temp: float, rh: float, wind: float) -> float:
	# Heat index when hot and humid
	if temp > 26 and rh > 0.4:
		# Simplified heat index
		var hi = temp + (rh - 0.4) * (temp - 26) * 0.5
		return hi
	# Wind chill when cold and windy
	elif temp < 10 and wind > 5:
		# Simplified wind chill
		var wc = temp - (wind * 0.1) * (10 - temp) * 0.05
		return wc
	return temp


func get_humidity_from_dewpoint(temp: float) -> float:
	## Calculate relative humidity from temperature and dew point
	## Using Magnus formula approximation
	if temp <= dew_point:
		return 1.0
	var rh = exp((17.27 * dew_point) / (237.7 + dew_point) - (17.27 * temp) / (237.7 + temp))
	return clampf(rh, 0.0, 1.0)


func update_humidity() -> void:
	## Recalculate humidity from current temp and dew point
	humidity = get_humidity_from_dewpoint(get_avg_temp())


func get_cloud_description() -> String:
	if cloud_cover < 0.1:
		return "Clear"
	elif cloud_cover < 0.25:
		return "Mostly Clear"
	elif cloud_cover < 0.5:
		return "Partly Cloudy"
	elif cloud_cover < 0.7:
		return "Mostly Cloudy"
	elif cloud_cover < 0.9:
		return "Cloudy"
	else:
		return "Overcast"


func get_wind_description() -> String:
	if wind_speed < 5:
		return "Calm"
	elif wind_speed < 12:
		return "Light"
	elif wind_speed < 25:
		return "Moderate"
	elif wind_speed < 40:
		return "Fresh"
	elif wind_speed < 55:
		return "Strong"
	elif wind_speed < 75:
		return "Gale"
	else:
		return "Storm"


func get_wind_cardinal() -> String:
	var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var index = int(round(wind_direction / 45.0)) % 8
	return dirs[index]


func get_pressure_description() -> String:
	if pressure > 1025:
		return "High"
	elif pressure > 1015:
		return "Normal"
	elif pressure > 1005:
		return "Low"
	else:
		return "Very Low"


func get_humidity_description() -> String:
	if humidity < 0.3:
		return "Dry"
	elif humidity < 0.5:
		return "Comfortable"
	elif humidity < 0.7:
		return "Humid"
	else:
		return "Very Humid"


func get_comfort_level() -> String:
	var apparent = get_apparent_high()
	if apparent > 35:
		return "Dangerous Heat"
	elif apparent > 32:
		return "Very Hot"
	elif apparent > 28:
		return "Hot"
	elif apparent > 18 and apparent < 26:
		return "Comfortable"
	elif apparent < 0:
		return "Freezing"
	elif apparent < 10:
		return "Cold"
	else:
		return "Cool"


func to_dict() -> Dictionary:
	return {
		"day_index": day_index,
		"high_temp": high_temp,
		"low_temp": low_temp,
		"temp_uncertainty": temp_uncertainty,
		"conditions": conditions,
		"precipitation_chance": precipitation_chance,
		"precipitation_type": precipitation_type,
		"precipitation_intensity": precipitation_intensity,
		"is_severe": is_severe,
		"cloud_cover": cloud_cover,
		"fog_chance": fog_chance,
		"wind_speed": wind_speed,
		"wind_gusts": wind_gusts,
		"wind_direction": wind_direction,
		"pressure": pressure,
		"pressure_trend": pressure_trend,
		"pressure_change": pressure_change,
		"dew_point": dew_point,
		"humidity": humidity,
		"front_type": front_type,
		"front_passage": front_passage,
		"front_timing": front_timing,
		"storm_phase": storm_phase,
		"storm_intensity": storm_intensity
	}


static func from_dict(data: Dictionary) -> DailyForecast:
	var f = DailyForecast.new()
	f.day_index = data.get("day_index", 0)
	f.high_temp = data.get("high_temp", 20.0)
	f.low_temp = data.get("low_temp", 15.0)
	f.temp_uncertainty = data.get("temp_uncertainty", 1.0)
	f.conditions = data.get("conditions", "Clear")
	f.precipitation_chance = data.get("precipitation_chance", 0.0)
	f.precipitation_type = data.get("precipitation_type", "none")
	f.precipitation_intensity = data.get("precipitation_intensity", 0.0)
	f.is_severe = data.get("is_severe", false)
	f.cloud_cover = data.get("cloud_cover", 0.2)
	f.fog_chance = data.get("fog_chance", 0.0)
	f.wind_speed = data.get("wind_speed", 10.0)
	f.wind_gusts = data.get("wind_gusts", 15.0)
	f.wind_direction = data.get("wind_direction", 180.0)
	f.pressure = data.get("pressure", 1013.0)
	f.pressure_trend = data.get("pressure_trend", "steady")
	f.pressure_change = data.get("pressure_change", 0.0)
	f.dew_point = data.get("dew_point", 10.0)
	f.humidity = data.get("humidity", 0.5)
	f.front_type = data.get("front_type", "none")
	f.front_passage = data.get("front_passage", false)
	f.front_timing = data.get("front_timing", "")
	f.storm_phase = data.get("storm_phase", "none")
	f.storm_intensity = data.get("storm_intensity", 0.0)
	return f
