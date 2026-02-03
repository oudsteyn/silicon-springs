extends DashboardTabBase
class_name DashboardInfrastructureTab
## Infrastructure tab for the city dashboard - shows utility and network status


func build_content(container: VBoxContainer) -> void:
	container.add_child(_create_section_header("Infrastructure Condition"))

	# Road condition
	var road_info = VBoxContainer.new()
	container.add_child(road_info)

	var road_label = Label.new()
	road_label.text = "Road Network"
	road_info.add_child(road_label)

	var road_condition = _get_road_condition()
	var road_bar = _create_condition_bar(road_condition)
	road_info.add_child(road_bar)

	# Utilities condition
	container.add_child(_create_section_header("Utility Networks"))

	var util_grid = GridContainer.new()
	util_grid.columns = 2
	util_grid.add_theme_constant_override("h_separation", 20)
	util_grid.add_theme_constant_override("v_separation", 12)
	container.add_child(util_grid)

	_add_utility_row(util_grid, "Power Grid", GameState.power_supply, GameState.power_demand, "MW")
	_add_utility_row(util_grid, "Water System", GameState.water_supply, GameState.water_demand, "ML")

	# Water Pressure Section
	_build_water_pressure_section(container)

	# Energy Storage Section
	_build_energy_storage_section(container)

	# Grid Stability Section
	_build_grid_stability_section(container)


func _get_road_condition() -> float:
	var infra_system = _get_system("infrastructure_age")
	if infra_system and infra_system.has_method("get_average_condition"):
		return infra_system.get_average_condition("road")
	return 85.0  # Default placeholder


func _add_utility_row(grid: GridContainer, utility_name: String, supply: float, demand: float, unit: String) -> void:
	var name_label = Label.new()
	name_label.text = utility_name
	name_label.add_theme_font_size_override("font_size", 12)
	grid.add_child(name_label)

	var ratio = supply / max(1, demand)
	var status_text = "%d/%d %s (%d%%)" % [int(supply), int(demand), unit, int(ratio * 100)]
	var status_label = Label.new()
	status_label.text = status_text
	status_label.add_theme_font_size_override("font_size", 12)
	if ratio >= 1.0:
		status_label.add_theme_color_override("font_color", COLOR_GOOD)
	elif ratio >= 0.5:
		status_label.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		status_label.add_theme_color_override("font_color", COLOR_CRITICAL)
	grid.add_child(status_label)


func _build_water_pressure_section(container: VBoxContainer) -> void:
	var water_system = _get_system("water")
	if not water_system or not water_system.has_method("get_pressure_info"):
		return

	var pressure_info = water_system.get_pressure_info()

	container.add_child(_create_section_header("Water Pressure"))

	var pressure_container = VBoxContainer.new()
	pressure_container.add_theme_constant_override("separation", 4)
	container.add_child(pressure_container)

	# Pressure bar
	var pressure_row = HBoxContainer.new()
	pressure_row.add_theme_constant_override("separation", 10)
	pressure_container.add_child(pressure_row)

	var pressure_label = Label.new()
	pressure_label.text = "System Pressure:"
	pressure_label.add_theme_font_size_override("font_size", 12)
	pressure_row.add_child(pressure_label)

	var pressure_bar = ProgressBar.new()
	pressure_bar.custom_minimum_size = Vector2(150, 18)
	pressure_bar.value = pressure_info.pressure_pct
	pressure_bar.show_percentage = false
	if pressure_info.is_critical:
		pressure_bar.modulate = COLOR_CRITICAL
	elif pressure_info.is_warning:
		pressure_bar.modulate = COLOR_WARNING
	else:
		pressure_bar.modulate = COLOR_GOOD
	pressure_row.add_child(pressure_bar)

	var pressure_value = Label.new()
	pressure_value.text = "%d%% (%s)" % [pressure_info.pressure_pct, pressure_info.status]
	pressure_value.add_theme_font_size_override("font_size", 11)
	if pressure_info.is_critical:
		pressure_value.add_theme_color_override("font_color", COLOR_CRITICAL)
	elif pressure_info.is_warning:
		pressure_value.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		pressure_value.add_theme_color_override("font_color", COLOR_GOOD)
	pressure_row.add_child(pressure_value)

	# Infrastructure boost info
	if pressure_info.boost > 0 or pressure_info.towers > 0 or pressure_info.pumps > 0:
		var infra_row = HBoxContainer.new()
		infra_row.add_theme_constant_override("separation", 15)
		pressure_container.add_child(infra_row)

		if pressure_info.towers > 0:
			var tower_label = Label.new()
			tower_label.text = "Water Towers: %d (+%d%%)" % [pressure_info.towers, int(pressure_info.towers * 15)]
			tower_label.add_theme_font_size_override("font_size", 10)
			tower_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
			infra_row.add_child(tower_label)

		if pressure_info.pumps > 0:
			var pump_label = Label.new()
			pump_label.text = "Pumping Stations: %d (+%d%%)" % [pressure_info.pumps, int(pressure_info.pumps * 10)]
			pump_label.add_theme_font_size_override("font_size", 10)
			pump_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
			infra_row.add_child(pump_label)

	# Warning if pressure is low
	if pressure_info.is_warning:
		var warning_label = Label.new()
		if pressure_info.is_critical:
			warning_label.text = "Critical pressure! Distant buildings losing water service."
		else:
			warning_label.text = "Low pressure. Consider adding water towers or pumping stations."
		warning_label.add_theme_font_size_override("font_size", 10)
		warning_label.add_theme_color_override("font_color", COLOR_WARNING)
		warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		pressure_container.add_child(warning_label)


