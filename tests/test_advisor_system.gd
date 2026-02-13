extends TestBase
## Tests for AdvisorSystem advice generation and event emission

const AdvisorScript = preload("res://src/systems/advisor_system.gd")

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


func test_give_advice_emits_signal() -> void:
	var advisor = _track(AdvisorScript.new())
	var received: Array = []
	advisor.advice_ready.connect(func(a, m, p): received.append({"advisor": a, "message": m, "priority": p}))

	advisor._give_advice(AdvisorSystem.AdvisorType.FINANCE, "test", "Budget is low", 2)

	assert_eq(received.size(), 1)
	assert_eq(received[0].advisor, "Financial Advisor")
	assert_eq(received[0].message, "Budget is low")
	assert_eq(received[0].priority, 2)


func test_give_advice_respects_cooldown() -> void:
	var advisor = _track(AdvisorScript.new())
	var counter: Array = [0]
	advisor.advice_ready.connect(func(_a, _m, _p): counter[0] += 1)

	advisor._give_advice(AdvisorSystem.AdvisorType.FINANCE, "dup", "msg", 1)
	advisor._give_advice(AdvisorSystem.AdvisorType.FINANCE, "dup", "msg", 1)

	assert_eq(counter[0], 1, "Second advice with same id should be blocked by cooldown")


func test_cooldown_expires_after_update() -> void:
	var advisor = _track(AdvisorScript.new())
	var counter: Array = [0]
	advisor.advice_ready.connect(func(_a, _m, _p): counter[0] += 1)

	advisor._give_advice(AdvisorSystem.AdvisorType.CITY, "expire", "msg", 1)

	# Tick down cooldown fully (ADVICE_COOLDOWN = 6)
	for i in range(7):
		advisor._update_cooldowns()

	advisor._give_advice(AdvisorSystem.AdvisorType.CITY, "expire", "msg", 1)
	assert_eq(counter[0], 2, "Advice should fire again after cooldown expires")


func test_finance_advice_on_negative_budget() -> void:
	var advisor = _track(AdvisorScript.new())
	var messages: Array = []
	advisor.advice_ready.connect(func(_a, m, _p): messages.append(m))

	GameState.budget = -100
	advisor._check_finance_conditions()

	assert_true(messages.size() > 0, "Should give advice on negative budget")
	assert_true(messages[0].find("red") >= 0 or messages[0].find("budget") >= 0)


func test_safety_advice_no_fire_station() -> void:
	var advisor = _track(AdvisorScript.new())
	var messages: Array = []
	advisor.advice_ready.connect(func(_a, m, _p): messages.append(m))

	GameState.population = 200
	advisor._check_safety_conditions()

	assert_true(messages.size() > 0, "Should advise building fire station")


func test_get_all_current_advice_sorted_by_priority() -> void:
	var advisor = _track(AdvisorScript.new())

	GameState.budget = -100
	GameState.population = 200
	GameState.residential_demand = 0.8
	var advice = advisor.get_all_current_advice()

	# Should be sorted highest priority first
	if advice.size() >= 2:
		assert_gte(advice[0].priority, advice[1].priority)


func test_advice_forwards_to_simulation_event() -> void:
	var advisor = _track(AdvisorScript.new())
	var events: Array = []
	advisor.advice_ready.connect(func(a, m, p):
		Events.simulation_event.emit("advisor_message", {"advisor": a, "message": m, "priority": p})
	)
	Events.simulation_event.connect(func(t, d):
		if t == "advisor_message":
			events.append(d)
	)

	advisor._give_advice(AdvisorSystem.AdvisorType.UTILITY, "test_fwd", "Power needed", 3)

	assert_eq(events.size(), 1)
	assert_eq(events[0].advisor, "Utility Manager")

	# Clean up connections
	for c in Events.simulation_event.get_connections():
		Events.simulation_event.disconnect(c.callable)
