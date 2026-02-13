extends TestBase

const CityEventBusScript = preload("res://src/autoloads/city_event_bus.gd")

class DummyBuildingData extends Resource:
	var display_name: String = "Substation"
	var maintenance_cost: int = 120

class DummyBuilding extends Node2D:
	var building_data: DummyBuildingData = DummyBuildingData.new()
	var is_operational: bool = true
	var workers: int = 15
	var workers_required: int = 20
	var efficiency: float = 0.75

class DummyEvents extends Node:
	signal budget_updated(balance: int, income: int, expenses: int)
	signal population_changed(population: int, delta: int)
	signal happiness_changed(happiness: float)
	signal build_mode_entered(mode_id: String)
	signal building_selected(building: Node2D)
	signal building_deselected()
	signal building_info_ready(building: Node2D, payload: Dictionary)

var _money: int = -1
var _income: int = -1
var _expenses: int = -1
var _selected_id: String = ""
var _selected_payload: Dictionary = {}
var _nodes_to_free: Array[Node] = []
var _root_events: Node = null
var _created_events_for_test: bool = false

func _track_node(node: Node) -> Node:
	_nodes_to_free.append(node)
	return node

func after_each() -> void:
	if _root_events and is_instance_valid(_root_events):
		if _created_events_for_test:
			_root_events.queue_free()
		_root_events = null
		_created_events_for_test = false
	for node in _nodes_to_free:
		if is_instance_valid(node):
			node.free()
	_nodes_to_free.clear()

func _capture_finance(balance: int, income: int, expenses: int) -> void:
	_money = balance
	_income = income
	_expenses = expenses

func _capture_selected(building_id: String, payload: Dictionary) -> void:
	_selected_id = building_id
	_selected_payload = payload


func _get_events_node() -> Node:
	var events = get_tree().root.get_node_or_null("Events")
	if events:
		_root_events = events
		_created_events_for_test = false
		return events
	var dummy = DummyEvents.new()
	dummy.name = "Events"
	get_tree().root.add_child(dummy)
	_root_events = dummy
	_created_events_for_test = true
	return dummy

func test_budget_bridge_emits_snapshot_and_money() -> void:
	var bus = _track_node(CityEventBusScript.new())
	bus.finance_snapshot_updated.connect(_capture_finance)
	bus.economy_changed.connect(func(money: int): _money = money)

	bus._on_budget_updated(150000, 4800, 2200)

	assert_eq(_money, 150000)
	assert_eq(_income, 4800)
	assert_eq(_expenses, 2200)

func test_building_selected_creates_payload() -> void:
	var bus = _track_node(CityEventBusScript.new())
	bus.building_selected.connect(_capture_selected)
	var building = _track_node(DummyBuilding.new())

	bus._on_building_selected(building)

	assert_ne(_selected_id, "")
	assert_eq(_selected_payload.get("name", ""), "Substation")
	assert_eq(_selected_payload.get("upkeep", 0), 120)
	assert_eq(_selected_payload.get("workers", 0), 15)
	assert_eq(_selected_payload.get("workers_capacity", 0), 20)
	assert_approx(float(_selected_payload.get("efficiency", 0.0)), 0.75, 0.0001)

func test_category_mapping_defaults_are_valid() -> void:
	var bus = _track_node(CityEventBusScript.new())
	assert_eq(bus._map_build_mode_to_building_id("roads"), "road")
	assert_eq(bus._map_build_mode_to_building_id("zoning"), "residential_zone")
	assert_eq(bus._map_build_mode_to_building_id("utilities"), "power_line")
	assert_eq(bus._map_build_mode_to_building_id("services"), "police_station")
	assert_eq(bus._map_build_mode_to_building_id("road"), "road")


func test_build_mode_request_emits_events_once_when_mapping_changes() -> void:
	var events = _get_events_node()
	var bus = _track_node(CityEventBusScript.new())
	get_tree().root.add_child(bus)

	var forwarded: Array[String] = []
	if events.has_signal("build_mode_entered"):
		events.connect("build_mode_entered", func(mode_id: String): forwarded.append(mode_id))
	bus._process_build_mode_request("roads")

	assert_size(forwarded, 1)
	assert_eq(forwarded[0], "road")


func test_build_mode_entered_passthrough_does_not_reemit_to_events() -> void:
	var events = _get_events_node()
	var bus = _track_node(CityEventBusScript.new())
	get_tree().root.add_child(bus)

	var forwarded: Array[String] = []
	var observed_bus: Array[String] = []
	if events.has_signal("build_mode_entered"):
		events.connect("build_mode_entered", func(mode_id: String): forwarded.append(mode_id))
	bus.build_mode_changed.connect(func(mode_id: String): observed_bus.append(mode_id))

	bus._on_build_mode_entered("road")

	assert_eq(observed_bus.size() >= 1, true)
	assert_eq(observed_bus[0], "road")
	assert_size(forwarded, 0)
