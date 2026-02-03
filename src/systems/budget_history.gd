extends Node
## Tracks budget and financial metrics over time for graphing

signal history_updated()

# Maximum months to track
const MAX_HISTORY: int = 120  # 10 years

# History arrays
var budget_history: Array[int] = []
var income_history: Array[int] = []
var expense_history: Array[int] = []
var population_history: Array[int] = []
var happiness_history: Array[float] = []

# Monthly breakdown tracking
var current_month_income: Dictionary = {
	"residential_tax": 0,
	"commercial_tax": 0,
	"industrial_tax": 0,
	"data_center": 0,
	"other": 0
}

var current_month_expenses: Dictionary = {
	"maintenance": 0,
	"ordinances": 0,
	"services": 0,
	"other": 0
}


func _ready() -> void:
	Events.month_tick.connect(_on_month_tick)


func _on_month_tick() -> void:
	# Record current state
	budget_history.append(GameState.budget)
	income_history.append(GameState.monthly_income)
	expense_history.append(GameState.monthly_expenses)
	population_history.append(GameState.population)
	happiness_history.append(GameState.happiness)

	# Trim to max history
	while budget_history.size() > MAX_HISTORY:
		budget_history.pop_front()
		income_history.pop_front()
		expense_history.pop_front()
		population_history.pop_front()
		happiness_history.pop_front()

	history_updated.emit()


func get_budget_history(months: int = 12) -> Array[int]:
	var count = min(months, budget_history.size())
	return budget_history.slice(-count) if count > 0 else []


func get_income_history(months: int = 12) -> Array[int]:
	var count = min(months, income_history.size())
	return income_history.slice(-count) if count > 0 else []


func get_expense_history(months: int = 12) -> Array[int]:
	var count = min(months, expense_history.size())
	return expense_history.slice(-count) if count > 0 else []


func get_population_history(months: int = 12) -> Array[int]:
	var count = min(months, population_history.size())
	return population_history.slice(-count) if count > 0 else []


func get_happiness_history(months: int = 12) -> Array[float]:
	var count = min(months, happiness_history.size())
	return happiness_history.slice(-count) if count > 0 else []


func get_net_history(months: int = 12) -> Array[int]:
	var income = get_income_history(months)
	var expense = get_expense_history(months)
	var net: Array[int] = []
	for i in range(min(income.size(), expense.size())):
		net.append(income[i] - expense[i])
	return net


func get_average_income(months: int = 12) -> float:
	var history = get_income_history(months)
	if history.is_empty():
		return 0.0
	var total = 0
	for val in history:
		total += val
	return float(total) / history.size()


func get_average_expense(months: int = 12) -> float:
	var history = get_expense_history(months)
	if history.is_empty():
		return 0.0
	var total = 0
	for val in history:
		total += val
	return float(total) / history.size()


func get_budget_trend(months: int = 12) -> float:
	# Returns positive if budget is trending up, negative if down
	var history = get_budget_history(months)
	if history.size() < 2:
		return 0.0

	var midpoint: int = int(history.size() * 0.5)
	var first_half = history.slice(0, midpoint)
	var second_half = history.slice(midpoint)

	var first_avg = 0.0
	for val in first_half:
		first_avg += val
	first_avg /= first_half.size() if first_half.size() > 0 else 1

	var second_avg = 0.0
	for val in second_half:
		second_avg += val
	second_avg /= second_half.size() if second_half.size() > 0 else 1

	return second_avg - first_avg


func get_months_tracked() -> int:
	return budget_history.size()


func clear_history() -> void:
	budget_history.clear()
	income_history.clear()
	expense_history.clear()
	population_history.clear()
	happiness_history.clear()


func get_save_data() -> Dictionary:
	return {
		"budget_history": budget_history.duplicate(),
		"income_history": income_history.duplicate(),
		"expense_history": expense_history.duplicate(),
		"population_history": population_history.duplicate(),
		"happiness_history": happiness_history.duplicate()
	}


func load_save_data(data: Dictionary) -> void:
	budget_history.assign(data.get("budget_history", []))
	income_history.assign(data.get("income_history", []))
	expense_history.assign(data.get("expense_history", []))
	population_history.assign(data.get("population_history", []))
	happiness_history.assign(data.get("happiness_history", []))
