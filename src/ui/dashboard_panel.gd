extends CanvasLayer
class_name DashboardPanel
## Comprehensive city overview dashboard with all key metrics

signal panel_requested(panel_name: String)

# Tab containers
var current_tab: int = 0
var panel_visible: bool = false

# Status indicator colors - use centralized theme
# DEPRECATED: Use UIManager.get_status_color() instead
var COLOR_GOOD: Color:
	get: return ThemeConstants.STATUS_GOOD
var COLOR_WARNING: Color:
	get: return ThemeConstants.STATUS_WARNING
var COLOR_CRITICAL: Color:
	get: return ThemeConstants.STATUS_CRITICAL
var COLOR_NEUTRAL: Color:
	get: return ThemeConstants.STATUS_NEUTRAL
var COLOR_POSITIVE: Color:
	get: return ThemeConstants.STATUS_GOOD
var COLOR_NEGATIVE: Color:
	get: return ThemeConstants.STATUS_CRITICAL

# UI References (created dynamically)
var main_panel: PanelContainer
var tab_bar: HBoxContainer
var content_container: VBoxContainer
var tabs: Dictionary = {}

# Modular tab components
var _tab_components: Dictionary = {}  # {tab_index: DashboardTabBase}


func _ready() -> void:
	layer = 95
	visible = false

	# Create centered panel container
	var center_container = CenterContainer.new()
	center_container.anchor_left = 0.0
	center_container.anchor_right = 1.0
	center_container.anchor_top = 0.0
	center_container.anchor_bottom = 1.0
	add_child(center_container)

	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(650, 450)

	# Style the panel using centralized theme
	var stylebox = UIManager.get_modal_style()
	stylebox.bg_color = Color(0.08, 0.10, 0.14, 0.98)
	stylebox.content_margin_top = ThemeConstants.PADDING_LARGE - 4
	main_panel.add_theme_stylebox_override("panel", stylebox)
	center_container.add_child(main_panel)

	_build_ui()
	_connect_signals()


func toggle() -> void:
	if panel_visible:
		hide_panel()
	else:
		show_panel()


func show_panel() -> void:
	if panel_visible:
		return
	panel_visible = true
	visible = true
	_update_all()


func hide_panel() -> void:
	if not panel_visible:
		return
	panel_visible = false
	visible = false


func _build_ui() -> void:
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	main_panel.add_child(main_vbox)

	# Header with title and close button
	var header = _create_header()
	main_vbox.add_child(header)

	# Tab bar
	tab_bar = _create_tab_bar()
	main_vbox.add_child(tab_bar)

	# Separator
	var sep = HSeparator.new()
	main_vbox.add_child(sep)

	# Content area with scroll
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 350)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 12)
	scroll.add_child(content_container)

	# Build tab content
	_build_overview_tab()


func _create_header() -> HBoxContainer:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)

	var title = Label.new()
	title.text = "City Dashboard"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(toggle)
	header.add_child(close_btn)

	return header


func _create_tab_bar() -> HBoxContainer:
	var bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)

	var tab_names = ["Overview", "Infrastructure", "Economy", "Environment", "Districts"]

	for i in range(tab_names.size()):
		var btn = Button.new()
		btn.text = tab_names[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.custom_minimum_size = Vector2(100, 32)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		bar.add_child(btn)
		tabs[i] = btn

	return bar


func _on_tab_pressed(index: int) -> void:
	current_tab = index

	# Update button states
	for i in tabs:
		tabs[i].button_pressed = (i == index)

	# Rebuild content
	for child in content_container.get_children():
		child.queue_free()

	# Use modular tab components
	var tab_component = _get_or_create_tab(index)
	if tab_component:
		tab_component.build_content(content_container)
	else:
		# Fallback to legacy methods
		match index:
			0: _build_overview_tab()
			1: _build_infrastructure_tab()
			2: _build_economy_tab()
			3: _build_environment_tab()
			4: _build_districts_tab()


func _get_or_create_tab(index: int) -> DashboardTabBase:
	if _tab_components.has(index):
		return _tab_components[index]

	var tab: DashboardTabBase = null
	match index:
		0:
			tab = DashboardOverviewTab.new()
			if tab.has_signal("panel_requested"):
				tab.panel_requested.connect(func(panel_name): panel_requested.emit(panel_name))
		1:
			tab = DashboardInfrastructureTab.new()
		2:
			tab = DashboardEconomyTab.new()
		3:
			tab = DashboardEnvironmentTab.new()
		4:
			tab = DashboardDistrictsTab.new()

	if tab:
		_tab_components[index] = tab

	return tab


func _build_overview_tab() -> void:
	# Quick Status Cards Row
	var cards_row = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 12)
	content_container.add_child(cards_row)

	# Population Card
	cards_row.add_child(_create_stat_card(
		"Population",
		_format_number(GameState.population),
		"Happiness: %d%%" % int(GameState.happiness * 100),
		_get_happiness_color()
	))

	# Budget Card
	var net = GameState.monthly_income - GameState.monthly_expenses
	cards_row.add_child(_create_stat_card(
		"Budget",
		"$%s" % _format_number(GameState.budget),
		"%s$%s/mo" % ["+" if net >= 0 else "-", _format_number(abs(net))],
		COLOR_GOOD if net >= 0 else COLOR_CRITICAL
	))

	# Power Card
	var power_ratio = GameState.power_supply / max(1, GameState.power_demand)
	cards_row.add_child(_create_stat_card(
		"Power",
		"%d MW" % int(GameState.power_supply),
		"%d%% capacity" % int(power_ratio * 100),
		COLOR_GOOD if power_ratio >= 1.0 else (COLOR_WARNING if power_ratio >= 0.5 else COLOR_CRITICAL)
	))

	# Water Card
	var water_ratio = GameState.water_supply / max(1, GameState.water_demand)
	cards_row.add_child(_create_stat_card(
		"Water",
		"%d ML" % int(GameState.water_supply),
		"%d%% capacity" % int(water_ratio * 100),
		COLOR_GOOD if water_ratio >= 1.0 else (COLOR_WARNING if water_ratio >= 0.5 else COLOR_CRITICAL)
	))

	# Happiness Breakdown Section
	_build_happiness_breakdown()

	# Alerts Section
	var alerts = _get_active_alerts()
	if alerts.size() > 0:
		content_container.add_child(_create_section_header("Active Alerts"))
		for alert in alerts:
			content_container.add_child(_create_alert_item(alert.message, alert.type))

	# Quick Actions
	content_container.add_child(_create_section_header("Quick Actions"))
	var actions_row = HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 8)
	content_container.add_child(actions_row)

	var budget_btn = _create_action_button("Budget (B)", "budget")
	budget_btn.tooltip_text = "View detailed budget breakdown\nShortcut: B"
	var advisors_btn = _create_action_button("Advisors (A)", "advisors")
	advisors_btn.tooltip_text = "Get advice from city advisors\nShortcut: A"
	var ordinances_btn = _create_action_button("Ordinances (O)", "ordinances")
	ordinances_btn.tooltip_text = "Manage city ordinances and policies\nShortcut: O"
	var deals_btn = _create_action_button("Trade (T)", "deals")
	deals_btn.tooltip_text = "Buy/sell power and water from neighbors\nShortcut: T"

	actions_row.add_child(budget_btn)
	actions_row.add_child(advisors_btn)
	actions_row.add_child(ordinances_btn)
	actions_row.add_child(deals_btn)

	# City Stats Grid
	content_container.add_child(_create_section_header("City Statistics"))
	var stats_grid = GridContainer.new()
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", 20)
	stats_grid.add_theme_constant_override("v_separation", 8)
	content_container.add_child(stats_grid)

	_add_stat_row(stats_grid, "Employment", "%d%%" % int(GameState.get_employment_ratio() * 100))
	_add_stat_row(stats_grid, "Education Rate", "%d%%" % int(GameState.education_rate * 100))
	_add_stat_row(stats_grid, "Crime Rate", "%d%%" % int(GameState.city_crime_rate * 100))
	_add_stat_row(stats_grid, "Traffic Congestion", "%d%%" % int(GameState.city_traffic_congestion * 100))
	_add_stat_row(stats_grid, "Residential Zones", str(GameState.residential_zones))
	_add_stat_row(stats_grid, "Commercial Zones", str(GameState.commercial_zones))
	_add_stat_row(stats_grid, "Industrial Zones", str(GameState.industrial_zones))
	_add_stat_row(stats_grid, "City Score", _format_number(GameState.score))
	_add_stat_row(stats_grid, "Game Date", GameState.get_date_string())


