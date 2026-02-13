extends "res://src/ui/widgets/widget_controller.gd"

@onready var value_label: Label = %ValueLabel

var _last_population: int = -2147483648


func _on_bind() -> void:
	var bus = get_event_bus()
	if bus and bus.has_signal("population_changed") and not bus.population_changed.is_connected(_on_population_changed):
		bus.population_changed.connect(_on_population_changed)


func _on_unbind() -> void:
	var bus = get_event_bus()
	if bus and bus.has_signal("population_changed") and bus.population_changed.is_connected(_on_population_changed):
		bus.population_changed.disconnect(_on_population_changed)


func _on_population_changed(population: int) -> void:
	if population == _last_population:
		return
	_last_population = population
	value_label.text = _format_int(population)


func _format_int(value: int) -> String:
	var raw = str(abs(value))
	var groups: Array[String] = []
	while raw.length() > 3:
		groups.push_front(raw.substr(raw.length() - 3, 3))
		raw = raw.substr(0, raw.length() - 3)
	groups.push_front(raw)
	var out = ",".join(groups)
	return "-%s" % out if value < 0 else out
