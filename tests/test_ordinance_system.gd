extends TestBase
## Tests for OrdinanceSystem enact/repeal/effects logic

const OrdinanceScript = preload("res://src/systems/ordinance_system.gd")

var _to_free: Array = []


func before_each() -> void:
	GameState.reset_game()


func after_each() -> void:
	for i in range(_to_free.size() - 1, -1, -1):
		var instance = _to_free[i]
		if is_instance_valid(instance):
			instance.free()
	_to_free.clear()


func _track(instance):
	_to_free.append(instance)
	return instance


func test_enact_ordinance_succeeds() -> void:
	var system = _track(OrdinanceScript.new())

	var result = system.enact_ordinance("neighborhood_watch")

	assert_true(result)
	assert_true(system.is_enacted("neighborhood_watch"))


func test_enact_unknown_ordinance_fails() -> void:
	var system = _track(OrdinanceScript.new())

	var check = system.can_enact("nonexistent_ordinance")

	assert_false(check.can_enact)
	assert_true(check.reasons.size() > 0)


func test_enact_already_enacted_fails() -> void:
	var system = _track(OrdinanceScript.new())
	system.enact_ordinance("neighborhood_watch")

	var check = system.can_enact("neighborhood_watch")

	assert_false(check.can_enact)


func test_repeal_ordinance_succeeds() -> void:
	var system = _track(OrdinanceScript.new())
	system.enact_ordinance("clean_air")

	var result = system.repeal_ordinance("clean_air")

	assert_true(result)
	assert_false(system.is_enacted("clean_air"))


func test_repeal_unenacted_ordinance_fails() -> void:
	var system = _track(OrdinanceScript.new())

	var result = system.repeal_ordinance("clean_air")

	assert_false(result)


func test_enact_emits_signal() -> void:
	var system = _track(OrdinanceScript.new())
	var emitted: Array = []
	system.ordinance_enacted.connect(func(id): emitted.append(id))

	system.enact_ordinance("recycling_program")

	assert_eq(emitted.size(), 1)
	assert_eq(emitted[0], "recycling_program")


func test_repeal_emits_signal() -> void:
	var system = _track(OrdinanceScript.new())
	system.enact_ordinance("recycling_program")

	var emitted: Array = []
	system.ordinance_repealed.connect(func(id): emitted.append(id))
	system.repeal_ordinance("recycling_program")

	assert_eq(emitted.size(), 1)
	assert_eq(emitted[0], "recycling_program")


func test_get_total_monthly_cost() -> void:
	var system = _track(OrdinanceScript.new())
	system.enact_ordinance("neighborhood_watch")  # cost: 50
	system.enact_ordinance("clean_air")            # cost: 200

	assert_eq(system.get_total_monthly_cost(), 250)


func test_get_effect_aggregates_across_ordinances() -> void:
	var system = _track(OrdinanceScript.new())
	system.enact_ordinance("neighborhood_watch")  # crime_reduction: 0.15
	system.enact_ordinance("homeless_shelter")     # crime_reduction: 0.05

	assert_approx(system.get_effect("crime_reduction"), 0.20)


func test_get_effect_returns_zero_when_none() -> void:
	var system = _track(OrdinanceScript.new())

	assert_approx(system.get_effect("nonexistent_effect"), 0.0)


func test_get_ordinances_by_category() -> void:
	var system = _track(OrdinanceScript.new())

	var safety = system.get_ordinances_by_category("safety")

	assert_true(safety.size() >= 2, "Should have at least volunteer_fire and neighborhood_watch")
	for item in safety:
		assert_eq(item.data.category, "safety")


func test_get_active_ordinances_returns_enacted_only() -> void:
	var system = _track(OrdinanceScript.new())
	system.enact_ordinance("clean_air")
	system.enact_ordinance("free_transit")

	var active = system.get_active_ordinances()

	assert_eq(active.size(), 2)


func test_green_energy_bonus_zero_when_not_enacted() -> void:
	var system = _track(OrdinanceScript.new())

	assert_eq(system.get_green_energy_bonus_income(), 0)


func test_is_city_renewable_requires_clean_and_no_dirty() -> void:
	var system = _track(OrdinanceScript.new())

	# No buildings at all
	assert_false(system.is_city_100_percent_renewable())
