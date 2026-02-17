extends CanvasLayer

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

func set_event_bus(bus: Node) -> void:
	_event_bus = bus

func _ready() -> void:
	_connect_event_bus()
	_connect_popup_actions()
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
