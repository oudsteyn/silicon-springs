extends CanvasLayer
class_name StatusPill
## Compact status display showing budget, population, date, and speed controls
## Top-left corner, 300x50px, click opens Dashboard

const PILL_WIDTH: int = 380
const PILL_HEIGHT: int = 60
const PADDING: int = 16
const ANIMATION_DURATION: float = 0.2

# Components
var panel: PanelContainer
var hbox: HBoxContainer
var budget_label: Label
var budget_delta_label: Label
var separator1: Label
var population_label: Label
var separator2: Label
var date_label: Label
var speed_container: HBoxContainer
var pause_button: Button
var speed_buttons: Array[Button] = []
var alert_container: HBoxContainer
var weather_label: Label

# State
var _is_hovered: bool = false
var _expanded_tooltip: Control = null
var _tooltip_tween: Tween = null

# Alert icons
var _alert_icons: Dictionary = {}  # alert_type: TextureRect/Label


func _ready() -> void:
	layer = 95
	_setup_ui()
	_connect_signals()
	_update_display()


func _exit_tree() -> void:
	# Clean up any running tweens
	if _tooltip_tween and _tooltip_tween.is_valid():
		_tooltip_tween.kill()
		_tooltip_tween = null
	if _expanded_tooltip and is_instance_valid(_expanded_tooltip):
		_expanded_tooltip.queue_free()
		_expanded_tooltip = null


func _setup_ui() -> void:
	# Main panel container
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PILL_WIDTH, PILL_HEIGHT)

	# Position in top-left corner with margin
	panel.anchor_left = 0
	panel.anchor_top = 0
	panel.anchor_right = 0
	panel.anchor_bottom = 0
	panel.offset_left = 70  # Leave room for tool palette
	panel.offset_top = 10
	panel.offset_right = 70 + PILL_WIDTH
	panel.offset_bottom = 10 + PILL_HEIGHT

	# Apply style using centralized theme
	var style = UIManager.get_pill_style()
	panel.add_theme_stylebox_override("panel", style)

	# Main horizontal layout
	hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	panel.add_child(hbox)

	# Budget section
	var budget_box = HBoxContainer.new()
	budget_box.add_theme_constant_override("separation", 2)

	budget_label = Label.new()
	budget_label.text = "$50K"
	budget_label.add_theme_color_override("font_color", UIManager.COLORS.text)
	budget_label.add_theme_font_size_override("font_size", 18)
	budget_box.add_child(budget_label)

	budget_delta_label = Label.new()
	budget_delta_label.text = "+$2K"
	budget_delta_label.add_theme_color_override("font_color", UIManager.COLORS.success)
	budget_delta_label.add_theme_font_size_override("font_size", 14)
	budget_box.add_child(budget_delta_label)

	hbox.add_child(budget_box)

	# Separator
	separator1 = Label.new()
	separator1.text = "|"
	separator1.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	hbox.add_child(separator1)

	# Population
	population_label = Label.new()
	population_label.text = "0"
	population_label.add_theme_color_override("font_color", UIManager.COLORS.text)
	population_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(population_label)

	# Separator
	separator2 = Label.new()
	separator2.text = "|"
	separator2.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	hbox.add_child(separator2)

	# Date
	date_label = Label.new()
	date_label.text = "Jan 2024"
	date_label.add_theme_color_override("font_color", UIManager.COLORS.text)
	date_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(date_label)

	# Separator
	var separator3 = Label.new()
	separator3.text = "|"
	separator3.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	hbox.add_child(separator3)

	# Weather indicator (compact)
	weather_label = Label.new()
	weather_label.text = "20C"
	weather_label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	weather_label.add_theme_font_size_override("font_size", 16)
	weather_label.tooltip_text = "Current weather (D for details)"
	hbox.add_child(weather_label)

	# Separator before speed
	var separator_weather = Label.new()
	separator_weather.text = "|"
	separator_weather.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	hbox.add_child(separator_weather)

	# Speed controls
	speed_container = HBoxContainer.new()
	speed_container.add_theme_constant_override("separation", 2)

	# Pause button
	pause_button = _create_speed_button(">")
	pause_button.pressed.connect(_on_pause_pressed)
	speed_container.add_child(pause_button)

	# Speed buttons (1x, 2x, 3x)
	for i in range(1, 4):
		var btn = _create_speed_button(str(i))
		btn.pressed.connect(_on_speed_pressed.bind(i))
		speed_buttons.append(btn)
		speed_container.add_child(btn)

	hbox.add_child(speed_container)

	# Alert container (at end, only shows when alerts active)
	alert_container = HBoxContainer.new()
	alert_container.add_theme_constant_override("separation", 4)
	alert_container.visible = false
	hbox.add_child(alert_container)

	# Create alert icons (hidden by default)
	_create_alert_icons()

	add_child(panel)

	# Make clickable
	panel.gui_input.connect(_on_panel_input)
	panel.mouse_entered.connect(_on_panel_mouse_entered)
	panel.mouse_exited.connect(_on_panel_mouse_exited)
	panel.tooltip_text = "Click to open Dashboard (D)"


