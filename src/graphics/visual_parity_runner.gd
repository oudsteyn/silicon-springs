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
	var result = pipeline.run_and_write_reports(
		graphics_settings_manager,
		daylight_controller,
		baseline_path,
		artifact_dir,
		mode,
		options
	)
	var passed := bool(result.get("passed", false))
	var exit_code := 0 if passed else 1
	var manifest = {
		"status": "PASS" if passed else "FAIL",
		"exit_code": exit_code,
		"mode": mode,
		"quality_score": float(result.get("quality_score", 0.0)),
		"quality_score_threshold": float(result.get("quality_score_threshold", 0.0)),
		"artifacts": {
			"report_markdown": "%s/visual_parity_report.md" % artifact_dir,
			"result_json": "%s/visual_parity_result.json" % artifact_dir
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
