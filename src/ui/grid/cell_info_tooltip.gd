extends Control
class_name CellInfoTooltip
## Smart hover tooltip showing contextual cell and building information
## Displays terrain, building details, zone data, utilities, and land value


# Visual configuration
const TOOLTIP_WIDTH: float = 220.0
const MAX_TOOLTIP_HEIGHT: float = 300.0
const PADDING: Vector2 = Vector2(12, 10)
const LINE_HEIGHT: float = 18.0
const SECTION_SPACING: float = 8.0
const CORNER_RADIUS: float = 6.0
const BORDER_WIDTH: float = 1.5
const HEADER_FONT_SIZE: int = 14
const BODY_FONT_SIZE: int = 11
const BAR_VALUE_FONT_SIZE: int = 10
const VALUE_COLUMN_WIDTH: float = 84.0
const ROW_COLUMN_GAP: float = 8.0

# Colors
const BG_COLOR: Color = Color(0.08, 0.1, 0.08, 0.95)
const BORDER_COLOR: Color = Color(0.3, 0.4, 0.3, 0.9)
const HEADER_COLOR: Color = Color(0.85, 0.9, 0.85, 1.0)
const TEXT_COLOR: Color = Color(0.7, 0.75, 0.7, 1.0)
const LABEL_COLOR: Color = Color(0.5, 0.55, 0.5, 0.9)
const POSITIVE_COLOR: Color = Color(0.3, 0.8, 0.4, 1.0)
const NEGATIVE_COLOR: Color = Color(0.9, 0.35, 0.3, 1.0)
const WARNING_COLOR: Color = Color(0.9, 0.7, 0.2, 1.0)

const FADE_DURATION: float = 0.15

# System references
var camera: Camera2D = null
var grid_system = null
var terrain_system = null
var power_system = null
var water_system = null
var pollution_system = null
var land_value_system = null
var service_coverage = null
var zoning_system = null
var traffic_system = null

# State
var _current_cell: Vector2i = Vector2i(-1, -1)
var _is_visible: bool = false
var _alpha: float = 0.0
var _tooltip_content: Array[Dictionary] = []  # [{type, label, value, color}]
var _tooltip_height: float = 0.0
var _building_at_cell = null
var _events: Node = null
var _blocked_controls: Array[Control] = []



func _ready() -> void:
	# Position above everything
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	visible = false


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
	camera = cam


func set_systems(gs, ts, ps, ws, polls, lvs, sc, zs, trs) -> void:
	grid_system = gs
	terrain_system = ts
	power_system = ps
	water_system = ws
	pollution_system = polls
	land_value_system = lvs
	service_coverage = sc
	zoning_system = zs
	traffic_system = trs


func set_blocked_controls(controls: Array[Control]) -> void:
	_blocked_controls = controls


func _process(delta: float) -> void:
	if not camera:
		return

	# Hide tooltip immediately when modal dialogs are open
	if UIManager.is_modal_open():
		if _is_visible:
			_hide_tooltip()
		_alpha = 0.0
		modulate.a = 0.0
		visible = false
		return

	# Handle fade animation
	if _is_visible:
		_alpha = minf(_alpha + delta / FADE_DURATION, 1.0)
	else:
		_alpha = maxf(_alpha - delta / FADE_DURATION, 0.0)

	modulate.a = _alpha
	visible = _alpha > 0.01

	if visible:
		_update_position()
		queue_redraw()


func _show_tooltip() -> void:
	if _current_cell == Vector2i(-1, -1):
		return

	# Don't show tooltip when modal dialogs are open
	if UIManager.is_modal_open():
		return

	_build_tooltip_content()

	# Only show if there's content
	if _tooltip_content.size() > 0:
		_is_visible = true


func show_cell(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1):
		_hide_tooltip()
		return

	_current_cell = cell
	_show_tooltip()


func _hide_tooltip() -> void:
	_is_visible = false
	_current_cell = Vector2i(-1, -1)


func _build_tooltip_content() -> void:
	_tooltip_content.clear()
	var cell = _current_cell

	if not grid_system or not grid_system.is_valid_cell(cell):
		return

	# Check for building
	_building_at_cell = grid_system.get_building_at(cell)

	if _building_at_cell:
		_add_building_info(_building_at_cell)
	else:
		_add_cell_info(cell)

	# Calculate tooltip height
	_tooltip_height = PADDING.y * 2.0
	for item in _tooltip_content:
		match item.type:
			"header":
				_tooltip_height += LINE_HEIGHT + 4.0
			"section":
				_tooltip_height += SECTION_SPACING
			"row":
				_tooltip_height += LINE_HEIGHT
			"bar":
				_tooltip_height += LINE_HEIGHT + 4.0

	_tooltip_height = minf(_tooltip_height, MAX_TOOLTIP_HEIGHT)


