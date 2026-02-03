extends DashboardTabBase
class_name DashboardEnvironmentTab
## Environment tab for the city dashboard - shows pollution, air quality, weather


func build_content(container: VBoxContainer) -> void:
	# Air Quality Section
	_build_air_quality_section(container)

	# Weather Section
	_build_weather_section(container)

	# Pollution Section
	_build_pollution_section(container)

	# Environmental Stats
	container.add_child(_create_section_header("Environmental Statistics"))
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 20)
	stats_grid.add_theme_constant_override("v_separation", 6)
	container.add_child(stats_grid)

	var pollution_system = _get_system("pollution")
	if pollution_system:
		var avg_pollution = pollution_system.get_average_pollution() if pollution_system.has_method("get_average_pollution") else 0.0
		var polluted_res = pollution_system.get_polluted_residential_count() if pollution_system.has_method("get_polluted_residential_count") else 0
		_add_stat_row(stats_grid, "Average Pollution", "%d%%" % int(avg_pollution * 100))
		_add_stat_row(stats_grid, "Polluted Residences", str(polluted_res))


func _build_air_quality_section(container: VBoxContainer) -> void:
	var pollution_system = _get_system("pollution")
	if not pollution_system:
		return

	container.add_child(_create_section_header("Air Quality"))

	var aqi_container = HBoxContainer.new()
	aqi_container.add_theme_constant_override("separation", 15)
	container.add_child(aqi_container)

	var aqi = pollution_system.get_air_quality_index() if pollution_system.has_method("get_air_quality_index") else 0.0
	var category = pollution_system.get_air_quality_category() if pollution_system.has_method("get_air_quality_category") else "Good"

	var aqi_label = Label.new()
	aqi_label.text = "AQI: %d" % int(aqi)
	aqi_label.add_theme_font_size_override("font_size", 16)
	aqi_label.add_theme_color_override("font_color", _get_aqi_color(aqi))
	aqi_container.add_child(aqi_label)

	var category_label = Label.new()
	category_label.text = "(%s)" % category
	category_label.add_theme_font_size_override("font_size", 14)
	category_label.add_theme_color_override("font_color", _get_aqi_color(aqi))
	aqi_container.add_child(category_label)

	# Smog alert
	if pollution_system.has_method("is_smog_alert") and pollution_system.is_smog_alert():
		var smog_label = Label.new()
		smog_label.text = "SMOG ALERT - Limit outdoor activities"
		smog_label.add_theme_font_size_override("font_size", 11)
		smog_label.add_theme_color_override("font_color", COLOR_WARNING)
		container.add_child(smog_label)

	# Wildfire smoke
	if pollution_system.has_method("is_wildfire_active") and pollution_system.is_wildfire_active():
		var fire_label = Label.new()
		fire_label.text = "Regional wildfire affecting air quality"
		fire_label.add_theme_font_size_override("font_size", 11)
		fire_label.add_theme_color_override("font_color", COLOR_CRITICAL)
		container.add_child(fire_label)


func _build_weather_section(container: VBoxContainer) -> void:
	var weather_system = _get_system("weather")
	if not weather_system:
		return

	container.add_child(_create_section_header("Current Weather"))

	var weather_grid = GridContainer.new()
	weather_grid.columns = 2
	weather_grid.add_theme_constant_override("h_separation", 20)
	weather_grid.add_theme_constant_override("v_separation", 6)
	container.add_child(weather_grid)

	if weather_system.has_method("get_temperature"):
		_add_stat_row(weather_grid, "Temperature", "%.1f C" % weather_system.get_temperature())

	if weather_system.has_method("get_conditions"):
		_add_stat_row(weather_grid, "Conditions", weather_system.get_conditions())

	if weather_system.has_method("get_wind_speed"):
		_add_stat_row(weather_grid, "Wind Speed", "%.0f km/h" % weather_system.get_wind_speed())

	if weather_system.has_method("get_humidity"):
		_add_stat_row(weather_grid, "Humidity", "%d%%" % int(weather_system.get_humidity() * 100))


func _build_pollution_section(container: VBoxContainer) -> void:
	var pollution_system = _get_system("pollution")
	if not pollution_system:
		return

	container.add_child(_create_section_header("Pollution Sources"))

	var pollution_grid = GridContainer.new()
	pollution_grid.columns = 2
	pollution_grid.add_theme_constant_override("h_separation", 20)
	pollution_grid.add_theme_constant_override("v_separation", 6)
	container.add_child(pollution_grid)

	# Get polluter count
	var polluter_count = pollution_system.polluters.size() if "polluters" in pollution_system else 0
	_add_stat_row(pollution_grid, "Industrial Polluters", str(polluter_count))

	# Green infrastructure
	var green_count = pollution_system.green_infrastructure_cells.size() if "green_infrastructure_cells" in pollution_system else 0
	_add_stat_row(pollution_grid, "Green Infrastructure", str(green_count) + " cells")


func _get_aqi_color(aqi: float) -> Color:
	if aqi <= 50:
		return COLOR_GOOD
	elif aqi <= 100:
		return Color(0.9, 0.9, 0.0)  # Yellow
	elif aqi <= 150:
		return Color(1.0, 0.6, 0.0)  # Orange
	elif aqi <= 200:
		return COLOR_CRITICAL
	else:
		return Color(0.5, 0.0, 0.3)  # Purple/hazardous
