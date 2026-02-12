extends TestBase

const VisualGateScript = preload("res://src/graphics/visual_acceptance_gate.gd")

func test_accepts_valid_day_profile() -> void:
	var gate = VisualGateScript.new()
	var result = gate.evaluate_day_profile({
		"tonemap_exposure": 1.05,
		"tonemap_white": 1.15,
		"fog_density": 0.011,
		"sun_energy": 1.1
	})
	assert_true(bool(result.get("passed", false)))
	assert_size(result.get("issues", []), 0)

func test_rejects_out_of_range_profile() -> void:
	var gate = VisualGateScript.new()
	var result = gate.evaluate_day_profile({
		"tonemap_exposure": 2.2,
		"tonemap_white": 0.6,
		"fog_density": 0.05,
		"sun_energy": 0.2
	})
	assert_false(bool(result.get("passed", true)))
	assert_true(result.get("issues", []).size() >= 1)

func test_accepts_valid_dusk_profile() -> void:
	var gate = VisualGateScript.new()
	var result = gate.evaluate_phase_profile("dusk", {
		"tonemap_exposure": 1.0,
		"tonemap_white": 1.1,
		"fog_density": 0.016,
		"sun_energy": 0.45
	})
	assert_true(bool(result.get("passed", false)))
	assert_size(result.get("issues", []), 0)

func test_rejects_out_of_range_night_profile() -> void:
	var gate = VisualGateScript.new()
	var result = gate.evaluate_phase_profile("night", {
		"tonemap_exposure": 1.2,
		"tonemap_white": 0.8,
		"fog_density": 0.04,
		"sun_energy": 0.5
	})
	assert_false(bool(result.get("passed", true)))
	assert_true(result.get("issues", []).size() >= 1)
