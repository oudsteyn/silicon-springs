extends TestBase

const GraphicsSettingsManagerScript = preload("res://src/autoloads/graphics_settings_manager.gd")

func test_apply_preset_low_disables_expensive_effects() -> void:
	var mgr = GraphicsSettingsManagerScript.new()
	var env = Environment.new()
	mgr.apply_preset(env, mgr.QualityPreset.LOW)

	assert_false(env.ssao_enabled)
	assert_false(env.ssr_enabled)
	assert_false(env.volumetric_fog_enabled)

func test_apply_preset_high_enables_effects() -> void:
	var mgr = GraphicsSettingsManagerScript.new()
	var env = Environment.new()
	mgr.apply_preset(env, mgr.QualityPreset.HIGH)

	assert_true(env.ssao_enabled)
	assert_true(env.ssr_enabled)
	assert_true(env.volumetric_fog_enabled)

func test_set_ssr_enabled_toggles_only_ssr() -> void:
	var mgr = GraphicsSettingsManagerScript.new()
	var env = Environment.new()
	env.ssao_enabled = true
	env.volumetric_fog_enabled = true

	mgr.set_ssr_enabled(env, true)
	assert_true(env.ssr_enabled)
	assert_true(env.ssao_enabled)
	assert_true(env.volumetric_fog_enabled)

	mgr.set_ssr_enabled(env, false)
	assert_false(env.ssr_enabled)