func _build_infrastructure_tab() -> void:
	content_container.add_child(_create_section_header("Infrastructure Condition"))

	# Road condition
	var road_info = VBoxContainer.new()
	content_container.add_child(road_info)

	var road_label = Label.new()
	road_label.text = "Road Network"
	road_info.add_child(road_label)

	var road_bar = _create_condition_bar(85.0)  # Placeholder
	road_info.add_child(road_bar)

	# Utilities condition
	content_container.add_child(_create_section_header("Utility Networks"))

	var util_grid = GridContainer.new()
	util_grid.columns = 2
	util_grid.add_theme_constant_override("h_separation", 20)
	util_grid.add_theme_constant_override("v_separation", 12)
	content_container.add_child(util_grid)

	_add_utility_row(util_grid, "Power Grid", GameState.power_supply, GameState.power_demand, "MW")
	_add_utility_row(util_grid, "Water System", GameState.water_supply, GameState.water_demand, "ML")

	# Water Pressure Section
	var water_system = _get_water_system()
	if water_system and water_system.has_method("get_pressure_info"):
		var pressure_info = water_system.get_pressure_info()

		content_container.add_child(_create_section_header("Water Pressure"))

		var pressure_container = VBoxContainer.new()
		pressure_container.add_theme_constant_override("separation", 4)
		content_container.add_child(pressure_container)

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
				warning_label.text = "⚠ Critical pressure! Distant buildings losing water service."
			else:
				warning_label.text = "⚠ Low pressure. Consider adding water towers or pumping stations."
			warning_label.add_theme_font_size_override("font_size", 10)
			warning_label.add_theme_color_override("font_color", COLOR_WARNING)
			warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			pressure_container.add_child(warning_label)

	# Energy Storage Section
	var power_system = _get_power_system()
	if power_system and power_system.has_method("get_storage_info"):
		var storage_info = power_system.get_storage_info()
		if storage_info.total_capacity > 0:
			content_container.add_child(_create_section_header("Energy Storage"))

			var storage_container = VBoxContainer.new()
			storage_container.add_theme_constant_override("separation", 4)
			content_container.add_child(storage_container)

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

	# Storm Outage Section
	if power_system and power_system.has_method("get_storm_outage_info"):
		var outage_info = power_system.get_storm_outage_info()
		if outage_info.active:
			content_container.add_child(_create_section_header("Storm Damage"))

			var outage_container = VBoxContainer.new()
			outage_container.add_theme_constant_override("separation", 4)
			content_container.add_child(outage_container)

			# Severity indicator
			var severity_row = HBoxContainer.new()
			severity_row.add_theme_constant_override("separation", 10)
			outage_container.add_child(severity_row)

			var severity_label = Label.new()
			severity_label.text = "⚠ Power Outage:"
			severity_label.add_theme_font_size_override("font_size", 12)
			severity_label.add_theme_color_override("font_color", COLOR_WARNING)
			severity_row.add_child(severity_label)

			var severity_value = Label.new()
			severity_value.text = "%d%% of grid affected (%d areas)" % [outage_info.severity_pct, outage_info.affected_cells]
			severity_value.add_theme_font_size_override("font_size", 11)
			severity_value.add_theme_color_override("font_color", COLOR_CRITICAL)
			severity_row.add_child(severity_value)

			# Restoration progress
			var restore_row = HBoxContainer.new()
			restore_row.add_theme_constant_override("separation", 10)
			outage_container.add_child(restore_row)

			var restore_label = Label.new()
			restore_label.text = "Restoration:"
			restore_label.add_theme_font_size_override("font_size", 12)
			restore_row.add_child(restore_label)

			var restore_bar = ProgressBar.new()
			restore_bar.custom_minimum_size = Vector2(150, 18)
			restore_bar.value = outage_info.restoration_pct
			restore_bar.show_percentage = false
			restore_bar.modulate = COLOR_GOOD
			restore_row.add_child(restore_bar)

			var restore_value = Label.new()
			restore_value.text = "%d%% complete" % outage_info.restoration_pct
			restore_value.add_theme_font_size_override("font_size", 11)
			restore_row.add_child(restore_value)

			var repair_info = Label.new()
			repair_info.text = "Repair crews working at %.1f areas/month" % outage_info.repair_rate
			repair_info.add_theme_font_size_override("font_size", 10)
			repair_info.add_theme_color_override("font_color", COLOR_NEUTRAL)
			outage_container.add_child(repair_info)

	# Service Coverage
	content_container.add_child(_create_section_header("Service Coverage"))
	var coverage_text = Label.new()
	coverage_text.text = "Fire, Police, and Education coverage statistics"
	coverage_text.add_theme_color_override("font_color", COLOR_NEUTRAL)
	content_container.add_child(coverage_text)


func _build_economy_tab() -> void:
	content_container.add_child(_create_section_header("Financial Overview"))

	var income_card = _create_budget_summary()
	content_container.add_child(income_card)

	content_container.add_child(_create_section_header("Employment"))

	var employment_grid = GridContainer.new()
	employment_grid.columns = 2
	employment_grid.add_theme_constant_override("h_separation", 40)
	employment_grid.add_theme_constant_override("v_separation", 8)
	content_container.add_child(employment_grid)

	_add_stat_row(employment_grid, "Total Jobs", _format_number(GameState.jobs_available))
	_add_stat_row(employment_grid, "Employed", _format_number(GameState.employed_population))
	_add_stat_row(employment_grid, "Skilled Jobs", _format_number(GameState.skilled_jobs_available))
	_add_stat_row(employment_grid, "Unskilled Jobs", _format_number(GameState.unskilled_jobs_available))

	content_container.add_child(_create_section_header("Demand Indicators"))
	var demand_row = HBoxContainer.new()
	demand_row.add_theme_constant_override("separation", 20)
	content_container.add_child(demand_row)

	# Get demand breakdown for tooltips
	var demand_result = DemandCalculator.calculate_with_breakdown(
		GameState.population,
		GameState.jobs_available,
		GameState.commercial_zones,
		GameState.industrial_zones,
		GameState.educated_population,
		GameState.has_power_shortage(),
		GameState.has_water_shortage(),
		GameState.city_traffic_congestion,
		GameState.city_crime_rate
	)

	demand_row.add_child(_create_demand_indicator("Residential", GameState.residential_demand, Color(0.3, 0.7, 0.4), demand_result.residential))
	demand_row.add_child(_create_demand_indicator("Commercial", GameState.commercial_demand, Color(0.3, 0.5, 0.8), demand_result.commercial))
	demand_row.add_child(_create_demand_indicator("Industrial", GameState.industrial_demand, Color(0.8, 0.7, 0.3), demand_result.industrial))

	# Weather Effects on Economy
	content_container.add_child(_create_section_header("Weather Effects"))

	var weather_system = _get_weather_system()
	var weather_effects_grid = GridContainer.new()
	weather_effects_grid.columns = 2
	weather_effects_grid.add_theme_constant_override("h_separation", 40)
	weather_effects_grid.add_theme_constant_override("v_separation", 8)
	content_container.add_child(weather_effects_grid)

	# Get weather modifiers
	var heating_mult = 1.0
	var cooling_mult = 1.0
	var construction_mult = 1.0
	var current_temp = 20.0

	if weather_system:
		if weather_system.has_method("get_heating_modifier"):
			heating_mult = weather_system.get_heating_modifier()
		if weather_system.has_method("get_cooling_modifier"):
			cooling_mult = weather_system.get_cooling_modifier()
		if weather_system.has_method("get_construction_cost_multiplier"):
			construction_mult = weather_system.get_construction_cost_multiplier()
		if weather_system.get("current_temperature") != null:
			current_temp = weather_system.current_temperature

	# Temperature display
	var temp_color = COLOR_NEUTRAL
	if current_temp < 5:
		temp_color = Color(0.4, 0.6, 0.9)  # Cold blue
	elif current_temp > 30:
		temp_color = Color(0.9, 0.5, 0.3)  # Hot orange

	_add_stat_row_colored(weather_effects_grid, "Temperature", "%.0f°C" % current_temp, temp_color)

	# Heating costs
	var heating_color = COLOR_POSITIVE
	var heating_text = "%.0f%%" % (heating_mult * 100)
	if heating_mult > 1.2:
		heating_color = COLOR_NEGATIVE
		heating_text += " (Cold penalty)"
	elif heating_mult > 1.0:
		heating_color = COLOR_WARNING
		heating_text += " (Elevated)"
	else:
		heating_text += " (Normal)"
	_add_stat_row_colored(weather_effects_grid, "Heating Costs", heating_text, heating_color)

	# Cooling costs
	var cooling_color = COLOR_POSITIVE
	var cooling_text = "%.0f%%" % (cooling_mult * 100)
	if cooling_mult > 1.2:
		cooling_color = COLOR_NEGATIVE
		cooling_text += " (Heat penalty)"
	elif cooling_mult > 1.0:
		cooling_color = COLOR_WARNING
		cooling_text += " (Elevated)"
	else:
		cooling_text += " (Normal)"
	_add_stat_row_colored(weather_effects_grid, "Cooling Costs", cooling_text, cooling_color)

	# Construction costs
	var construction_color = COLOR_POSITIVE
	var construction_text = "%.0f%%" % (construction_mult * 100)
	if construction_mult > 1.2:
		construction_color = COLOR_NEGATIVE
		construction_text += " (Weather penalty)"
	elif construction_mult > 1.0:
		construction_color = COLOR_WARNING
		construction_text += " (Elevated)"
	else:
		construction_text += " (Normal)"
	_add_stat_row_colored(weather_effects_grid, "Construction", construction_text, construction_color)

	# Additional weather impacts summary
	var impacts: Array[String] = []
	if weather_system:
		if weather_system.get("is_storming") == true:
			impacts.append("Storm reducing productivity")
		if weather_system.get("drought_active") == true:
			impacts.append("Drought increasing water costs")
		if weather_system.get("is_flooding") == true:
			impacts.append("Flooding disrupting commerce")

	if impacts.size() > 0:
		var impacts_label = Label.new()
		impacts_label.text = "Active: " + ", ".join(impacts)
		impacts_label.add_theme_font_size_override("font_size", 10)
		impacts_label.add_theme_color_override("font_color", COLOR_WARNING)
		impacts_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		content_container.add_child(impacts_label)


