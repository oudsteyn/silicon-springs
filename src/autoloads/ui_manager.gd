extends Node
class_name UIManagerClass
## Central UI state and panel coordinator for the minimalist interface
## Single source of truth for panel visibility, tool state, and UI modes

# UI Mode enum - determines overall UI behavior
enum UIMode {
	DEFAULT,    # Normal gameplay - status pill visible, tools available
	BUILDING,   # Build mode active - ghost preview, placement UI
	SELECTING,  # Building/cell selected - info panel visible
	OVERLAY,    # Visualization overlay active
	MODAL       # Modal panel open (dashboard, settings, etc)
}

# Tool enum - mirrors GameWorld.ToolMode for UI coordination
enum Tool {
	SELECT,
	PAN,
	ZOOM,
	BUILD,
	ZONE,
	DEMOLISH,
	TERRAIN,
	OVERLAY,
	SETTINGS
}

# Signals for UI state changes
signal ui_mode_changed(old_mode: UIMode, new_mode: UIMode)
signal tool_changed(tool: Tool)
signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)
signal flyout_opened(flyout_id: String)
signal flyout_closed(flyout_id: String)
signal alert_state_changed(alert_type: String, active: bool)

# Current state
var current_mode: UIMode = UIMode.DEFAULT
var current_tool: Tool = Tool.SELECT
var previous_tool: Tool = Tool.SELECT

# Panel visibility tracking
var _open_panels: Dictionary = {}  # panel_name: bool
var _open_flyouts: Array[String] = []

# Alert states
var _alerts: Dictionary = {
	"power": false,
	"water": false,
	"crime": false,
	"traffic": false,
	"budget": false,
	"fire": false
}

# Animation constants
const PANEL_SLIDE_DURATION: float = 0.2
const MODAL_FADE_DURATION: float = 0.15
const HOVER_TRANSITION_DURATION: float = 0.1

# Color palette (design spec)
const COLORS = {
	"background": Color("#0A0E14"),
	"panel_bg": Color("#141A22"),
	"accent": Color("#2E8B9A"),
	"success": Color("#3CB371"),
	"warning": Color("#D4A035"),
	"danger": Color("#C75050"),
	"text": Color("#E8ECF0"),
	"text_dim": Color(0.60, 0.65, 0.75),  # Improved contrast (5.1:1 ratio)
	"text_disabled": Color(0.40, 0.42, 0.48),
	"border": Color("#2A3545")
}

# References to UI components (set by main.gd)
var status_pill = null
var tool_palette = null
var info_panel = null
var dashboard_panel = null


func _ready() -> void:
	# Connect to global events
	Events.power_updated.connect(_on_power_updated)
	Events.water_updated.connect(_on_water_updated)
	Events.budget_updated.connect(_on_budget_updated)
	Events.building_selected.connect(_on_building_selected)
	Events.building_deselected.connect(_on_building_deselected)
	Events.build_mode_entered.connect(_on_build_mode_entered)
	Events.build_mode_exited.connect(_on_build_mode_exited)


# ============================================
# MODE MANAGEMENT
# ============================================

func set_mode(new_mode: UIMode) -> void:
	if new_mode == current_mode:
		return
	var old_mode = current_mode
	current_mode = new_mode
	ui_mode_changed.emit(old_mode, new_mode)


func get_mode() -> UIMode:
	return current_mode


func is_modal_open() -> bool:
	return current_mode == UIMode.MODAL


# ============================================
# TOOL MANAGEMENT
# ============================================

func set_tool(tool: Tool) -> void:
	if tool == current_tool:
		return
	previous_tool = current_tool
	current_tool = tool
	tool_changed.emit(tool)

	# Update mode based on tool
	match tool:
		Tool.SELECT:
			if current_mode != UIMode.SELECTING:
				set_mode(UIMode.DEFAULT)
		Tool.BUILD, Tool.ZONE, Tool.DEMOLISH, Tool.TERRAIN:
			set_mode(UIMode.BUILDING)
		Tool.OVERLAY:
			set_mode(UIMode.OVERLAY)
		_:
			if current_mode == UIMode.BUILDING:
				set_mode(UIMode.DEFAULT)


func get_tool() -> Tool:
	return current_tool


