class_name VisualParityCli
extends RefCounted

const VisualParityRunnerScript = preload("res://src/graphics/visual_parity_runner.gd")
const VisualParityCiContractScript = preload("res://src/graphics/visual_parity_ci_contract.gd")
const VisualParityHeadlessCaptureProviderScript = preload("res://src/graphics/visual_parity_headless_capture_provider.gd")

func run(args: Array, dependencies: Dictionary = {}) -> Dictionary:
	var parsed = _parse_args(args)
	var runner = dependencies.get("runner", VisualParityRunnerScript.new())
	var contract = dependencies.get("contract", VisualParityCiContractScript.new())
	var graphics_settings_manager = dependencies.get("graphics_settings_manager", null)
	var daylight_controller = dependencies.get("daylight_controller", null)
	var capture_provider = dependencies.get("capture_provider", null)
	if capture_provider == null and bool(parsed.get("auto_capture", true)):
		capture_provider = dependencies.get("default_capture_provider", VisualParityHeadlessCaptureProviderScript.new())

	var context: Dictionary = {
		"capture_provider": capture_provider,
		"frame_baseline_dir": parsed.get("frame_baseline_dir", "user://visual_parity_frames"),
		"mode": parsed.get("mode", "verify_or_record"),
		"quality_score_threshold": parsed.get("quality_score_threshold", 75.0),
		"strict_baseline_override": parsed.get("strict_baseline_override", true),
		"metadata": parsed.get("metadata", {})
	}
	var manifest = runner.execute_with_contract(
		graphics_settings_manager,
		daylight_controller,
		str(parsed.get("baseline_path", "user://visual_parity_baseline.json")),
		str(parsed.get("artifact_dir", "user://visual_parity_artifacts")),
		contract,
		str(parsed.get("profile", "ci_strict")),
		context
	)
	if bool(parsed.get("auto_seed", false)) and str(manifest.get("status", "")) == "SEED_REQUIRED":
		var verify_context = context.duplicate(true)
		verify_context["mode"] = "verify"
		manifest = runner.execute_with_contract(
			graphics_settings_manager,
			daylight_controller,
			str(parsed.get("baseline_path", "user://visual_parity_baseline.json")),
			str(parsed.get("artifact_dir", "user://visual_parity_artifacts")),
			contract,
			str(parsed.get("profile", "ci_strict")),
			verify_context
		)
	var should_fail = bool(contract.should_fail_build(manifest, str(parsed.get("profile", "ci_strict"))))
	var exit_code = int(manifest.get("exit_code", 1)) if should_fail else 0
	return {
		"exit_code": exit_code,
		"profile": parsed.get("profile", "ci_strict"),
		"manifest": manifest
	}


func _parse_args(args: Array) -> Dictionary:
	var parsed: Dictionary = {
		"profile": "ci_strict",
		"baseline_path": "user://visual_parity_baseline.json",
		"artifact_dir": "user://visual_parity_artifacts",
		"frame_baseline_dir": "user://visual_parity_frames",
		"mode": "verify_or_record",
		"quality_score_threshold": 75.0,
		"strict_baseline_override": true,
		"auto_seed": false,
		"auto_capture": true,
		"metadata": {}
	}
	for value in args:
		var arg = str(value)
		if arg.begins_with("--profile="):
			parsed["profile"] = arg.trim_prefix("--profile=")
		elif arg.begins_with("--baseline-path="):
			parsed["baseline_path"] = arg.trim_prefix("--baseline-path=")
		elif arg.begins_with("--artifact-dir="):
			parsed["artifact_dir"] = arg.trim_prefix("--artifact-dir=")
		elif arg.begins_with("--frame-baseline-dir="):
			parsed["frame_baseline_dir"] = arg.trim_prefix("--frame-baseline-dir=")
		elif arg.begins_with("--mode="):
			parsed["mode"] = arg.trim_prefix("--mode=")
		elif arg.begins_with("--quality-score-threshold="):
			parsed["quality_score_threshold"] = float(arg.trim_prefix("--quality-score-threshold="))
		elif arg.begins_with("--strict-baseline="):
			parsed["strict_baseline_override"] = _parse_bool(arg.trim_prefix("--strict-baseline="))
		elif arg.begins_with("--auto-seed="):
			parsed["auto_seed"] = _parse_bool(arg.trim_prefix("--auto-seed="))
		elif arg.begins_with("--auto-capture="):
			parsed["auto_capture"] = _parse_bool(arg.trim_prefix("--auto-capture="))
		elif arg.begins_with("--meta="):
			var kv = arg.trim_prefix("--meta=")
			var idx = kv.find("=")
			if idx > 0:
				var k = kv.substr(0, idx)
				var v = kv.substr(idx + 1)
				(parsed["metadata"] as Dictionary)[k] = v
	return parsed


func _parse_bool(value: String) -> bool:
	var normalized = value.to_lower()
	return normalized in ["1", "true", "yes", "on"]
