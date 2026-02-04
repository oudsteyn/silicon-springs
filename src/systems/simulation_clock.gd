extends RefCounted
class_name SimulationClock
## Handles simulation time progression and speed state.

var speed_settings: Array[float] = []
var speed_names: Array[String] = []
var current_speed: int = 1
var is_paused: bool = false
var tick_timer: float = 0.0


func _init(settings: Array[float], names: Array[String], initial_speed: int = 1) -> void:
	speed_settings = settings
	speed_names = names
	set_speed(initial_speed)


func advance(delta: float) -> bool:
	if is_paused or current_speed == 0:
		return false

	tick_timer += delta
	var seconds_per_tick = speed_settings[current_speed]
	if tick_timer >= seconds_per_tick:
		tick_timer -= seconds_per_tick
		return true
	return false


func set_speed(speed: int) -> void:
	current_speed = clamp(speed, 0, speed_settings.size() - 1)
	is_paused = (current_speed == 0)


func toggle_pause() -> void:
	is_paused = not is_paused


func reset() -> void:
	tick_timer = 0.0


func get_speed_name() -> String:
	if is_paused:
		return "Paused"
	return speed_names[current_speed]
