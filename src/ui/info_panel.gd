extends PanelContainer
class_name InfoPanel
## Displays information about selected buildings or tiles
## Slides in from right edge, 300px wide, with modern styling

const PANEL_WIDTH: int = 300
const SLIDE_DURATION: float = 0.2
const OFFSCREEN_OFFSET: int = 320  # Width + margin for slide animation

@onready var title_label: Label = $MarginContainer/VBox/TitleLabel
@onready var content_container: VBoxContainer = $MarginContainer/VBox/ContentContainer
@onready var close_button: Button = $MarginContainer/VBox/CloseButton

var current_building = null  # Building

# Pending info request tracking
var _pending_building_info: Node2D = null

# Animation state
var _slide_tween: Tween = null
var _is_visible: bool = false
var _events: Node = null


func set_events(events: Node) -> void:
	_events = events


func _get_events() -> Node:
	if _events:
		return _events
	var tree = get_tree()
	if tree:
		return tree.root.get_node_or_null("Events")
	return null


func _ready() -> void:
	visible = false
	_setup_modern_style()
	close_button.pressed.connect(_on_close_pressed)
	var events = _get_events()
	if events:
		events.building_selected.connect(_on_building_selected)
		events.building_deselected.connect(_on_building_deselected)

	# Connect to query response signals (decoupled from systems)
	if events:
		events.building_info_ready.connect(_on_building_info_ready)
		events.cell_info_ready.connect(_on_cell_info_ready)

	# Position panel off-screen to the right
	_set_offscreen_position()


func _exit_tree() -> void:
	# Clean up slide tween
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
		_slide_tween = null


func _setup_modern_style() -> void:
	# Apply modern panel style using centralized theme
	var style = UIManager.get_slide_panel_style()
	add_theme_stylebox_override("panel", style)

	# Style close button using centralized theme
	if close_button:
		close_button.text = "Close"
		var btn_style = UIManager.get_button_normal_style(UIManager.COLORS.panel_bg.lightened(0.05))
		close_button.add_theme_stylebox_override("normal", btn_style)

		var btn_hover = UIManager.get_button_hover_style()
		btn_hover.bg_color = UIManager.COLORS.danger.darkened(0.3)
		btn_hover.border_color = UIManager.COLORS.danger
		close_button.add_theme_stylebox_override("hover", btn_hover)

		close_button.add_theme_color_override("font_color", UIManager.COLORS.text)

	# Style title using centralized theme constants
	if title_label:
		title_label.add_theme_color_override("font_color", UIManager.COLORS.text)
		title_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_LARGE)


func _set_offscreen_position() -> void:
	# Position on right edge, but offscreen
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0
	anchor_bottom = 1.0
	offset_left = 10  # Offscreen (positive = past right edge)
	offset_right = 10 + PANEL_WIDTH
	offset_top = 70
	offset_bottom = -70


func _set_onscreen_position() -> void:
	offset_left = -PANEL_WIDTH - 10
	offset_right = -10


func _on_building_selected(building: Node2D) -> void:
	if building and building.has_method("get_info"):
		current_building = building
		_pending_building_info = building
		# Request info via signal - GameWorld will aggregate and respond
		var events = _get_events()
		if events:
			events.building_info_requested.emit(building)
		_slide_in()


func _on_building_info_ready(building: Node2D, info: Dictionary) -> void:
	# Only process if this is the building we're waiting for
	if building != _pending_building_info:
		return
	_pending_building_info = null
	_display_building_info(info)


func _on_cell_info_ready(cell: Vector2i, info: Dictionary) -> void:
	_display_cell_info(cell, info)


func _on_building_deselected() -> void:
	current_building = null
	_slide_out()


func _slide_in() -> void:
	if _is_visible:
		return

	_is_visible = true
	visible = true

	# Register as modal to hide tooltips
	UIManager.open_panel("info")

	# Cancel any existing animation
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()

	# Start from offscreen
	_set_offscreen_position()

	# Animate to onscreen
	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_OUT)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_property(self, "offset_left", -PANEL_WIDTH - 10, SLIDE_DURATION)
	_slide_tween.parallel().tween_property(self, "offset_right", -10, SLIDE_DURATION)


func _slide_out() -> void:
	if not _is_visible:
		return

	_is_visible = false

	# Unregister from modal state
	UIManager.close_panel("info")

	# Cancel any existing animation
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()

	# Animate to offscreen
	_slide_tween = create_tween()
	_slide_tween.set_ease(Tween.EASE_IN)
	_slide_tween.set_trans(Tween.TRANS_CUBIC)
	_slide_tween.tween_property(self, "offset_left", 10, SLIDE_DURATION)
	_slide_tween.parallel().tween_property(self, "offset_right", 10 + PANEL_WIDTH, SLIDE_DURATION)
	_slide_tween.tween_callback(func(): visible = false)


