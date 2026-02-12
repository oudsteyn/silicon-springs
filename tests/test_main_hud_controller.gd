extends TestBase

const MainHUDControllerScript = preload("res://src/ui/hud/main_hud_controller.gd")

class FakeBus extends Node:
	signal economy_changed(money: int)
	signal population_changed(population: int)
	signal happiness_changed(happiness: float)
	signal building_selected(building_id: String, payload: Dictionary)
	signal building_deselected()
	signal building_stats_changed(building_id: String, payload: Dictionary)
	signal finance_panel_toggled(visible: bool)
	signal finance_snapshot_updated(balance: int, income: int, expenses: int)
	signal build_mode_changed(mode_id: String)

class FakeInfoPopup extends Control:
	var shown_with_id: String = ""
	var shown_payload: Dictionary = {}
	var hide_called: bool = false
	var update_count: int = 0

	func show_building(building_id: String, payload: Dictionary) -> void:
		shown_with_id = building_id
		shown_payload = payload
		hide_called = false

	func hide_building() -> void:
		hide_called = true

	func update_building_stats(payload: Dictionary) -> void:
		update_count += 1
		for key in payload.keys():
			shown_payload[key] = payload[key]

var _selected_mode: String = ""

func _build_hud(bus: Node) -> CanvasLayer:
	var hud := CanvasLayer.new()
	hud.set_script(MainHUDControllerScript)

	var root := Control.new()
	root.name = "Root"
	hud.add_child(root)

	var build_menu := PanelContainer.new()
	build_menu.name = "BuildMenu"
	root.add_child(build_menu)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	build_menu.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "Row"
	margin.add_child(row)

	for button_name in ["Roads", "Zoning", "Utilities", "Services"]:
		var btn := Button.new()
		btn.name = button_name
		row.add_child(btn)

	var stats_panel := PanelContainer.new()
	stats_panel.name = "StatsPanel"
	root.add_child(stats_panel)

	var stats_margin := MarginContainer.new()
	stats_margin.name = "Margin"
	stats_panel.add_child(stats_margin)

	var grid := GridContainer.new()
	grid.name = "Grid"
	stats_margin.add_child(grid)

	for label_name in ["MoneyValue", "PopulationValue", "HappinessValue"]:
		var lbl := Label.new()
		lbl.name = label_name
		grid.add_child(lbl)

	var finance_panel := PanelContainer.new()
	finance_panel.name = "FinancePanel"
	root.add_child(finance_panel)

	var finance_margin := MarginContainer.new()
	finance_margin.name = "FinanceMargin"
	finance_panel.add_child(finance_margin)

	var finance_grid := GridContainer.new()
	finance_grid.name = "FinanceGrid"
	finance_margin.add_child(finance_grid)

	for finance_label_name in ["FinanceBalance", "FinanceIncome", "FinanceExpenses"]:
		var lbl2 := Label.new()
		lbl2.name = finance_label_name
		finance_grid.add_child(lbl2)

	var popup := FakeInfoPopup.new()
	popup.name = "BuildingInfoPopup"
	root.add_child(popup)

	hud.call("set_event_bus", bus)
	return hud

func test_finance_panel_visibility_and_values() -> void:
	var bus = FakeBus.new()
	var hud = _build_hud(bus)
	add_child(bus)
	add_child(hud)

	bus.finance_snapshot_updated.emit(100000, 5000, 3200)
	assert_eq(hud.get_node("Root/FinancePanel/FinanceMargin/FinanceGrid/FinanceBalance").text, "$100000")
	assert_eq(hud.get_node("Root/FinancePanel/FinanceMargin/FinanceGrid/FinanceIncome").text, "+$5000/mo")
	assert_eq(hud.get_node("Root/FinancePanel/FinanceMargin/FinanceGrid/FinanceExpenses").text, "-$3200/mo")

	bus.finance_panel_toggled.emit(true)
	assert_true(hud.get_node("Root/FinancePanel").visible)

	bus.finance_panel_toggled.emit(false)
	assert_false(hud.get_node("Root/FinancePanel").visible)

	hud.free()
	bus.free()

func test_build_menu_selection_emits_build_mode() -> void:
	var bus = FakeBus.new()
	_selected_mode = ""
	bus.build_mode_changed.connect(func(mode_id: String): _selected_mode = mode_id)

	var hud = _build_hud(bus)
	add_child(bus)
	add_child(hud)

	hud.call("_on_build_category_selected", "roads")
	assert_eq(_selected_mode, "roads")

	hud.free()
	bus.free()

func test_building_selection_routes_to_popup() -> void:
	var bus = FakeBus.new()
	var hud = _build_hud(bus)
	add_child(bus)
	add_child(hud)

	bus.building_selected.emit("b-1", {"name": "Road"})
	var popup = hud.get_node("Root/BuildingInfoPopup") as FakeInfoPopup
	assert_eq(popup.shown_with_id, "b-1")
	assert_eq(popup.shown_payload.get("name", ""), "Road")

	bus.building_deselected.emit()
	assert_true(popup.hide_called)

	hud.free()
	bus.free()

func test_building_stats_update_tracks_selected_building_only() -> void:
	var bus = FakeBus.new()
	var hud = _build_hud(bus)
	add_child(bus)
	add_child(hud)
	var popup = hud.get_node("Root/BuildingInfoPopup") as FakeInfoPopup

	bus.building_selected.emit("b-1", {"name": "Road", "workers": 2})
	bus.building_stats_changed.emit("b-2", {"workers": 99})
	assert_eq(popup.update_count, 0)
	assert_eq(popup.shown_payload.get("workers", 0), 2)

	bus.building_stats_changed.emit("b-1", {"workers": 3, "efficiency": 0.9})
	assert_eq(popup.update_count, 1)
	assert_eq(popup.shown_payload.get("workers", 0), 3)
	assert_eq(popup.shown_payload.get("efficiency", 0.0), 0.9)

	bus.building_deselected.emit()
	bus.building_stats_changed.emit("b-1", {"workers": 4})
	assert_eq(popup.update_count, 1)

	hud.free()
	bus.free()
