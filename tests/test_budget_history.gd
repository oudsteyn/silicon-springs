extends TestBase
## Tests for BudgetHistory financial tracking

const BudgetHistoryScript = preload("res://src/systems/budget_history.gd")

var _to_free: Array = []


func after_each() -> void:
	for i in range(_to_free.size() - 1, -1, -1):
		var instance = _to_free[i]
		if is_instance_valid(instance):
			instance.free()
	_to_free.clear()


func _track(instance):
	_to_free.append(instance)
	return instance


func _make_history() -> Node:
	var h = _track(BudgetHistoryScript.new())
	return h


func test_initial_state_empty() -> void:
	var h = _make_history()
	assert_eq(h.get_months_tracked(), 0)
	assert_eq(h.get_budget_history().size(), 0)


func test_get_budget_history_returns_last_n_months() -> void:
	var h = _make_history()
	h.budget_history = [100, 200, 300, 400, 500] as Array[int]
	var last3 = h.get_budget_history(3)
	assert_eq(last3.size(), 3)
	assert_eq(last3[0], 300)
	assert_eq(last3[2], 500)


func test_get_budget_history_clamps_to_available() -> void:
	var h = _make_history()
	h.budget_history = [100, 200] as Array[int]
	var result = h.get_budget_history(10)
	assert_eq(result.size(), 2)


func test_get_net_history_computes_income_minus_expense() -> void:
	var h = _make_history()
	h.income_history = [1000, 1500, 2000] as Array[int]
	h.expense_history = [800, 900, 2500] as Array[int]
	var net = h.get_net_history(3)
	assert_eq(net.size(), 3)
	assert_eq(net[0], 200)
	assert_eq(net[1], 600)
	assert_eq(net[2], -500)


func test_get_average_income() -> void:
	var h = _make_history()
	h.income_history = [100, 200, 300] as Array[int]
	var avg = h.get_average_income(3)
	assert_approx(avg, 200.0, 0.01)


func test_get_average_income_empty() -> void:
	var h = _make_history()
	assert_approx(h.get_average_income(), 0.0, 0.01)


func test_get_average_expense() -> void:
	var h = _make_history()
	h.expense_history = [50, 150] as Array[int]
	assert_approx(h.get_average_expense(2), 100.0, 0.01)


func test_get_budget_trend_positive() -> void:
	var h = _make_history()
	h.budget_history = [100, 100, 200, 200] as Array[int]
	# First half avg = 100, second half avg = 200 → trend = +100
	var trend = h.get_budget_trend(4)
	assert_true(trend > 0, "Trend should be positive")


func test_get_budget_trend_negative() -> void:
	var h = _make_history()
	h.budget_history = [500, 500, 100, 100] as Array[int]
	var trend = h.get_budget_trend(4)
	assert_true(trend < 0, "Trend should be negative")


func test_get_budget_trend_insufficient_data() -> void:
	var h = _make_history()
	h.budget_history = [100] as Array[int]
	assert_approx(h.get_budget_trend(), 0.0, 0.01)


func test_clear_history() -> void:
	var h = _make_history()
	h.budget_history = [1, 2, 3] as Array[int]
	h.income_history = [1] as Array[int]
	h.expense_history = [1] as Array[int]
	h.population_history = [1] as Array[int]
	h.happiness_history = [0.5] as Array[float]

	h.clear_history()

	assert_eq(h.budget_history.size(), 0)
	assert_eq(h.income_history.size(), 0)
	assert_eq(h.expense_history.size(), 0)
	assert_eq(h.population_history.size(), 0)
	assert_eq(h.happiness_history.size(), 0)


func test_save_and_load_round_trip() -> void:
	var h = _make_history()
	h.budget_history = [100, 200] as Array[int]
	h.income_history = [50, 60] as Array[int]
	h.expense_history = [30, 40] as Array[int]
	h.population_history = [10, 20] as Array[int]
	h.happiness_history = [0.5, 0.7] as Array[float]

	var data = h.get_save_data()

	var h2 = _make_history()
	h2.load_save_data(data)

	assert_eq(h2.budget_history.size(), 2)
	assert_eq(h2.budget_history[0], 100)
	assert_eq(h2.income_history[1], 60)
	assert_eq(h2.population_history[1], 20)
