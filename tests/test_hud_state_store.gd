extends TestBase

const HUDStateStoreScript = preload("res://src/ui/autoloads/hud_state_store.gd")
const UIEventBusScript = preload("res://src/ui/autoloads/ui_event_bus.gd")

var _tracked_nodes: Array[Node] = []


func after_each() -> void:
	for i in range(_tracked_nodes.size() - 1, -1, -1):
		var node = _tracked_nodes[i]
		if is_instance_valid(node):
			node.queue_free()
	_tracked_nodes.clear()


func _track(node: Node) -> Node:
	_tracked_nodes.append(node)
	get_tree().root.add_child(node)
	return node


func test_ingest_coalesces_high_frequency_updates() -> void:
	var bus = _track(UIEventBusScript.new())
	var store = _track(HUDStateStoreScript.new())
	store.set_event_bus(bus)
	store.set_push_interval_ms_for_tests(100)

	var budget_events: Array[Dictionary] = []
	bus.budget_changed.connect(func(balance: int, income: int, expenses: int) -> void:
		budget_events.append({"balance": balance, "income": income, "expenses": expenses})
	)

	store.ingest_simulation_snapshot({"balance": 100, "income": 50, "expenses": 20})
	store.ingest_simulation_snapshot({"balance": 120, "income": 60, "expenses": 25})
	store.pump(10)

	assert_size(budget_events, 1)
	assert_eq(int(budget_events[0]["balance"]), 120)
	assert_eq(int(budget_events[0]["income"]), 60)
	assert_eq(int(budget_events[0]["expenses"]), 25)


func test_pump_respects_interval_and_skips_unchanged_state() -> void:
	var bus = _track(UIEventBusScript.new())
	var store = _track(HUDStateStoreScript.new())
	store.set_event_bus(bus)
	store.set_push_interval_ms_for_tests(100)

	var population_events: Array[int] = []
	bus.population_changed.connect(func(value: int) -> void:
		population_events.append(value)
	)

	store.ingest_simulation_snapshot({"population": 10})
	assert_true(store.pump(100))
	assert_false(store.pump(150))

	store.ingest_simulation_snapshot({"population": 10})
	assert_true(store.pump(250))
	assert_size(population_events, 1)

	store.ingest_simulation_snapshot({"population": 11})
	assert_true(store.pump(400))
	assert_size(population_events, 2)
	assert_eq(population_events, [10, 11])
