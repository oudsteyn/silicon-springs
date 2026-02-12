class_name VisualParityFrameGate
extends RefCounted

const VisualImageDiffScript = preload("res://src/graphics/visual_image_diff.gd")

var image_diff = VisualImageDiffScript.new()

func verify_frames(capture_provider, baseline_dir: String, profile_ids: Array, options: Dictionary = {}) -> Dictionary:
	var seed_missing := bool(options.get("seed_missing", false))
	var mse_threshold: float = float(options.get("mse_threshold", 0.001))
	var max_delta_threshold: float = float(options.get("max_delta_threshold", 0.08))
	var mismatches: Array = []
	var seeded := 0
	var compared := 0

	for profile_id_value in profile_ids:
		var profile_id = str(profile_id_value)
		var actual = _capture_image(capture_provider, profile_id)
		if actual == null:
			mismatches.append({"profile_id": profile_id, "reason": "capture_missing"})
			continue

		var baseline_path = "%s/%s.png" % [baseline_dir, profile_id]
		var expected = image_diff.load_png(baseline_path)
		if expected == null:
			if seed_missing and image_diff.save_png(baseline_path, actual):
				seeded += 1
				continue
			mismatches.append({"profile_id": profile_id, "reason": "baseline_missing"})
			continue

		var diff = image_diff.compare_images(expected, actual, {
			"mse_threshold": mse_threshold,
			"max_delta_threshold": max_delta_threshold
		})
		compared += 1
		if not bool(diff.get("passed", false)):
			diff["profile_id"] = profile_id
			mismatches.append(diff)

	return {
		"passed": mismatches.is_empty(),
		"seeded": seeded,
		"compared": compared,
		"mismatches": mismatches
	}


func _capture_image(capture_provider, profile_id: String) -> Image:
	if capture_provider == null:
		return null
	if not capture_provider.has_method("capture_profile_frame"):
		return null
	var captured = capture_provider.capture_profile_frame(profile_id)
	return captured if captured is Image else null
