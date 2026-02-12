extends TestBase

const VisualParityCiContractScript = preload("res://src/graphics/visual_parity_ci_contract.gd")

func test_build_options_for_ci_strict_profile() -> void:
	var contract = VisualParityCiContractScript.new()
	var options = contract.build_options("ci_strict", {
		"capture_provider": null,
		"frame_baseline_dir": "user://parity_frames_ci"
	})

	assert_eq(str(options.get("mode", "")), "verify_or_record")
	assert_true(bool(options.get("strict_baseline", false)))
	assert_eq(float(options.get("quality_score_threshold", 0.0)), 75.0)
	assert_true(bool(options.get("frame_gate", {}).get("enabled", false)))
	assert_eq(str(options.get("frame_gate", {}).get("baseline_dir", "")), "user://parity_frames_ci")


func test_build_options_for_local_profile_is_permissive() -> void:
	var contract = VisualParityCiContractScript.new()
	var options = contract.build_options("local", {})

	assert_eq(str(options.get("mode", "")), "verify_or_record")
	assert_false(bool(options.get("strict_baseline", true)))
	assert_eq(float(options.get("quality_score_threshold", 0.0)), 65.0)


func test_should_fail_build_for_status() -> void:
	var contract = VisualParityCiContractScript.new()
	assert_true(contract.should_fail_build({"status": "FAIL"}, "ci_strict"))
	assert_true(contract.should_fail_build({"status": "SEED_REQUIRED"}, "ci_strict"))
	assert_false(contract.should_fail_build({"status": "PASS"}, "ci_strict"))
	assert_false(contract.should_fail_build({"status": "SEED_REQUIRED"}, "local"))
