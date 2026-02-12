extends TestBase

const VisualParityRunnerScript = preload("res://src/graphics/visual_parity_runner.gd")

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

class FakeDaylight:
	var _t := 0.5
	func set_time_normalized(v: float) -> void:
		_t = v
	func get_visual_state() -> Dictionary:
		if _t >= 0.75:
			return {"sun_energy": 0.35, "fog_density": 0.018}
		if _t <= 0.25:
			return {"sun_energy": 0.10, "fog_density": 0.022}
		return {"sun_energy": 1.0, "fog_density": 0.011}

var _baseline_path := "user://visual_parity_runner_baseline.json"
var _artifact_dir := "user://visual_parity_runner_artifacts"

func after_each() -> void:
	if FileAccess.file_exists(_baseline_path):
		DirAccess.remove_absolute(_baseline_path)
	for path in [
		"%s/visual_parity_result.json" % _artifact_dir,
		"%s/visual_parity_report.md" % _artifact_dir,
		"%s/visual_parity_manifest.json" % _artifact_dir,
		_artifact_dir
	]:
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			DirAccess.remove_absolute(path)

func test_execute_success_returns_zero_and_writes_manifest() -> void:
	var runner = VisualParityRunnerScript.new()
	var graphics = FakeGraphicsSettings.new()
	var daylight = FakeDaylight.new()

	runner.execute(graphics, daylight, _baseline_path, _artifact_dir, {"mode": "record"})
	var result = runner.execute(graphics, daylight, _baseline_path, _artifact_dir)

	assert_eq(int(result.get("exit_code", 1)), 0)
	assert_true(FileAccess.file_exists("%s/visual_parity_manifest.json" % _artifact_dir))

	var f = FileAccess.open("%s/visual_parity_manifest.json" % _artifact_dir, FileAccess.READ)
	assert_not_null(f)
	var payload = JSON.parse_string(f.get_as_text())
	f.close()
	assert_true(payload is Dictionary)
	assert_eq(str(payload.get("status", "")), "PASS")
	assert_true(payload.get("artifacts", {}).has("report_markdown"))
	assert_true(payload.get("artifacts", {}).has("result_json"))

func test_execute_failure_returns_nonzero_when_threshold_fails() -> void:
	var runner = VisualParityRunnerScript.new()
	var graphics = FakeGraphicsSettings.new()
	var daylight = FakeDaylight.new()

	runner.execute(graphics, daylight, _baseline_path, _artifact_dir, {"mode": "record"})
	var result = runner.execute(graphics, daylight, _baseline_path, _artifact_dir, {"quality_score_threshold": 95.0})

	assert_eq(int(result.get("exit_code", 0)), 1)
	assert_eq(str(result.get("status", "PASS")), "FAIL")
