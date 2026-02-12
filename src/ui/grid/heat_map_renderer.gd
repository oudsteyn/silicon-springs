extends Node2D
class_name HeatMapRenderer
## Efficient heat map overlay using _draw() instead of ColorRect nodes
## Supports multiple data visualization modes with smooth gradients and viewport culling

# Overlay modes
enum OverlayMode {
	NONE,
	POWER,
	WATER,
	POLLUTION,
	LAND_VALUE,
	SERVICES,
	TRAFFIC,
	ZONES,
	DESIRABILITY  # Combined metric
}

# Color gradients for continuous data
const GRADIENT_POLLUTION = [
	Color(0.1, 0.5, 0.1, 0.0),   # Clean - transparent green
	Color(0.6, 0.6, 0.1, 0.3),   # Low - yellow
	Color(0.8, 0.4, 0.1, 0.4),   # Medium - orange
	Color(0.9, 0.2, 0.1, 0.5),   # High - red
	Color(0.6, 0.1, 0.3, 0.6),   # Severe - dark red/purple
]

const GRADIENT_LAND_VALUE = [
	Color(0.7, 0.2, 0.2, 0.4),   # Very low - red
	Color(0.8, 0.5, 0.2, 0.35),  # Low - orange
	Color(0.7, 0.7, 0.2, 0.3),   # Medium - yellow
	Color(0.4, 0.7, 0.3, 0.35),  # Good - light green
	Color(0.2, 0.8, 0.3, 0.4),   # High - green
	Color(0.1, 0.6, 0.5, 0.45),  # Very high - teal
]

const GRADIENT_TRAFFIC = [
	Color(0.2, 0.7, 0.3, 0.25),  # Light - green
	Color(0.6, 0.7, 0.2, 0.3),   # Moderate - yellow-green
	Color(0.8, 0.6, 0.1, 0.35),  # Heavy - yellow-orange
	Color(0.9, 0.4, 0.1, 0.4),   # Very heavy - orange
	Color(0.9, 0.2, 0.2, 0.5),   # Gridlock - red
]

const GRADIENT_DESIRABILITY = [
	Color(0.8, 0.2, 0.2, 0.4),   # Undesirable - red
	Color(0.7, 0.5, 0.2, 0.35),  # Poor - orange
	Color(0.6, 0.6, 0.3, 0.3),   # Average - yellow
	Color(0.3, 0.6, 0.4, 0.35),  # Good - green
	Color(0.2, 0.5, 0.7, 0.4),   # Excellent - blue-green
]

# Binary overlay colors
const COLOR_POWER_ON: Color = Color(1.0, 0.9, 0.2, 0.35)
const COLOR_POWER_OFF: Color = Color(0.3, 0.25, 0.1, 0.15)
const COLOR_WATER_ON: Color = Color(0.3, 0.6, 0.95, 0.35)
const COLOR_WATER_OFF: Color = Color(0.15, 0.25, 0.4, 0.15)

# Service colors (RGB channels)
const COLOR_FIRE: Color = Color(1.0, 0.3, 0.3, 0.3)
const COLOR_POLICE: Color = Color(0.3, 0.3, 1.0, 0.3)
const COLOR_EDUCATION: Color = Color(0.3, 1.0, 0.3, 0.3)
const COLOR_HEALTH: Color = Color(1.0, 0.3, 1.0, 0.3)

# Legend configuration - linked to theme system
const LEGEND_WIDTH: float = 180.0
const LEGEND_HEIGHT: float = 140.0
const LEGEND_MARGIN: float = 16.0
const LEGEND_PADDING: float = 12.0
const LEGEND_BAR_HEIGHT: float = 16.0
const LEGEND_FONT_SIZE: int = 11
const LEGEND_TITLE_SIZE: int = 13

## Legend colors derived from UI theme for consistency
static var LEGEND_BG_COLOR: Color:
	get: return Color(0.08, 0.10, 0.14, 0.92)  # Matches UIManager panel_bg
static var LEGEND_BORDER_COLOR: Color:
	get: return Color(0.25, 0.30, 0.38, 0.85)  # Matches UIManager border
