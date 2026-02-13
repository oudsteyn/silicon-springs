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
var ssao_power: float = 1.0
var tonemap_exposure: float = 1.0
var tonemap_white: float = 1.0
var auto_quality_enabled: bool = true

var _bound_environment: Environment = null
var _bound_sun_light: DirectionalLight3D = null
var _settings_path: String = "user://graphics_settings.cfg"
var _preset_contracts: Dictionary = {}


func _ready() -> void:
	_build_preset_contracts()
	load_settings_from_disk(false)

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
			"ssao_power": ssao_power,
			"tonemap_exposure": tonemap_exposure,
			"tonemap_white": tonemap_white,
			"auto_quality_enabled": auto_quality_enabled
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


func set_auto_quality_enabled(enabled: bool) -> void:
	auto_quality_enabled = enabled
	settings_changed.emit(get_current_settings())


func is_auto_quality_enabled() -> bool:
	return auto_quality_enabled


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


func to_serializable_dict() -> Dictionary:
	return get_current_settings().duplicate(true)


func apply_serialized_settings(data: Dictionary, apply_now: bool = true) -> void:
	current_preset = _sanitize_preset(int(data.get("preset", int(current_preset))))
	current_shadow_quality = _sanitize_shadow_quality(int(data.get("shadow_quality", int(current_shadow_quality))))
	ssao_enabled = bool(data.get("ssao_enabled", ssao_enabled))
	ssr_enabled = bool(data.get("ssr_enabled", ssr_enabled))
	volumetric_fog_enabled = bool(data.get("volumetric_fog_enabled", volumetric_fog_enabled))
	glow_enabled = bool(data.get("glow_enabled", glow_enabled))
	ssao_power = clampf(float(data.get("ssao_power", ssao_power)), 0.1, 4.0)
	tonemap_exposure = clampf(float(data.get("tonemap_exposure", tonemap_exposure)), 0.4, 2.2)
	tonemap_white = clampf(float(data.get("tonemap_white", tonemap_white)), 0.8, 2.5)
	auto_quality_enabled = bool(data.get("auto_quality_enabled", auto_quality_enabled))

	if apply_now:
		apply_current_settings()
		apply_shadow_quality()
	settings_changed.emit(get_current_settings())


func _sanitize_preset(value: int) -> QualityPreset:
	if value < int(QualityPreset.LOW) or value > int(QualityPreset.ULTRA):
		return QualityPreset.HIGH
	return value as QualityPreset


func _sanitize_shadow_quality(value: int) -> ShadowQuality:
	if value < int(ShadowQuality.LOW) or value > int(ShadowQuality.ULTRA):
		return ShadowQuality.HIGH
	return value as ShadowQuality


func set_settings_path_for_tests(path: String) -> void:
	if path != "":
		_settings_path = path


func save_settings_to_disk() -> bool:
	var config = ConfigFile.new()
	config.set_value("graphics", "settings", to_serializable_dict())
	return config.save(_settings_path) == OK


func load_settings_from_disk(apply_now: bool = true) -> bool:
	var config = ConfigFile.new()
	var err = config.load(_settings_path)
	if err != OK:
		return false
	var data = config.get_value("graphics", "settings", {}) as Dictionary
	apply_serialized_settings(data, apply_now)
	return true


