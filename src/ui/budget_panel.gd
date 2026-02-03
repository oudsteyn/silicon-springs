extends PanelContainer
class_name BudgetPanel
## Detailed budget screen with income/expense breakdown and adjustable rates

signal closed()

@onready var close_button: Button = $VBox/Header/CloseButton
@onready var income_list: VBoxContainer = $VBox/Content/IncomeSection/IncomeList
@onready var expense_list: VBoxContainer = $VBox/Content/ExpenseSection/ExpenseList
@onready var total_income_label: Label = $VBox/Content/IncomeSection/TotalIncome
@onready var total_expense_label: Label = $VBox/Content/ExpenseSection/TotalExpense
@onready var net_label: Label = $VBox/Summary/NetLabel
@onready var tax_rate_slider: HSlider = $VBox/Controls/TaxSection/TaxSlider
@onready var tax_rate_label: Label = $VBox/Controls/TaxSection/TaxValue

# Cached expense breakdown (received via Events)
var _expense_breakdown: Dictionary = {}


func _ready() -> void:
	visible = false
	close_button.pressed.connect(_on_close_pressed)
	tax_rate_slider.value_changed.connect(_on_tax_rate_changed)

	# Set initial tax rate
	tax_rate_slider.value = GameState.BASE_TAX_RATE * 100

	# Connect to events
	Events.month_tick.connect(_on_month_tick)
	Events.expense_breakdown_ready.connect(_on_expense_breakdown_ready)

	# Apply consistent styling
	_apply_styling()


func _apply_styling() -> void:
	# Apply centralized panel styling
	var style = UIManager.get_modal_style()
	add_theme_stylebox_override("panel", style)

	# Style labels
	if total_income_label:
		total_income_label.add_theme_color_override("font_color", UIManager.COLORS.success)
	if total_expense_label:
		total_expense_label.add_theme_color_override("font_color", UIManager.COLORS.danger)
	if net_label:
		net_label.add_theme_font_size_override("font_size", 16)


func _on_month_tick() -> void:
	if visible:
		_request_expense_breakdown()


func _request_expense_breakdown() -> void:
	Events.expense_breakdown_requested.emit()


func _on_expense_breakdown_ready(breakdown: Dictionary) -> void:
	_expense_breakdown = breakdown
	if visible:
		_update_budget()


func show_budget() -> void:
	visible = true
	_request_expense_breakdown()  # Request fresh data, will trigger _update_budget when ready


func hide_budget() -> void:
	visible = false


func _on_close_pressed() -> void:
	hide_budget()
	closed.emit()


func _on_tax_rate_changed(value: float) -> void:
	GameState.tax_rate = value / 100.0
	tax_rate_label.text = "%d%%" % int(value)
	_update_budget()


func _update_budget() -> void:
	if not visible:
		return

	_update_income()
	_update_expenses()
	_update_summary()


func _update_income() -> void:
	# Clear existing items
	for child in income_list.get_children():
		child.queue_free()

	var total = 0

	# Residential tax
	var res_tax = int(GameState.employed_population * GameState.RESIDENTIAL_TAX_PER_POP * GameState.tax_rate / GameState.BASE_TAX_RATE)
	_add_line_item(income_list, "Residential Tax", res_tax, "%d employed x $%.0f" % [GameState.employed_population, GameState.RESIDENTIAL_TAX_PER_POP])
	total += res_tax

	# Commercial tax
	var com_count = GameState.commercial_zones
	var com_tax = int(com_count * GameState.COMMERCIAL_TAX_PER_BUILDING * GameState.tax_rate / GameState.BASE_TAX_RATE)
	_add_line_item(income_list, "Commercial Tax", com_tax, "%d zones x $%.0f" % [com_count, GameState.COMMERCIAL_TAX_PER_BUILDING])
	total += com_tax

	# Industrial tax
	var ind_count = GameState.industrial_zones
	var ind_tax = int(ind_count * 30 * GameState.tax_rate / GameState.BASE_TAX_RATE)
	_add_line_item(income_list, "Industrial Tax", ind_tax, "%d zones x $30" % ind_count)
	total += ind_tax

	# Data center income
	var dc1 = GameState.data_centers_by_tier.get(1, 0) * 500
	var dc2 = GameState.data_centers_by_tier.get(2, 0) * 2000
	var dc3 = GameState.data_centers_by_tier.get(3, 0) * 5000
	var dc_total = dc1 + dc2 + dc3
	if dc_total > 0:
		_add_line_item(income_list, "Data Centers", dc_total, "T1:%d T2:%d T3:%d" % [
			GameState.data_centers_by_tier.get(1, 0),
			GameState.data_centers_by_tier.get(2, 0),
			GameState.data_centers_by_tier.get(3, 0)
		])
		total += dc_total

	total_income_label.text = "Total Income: $%s/mo" % _format_number(total)
	total_income_label.modulate = Color.GREEN


func _update_expenses() -> void:
	# Clear existing items
	for child in expense_list.get_children():
		child.queue_free()

	var total = 0

	# Display by category (from cached expense breakdown)
	var category_names = {
		"infrastructure": "Infrastructure",
		"power": "Power Plants",
		"water": "Water Facilities",
		"service": "Services",
		"recreation": "Recreation",
		"zone": "Zones",
		"data_center": "Data Centers"
	}

	for cat in _expense_breakdown:
		var cat_name = category_names.get(cat, cat.capitalize())
		var data = _expense_breakdown[cat]
		_add_line_item(expense_list, cat_name, -data.total, "%d buildings" % data.count)
		total += data.total

	total_expense_label.text = "Total Expenses: -$%s/mo" % _format_number(total)
	total_expense_label.modulate = Color.RED


func _update_summary() -> void:
	var net = GameState.monthly_income - GameState.monthly_expenses
	if net >= 0:
		net_label.text = "Net: +$%s/mo" % _format_number(net)
		net_label.modulate = Color.GREEN
	else:
		net_label.text = "Net: -$%s/mo" % _format_number(abs(net))
		net_label.modulate = Color.RED


func _add_line_item(container: VBoxContainer, item_name: String, amount: int, detail: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = item_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var detail_label = Label.new()
	detail_label.text = detail
	detail_label.modulate = Color(0.7, 0.7, 0.7)
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(detail_label)

	var amount_label = Label.new()
	if amount >= 0:
		amount_label.text = "+$%s" % _format_number(amount)
		amount_label.modulate = Color.GREEN
	else:
		amount_label.text = "-$%s" % _format_number(abs(amount))
		amount_label.modulate = Color.RED
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount_label.custom_minimum_size.x = 80
	hbox.add_child(amount_label)

	container.add_child(hbox)


func _format_number(num: int) -> String:
	return FormatUtils.format_number(num)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		hide_budget()
		get_viewport().set_input_as_handled()
