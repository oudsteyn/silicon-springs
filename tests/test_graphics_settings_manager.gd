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


func test_auto_quality_mode_toggle() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	mgr.set_auto_quality_enabled(false)
	assert_false(mgr.is_auto_quality_enabled())
	mgr.set_auto_quality_enabled(true)
	assert_true(mgr.is_auto_quality_enabled())


func test_settings_round_trip_serialization() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	mgr.set_quality_preset(mgr.QualityPreset.ULTRA, false)
	mgr.set_shadow_quality(mgr.ShadowQuality.ULTRA, false)
	mgr.set_ssr_override(false, false)
	mgr.set_ssao_override(true, false)
	mgr.set_volumetric_fog_override(true, false)
	mgr.set_cinematic_grade(1.12, 1.3, true, false)
	mgr.set_auto_quality_enabled(false)

	var packed = mgr.to_serializable_dict()
	var mgr2 = _track_node(GraphicsSettingsManagerScript.new())
	mgr2.apply_serialized_settings(packed, false)
	var unpacked = mgr2.get_current_settings()

	assert_eq(int(unpacked.get("preset", -1)), int(mgr.QualityPreset.ULTRA))
	assert_eq(int(unpacked.get("shadow_quality", -1)), int(mgr.ShadowQuality.ULTRA))
	assert_false(bool(unpacked.get("ssr_enabled", true)))
	assert_true(bool(unpacked.get("ssao_enabled", false)))
	assert_true(bool(unpacked.get("volumetric_fog_enabled", false)))
	assert_false(bool(unpacked.get("auto_quality_enabled", true)))


func test_settings_save_and_load_from_disk() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var path = "user://graphics_settings_test.cfg"
	mgr.set_settings_path_for_tests(path)
	mgr.set_quality_preset(mgr.QualityPreset.MEDIUM, false)
	mgr.set_auto_quality_enabled(false)
	assert_true(mgr.save_settings_to_disk())

	var mgr2 = _track_node(GraphicsSettingsManagerScript.new())
	mgr2.set_settings_path_for_tests(path)
	assert_true(mgr2.load_settings_from_disk(false))
	var settings = mgr2.get_current_settings()
	assert_eq(int(settings.get("preset", -1)), int(mgr.QualityPreset.MEDIUM))
	assert_false(bool(settings.get("auto_quality_enabled", true)))


func test_preset_contract_validation_passes() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	assert_true(mgr.validate_preset_contract())


func test_low_preset_contract_values_are_stable() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var profile = mgr.get_preset_contract(int(mgr.QualityPreset.LOW))
	assert_false(bool(profile.get("ssr_enabled", true)))
	assert_false(bool(profile.get("ssao_enabled", true)))
	assert_false(bool(profile.get("volumetric_fog_enabled", true)))
	assert_eq(int(profile.get("shadow_quality", -1)), int(mgr.ShadowQuality.LOW))


func test_ultra_preset_boosts_ssao_power() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var env = Environment.new()

	mgr.apply_preset(env, mgr.QualityPreset.ULTRA)

	assert_approx(env.ssao_power, 1.7, 0.001)


func test_downgrading_from_ultra_resets_ssao_power() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var env = Environment.new()

	mgr.apply_preset(env, mgr.QualityPreset.ULTRA)
	mgr.apply_preset(env, mgr.QualityPreset.LOW)

	assert_approx(env.ssao_power, 1.0, 0.001)


func test_apply_serialized_settings_clamps_visual_ranges() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	mgr.apply_serialized_settings({
		"ssao_power": 99.0,
		"tonemap_exposure": -5.0,
		"tonemap_white": 99.0
	}, false)
	var settings = mgr.get_current_settings()

	assert_approx(float(settings.get("ssao_power", 0.0)), 4.0, 0.001)
	assert_approx(float(settings.get("tonemap_exposure", 0.0)), 0.4, 0.001)
	assert_approx(float(settings.get("tonemap_white", 0.0)), 2.5, 0.001)


func test_apply_serialized_settings_clamps_invalid_enum_values() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	mgr.apply_serialized_settings({
		"preset": 999,
		"shadow_quality": -99
	}, false)
	var settings = mgr.get_current_settings()

	assert_eq(int(settings.get("preset", -1)), int(mgr.QualityPreset.HIGH))
	assert_eq(int(settings.get("shadow_quality", -1)), int(mgr.ShadowQuality.HIGH))


func test_apply_terrain_atmosphere_profile_enables_fog_and_dof() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var env = Environment.new()

	var applied = mgr.apply_terrain_atmosphere_profile(env, "city_scale")

	assert_true(env.volumetric_fog_enabled)
	assert_true(bool(applied.get("dof_far_enabled", false)))
	assert_gt(float(applied.get("dof_far_distance", 0.0)), 1000.0)
