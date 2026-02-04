extends TestBase
## Tests for UI components using injected Events instead of global autoload.

const InfoPanelScene = preload("res://src/ui/info_panel.tscn")
const BudgetPanelScene = preload("res://src/ui/budget_panel.tscn")


class FakeEvents extends Node:
	signal building_selected(building)
	signal building_deselected()
	signal building_info_ready(building, info)
	signal cell_info_ready(cell, info)
	signal building_info_requested(building)
	signal cell_info_requested(cell)

	signal month_tick()
	signal expense_breakdown_ready(breakdown)
	signal expense_breakdown_requested()

	signal simulation_event(event_name, payload)
	signal building_placed(cell, building)
	signal building_removed(cell, building)

	signal power_updated()
	signal water_updated()
	signal pollution_updated()
	signal coverage_updated()

var _requested_cell: Vector2i = Vector2i(-1, -1)
var _expense_requested: bool = false
var _last_sim_event: String = ""


func _on_cell_info_requested(cell: Vector2i) -> void:
	_requested_cell = cell


func _on_expense_breakdown_requested() -> void:
	_expense_requested = true


func _on_simulation_event(name: String, _payload) -> void:
	_last_sim_event = name


func test_info_panel_uses_injected_events() -> void:
	var events = FakeEvents.new()
	add_child(events)
	var panel = InfoPanelScene.instantiate()
	panel.set_events(events)
	add_child(panel)
	assert_eq(panel._get_events(), events)

	assert_true(events.building_selected.is_connected(Callable(panel, "_on_building_selected")))
	assert_true(events.building_deselected.is_connected(Callable(panel, "_on_building_deselected")))
	assert_true(events.building_info_ready.is_connected(Callable(panel, "_on_building_info_ready")))
	assert_true(events.cell_info_ready.is_connected(Callable(panel, "_on_cell_info_ready")))

	_requested_cell = Vector2i(-1, -1)
	events.cell_info_requested.connect(Callable(self, "_on_cell_info_requested"))
	panel.show_cell_info(Vector2i(2, 3))
	assert_eq(_requested_cell, Vector2i(2, 3))

	panel.free()
	events.free()


func test_budget_panel_uses_injected_events() -> void:
	var events = FakeEvents.new()
	add_child(events)
	var panel = BudgetPanelScene.instantiate()
	panel.set_events(events)
	add_child(panel)
	assert_eq(panel._get_events(), events)

	assert_true(events.month_tick.is_connected(Callable(panel, "_on_month_tick")))
	assert_true(events.expense_breakdown_ready.is_connected(Callable(panel, "_on_expense_breakdown_ready")))

	_expense_requested = false
	events.expense_breakdown_requested.connect(Callable(self, "_on_expense_breakdown_requested"))
	panel.show_budget()
	assert_true(_expense_requested)

	panel.free()
	events.free()


func test_measurement_tool_emits_via_injected_events() -> void:
	var events = FakeEvents.new()
	add_child(events)
	var tool = MeasurementTool.new()
	tool.set_events(events)
	add_child(tool)
	assert_eq(tool._get_events(), events)

	_last_sim_event = ""
	events.simulation_event.connect(Callable(self, "_on_simulation_event"))
	tool.activate()
	assert_eq(_last_sim_event, "measurement_started")

	tool.deactivate()
	assert_eq(_last_sim_event, "measurement_ended")

	tool.free()
	events.free()


func test_action_feedback_effects_uses_injected_events() -> void:
	var events = FakeEvents.new()
	add_child(events)
	var effects = ActionFeedbackEffects.new()
	effects.set_events(events)
	add_child(effects)

	assert_true(events.building_placed.is_connected(Callable(effects, "_on_building_placed")))
	assert_true(events.building_removed.is_connected(Callable(effects, "_on_building_removed")))
	assert_true(events.simulation_event.is_connected(Callable(effects, "_on_simulation_event")))

	effects.free()
	events.free()


func test_heat_map_renderer_uses_injected_events() -> void:
	var events = FakeEvents.new()
	add_child(events)
	var renderer = HeatMapRenderer.new()
	renderer.set_events(events)
	add_child(renderer)

	assert_true(events.power_updated.is_connected(Callable(renderer, "_on_data_updated")))
	assert_true(events.water_updated.is_connected(Callable(renderer, "_on_data_updated")))
	assert_true(events.pollution_updated.is_connected(Callable(renderer, "_on_data_updated")))
	assert_true(events.coverage_updated.is_connected(Callable(renderer, "_on_coverage_updated")))
	assert_true(events.month_tick.is_connected(Callable(renderer, "_on_month_tick")))

	renderer.free()
	events.free()