func _display_building_info(info: Dictionary) -> void:
	# Clear existing content
	for child in content_container.get_children():
		child.queue_free()

	var cell = info.get("cell", Vector2i.ZERO)

	title_label.text = info.get("name", "Unknown")

	# Add info rows
	_add_info_row("Category", info.get("category", "").capitalize())
	_add_info_row("Position", "(%d, %d)" % [cell.x, cell.y])

	# Development level (for zones)
	var is_zone = info.get("building_type", "") in ["residential", "commercial", "industrial", "agricultural", "mixed_use"]
	if info.has("development_level") and info.development_level > 0:
		var level_text = "Level %d" % info.development_level
		if info.development_level < 3 and info.has("development_progress"):
			level_text += " (%.0f%%)" % info.development_progress
		_add_info_row("Development", level_text)

	# Status with diagnostics
	var operational = info.get("operational", true)
	var status = "Operational" if operational else "Offline"
	var status_color = UIManager.COLORS.success if operational else UIManager.COLORS.danger
	_add_info_row("Status", status, status_color)

	# Detailed diagnostics if not operational
	if not operational:
		_add_separator()
		_add_section_header("Problems:")

		if not info.get("powered", true):
			_add_diagnostic("No power connection", "Build power lines or connect to power grid")

		if not info.get("watered", true):
			_add_diagnostic("No water connection", "Build water pipes or connect to water network")

		var building_health = info.get("health", 100)
		if building_health <= 0:
			_add_diagnostic("Building destroyed", "Demolish and rebuild")

	# Zone development diagnostics (why won't this zone develop?)
	if is_zone:
		_display_zone_diagnostics(info)

	# Health
	var current_health = info.get("health", 100)
	if current_health < 100 and current_health > 0:
		var health_color = UIManager.COLORS.danger if current_health < 50 else UIManager.COLORS.warning
		_add_info_row("Health", "%d%%" % current_health, health_color)

	# Maintenance
	var maintenance = info.get("maintenance", 0)
	if maintenance > 0:
		_add_info_row("Maintenance", "$%d/mo" % maintenance)

	# Resource production/consumption
	if info.has("power_production") and info.power_production > 0:
		_add_info_row("Power Output", "+%d MW" % int(info.power_production), UIManager.COLORS.success)
	if info.has("power_consumption") and info.power_consumption > 0:
		_add_info_row("Power Usage", "-%d MW" % int(info.power_consumption), UIManager.COLORS.warning)
	if info.has("water_production") and info.water_production > 0:
		_add_info_row("Water Output", "+%d ML" % int(info.water_production), UIManager.COLORS.success)
	if info.has("water_consumption") and info.water_consumption > 0:
		_add_info_row("Water Usage", "-%d ML" % int(info.water_consumption), UIManager.COLORS.warning)

	# Service coverage
	if info.has("coverage_radius") and info.coverage_radius > 0:
		_add_info_row("Coverage", "%d tiles (%s)" % [info.coverage_radius, info.service_type.capitalize()])

	# Environmental info (now from aggregated query response)
	_add_separator()
	_add_section_header("Environment:")

	# Pollution (from query response)
	var pollution = info.get("pollution", 0.0)
	var pollution_text = "None"
	var pollution_color = UIManager.COLORS.success
	if pollution > 0.6:
		pollution_text = "Severe"
		pollution_color = UIManager.COLORS.danger
	elif pollution > 0.3:
		pollution_text = "Moderate"
		pollution_color = UIManager.COLORS.warning
	elif pollution > 0.1:
		pollution_text = "Light"
		pollution_color = UIManager.COLORS.text
	_add_info_row("Pollution", pollution_text, pollution_color)

	# Land value (from query response)
	var land_value = info.get("land_value", 0.5)
	var value_text = "Low"
	var value_color = UIManager.COLORS.danger
	if land_value > 0.7:
		value_text = "High"
		value_color = UIManager.COLORS.success
	elif land_value > 0.5:
		value_text = "Medium"
		value_color = UIManager.COLORS.warning
	_add_info_row("Land Value", value_text, value_color)


func _add_info_row(label_text: String, value_text: String, value_color: Color = UIManager.COLORS.text) -> Label:
	var hbox = HBoxContainer.new()

	var label = Label.new()
	label.text = label_text + ":"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	label.add_theme_font_size_override("font_size", 13)
	hbox.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_color_override("font_color", value_color)
	value.add_theme_font_size_override("font_size", 13)
	hbox.add_child(value)

	content_container.add_child(hbox)
	return value


func _add_separator() -> void:
	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", UIManager.COLORS.border)
	content_container.add_child(sep)


func _add_section_header(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UIManager.COLORS.accent)
	label.add_theme_font_size_override("font_size", 12)
	content_container.add_child(label)


func _add_diagnostic(problem: String, solution: String) -> void:
	var vbox = VBoxContainer.new()

	var problem_label = Label.new()
	problem_label.text = "- " + problem
	problem_label.add_theme_color_override("font_color", UIManager.COLORS.danger)
	problem_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(problem_label)

	var solution_label = Label.new()
	solution_label.text = "  Fix: " + solution
	solution_label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	solution_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(solution_label)

	content_container.add_child(vbox)


