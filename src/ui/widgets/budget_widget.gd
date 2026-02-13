extends "res://src/ui/widgets/widget_controller.gd"

@onready var balance_label: Label = %BalanceLabel
@onready var income_label: Label = %IncomeLabel
@onready var expenses_label: Label = %ExpensesLabel

var _last_balance: int = -2147483648
var _last_income: int = -2147483648
var _last_expenses: int = -2147483648


func _on_bind() -> void:
	var bus = get_event_bus()
	if bus and bus.has_signal("budget_changed") and not bus.budget_changed.is_connected(_on_budget_changed):
		bus.budget_changed.connect(_on_budget_changed)


func _on_unbind() -> void:
	var bus = get_event_bus()
	if bus and bus.has_signal("budget_changed") and bus.budget_changed.is_connected(_on_budget_changed):
		bus.budget_changed.disconnect(_on_budget_changed)


func _on_budget_changed(balance: int, income: int, expenses: int) -> void:
	if balance != _last_balance:
		_last_balance = balance
		balance_label.text = "$%s" % _format_int(balance)

	if income != _last_income:
		_last_income = income
		income_label.text = "+$%s" % _format_int(income)

	if expenses != _last_expenses:
		_last_expenses = expenses
		expenses_label.text = "-$%s" % _format_int(expenses)


func _format_int(value: int) -> String:
	var raw = str(abs(value))
	var groups: Array[String] = []
	while raw.length() > 3:
		groups.push_front(raw.substr(raw.length() - 3, 3))
		raw = raw.substr(0, raw.length() - 3)
	groups.push_front(raw)
	var out = ",".join(groups)
	return "-%s" % out if value < 0 else out