func _build_energy_storage_section(container: VBoxContainer) -> void:
	var power_system = _get_system("power")
	if not power_system or not power_system.has_method("get_storage_info"):
		return

	var storage_info = power_system.get_storage_info()
	if storage_info.total_capacity <= 0:
		return

	container.add_child(_create_section_header("Energy Storage"))

	var storage_container = VBoxContainer.new()
	storage_container.add_theme_constant_override("separation", 4)
	container.add_child(storage_container)

	# Storage bar
	var storage_row = HBoxContainer.new()
	storage_row.add_theme_constant_override("separation", 10)
	storage_container.add_child(storage_row)

	var storage_label = Label.new()
	storage_label.text = "Battery Charge:"
	storage_label.add_theme_font_size_override("font_size", 12)
	storage_row.add_child(storage_label)

	var storage_bar = ProgressBar.new()
	storage_bar.custom_minimum_size = Vector2(150, 18)
	storage_bar.value = storage_info.charge_percent
	storage_bar.show_percentage = false
	if storage_info.charge_percent < 20:
		storage_bar.modulate = COLOR_CRITICAL
	elif storage_info.charge_percent < 50:
		storage_bar.modulate = COLOR_WARNING
	else:
		storage_bar.modulate = COLOR_GOOD
	storage_row.add_child(storage_bar)

	var storage_value = Label.new()
	var status_text = "Charging" if storage_info.is_charging else ("Discharging" if storage_info.is_discharging else "Idle")
	storage_value.text = "%.0f/%.0f MWh (%s)" % [storage_info.total_stored, storage_info.total_capacity, status_text]
	storage_value.add_theme_font_size_override("font_size", 11)
	storage_row.add_child(storage_value)

	var buildings_label = Label.new()
	buildings_label.text = "Storage facilities: %d" % storage_info.building_count
	buildings_label.add_theme_font_size_override("font_size", 10)
	buildings_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	storage_container.add_child(buildings_label)


func _build_grid_stability_section(container: VBoxContainer) -> void:
	var power_system = _get_system("power")
	if not power_system or not power_system.has_method("get_grid_info"):
		return

	var grid_info = power_system.get_grid_info()

	container.add_child(_create_section_header("Grid Stability"))

	var stability_container = VBoxContainer.new()
	stability_container.add_theme_constant_override("separation", 4)
	container.add_child(stability_container)

	# Stability bar
	var stability_row = HBoxContainer.new()
	stability_row.add_theme_constant_override("separation", 10)
	stability_container.add_child(stability_row)

	var stability_label = Label.new()
	stability_label.text = "Grid Stability:"
	stability_label.add_theme_font_size_override("font_size", 12)
	stability_row.add_child(stability_label)

	var stability_bar = ProgressBar.new()
	stability_bar.custom_minimum_size = Vector2(150, 18)
	stability_bar.value = grid_info.stability * 100
	stability_bar.show_percentage = false
	if grid_info.stability < 0.5:
		stability_bar.modulate = COLOR_CRITICAL
	elif grid_info.stability < 0.8:
		stability_bar.modulate = COLOR_WARNING
	else:
		stability_bar.modulate = COLOR_GOOD
	stability_row.add_child(stability_bar)

	var stability_value = Label.new()
	stability_value.text = "%d%% (%s)" % [int(grid_info.stability * 100), grid_info.status]
	stability_value.add_theme_font_size_override("font_size", 11)
	stability_row.add_child(stability_value)

	# Frequency info
	var freq_label = Label.new()
	freq_label.text = "Grid frequency: %.2f Hz" % grid_info.frequency
	freq_label.add_theme_font_size_override("font_size", 10)
	freq_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	stability_container.add_child(freq_label)
