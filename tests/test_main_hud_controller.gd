extends TestBase

const MainHUDScene = preload("res://src/ui/hud/main_hud.tscn")

class FakeBus extends Node:
	signal economy_changed(money: int)
	signal population_changed(population: int)
	signal happiness_changed(happiness: float)
	signal building_selected(building_id: String, payload: Dictionary)
	signal building_deselected()
	signal finance_panel_toggled(visible: bool)
	signal finance_snapshot_updated(balance: int, income: int, expenses: int)
	signal build_mode_changed(mode_id: String)

var _selected_mode: String = ""

func test_finance_panel_visibility_and_values() -> void:
	var hud = MainHUDScene.instantiate()
	var bus = FakeBus.new()
	hud.set_event_bus(bus)
	add_child(bus)
	add_child(hud)

	bus.finance_snapshot_updated.emit(100000, 5000, 3200)
	assert_eq(hud.get_node("%FinanceBalance").text, "$100000")
	assert_eq(hud.get_node("%FinanceIncome").text, "+$5000/mo")
	assert_eq(hud.get_node("%FinanceExpenses").text, "-$3200/mo")

	bus.finance_panel_toggled.emit(true)
	assert_true(hud.get_node("%FinancePanel").visible)

	bus.finance_panel_toggled.emit(false)
	assert_false(hud.get_node("%FinancePanel").visible)

	hud.free()
	bus.free()

func test_build_menu_selection_emits_build_mode() -> void:
	var hud = MainHUDScene.instantiate()
	var bus = FakeBus.new()
	_selected_mode = ""
	bus.build_mode_changed.connect(func(mode_id: String): _selected_mode = mode_id)
	hud.set_event_bus(bus)
	add_child(bus)
	add_child(hud)

	hud.call("_on_build_category_selected", "roads")
	assert_eq(_selected_mode, "roads")

	hud.free()
	bus.free()
