class_name VisualAcceptanceGate
extends RefCounted

const DAY_TARGETS := {
	"tonemap_exposure": Vector2(1.00, 1.15),
	"tonemap_white": Vector2(1.05, 1.30),
	"fog_density": Vector2(0.008, 0.014),
	"sun_energy": Vector2(0.95, 1.35)
}

func evaluate_day_profile(profile: Dictionary) -> Dictionary:
	return _evaluate_profile(profile, DAY_TARGETS)

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