func _build_environment_tab() -> void:
	var weather_system = _get_weather_system()

	# Current Weather Header
	content_container.add_child(_create_section_header("Current Weather"))

	var current_row = HBoxContainer.new()
	current_row.add_theme_constant_override("separation", 16)
	content_container.add_child(current_row)

	# Today's weather card
	var today_card = _create_weather_card("Now", weather_system)
	current_row.add_child(today_card)

	# Year and system info
	var info_column = VBoxContainer.new()
	info_column.add_theme_constant_override("separation", 3)
	current_row.add_child(info_column)

	var biome_name = "Default"
	var year_summary = "Normal conditions"
	if weather_system:
		if weather_system.has_method("get_biome"):
			var biome = weather_system.get_biome()
			if biome and biome.get("display_name"):
				biome_name = biome.display_name
		if weather_system.has_method("get_year_summary"):
			year_summary = weather_system.get_year_summary()

	var biome_label = Label.new()
	biome_label.text = "Biome: %s" % biome_name
	biome_label.add_theme_font_size_override("font_size", 11)
	biome_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	info_column.add_child(biome_label)

	var year_label = Label.new()
	year_label.text = year_summary
	year_label.add_theme_font_size_override("font_size", 10)
	year_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	year_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	year_label.custom_minimum_size.x = 160
	info_column.add_child(year_label)

	# Front warning if approaching
	if weather_system and weather_system.get("days_until_front") != null:
		var days_to_front = weather_system.days_until_front
		var front_type = weather_system.next_front_type if weather_system.get("next_front_type") else "none"
		if days_to_front >= 0 and days_to_front <= 3 and front_type != "none":
			var front_warning = Label.new()
			if days_to_front == 0:
				front_warning.text = "%s front passing today" % front_type.capitalize()
			else:
				front_warning.text = "%s front in %d day%s" % [front_type.capitalize(), days_to_front, "s" if days_to_front > 1 else ""]
			front_warning.add_theme_font_size_override("font_size", 10)
			front_warning.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8))
			info_column.add_child(front_warning)

	# Active weather alerts
	if weather_system:
		if weather_system.get("heat_wave_active") and weather_system.heat_wave_active:
			var alert = Label.new()
			alert.text = "⚠ HEAT WAVE ACTIVE"
			alert.add_theme_font_size_override("font_size", 10)
			alert.add_theme_color_override("font_color", COLOR_WARNING)
			info_column.add_child(alert)
		if weather_system.get("cold_snap_active") and weather_system.cold_snap_active:
			var alert = Label.new()
			alert.text = "⚠ COLD SNAP ACTIVE"
			alert.add_theme_font_size_override("font_size", 10)
			alert.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
			info_column.add_child(alert)
		if weather_system.get("flood_active") and weather_system.flood_active:
			var alert = Label.new()
			alert.text = "⚠ FLOOD WARNING"
			alert.add_theme_font_size_override("font_size", 10)
			alert.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
			info_column.add_child(alert)
		if weather_system.get("drought_active") and weather_system.drought_active:
			var drought_info = weather_system.get_drought_info() if weather_system.has_method("get_drought_info") else {}
			var severity_pct = drought_info.get("severity_pct", 0)
			var water_reduction = drought_info.get("water_reduction", 0)
			var alert = Label.new()
			alert.text = "⚠ DROUGHT (%d%% severity, -%d%% water)" % [severity_pct, water_reduction]
			alert.add_theme_font_size_override("font_size", 10)
			alert.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3))
			info_column.add_child(alert)

	# Check for wildfire in pollution system
	var pollution_system = _get_pollution_system()
	if pollution_system and pollution_system.get("wildfire_active") and pollution_system.wildfire_active:
		var wildfire_info = pollution_system.get_wildfire_info() if pollution_system.has_method("get_wildfire_info") else {}
		var intensity_pct = wildfire_info.get("intensity_pct", 0)
		var alert = Label.new()
		alert.text = "🔥 WILDFIRE (%d%% intensity) - Smoke affecting air quality" % intensity_pct
		alert.add_theme_font_size_override("font_size", 10)
		alert.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
		info_column.add_child(alert)

	# Climate change info
	if weather_system and weather_system.has_method("get_climate_warming"):
		var warming = weather_system.get_climate_warming()
		if warming > 0.1:
			var climate_label = Label.new()
			climate_label.text = "Climate shift: +%.1f C" % warming
			climate_label.add_theme_font_size_override("font_size", 10)
			climate_label.add_theme_color_override("font_color", COLOR_WARNING)
			info_column.add_child(climate_label)

	# Air Quality Section
	_build_air_quality_section()

	# 10-Day Forecast
	content_container.add_child(_create_section_header("10-Day Forecast"))

	# Scrollable forecast container
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 100)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_container.add_child(scroll)

	var forecast_row = HBoxContainer.new()
	forecast_row.add_theme_constant_override("separation", 8)
	scroll.add_child(forecast_row)

	# Add forecast days
	if weather_system and weather_system.has_method("get_forecast"):
		var forecast_data = weather_system.get_forecast()
		for i in range(mini(10, forecast_data.size())):
			var day = forecast_data[i]
			var day_card = _create_forecast_day_card(day, i)
			forecast_row.add_child(day_card)
	else:
		var no_data = Label.new()
		no_data.text = "Forecast unavailable"
		no_data.add_theme_color_override("font_color", COLOR_NEUTRAL)
		forecast_row.add_child(no_data)

	# Climate impacts section
	content_container.add_child(_create_section_header("Climate Impacts on Infrastructure"))

	var impacts_grid = GridContainer.new()
	impacts_grid.columns = 3
	impacts_grid.add_theme_constant_override("h_separation", 16)
	impacts_grid.add_theme_constant_override("v_separation", 6)
	content_container.add_child(impacts_grid)

	var solar_mult = 1.0
	var wind_mult = 1.0
	var water_supply_mult = 1.0
	var water_demand_mult = 1.0
	var construction_mult = 1.0
	var heating = 1.0
	var cooling = 1.0
	var humidity = 0.5
	var pressure = 1013.0

	if weather_system:
		if weather_system.has_method("get_solar_multiplier"):
			solar_mult = weather_system.get_solar_multiplier()
		if weather_system.has_method("get_wind_multiplier"):
			wind_mult = weather_system.get_wind_multiplier()
		if weather_system.has_method("get_water_multiplier"):
			water_supply_mult = weather_system.get_water_multiplier()
		if weather_system.has_method("get_water_demand_multiplier"):
			water_demand_mult = weather_system.get_water_demand_multiplier()
		if weather_system.has_method("get_construction_cost_multiplier"):
			construction_mult = weather_system.get_construction_cost_multiplier()
		if weather_system.has_method("get_heating_modifier"):
			heating = weather_system.get_heating_modifier()
		if weather_system.has_method("get_cooling_modifier"):
			cooling = weather_system.get_cooling_modifier()
		if weather_system.has_method("get_humidity"):
			humidity = weather_system.get_humidity()
		if weather_system.has_method("get_pressure"):
			pressure = weather_system.get_pressure()

	# Power generation
	_add_impact_pill(impacts_grid, "Solar Power", solar_mult, true)
	_add_impact_pill(impacts_grid, "Wind Power", wind_mult, true)

	# Water
	_add_impact_pill(impacts_grid, "Water Supply", water_supply_mult, true)
	if water_demand_mult > 1.05 or water_demand_mult < 0.95:
		_add_impact_pill(impacts_grid, "Water Demand", water_demand_mult, false)

	# Costs
	_add_impact_pill(impacts_grid, "Construction", construction_mult, false)

	# Climate control costs
	if heating > 1.05:
		_add_impact_pill(impacts_grid, "Heating", heating, false)
	if cooling > 1.05:
		_add_impact_pill(impacts_grid, "Cooling", cooling, false)

	# Weather impact notes
	var notes_container = VBoxContainer.new()
	notes_container.add_theme_constant_override("separation", 2)
	content_container.add_child(notes_container)

	if humidity > 0.7:
		var humid_label = Label.new()
		humid_label.text = "• High humidity increasing cooling load"
		humid_label.add_theme_font_size_override("font_size", 10)
		humid_label.add_theme_color_override("font_color", COLOR_WARNING)
		notes_container.add_child(humid_label)

	if humidity < 0.3:
		var dry_label = Label.new()
		dry_label.text = "• Low humidity increasing water evaporation"
		dry_label.add_theme_font_size_override("font_size", 10)
		dry_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
		notes_container.add_child(dry_label)

	if water_demand_mult > 1.15:
		var water_label = Label.new()
		water_label.text = "• Hot weather increasing water demand by %d%%" % int((water_demand_mult - 1.0) * 100)
		water_label.add_theme_font_size_override("font_size", 10)
		water_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.85))
		notes_container.add_child(water_label)

	if pressure < 1000:
		var pressure_label = Label.new()
		pressure_label.text = "• Low pressure system - expect unsettled weather"
		pressure_label.add_theme_font_size_override("font_size", 10)
		pressure_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		notes_container.add_child(pressure_label)

	if pressure > 1030:
		var hp_label = Label.new()
		hp_label.text = "• High pressure - stable, clear conditions"
		hp_label.add_theme_font_size_override("font_size", 10)
		hp_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
		notes_container.add_child(hp_label)