func _set_defaults_for_preset(preset: QualityPreset) -> void:
	if _preset_contracts.is_empty():
		_build_preset_contracts()
	var contract: Dictionary = _preset_contracts.get(int(preset), {})
	if not contract.is_empty():
		current_preset = preset
		current_shadow_quality = int(contract.get("shadow_quality", int(current_shadow_quality)))
		ssao_enabled = bool(contract.get("ssao_enabled", ssao_enabled))
		ssr_enabled = bool(contract.get("ssr_enabled", ssr_enabled))
		volumetric_fog_enabled = bool(contract.get("volumetric_fog_enabled", volumetric_fog_enabled))
		glow_enabled = bool(contract.get("glow_enabled", glow_enabled))
		ssao_power = float(contract.get("ssao_power", ssao_power))
		tonemap_exposure = float(contract.get("tonemap_exposure", tonemap_exposure))
		tonemap_white = float(contract.get("tonemap_white", tonemap_white))
		return

	current_preset = preset
	match preset:
		QualityPreset.LOW:
			ssao_enabled = false
			ssr_enabled = false
			volumetric_fog_enabled = false
			glow_enabled = false
			ssao_power = 1.0
			current_shadow_quality = ShadowQuality.LOW
			tonemap_exposure = 0.95
			tonemap_white = 1.0
		QualityPreset.MEDIUM:
			ssao_enabled = true
			ssr_enabled = false
			volumetric_fog_enabled = true
			glow_enabled = true
			ssao_power = 1.2
			current_shadow_quality = ShadowQuality.MEDIUM
			tonemap_exposure = 1.0
			tonemap_white = 1.0
		QualityPreset.HIGH:
			ssao_enabled = true
			ssr_enabled = true
			volumetric_fog_enabled = true
			glow_enabled = true
			ssao_power = 1.4
			current_shadow_quality = ShadowQuality.HIGH
			tonemap_exposure = 1.05
			tonemap_white = 1.1
		QualityPreset.ULTRA:
			ssao_enabled = true
			ssr_enabled = true
			volumetric_fog_enabled = true
			glow_enabled = true
			ssao_power = 1.7
			current_shadow_quality = ShadowQuality.ULTRA
			tonemap_exposure = 1.1
			tonemap_white = 1.2


func get_preset_contract(preset: int) -> Dictionary:
	if _preset_contracts.is_empty():
		_build_preset_contracts()
	return (_preset_contracts.get(preset, {}) as Dictionary).duplicate(true)


func validate_preset_contract() -> bool:
	if _preset_contracts.is_empty():
		_build_preset_contracts()
	for key in [int(QualityPreset.LOW), int(QualityPreset.MEDIUM), int(QualityPreset.HIGH), int(QualityPreset.ULTRA)]:
		var profile = _preset_contracts.get(key, {})
		if profile.is_empty():
			return false
		for required in [
			"shadow_quality",
			"ssao_enabled",
			"ssr_enabled",
				"volumetric_fog_enabled",
				"glow_enabled",
				"ssao_power",
				"tonemap_exposure",
				"tonemap_white"
			]:
			if not profile.has(required):
				return false
	return true


func _build_preset_contracts() -> void:
	_preset_contracts = {
		int(QualityPreset.LOW): {
			"shadow_quality": int(ShadowQuality.LOW),
			"ssao_enabled": false,
				"ssr_enabled": false,
				"volumetric_fog_enabled": false,
				"glow_enabled": false,
				"ssao_power": 1.0,
				"tonemap_exposure": 0.95,
				"tonemap_white": 1.0
			},
		int(QualityPreset.MEDIUM): {
			"shadow_quality": int(ShadowQuality.MEDIUM),
			"ssao_enabled": true,
				"ssr_enabled": false,
				"volumetric_fog_enabled": true,
				"glow_enabled": true,
				"ssao_power": 1.2,
				"tonemap_exposure": 1.0,
				"tonemap_white": 1.0
			},
		int(QualityPreset.HIGH): {
			"shadow_quality": int(ShadowQuality.HIGH),
			"ssao_enabled": true,
				"ssr_enabled": true,
				"volumetric_fog_enabled": true,
				"glow_enabled": true,
				"ssao_power": 1.4,
				"tonemap_exposure": 1.05,
				"tonemap_white": 1.1
			},
		int(QualityPreset.ULTRA): {
			"shadow_quality": int(ShadowQuality.ULTRA),
			"ssao_enabled": true,
				"ssr_enabled": true,
				"volumetric_fog_enabled": true,
				"glow_enabled": true,
				"ssao_power": 1.7,
				"tonemap_exposure": 1.1,
				"tonemap_white": 1.2
			}
		}

func set_ssr_enabled(env: Environment, enabled: bool) -> void:
	ssr_enabled = enabled
	if env:
		env.ssr_enabled = enabled
	settings_changed.emit(get_current_settings())


func _apply_to_environment(env: Environment) -> void:
	_set_features(env, ssao_enabled, ssr_enabled, volumetric_fog_enabled)
	env.ssao_power = ssao_power
	env.glow_enabled = glow_enabled
	env.tonemap_exposure = tonemap_exposure
	env.tonemap_white = tonemap_white
	apply_shadow_quality()

func _set_features(env: Environment, ssao_on: bool, ssr_on: bool, fog_on: bool) -> void:
	env.ssao_enabled = ssao_on
	env.ssr_enabled = ssr_on
	env.volumetric_fog_enabled = fog_on