static var LEGEND_TEXT_COLOR: Color:
	get: return Color(0.85, 0.88, 0.92)  # Matches ThemeConstants TEXT_PRIMARY
static var LEGEND_TEXT_DIM_COLOR: Color:
	get: return Color(0.60, 0.65, 0.75)  # Matches ThemeConstants TEXT_SECONDARY

# State
var current_mode: OverlayMode = OverlayMode.NONE
var _target_mode: OverlayMode = OverlayMode.NONE
var _transition_progress: float = 1.0
var _transition_speed: float = 5.0  # 0.2s transitions (matches ThemeConstants.ANIM_PANEL_SLIDE)

# Cached data
var _cell_values: Dictionary = {}  # Vector2i -> float (0-1 normalized)
var _cell_colors: Dictionary = {}  # Vector2i -> Color (for services)
var _data_dirty: bool = true

# Viewport culling
var _visible_rect: Rect2i = Rect2i()
var _camera: Camera2D = null

# System references
var power_system = null
var water_system = null
var pollution_system = null
var land_value_system = null
var service_coverage = null
var traffic_system = null
var zoning_system = null
var grid_system = null

# Legend state
var _show_legend: bool = true
var _legend_position: Vector2 = Vector2.ZERO  # Calculated based on viewport
var _events: Node = null


func _ready() -> void:
	z_index = 4  # Above terrain, below buildings
	visible = false

	# Connect to update events
	var events = _get_events()
	if events:
		events.power_updated.connect(_on_data_updated)
		events.water_updated.connect(_on_data_updated)
		events.pollution_updated.connect(_on_data_updated)
		events.coverage_updated.connect(_on_coverage_updated)
		events.month_tick.connect(_on_month_tick)


func set_events(events: Node) -> void:
	_events = events


func _get_events() -> Node:
	if _events:
		return _events
	var tree = get_tree()
	if tree:
		return tree.root.get_node_or_null("Events")
	return null


func set_camera(cam: Camera2D) -> void:
	_camera = cam


func set_systems(power, water, pollution, land_value, services, traffic, zoning, grid) -> void:
	power_system = power
	water_system = water
	pollution_system = pollution
	land_value_system = land_value
	service_coverage = services
	traffic_system = traffic
	zoning_system = zoning
	grid_system = grid


func _process(delta: float) -> void:
	if current_mode == OverlayMode.NONE and _target_mode == OverlayMode.NONE:
		return

	# Handle mode transition
	if _transition_progress < 1.0:
		_transition_progress = minf(_transition_progress + delta * _transition_speed, 1.0)
		if _transition_progress >= 0.5 and current_mode != _target_mode:
			current_mode = _target_mode
			_data_dirty = true

	# Update visible area
	_update_visible_area()

	# Rebuild data if dirty
	if _data_dirty:
		_rebuild_cell_data()

	queue_redraw()


func _update_visible_area() -> void:
	if not _camera:
		_visible_rect = Rect2i(0, 0, GridConstants.GRID_WIDTH, GridConstants.GRID_HEIGHT)
		return

	var viewport_size = get_viewport_rect().size
	var half_size = viewport_size / (2.0 * _camera.zoom.x)
	var padding = GridConstants.CELL_SIZE * 2

	var min_x = maxi(0, int((_camera.position.x - half_size.x - padding) / GridConstants.CELL_SIZE))
	var min_y = maxi(0, int((_camera.position.y - half_size.y - padding) / GridConstants.CELL_SIZE))
	var max_x = mini(GridConstants.GRID_WIDTH, int((_camera.position.x + half_size.x + padding) / GridConstants.CELL_SIZE) + 1)
	var max_y = mini(GridConstants.GRID_HEIGHT, int((_camera.position.y + half_size.y + padding) / GridConstants.CELL_SIZE) + 1)

	_visible_rect = Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)

	# Calculate legend position (bottom-right of viewport, in world coordinates)
	var viewport_br = _camera.position + half_size
	_legend_position = viewport_br - Vector2(LEGEND_WIDTH + LEGEND_MARGIN, LEGEND_HEIGHT + LEGEND_MARGIN)


