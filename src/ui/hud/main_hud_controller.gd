extends CanvasLayer

@onready var money_label: Label = $Root/StatsPanel/Margin/VBox/Grid/MoneyValue
@onready var pop_label: Label = $Root/StatsPanel/Margin/VBox/Grid/PopulationValue
@onready var happ_label: Label = $Root/StatsPanel/Margin/VBox/Grid/HappinessValue
@onready var stats_panel: PanelContainer = $Root/StatsPanel
@onready var stats_margin: MarginContainer = $Root/StatsPanel/Margin
@onready var stats_header: HBoxContainer = $Root/StatsPanel/Margin/VBox/Header
@onready var stats_vbox: VBoxContainer = $Root/StatsPanel/Margin/VBox
@onready var stats_close_button: Button = $Root/StatsPanel/Margin/VBox/Header/StatsCloseButton
@onready var stats_grid: GridContainer = $Root/StatsPanel/Margin/VBox/Grid
@onready var info_popup: Control = $Root/BuildingInfoPopup
@onready var build_menu: PanelContainer = $Root/BuildMenu
@onready var roads_button: Button = $Root/BuildMenu/Margin/Row/Roads
@onready var zoning_button: Button = $Root/BuildMenu/Margin/Row/Zoning
@onready var utilities_button: Button = $Root/BuildMenu/Margin/Row/Utilities
@onready var services_button: Button = $Root/BuildMenu/Margin/Row/Services
@onready var finance_panel: PanelContainer = $Root/FinancePanel
@onready var finance_balance: Label = $Root/FinancePanel/FinanceMargin/FinanceGrid/FinanceBalance
@onready var finance_income: Label = $Root/FinancePanel/FinanceMargin/FinanceGrid/FinanceIncome
@onready var finance_expenses: Label = $Root/FinancePanel/FinanceMargin/FinanceGrid/FinanceExpenses

var _event_bus: Node = null
var _selected_building_id: String = ""
var _selected_building_payload: Dictionary = {}
var _stats_collapsed: bool = false
var _stats_expanded_height: float = 0.0
var _stats_expanded_min_height: float = 0.0

func set_event_bus(bus: Node) -> void:
	_event_bus = bus

func _ready() -> void:
	_connect_event_bus()
	_connect_popup_actions()
	if stats_close_button and not stats_close_button.pressed.is_connected(_on_stats_close_pressed):
		stats_close_button.pressed.connect(_on_stats_close_pressed)
	_initialize_stats_panel_height()
	var build_menu_has_category_signal := build_menu and build_menu.has_signal("build_category_selected")
	if build_menu_has_category_signal:
		build_menu.connect("build_category_selected", Callable(self, "_on_build_category_selected"))
	else:
		roads_button.pressed.connect(func(): _on_build_category_selected("roads"))
		zoning_button.pressed.connect(func(): _on_build_category_selected("zoning"))
		utilities_button.pressed.connect(func(): _on_build_category_selected("utilities"))
		services_button.pressed.connect(func(): _on_build_category_selected("services"))
	if finance_panel:
		finance_panel.visible = false


func _connect_popup_actions() -> void:
	if info_popup == null:
		return
	if info_popup.has_signal("upgrade_requested") and not info_popup.upgrade_requested.is_connected(_on_popup_upgrade_requested):
		info_popup.upgrade_requested.connect(_on_popup_upgrade_requested)
	if info_popup.has_signal("demolish_requested") and not info_popup.demolish_requested.is_connected(_on_popup_demolish_requested):
		info_popup.demolish_requested.connect(_on_popup_demolish_requested)


func _connect_event_bus() -> void:
	var bus = _get_event_bus()
	if bus == null:
		return
	if info_popup and info_popup.has_method("set_event_bus"):
		info_popup.call("set_event_bus", bus)
	if not bus.economy_changed.is_connected(_on_economy_changed):
		bus.economy_changed.connect(_on_economy_changed)
	if not bus.population_changed.is_connected(_on_population_changed):
		bus.population_changed.connect(_on_population_changed)
	if not bus.happiness_changed.is_connected(_on_happiness_changed):
		bus.happiness_changed.connect(_on_happiness_changed)
	if not bus.building_selected.is_connected(_on_building_selected):
		bus.building_selected.connect(_on_building_selected)
	if not bus.building_deselected.is_connected(_on_building_deselected):
		bus.building_deselected.connect(_on_building_deselected)
	if bus.has_signal("building_stats_changed") and not bus.building_stats_changed.is_connected(_on_building_stats_changed):
		bus.building_stats_changed.connect(_on_building_stats_changed)
	if bus.has_signal("finance_snapshot_updated") and not bus.finance_snapshot_updated.is_connected(_on_finance_snapshot_updated):
		bus.finance_snapshot_updated.connect(_on_finance_snapshot_updated)
	if bus.has_signal("finance_panel_toggled") and not bus.finance_panel_toggled.is_connected(_on_finance_panel_toggled):
		bus.finance_panel_toggled.connect(_on_finance_panel_toggled)


