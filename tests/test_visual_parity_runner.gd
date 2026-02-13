extends TestBase

const VisualParityRunnerScript = preload("res://src/graphics/visual_parity_runner.gd")
const VisualParityCiContractScript = preload("res://src/graphics/visual_parity_ci_contract.gd")

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


class MalformedPipeline:
	extends RefCounted
	func run_and_write_reports(_g, _d, _b, _a, _m, _o = {}) -> Dictionary:
		return {
			"passed": true,
			"quality_score": 99.0,
			"quality_score_threshold": 75.0,
			"mismatches": "invalid",
			"frame_gate": "invalid"
		}

var _baseline_path := "user://visual_parity_runner_baseline.json"
var _artifact_dir := "user://visual_parity_runner_artifacts"
var _frame_dir := "user://visual_parity_runner_frames"

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
	if DirAccess.dir_exists_absolute(_frame_dir):
		var dir = DirAccess.open(_frame_dir)
		if dir:
			dir.list_dir_begin()
			var n = dir.get_next()
			while n != "":
				if not dir.current_is_dir():
					DirAccess.remove_absolute("%s/%s" % [_frame_dir, n])
				n = dir.get_next()
			dir.list_dir_end()
		DirAccess.remove_absolute(_frame_dir)

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

func test_manifest_includes_metadata_and_artifact_hashes() -> void:
	var runner = VisualParityRunnerScript.new()
	var graphics = FakeGraphicsSettings.new()
	var daylight = FakeDaylight.new()

	runner.execute(graphics, daylight, _baseline_path, _artifact_dir, {"mode": "record"})
	var result = runner.execute(graphics, daylight, _baseline_path, _artifact_dir, {
		"metadata": {"git_sha": "abc123", "build_id": "ci-42"}
	})

	assert_eq(str(result.get("metadata", {}).get("git_sha", "")), "abc123")
	assert_eq(str(result.get("metadata", {}).get("build_id", "")), "ci-42")
	assert_eq(int(str(result.get("artifacts", {}).get("result_json_md5", "")).length()), 32)
	assert_eq(int(str(result.get("artifacts", {}).get("report_markdown_md5", "")).length()), 32)


func test_execute_strict_baseline_returns_seed_required_status() -> void:
	var runner = VisualParityRunnerScript.new()
	var graphics = FakeGraphicsSettings.new()
	var daylight = FakeDaylight.new()

	var result = runner.execute(graphics, daylight, _baseline_path, _artifact_dir, {
		"mode": "verify_or_record",
		"strict_baseline": true
	})

	assert_eq(str(result.get("status", "PASS")), "SEED_REQUIRED")
	assert_eq(int(result.get("exit_code", 0)), 2)

func test_execute_with_contract_profile_applies_policy_options() -> void:
	var runner = VisualParityRunnerScript.new()
	var contract = VisualParityCiContractScript.new()
	var graphics = FakeGraphicsSettings.new()
	var daylight = FakeDaylight.new()

	var result = runner.execute_with_contract(
		graphics,
		daylight,
		_baseline_path,
		_artifact_dir,
		contract,
		"ci_strict",
		{"frame_baseline_dir": _frame_dir}
	)

	assert_eq(str(result.get("status", "")), "SEED_REQUIRED")
	assert_eq(int(result.get("exit_code", 0)), 2)


func test_execute_tolerates_malformed_pipeline_result_shapes() -> void:
	var runner = VisualParityRunnerScript.new()
	runner.pipeline = MalformedPipeline.new()

	var result = runner.execute(FakeGraphicsSettings.new(), FakeDaylight.new(), _baseline_path, _artifact_dir)

	assert_eq(int(result.get("exit_code", 1)), 0)
	assert_eq(int(result.get("result_summary", {}).get("mismatch_count", -1)), 0)
	assert_eq(int(result.get("result_summary", {}).get("frame_gate_mismatch_count", -1)), 0)
