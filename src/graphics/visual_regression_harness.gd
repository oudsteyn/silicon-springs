class_name VisualRegressionHarness
extends RefCounted

const TIMEPOINTS := {
	"dawn": 0.23,
	"noon": 0.50,
	"dusk": 0.77
}

const PRESETS := {
	"LOW": 0,
	"MEDIUM": 1,
	"HIGH": 2,
	"ULTRA": 3
}

func make_signature(settings: Dictionary, visual_state: Dictionary) -> String:
	var normalized := {
		"settings": _normalize_value(settings),
		"visual": _normalize_value(visual_state)
	}
	return JSON.stringify(normalized, "", false, true)


func compare_against_baseline(profile_id: String, current_signature: String, baseline: Dictionary) -> Dictionary:
	var expected = str(baseline.get(profile_id, ""))
	return {
		"profile_id": profile_id,
		"passed": expected != "" and expected == current_signature,
		"expected": expected,
		"actual": current_signature
	}


func generate_profile_signatures(graphics_settings_manager, daylight_controller) -> Dictionary:
	var out: Dictionary = {}
	for preset_name in PRESETS.keys():
		var preset_id = int(PRESETS[preset_name])
		var preset_profile: Dictionary = {}
		if graphics_settings_manager and graphics_settings_manager.has_method("get_preset_contract"):
			preset_profile = graphics_settings_manager.get_preset_contract(preset_id)

		for time_name in TIMEPOINTS.keys():
			var t = float(TIMEPOINTS[time_name])
			if daylight_controller and daylight_controller.has_method("set_time_normalized"):
				daylight_controller.set_time_normalized(t)
			var visual_state: Dictionary = {}
			if daylight_controller and daylight_controller.has_method("get_visual_state"):
				visual_state = daylight_controller.get_visual_state()
			var key = "%s_%s" % [preset_name, time_name]
			out[key] = make_signature(preset_profile, visual_state)
	return out


func save_baseline(path: String, baseline: Dictionary) -> bool:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(baseline, "\t", true, true))
	file.close()
	return true


func load_baseline(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	file.close()
	var data = JSON.parse_string(text)
	return data if data is Dictionary else {}


func _normalize_value(value):
	if value is float:
		return snappedf(value, 0.001)
	if value is Dictionary:
		var keys = value.keys()
		keys.sort_custom(func(a, b): return str(a) < str(b))
		var out: Dictionary = {}
		for key in keys:
			out[str(key)] = _normalize_value(value[key])
		return out
	if value is Array:
		var out_arr: Array = []
		for item in value:
			out_arr.append(_normalize_value(item))
		return out_arr
	return value