func _create_weather_card(title: String, weather_system: Node) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 140)

	var style = UIManager.get_panel_style(ThemeConstants.RADIUS_MEDIUM)
	style.bg_color = UIManager.COLORS.panel_bg.lightened(0.05)
	style.bg_color.a = 0.8
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	vbox.add_child(title_label)

	var temp = "20 C"
	var apparent_temp = "20 C"
	var conditions = "Clear"
	var cloud_pct = 20
	var wind_speed = 10.0
	var wind_desc = "Light"
	var wind_dir = "SW"
	var pressure = 1013.0
	var pressure_trend = "steady"
	var humidity = 50
	var dew_point = 10.0

	if weather_system:
		if weather_system.has_method("get_temperature_string"):
			temp = weather_system.get_temperature_string()
		if weather_system.has_method("get_apparent_temperature_string"):
			apparent_temp = weather_system.get_apparent_temperature_string()
		if weather_system.has_method("get_conditions"):
			conditions = weather_system.get_conditions()
		if weather_system.has_method("get_cloud_cover"):
			cloud_pct = int(weather_system.get_cloud_cover() * 100)
		if weather_system.has_method("get_wind_speed"):
			wind_speed = weather_system.get_wind_speed()
		if weather_system.has_method("get_wind_description"):
			wind_desc = weather_system.get_wind_description()
		if weather_system.has_method("get_wind_cardinal"):
			wind_dir = weather_system.get_wind_cardinal()
		if weather_system.has_method("get_pressure"):
			pressure = weather_system.get_pressure()
		if weather_system.has_method("get_pressure_trend"):
			pressure_trend = weather_system.get_pressure_trend()
		if weather_system.has_method("get_humidity"):
			humidity = int(weather_system.get_humidity() * 100)
		if weather_system.has_method("get_dew_point"):
			dew_point = weather_system.get_dew_point()

	# Temperature row with feels-like
	var temp_row = HBoxContainer.new()
	temp_row.add_theme_constant_override("separation", 6)
	vbox.add_child(temp_row)

	var temp_label = Label.new()
	temp_label.text = temp
	temp_label.add_theme_font_size_override("font_size", 18)
	temp_row.add_child(temp_label)

	if temp != apparent_temp:
		var feels_label = Label.new()
		feels_label.text = "(feels %s)" % apparent_temp
		feels_label.add_theme_font_size_override("font_size", 10)
		feels_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
		temp_row.add_child(feels_label)

	# Conditions
	var cond_label = Label.new()
	cond_label.text = conditions
	cond_label.add_theme_font_size_override("font_size", 12)
	cond_label.add_theme_color_override("font_color", _get_conditions_color(conditions))
	vbox.add_child(cond_label)

	# Pressure row with trend arrow
	var pressure_row = HBoxContainer.new()
	pressure_row.add_theme_constant_override("separation", 4)
	var pressure_icon = Label.new()
	pressure_icon.text = "P:"
	pressure_icon.add_theme_font_size_override("font_size", 10)
	pressure_icon.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
	pressure_row.add_child(pressure_icon)
	var pressure_text = Label.new()
	var trend_arrow = ""
	match pressure_trend:
		"rising": trend_arrow = " ^"
		"falling": trend_arrow = " v"
		_: trend_arrow = " -"
	pressure_text.text = "%.0f mb%s" % [pressure, trend_arrow]
	pressure_text.add_theme_font_size_override("font_size", 10)
	# Color based on pressure (low = stormy)
	if pressure < 1000:
		pressure_text.add_theme_color_override("font_color", COLOR_WARNING)
	elif pressure > 1025:
		pressure_text.add_theme_color_override("font_color", COLOR_GOOD)
	else:
		pressure_text.add_theme_color_override("font_color", COLOR_NEUTRAL)
	pressure_row.add_child(pressure_text)
	vbox.add_child(pressure_row)

	# Humidity row
	var humidity_row = HBoxContainer.new()
	humidity_row.add_theme_constant_override("separation", 4)
	var humidity_icon = Label.new()
	humidity_icon.text = "H:"
	humidity_icon.add_theme_font_size_override("font_size", 10)
	humidity_icon.add_theme_color_override("font_color", Color(0.4, 0.6, 0.8))
	humidity_row.add_child(humidity_icon)
	var humidity_text = Label.new()
	humidity_text.text = "%d%% (dp %.0f C)" % [humidity, dew_point]
	humidity_text.add_theme_font_size_override("font_size", 10)
	humidity_text.add_theme_color_override("font_color", COLOR_NEUTRAL)
	humidity_text.tooltip_text = "Relative humidity and dew point"
	humidity_row.add_child(humidity_text)
	vbox.add_child(humidity_row)

	# Cloud coverage row
	var cloud_row = HBoxContainer.new()
	cloud_row.add_theme_constant_override("separation", 4)
	var cloud_icon = Label.new()
	cloud_icon.text = "="
	cloud_icon.add_theme_font_size_override("font_size", 10)
	cloud_icon.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	cloud_row.add_child(cloud_icon)
	var cloud_text = Label.new()
	cloud_text.text = "%d%% clouds" % cloud_pct
	cloud_text.add_theme_font_size_override("font_size", 10)
	cloud_text.add_theme_color_override("font_color", COLOR_NEUTRAL)
	cloud_row.add_child(cloud_text)
	vbox.add_child(cloud_row)

	# Wind row with direction
	var wind_row = HBoxContainer.new()
	wind_row.add_theme_constant_override("separation", 4)
	var wind_icon = Label.new()
	wind_icon.text = "~"
	wind_icon.add_theme_font_size_override("font_size", 10)
	wind_icon.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
	wind_row.add_child(wind_icon)
	var wind_text = Label.new()
	wind_text.text = "%s %.0f km/h %s" % [wind_desc, wind_speed, wind_dir]
	wind_text.add_theme_font_size_override("font_size", 10)
	if wind_speed >= 50:
		wind_text.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		wind_text.add_theme_color_override("font_color", COLOR_NEUTRAL)
	wind_row.add_child(wind_text)
	vbox.add_child(wind_row)

	return card


