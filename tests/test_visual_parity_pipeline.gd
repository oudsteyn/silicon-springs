extends TestBase

const VisualParityPipelineScript = preload("res://src/graphics/visual_parity_pipeline.gd")

class FakeGraphicsSettings:
	enum QualityPreset { LOW, MEDIUM, HIGH, ULTRA }
	var _contracts := {
		0: {"ssr_enabled": false, "ssao_enabled": false, "shadow_quality": 0, "tonemap_exposure": 1.0, "tonemap_white": 1.1},
		1: {"ssr_enabled": false, "ssao_enabled": true, "shadow_quality": 1, "tonemap_exposure": 1.0, "tonemap_white": 1.1},
		2: {"ssr_enabled": true, "ssao_enabled": true, "shadow_quality": 2, "tonemap_exposure": 1.05, "tonemap_white": 1.1},
		3: {"ssr_enabled": true, "ssao_enabled": true, "shadow_quality": 3, "tonemap_exposure": 1.1, "tonemap_white": 1.2}
	}
	func get_preset_contract(preset: int) -> Dictionary:
		return (_contracts.get(preset, {}) as Dictionary).duplicate(true)
	func set_contract(preset: int, profile: Dictionary) -> void:
		_contracts[preset] = profile.duplicate(true)

class FakeDaylight:
	var _t := 0.5
	func set_time_normalized(v: float) -> void:
		_t = v
	func get_visual_state() -> Dictionary:
		return {
			"day_factor": _t,
			"sun_energy": 1.0 if _t > 0.3 and _t < 0.7 else 0.15,
			"fog_density": 0.011 if _t > 0.3 and _t < 0.7 else 0.02
		}

var _baseline_path := "user://visual_parity_pipeline_test.json"

func after_each() -> void:
	if FileAccess.file_exists(_baseline_path):
		DirAccess.remove_absolute(_baseline_path)

func test_record_then_verify_pipeline_passes() -> void:
	var pipeline = VisualParityPipelineScript.new()
	var graphics = FakeGraphicsSettings.new()
	var daylight = FakeDaylight.new()

	var recorded = pipeline.run(graphics, daylight, _baseline_path, "record")
	assert_true(bool(recorded.get("passed", false)))

	var verified = pipeline.run(graphics, daylight, _baseline_path, "verify")
	assert_true(bool(verified.get("passed", false)))
	assert_size(verified.get("mismatches", []), 0)

func test_verify_detects_signature_drift() -> void:
	var pipeline = VisualParityPipelineScript.new()
	var graphics = FakeGraphicsSettings.new()
	var daylight = FakeDaylight.new()
	pipeline.run(graphics, daylight, _baseline_path, "record")

	graphics.set_contract(graphics.QualityPreset.ULTRA, {"ssr_enabled": false, "ssao_enabled": false, "shadow_quality": 0, "tonemap_exposure": 0.9, "tonemap_white": 0.9})
	var verified = pipeline.run(graphics, daylight, _baseline_path, "verify")

	assert_false(bool(verified.get("passed", true)))
	assert_true(verified.get("mismatches", []).size() >= 1)

func test_verify_fails_acceptance_gate_for_bad_day_profile() -> void:
	var pipeline = VisualParityPipelineScript.new()
	var graphics = FakeGraphicsSettings.new()
	var daylight = FakeDaylight.new()
	pipeline.run(graphics, daylight, _baseline_path, "record")

	graphics.set_contract(graphics.QualityPreset.HIGH, {"ssr_enabled": true, "ssao_enabled": true, "shadow_quality": 2, "tonemap_exposure": 2.0, "tonemap_white": 0.7})
	var verified = pipeline.run(graphics, daylight, _baseline_path, "verify")
	assert_false(bool(verified.get("passed", true)))
	assert_true(verified.has("acceptance"))
	assert_false(bool(verified.get("acceptance", {}).get("passed", true)))