func _rebuild_cell_data() -> void:
	_cell_values.clear()
	_cell_colors.clear()

	match current_mode:
		OverlayMode.POWER:
			_build_power_data()
		OverlayMode.WATER:
			_build_water_data()
		OverlayMode.POLLUTION:
			_build_pollution_data()
		OverlayMode.LAND_VALUE:
			_build_land_value_data()
		OverlayMode.SERVICES:
			_build_services_data()
		OverlayMode.TRAFFIC:
			_build_traffic_data()
		OverlayMode.ZONES:
			_build_zones_data()
		OverlayMode.DESIRABILITY:
			_build_desirability_data()

	_data_dirty = false


func _build_power_data() -> void:
	if not power_system:
		return
	var powered = power_system.get_powered_cells()
	for cell in powered:
		_cell_values[cell] = 1.0


func _build_water_data() -> void:
	if not water_system:
		return
	var watered = water_system.get_watered_cells()
	for cell in watered:
		_cell_values[cell] = 1.0


func _build_pollution_data() -> void:
	if not pollution_system:
		return
	var pollution_map = pollution_system.get_pollution_map()
	for cell in pollution_map:
		_cell_values[cell] = clampf(pollution_map[cell], 0.0, 1.0)


func _build_land_value_data() -> void:
	if not land_value_system:
		return
	var lv_map = land_value_system.get_land_value_map()
	for cell in lv_map:
		_cell_values[cell] = clampf(lv_map[cell], 0.0, 1.0)


func _build_services_data() -> void:
	if not service_coverage:
		return

	# Combine service coverages into RGB
	var combined: Dictionary = {}

	# Fire coverage -> Red
	for cell in service_coverage.fire_coverage:
		if not combined.has(cell):
			combined[cell] = Color(0, 0, 0, 0)
		combined[cell].r = 0.8

	# Police coverage -> Blue
	for cell in service_coverage.police_coverage:
		if not combined.has(cell):
			combined[cell] = Color(0, 0, 0, 0)
		combined[cell].b = 0.8

	# Education coverage -> Green
	for cell in service_coverage.education_coverage:
		if not combined.has(cell):
			combined[cell] = Color(0, 0, 0, 0)
		combined[cell].g = 0.8

	for cell in combined:
		var c = combined[cell]
		c.a = 0.35
		_cell_colors[cell] = c


func _build_traffic_data() -> void:
	if not traffic_system:
		return
	var traffic_map = traffic_system.get_traffic_map()
	for cell in traffic_map:
		var congestion = traffic_system.get_congestion_at(cell)
		_cell_values[cell] = clampf(congestion, 0.0, 1.0)


func _build_zones_data() -> void:
	if not zoning_system:
		return
	var zones = zoning_system.get_all_zones()
	for cell in zones:
		var zone_data = zones[cell]
		var color = zoning_system.get_zone_color(zone_data.type)
		color.a = 0.5
		_cell_colors[cell] = color


func _build_desirability_data() -> void:
	# Combined metric from multiple factors
	if not grid_system:
		return

	for x in range(_visible_rect.position.x, _visible_rect.position.x + _visible_rect.size.x):
		for y in range(_visible_rect.position.y, _visible_rect.position.y + _visible_rect.size.y):
			var cell = Vector2i(x, y)
			var desirability = _calculate_desirability(cell)
			if desirability > 0.01:
				_cell_values[cell] = desirability


func _calculate_desirability(cell: Vector2i) -> float:
	var score = 0.5  # Base score

	# Land value contribution (40%)
	if land_value_system:
		score += (land_value_system.get_land_value_at(cell) - 0.5) * 0.4

	# Pollution penalty (20%)
	if pollution_system:
		score -= pollution_system.get_pollution_at(cell) * 0.2

	# Traffic penalty (15%)
	if traffic_system:
		score -= traffic_system.get_congestion_at(cell) * 0.15

	# Service coverage bonus (25%)
	if service_coverage:
		var service_score = 0.0
		if service_coverage.has_fire_coverage(cell):
			service_score += 0.33
		if service_coverage.has_police_coverage(cell):
			service_score += 0.33
		if service_coverage.has_education_coverage(cell):
			service_score += 0.34
		score += service_score * 0.25

	return clampf(score, 0.0, 1.0)