func get_tool_name(tool: Tool = current_tool) -> String:
	match tool:
		Tool.SELECT: return "Select"
		Tool.PAN: return "Pan"
		Tool.ZOOM: return "Zoom"
		Tool.BUILD: return "Build"
		Tool.ZONE: return "Zone"
		Tool.DEMOLISH: return "Demolish"
		Tool.TERRAIN: return "Terrain"
		Tool.OVERLAY: return "Overlays"
		Tool.SETTINGS: return "Settings"
	return "Unknown"


func restore_previous_tool() -> void:
	set_tool(previous_tool)


# Convert from GameWorld.ToolMode to UIManager.Tool
func from_game_tool(game_tool: int) -> Tool:
	# GameWorld.ToolMode: SELECT=0, PAN=1, BUILD=2, DEMOLISH=3, ZONE=4, TERRAIN=5
	match game_tool:
		0: return Tool.SELECT
		1: return Tool.PAN
		2: return Tool.BUILD
		3: return Tool.DEMOLISH
		4: return Tool.ZONE
		5: return Tool.TERRAIN
	return Tool.SELECT


# Convert from UIManager.Tool to GameWorld.ToolMode
func to_game_tool(tool: Tool) -> int:
	# GameWorld.ToolMode: SELECT=0, PAN=1, BUILD=2, DEMOLISH=3, ZONE=4, TERRAIN=5
	match tool:
		Tool.SELECT: return 0
		Tool.PAN: return 1
		Tool.BUILD: return 2
		Tool.DEMOLISH: return 3
		Tool.ZONE: return 4
		Tool.TERRAIN: return 5
	return 0


# ============================================
# PANEL MANAGEMENT
# ============================================

func open_panel(panel_name: String) -> void:
	if _open_panels.get(panel_name, false):
		return
	_open_panels[panel_name] = true
	panel_opened.emit(panel_name)

	# Set modal mode for certain panels
	if panel_name in ["dashboard", "budget", "settings", "save_load", "difficulty", "terrain_editor"]:
		set_mode(UIMode.MODAL)


func close_panel(panel_name: String) -> void:
	if not _open_panels.get(panel_name, false):
		return
	_open_panels[panel_name] = false
	panel_closed.emit(panel_name)

	# Exit modal mode if no modals left
	if current_mode == UIMode.MODAL:
		var any_modal = false
		for p in ["dashboard", "budget", "settings", "save_load", "difficulty", "terrain_editor"]:
			if _open_panels.get(p, false):
				any_modal = true
				break
		if not any_modal:
			set_mode(UIMode.DEFAULT)


func toggle_panel(panel_name: String) -> void:
	if is_panel_open(panel_name):
		close_panel(panel_name)
	else:
		open_panel(panel_name)


func is_panel_open(panel_name: String) -> bool:
	return _open_panels.get(panel_name, false)


func close_all_panels() -> void:
	for panel_name in _open_panels.keys():
		close_panel(panel_name)


# ============================================
# FLYOUT MANAGEMENT
# ============================================

func open_flyout(flyout_id: String) -> void:
	if flyout_id in _open_flyouts:
		return
	_open_flyouts.append(flyout_id)
	flyout_opened.emit(flyout_id)


func close_flyout(flyout_id: String) -> void:
	var idx = _open_flyouts.find(flyout_id)
	if idx >= 0:
		_open_flyouts.remove_at(idx)
		flyout_closed.emit(flyout_id)


func close_all_flyouts() -> void:
	var flyouts_to_close = _open_flyouts.duplicate()
	for flyout_id in flyouts_to_close:
		close_flyout(flyout_id)


func is_flyout_open(flyout_id: String) -> bool:
	return flyout_id in _open_flyouts


func get_open_flyouts() -> Array[String]:
	return _open_flyouts.duplicate()


# ============================================
# ALERT MANAGEMENT
# ============================================

func set_alert(alert_type: String, active: bool) -> void:
	if _alerts.get(alert_type) == active:
		return
	_alerts[alert_type] = active
	alert_state_changed.emit(alert_type, active)


func is_alert_active(alert_type: String) -> bool:
	return _alerts.get(alert_type, false)


func get_active_alerts() -> Array[String]:
	var active: Array[String] = []
	for alert_type in _alerts:
		if _alerts[alert_type]:
			active.append(alert_type)
	return active


func has_any_alert() -> bool:
	for alert_type in _alerts:
		if _alerts[alert_type]:
			return true
	return false


# ============================================
# EVENT HANDLERS
# ============================================

