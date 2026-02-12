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

var _money: int = -1
var _income: int = -1
var _expenses: int = -1
var _selected_id: String = ""
var _selected_payload: Dictionary = {}

func _capture_finance(balance: int, income: int, expenses: int) -> void:
	_money = balance
	_income = income
	_expenses = expenses

func _capture_selected(building_id: String, payload: Dictionary) -> void:
	_selected_id = building_id
	_selected_payload = payload

func test_budget_bridge_emits_snapshot_and_money() -> void:
	var bus = CityEventBusScript.new()
	bus.finance_snapshot_updated.connect(_capture_finance)
	bus.economy_changed.connect(func(money: int): _money = money)

	bus._on_budget_updated(150000, 4800, 2200)

	assert_eq(_money, 150000)
	assert_eq(_income, 4800)
	assert_eq(_expenses, 2200)

func test_building_selected_creates_payload() -> void:
	var bus = CityEventBusScript.new()
	bus.building_selected.connect(_capture_selected)
	var building = DummyBuilding.new()

	bus._on_building_selected(building)

	assert_ne(_selected_id, "")
	assert_eq(_selected_payload.get("name", ""), "Substation")
	assert_eq(_selected_payload.get("upkeep", 0), 120)
	assert_eq(_selected_payload.get("workers", 0), 15)
	assert_eq(_selected_payload.get("workers_capacity", 0), 20)
	assert_approx(float(_selected_payload.get("efficiency", 0.0)), 0.75, 0.0001)

	building.free()

func test_category_mapping_defaults_are_valid() -> void:
	var bus = CityEventBusScript.new()
	assert_eq(bus._map_build_mode_to_building_id("roads"), "road")
	assert_eq(bus._map_build_mode_to_building_id("zoning"), "residential_zone")
	assert_eq(bus._map_build_mode_to_building_id("utilities"), "power_line")
	assert_eq(bus._map_build_mode_to_building_id("services"), "police_station")
	assert_eq(bus._map_build_mode_to_building_id("road"), "road")