func _add_building_info(building) -> void:
	var data = building.building_data
	if not data:
		return

	var cell = building.grid_cell if building.get("grid_cell") else _current_cell

	# Header - building name
	_tooltip_content.append({
		"type": "header",
		"text": data.display_name,
		"color": HEADER_COLOR
	})

	# Category
	_tooltip_content.append({
		"type": "row",
		"label": "Category",
		"value": data.category.capitalize(),
		"color": TEXT_COLOR
	})

	# Size
	if data.size != Vector2i(1, 1):
		_tooltip_content.append({
			"type": "row",
			"label": "Size",
			"value": "%dx%d" % [data.size.x, data.size.y],
			"color": TEXT_COLOR
		})

	# Maintenance cost
	if data.monthly_maintenance > 0:
		_tooltip_content.append({
			"type": "row",
			"label": "Maintenance",
			"value": "$%d/mo" % data.monthly_maintenance,
			"color": WARNING_COLOR
		})

	# Power production/consumption
	if data.power_production > 0:
		_tooltip_content.append({
			"type": "row",
			"label": "Produces",
			"value": "%d MW" % int(data.power_production),
			"color": POSITIVE_COLOR
		})
	elif data.power_consumption > 0:
		_tooltip_content.append({
			"type": "row",
			"label": "Uses",
			"value": "%d MW" % int(data.power_consumption),
			"color": TEXT_COLOR
		})

	# Water
	if data.water_production > 0:
		_tooltip_content.append({
			"type": "row",
			"label": "Water",
			"value": "+%d ML" % int(data.water_production),
			"color": POSITIVE_COLOR
		})
	elif data.water_consumption > 0:
		_tooltip_content.append({
			"type": "row",
			"label": "Water",
			"value": "-%d ML" % int(data.water_consumption),
			"color": TEXT_COLOR
		})

	# Service coverage
	if data.coverage_radius > 0:
		_tooltip_content.append({
			"type": "row",
			"label": "Coverage",
			"value": "%d cells" % data.coverage_radius,
			"color": TEXT_COLOR
		})

	# Section divider
	_tooltip_content.append({"type": "section"})

	# Utility status
	_add_utility_status(cell)


func _add_cell_info(cell: Vector2i) -> void:
	# Header - cell coordinates
	_tooltip_content.append({
		"type": "header",
		"text": "Cell (%d, %d)" % [cell.x, cell.y],
		"color": HEADER_COLOR
	})

	# Terrain info
	if terrain_system:
		var elevation = terrain_system.get_elevation(cell)
		var water_type = terrain_system.get_water(cell)
		var feature = terrain_system.get_feature(cell)

		var terrain_text = _get_terrain_name(elevation, water_type)
		_tooltip_content.append({
			"type": "row",
			"label": "Terrain",
			"value": terrain_text,
			"color": TEXT_COLOR
		})

		# Handle single feature (not array)
		if feature != terrain_system.FeatureType.NONE:
			var feature_names = [_get_feature_name(feature)]
			_tooltip_content.append({
				"type": "row",
				"label": "Features",
				"value": ", ".join(feature_names),
				"color": TEXT_COLOR
			})

	# Zone info
	if zoning_system:
		var zone_type = zoning_system.get_zone_at(cell)
		if zone_type and zone_type != 0:  # 0 = ZoneType.NONE
			var zone_name = zoning_system.get_zone_name(zone_type)
			_tooltip_content.append({
				"type": "row",
				"label": "Zone",
				"value": zone_name,
				"color": zoning_system.get_zone_color(zone_type)
			})

	# Section divider
	_tooltip_content.append({"type": "section"})

	# Utility status
	_add_utility_status(cell)

	# Land value
	if land_value_system:
		var value = land_value_system.get_land_value_at(cell)
		var value_color = _get_value_color(value)
		_tooltip_content.append({
			"type": "bar",
			"label": "Land Value",
			"value": value,
			"max_value": 100.0,
			"color": value_color
		})

	# Pollution
	if pollution_system:
		var pollution = pollution_system.get_pollution_at(cell)
		if pollution > 0:
			var poll_color = lerp(POSITIVE_COLOR, NEGATIVE_COLOR, pollution / 100.0)
			_tooltip_content.append({
				"type": "bar",
				"label": "Pollution",
				"value": pollution,
				"max_value": 100.0,
				"color": poll_color
			})

	# Traffic congestion
	if traffic_system:
		var congestion = traffic_system.get_congestion_at(cell)
		if congestion > 0:
			var cong_color = lerp(POSITIVE_COLOR, WARNING_COLOR, congestion / 100.0)
			_tooltip_content.append({
				"type": "bar",
				"label": "Traffic",
				"value": congestion,
				"max_value": 100.0,
				"color": cong_color
			})


