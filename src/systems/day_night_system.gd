extends CanvasModulate
class_name DayNightSystem
## Manages day/night cycle visual effects

signal time_of_day_changed(hour: int, period: String)

# Time settings
var current_hour: float = 8.0  # Start at 8 AM
var hours_per_month: float = 24.0 * 30.0  # Full month of day cycles
var time_scale: float = 1.0  # Multiplier for time progression

# Biome reference for daylight hours
var current_biome: Resource = null  # BiomePreset

# Day phases
enum DayPhase { DAWN, DAY, DUSK, NIGHT }
var current_phase: DayPhase = DayPhase.DAY

# Color settings for different times
const COLORS = {
	0: Color(0.1, 0.1, 0.2, 1.0),   # Midnight - deep blue
	4: Color(0.15, 0.15, 0.25, 1.0), # Late night
	6: Color(0.6, 0.5, 0.5, 1.0),    # Dawn - pink/orange tint
	8: Color(1.0, 0.95, 0.9, 1.0),   # Morning - warm
	12: Color(1.0, 1.0, 1.0, 1.0),   # Noon - full bright
	16: Color(1.0, 0.95, 0.85, 1.0), # Afternoon - warm
	18: Color(0.9, 0.7, 0.5, 1.0),   # Sunset - orange
	20: Color(0.4, 0.35, 0.5, 1.0),  # Dusk - purple
	22: Color(0.15, 0.15, 0.25, 1.0) # Night
}

# Biome sky tint (applied on top of time-of-day colors)
var sky_tint: Color = Color.WHITE

# Whether day/night cycle is enabled
var enabled: bool = false

# Track last emitted hour for change detection
var last_emitted_hour: int = -1


func _ready() -> void:
	Events.month_tick.connect(_on_month_tick)
	# Start with no color tint
	color = Color.WHITE


func _process(delta: float) -> void:
	if not enabled:
		color = Color.WHITE
		return

	# Progress time based on simulation speed
	if not Simulation.is_paused and Simulation.current_speed > 0:
		var speed_multiplier = Simulation.SPEED_SETTINGS[Simulation.current_speed]
		if speed_multiplier > 0:
			# Calculate hours per real second based on game speed
			var hours_per_second = hours_per_month / (speed_multiplier * 30.0)
			current_hour += hours_per_second * delta * time_scale

			# Wrap around at 24 hours
			while current_hour >= 24.0:
				current_hour -= 24.0

			_update_color()
			_check_phase_change()


func _on_month_tick() -> void:
	# Reset to morning on new month (optional, can be removed for continuous cycle)
	pass


func _update_color() -> void:
	# Find the two nearest color keyframes and interpolate
	var hour_int = int(current_hour)
	var _hour_frac = current_hour - hour_int  # Reserved for future interpolation refinement

	var prev_hour = -1
	var next_hour = -1
	var prev_color = Color.WHITE
	var next_color = Color.WHITE

	# Find surrounding keyframes
	var sorted_hours = COLORS.keys()
	sorted_hours.sort()

	for i in range(sorted_hours.size()):
		if sorted_hours[i] <= hour_int:
			prev_hour = sorted_hours[i]
			prev_color = COLORS[prev_hour]
		if sorted_hours[i] > hour_int and next_hour == -1:
			next_hour = sorted_hours[i]
			next_color = COLORS[next_hour]

	# Handle wrap-around
	if next_hour == -1:
		next_hour = sorted_hours[0] + 24
		next_color = COLORS[sorted_hours[0]]
	if prev_hour == -1:
		prev_hour = sorted_hours[-1] - 24
		prev_color = COLORS[sorted_hours[-1]]

	# Calculate interpolation factor
	var range_size = next_hour - prev_hour
	var progress = (current_hour - prev_hour) / range_size if range_size > 0 else 0.0
	progress = clamp(progress, 0.0, 1.0)

	# Smooth interpolation
	var base_color = prev_color.lerp(next_color, progress)

	# Apply biome sky tint
	color = Color(
		base_color.r * sky_tint.r,
		base_color.g * sky_tint.g,
		base_color.b * sky_tint.b,
		base_color.a
	)


func _check_phase_change() -> void:
	var hour_int = int(current_hour)

	# Get biome-adjusted sunrise/sunset
	var sunrise = get_sunrise_hour()
	var sunset = get_sunset_hour()
	var dawn_start = sunrise - 1.0
	var dusk_end = sunset + 1.5

	# Determine current phase based on biome daylight
	var new_phase: DayPhase
	if current_hour >= dawn_start and current_hour < sunrise:
		new_phase = DayPhase.DAWN
	elif current_hour >= sunrise and current_hour < sunset:
		new_phase = DayPhase.DAY
	elif current_hour >= sunset and current_hour < dusk_end:
		new_phase = DayPhase.DUSK
	else:
		new_phase = DayPhase.NIGHT

	# Emit signal on hour change
	if hour_int != last_emitted_hour:
		last_emitted_hour = hour_int
		var period = _get_period_name()
		time_of_day_changed.emit(hour_int, period)

	current_phase = new_phase


func _get_period_name() -> String:
	match current_phase:
		DayPhase.DAWN: return "Dawn"
		DayPhase.DAY: return "Day"
		DayPhase.DUSK: return "Dusk"
		DayPhase.NIGHT: return "Night"
	return "Unknown"


func get_time_string() -> String:
	var hour_12 = int(current_hour) % 12
	if hour_12 == 0:
		hour_12 = 12
	var minute = int((current_hour - int(current_hour)) * 60)
	var am_pm = "AM" if current_hour < 12 else "PM"
	return "%d:%02d %s" % [hour_12, minute, am_pm]


func get_hour() -> int:
	return int(current_hour)


func set_hour(hour: float) -> void:
	current_hour = fmod(hour, 24.0)
	if current_hour < 0:
		current_hour += 24.0
	_update_color()
	_check_phase_change()


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		color = Color.WHITE


func toggle() -> void:
	set_enabled(not enabled)


func is_night() -> bool:
	return current_phase == DayPhase.NIGHT


func is_day() -> bool:
	return current_phase == DayPhase.DAY


func set_biome(biome: Resource) -> void:
	current_biome = biome
	if biome and biome.get("sky_tint"):
		sky_tint = biome.sky_tint
	else:
		sky_tint = Color.WHITE
	_update_color()


func get_daylight_hours() -> float:
	# Get daylight hours for current month from biome, or default 12
	if current_biome and current_biome.has_method("get_daylight_hours_for_month"):
		return current_biome.get_daylight_hours_for_month(GameState.current_month)
	return 12.0


func get_sunrise_hour() -> float:
	# Calculate sunrise based on daylight hours (centered around noon)
	var daylight = get_daylight_hours()
	return 12.0 - (daylight / 2.0)


func get_sunset_hour() -> float:
	# Calculate sunset based on daylight hours (centered around noon)
	var daylight = get_daylight_hours()
	return 12.0 + (daylight / 2.0)
