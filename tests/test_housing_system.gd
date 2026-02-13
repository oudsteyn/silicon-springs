extends TestBase
## Tests for HousingSystem affordability, brackets, and gentrification

const HousingScript = preload("res://src/systems/housing_system.gd")

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


func _make_housing() -> Node:
	return _track(HousingScript.new())


func test_initial_capacity_all_zero() -> void:
	var h = _make_housing()
	var cap = h.get_housing_capacity_by_bracket()
	assert_eq(cap["low"], 0)
	assert_eq(cap["medium"], 0)
	assert_eq(cap["high"], 0)


func test_affordable_housing_shortage_with_no_population() -> void:
	var h = _make_housing()
	GameState.population = 0
	var shortage = h.get_affordable_housing_shortage()
	assert_eq(shortage, 0)


func test_affordable_housing_shortage_with_population() -> void:
	var h = _make_housing()
	GameState.population = 1000
	# 30% of 1000 = 300 low-income needed, 0 capacity
	var shortage = h.get_affordable_housing_shortage()
	assert_eq(shortage, 300)


func test_affordable_housing_shortage_partially_met() -> void:
	var h = _make_housing()
	GameState.population = 1000
	h.housing_capacity["low"] = 100
	var shortage = h.get_affordable_housing_shortage()
	assert_eq(shortage, 200)


func test_housing_affordability_score_no_capacity() -> void:
	var h = _make_housing()
	var score = h.get_housing_affordability_score()
	assert_approx(score, 0.5, 0.01)


func test_housing_affordability_score_perfect_balance() -> void:
	var h = _make_housing()
	# Ideal: 30% low, 50% medium, 20% high
	h.housing_capacity["low"] = 30
	h.housing_capacity["medium"] = 50
	h.housing_capacity["high"] = 20
	var score = h.get_housing_affordability_score()
	assert_approx(score, 1.0, 0.01)


func test_housing_affordability_score_no_low_income_housing() -> void:
	var h = _make_housing()
	h.housing_capacity["low"] = 0
	h.housing_capacity["medium"] = 50
	h.housing_capacity["high"] = 50
	var score = h.get_housing_affordability_score()
	# low_ratio = 0, target = 0.3, deviation = 0.3
	assert_approx(score, 0.7, 0.01)


func test_gentrification_rate_no_history() -> void:
	var h = _make_housing()
	assert_approx(h.get_gentrification_rate(), 0.0, 0.01)


func test_gentrification_rate_with_history() -> void:
	var h = _make_housing()
	h.displacement_history = [10, 20, 30] as Array[int]
	assert_approx(h.get_gentrification_rate(), 20.0, 0.01)


func test_displacement_history_capped_at_12() -> void:
	var h = _make_housing()
	for i in range(15):
		h.displaced_residents = i
		h._update_displacement_history()
	assert_eq(h.displacement_history.size(), 12)


func test_affordability_happiness_modifier_good() -> void:
	var h = _make_housing()
	GameState.population = 100
	h.housing_capacity["low"] = 100  # More than enough
	var mod = h.get_affordability_happiness_modifier()
	assert_approx(mod, 0.02, 0.001)


func test_affordability_happiness_modifier_severe_shortage() -> void:
	var h = _make_housing()
	GameState.population = 5000
	h.housing_capacity["low"] = 0  # 1500 shortage
	var mod = h.get_affordability_happiness_modifier()
	assert_approx(mod, -0.10, 0.001)


func test_income_diversity_bonus_balanced() -> void:
	var h = _make_housing()
	h.housing_capacity["low"] = 33
	h.housing_capacity["medium"] = 34
	h.housing_capacity["high"] = 33
	var bonus = h.get_income_diversity_bonus()
	assert_true(bonus > 0, "Should have diversity bonus when balanced")


func test_income_diversity_bonus_zero_capacity() -> void:
	var h = _make_housing()
	assert_approx(h.get_income_diversity_bonus(), 0.0, 0.001)


func test_income_diversity_bonus_skewed() -> void:
	var h = _make_housing()
	h.housing_capacity["low"] = 0
	h.housing_capacity["medium"] = 100
	h.housing_capacity["high"] = 0
	var bonus = h.get_income_diversity_bonus()
	assert_approx(bonus, 0.0, 0.001)