func _add_utility_status(cell: Vector2i) -> void:
	# Power
	if power_system:
		var has_power = power_system.is_cell_powered(cell)
		_tooltip_content.append({
			"type": "status",
			"label": "Power",
			"active": has_power,
			"color": Color(1.0, 0.9, 0.2) if has_power else LABEL_COLOR
		})

	# Water
	if water_system:
		var has_water = water_system.is_cell_watered(cell)
		_tooltip_content.append({
			"type": "status",
			"label": "Water",
			"active": has_water,
			"color": Color(0.3, 0.6, 0.95) if has_water else LABEL_COLOR
		})

	# Service coverage
	if service_coverage:
		var coverage = service_coverage.get_coverage_at_cell(cell)
		var services = []
		if coverage.get("fire", false):
			services.append("Fire")
		if coverage.get("police", false):
			services.append("Police")
		if coverage.get("health", false):
			services.append("Health")
		if coverage.get("education", false):
			services.append("Edu")

		if services.size() > 0:
			_tooltip_content.append({
				"type": "row",
				"label": "Services",
				"value": ", ".join(services),
				"color": POSITIVE_COLOR
			})


func _get_terrain_name(elevation: int, water_type: int) -> String:
	if water_type != 0:
		return "Water"
	match elevation:
		-1: return "Beach"
		0, 1: return "Grassland"
		2, 3: return "Hills"
		_:
			if elevation >= 4:
				return "Mountain"
			elif elevation <= -2:
				return "Deep Water"
	return "Grassland"


func _get_feature_name(feature: int) -> String:
	# Matches TerrainSystem.FeatureType
	match feature:
		1: return "Trees"
		2: return "Dense Forest"
		3: return "Rock"
		4: return "Boulder"
		5: return "Flower Patch"
		6: return "Tall Grass"
	return "Unknown"


func _get_value_color(value: float) -> Color:
	if value >= 70:
		return POSITIVE_COLOR
	elif value >= 40:
		return Color(0.7, 0.75, 0.3)
	elif value >= 20:
		return WARNING_COLOR
	else:
		return NEGATIVE_COLOR


func _update_position() -> void:
	if not camera:
		return

	# Get cell world position
	var cell_world = Vector2(_current_cell) * GridConstants.CELL_SIZE + Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE) * 0.5

	# Convert to screen position
	var viewport_size = get_viewport_rect().size
	var half_viewport = viewport_size * 0.5
	var screen_pos = (cell_world - camera.position) * camera.zoom.x + half_viewport

	var tooltip_size = Vector2(TOOLTIP_WIDTH, _tooltip_height)
	var candidates: Array[Vector2] = [
		screen_pos + Vector2(20, -10),
		screen_pos + Vector2(-tooltip_size.x - 20, -10),
		screen_pos + Vector2(20, 14),
		screen_pos + Vector2(-tooltip_size.x - 20, 14)
	]
	var tooltip_pos := candidates[0]

	for candidate in candidates:
		var clamped = _clamp_tooltip_to_viewport(candidate, tooltip_size, viewport_size)
		if not _intersects_blocked_rects(Rect2(clamped, tooltip_size)):
			tooltip_pos = clamped
			break

	position = _clamp_tooltip_to_viewport(tooltip_pos, tooltip_size, viewport_size)
	size = tooltip_size


func _clamp_tooltip_to_viewport(pos: Vector2, tooltip_size: Vector2, viewport_size: Vector2) -> Vector2:
	var clamped = pos
	if clamped.x + tooltip_size.x > viewport_size.x - 10:
		clamped.x = viewport_size.x - tooltip_size.x - 10
	if clamped.x < 10:
		clamped.x = 10
	if clamped.y + tooltip_size.y > viewport_size.y - 10:
		clamped.y = viewport_size.y - tooltip_size.y - 10
	if clamped.y < 10:
		clamped.y = 10
	return clamped


func _intersects_blocked_rects(rect: Rect2) -> bool:
	for control in _blocked_controls:
		if not is_instance_valid(control) or not control.is_visible_in_tree():
			continue
		if rect.intersects(control.get_global_rect()):
			return true
	return false


