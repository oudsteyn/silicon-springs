class_name VisualParityRunner
extends RefCounted

const VisualParityPipelineScript = preload("res://src/graphics/visual_parity_pipeline.gd")

var pipeline = VisualParityPipelineScript.new()

func execute(
	graphics_settings_manager,
	daylight_controller,
	baseline_path: String,
	artifact_dir: String,
	options: Dictionary = {}
) -> Dictionary:
	var mode := str(options.get("mode", "verify"))
	var strict_baseline := bool(options.get("strict_baseline", false))
	var result = pipeline.run_and_write_reports(
		graphics_settings_manager,
		daylight_controller,
		baseline_path,
		artifact_dir,
		mode,
		options
	)
	var passed := bool(result.get("passed", false))
	var seeded_baseline := bool(result.get("seeded_baseline", false))
	var status := "PASS" if passed else "FAIL"
	var exit_code := 0 if passed else 1
	if strict_baseline and seeded_baseline:
		status = "SEED_REQUIRED"
		exit_code = 2

	var metadata := _build_metadata(options)
	var report_path = "%s/visual_parity_report.md" % artifact_dir
	var result_path = "%s/visual_parity_result.json" % artifact_dir
	var manifest = {
		"status": status,
		"exit_code": exit_code,
		"mode": mode,
		"quality_score": float(result.get("quality_score", 0.0)),
		"quality_score_threshold": float(result.get("quality_score_threshold", 0.0)),
		"metadata": metadata,
		"artifacts": {
			"report_markdown": report_path,
			"result_json": result_path,
			"report_markdown_md5": FileAccess.get_md5(report_path),
			"result_json_md5": FileAccess.get_md5(result_path)
		},
		"result_summary": {
			"mismatch_count": (result.get("mismatches", []) as Array).size(),
			"frame_gate_mismatch_count": (result.get("frame_gate", {}).get("mismatches", []) as Array).size(),
			"seeded_baseline": seeded_baseline
		}
	}
	_write_manifest("%s/visual_parity_manifest.json" % artifact_dir, manifest)
	return manifest


func _write_manifest(path: String, payload: Dictionary) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t", true, true))
	file.close()
	return true


func _build_metadata(options: Dictionary) -> Dictionary:
	var md = {
		"engine_version": Engine.get_version_info().get("string", ""),
		"platform": OS.get_name(),
		"unix_time": Time.get_unix_time_from_system()
	}
	var overrides = options.get("metadata", {})
	if overrides is Dictionary:
		for key in overrides.keys():
			md[key] = overrides[key]
	return md


func execute_with_contract(
	graphics_settings_manager,
	daylight_controller,
	baseline_path: String,
	artifact_dir: String,
	contract,
	profile: String,
	context: Dictionary = {}
) -> Dictionary:
	if contract == null or not contract.has_method("build_options"):
		return execute(graphics_settings_manager, daylight_controller, baseline_path, artifact_dir, {})
	var options = contract.build_options(profile, context)
	return execute(graphics_settings_manager, daylight_controller, baseline_path, artifact_dir, options)
