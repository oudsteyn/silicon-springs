extends Control
class_name AlertIndicator
## Alert dot indicators for Status Pill - shows problems as colored dots
## Only visible when problems exist

const DOT_SIZE: int = 8
const DOT_SPACING: int = 4
const PULSE_DURATION: float = 1.0

# Alert definitions
const ALERTS = {
	"power": {
		"color": Color("#D4A035"),  # Warning yellow
		"tooltip": "Power shortage - demand exceeds supply",
		"priority": 1
	},
	"water": {
		"color": Color("#2E8B9A"),  # Teal
		"tooltip": "Water shortage - demand exceeds supply",
		"priority": 2
	},
	"budget": {
		"color": Color("#C75050"),  # Danger red
		"tooltip": "Budget crisis - balance is negative",
		"priority": 0
	},
	"crime": {
		"color": Color("#C75050"),  # Danger red
		"tooltip": "High crime rate - build more police stations",
		"priority": 3
	},
	"traffic": {
		"color": Color("#D4A035"),  # Warning yellow
		"tooltip": "Traffic congestion - improve road network",
		"priority": 4
	},
	"fire": {
		"color": Color("#FF6B35"),  # Orange-red
		"tooltip": "Active fire - send fire trucks",
		"priority": 0
	}
}

# Components
var container: HBoxContainer
var dots: Dictionary = {}  # alert_type: ColorRect
var pulse_tweens: Dictionary = {}  # alert_type: Tween

# State
var _active_alerts: Dictionary = {}  # alert_type: bool


func _ready() -> void:
	_setup_ui()
	_connect_signals()


func _exit_tree() -> void:
	# Clean up all running pulse tweens
	for alert_type in pulse_tweens:
		if pulse_tweens[alert_type] and pulse_tweens[alert_type].is_valid():
			pulse_tweens[alert_type].kill()
	pulse_tweens.clear()


func _setup_ui() -> void:
	container = HBoxContainer.new()
	container.add_theme_constant_override("separation", DOT_SPACING)
	add_child(container)

	# Create all dots (hidden by default)
	var sorted_alerts = ALERTS.keys()
	sorted_alerts.sort_custom(func(a, b): return ALERTS[a].priority < ALERTS[b].priority)

	for alert_type in sorted_alerts:
		var dot = _create_dot(alert_type)
		dots[alert_type] = dot
		container.add_child(dot)


func _create_dot(alert_type: String) -> ColorRect:
	var alert_data = ALERTS[alert_type]

	var dot = ColorRect.new()
	dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
	dot.color = alert_data.color
	dot.tooltip_text = alert_data.tooltip
	dot.visible = false
	dot.mouse_filter = Control.MOUSE_FILTER_PASS  # Allow tooltip

	return dot


func _connect_signals() -> void:
	UIManager.alert_state_changed.connect(_on_alert_changed)


func _on_alert_changed(alert_type: String, active: bool) -> void:
	if not dots.has(alert_type):
		return

	_active_alerts[alert_type] = active
	var dot = dots[alert_type]

	if active:
		dot.visible = true
		_start_pulse(alert_type)
	else:
		dot.visible = false
		_stop_pulse(alert_type)


func _start_pulse(alert_type: String) -> void:
	if pulse_tweens.has(alert_type):
		return  # Already pulsing

	var dot = dots[alert_type]
	var base_color = ALERTS[alert_type].color

	var tween = create_tween()
	tween.set_loops()

	# Pulse animation: brighten then return to normal
	tween.tween_property(dot, "color", base_color.lightened(0.3), PULSE_DURATION / 2)
	tween.tween_property(dot, "color", base_color, PULSE_DURATION / 2)

	pulse_tweens[alert_type] = tween


func _stop_pulse(alert_type: String) -> void:
	if pulse_tweens.has(alert_type):
		pulse_tweens[alert_type].kill()
		pulse_tweens.erase(alert_type)

	# Reset to base color
	if dots.has(alert_type):
		dots[alert_type].color = ALERTS[alert_type].color


func set_alert(alert_type: String, active: bool) -> void:
	_on_alert_changed(alert_type, active)


func get_active_count() -> int:
	var count = 0
	for alert_type in _active_alerts:
		if _active_alerts[alert_type]:
			count += 1
	return count


func has_any_alert() -> bool:
	return get_active_count() > 0


func get_visible_size() -> Vector2:
	var count = get_active_count()
	if count == 0:
		return Vector2.ZERO
	return Vector2(count * DOT_SIZE + (count - 1) * DOT_SPACING, DOT_SIZE)
