extends CanvasLayer
class_name ToastNotificationSystem
## Polished toast notification system with stacking and animations

const MAX_VISIBLE_TOASTS: int = 3
const TOAST_DURATION: float = 3.0
const TOAST_FADE_TIME: float = 0.4
const TOAST_SLIDE_TIME: float = 0.25

# Filter out spammy info notifications - only show important ones
const ALLOWED_INFO_MESSAGES: Array[String] = [
	"game_saved", "game_loaded", "Game saved", "Game loaded",
	"tier_unlocked", "building_unlocked", "milestone",
	"Starting new city"
]

var toast_container: VBoxContainer
var active_toasts: Array[Control] = []
var _toast_timers: Dictionary = {}  # toast: Timer

# Toast types with styling
const TOAST_STYLES = {
	"info": {
		"icon": "i",
		"bg_color": Color(0.12, 0.30, 0.45, 0.95),
		"border_color": Color(0.25, 0.55, 0.75, 1),
		"icon_color": Color(0.5, 0.8, 1.0)
	},
	"success": {
		"icon": "OK",
		"bg_color": Color(0.12, 0.38, 0.28, 0.95),
		"border_color": Color(0.25, 0.65, 0.45, 1),
		"icon_color": Color(0.5, 1.0, 0.7)
	},
	"warning": {
		"icon": "!",
		"bg_color": Color(0.42, 0.32, 0.12, 0.95),
		"border_color": Color(0.85, 0.65, 0.25, 1),
		"icon_color": Color(1.0, 0.85, 0.4)
	},
	"error": {
		"icon": "X",
		"bg_color": Color(0.42, 0.15, 0.15, 0.95),
		"border_color": Color(0.85, 0.30, 0.30, 1),
		"icon_color": Color(1.0, 0.5, 0.5)
	}
}


func _ready() -> void:
	layer = 100  # Above everything

	# Create container for toasts (bottom-right corner)
	toast_container = VBoxContainer.new()
	toast_container.anchor_left = 1.0
	toast_container.anchor_right = 1.0
	toast_container.anchor_top = 1.0
	toast_container.anchor_bottom = 1.0
	toast_container.offset_left = -320
	toast_container.offset_right = -20
	toast_container.offset_top = -200
	toast_container.offset_bottom = -20
	toast_container.add_theme_constant_override("separation", 8)
	toast_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	toast_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(toast_container)

	# Connect to notification events
	Events.notification_requested.connect(show_toast)


func _exit_tree() -> void:
	# Clean up all toast timers
	for toast in _toast_timers:
		if is_instance_valid(_toast_timers[toast]):
			_toast_timers[toast].stop()
			_toast_timers[toast].queue_free()
	_toast_timers.clear()


func show_toast(message: String, type: String = "info") -> void:
	# Filter out most info notifications to reduce spam
	if type == "info":
		var is_allowed = false
		for allowed in ALLOWED_INFO_MESSAGES:
			if message.contains(allowed):
				is_allowed = true
				break
		if not is_allowed:
			return

	# Remove oldest toast if at max
	if active_toasts.size() >= MAX_VISIBLE_TOASTS:
		var oldest = active_toasts.pop_front()
		_cleanup_toast_timer(oldest)
		if is_instance_valid(oldest):
			oldest.queue_free()

	var toast = _create_toast(message, type)
	toast_container.add_child(toast)
	toast_container.move_child(toast, 0)  # Add at top
	active_toasts.append(toast)

	# Animate in
	toast.modulate.a = 0.0
	toast.position.x = 50

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(toast, "modulate:a", 1.0, TOAST_SLIDE_TIME)
	tween.tween_property(toast, "position:x", 0.0, TOAST_SLIDE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Schedule removal using a Timer node (prevents leaks on exit)
	var timer = Timer.new()
	timer.wait_time = TOAST_DURATION
	timer.one_shot = true
	timer.timeout.connect(_on_toast_timeout.bind(toast))
	add_child(timer)
	_toast_timers[toast] = timer
	timer.start()


func _on_toast_timeout(toast: Control) -> void:
	_dismiss_toast(toast)


func _cleanup_toast_timer(toast: Control) -> void:
	if _toast_timers.has(toast):
		var timer = _toast_timers[toast]
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
		_toast_timers.erase(toast)


func _dismiss_toast(toast: Control) -> void:
	if not is_instance_valid(toast):
		return

	_cleanup_toast_timer(toast)
	active_toasts.erase(toast)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(toast, "modulate:a", 0.0, TOAST_FADE_TIME)
	tween.tween_property(toast, "position:x", 50.0, TOAST_FADE_TIME)
	tween.chain().tween_callback(toast.queue_free)


func _create_toast(message: String, type: String) -> PanelContainer:
	var style = TOAST_STYLES.get(type, TOAST_STYLES["info"])

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 50)

	# Create stylebox using ThemeConstants for consistent sizing
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = style.bg_color
	stylebox.border_width_left = ThemeConstants.BORDER_THICK + 1
	stylebox.border_width_top = ThemeConstants.BORDER_THIN
	stylebox.border_width_right = ThemeConstants.BORDER_THIN
	stylebox.border_width_bottom = ThemeConstants.BORDER_THIN
	stylebox.border_color = style.border_color
	stylebox.set_corner_radius_all(ThemeConstants.RADIUS_MEDIUM)
	stylebox.content_margin_left = ThemeConstants.PADDING_LARGE
	stylebox.content_margin_top = ThemeConstants.PADDING_NORMAL + 2
	stylebox.content_margin_right = ThemeConstants.PADDING_LARGE
	stylebox.content_margin_bottom = ThemeConstants.PADDING_NORMAL + 2
	stylebox.shadow_color = Color(0, 0, 0, 0.4)
	stylebox.shadow_size = ThemeConstants.SHADOW_SIZE_SMALL
	panel.add_theme_stylebox_override("panel", stylebox)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Icon
	var icon = Label.new()
	icon.text = style.icon
	icon.add_theme_font_size_override("font_size", 14)
	icon.add_theme_color_override("font_color", style.icon_color)
	icon.custom_minimum_size = Vector2(24, 0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(icon)

	# Message
	var msg = Label.new()
	msg.text = message
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 13)
	hbox.add_child(msg)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "x"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(20, 20)
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.pressed.connect(func(): _dismiss_toast(panel))
	hbox.add_child(close_btn)

	return panel
