extends Node3D

@export var sun: DirectionalLight3D
@export var day_seconds: float = 1200.0
@export var latitude_tilt_deg: float = 35.0
@export var min_sun_energy: float = 0.02
@export var max_sun_energy: float = 1.2
@export var day_fog_density: float = 0.010
@export var night_fog_density: float = 0.024

var _t: float = 0.25
var _last_visual_state: Dictionary = {}

func _process(delta: float) -> void:
	if sun == null or day_seconds <= 0.0:
		return

	_t = fmod(_t + delta / day_seconds, 1.0)
	_update_sun()

func _update_sun() -> void:
	var state = _compute_visual_state_for_time(_t)
	var sun_angle = (float(state.get("time", _t)) * TAU) - PI * 0.5
	var elevation = float(state.get("elevation", sin(sun_angle)))
	var azimuth = _t * TAU

	sun.rotation = Vector3(deg_to_rad(latitude_tilt_deg), azimuth, 0.0)
	sun.rotate_x(-asin(clampf(elevation, -1.0, 1.0)))

	sun.light_energy = float(state.get("sun_energy", min_sun_energy))
	sun.light_temperature = float(state.get("sun_temperature", 6500.0))
	sun.shadow_enabled = bool(state.get("shadow_enabled", true))
	_last_visual_state = state


func set_time_normalized(normalized_time: float) -> void:
	_t = clampf(normalized_time, 0.0, 1.0)
	if sun:
		_update_sun()
	else:
		_last_visual_state = _compute_visual_state_for_time(_t)


func get_visual_state() -> Dictionary:
	if _last_visual_state.is_empty():
		_last_visual_state = _compute_visual_state_for_time(_t)
	return _last_visual_state.duplicate(true)


func _compute_visual_state_for_time(normalized_time: float) -> Dictionary:
	var t = clampf(normalized_time, 0.0, 1.0)
	var sun_angle = (t * TAU) - PI * 0.5
	var elevation = sin(sun_angle)
	var day_factor = _smooth_day_factor(elevation)
	var sun_energy = lerpf(min_sun_energy, max_sun_energy, day_factor)
	var fog_density = lerpf(night_fog_density, day_fog_density, day_factor)
	return {
		"time": t,
		"elevation": elevation,
		"day_factor": day_factor,
		"sun_energy": sun_energy,
		"sun_temperature": lerpf(2300.0, 6500.0, day_factor),
		"fog_density": fog_density,
		"shadow_enabled": day_factor > 0.03
	}


func _smooth_day_factor(elevation: float) -> float:
	var raw = clampf((elevation + 0.12) / 1.12, 0.0, 1.0)
	return raw * raw * (3.0 - 2.0 * raw)