func _create_forecast_day_card(day, day_index: int) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(65, 115)

	var style = UIManager.get_panel_style(ThemeConstants.RADIUS_SMALL)
	style.set_content_margin_all(ThemeConstants.MARGIN_SMALL)
	if day_index == 0:
		style.bg_color = UIManager.COLORS.panel_bg.lightened(0.1)
		style.bg_color.a = 0.9
	else:
		style.bg_color = UIManager.COLORS.panel_bg
		style.bg_color.a = 0.7

	# Border for severe weather or fronts
	if day.is_severe:
		style.border_color = ThemeConstants.STATUS_WARNING
		style.border_width_bottom = 2
	elif "front_passage" in day and day.front_passage:
		style.border_color = Color(0.4, 0.5, 0.7)
		style.border_width_bottom = 2

	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Day name
	var day_names = ["Today", "Tom", "D3", "D4", "D5", "D6", "D7", "D8", "D9", "D10"]
	var day_label = Label.new()
	day_label.text = day_names[mini(day_index, 9)]
	day_label.add_theme_font_size_override("font_size", 9)
	day_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(day_label)

	# Weather icon/symbol
	var icon_label = Label.new()
	icon_label.text = _get_weather_symbol(day.conditions)
	icon_label.add_theme_font_size_override("font_size", 14)
	icon_label.add_theme_color_override("font_color", _get_conditions_color(day.conditions))
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_label)

	# High/Low temps with uncertainty
	var temp_row = HBoxContainer.new()
	temp_row.alignment = BoxContainer.ALIGNMENT_CENTER
	temp_row.add_theme_constant_override("separation", 1)
	vbox.add_child(temp_row)

	var high_label = Label.new()
	high_label.text = "%.0f" % day.high_temp
	high_label.add_theme_font_size_override("font_size", 11)
	high_label.add_theme_color_override("font_color", _get_temp_color(day.high_temp))
	temp_row.add_child(high_label)

	var sep = Label.new()
	sep.text = "/"
	sep.add_theme_font_size_override("font_size", 9)
	sep.add_theme_color_override("font_color", Color(0.4, 0.42, 0.45))
	temp_row.add_child(sep)

	var low_label = Label.new()
	low_label.text = "%.0f" % day.low_temp
	low_label.add_theme_font_size_override("font_size", 9)
	low_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	temp_row.add_child(low_label)

	# Show uncertainty for distant forecasts
	var uncertainty = 1.0
	if "temp_uncertainty" in day:
		uncertainty = day.temp_uncertainty
	if uncertainty > 2.0:
		var uncert_label = Label.new()
		uncert_label.text = "±%.0f" % uncertainty
		uncert_label.add_theme_font_size_override("font_size", 7)
		uncert_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		uncert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(uncert_label)

	# Pressure trend indicator
	var pressure_trend = "steady"
	if "pressure_trend" in day:
		pressure_trend = day.pressure_trend
	var trend_row = HBoxContainer.new()
	trend_row.alignment = BoxContainer.ALIGNMENT_CENTER
	trend_row.add_theme_constant_override("separation", 2)
	vbox.add_child(trend_row)

	var trend_icon = Label.new()
	match pressure_trend:
		"rising": trend_icon.text = "^"
		"falling": trend_icon.text = "v"
		_: trend_icon.text = "-"
	trend_icon.add_theme_font_size_override("font_size", 8)
	if pressure_trend == "falling":
		trend_icon.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4))
	elif pressure_trend == "rising":
		trend_icon.add_theme_color_override("font_color", Color(0.4, 0.6, 0.5))
	else:
		trend_icon.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	trend_icon.tooltip_text = "Pressure %s" % pressure_trend
	trend_row.add_child(trend_icon)

	# Wind speed
	var wind_spd = 10.0
	if "wind_speed" in day:
		wind_spd = day.wind_speed

	var wind_label = Label.new()
	wind_label.text = "~%.0f" % wind_spd
	wind_label.add_theme_font_size_override("font_size", 8)
	if wind_spd >= 50:
		wind_label.add_theme_color_override("font_color", COLOR_WARNING)
	elif wind_spd >= 25:
		wind_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
	else:
		wind_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6))
	wind_label.tooltip_text = "Wind: %.0f km/h" % wind_spd
	trend_row.add_child(wind_label)

	# Front indicator or precip chance
	var has_front = "front_passage" in day and day.front_passage
	var front_type = day.front_type if "front_type" in day else "none"

	if has_front:
		var front_label = Label.new()
		match front_type:
			"cold": front_label.text = "COLD"
			"warm": front_label.text = "WARM"
			"occluded": front_label.text = "OCCL"
			"stationary": front_label.text = "STAT"
			_: front_label.text = "FRNT"
		front_label.add_theme_font_size_override("font_size", 7)
		front_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8))
		front_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		front_label.tooltip_text = "%s front passage" % front_type.capitalize()
		vbox.add_child(front_label)
	elif day.precipitation_chance > 0.2:
		var precip_label = Label.new()
		precip_label.text = "%d%%" % int(day.precipitation_chance * 100)
		precip_label.add_theme_font_size_override("font_size", 8)
		precip_label.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
		precip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		precip_label.tooltip_text = "Precipitation chance"
		vbox.add_child(precip_label)

	# Storm phase indicator
	var storm_phase = day.storm_phase if "storm_phase" in day else "none"
	if storm_phase != "none":
		var storm_label = Label.new()
		match storm_phase:
			"developing": storm_label.text = "[DEV]"
			"mature": storm_label.text = "[!!!]"
			"dissipating": storm_label.text = "[dis]"
		storm_label.add_theme_font_size_override("font_size", 7)
		storm_label.add_theme_color_override("font_color", COLOR_WARNING)
		storm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(storm_label)

	# Build detailed tooltip
	var cloud_pct = int(day.cloud_cover * 100) if "cloud_cover" in day else 30
	var humidity = int(day.humidity * 100) if "humidity" in day else 50
	var pressure = day.pressure if "pressure" in day else 1013.0
	var dew_point = day.dew_point if "dew_point" in day else 10.0

	var tooltip = "%s\n" % day.conditions
	tooltip += "High: %.0f C / Low: %.0f C" % [day.high_temp, day.low_temp]
	if uncertainty > 2.0:
		tooltip += " (±%.0f)" % uncertainty
	tooltip += "\nPressure: %.0f mb (%s)" % [pressure, pressure_trend]
	tooltip += "\nHumidity: %d%% | Dew point: %.0f C" % [humidity, dew_point]
	tooltip += "\nCloud cover: %d%%" % cloud_pct
	tooltip += "\nWind: %.0f km/h" % wind_spd

	if day.precipitation_chance > 0.05:
		var precip_type = day.precipitation_type if "precipitation_type" in day else "rain"
		tooltip += "\nPrecipitation: %d%% chance of %s" % [int(day.precipitation_chance * 100), precip_type]

	if has_front:
		var timing = day.front_timing if "front_timing" in day else ""
		tooltip += "\n%s front passage" % front_type.capitalize()
		if timing:
			tooltip += " (%s)" % timing

	if storm_phase != "none":
		tooltip += "\nStorm: %s phase" % storm_phase

	if day.is_severe:
		tooltip += "\n⚠ SEVERE WEATHER WARNING"

	card.tooltip_text = tooltip

	return card


func _get_weather_symbol(conditions: String) -> String:
	match conditions:
		"Clear": return "*"
		"Partly Cloudy": return "*="
		"Mostly Cloudy": return "=*"
		"Hot": return "**"
		"Cold": return "+"
		"Cloudy": return "="
		"Overcast": return "=="
		"Rain": return "~"
		"Heavy Rain": return "~~"
		"Sleet": return "+~"
		"Ice": return "+="
		"Snow": return "++"
		"Storm": return "!!"
		"Blizzard": return "+!!"
		_: return "*"


func _get_conditions_color(conditions: String) -> Color:
	match conditions:
		"Clear": return Color(0.9, 0.85, 0.4)
		"Partly Cloudy": return Color(0.8, 0.8, 0.55)
		"Mostly Cloudy": return Color(0.65, 0.68, 0.72)
		"Hot": return Color(0.95, 0.5, 0.3)
		"Cold": return Color(0.5, 0.7, 0.9)
		"Cloudy", "Overcast": return Color(0.6, 0.65, 0.7)
		"Rain": return Color(0.4, 0.6, 0.85)
		"Heavy Rain": return Color(0.35, 0.5, 0.8)
		"Sleet": return Color(0.5, 0.65, 0.8)
		"Ice": return Color(0.6, 0.75, 0.9)
		"Snow": return Color(0.85, 0.9, 0.95)
		"Storm", "Blizzard": return COLOR_WARNING
		_: return Color(0.7, 0.75, 0.8)


func _get_temp_color(temp: float) -> Color:
	if temp > 35:
		return Color(0.95, 0.4, 0.3)  # Hot red
	elif temp > 25:
		return Color(0.9, 0.7, 0.3)  # Warm orange
	elif temp > 15:
		return Color(0.8, 0.85, 0.8)  # Mild
	elif temp > 5:
		return Color(0.6, 0.75, 0.85)  # Cool blue
	elif temp > -5:
		return Color(0.5, 0.7, 0.9)  # Cold
	else:
		return Color(0.7, 0.8, 0.95)  # Freezing


func _add_impact_pill(container: GridContainer, label_text: String, value: float, higher_is_better: bool) -> void:
	var pill = HBoxContainer.new()
	pill.add_theme_constant_override("separation", 4)

	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	pill.add_child(label)

	var value_label = Label.new()
	value_label.text = "%d%%" % int(value * 100)
	value_label.add_theme_font_size_override("font_size", 11)

	# Color based on good/bad
	var is_good = (higher_is_better and value >= 1.0) or (not higher_is_better and value <= 1.0)
	if abs(value - 1.0) < 0.05:
		value_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	elif is_good:
		value_label.add_theme_color_override("font_color", COLOR_GOOD)
	else:
		value_label.add_theme_color_override("font_color", COLOR_WARNING)

	pill.add_child(value_label)
	container.add_child(pill)


