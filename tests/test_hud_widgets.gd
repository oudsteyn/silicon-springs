extends TestBase

const UIEventBusScript = preload("res://src/ui/autoloads/ui_event_bus.gd")
const BudgetWidgetScene = preload("res://src/ui/widgets/budget_widget.tscn")
const PopulationWidgetScene = preload("res://src/ui/widgets/population_widget.tscn")
const GlassPanelScene = preload("res://src/ui/components/glass_panel.tscn")

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


func test_budget_widget_binds_and_updates_labels() -> void:
	var bus = _track(UIEventBusScript.new())
	var widget = _track(BudgetWidgetScene.instantiate())
	widget.set_event_bus(bus)
	widget.bind_widget()

	bus.budget_changed.emit(1500, 420, 260)

	assert_eq(widget.get_node("Rows/BalanceLabel").text, "$1,500")
	assert_eq(widget.get_node("Rows/IncomeLabel").text, "+$420")
	assert_eq(widget.get_node("Rows/ExpensesLabel").text, "-$260")


func test_population_widget_updates_only_on_signal() -> void:
	var bus = _track(UIEventBusScript.new())
	var widget = _track(PopulationWidgetScene.instantiate())
	widget.set_event_bus(bus)
	widget.bind_widget()

	assert_eq(widget.get_node("ValueLabel").text, "0")
	bus.population_changed.emit(3210)
	assert_eq(widget.get_node("ValueLabel").text, "3,210")


func test_glass_panel_applies_style_defaults() -> void:
	var panel = _track(GlassPanelScene.instantiate())
	panel.apply_glass_style()
	var style = panel.get_theme_stylebox("panel")
	assert_not_null(style)
