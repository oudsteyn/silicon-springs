extends TestBase

const OptionsPanelScript = preload("res://src/ui/components/options_panel.gd")

class FakeGraphicsManager extends Node:
	var bound_environment: Environment = null
	var selected_preset: int = -1
	var shadow_quality: int = -1
	var ssr_enabled: bool = true
	var ssao_enabled: bool = true
	var fog_enabled: bool = true
	var glow_enabled: bool = false
	var exposure: float = 1.0
	var white_point: float = 1.0
	var auto_quality_enabled: bool = true

	func bind_environment(env: Environment) -> void:
		bound_environment = env

	func set_quality_preset(preset: int, _apply_now: bool = true) -> void:
		selected_preset = preset

	func set_shadow_quality(quality: int, _apply_now: bool = true) -> void:
		shadow_quality = quality

	func set_ssr_override(enabled: bool, _apply_now: bool = true) -> void:
		ssr_enabled = enabled

	func set_ssao_override(enabled: bool, _apply_now: bool = true) -> void:
		ssao_enabled = enabled

	func set_volumetric_fog_override(enabled: bool, _apply_now: bool = true) -> void:
		fog_enabled = enabled

	func set_cinematic_grade(new_exposure: float, new_white_point: float, new_glow_enabled: bool, _apply_now: bool = true) -> void:
		exposure = new_exposure
		white_point = new_white_point
		glow_enabled = new_glow_enabled

	func set_auto_quality_enabled(enabled: bool) -> void:
		auto_quality_enabled = enabled

	func get_current_settings() -> Dictionary:
		return {
			"preset": selected_preset,
			"shadow_quality": shadow_quality,
			"ssr_enabled": ssr_enabled,
			"ssao_enabled": ssao_enabled,
			"volumetric_fog_enabled": fog_enabled,
			"glow_enabled": glow_enabled,
			"tonemap_exposure": exposure,
			"tonemap_white": white_point,
			"auto_quality_enabled": auto_quality_enabled
		}

var _nodes_to_free: Array[Node] = []

func _track_node(node: Node) -> Node:
	_nodes_to_free.append(node)
	return node

func after_each() -> void:
	for node in _nodes_to_free:
		if is_instance_valid(node):
			node.free()
	_nodes_to_free.clear()

func test_graphics_controls_forward_to_graphics_manager() -> void:
	var manager = _track_node(FakeGraphicsManager.new())
	var panel = _track_node(OptionsPanelScript.new())
	var env = Environment.new()
	panel.call("set_graphics_manager", manager)
	panel.call("set_graphics_environment", env)

	add_child(manager)
	add_child(panel)

	panel.call("_on_graphics_quality_selected", 2)
	panel.call("_on_shadow_quality_selected", 3)
	panel.call("_on_ssr_toggled", false)
	panel.call("_on_ssao_toggled", false)
	panel.call("_on_volumetric_fog_toggled", false)
	panel.call("_on_glow_toggled", true)
	panel.call("_on_exposure_changed", 1.15)
	panel.call("_on_white_point_changed", 1.35)
	panel.call("_on_auto_quality_toggled", false)

	assert_eq(manager.selected_preset, 2)
	assert_eq(manager.shadow_quality, 3)
	assert_false(manager.ssr_enabled)
	assert_false(manager.ssao_enabled)
	assert_false(manager.fog_enabled)
	assert_true(manager.glow_enabled)
	assert_approx(manager.exposure, 1.15, 0.0001)
	assert_approx(manager.white_point, 1.35, 0.0001)
	assert_false(manager.auto_quality_enabled)
	assert_eq(manager.bound_environment, env)


func test_auto_quality_disables_manual_controls() -> void:
	var manager = _track_node(FakeGraphicsManager.new())
	manager.auto_quality_enabled = true
	var panel = _track_node(OptionsPanelScript.new())
	panel.call("set_graphics_manager", manager)
	add_child(manager)
	add_child(panel)

	panel.call("_sync_graphics_controls")
	var quality = panel.get("_quality_options") as OptionButton
	var shadow_quality = panel.get("_shadow_quality_options") as OptionButton
	assert_true(quality.disabled)
	assert_true(shadow_quality.disabled)
