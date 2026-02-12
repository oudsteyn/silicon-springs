class_name VisualParityCiContract
extends RefCounted

func build_options(profile: String, context: Dictionary = {}) -> Dictionary:
	var frame_baseline_dir = str(context.get("frame_baseline_dir", "user://visual_parity_frames"))
	var capture_provider = context.get("capture_provider", null)
	match profile:
		"ci_strict":
			return {
				"mode": "verify_or_record",
				"strict_baseline": true,
				"quality_score_threshold": 75.0,
				"frame_gate": {
					"enabled": true,
					"seed_missing": true,
					"baseline_dir": frame_baseline_dir,
					"capture_provider": capture_provider,
					"mse_threshold": 0.001,
					"max_delta_threshold": 0.06
				}
			}
		_:
			return {
				"mode": "verify_or_record",
				"strict_baseline": false,
				"quality_score_threshold": 65.0,
				"frame_gate": {
					"enabled": false
				}
			}


func should_fail_build(manifest: Dictionary, profile: String) -> bool:
	var status = str(manifest.get("status", "FAIL"))
	if profile == "ci_strict":
		return status != "PASS"
	return status == "FAIL"
