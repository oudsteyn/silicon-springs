extends DashboardTabBase
class_name DashboardEconomyTab
## Economy tab for the city dashboard - shows financial metrics and trends


func build_content(container: VBoxContainer) -> void:
	# Budget Overview
	container.add_child(_create_section_header("Budget Overview"))

	var budget_cards = HBoxContainer.new()
	budget_cards.add_theme_constant_override("separation", 12)
	container.add_child(budget_cards)

	var net = GameState.monthly_income - GameState.monthly_expenses
	budget_cards.add_child(_create_stat_card(
		"Balance",
		"$%s" % _format_number(GameState.budget),
		"Available funds",
		COLOR_GOOD if GameState.budget > 0 else COLOR_CRITICAL
	))

	budget_cards.add_child(_create_stat_card(
		"Income",
		"+$%s" % _format_number(GameState.monthly_income),
		"Monthly revenue",
		COLOR_GOOD
	))

	budget_cards.add_child(_create_stat_card(
		"Expenses",
		"-$%s" % _format_number(GameState.monthly_expenses),
		"Monthly costs",
		COLOR_NEUTRAL
	))

	budget_cards.add_child(_create_stat_card(
		"Net Change",
		"%s$%s" % ["+" if net >= 0 else "", _format_number(net)],
		"Per month",
		COLOR_GOOD if net >= 0 else COLOR_CRITICAL
	))

	# Income Breakdown
	container.add_child(_create_section_header("Income Sources"))
	var income_grid = GridContainer.new()
	income_grid.columns = 2
	income_grid.add_theme_constant_override("h_separation", 20)
	income_grid.add_theme_constant_override("v_separation", 6)
	container.add_child(income_grid)

	_add_stat_row(income_grid, "Residential Tax", "$%s" % _format_number(_estimate_residential_tax()), COLOR_GOOD)
	_add_stat_row(income_grid, "Commercial Tax", "$%s" % _format_number(_estimate_commercial_tax()), COLOR_GOOD)
	_add_stat_row(income_grid, "Industrial Tax", "$%s" % _format_number(_estimate_industrial_tax()), COLOR_GOOD)
	_add_stat_row(income_grid, "Data Centers", "$%s" % _format_number(_estimate_dc_income()), COLOR_GOOD)

	# Expense Breakdown
	container.add_child(_create_section_header("Expenses"))
	var expense_grid = GridContainer.new()
	expense_grid.columns = 2
	expense_grid.add_theme_constant_override("h_separation", 20)
	expense_grid.add_theme_constant_override("v_separation", 6)
	container.add_child(expense_grid)

	_add_stat_row(expense_grid, "Building Maintenance", "$%s" % _format_number(_estimate_maintenance()), COLOR_NEUTRAL)
	_add_stat_row(expense_grid, "Ordinances", "$%s" % _format_number(_estimate_ordinance_costs()), COLOR_NEUTRAL)
	_add_stat_row(expense_grid, "Trade Deals", "$%s" % _format_number(_estimate_trade_costs()), COLOR_NEUTRAL)

	# Tax Rate Info
	container.add_child(_create_section_header("Tax Settings"))
	var tax_label = Label.new()
	tax_label.text = "Current tax rate: %d%%" % int(GameConfig.base_tax_rate * 100)
	tax_label.add_theme_font_size_override("font_size", 12)
	container.add_child(tax_label)


func _estimate_residential_tax() -> int:
	var employed = GameState.population * GameState.get_employment_ratio()
	return int(employed * GameConfig.residential_tax_per_pop * GameConfig.base_tax_rate)


func _estimate_commercial_tax() -> int:
	return int(GameState.commercial_zones * GameConfig.commercial_tax_per_building * GameConfig.base_tax_rate)


func _estimate_industrial_tax() -> int:
	return int(GameState.industrial_zones * GameConfig.industrial_tax_per_building * GameConfig.base_tax_rate)


func _estimate_dc_income() -> int:
	# Placeholder - would need DC tracking
	return 0


func _estimate_maintenance() -> int:
	var grid = _get_system("grid")
	if grid and grid.has_method("get_total_maintenance"):
		return grid.get_total_maintenance()
	return GameState.monthly_expenses


func _estimate_ordinance_costs() -> int:
	# Placeholder for ordinance costs
	return 0


func _estimate_trade_costs() -> int:
	if NeighborDeals:
		return NeighborDeals.get_total_monthly_cost()
	return 0
