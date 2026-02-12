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
	var dusk_sun_energy := 0.35
	var dusk_fog_density := 0.018
	func set_time_normalized(v: float) -> void:
		_t = v
	func get_visual_state() -> Dictionary:
		if _t >= 0.75:
			return {
				"day_factor": _t,
				"sun_energy": dusk_sun_energy,
				"fog_density": dusk_fog_density
			}
		if _t <= 0.25:
			return {
				"day_factor": _t,
				"sun_energy": 0.1,
				"fog_density": 0.022
			}
		return {
			"day_factor": _t,
			"sun_energy": 1.0 if _t > 0.3 and _t < 0.7 else 0.15,
			"fog_density": 0.011 if _t > 0.3 and _t < 0.7 else 0.02
		}

var _baseline_path := "user://visual_parity_pipeline_test.json"
var _report_dir := "user://visual_parity_reports_test"

func after_each() -> void:
	if FileAccess.file_exists(_baseline_path):
		DirAccess.remove_absolute(_baseline_path)
	if DirAccess.dir_exists_absolute(_report_dir):
		DirAccess.remove_absolute("%s/visual_parity_result.json" % _report_dir)
		DirAccess.remove_absolute("%s/visual_parity_report.md" % _report_dir)
		DirAccess.remove_absolute(_report_dir)

func test_record_then_verify_pipeline_passes() -> void:
	var pipeline = VisualParityPipelineScript.new()
	var graphics = FakeGraphicsSettings.new()
	var daylight = FakeDaylight.new()

	var recorded = pipeline.run(graphics, daylight, _baseline_path, "record")
	assert_true(bool(recorded.get("passed", false)))

	var verified = pipeline.run(graphics, daylight, _baseline_path, "verify")
	assert_true(bool(verified.get("passed", false)))
	assert_size(verified.get("mismatches", []), 0)
	assert_true(bool(verified.get("acceptance", {}).get("passed", false)))
	assert_true(verified.get("acceptance", {}).has("by_phase"))

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

func test_verify_fails_when_dusk_profile_is_out_of_range() -> void:
	var pipeline = VisualParityPipelineScript.new()
	var graphics = FakeGraphicsSettings.new()
	var daylight = FakeDaylight.new()
	pipeline.run(graphics, daylight, _baseline_path, "record")

	daylight.dusk_sun_energy = 0.9
	var verified = pipeline.run(graphics, daylight, _baseline_path, "verify")

	assert_false(bool(verified.get("passed", true)))
	assert_false(bool(verified.get("acceptance", {}).get("passed", true)))
	var by_phase = verified.get("acceptance", {}).get("by_phase", {})
	assert_true(by_phase.has("dusk"))
	assert_false(bool(by_phase.get("dusk", {}).get("passed", true)))

func test_verify_or_record_seeds_missing_baseline() -> void:
	var pipeline = VisualParityPipelineScript.new()
	var graphics = FakeGraphicsSettings.new()
	var daylight = FakeDaylight.new()

	var result = pipeline.run(graphics, daylight, _baseline_path, "verify_or_record")
	assert_true(bool(result.get("passed", false)))
	assert_true(bool(result.get("seeded_baseline", false)))
	assert_true(FileAccess.file_exists(_baseline_path))

func test_run_and_write_reports_outputs_markdown_and_json() -> void:
	var pipeline = VisualParityPipelineScript.new()
	var graphics = FakeGraphicsSettings.new()
	var daylight = FakeDaylight.new()
	pipeline.run(graphics, daylight, _baseline_path, "record")

	var result = pipeline.run_and_write_reports(graphics, daylight, _baseline_path, _report_dir, "verify")
	assert_true(bool(result.get("passed", false)))
	assert_true(FileAccess.file_exists("%s/visual_parity_result.json" % _report_dir))
	assert_true(FileAccess.file_exists("%s/visual_parity_report.md" % _report_dir))

func test_verify_fails_when_quality_score_below_threshold() -> void:
	var pipeline = VisualParityPipelineScript.new()
	var graphics = FakeGraphicsSettings.new()
	var daylight = FakeDaylight.new()
	pipeline.run(graphics, daylight, _baseline_path, "record")

	var result = pipeline.run(graphics, daylight, _baseline_path, "verify", {"quality_score_threshold": 95.0})
	assert_false(bool(result.get("passed", true)))
	assert_true(result.has("quality_score_threshold"))
	assert_true(float(result.get("quality_score", 0.0)) < 95.0)
