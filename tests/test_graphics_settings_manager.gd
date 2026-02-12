extends TestBase

const GraphicsSettingsManagerScript = preload("res://src/autoloads/graphics_settings_manager.gd")

var _nodes_to_free: Array[Node] = []

func _track_node(node: Node) -> Node:
	_nodes_to_free.append(node)
	return node

func after_each() -> void:
	for node in _nodes_to_free:
		if is_instance_valid(node):
			node.free()
	_nodes_to_free.clear()

func test_apply_preset_low_disables_expensive_effects() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var env = Environment.new()
	mgr.apply_preset(env, mgr.QualityPreset.LOW)

	assert_false(env.ssao_enabled)
	assert_false(env.ssr_enabled)
	assert_false(env.volumetric_fog_enabled)

func test_apply_preset_high_enables_effects() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var env = Environment.new()
	mgr.apply_preset(env, mgr.QualityPreset.HIGH)

	assert_true(env.ssao_enabled)
	assert_true(env.ssr_enabled)
	assert_true(env.volumetric_fog_enabled)

func test_set_ssr_enabled_toggles_only_ssr() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var env = Environment.new()
	env.ssao_enabled = true
	env.volumetric_fog_enabled = true

	mgr.set_ssr_enabled(env, true)
	assert_true(env.ssr_enabled)
	assert_true(env.ssao_enabled)
	assert_true(env.volumetric_fog_enabled)

	mgr.set_ssr_enabled(env, false)
	assert_false(env.ssr_enabled)


func test_bind_environment_applies_current_settings() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var env = Environment.new()
	mgr.set_quality_preset(mgr.QualityPreset.LOW, false)

	mgr.bind_environment(env)

	assert_false(env.ssao_enabled)
	assert_false(env.ssr_enabled)
	assert_false(env.volumetric_fog_enabled)


func test_quality_preset_updates_bound_environment() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var env = Environment.new()
	mgr.bind_environment(env)

	mgr.set_quality_preset(mgr.QualityPreset.MEDIUM, true)

	assert_true(env.ssao_enabled)
	assert_false(env.ssr_enabled)
	assert_true(env.volumetric_fog_enabled)


func test_runtime_overrides_update_bound_environment() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var env = Environment.new()
	mgr.bind_environment(env)

	mgr.set_ssr_override(false, true)
	mgr.set_ssao_override(false, true)
	mgr.set_volumetric_fog_override(false, true)

	assert_false(env.ssr_enabled)
	assert_false(env.ssao_enabled)
	assert_false(env.volumetric_fog_enabled)


func test_bind_sun_light_and_apply_shadow_quality() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var sun = _track_node(DirectionalLight3D.new())

	mgr.bind_sun_light(sun)
	mgr.set_shadow_quality(mgr.ShadowQuality.LOW)
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_ORTHOGONAL)
	assert_approx(float(sun.directional_shadow_max_distance), 120.0, 0.01)

	mgr.set_shadow_quality(mgr.ShadowQuality.ULTRA)
	assert_eq(sun.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS)
	assert_approx(float(sun.directional_shadow_max_distance), 520.0, 0.01)


func test_set_cinematic_grade_updates_environment_tonemap() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var env = Environment.new()
	mgr.bind_environment(env)

	mgr.set_cinematic_grade(1.25, 1.4, true)

	assert_approx(env.tonemap_exposure, 1.25, 0.001)
	assert_approx(env.tonemap_white, 1.4, 0.001)
	assert_true(env.glow_enabled)
