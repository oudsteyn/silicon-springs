extends TestBase

const VisualParityFrameGateScript = preload("res://src/graphics/visual_parity_frame_gate.gd")

class FakeCaptureProvider:
	var frames: Dictionary = {}
	func capture_profile_frame(profile_id: String) -> Image:
		return frames.get(profile_id, null)

func _solid_image(color: Color) -> Image:
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img

var _baseline_dir := "user://visual_frame_gate_baselines"
var _profile_ids := ["HIGH_noon", "ULTRA_dusk"]

func after_each() -> void:
	if DirAccess.dir_exists_absolute(_baseline_dir):
		for profile_id in _profile_ids:
			var p = "%s/%s.png" % [_baseline_dir, profile_id]
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
		DirAccess.remove_absolute(_baseline_dir)


func test_verify_frames_detects_drift() -> void:
	var gate = VisualParityFrameGateScript.new()
	var provider = FakeCaptureProvider.new()
	provider.frames["HIGH_noon"] = _solid_image(Color.BLACK)
	provider.frames["ULTRA_dusk"] = _solid_image(Color.BLACK)

	gate.verify_frames(provider, _baseline_dir, _profile_ids, {"seed_missing": true})
	provider.frames["ULTRA_dusk"] = _solid_image(Color.WHITE)

	var result = gate.verify_frames(provider, _baseline_dir, _profile_ids, {"mse_threshold": 0.01, "max_delta_threshold": 0.05})
	assert_false(bool(result.get("passed", true)))
	assert_true(result.get("mismatches", []).size() >= 1)


func test_verify_frames_seeds_when_missing_enabled() -> void:
	var gate = VisualParityFrameGateScript.new()
	var provider = FakeCaptureProvider.new()
	provider.frames["HIGH_noon"] = _solid_image(Color(0.2, 0.2, 0.2, 1.0))
	provider.frames["ULTRA_dusk"] = _solid_image(Color(0.3, 0.3, 0.3, 1.0))

	var result = gate.verify_frames(provider, _baseline_dir, _profile_ids, {"seed_missing": true})
	assert_true(bool(result.get("passed", false)))
	assert_eq(int(result.get("seeded", 0)), 2)
	assert_true(FileAccess.file_exists("%s/HIGH_noon.png" % _baseline_dir))
