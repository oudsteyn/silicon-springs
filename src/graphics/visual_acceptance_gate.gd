class_name VisualAcceptanceGate
extends RefCounted

const DAY_TARGETS := {
	"tonemap_exposure": Vector2(1.00, 1.15),
	"tonemap_white": Vector2(1.05, 1.30),
	"fog_density": Vector2(0.008, 0.014),
	"sun_energy": Vector2(0.95, 1.35)
}

const DUSK_TARGETS := {
	"tonemap_exposure": Vector2(0.95, 1.10),
	"tonemap_white": Vector2(1.00, 1.20),
	"fog_density": Vector2(0.012, 0.022),
	"sun_energy": Vector2(0.28, 0.75)
}

const NIGHT_TARGETS := {
	"tonemap_exposure": Vector2(0.85, 1.00),
	"tonemap_white": Vector2(0.95, 1.15),
	"fog_density": Vector2(0.018, 0.030),
	"sun_energy": Vector2(0.02, 0.20)
}

func evaluate_day_profile(profile: Dictionary) -> Dictionary:
	return _evaluate_profile(profile, DAY_TARGETS)

func evaluate_phase_profile(phase: String, profile: Dictionary) -> Dictionary:
	var targets = _get_targets_for_phase(phase)
	if targets.is_empty():
		return {
			"passed": false,
			"issues": ["Unknown phase: %s" % phase]
		}
	return _evaluate_profile(profile, targets)

func evaluate_profiles_by_phase(profiles: Dictionary) -> Dictionary:
	var by_phase: Dictionary = {}
	var overall_passed := true
	for phase in ["day", "dusk", "night"]:
		var result = evaluate_phase_profile(phase, profiles.get(phase, {}))
		by_phase[phase] = result
		if not bool(result.get("passed", false)):
			overall_passed = false
	return {
		"passed": overall_passed,
		"by_phase": by_phase
	}

func _get_targets_for_phase(phase: String) -> Dictionary:
	match phase.to_lower():
		"day":
			return DAY_TARGETS
		"dusk":
			return DUSK_TARGETS
		"night":
			return NIGHT_TARGETS
	return {}

func _evaluate_profile(profile: Dictionary, targets: Dictionary) -> Dictionary:
	var issues: Array[String] = []
	for key in targets.keys():
		var range: Vector2 = targets[key]
		var value = float(profile.get(key, INF))
		if value < range.x or value > range.y:
			issues.append("%s out of range: %.3f not in [%.3f, %.3f]" % [key, value, range.x, range.y])
	return {
		"passed": issues.is_empty(),
		"issues": issues
	}
