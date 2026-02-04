extends TestBase
## Tests for DailyForecast data object.

const DailyForecast = preload("res://src/systems/daily_forecast.gd")


func test_cloud_description_thresholds() -> void:
	var day = DailyForecast.new()

	day.cloud_cover = 0.05
	assert_eq(day.get_cloud_description(), "Clear")

	day.cloud_cover = 0.2
	assert_eq(day.get_cloud_description(), "Mostly Clear")

	day.cloud_cover = 0.4
	assert_eq(day.get_cloud_description(), "Partly Cloudy")

	day.cloud_cover = 0.6
	assert_eq(day.get_cloud_description(), "Mostly Cloudy")

	day.cloud_cover = 0.8
	assert_eq(day.get_cloud_description(), "Cloudy")

	day.cloud_cover = 0.95
	assert_eq(day.get_cloud_description(), "Overcast")


func test_apparent_temperature_heat_index() -> void:
	var day = DailyForecast.new()
	day.high_temp = 30.0
	day.humidity = 0.6
	day.wind_speed = 5.0

	# heat index: temp + (rh - 0.4) * (temp - 26) * 0.5
	var expected = 30.0 + (0.6 - 0.4) * (30.0 - 26.0) * 0.5
	assert_approx(day.get_apparent_high(), expected, 0.0001)


func test_to_dict_round_trip() -> void:
	var day = DailyForecast.new()
	day.day_index = 2
	day.high_temp = 31.5
	day.low_temp = 12.25
	day.conditions = "Rain"
	day.precipitation_chance = 0.8
	day.precipitation_type = "rain"
	day.pressure = 1005.0
	day.wind_direction = 90.0
	day.front_type = "cold"
	day.storm_phase = "mature"
	day.storm_intensity = 0.7

	var data = day.to_dict()
	var restored = DailyForecast.from_dict(data)

	assert_eq(restored.day_index, 2)
	assert_eq(restored.high_temp, 31.5)
	assert_eq(restored.low_temp, 12.25)
	assert_eq(restored.conditions, "Rain")
	assert_eq(restored.precipitation_chance, 0.8)
	assert_eq(restored.precipitation_type, "rain")
	assert_eq(restored.pressure, 1005.0)
	assert_eq(restored.wind_direction, 90.0)
	assert_eq(restored.front_type, "cold")
	assert_eq(restored.storm_phase, "mature")
	assert_eq(restored.storm_intensity, 0.7)
