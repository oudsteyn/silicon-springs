extends PanelContainer
class_name DCRequirementsPanel
## Shows data center tier requirements and current status

@onready var title_label: Label = $VBox/TitleLabel
@onready var requirements_container: VBoxContainer = $VBox/RequirementsContainer

var current_tier: int = 0
var _events: Node = null

# Requirement thresholds per tier
const REQUIREMENTS = {
	1: {"power": 5, "water": 100, "population": 10, "education": 0, "fire": true, "police": false},
	2: {"power": 25, "water": 500, "population": 100, "education": 20, "fire": true, "police": true},
	3: {"power": 100, "water": 2000, "population": 500, "education": 40, "fire": true, "police": true}
}


func _ready() -> void:
	visible = false

	# Update when resources change
	var events = _get_events()
	if events:
		events.power_updated.connect(_on_resources_updated)
		events.water_updated.connect(_on_resources_updated)
		events.population_changed.connect(_on_resources_updated)
		events.education_changed.connect(_on_resources_updated)
		events.coverage_updated.connect(_on_resources_updated)


func set_events(events: Node) -> void:
	_events = events


func _get_events() -> Node:
	if _events:
		return _events
	var tree = get_tree()
	if tree:
		return tree.root.get_node_or_null("Events")
	return null


func show_requirements(tier: int, at_cell: Vector2i = Vector2i(-1, -1)) -> void:
	current_tier = tier
	if not REQUIREMENTS.has(tier):
		visible = false
		return

	title_label.text = "Tier %d Requirements" % tier
	_update_requirements(at_cell)
	visible = true


func hide_requirements() -> void:
	visible = false


func _update_requirements(at_cell: Vector2i = Vector2i(-1, -1)) -> void:
	# Clear existing
	for child in requirements_container.get_children():
		child.queue_free()

	if not REQUIREMENTS.has(current_tier):
		return

	var reqs = REQUIREMENTS[current_tier]

	# Power requirement
	var power_available = GameState.get_available_power()
	var power_needed = reqs.power
	_add_requirement_row(
		"Power",
		"%d / %d MW" % [int(power_available), power_needed],
		power_available >= power_needed
	)

	# Water requirement
	var water_available = GameState.get_available_water()
	var water_needed = reqs.water
	_add_requirement_row(
		"Water",
		"%d / %d ML" % [int(water_available), water_needed],
		water_available >= water_needed
	)

	# Population requirement
	var pop = GameState.population
	var pop_needed = reqs.population
	_add_requirement_row(
		"Population",
		"%d / %d" % [pop, pop_needed],
		pop >= pop_needed
	)

	# Education requirement (if any)
	if reqs.education > 0:
		var edu = int(GameState.education_rate * 100)
		var edu_needed = reqs.education
		_add_requirement_row(
			"Education",
			"%d%% / %d%%" % [edu, edu_needed],
			edu >= edu_needed
		)

	# Fire coverage
	if reqs.fire:
		var has_fire = _check_fire_coverage(at_cell)
		_add_requirement_row(
			"Fire Coverage",
			"Yes" if has_fire else "No",
			has_fire
		)

	# Police coverage
	if reqs.police:
		var has_police = _check_police_coverage(at_cell)
		_add_requirement_row(
			"Police Coverage",
			"Yes" if has_police else "No",
			has_police
		)


func _add_requirement_row(label_text: String, value_text: String, is_met: bool) -> void:
	var hbox = HBoxContainer.new()

	var icon = Label.new()
	icon.text = "✓" if is_met else "✗"
	icon.modulate = Color.GREEN if is_met else Color.RED
	icon.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(icon)

	var label = Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.modulate = Color.GREEN if is_met else Color.RED
	hbox.add_child(value)

	requirements_container.add_child(hbox)


func _check_fire_coverage(at_cell: Vector2i) -> bool:
	if at_cell == Vector2i(-1, -1):
		# No specific cell, check if any fire station exists
		return GameState.get_building_count("fire_station") > 0
	# Check specific cell coverage
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.game_world and main.game_world.service_coverage:
		return main.game_world.service_coverage.has_fire_coverage(at_cell)
	return false


func _check_police_coverage(at_cell: Vector2i) -> bool:
	if at_cell == Vector2i(-1, -1):
		return GameState.get_building_count("police_station") > 0
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.game_world and main.game_world.service_coverage:
		return main.game_world.service_coverage.has_police_coverage(at_cell)
	return false


func _on_resources_updated(_arg1 = null, _arg2 = null) -> void:
	if visible:
		_update_requirements()
