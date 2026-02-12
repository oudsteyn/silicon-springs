extends PanelContainer

signal upgrade_requested(building_id: String)
signal demolish_requested(building_id: String)

@onready var title_label: Label = %Title
@onready var status_label: Label = %Status
@onready var workers_label: Label = %Workers
@onready var efficiency_label: Label = %Efficiency
@onready var upkeep_label: Label = %Upkeep
@onready var upgrade_button: Button = %UpgradeButton
@onready var demolish_button: Button = %DemolishButton

var _building_id: String = ""
var _event_bus: Node = null

func _ready() -> void:
	visible = false
	upgrade_button.pressed.connect(_on_upgrade_pressed)
	demolish_button.pressed.connect(_on_demolish_pressed)
	var bus = _get_event_bus()
	if bus and bus.has_signal("building_stats_changed"):
		bus.building_stats_changed.connect(_on_building_stats_changed)

func show_building(building_id: String, payload: Dictionary) -> void:
	_building_id = building_id
	_apply_payload(payload)
	visible = true


func update_building_stats(payload: Dictionary) -> void:
	_apply_payload(payload)


func hide_building() -> void:
	_building_id = ""
	visible = false

func _on_building_stats_changed(building_id: String, payload: Dictionary) -> void:
	if visible and building_id == _building_id:
		_apply_payload(payload)

func _apply_payload(payload: Dictionary) -> void:
	title_label.text = str(payload.get("name", "Building"))
	status_label.text = str(payload.get("status", "Operational"))
	workers_label.text = "%s / %s" % [payload.get("workers", 0), payload.get("workers_capacity", 0)]
	efficiency_label.text = "%d%%" % int(round(float(payload.get("efficiency", 0.0)) * 100.0))
	upkeep_label.text = "$%s / mo" % str(payload.get("upkeep", 0))

func _on_upgrade_pressed() -> void:
	if _building_id != "":
		upgrade_requested.emit(_building_id)

func _on_demolish_pressed() -> void:
	if _building_id != "":
		demolish_requested.emit(_building_id)


func set_event_bus(bus: Node) -> void:
	_event_bus = bus


func _get_event_bus() -> Node:
	if _event_bus:
		return _event_bus
	if has_node("/root/CityEventBus"):
		return get_node("/root/CityEventBus")
	return null
