class_name VisualParityPipeline
extends RefCounted

const VisualRegressionHarnessScript = preload("res://src/graphics/visual_regression_harness.gd")
const VisualAcceptanceGateScript = preload("res://src/graphics/visual_acceptance_gate.gd")

var harness = VisualRegressionHarnessScript.new()
var acceptance_gate = VisualAcceptanceGateScript.new()

func run(graphics_settings_manager, daylight_controller, baseline_path: String, mode: String = "verify") -> Dictionary:
	var signatures = harness.generate_profile_signatures(graphics_settings_manager, daylight_controller)
	if mode == "record":
		var ok = harness.save_baseline(baseline_path, signatures)
		return {
			"passed": ok,
			"mode": mode,
			"baseline_path": baseline_path,
			"profile_count": signatures.size(),
			"mismatches": []
		}

	var baseline = harness.load_baseline(baseline_path)
	if baseline.is_empty():
		return {
			"passed": false,
			"mode": mode,
			"baseline_path": baseline_path,
			"profile_count": signatures.size(),
			"mismatches": ["Baseline missing or empty"]
		}

	var mismatches: Array = []
	for key in signatures.keys():
		var cmp = harness.compare_against_baseline(str(key), str(signatures[key]), baseline)
		if not bool(cmp.get("passed", false)):
			mismatches.append(cmp)

	var acceptance = _evaluate_day_acceptance(graphics_settings_manager, daylight_controller)
	return {
		"passed": mismatches.is_empty() and bool(acceptance.get("passed", false)),
		"mode": mode,
		"baseline_path": baseline_path,
		"profile_count": signatures.size(),
		"mismatches": mismatches,
		"acceptance": acceptance
	}


func _evaluate_day_acceptance(graphics_settings_manager, daylight_controller) -> Dictionary:
	var noon_state: Dictionary = {}
	if daylight_controller and daylight_controller.has_method("set_time_normalized"):
		daylight_controller.set_time_normalized(0.5)
	if daylight_controller and daylight_controller.has_method("get_visual_state"):
		noon_state = daylight_controller.get_visual_state()

	var high_profile: Dictionary = {}
	if graphics_settings_manager and graphics_settings_manager.has_method("get_preset_contract"):
		high_profile = graphics_settings_manager.get_preset_contract(2)

	var profile = {
		"tonemap_exposure": float(high_profile.get("tonemap_exposure", 1.05)),
		"tonemap_white": float(high_profile.get("tonemap_white", 1.1)),
		"fog_density": float(noon_state.get("fog_density", 0.011)),
		"sun_energy": float(noon_state.get("sun_energy", 1.0))
	}
	return acceptance_gate.evaluate_day_profile(profile)