func _get_weather_system() -> Node:
	var game_world = get_tree().get_first_node_in_group("game_world")
	if game_world and game_world.has_node("WeatherSystem"):
		return game_world.get_node("WeatherSystem")
	return null


func _get_water_system() -> Node:
	var game_world = get_tree().get_first_node_in_group("game_world")
	if game_world and game_world.has_node("WaterSystem"):
		return game_world.get_node("WaterSystem")
	return null


func _get_pollution_system() -> Node:
	var game_world = get_tree().get_first_node_in_group("game_world")
	if game_world and game_world.has_node("PollutionSystem"):
		return game_world.get_node("PollutionSystem")
	return null


func _get_power_system() -> Node:
	var game_world = get_tree().get_first_node_in_group("game_world")
	if game_world and game_world.has_node("PowerSystem"):
		return game_world.get_node("PowerSystem")
	return null


func _build_air_quality_section() -> void:
	var pollution_system = _get_pollution_system()
	var weather_system = _get_weather_system()

	content_container.add_child(_create_section_header("Air Quality"))

	var aq_container = HBoxContainer.new()
	aq_container.add_theme_constant_override("separation", 16)
	content_container.add_child(aq_container)

	# AQI Card
	var aqi_card = PanelContainer.new()
	aqi_card.custom_minimum_size = Vector2(140, 90)

	var aqi_style = UIManager.get_panel_style(ThemeConstants.RADIUS_MEDIUM)
	aqi_style.bg_color = UIManager.COLORS.panel_bg.lightened(0.05)
	aqi_style.bg_color.a = 0.8
	aqi_card.add_theme_stylebox_override("panel", aqi_style)

	var aqi_vbox = VBoxContainer.new()
	aqi_vbox.add_theme_constant_override("separation", 2)
	aqi_card.add_child(aqi_vbox)

	var aqi_title = Label.new()
	aqi_title.text = "Air Quality Index"
	aqi_title.add_theme_font_size_override("font_size", 10)
	aqi_title.add_theme_color_override("font_color", COLOR_NEUTRAL)
	aqi_vbox.add_child(aqi_title)

	var aqi_value = 0.0
	var aqi_category = "Good"
	var aqi_color = COLOR_GOOD
	var is_smog = false
	var is_inversion = false
	var inversion_strength = 0.0
	var wind_dispersion = 0.5
	var is_wildfire = false
	var wildfire_intensity = 0.0
	var wildfire_smoke = 0.0

	if pollution_system:
		if pollution_system.has_method("get_air_quality_index"):
			aqi_value = pollution_system.get_air_quality_index()
		if pollution_system.has_method("get_air_quality_category"):
			aqi_category = pollution_system.get_air_quality_category()
		if pollution_system.has_method("get_air_quality_color"):
			aqi_color = pollution_system.get_air_quality_color()
		if pollution_system.has_method("is_smog_alert"):
			is_smog = pollution_system.is_smog_alert()
		if pollution_system.has_method("is_inversion_active"):
			is_inversion = pollution_system.is_inversion_active()
		if pollution_system.has_method("get_inversion_strength"):
			inversion_strength = pollution_system.get_inversion_strength()
		if pollution_system.has_method("get_wind_dispersion"):
			wind_dispersion = pollution_system.get_wind_dispersion()
		if pollution_system.has_method("is_wildfire_active"):
			is_wildfire = pollution_system.is_wildfire_active()
		if pollution_system.has_method("get_wildfire_intensity"):
			wildfire_intensity = pollution_system.get_wildfire_intensity()
		if pollution_system.has_method("get_wildfire_smoke_contribution"):
			wildfire_smoke = pollution_system.get_wildfire_smoke_contribution()

	var aqi_number = Label.new()
	aqi_number.text = "%d" % int(aqi_value)
	aqi_number.add_theme_font_size_override("font_size", 24)
	aqi_number.add_theme_color_override("font_color", aqi_color)
	aqi_vbox.add_child(aqi_number)

	var aqi_cat_label = Label.new()
	aqi_cat_label.text = aqi_category
	aqi_cat_label.add_theme_font_size_override("font_size", 10)
	aqi_cat_label.add_theme_color_override("font_color", aqi_color)
	aqi_vbox.add_child(aqi_cat_label)

	# Smog alert indicator
	if is_smog:
		var smog_label = Label.new()
		smog_label.text = "⚠ SMOG ALERT"
		smog_label.add_theme_font_size_override("font_size", 9)
		smog_label.add_theme_color_override("font_color", COLOR_WARNING)
		aqi_vbox.add_child(smog_label)

	# Wildfire alert indicator
	if is_wildfire:
		var fire_label = Label.new()
		fire_label.text = "🔥 WILDFIRE SMOKE"
		fire_label.add_theme_font_size_override("font_size", 9)
		fire_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
		aqi_vbox.add_child(fire_label)

	aqi_card.tooltip_text = _get_aqi_tooltip(aqi_value, aqi_category, is_wildfire, wildfire_smoke)
	aq_container.add_child(aqi_card)

	# Weather conditions affecting air quality
	var conditions_vbox = VBoxContainer.new()
	conditions_vbox.add_theme_constant_override("separation", 3)
	aq_container.add_child(conditions_vbox)

	# Wind dispersion
	var wind_row = HBoxContainer.new()
	wind_row.add_theme_constant_override("separation", 6)
	conditions_vbox.add_child(wind_row)

	var wind_label = Label.new()
	wind_label.text = "Wind Dispersion:"
	wind_label.add_theme_font_size_override("font_size", 10)
	wind_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	wind_row.add_child(wind_label)

	var wind_value = Label.new()
	var dispersion_desc = "Low" if wind_dispersion < 0.15 else ("Moderate" if wind_dispersion < 0.35 else "Good")
	wind_value.text = "%s (%d%%)" % [dispersion_desc, int(wind_dispersion * 100)]
	wind_value.add_theme_font_size_override("font_size", 10)
	if wind_dispersion < 0.15:
		wind_value.add_theme_color_override("font_color", COLOR_WARNING)
	elif wind_dispersion > 0.35:
		wind_value.add_theme_color_override("font_color", COLOR_GOOD)
	else:
		wind_value.add_theme_color_override("font_color", COLOR_NEUTRAL)
	wind_row.add_child(wind_value)

	# Temperature inversion status
	var inversion_row = HBoxContainer.new()
	inversion_row.add_theme_constant_override("separation", 6)
	conditions_vbox.add_child(inversion_row)

	var inversion_label = Label.new()
	inversion_label.text = "Temperature Inversion:"
	inversion_label.add_theme_font_size_override("font_size", 10)
	inversion_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	inversion_row.add_child(inversion_label)

	var inversion_value = Label.new()
	if is_inversion:
		inversion_value.text = "Active (%d%%)" % int(inversion_strength * 100)
		inversion_value.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		inversion_value.text = "None"
		inversion_value.add_theme_color_override("font_color", COLOR_GOOD)
	inversion_value.add_theme_font_size_override("font_size", 10)
	inversion_row.add_child(inversion_value)

	# Precipitation effect
	var precip_row = HBoxContainer.new()
	precip_row.add_theme_constant_override("separation", 6)
	conditions_vbox.add_child(precip_row)

	var precip_label = Label.new()
	precip_label.text = "Precipitation Effect:"
	precip_label.add_theme_font_size_override("font_size", 10)
	precip_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	precip_row.add_child(precip_label)

	var precip_value = Label.new()
	var is_raining = false
	if weather_system and weather_system.has_method("get_conditions"):
		var conditions = weather_system.get_conditions()
		is_raining = conditions in ["Rain", "Heavy Rain", "Storm", "Snow"]

	if is_raining:
		precip_value.text = "Clearing pollutants"
		precip_value.add_theme_color_override("font_color", COLOR_GOOD)
	else:
		precip_value.text = "None"
		precip_value.add_theme_color_override("font_color", COLOR_NEUTRAL)
	precip_value.add_theme_font_size_override("font_size", 10)
	precip_row.add_child(precip_value)

	# Wildfire status
	if is_wildfire:
		var wildfire_row = HBoxContainer.new()
		wildfire_row.add_theme_constant_override("separation", 6)
		conditions_vbox.add_child(wildfire_row)

		var wildfire_label = Label.new()
		wildfire_label.text = "Wildfire Status:"
		wildfire_label.add_theme_font_size_override("font_size", 10)
		wildfire_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
		wildfire_row.add_child(wildfire_label)

		var wildfire_value = Label.new()
		wildfire_value.text = "Active (%d%% intensity, +%d AQI)" % [int(wildfire_intensity * 100), int(wildfire_smoke)]
		wildfire_value.add_theme_font_size_override("font_size", 10)
		wildfire_value.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
		wildfire_row.add_child(wildfire_value)

		var fire_explain = Label.new()
		fire_explain.text = "• Regional wildfire smoke degrading air quality"
		fire_explain.add_theme_font_size_override("font_size", 9)
		fire_explain.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
		fire_explain.autowrap_mode = TextServer.AUTOWRAP_WORD
		conditions_vbox.add_child(fire_explain)

	# Inversion explanation
	if is_inversion:
		var explain_label = Label.new()
		explain_label.text = "• Inversion layer trapping pollution near ground level"
		explain_label.add_theme_font_size_override("font_size", 9)
		explain_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5))
		explain_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		conditions_vbox.add_child(explain_label)