func _create_speed_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(22, 22)
	btn.flat = true
	btn.add_theme_font_size_override("font_size", ThemeConstants.FONT_SMALL)
	btn.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	btn.add_theme_color_override("font_hover_color", UIManager.COLORS.text)
	btn.add_theme_color_override("font_pressed_color", UIManager.COLORS.accent)

	# Use centralized theme styles
	var style_normal = UIManager.get_button_normal_style()
	style_normal.bg_color = Color.TRANSPARENT
	style_normal.set_border_width_all(0)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = UIManager.get_button_hover_style()
	style_hover.bg_color = UIManager.COLORS.panel_bg.lightened(0.1)
	style_hover.border_width_left = 0
	style_hover.border_width_right = 0
	style_hover.border_width_top = 0
	style_hover.border_width_bottom = 0
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = UIManager.get_button_pressed_style()
	style_pressed.bg_color = UIManager.COLORS.accent.darkened(0.3)
	style_pressed.border_width_left = 0
	style_pressed.border_width_right = 0
	style_pressed.border_width_top = 0
	style_pressed.border_width_bottom = 0
	btn.add_theme_stylebox_override("pressed", style_pressed)

	return btn


func _create_alert_icons() -> void:
	var alert_types = {
		"power": {"icon": "!", "color": UIManager.COLORS.warning},
		"water": {"icon": "~", "color": UIManager.COLORS.accent},
		"crime": {"icon": "X", "color": UIManager.COLORS.danger},
		"traffic": {"icon": "#", "color": UIManager.COLORS.warning},
		"budget": {"icon": "$", "color": UIManager.COLORS.danger},
		"fire": {"icon": "*", "color": UIManager.COLORS.danger},
		"storm": {"icon": "S", "color": UIManager.COLORS.warning},
		"flood": {"icon": "F", "color": UIManager.COLORS.danger},
		"heat_wave": {"icon": "H", "color": Color(0.95, 0.5, 0.3)},
		"cold_snap": {"icon": "C", "color": Color(0.5, 0.7, 0.95)}
	}

	for alert_type in alert_types:
		var data = alert_types[alert_type]
		var icon = Label.new()
		icon.text = data.icon
		icon.add_theme_color_override("font_color", data.color)
		icon.add_theme_font_size_override("font_size", 16)
		icon.visible = false
		icon.tooltip_text = alert_type.capitalize() + " Alert"
		_alert_icons[alert_type] = icon
		alert_container.add_child(icon)


func _connect_signals() -> void:
	Events.budget_updated.connect(_on_budget_updated)
	Events.population_changed.connect(_on_population_changed)
	Events.month_tick.connect(_on_month_tick)
	Events.simulation_speed_changed.connect(_on_speed_changed)
	Events.simulation_paused.connect(_on_paused_changed)
	UIManager.alert_state_changed.connect(_on_alert_changed)
	Events.weather_changed.connect(_on_weather_changed)
	Events.storm_started.connect(_on_storm_started)
	Events.storm_ended.connect(_on_storm_ended)
	Events.flood_started.connect(_on_flood_started)
	Events.flood_ended.connect(_on_flood_ended)
	Events.heat_wave_started.connect(_on_heat_wave_started)
	Events.heat_wave_ended.connect(_on_heat_wave_ended)
	Events.cold_snap_started.connect(_on_cold_snap_started)
	Events.cold_snap_ended.connect(_on_cold_snap_ended)

	# Domain events (rich aggregated events)
	Events.power_state_changed.connect(_on_power_state_changed)
	Events.storm_outage_changed.connect(_on_storm_outage_changed)


func _update_display() -> void:
	# Update budget
	budget_label.text = UIManager.format_money(GameState.budget)

	var delta = GameState.monthly_income - GameState.monthly_expenses
	budget_delta_label.text = UIManager.format_money(delta, true)
	if delta >= 0:
		budget_delta_label.add_theme_color_override("font_color", UIManager.COLORS.success)
	else:
		budget_delta_label.add_theme_color_override("font_color", UIManager.COLORS.danger)

	# Update population
	population_label.text = UIManager.format_number(GameState.population)

	# Update date
	var month_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
					   "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	var month_idx = clampi((GameState.current_month - 1) % 12, 0, 11)
	date_label.text = "%s %d" % [month_names[month_idx], GameState.current_year]

	# Update speed buttons
	_update_speed_buttons()


