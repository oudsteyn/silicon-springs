extends TestBase

const VisualParityCliScript = preload("res://src/graphics/visual_parity_cli.gd")

class FakeRunner:
	var calls: Array = []
	var response: Dictionary = {"status": "PASS", "exit_code": 0}
	func execute_with_contract(graphics, daylight, baseline_path, artifact_dir, contract, profile, context):
		calls.append({
			"graphics": graphics,
			"daylight": daylight,
			"baseline_path": baseline_path,
			"artifact_dir": artifact_dir,
			"profile": profile,
			"context": context.duplicate(true)
		})
		return response.duplicate(true)

class FakeContract:
	var fail_build := false
	func should_fail_build(manifest: Dictionary, profile: String) -> bool:
		if fail_build:
			return true
		return str(manifest.get("status", "FAIL")) == "FAIL"

func test_run_uses_defaults_and_returns_success() -> void:
	var cli = VisualParityCliScript.new()
	var runner = FakeRunner.new()
	var contract = FakeContract.new()
	var output = cli.run([], {
		"runner": runner,
		"contract": contract,
		"graphics_settings_manager": {},
		"daylight_controller": {}
	})

	assert_eq(int(output.get("exit_code", 1)), 0)
	assert_eq(runner.calls.size(), 1)
	assert_eq(str(runner.calls[0]["profile"]), "ci_strict")
	assert_eq(str(runner.calls[0]["baseline_path"]), "user://visual_parity_baseline.json")
	assert_eq(str(runner.calls[0]["artifact_dir"]), "user://visual_parity_artifacts")


func test_run_parses_overrides_and_metadata() -> void:
	var cli = VisualParityCliScript.new()
	var runner = FakeRunner.new()
	var contract = FakeContract.new()
	cli.run([
		"--profile=local",
		"--baseline-path=user://b.json",
		"--artifact-dir=user://a",
		"--frame-baseline-dir=user://f",
		"--mode=verify",
		"--quality-score-threshold=88.5",
		"--strict-baseline=false",
		"--meta=git_sha=abc123",
		"--meta=build_id=ci-99"
	], {
		"runner": runner,
		"contract": contract,
		"graphics_settings_manager": {},
		"daylight_controller": {}
	})

	var call = runner.calls[0]
	assert_eq(str(call["profile"]), "local")
	assert_eq(str(call["baseline_path"]), "user://b.json")
	assert_eq(str(call["artifact_dir"]), "user://a")
	assert_eq(str(call["context"]["frame_baseline_dir"]), "user://f")
	assert_eq(str(call["context"]["mode"]), "verify")
	assert_eq(float(call["context"]["quality_score_threshold"]), 88.5)
	assert_false(bool(call["context"]["strict_baseline_override"]))
	assert_eq(str(call["context"]["metadata"]["git_sha"]), "abc123")
	assert_eq(str(call["context"]["metadata"]["build_id"]), "ci-99")


func test_run_respects_contract_build_failure_policy() -> void:
	var cli = VisualParityCliScript.new()
	var runner = FakeRunner.new()
	runner.response = {"status": "SEED_REQUIRED", "exit_code": 2}
	var contract = FakeContract.new()
	contract.fail_build = true

	var output = cli.run([], {
		"runner": runner,
		"contract": contract,
		"graphics_settings_manager": {},
		"daylight_controller": {}
	})
	assert_eq(int(output.get("exit_code", 0)), 2)
