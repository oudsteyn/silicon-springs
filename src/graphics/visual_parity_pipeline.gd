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
	var high_profile: Dictionary = {}
	if graphics_settings_manager and graphics_settings_manager.has_method("get_preset_contract"):
		high_profile = graphics_settings_manager.get_preset_contract(2)

	var profiles_by_phase := {
		"day": _make_profile_for_time(high_profile, daylight_controller, 0.50, 1.05, 1.10, 0.011, 1.0, true),
		"dusk": _make_profile_for_time(high_profile, daylight_controller, 0.77, 1.00, 1.10, 0.016, 0.45, false),
		"night": _make_profile_for_time(high_profile, daylight_controller, 0.23, 0.92, 1.00, 0.022, 0.10, false)
	}
	return acceptance_gate.evaluate_profiles_by_phase(profiles_by_phase)


func _make_profile_for_time(
	high_profile: Dictionary,
	daylight_controller,
	t: float,
	default_exposure: float,
	default_white: float,
	default_fog: float,
	default_sun: float,
	use_contract_tonemap: bool
) -> Dictionary:
	var state: Dictionary = {}
	if daylight_controller and daylight_controller.has_method("set_time_normalized"):
		daylight_controller.set_time_normalized(t)
	if daylight_controller and daylight_controller.has_method("get_visual_state"):
		state = daylight_controller.get_visual_state()
	return {
		"tonemap_exposure": float(high_profile.get("tonemap_exposure", default_exposure)) if use_contract_tonemap else default_exposure,
		"tonemap_white": float(high_profile.get("tonemap_white", default_white)) if use_contract_tonemap else default_white,
		"fog_density": float(state.get("fog_density", default_fog)),
		"sun_energy": float(state.get("sun_energy", default_sun))
	}