func _on_close_pressed() -> void:
	if current_building:
		current_building.set_selected(false)
	var events = _get_events()
	if events:
		events.building_deselected.emit()


func show_cell_info(cell: Vector2i) -> void:
	# Request cell info via signal - GameWorld will aggregate and respond
	var events = _get_events()
	if events:
		events.cell_info_requested.emit(cell)
	_slide_in()


func _display_cell_info(cell: Vector2i, info: Dictionary) -> void:
	# Clear existing content
	for child in content_container.get_children():
		child.queue_free()

	title_label.text = "Cell (%d, %d)" % [cell.x, cell.y]

	# Service Coverage
	var coverage = info.get("coverage", {})
	_add_section_header("Service Coverage:")
	var fire_color = UIManager.COLORS.success if coverage.get("fire", false) else UIManager.COLORS.danger
	var police_color = UIManager.COLORS.success if coverage.get("police", false) else UIManager.COLORS.danger
	var edu_color = UIManager.COLORS.success if coverage.get("education", false) else UIManager.COLORS.danger
	_add_info_row("Fire", "Yes" if coverage.get("fire", false) else "No", fire_color)
	_add_info_row("Police", "Yes" if coverage.get("police", false) else "No", police_color)
	_add_info_row("Education", "Yes" if coverage.get("education", false) else "No", edu_color)

	# Utilities
	_add_separator()
	_add_section_header("Utilities:")

	var has_power = info.get("has_power", false)
	var power_color = UIManager.COLORS.success if has_power else UIManager.COLORS.danger
	_add_info_row("Power", "Connected" if has_power else "Not connected", power_color)

	var has_water = info.get("has_water", false)
	var water_color = UIManager.COLORS.success if has_water else UIManager.COLORS.danger
	_add_info_row("Water", "Connected" if has_water else "Not connected", water_color)

	# Environment
	_add_separator()
	_add_section_header("Environment:")

	var pollution = info.get("pollution", 0.0)
	var pollution_text = "Clean" if pollution < 0.1 else "%.0f%%" % (pollution * 100)
	var pollution_color = UIManager.COLORS.success if pollution < 0.1 else (UIManager.COLORS.warning if pollution < 0.5 else UIManager.COLORS.danger)
	_add_info_row("Pollution", pollution_text, pollution_color)

	var land_value = info.get("land_value", 0.5)
	_add_info_row("Land Value", "%.0f%%" % (land_value * 100))

	var congestion = info.get("congestion", 0.0)
	if congestion > 0:
		var traffic_text = "Light" if congestion < 0.3 else ("Moderate" if congestion < 0.6 else "Heavy")
		var traffic_color = UIManager.COLORS.success if congestion < 0.3 else (UIManager.COLORS.warning if congestion < 0.6 else UIManager.COLORS.danger)
		_add_info_row("Traffic", traffic_text, traffic_color)


func _input(event: InputEvent) -> void:
	# ESC closes the panel
	if _is_visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
		get_viewport().set_input_as_handled()


func _display_zone_diagnostics(info: Dictionary) -> void:
	var zone_type = info.get("building_type", "")
	if zone_type.is_empty():
		return

	# Get demand for this zone type
	var demand = 0.0
	match zone_type:
		"residential":
			demand = GameState.residential_demand
		"commercial":
			demand = GameState.commercial_demand
		"industrial":
			demand = GameState.industrial_demand
		"agricultural":
			demand = max(0.2, GameState.industrial_demand)

	# Run zone diagnostic
	var diagnostic = ZoneDiagnostic.diagnose(
		zone_type,
		info.get("powered", false),
		info.get("watered", false),
		info.get("has_road", true),  # Assume road access if not specified
		info.get("pollution", 0.0),
		GameState.city_crime_rate,
		info.get("congestion", GameState.city_traffic_congestion),
		info.get("land_value", 0.5),
		info.get("near_incompatible", false),
		demand,
		info.get("development_level", 0),
		info.get("under_construction", false)
	)

	# Only show diagnostics if there are issues
	if diagnostic.issues.size() == 0:
		return

	_add_separator()
	_add_section_header("Development Status:")

	# Overall status
	var status_text = diagnostic.overall_status.capitalize()
	var status_color = ZoneDiagnostic.get_status_color(diagnostic)
	_add_info_row("Status", status_text, status_color)

	# Development rate
	if diagnostic.development_rate < 1.0:
		var rate_text = "%.0f%%" % (diagnostic.development_rate * 100)
		var rate_color = UIManager.COLORS.success if diagnostic.development_rate > 0.7 else (UIManager.COLORS.warning if diagnostic.development_rate > 0.3 else UIManager.COLORS.danger)
		_add_info_row("Dev. Speed", rate_text, rate_color)

	# Show issues (limit to top 3)
	var issues_to_show = diagnostic.issues.slice(0, mini(3, diagnostic.issues.size()))
	for issue in issues_to_show:
		_add_diagnostic(issue.problem, issue.solution)