func _draw() -> void:
	if current_mode == OverlayMode.NONE:
		return

	# Calculate transition alpha
	var alpha_mult = 1.0
	if _transition_progress < 1.0:
		# Fade out then in
		if _transition_progress < 0.5:
			alpha_mult = 1.0 - (_transition_progress * 2.0)
		else:
			alpha_mult = (_transition_progress - 0.5) * 2.0

	# Draw cells
	_draw_heat_map_cells(alpha_mult)

	# Draw legend
	if _show_legend:
		_draw_legend(alpha_mult)


func _draw_heat_map_cells(alpha_mult: float) -> void:
	var use_colors = current_mode in [OverlayMode.SERVICES, OverlayMode.ZONES]

	for x in range(_visible_rect.position.x, _visible_rect.position.x + _visible_rect.size.x):
		for y in range(_visible_rect.position.y, _visible_rect.position.y + _visible_rect.size.y):
			var cell = Vector2i(x, y)
			var color: Color

			if use_colors:
				if not _cell_colors.has(cell):
					continue
				color = _cell_colors[cell]
			else:
				if not _cell_values.has(cell):
					# For binary modes, show "off" state
					if current_mode == OverlayMode.POWER:
						color = COLOR_POWER_OFF
					elif current_mode == OverlayMode.WATER:
						color = COLOR_WATER_OFF
					else:
						continue
				else:
					color = _get_gradient_color(_cell_values[cell])

			color.a *= alpha_mult
			var rect = Rect2(Vector2(cell) * GridConstants.CELL_SIZE, Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE))
			draw_rect(rect, color)


func _get_gradient_color(value: float) -> Color:
	var gradient: Array
	match current_mode:
		OverlayMode.POWER:
			return COLOR_POWER_ON if value > 0.5 else COLOR_POWER_OFF
		OverlayMode.WATER:
			return COLOR_WATER_ON if value > 0.5 else COLOR_WATER_OFF
		OverlayMode.POLLUTION:
			gradient = GRADIENT_POLLUTION
		OverlayMode.LAND_VALUE:
			gradient = GRADIENT_LAND_VALUE
		OverlayMode.TRAFFIC:
			gradient = GRADIENT_TRAFFIC
		OverlayMode.DESIRABILITY:
			gradient = GRADIENT_DESIRABILITY
		_:
			return Color(value, value, value, 0.3)

	# Interpolate through gradient
	var segments = gradient.size() - 1
	var segment_value = value * segments
	var segment_index = mini(int(segment_value), segments - 1)
	var segment_t = segment_value - segment_index

	return gradient[segment_index].lerp(gradient[segment_index + 1], segment_t)


func _draw_legend(alpha_mult: float) -> void:
	var pos = _legend_position

	# Background
	var bg_color = LEGEND_BG_COLOR
	bg_color.a *= alpha_mult
	var border_color = LEGEND_BORDER_COLOR
	border_color.a *= alpha_mult

	draw_rect(Rect2(pos, Vector2(LEGEND_WIDTH, LEGEND_HEIGHT)), bg_color)
	draw_rect(Rect2(pos, Vector2(LEGEND_WIDTH, LEGEND_HEIGHT)), border_color, false, 1.5)

	var font = ThemeDB.fallback_font
	var text_color = Color(0.9, 0.9, 0.9, alpha_mult)
	var y_offset = LEGEND_PADDING

	# Title
	var title = _get_mode_name(current_mode)
	draw_string(font, pos + Vector2(LEGEND_PADDING, y_offset + LEGEND_TITLE_SIZE),
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_TITLE_SIZE, text_color)
	y_offset += LEGEND_TITLE_SIZE + 12

	# Draw gradient bar or legend items based on mode
	if current_mode in [OverlayMode.SERVICES]:
		_draw_service_legend(pos, y_offset, alpha_mult, font)
	elif current_mode in [OverlayMode.ZONES]:
		_draw_zone_legend(pos, y_offset, alpha_mult, font)
	elif current_mode in [OverlayMode.POWER, OverlayMode.WATER]:
		_draw_binary_legend(pos, y_offset, alpha_mult, font)
	else:
		_draw_gradient_legend(pos, y_offset, alpha_mult, font)