func _on_power_updated(supply: float, demand: float) -> void:
	set_alert("power", demand > supply)


func _on_water_updated(supply: float, demand: float) -> void:
	set_alert("water", demand > supply)


func _on_budget_updated(balance: int, _income: int, _expenses: int) -> void:
	set_alert("budget", balance < 0)


func _on_building_selected(_building: Node2D) -> void:
	if current_mode != UIMode.MODAL:
		set_mode(UIMode.SELECTING)


func _on_building_deselected() -> void:
	if current_mode == UIMode.SELECTING:
		set_mode(UIMode.DEFAULT)


func _on_build_mode_entered(_building_id: String) -> void:
	set_tool(Tool.BUILD)


func _on_build_mode_exited() -> void:
	set_tool(Tool.SELECT)


# ============================================
# UTILITY FUNCTIONS
# ============================================

## @deprecated Use get_panel_style() instead
func create_panel_style() -> StyleBoxFlat:
	return get_panel_style(6)


## @deprecated Use get_button_normal_style() instead
func create_button_style(normal_color: Color = COLORS.panel_bg) -> StyleBoxFlat:
	return get_button_normal_style(normal_color)


## @deprecated Use get_button_hover_style() instead
func create_hover_style(base_color: Color = COLORS.panel_bg) -> StyleBoxFlat:
	return get_button_hover_style(base_color)


## @deprecated Use get_button_pressed_style() instead
func create_pressed_style(base_color: Color = COLORS.panel_bg) -> StyleBoxFlat:
	return get_button_pressed_style(base_color)


## @deprecated Use get_button_active_style() instead
func create_active_style() -> StyleBoxFlat:
	return get_button_active_style()


# Format number with K/M suffix
func format_number(value: int) -> String:
	if abs(value) >= 1000000:
		return "%.1fM" % (value / 1000000.0)
	elif abs(value) >= 1000:
		return "%.1fK" % (value / 1000.0)
	return str(value)


# Format money with sign
func format_money(value: int, show_sign: bool = false) -> String:
	var formatted = format_number(abs(value))
	if show_sign:
		if value >= 0:
			return "+$" + formatted
		else:
			return "-$" + formatted
	return "$" + formatted


# ============================================
# THEME ACCESS METHODS
# ============================================

## Get a status color by name
func get_status_color(status: String) -> Color:
	match status:
		"good", "success":
			return ThemeConstants.STATUS_GOOD
		"warning":
			return ThemeConstants.STATUS_WARNING
		"critical", "danger", "error":
			return ThemeConstants.STATUS_CRITICAL
		_:
			return ThemeConstants.STATUS_NEUTRAL


## Create a standard panel style with optional customization
func get_panel_style(corner_radius: int = ThemeConstants.RADIUS_MEDIUM) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLORS.panel_bg
	style.border_color = COLORS.border
	style.set_border_width_all(ThemeConstants.BORDER_THIN)
	style.set_corner_radius_all(corner_radius)
	style.set_content_margin_all(ThemeConstants.MARGIN_NORMAL)
	return style


## Create a pill-shaped panel style (for status pill, badges, etc.)
func get_pill_style() -> StyleBoxFlat:
	var style = get_panel_style(ThemeConstants.RADIUS_PILL)
	style.set_content_margin_all(0)
	style.content_margin_left = ThemeConstants.PADDING_LARGE
	style.content_margin_right = ThemeConstants.PADDING_LARGE
	return style


## Create a modal panel style with shadow
func get_modal_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLORS.panel_bg.darkened(0.1)
	style.border_color = COLORS.border
	style.set_border_width_all(ThemeConstants.BORDER_THIN)
	style.border_width_bottom = ThemeConstants.BORDER_NORMAL
	style.set_corner_radius_all(ThemeConstants.RADIUS_LARGE)
	style.set_content_margin_all(ThemeConstants.MARGIN_LARGE)
	style.shadow_color = ThemeConstants.SHADOW_COLOR
	style.shadow_size = ThemeConstants.SHADOW_SIZE_NORMAL
	return style


## Create a slide-in panel style (for info panels)
func get_slide_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLORS.panel_bg
	style.set_border_width_all(ThemeConstants.BORDER_THIN)
	style.border_width_left = ThemeConstants.BORDER_NORMAL
	style.border_color = COLORS.accent.darkened(0.3)
	style.set_corner_radius_all(0)
	style.corner_radius_top_left = ThemeConstants.RADIUS_LARGE
	style.corner_radius_bottom_left = ThemeConstants.RADIUS_LARGE
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = ThemeConstants.SHADOW_SIZE_NORMAL
	style.shadow_offset = Vector2(-4, 0)
	return style