func _draw() -> void:
	if _tooltip_content.size() == 0:
		return

	var rect = Rect2(Vector2.ZERO, Vector2(TOOLTIP_WIDTH, _tooltip_height))

	# Draw background
	draw_rect(rect, BG_COLOR)

	# Draw border
	draw_rect(rect, BORDER_COLOR, false, BORDER_WIDTH)

	# Draw content
	var font = ThemeDB.fallback_font
	var y_offset = PADDING.y
	var content_bottom = _tooltip_height - PADDING.y

	for item in _tooltip_content:
		match item.type:
			"header":
				if y_offset + LINE_HEIGHT + 4.0 > content_bottom:
					break
				var header_width = TOOLTIP_WIDTH - PADDING.x * 2.0
				var header_text = _fit_text(font, str(item.text), HEADER_FONT_SIZE, header_width)
				draw_string(font, Vector2(PADDING.x, y_offset + 14), header_text,
					HORIZONTAL_ALIGNMENT_LEFT, header_width, HEADER_FONT_SIZE, item.color)
				y_offset += LINE_HEIGHT + 4.0

			"section":
				if y_offset + SECTION_SPACING > content_bottom:
					break
				# Draw separator line
				var line_y = y_offset + SECTION_SPACING * 0.5
				draw_line(
					Vector2(PADDING.x, line_y),
					Vector2(TOOLTIP_WIDTH - PADDING.x, line_y),
					BORDER_COLOR * Color(1, 1, 1, 0.5),
					1.0
				)
				y_offset += SECTION_SPACING

			"row":
				if y_offset + LINE_HEIGHT > content_bottom:
					break
				# Label on left, value on right
				var label_width = TOOLTIP_WIDTH - PADDING.x * 2.0 - VALUE_COLUMN_WIDTH - ROW_COLUMN_GAP
				var value_x = PADDING.x + label_width + ROW_COLUMN_GAP
				var label_text = _fit_text(font, str(item.label), BODY_FONT_SIZE, label_width)
				var value_text = _fit_text(font, str(item.value), BODY_FONT_SIZE, VALUE_COLUMN_WIDTH)
				draw_string(font, Vector2(PADDING.x, y_offset + 12), label_text,
					HORIZONTAL_ALIGNMENT_LEFT, label_width, BODY_FONT_SIZE, LABEL_COLOR)
				draw_string(font, Vector2(value_x, y_offset + 12), value_text,
					HORIZONTAL_ALIGNMENT_RIGHT, VALUE_COLUMN_WIDTH, BODY_FONT_SIZE, item.color)
				y_offset += LINE_HEIGHT

			"status":
				if y_offset + LINE_HEIGHT > content_bottom:
					break
				# Label with status indicator
				var indicator_color = item.color if item.active else LABEL_COLOR
				draw_circle(Vector2(PADDING.x + 4, y_offset + 8), 4, indicator_color)
				var status_width = TOOLTIP_WIDTH - (PADDING.x + 14.0) - PADDING.x
				var status_text = _fit_text(font, str(item.label), BODY_FONT_SIZE, status_width)
				draw_string(font, Vector2(PADDING.x + 14, y_offset + 12), status_text,
					HORIZONTAL_ALIGNMENT_LEFT, status_width, BODY_FONT_SIZE, item.color if item.active else LABEL_COLOR)
				y_offset += LINE_HEIGHT

			"bar":
				if y_offset + LINE_HEIGHT + 4.0 > content_bottom:
					break
				# Label with progress bar
				var bar_label_width = TOOLTIP_WIDTH - PADDING.x * 2.0 - 68.0
				var bar_label = _fit_text(font, str(item.label), BODY_FONT_SIZE, bar_label_width)
				draw_string(font, Vector2(PADDING.x, y_offset + 12), bar_label,
					HORIZONTAL_ALIGNMENT_LEFT, bar_label_width, BODY_FONT_SIZE, LABEL_COLOR)

				# Draw bar background
				var bar_width = 60.0
				var bar_height = 6.0
				var bar_x = TOOLTIP_WIDTH - PADDING.x - bar_width
				var bar_y = y_offset + 6
				var bar_rect = Rect2(bar_x, bar_y, bar_width, bar_height)
				draw_rect(bar_rect, Color(0.2, 0.2, 0.2, 0.8))

				# Draw bar fill
				var fill_width = bar_width * clampf(item.value / item.max_value, 0.0, 1.0)
				if fill_width > 0:
					draw_rect(Rect2(bar_x, bar_y, fill_width, bar_height), item.color)

				# Draw value text
				draw_string(font, Vector2(bar_x - 8, y_offset + 12), "%d" % int(item.value),
					HORIZONTAL_ALIGNMENT_RIGHT, 26.0, BAR_VALUE_FONT_SIZE, TEXT_COLOR)

				y_offset += LINE_HEIGHT + 4.0


func _fit_text(font: Font, text: String, font_size: int, max_width: float) -> String:
	if max_width <= 0.0 or text.is_empty():
		return ""
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
		return text

	var clipped = text
	while clipped.length() > 1:
		clipped = clipped.left(clipped.length() - 1)
		var candidate = "%s..." % clipped
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			return candidate
	return "..."


## Force hide the tooltip
func hide_tooltip() -> void:
	_hide_tooltip()


## Check if tooltip is currently visible
func is_showing() -> bool:
	return _is_visible
