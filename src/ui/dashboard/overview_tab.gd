extends DashboardTabBase
class_name DashboardOverviewTab
## Overview tab for the city dashboard - shows key metrics at a glance

signal panel_requested(panel_name: String)


func build_content(container: VBoxContainer) -> void:
	# Quick Status Cards Row
	var cards_row = HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 12)
	container.add_child(cards_row)

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
	_build_happiness_breakdown(container)

	# Alerts Section
	var alerts = _get_active_alerts()
	if alerts.size() > 0:
		container.add_child(_create_section_header("Active Alerts"))
		for alert in alerts:
			container.add_child(_create_alert_item(alert.message, alert.type))

	# Quick Actions
	container.add_child(_create_section_header("Quick Actions"))
	var actions_row = HBoxContainer.new()
	actions_row.add_theme_constant_override("separation", 8)
	container.add_child(actions_row)

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
	container.add_child(_create_section_header("City Statistics"))
	var stats_grid = GridContainer.new()
	stats_grid.columns = 3
	stats_grid.add_theme_constant_override("h_separation", 20)
	stats_grid.add_theme_constant_override("v_separation", 8)
	container.add_child(stats_grid)

	_add_stat_row(stats_grid, "Employment", "%d%%" % int(GameState.get_employment_ratio() * 100))
	_add_stat_row(stats_grid, "Education Rate", "%d%%" % int(GameState.education_rate * 100))
	_add_stat_row(stats_grid, "Crime Rate", "%d%%" % int(GameState.city_crime_rate * 100))
	_add_stat_row(stats_grid, "Traffic Congestion", "%d%%" % int(GameState.city_traffic_congestion * 100))
	_add_stat_row(stats_grid, "Residential Zones", str(GameState.residential_zones))
	_add_stat_row(stats_grid, "Commercial Zones", str(GameState.commercial_zones))
	_add_stat_row(stats_grid, "Industrial Zones", str(GameState.industrial_zones))
	_add_stat_row(stats_grid, "City Score", _format_number(GameState.score))
	_add_stat_row(stats_grid, "Game Date", GameState.get_date_string())


func _get_happiness_color() -> Color:
	if GameState.happiness >= 0.7:
		return COLOR_GOOD
	elif GameState.happiness >= 0.4:
		return COLOR_WARNING
	else:
		return COLOR_CRITICAL


func _build_happiness_breakdown(container: VBoxContainer) -> void:
	container.add_child(_create_section_header("Happiness Factors"))

	var factors_grid = GridContainer.new()
	factors_grid.columns = 2
	factors_grid.add_theme_constant_override("h_separation", 15)
	factors_grid.add_theme_constant_override("v_separation", 4)
	container.add_child(factors_grid)

	# Get happiness breakdown from GameState
	var factors = GameState.get_happiness_breakdown() if GameState.has_method("get_happiness_breakdown") else {}

	for factor_name in factors:
		var factor_value = factors[factor_name]
		var label = Label.new()
		label.text = factor_name + ":"
		label.add_theme_font_size_override("font_size", 10)
		factors_grid.add_child(label)

		var value_label = Label.new()
		var sign_str = "+" if factor_value > 0 else ""
		value_label.text = "%s%d%%" % [sign_str, int(factor_value * 100)]
		value_label.add_theme_font_size_override("font_size", 10)
		if factor_value > 0:
			value_label.add_theme_color_override("font_color", COLOR_GOOD)
		elif factor_value < 0:
			value_label.add_theme_color_override("font_color", COLOR_CRITICAL)
		factors_grid.add_child(value_label)


func _get_active_alerts() -> Array:
	var alerts = []

	# Power shortage
	if GameState.has_power_shortage():
		alerts.append({"message": "Power shortage! Build more power plants.", "type": "critical"})

	# Water shortage
	if GameState.has_water_shortage():
		alerts.append({"message": "Water shortage! Expand water infrastructure.", "type": "critical"})

	# Low happiness
	if GameState.happiness < 0.3:
		alerts.append({"message": "Citizens are unhappy! Check service coverage.", "type": "warning"})

	# Budget crisis
	if GameState.budget < 0:
		alerts.append({"message": "Budget in deficit! Reduce expenses or increase taxes.", "type": "critical"})

	# High unemployment
	if GameState.get_employment_ratio() < 0.7:
		alerts.append({"message": "High unemployment. Build more commercial/industrial zones.", "type": "warning"})

	return alerts


func _create_alert_item(message: String, alert_type: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var icon = Label.new()
	icon.text = "!" if alert_type == "critical" else "?"
	icon.add_theme_font_size_override("font_size", 14)
	icon.add_theme_color_override("font_color", COLOR_CRITICAL if alert_type == "critical" else COLOR_WARNING)
	row.add_child(icon)

	var msg = Label.new()
	msg.text = message
	msg.add_theme_font_size_override("font_size", 11)
	msg.add_theme_color_override("font_color", COLOR_CRITICAL if alert_type == "critical" else COLOR_WARNING)
	row.add_child(msg)

	return row


func _create_action_button(text: String, panel_name: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(100, 30)
	btn.pressed.connect(func(): panel_requested.emit(panel_name))
	return btn
