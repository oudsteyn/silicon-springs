extends Control
class_name WidgetController

@export var event_bus_path: NodePath = NodePath("/root/UIEventBus")

var _event_bus: Node = null
var _is_bound: bool = false


func _ready() -> void:
	if _event_bus == null and not event_bus_path.is_empty():
		_event_bus = get_node_or_null(event_bus_path)
	bind_widget()


func _exit_tree() -> void:
	unbind_widget()


func set_event_bus(bus: Node) -> void:
	if _event_bus == bus:
		return
	if _is_bound:
		_on_unbind()
		_is_bound = false
	_event_bus = bus


func get_event_bus() -> Node:
	return _event_bus


func bind_widget() -> void:
	if _is_bound:
		return
	_is_bound = true
	_on_bind()


func unbind_widget() -> void:
	if not _is_bound:
		return
	_on_unbind()
	_is_bound = false


func _on_bind() -> void:
	pass


func _on_unbind() -> void:
	pass
