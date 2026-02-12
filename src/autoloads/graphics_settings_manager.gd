extends Node

enum QualityPreset {
	LOW,
	MEDIUM,
	HIGH,
	ULTRA
}

enum ShadowQuality {
	LOW,
	MEDIUM,
	HIGH,
	ULTRA
}

signal settings_changed(settings: Dictionary)

var current_preset: QualityPreset = QualityPreset.HIGH
var current_shadow_quality: ShadowQuality = ShadowQuality.HIGH
var ssao_enabled: bool = true
var ssr_enabled: bool = true
var volumetric_fog_enabled: bool = true
var glow_enabled: bool = true
var tonemap_exposure: float = 1.0
var tonemap_white: float = 1.0

var _bound_environment: Environment = null
var _bound_sun_light: DirectionalLight3D = null

func apply_preset(env: Environment, preset: QualityPreset) -> void:
	if env == null:
		return

	_set_defaults_for_preset(preset)
	_apply_to_environment(env)
	settings_changed.emit(get_current_settings())


func bind_environment(env: Environment) -> void:
	_bound_environment = env
	apply_current_settings(env)


func bind_sun_light(sun: DirectionalLight3D) -> void:
	_bound_sun_light = sun
	apply_shadow_quality()


func set_quality_preset(preset: QualityPreset, apply_now: bool = true) -> void:
	_set_defaults_for_preset(preset)
	if apply_now:
		apply_current_settings()
	settings_changed.emit(get_current_settings())


func apply_current_settings(env: Environment = null) -> void:
	var target = env
	if target == null:
		target = _bound_environment
	if target == null:
		return
	_apply_to_environment(target)


func get_current_settings() -> Dictionary:
	return {
		"preset": int(current_preset),
		"shadow_quality": int(current_shadow_quality),
		"ssao_enabled": ssao_enabled,
		"ssr_enabled": ssr_enabled,
		"volumetric_fog_enabled": volumetric_fog_enabled,
		"glow_enabled": glow_enabled,
		"tonemap_exposure": tonemap_exposure,
		"tonemap_white": tonemap_white
	}


func set_ssr_override(enabled: bool, apply_now: bool = true) -> void:
	ssr_enabled = enabled
	if apply_now:
		apply_current_settings()
	settings_changed.emit(get_current_settings())


func set_ssao_override(enabled: bool, apply_now: bool = true) -> void:
	ssao_enabled = enabled
	if apply_now:
		apply_current_settings()
	settings_changed.emit(get_current_settings())


func set_volumetric_fog_override(enabled: bool, apply_now: bool = true) -> void:
	volumetric_fog_enabled = enabled
	if apply_now:
		apply_current_settings()
	settings_changed.emit(get_current_settings())


func set_ssao_enabled(env: Environment, enabled: bool) -> void:
	ssao_enabled = enabled
	if env:
		env.ssao_enabled = enabled
	settings_changed.emit(get_current_settings())


func set_volumetric_fog_enabled(env: Environment, enabled: bool) -> void:
	volumetric_fog_enabled = enabled
	if env:
		env.volumetric_fog_enabled = enabled
	settings_changed.emit(get_current_settings())


func set_shadow_quality(quality: ShadowQuality, apply_now: bool = true) -> void:
	current_shadow_quality = quality
	if apply_now:
		apply_shadow_quality()
	settings_changed.emit(get_current_settings())


func apply_shadow_quality(light: DirectionalLight3D = null) -> void:
	var target = light
	if target == null:
		target = _bound_sun_light
	if target == null:
		return

	match current_shadow_quality:
		ShadowQuality.LOW:
			target.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			target.directional_shadow_max_distance = 120.0
		ShadowQuality.MEDIUM:
			target.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			target.directional_shadow_max_distance = 240.0
		ShadowQuality.HIGH:
			target.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			target.directional_shadow_max_distance = 360.0
		ShadowQuality.ULTRA:
			target.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
			target.directional_shadow_max_distance = 520.0


func set_cinematic_grade(exposure: float, white_point: float, enable_glow: bool, apply_now: bool = true) -> void:
	tonemap_exposure = clampf(exposure, 0.4, 2.2)
	tonemap_white = clampf(white_point, 0.8, 2.5)
	glow_enabled = enable_glow
	if apply_now:
		apply_current_settings()
	settings_changed.emit(get_current_settings())


func _set_defaults_for_preset(preset: QualityPreset) -> void:
	current_preset = preset
	match preset:
		QualityPreset.LOW:
			ssao_enabled = false
			ssr_enabled = false
			volumetric_fog_enabled = false
			glow_enabled = false
			current_shadow_quality = ShadowQuality.LOW
			tonemap_exposure = 0.95
			tonemap_white = 1.0
		QualityPreset.MEDIUM:
			ssao_enabled = true
			ssr_enabled = false
			volumetric_fog_enabled = true
			glow_enabled = true
			current_shadow_quality = ShadowQuality.MEDIUM
			tonemap_exposure = 1.0
			tonemap_white = 1.0
		QualityPreset.HIGH:
			ssao_enabled = true
			ssr_enabled = true
			volumetric_fog_enabled = true
			glow_enabled = true
			current_shadow_quality = ShadowQuality.HIGH
			tonemap_exposure = 1.05
			tonemap_white = 1.1
		QualityPreset.ULTRA:
			ssao_enabled = true
			ssr_enabled = true
			volumetric_fog_enabled = true
			glow_enabled = true
			current_shadow_quality = ShadowQuality.ULTRA
			tonemap_exposure = 1.1
			tonemap_white = 1.2

func set_ssr_enabled(env: Environment, enabled: bool) -> void:
	ssr_enabled = enabled
	if env:
		env.ssr_enabled = enabled
	settings_changed.emit(get_current_settings())


func _apply_to_environment(env: Environment) -> void:
	_set_features(env, ssao_enabled, ssr_enabled, volumetric_fog_enabled)
	if current_preset == QualityPreset.ULTRA:
		env.ssao_power = 1.7
	env.glow_enabled = glow_enabled
	env.tonemap_exposure = tonemap_exposure
	env.tonemap_white = tonemap_white
	apply_shadow_quality()

func _set_features(env: Environment, ssao_on: bool, ssr_on: bool, fog_on: bool) -> void:
	env.ssao_enabled = ssao_on
	env.ssr_enabled = ssr_on
	env.volumetric_fog_enabled = fog_on