func _on_popup_upgrade_requested(building_id: String) -> void:
	var bus = _get_event_bus()
	if bus and bus.has_signal("building_upgrade_requested"):
		bus.emit_signal("building_upgrade_requested", building_id)


func _on_popup_demolish_requested(building_id: String) -> void:
	var bus = _get_event_bus()
	if bus and bus.has_signal("building_demolish_requested"):
		bus.emit_signal("building_demolish_requested", building_id)

func _get_event_bus() -> Node:
	if _event_bus:
		return _event_bus
	if has_node("/root/CityEventBus"):
		return get_node("/root/CityEventBus")
	return null

func _on_economy_changed(money: int) -> void:
	money_label.text = "$%s" % String.num_int64(money)

func _on_population_changed(population: int) -> void:
	pop_label.text = String.num_int64(population)

func _on_happiness_changed(happiness: float) -> void:
	happ_label.text = "%d%%" % int(round(happiness * 100.0))

func _on_building_selected(building_id: String, payload: Dictionary) -> void:
	_selected_building_id = building_id
	_selected_building_payload = payload.duplicate(true)
	info_popup.call("show_building", building_id, payload)

func _on_building_deselected() -> void:
	_selected_building_id = ""
	_selected_building_payload.clear()
	info_popup.call("hide_building")


func _on_building_stats_changed(building_id: String, payload: Dictionary) -> void:
	if _selected_building_id == "" or _selected_building_id != building_id:
		return
	for key in payload.keys():
		_selected_building_payload[key] = payload[key]
	if info_popup.has_method("update_building_stats"):
		info_popup.call("update_building_stats", _selected_building_payload)
	else:
		info_popup.call("show_building", _selected_building_id, _selected_building_payload)

func _on_finance_snapshot_updated(balance: int, income: int, expenses: int) -> void:
	finance_balance.text = "$%s" % String.num_int64(balance)
	finance_income.text = "+$%s/mo" % String.num_int64(income)
	finance_expenses.text = "-$%s/mo" % String.num_int64(expenses)

func _on_finance_panel_toggled(visible_state: bool) -> void:
	finance_panel.visible = visible_state

func _on_build_category_selected(category_id: String) -> void:
	var bus = _get_event_bus()
	if bus:
		bus.emit_signal("build_mode_changed", category_id)


func _on_stats_close_pressed() -> void:
	_set_stats_collapsed(not _stats_collapsed)


func _initialize_stats_panel_height() -> void:
	if not stats_panel:
		return
	stats_panel.anchor_top = 0.0
	stats_panel.anchor_bottom = 0.0
	_stats_expanded_min_height = stats_panel.custom_minimum_size.y
	_stats_expanded_height = _measure_stats_expanded_height()
	_set_stats_collapsed(false)


func _set_stats_collapsed(collapsed: bool) -> void:
	if not stats_panel:
		return
	_stats_collapsed = collapsed
	stats_close_button.text = "+" if collapsed else "x"
	if collapsed:
		if stats_grid:
			stats_grid.visible = false
		var collapsed_height = _measure_stats_collapsed_height()
		_apply_stats_panel_height(collapsed_height)
	else:
		if stats_grid:
			stats_grid.visible = true
		_stats_expanded_height = _measure_stats_expanded_height()
		var expanded_height = maxf(_stats_expanded_min_height, _stats_expanded_height)
		_apply_stats_panel_height(expanded_height)


func _measure_stats_expanded_height() -> float:
	var collapsed_height := _measure_stats_collapsed_height()
	if not stats_grid:
		return collapsed_height
	var grid_height := stats_grid.get_combined_minimum_size().y
	var row_spacing := _get_vbox_separation()
	return collapsed_height + row_spacing + grid_height


func _measure_stats_collapsed_height() -> float:
	var header_height := stats_header.get_combined_minimum_size().y if stats_header else 22.0
	var margin_top := _get_margin_constant("margin_top", 8)
	var margin_bottom := _get_margin_constant("margin_bottom", 8)
	return header_height + margin_top + margin_bottom


func _get_margin_constant(name: String, fallback: int) -> int:
	if not stats_margin:
		return fallback
	return stats_margin.get_theme_constant(name) if stats_margin.has_theme_constant(name) else fallback


func _get_vbox_separation() -> int:
	if not stats_vbox:
		return 0
	return stats_vbox.get_theme_constant("separation") if stats_vbox.has_theme_constant("separation") else 0


func _apply_stats_panel_height(target_height: float) -> void:
	var height = maxf(1.0, target_height)

	var min_size = stats_panel.custom_minimum_size
	min_size.y = height
	stats_panel.custom_minimum_size = min_size

	# Explicit size assignment avoids stale visual height in some layout paths.
	var panel_size = stats_panel.size
	panel_size.y = height
	stats_panel.size = panel_size

	stats_panel.offset_bottom = stats_panel.offset_top + height