func _update_speed_buttons() -> void:
	var is_paused = Simulation.is_paused
	var current_speed = Simulation.current_speed

	# Update pause button
	if is_paused:
		pause_button.text = ">"
		pause_button.add_theme_color_override("font_color", UIManager.COLORS.warning)
	else:
		pause_button.text = "||"
		pause_button.add_theme_color_override("font_color", UIManager.COLORS.text_dim)

	# Update speed buttons
	for i in range(speed_buttons.size()):
		var btn = speed_buttons[i]
		if (i + 1) == current_speed and not is_paused:
			btn.add_theme_color_override("font_color", UIManager.COLORS.accent)
		else:
			btn.add_theme_color_override("font_color", UIManager.COLORS.text_dim)


func _on_budget_updated(_balance: int, _income: int, _expenses: int) -> void:
	_update_display()


func _on_population_changed(_new_pop: int, _delta: int) -> void:
	_update_display()


func _on_month_tick() -> void:
	_update_display()


func _on_speed_changed(_speed: int) -> void:
	_update_speed_buttons()


func _on_paused_changed(_paused: bool) -> void:
	_update_speed_buttons()


func _on_pause_pressed() -> void:
	Simulation.toggle_pause()


func _on_speed_pressed(speed: int) -> void:
	Simulation.set_speed(speed)


func _on_alert_changed(alert_type: String, active: bool) -> void:
	if _alert_icons.has(alert_type):
		_alert_icons[alert_type].visible = active

	# Show/hide alert container based on any active alerts
	var any_active = false
	for icon in _alert_icons.values():
		if icon.visible:
			any_active = true
			break
	alert_container.visible = any_active


func _on_weather_changed(temperature: float, conditions: String) -> void:
	# Format compact weather display
	var temp_str = "%.0fC" % temperature
	var icon = _get_weather_icon(conditions)
	weather_label.text = "%s %s" % [icon, temp_str]

	# Color based on conditions
	if conditions in ["Storm", "Blizzard", "Flooding"]:
		weather_label.add_theme_color_override("font_color", UIManager.COLORS.warning)
	elif conditions in ["Hot"]:
		weather_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.3))
	elif conditions in ["Cold", "Snow"]:
		weather_label.add_theme_color_override("font_color", Color(0.5, 0.7, 0.9))
	else:
		weather_label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)

	weather_label.tooltip_text = "%s, %s" % [conditions, temp_str]


func _get_weather_icon(conditions: String) -> String:
	match conditions:
		"Clear", "Hot": return "*"  # Sun-like
		"Cloudy", "Overcast": return "="
		"Rain": return "~"
		"Snow", "Cold": return "+"
		"Storm", "Blizzard": return "!"
		"Flooding": return "^"
		_: return "*"


func _on_storm_started() -> void:
	_on_alert_changed("storm", true)


func _on_storm_ended() -> void:
	_on_alert_changed("storm", false)


func _on_flood_started() -> void:
	_on_alert_changed("flood", true)


func _on_flood_ended() -> void:
	_on_alert_changed("flood", false)


func _on_heat_wave_started() -> void:
	_on_alert_changed("heat_wave", true)


func _on_heat_wave_ended() -> void:
	_on_alert_changed("heat_wave", false)


func _on_cold_snap_started() -> void:
	_on_alert_changed("cold_snap", true)


func _on_cold_snap_ended() -> void:
	_on_alert_changed("cold_snap", false)


func _on_panel_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Open dashboard
		UIManager.toggle_panel("dashboard")
		get_viewport().set_input_as_handled()


func _on_panel_mouse_entered() -> void:
	_is_hovered = true
	_show_tooltip()


func _on_panel_mouse_exited() -> void:
	_is_hovered = false
	_hide_tooltip()