## Create a button normal style
func get_button_normal_style(bg_color: Color = COLORS.panel_bg) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = COLORS.border
	style.set_border_width_all(ThemeConstants.BORDER_THIN)
	style.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
	style.set_content_margin_all(ThemeConstants.MARGIN_SMALL)
	return style


## Create a button hover style
func get_button_hover_style(base_color: Color = COLORS.panel_bg) -> StyleBoxFlat:
	var style = get_button_normal_style(base_color.lightened(0.1))
	style.border_color = COLORS.accent
	return style


## Create a button pressed style
func get_button_pressed_style(base_color: Color = COLORS.panel_bg) -> StyleBoxFlat:
	var style = get_button_normal_style(base_color.darkened(0.1))
	style.border_color = COLORS.accent
	return style


## Create an active/selected button style
func get_button_active_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLORS.accent.darkened(0.3)
	style.border_color = COLORS.accent
	style.set_border_width_all(ThemeConstants.BORDER_NORMAL)
	style.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
	style.set_content_margin_all(ThemeConstants.MARGIN_SMALL)
	return style


## Create a tooltip style
func get_tooltip_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.95)
	style.border_color = COLORS.border.lightened(0.1)
	style.set_border_width_all(ThemeConstants.BORDER_THIN)
	style.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
	style.set_content_margin_all(ThemeConstants.MARGIN_SMALL)
	style.shadow_color = ThemeConstants.SHADOW_COLOR
	style.shadow_size = ThemeConstants.SHADOW_SIZE_SMALL
	return style


## Create an input field style
func get_input_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLORS.background
	style.border_color = COLORS.border
	style.set_border_width_all(ThemeConstants.BORDER_THIN)
	style.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
	style.content_margin_left = ThemeConstants.PADDING_NORMAL
	style.content_margin_right = ThemeConstants.PADDING_NORMAL
	style.content_margin_top = ThemeConstants.PADDING_SMALL
	style.content_margin_bottom = ThemeConstants.PADDING_SMALL
	return style


## Create an input field focused style
func get_input_focus_style() -> StyleBoxFlat:
	var style = get_input_style()
	style.border_color = COLORS.accent
	return style


## Create a progress bar background style
func get_progress_bg_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLORS.background
	style.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
	return style


## Create a progress bar fill style
func get_progress_fill_style(color: Color = COLORS.accent) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
	return style


## Apply full button styling to a Button node
func apply_button_styles(button: Button, bg_color: Color = COLORS.panel_bg) -> void:
	button.add_theme_stylebox_override("normal", get_button_normal_style(bg_color))
	button.add_theme_stylebox_override("hover", get_button_hover_style(bg_color))
	button.add_theme_stylebox_override("pressed", get_button_pressed_style(bg_color))
	button.add_theme_stylebox_override("focus", get_button_hover_style(bg_color))
	button.add_theme_color_override("font_color", COLORS.text)
	button.add_theme_color_override("font_hover_color", COLORS.text)
	button.add_theme_color_override("font_pressed_color", COLORS.text)
	button.add_theme_font_size_override("font_size", ThemeConstants.FONT_NORMAL)


## Apply styling to a LineEdit/TextEdit node
func apply_input_styles(input: Control) -> void:
	input.add_theme_stylebox_override("normal", get_input_style())
	input.add_theme_stylebox_override("focus", get_input_focus_style())
	input.add_theme_color_override("font_color", COLORS.text)
	input.add_theme_color_override("caret_color", COLORS.accent)
	input.add_theme_font_size_override("font_size", ThemeConstants.FONT_NORMAL)


## Apply styling to a ProgressBar node
func apply_progress_styles(progress: ProgressBar, fill_color: Color = COLORS.accent) -> void:
	progress.add_theme_stylebox_override("background", get_progress_bg_style())
	progress.add_theme_stylebox_override("fill", get_progress_fill_style(fill_color))


## Create a separator line style
func get_separator_style(vertical: bool = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLORS.border
	if vertical:
		style.content_margin_left = 1
		style.content_margin_right = 1
	else:
		style.content_margin_top = 1
		style.content_margin_bottom = 1
	return style
