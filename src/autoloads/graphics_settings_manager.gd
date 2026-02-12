extends Node

enum QualityPreset {
	LOW,
	MEDIUM,
	HIGH,
	ULTRA
}

var current_preset: QualityPreset = QualityPreset.HIGH

func apply_preset(env: Environment, preset: QualityPreset) -> void:
	if env == null:
		return

	current_preset = preset
	match preset:
		QualityPreset.LOW:
			_set_features(env, false, false, false)
		QualityPreset.MEDIUM:
			_set_features(env, true, false, true)
		QualityPreset.HIGH:
			_set_features(env, true, true, true)
		QualityPreset.ULTRA:
			_set_features(env, true, true, true)
			env.ssao_power = 1.7

func set_ssr_enabled(env: Environment, enabled: bool) -> void:
	if env:
		env.ssr_enabled = enabled

func _set_features(env: Environment, ssao_on: bool, ssr_on: bool, fog_on: bool) -> void:
	env.ssao_enabled = ssao_on
	env.ssr_enabled = ssr_on
	env.volumetric_fog_enabled = fog_on