func _get_aqi_tooltip(aqi: float, category: String, has_wildfire: bool = false, smoke_contribution: float = 0.0) -> String:
	var tooltip = "Air Quality Index: %d\nCategory: %s\n\n" % [int(aqi), category]

	if has_wildfire:
		tooltip += "⚠ WILDFIRE SMOKE\n"
		tooltip += "Smoke contribution: +%d AQI\n\n" % int(smoke_contribution)

	tooltip += "AQI Scale:\n"
	tooltip += "0-50: Good - Air quality is satisfactory\n"
	tooltip += "51-100: Moderate - Acceptable for most\n"
	tooltip += "101-150: Unhealthy for Sensitive Groups\n"
	tooltip += "151-200: Unhealthy - Everyone may be affected\n"
	tooltip += "201-300: Very Unhealthy - Health alert\n"
	tooltip += "301-500: Hazardous - Emergency conditions\n\n"

	tooltip += "Weather Effects:\n"
	tooltip += "• Wind disperses pollution\n"
	tooltip += "• Rain washes pollutants from air\n"
	tooltip += "• Temperature inversions trap pollution\n"
	tooltip += "• Summer wildfires produce heavy smoke"

	return tooltip


func _calculate_tree_coverage() -> float:
	var game_world = get_tree().get_first_node_in_group("game_world")
	if not game_world or not game_world.has_node("TerrainSystem"):
		return 0.0

	var terrain = game_world.get_node("TerrainSystem")
	if not terrain.has_method("get_feature"):
		return 0.0

	var tree_count = 0
	var total_cells = 128 * 128  # Grid size

	# Sample terrain for trees (checking every cell would be slow)
	for x in range(0, 128, 2):
		for y in range(0, 128, 2):
			var feature = terrain.get_feature(Vector2i(x, y))
			if feature in [1, 2]:  # TREE_SPARSE, TREE_DENSE
				tree_count += 4  # Estimate for sampled area

	return float(tree_count) / float(total_cells)


func _calculate_water_features() -> int:
	var game_world = get_tree().get_first_node_in_group("game_world")
	if not game_world or not game_world.has_node("TerrainSystem"):
		return 0

	var terrain = game_world.get_node("TerrainSystem")
	if not terrain.has_method("get_water"):
		return 0

	var water_count = 0

	# Sample terrain for water
	for x in range(0, 128, 2):
		for y in range(0, 128, 2):
			var water = terrain.get_water(Vector2i(x, y))
			if water != 0:  # Not NONE
				water_count += 4

	return water_count


func _get_air_quality() -> String:
	var pollution = _get_pollution_system()
	if not pollution:
		return "Unknown"

	# Use the new AQI-based category if available
	if pollution.has_method("get_air_quality_category"):
		return pollution.get_air_quality_category()

	# Fallback to old method
	if not pollution.has_method("get_average_pollution"):
		return "Unknown"

	var avg = pollution.get_average_pollution()

	if avg < 0.1:
		return "Excellent"
	elif avg < 0.25:
		return "Good"
	elif avg < 0.5:
		return "Moderate"
	elif avg < 0.75:
		return "Poor"
	else:
		return "Hazardous"


func _build_districts_tab() -> void:
	content_container.add_child(_create_section_header("Neighborhood Districts"))

	var info_label = Label.new()
	info_label.text = "Create and manage distinct neighborhood districts with custom policies."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	content_container.add_child(info_label)

	var create_btn = Button.new()
	create_btn.text = "+ Create District"
	create_btn.custom_minimum_size = Vector2(150, 36)
	content_container.add_child(create_btn)


# Helper functions

func _create_stat_card(title: String, value: String, subtitle: String, accent_color: Color) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 80)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 11)
	title_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	vbox.add_child(title_label)

	var value_label = Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(value_label)

	var subtitle_label = Label.new()
	subtitle_label.text = subtitle
	subtitle_label.add_theme_font_size_override("font_size", 11)
	subtitle_label.add_theme_color_override("font_color", accent_color)
	vbox.add_child(subtitle_label)

	return card