func _draw_gradient_legend(pos: Vector2, y_offset: float, alpha_mult: float, font: Font) -> void:
	var bar_pos = pos + Vector2(LEGEND_PADDING, y_offset)
	var bar_width = LEGEND_WIDTH - LEGEND_PADDING * 2

	# Draw gradient bar
	var segments = 20
	var segment_width = bar_width / segments
	for i in range(segments):
		var t = float(i) / (segments - 1)
		var color = _get_gradient_color(t)
		color.a *= alpha_mult
		draw_rect(Rect2(bar_pos + Vector2(i * segment_width, 0),
			Vector2(segment_width + 1, LEGEND_BAR_HEIGHT)), color)

	# Border around gradient bar
	draw_rect(Rect2(bar_pos, Vector2(bar_width, LEGEND_BAR_HEIGHT)),
		Color(0.5, 0.5, 0.5, alpha_mult), false, 1.0)

	# Labels
	var label_y = y_offset + LEGEND_BAR_HEIGHT + 4 + LEGEND_FONT_SIZE
	var text_color = Color(0.8, 0.8, 0.8, alpha_mult)

	var low_label = "Low"
	var high_label = "High"
	match current_mode:
		OverlayMode.POLLUTION:
			low_label = "Clean"
			high_label = "Polluted"
		OverlayMode.LAND_VALUE:
			low_label = "Low $"
			high_label = "High $"
		OverlayMode.TRAFFIC:
			low_label = "Light"
			high_label = "Gridlock"
		OverlayMode.DESIRABILITY:
			low_label = "Poor"
			high_label = "Excellent"

	draw_string(font, pos + Vector2(LEGEND_PADDING, label_y),
		low_label, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, text_color)

	var high_width = font.get_string_size(high_label, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE).x
	draw_string(font, pos + Vector2(LEGEND_WIDTH - LEGEND_PADDING - high_width, label_y),
		high_label, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, text_color)


func _draw_binary_legend(pos: Vector2, y_offset: float, alpha_mult: float, font: Font) -> void:
	var on_color: Color
	var off_color: Color
	var on_label: String
	var off_label: String

	match current_mode:
		OverlayMode.POWER:
			on_color = COLOR_POWER_ON
			off_color = COLOR_POWER_OFF
			on_label = "Powered"
			off_label = "No Power"
		OverlayMode.WATER:
			on_color = COLOR_WATER_ON
			off_color = COLOR_WATER_OFF
			on_label = "Water"
			off_label = "No Water"

	var text_color = Color(0.8, 0.8, 0.8, alpha_mult)
	var swatch_size = 16.0

	# On state
	on_color.a *= alpha_mult
	draw_rect(Rect2(pos + Vector2(LEGEND_PADDING, y_offset), Vector2(swatch_size, swatch_size)), on_color)
	draw_string(font, pos + Vector2(LEGEND_PADDING + swatch_size + 8, y_offset + LEGEND_FONT_SIZE),
		on_label, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, text_color)

	y_offset += swatch_size + 8

	# Off state
	off_color.a *= alpha_mult
	draw_rect(Rect2(pos + Vector2(LEGEND_PADDING, y_offset), Vector2(swatch_size, swatch_size)), off_color)
	draw_string(font, pos + Vector2(LEGEND_PADDING + swatch_size + 8, y_offset + LEGEND_FONT_SIZE),
		off_label, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, text_color)


func _draw_service_legend(pos: Vector2, y_offset: float, alpha_mult: float, font: Font) -> void:
	var services = [
		{"color": COLOR_FIRE, "label": "Fire"},
		{"color": COLOR_POLICE, "label": "Police"},
		{"color": COLOR_EDUCATION, "label": "Education"},
	]

	var text_color = Color(0.8, 0.8, 0.8, alpha_mult)
	var swatch_size = 14.0

	for service in services:
		var color = service.color
		color.a *= alpha_mult
		draw_rect(Rect2(pos + Vector2(LEGEND_PADDING, y_offset), Vector2(swatch_size, swatch_size)), color)
		draw_string(font, pos + Vector2(LEGEND_PADDING + swatch_size + 8, y_offset + LEGEND_FONT_SIZE - 2),
			service.label, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, text_color)
		y_offset += swatch_size + 6


