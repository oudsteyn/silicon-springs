class_name VisualParityCiContract
extends RefCounted

func build_options(profile: String, context: Dictionary = {}) -> Dictionary:
	var frame_baseline_dir = str(context.get("frame_baseline_dir", "user://visual_parity_frames"))
	var capture_provider = context.get("capture_provider", null)
	var mode = str(context.get("mode", "verify_or_record"))
	var quality_score_threshold = float(context.get("quality_score_threshold", 75.0))
	var strict_baseline_override = bool(context.get("strict_baseline_override", true))
	var metadata = context.get("metadata", {})
	match profile:
		"ci_strict":
			var options = {
				"mode": mode,
				"strict_baseline": strict_baseline_override,
				"quality_score_threshold": quality_score_threshold,
				"frame_gate": {
					"enabled": true,
					"seed_missing": true,
					"baseline_dir": frame_baseline_dir,
					"capture_provider": capture_provider,
					"mse_threshold": 0.001,
					"max_delta_threshold": 0.06
				}
			}
			if metadata is Dictionary and not metadata.is_empty():
				options["metadata"] = metadata
			return options
		_:
			var local_options = {
				"mode": str(context.get("mode", "verify_or_record")),
				"strict_baseline": bool(context.get("strict_baseline_override", false)),
				"quality_score_threshold": float(context.get("quality_score_threshold", 65.0)),
				"frame_gate": {
					"enabled": false
				}
			}
			if metadata is Dictionary and not metadata.is_empty():
				local_options["metadata"] = metadata
			return local_options


func should_fail_build(manifest: Dictionary, profile: String) -> bool:
	var status = str(manifest.get("status", "FAIL"))
	if profile == "ci_strict":
		return status != "PASS"
	return status == "FAIL"
