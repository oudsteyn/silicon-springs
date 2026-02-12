extends TestBase

const DaylightControllerScript = preload("res://src/world/lighting/daylight_controller.gd")

var _nodes_to_free: Array[Node] = []

func _track_node(node: Node) -> Node:
	_nodes_to_free.append(node)
	return node

func after_each() -> void:
	for node in _nodes_to_free:
		if is_instance_valid(node):
			node.free()
	_nodes_to_free.clear()

func test_get_visual_state_has_expected_ranges() -> void:
	var controller = _track_node(DaylightControllerScript.new())
	var sun = _track_node(DirectionalLight3D.new())
	controller.sun = sun
	controller.set_time_normalized(0.5)

	var state: Dictionary = controller.get_visual_state()
	assert_gte(float(state.get("day_factor", -1.0)), 0.0)
	assert_lte(float(state.get("day_factor", 2.0)), 1.0)
	assert_gte(float(state.get("sun_energy", 0.0)), 0.02)
	assert_lte(float(state.get("sun_energy", 99.0)), 1.5)
	assert_gte(float(state.get("fog_density", 0.0)), 0.008)
	assert_lte(float(state.get("fog_density", 99.0)), 0.03)

func test_night_has_lower_energy_than_midday() -> void:
	var controller = _track_node(DaylightControllerScript.new())
	var sun = _track_node(DirectionalLight3D.new())
	controller.sun = sun

	controller.set_time_normalized(0.0)
	var night = controller.get_visual_state()
	controller.set_time_normalized(0.5)
	var noon = controller.get_visual_state()

	assert_lt(float(night.get("sun_energy", 9.0)), float(noon.get("sun_energy", -1.0)))
	assert_gt(float(night.get("fog_density", 0.0)), float(noon.get("fog_density", 1.0)))