func _show_tooltip() -> void:
	if _expanded_tooltip:
		return

	# Kill any existing hide animation
	if _tooltip_tween and _tooltip_tween.is_valid():
		_tooltip_tween.kill()
		_tooltip_tween = null

	_expanded_tooltip = PanelContainer.new()
	_expanded_tooltip.anchor_left = 0
	_expanded_tooltip.anchor_top = 0
	_expanded_tooltip.offset_left = 70
	_expanded_tooltip.offset_top = PILL_HEIGHT + 15
	_expanded_tooltip.offset_right = 70 + 280
	_expanded_tooltip.offset_bottom = PILL_HEIGHT + 15 + 170

	# Use centralized panel style
	var style = UIManager.get_panel_style(ThemeConstants.RADIUS_MEDIUM)
	style.set_content_margin_all(ThemeConstants.PADDING_LARGE)
	_expanded_tooltip.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# Budget details
	_add_tooltip_row(vbox, "Balance", UIManager.format_money(GameState.budget))
	_add_tooltip_row(vbox, "Income", UIManager.format_money(GameState.monthly_income, true),
					 UIManager.COLORS.success if GameState.monthly_income >= 0 else UIManager.COLORS.danger)
	_add_tooltip_row(vbox, "Expenses", "-" + UIManager.format_money(GameState.monthly_expenses),
					 UIManager.COLORS.danger)

	# Separator
	var sep = HSeparator.new()
	sep.add_theme_color_override("separation", UIManager.COLORS.border)
	vbox.add_child(sep)

	# Population details
	_add_tooltip_row(vbox, "Population", str(GameState.population))
	_add_tooltip_row(vbox, "Happiness", "%.0f%%" % (GameState.happiness * 100),
					 _happiness_color(GameState.happiness))
	_add_tooltip_row(vbox, "Employment", "%.0f%%" % ((1.0 - GameState.unemployment_rate) * 100))

	# Separator
	var sep2 = HSeparator.new()
	sep2.add_theme_color_override("separation", UIManager.COLORS.border)
	vbox.add_child(sep2)

	# Resources
	_add_tooltip_row(vbox, "Power", "%d / %d MW" % [int(GameState.power_demand), int(GameState.power_supply)],
					 UIManager.COLORS.success if GameState.power_supply >= GameState.power_demand else UIManager.COLORS.danger)
	_add_tooltip_row(vbox, "Water", "%d / %d ML" % [int(GameState.water_demand), int(GameState.water_supply)],
					 UIManager.COLORS.success if GameState.water_supply >= GameState.water_demand else UIManager.COLORS.danger)

	# Hint at bottom
	var sep3 = HSeparator.new()
	sep3.add_theme_color_override("separation", UIManager.COLORS.border)
	vbox.add_child(sep3)

	var hint = Label.new()
	hint.text = "Click for full Dashboard (D)"
	hint.add_theme_color_override("font_color", UIManager.COLORS.accent)
	hint.add_theme_font_size_override("font_size", 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hint)

	_expanded_tooltip.add_child(vbox)
	add_child(_expanded_tooltip)

	# Fade in (track tween for cleanup)
	_expanded_tooltip.modulate.a = 0
	_tooltip_tween = create_tween()
	_tooltip_tween.tween_property(_expanded_tooltip, "modulate:a", 1.0, 0.15)
	_tooltip_tween.tween_callback(func(): _tooltip_tween = null)


func _add_tooltip_row(container: VBoxContainer, label_text: String, value_text: String, color: Color = UIManager.COLORS.text) -> void:
	var row = HBoxContainer.new()

	var label = Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	label.add_theme_font_size_override("font_size", 15)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", color)
	value.add_theme_font_size_override("font_size", 15)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)

	container.add_child(row)


func _happiness_color(happiness: float) -> Color:
	if happiness >= 0.7:
		return UIManager.COLORS.success
	elif happiness >= 0.4:
		return UIManager.COLORS.warning
	return UIManager.COLORS.danger


func _hide_tooltip() -> void:
	if _expanded_tooltip:
		# Kill any existing animation
		if _tooltip_tween and _tooltip_tween.is_valid():
			_tooltip_tween.kill()

		var tooltip = _expanded_tooltip
		_expanded_tooltip = null
		_tooltip_tween = create_tween()
		_tooltip_tween.tween_property(tooltip, "modulate:a", 0.0, 0.1)
		_tooltip_tween.tween_callback(func():
			if is_instance_valid(tooltip):
				tooltip.queue_free()
			_tooltip_tween = null
		)


# ============================================
# DOMAIN EVENT HANDLERS
# ============================================

func _on_power_state_changed(event: DomainEvents.PowerStateChanged) -> void:
	# Update power alert based on rich event data
	var has_power_issue = event.has_shortage or event.is_brownout or event.blackout_cells > 0
	_on_alert_changed("power", has_power_issue)


func _on_storm_outage_changed(event: DomainEvents.StormOutageEvent) -> void:
	# Update storm alert based on outage event
	if event.active and event.severity > 0.1:
		_on_alert_changed("storm", true)
	elif not event.active:
		_on_alert_changed("storm", false)