func _create_section_header(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	return label


func _create_alert_item(message: String, type: String) -> PanelContainer:
	var alert_panel = PanelContainer.new()

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	alert_panel.add_child(hbox)

	var icon = Label.new()
	match type:
		"critical": icon.text = "!!!"
		"warning": icon.text = "!"
		_: icon.text = "i"
	icon.add_theme_color_override("font_color", COLOR_CRITICAL if type == "critical" else (COLOR_WARNING if type == "warning" else COLOR_NEUTRAL))
	hbox.add_child(icon)

	var msg = Label.new()
	msg.text = message
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(msg)

	return alert_panel


func _create_action_button(text: String, panel_name: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(100, 32)
	btn.pressed.connect(func(): panel_requested.emit(panel_name))
	return btn


func _add_stat_row(parent: Control, label_text: String, value_text: String) -> void:
	var label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	parent.add_child(label)

	var value = Label.new()
	value.text = value_text
	parent.add_child(value)

	# Spacer for 3-column grid
	if parent is GridContainer and parent.columns == 3:
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(50, 0)
		parent.add_child(spacer)


func _add_stat_row_colored(parent: Control, label_text: String, value_text: String, value_color: Color) -> void:
	var label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	parent.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", value_color)
	parent.add_child(value)

	# Spacer for 3-column grid
	if parent is GridContainer and parent.columns == 3:
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(50, 0)
		parent.add_child(spacer)


func _add_utility_row(parent: Control, utility_name: String, supply: float, demand: float, unit: String) -> void:
	var label = Label.new()
	label.text = utility_name
	parent.add_child(label)

	var ratio = supply / max(1, demand)
	var bar_container = HBoxContainer.new()
	bar_container.add_theme_constant_override("separation", 8)
	parent.add_child(bar_container)

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, 20)
	bar.value = min(ratio * 100, 100)
	bar.show_percentage = false
	if ratio >= 1.0:
		bar.modulate = COLOR_GOOD
	elif ratio >= 0.5:
		bar.modulate = COLOR_WARNING
	else:
		bar.modulate = COLOR_CRITICAL
	bar_container.add_child(bar)

	var text = Label.new()
	text.text = "%d / %d %s" % [int(supply), int(demand), unit]
	text.add_theme_font_size_override("font_size", 11)
	bar_container.add_child(text)


func _create_condition_bar(condition: float) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(200, 16)
	bar.value = condition
	bar.show_percentage = false
	if condition >= 70:
		bar.modulate = COLOR_GOOD
	elif condition >= 40:
		bar.modulate = COLOR_WARNING
	else:
		bar.modulate = COLOR_CRITICAL
	hbox.add_child(bar)

	var label = Label.new()
	label.text = "%d%% - %s" % [int(condition), "Good" if condition >= 70 else ("Fair" if condition >= 40 else "Poor")]
	label.add_theme_font_size_override("font_size", 12)
	hbox.add_child(label)

	return hbox


func _create_budget_summary() -> PanelContainer:
	var budget_panel = PanelContainer.new()

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	budget_panel.add_child(grid)

	# Income
	var income_label = Label.new()
	income_label.text = "Monthly Income"
	income_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	grid.add_child(income_label)

	var income_value = Label.new()
	income_value.text = "+$%s" % _format_number(GameState.monthly_income)
	income_value.add_theme_color_override("font_color", COLOR_GOOD)
	grid.add_child(income_value)

	# Expenses
	var expense_label = Label.new()
	expense_label.text = "Monthly Expenses"
	expense_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	grid.add_child(expense_label)

	var expense_value = Label.new()
	expense_value.text = "-$%s" % _format_number(GameState.monthly_expenses)
	expense_value.add_theme_color_override("font_color", COLOR_CRITICAL)
	grid.add_child(expense_value)

	# Net
	var net = GameState.monthly_income - GameState.monthly_expenses
	var net_label = Label.new()
	net_label.text = "Net Income"
	grid.add_child(net_label)

	var net_value = Label.new()
	net_value.text = "%s$%s/mo" % ["+" if net >= 0 else "-", _format_number(abs(net))]
	net_value.add_theme_color_override("font_color", COLOR_GOOD if net >= 0 else COLOR_CRITICAL)
	net_value.add_theme_font_size_override("font_size", 16)
	grid.add_child(net_value)

	return budget_panel


func _create_demand_indicator(label: String, demand: float, color: Color, breakdown: DemandCalculator.ZoneDemandBreakdown = null) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var name_label = Label.new()
	name_label.text = label
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	vbox.add_child(name_label)

	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(100, 24)
	bar.value = max(0, demand) * 100
	bar.show_percentage = false
	bar.modulate = color if demand >= 0 else color.darkened(0.5)
	vbox.add_child(bar)

	var value_label = Label.new()
	value_label.text = "%+.0f%%" % (demand * 100)
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(value_label)

	# Add tooltip with detailed breakdown
	if breakdown:
		vbox.tooltip_text = DemandCalculator.get_demand_tooltip(breakdown)
	else:
		vbox.tooltip_text = "%s demand: %+d%%" % [label, int(demand * 100)]

	return vbox


func _get_active_alerts() -> Array:
	var alerts = []

	if GameState.has_power_shortage():
		alerts.append({"message": "Power shortage! Build more power plants.", "type": "critical"})

	if GameState.has_water_shortage():
		alerts.append({"message": "Water shortage! Expand water infrastructure.", "type": "critical"})

	if GameState.budget < 0:
		alerts.append({"message": "Budget in deficit! Reduce expenses or raise taxes.", "type": "warning"})

	if GameState.happiness < 0.3:
		alerts.append({"message": "Citizens are very unhappy!", "type": "warning"})

	if GameState.city_crime_rate > 0.3:
		alerts.append({"message": "High crime rate! Build more police stations.", "type": "warning"})

	# Storm outage alerts
	var power_system = _get_power_system()
	if power_system and power_system.get("storm_outage_active") and power_system.storm_outage_active:
		var outage_info = power_system.get_storm_outage_info() if power_system.has_method("get_storm_outage_info") else {}
		var severity = outage_info.get("severity_pct", 0)
		var restoration = outage_info.get("restoration_pct", 0)
		alerts.append({
			"message": "Storm damage: %d%% of grid affected (%d%% restored)" % [severity, restoration],
			"type": "critical"
		})

	# Drought alerts
	var weather_system = _get_weather_system()
	if weather_system and weather_system.get("drought_active") and weather_system.drought_active:
		var drought_info = weather_system.get_drought_info() if weather_system.has_method("get_drought_info") else {}
		var water_reduction = drought_info.get("water_reduction", 0)
		alerts.append({
			"message": "Drought: Water supply reduced by %d%%" % water_reduction,
			"type": "warning"
		})

	# Wildfire alerts
	var pollution_system = _get_pollution_system()
	if pollution_system and pollution_system.get("wildfire_active") and pollution_system.wildfire_active:
		var wildfire_info = pollution_system.get_wildfire_info() if pollution_system.has_method("get_wildfire_info") else {}
		var smoke_aqi = wildfire_info.get("smoke_aqi", 0)
		alerts.append({
			"message": "Wildfire smoke: +%d AQI impact on air quality" % smoke_aqi,
			"type": "warning"
		})

	# Poor air quality alerts
	if pollution_system and pollution_system.has_method("get_air_quality_index"):
		var aqi = pollution_system.get_air_quality_index()
		if aqi > 150:
			var category = pollution_system.get_air_quality_category() if pollution_system.has_method("get_air_quality_category") else "Unhealthy"
			alerts.append({
				"message": "Poor air quality: %s (AQI %d)" % [category, int(aqi)],
				"type": "critical" if aqi > 200 else "warning"
			})

	# Heat wave / Cold snap alerts
	if weather_system:
		if weather_system.get("heat_wave_active") and weather_system.heat_wave_active:
			alerts.append({"message": "Heat wave! Increased cooling costs and water demand.", "type": "warning"})
		if weather_system.get("cold_snap_active") and weather_system.cold_snap_active:
			alerts.append({"message": "Cold snap! Increased heating costs.", "type": "warning"})
		if weather_system.get("flood_active") and weather_system.flood_active:
			alerts.append({"message": "Flooding! Low-lying areas at risk.", "type": "critical"})

	return alerts


func _get_happiness_color() -> Color:
	if GameState.happiness >= 0.7:
		return COLOR_GOOD
	elif GameState.happiness >= 0.4:
		return COLOR_WARNING
	else:
		return COLOR_CRITICAL


func _connect_signals() -> void:
	Events.month_tick.connect(_update_all)
	Events.budget_updated.connect(func(_a, _b, _c): _update_all())
	Events.population_changed.connect(func(_a, _b): _update_all())


func _update_all() -> void:
	if not is_visible:
		return
	_on_tab_pressed(current_tab)


func _format_number(num: int) -> String:
	var str_num = str(abs(num))
	var result = ""
	var count = 0
	for i in range(str_num.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = str_num[i] + result
		count += 1
	return result


func _build_happiness_breakdown() -> void:
	# Get happiness breakdown from simulation
	var breakdown = Simulation.get_happiness_breakdown()
	if not breakdown:
		return

	# Section header with overall happiness
	var header_container = HBoxContainer.new()
	header_container.add_theme_constant_override("separation", 10)
	content_container.add_child(header_container)

	var header = Label.new()
	header.text = "Happiness Breakdown"
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9, 1))
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_container.add_child(header)

	var overall = Label.new()
	overall.text = "%d%%" % int(GameState.happiness * 100)
	overall.add_theme_font_size_override("font_size", 16)
	overall.add_theme_color_override("font_color", _get_happiness_color())
	header_container.add_child(overall)

	# Factor bars container
	var factors_container = VBoxContainer.new()
	factors_container.add_theme_constant_override("separation", 4)
	content_container.add_child(factors_container)

	# Display each factor as a bar
	for factor in breakdown.factors:
		var factor_row = _create_factor_row(factor, factor == breakdown.bottleneck)
		factors_container.add_child(factor_row)

	# Bottleneck advice (if any issues)
	if breakdown.bottleneck and breakdown.bottleneck.raw_value < 0.7:
		var advice_panel = PanelContainer.new()
		var advice_style = UIManager.get_panel_style(ThemeConstants.RADIUS_SMALL)
		advice_style.bg_color = ThemeConstants.STATUS_WARNING.darkened(0.7)
		advice_style.bg_color.a = 0.8
		advice_panel.add_theme_stylebox_override("panel", advice_style)
		content_container.add_child(advice_panel)

		var advice_hbox = HBoxContainer.new()
		advice_hbox.add_theme_constant_override("separation", 8)
		advice_panel.add_child(advice_hbox)

		var tip_icon = Label.new()
		tip_icon.text = "💡"
		advice_hbox.add_child(tip_icon)

		var advice_text = Label.new()
		advice_text.text = HappinessCalculator.get_factor_advice(breakdown.bottleneck.id)
		advice_text.autowrap_mode = TextServer.AUTOWRAP_WORD
		advice_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		advice_text.add_theme_font_size_override("font_size", 11)
		advice_text.add_theme_color_override("font_color", COLOR_WARNING)
		advice_hbox.add_child(advice_text)


func _create_factor_row(factor: HappinessCalculator.HappinessFactor, is_bottleneck: bool) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 22

	# Icon
	var icon = Label.new()
	icon.text = factor.icon
	icon.custom_minimum_size.x = 24
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(icon)

	# Name
	var name_label = Label.new()
	name_label.text = factor.name
	name_label.custom_minimum_size.x = 130
	name_label.add_theme_font_size_override("font_size", 11)
	if is_bottleneck:
		name_label.add_theme_color_override("font_color", COLOR_WARNING)
	else:
		name_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	row.add_child(name_label)

	# Progress bar
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(150, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.value = factor.raw_value * 100
	bar.show_percentage = false

	# Color based on status
	match factor.status:
		"good":
			bar.modulate = COLOR_GOOD
		"warning":
			bar.modulate = COLOR_WARNING
		"critical":
			bar.modulate = COLOR_CRITICAL
	row.add_child(bar)

	# Percentage value
	var value_label = Label.new()
	value_label.text = "%d%%" % int(factor.raw_value * 100)
	value_label.custom_minimum_size.x = 40
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 11)

	match factor.status:
		"good":
			value_label.add_theme_color_override("font_color", COLOR_GOOD)
		"warning":
			value_label.add_theme_color_override("font_color", COLOR_WARNING)
		"critical":
			value_label.add_theme_color_override("font_color", COLOR_CRITICAL)
	row.add_child(value_label)

	# Bottleneck indicator
	if is_bottleneck:
		var bottleneck_label = Label.new()
		bottleneck_label.text = "← Focus here"
		bottleneck_label.add_theme_font_size_override("font_size", 10)
		bottleneck_label.add_theme_color_override("font_color", COLOR_WARNING)
		row.add_child(bottleneck_label)

	return row
