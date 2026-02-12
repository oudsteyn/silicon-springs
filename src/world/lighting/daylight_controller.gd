extends Node3D

@export var sun: DirectionalLight3D
@export var day_seconds: float = 1200.0
@export var latitude_tilt_deg: float = 35.0

var _t: float = 0.25

func _process(delta: float) -> void:
	if sun == null or day_seconds <= 0.0:
		return

	_t = fmod(_t + delta / day_seconds, 1.0)
	_update_sun()

func _update_sun() -> void:
	var sun_angle = (_t * TAU) - PI * 0.5
	var elevation = sin(sun_angle)
	var azimuth = _t * TAU

	sun.rotation = Vector3(deg_to_rad(latitude_tilt_deg), azimuth, 0.0)
	sun.rotate_x(-asin(clampf(elevation, -1.0, 1.0)))

	var day_factor = clampf((elevation + 0.12) / 1.12, 0.0, 1.0)
	sun.light_energy = lerpf(0.02, 1.2, day_factor)
	sun.light_temperature = lerpf(2300.0, 6500.0, day_factor)
	sun.shadow_enabled = day_factor > 0.03