func _draw_zone_legend(pos: Vector2, y_offset: float, alpha_mult: float, font: Font) -> void:
	if not zoning_system:
		return

	var zones = [
		{"type": 1, "label": "Res"},  # RESIDENTIAL_LOW
		{"type": 4, "label": "Com"},  # COMMERCIAL_LOW
		{"type": 7, "label": "Ind"},  # INDUSTRIAL_LOW
	]

	var text_color = Color(0.8, 0.8, 0.8, alpha_mult)
	var swatch_size = 14.0

	for zone in zones:
		var color = zoning_system.get_zone_color(zone.type)
		color.a = 0.6 * alpha_mult
		draw_rect(Rect2(pos + Vector2(LEGEND_PADDING, y_offset), Vector2(swatch_size, swatch_size)), color)
		draw_string(font, pos + Vector2(LEGEND_PADDING + swatch_size + 8, y_offset + LEGEND_FONT_SIZE - 2),
			zone.label, HORIZONTAL_ALIGNMENT_LEFT, -1, LEGEND_FONT_SIZE, text_color)
		y_offset += swatch_size + 6


func _get_mode_name(mode: OverlayMode) -> String:
	match mode:
		OverlayMode.POWER: return "Power Grid"
		OverlayMode.WATER: return "Water Network"
		OverlayMode.POLLUTION: return "Pollution"
		OverlayMode.LAND_VALUE: return "Land Value"
		OverlayMode.SERVICES: return "Services"
		OverlayMode.TRAFFIC: return "Traffic"
		OverlayMode.ZONES: return "Zoning"
		OverlayMode.DESIRABILITY: return "Desirability"
		_: return "None"


# Public API
func set_overlay_mode(mode: OverlayMode) -> void:
	var events = _get_events()
	if current_mode == mode:
		# Toggle off
		_target_mode = OverlayMode.NONE
		_transition_progress = 0.0
		if events:
			events.simulation_event.emit("overlay_changed", {"mode": "Off"})
		return

	_target_mode = mode
	_transition_progress = 0.0
	visible = true

	if current_mode == OverlayMode.NONE:
		current_mode = mode
		_data_dirty = true

	if events:
		events.simulation_event.emit("overlay_changed", {"mode": _get_mode_name(mode)})


func get_current_mode() -> OverlayMode:
	return current_mode


func toggle_power() -> void:
	set_overlay_mode(OverlayMode.POWER)


func toggle_water() -> void:
	set_overlay_mode(OverlayMode.WATER)


func toggle_pollution() -> void:
	set_overlay_mode(OverlayMode.POLLUTION)


func toggle_land_value() -> void:
	set_overlay_mode(OverlayMode.LAND_VALUE)


func toggle_services() -> void:
	set_overlay_mode(OverlayMode.SERVICES)


func toggle_traffic() -> void:
	set_overlay_mode(OverlayMode.TRAFFIC)


func toggle_zones() -> void:
	set_overlay_mode(OverlayMode.ZONES)


func toggle_desirability() -> void:
	set_overlay_mode(OverlayMode.DESIRABILITY)


func cycle_overlay() -> void:
	var next = (current_mode + 1) % OverlayMode.size()
	set_overlay_mode(next as OverlayMode)


func set_legend_visible(should_show: bool) -> void:
	_show_legend = should_show


func refresh() -> void:
	_data_dirty = true


# Event handlers
func _on_data_updated(_a = null, _b = null) -> void:
	if current_mode != OverlayMode.NONE:
		_data_dirty = true


func _on_coverage_updated(_service_type: String) -> void:
	if current_mode == OverlayMode.SERVICES:
		_data_dirty = true


func _on_month_tick() -> void:
	# Refresh data periodically
	if current_mode != OverlayMode.NONE:
		_data_dirty = true
