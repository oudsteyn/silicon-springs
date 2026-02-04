extends Node2D
class_name DragSelectionOverlay
## Visual feedback for multi-cell drag selection operations
## Shows selection rectangle, dimensions, cell count, and cost estimation
## Used for zone painting, area demolish, and multi-select operations

# Visual configuration
const BORDER_WIDTH: float = 2.5
const BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.9)
const FILL_ALPHA: float = 0.15
const DASH_LENGTH: float = 8.0
const DASH_GAP: float = 4.0
const CORNER_SIZE: float = 12.0

# Info panel configuration
const INFO_PANEL_PADDING: Vector2 = Vector2(8, 4)
const INFO_PANEL_OFFSET: Vector2 = Vector2(10, -40)
const INFO_FONT_SIZE: int = 12
const INFO_BG_COLOR: Color = Color(0.1, 0.1, 0.1, 0.85)
const INFO_BORDER_COLOR: Color = Color(0.4, 0.4, 0.4, 0.8)

# Animation
const DASH_SPEED: float = 30.0  # Pixels per second
const PULSE_SPEED: float = 3.0

# State
var _active: bool = false
var _start_cell: Vector2i = Vector2i(-1, -1)
var _end_cell: Vector2i = Vector2i(-1, -1)
var _selection_color: Color = Color.WHITE
var _operation_type: String = "select"  # "select", "zone", "demolish"
var _zone_type: int = 0
var _cost_per_cell: int = 0

# Animation state
var _dash_offset: float = 0.0
var _pulse_phase: float = 0.0

# Cached calculations
var _cell_count: int = 0
var _dimensions: Vector2i = Vector2i.ZERO
var _total_cost: int = 0
var _valid_cells: int = 0

# System references
var grid_system = null
var zoning_system = null


func _ready() -> void:
	z_index = 15  # Above most game elements
	visible = false


func set_grid_system(gs) -> void:
	grid_system = gs


func set_zoning_system(zs) -> void:
	zoning_system = zs


func _process(delta: float) -> void:
	if not _active:
		return

	# Animate dash pattern
	_dash_offset += delta * DASH_SPEED
	if _dash_offset > (DASH_LENGTH + DASH_GAP):
		_dash_offset -= (DASH_LENGTH + DASH_GAP)

	# Animate pulse
	_pulse_phase += delta * PULSE_SPEED
	if _pulse_phase > TAU:
		_pulse_phase -= TAU

	queue_redraw()


## Start a drag selection
func start_selection(cell: Vector2i, operation: String = "select", color: Color = Color.WHITE) -> void:
	_active = true
	_start_cell = cell
	_end_cell = cell
	_operation_type = operation
	_selection_color = color
	visible = true
	_update_calculations()


## Update the selection end point
func update_selection(cell: Vector2i) -> void:
	if not _active:
		return

	if cell != _end_cell:
		_end_cell = cell
		_update_calculations()


## End the selection and return the selected area
func end_selection() -> Rect2i:
	if not _active:
		return Rect2i()

	var result = get_selection_rect()
	_active = false
	visible = false
	return result


## Cancel the selection
func cancel_selection() -> void:
	_active = false
	visible = false
	_start_cell = Vector2i(-1, -1)
	_end_cell = Vector2i(-1, -1)


## Check if selection is active
func is_active() -> bool:
	return _active


## Get the current selection rectangle
func get_selection_rect() -> Rect2i:
	var min_x = mini(_start_cell.x, _end_cell.x)
	var min_y = mini(_start_cell.y, _end_cell.y)
	var max_x = maxi(_start_cell.x, _end_cell.x)
	var max_y = maxi(_start_cell.y, _end_cell.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## Set the zone type for cost calculation
func set_zone_type(zone_type: int) -> void:
	_zone_type = zone_type
	_update_calculations()


## Set cost per cell (for operations with fixed cost)
func set_cost_per_cell(cost: int) -> void:
	_cost_per_cell = cost
	_update_calculations()


func _update_calculations() -> void:
	var rect = get_selection_rect()
	_dimensions = rect.size
	_cell_count = rect.size.x * rect.size.y

	# Calculate valid cells and cost
	_valid_cells = 0
	_total_cost = 0

	for x in range(rect.position.x, rect.position.x + rect.size.x):
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			var cell = Vector2i(x, y)
			if _is_cell_valid(cell):
				_valid_cells += 1
				_total_cost += _get_cell_cost(cell)


func _is_cell_valid(cell: Vector2i) -> bool:
	if not grid_system:
		return true

	if not grid_system.is_valid_cell(cell):
		return false

	match _operation_type:
		"zone":
			# Check if zone can be placed (no buildings, has road access)
			if grid_system.has_building_at(cell):
				var building = grid_system.get_building_at(cell)
				if building and building.building_data and building.building_data.category != "zone":
					return false
			return true
		"demolish":
			# Check if there's something to demolish
			return grid_system.has_building_at(cell)
		_:
			return true


func _get_cell_cost(_cell: Vector2i) -> int:
	if _cost_per_cell > 0:
		return _cost_per_cell

	# Zone cost is typically free (zones don't cost money to paint)
	# Cell-specific costs could be added here in the future
	return 0


func _draw() -> void:
	if not _active:
		return

	var rect = get_selection_rect()
	var world_rect = Rect2(
		Vector2(rect.position) * GridConstants.CELL_SIZE,
		Vector2(rect.size) * GridConstants.CELL_SIZE
	)

	# Calculate pulse intensity for fill
	var pulse = sin(_pulse_phase) * 0.3 + 0.7

	# Draw fill
	var fill_color = _selection_color
	fill_color.a = FILL_ALPHA * pulse
	draw_rect(world_rect, fill_color)

	# Draw animated dashed border
	_draw_dashed_rect(world_rect, _selection_color)

	# Draw corner brackets
	_draw_corner_brackets(world_rect)

	# Draw cell grid within selection (subtle)
	_draw_cell_divisions(world_rect, rect)

	# Draw info panel
	_draw_info_panel(world_rect)


func _draw_dashed_rect(rect: Rect2, color: Color) -> void:
	var points = [
		rect.position,
		rect.position + Vector2(rect.size.x, 0),
		rect.position + rect.size,
		rect.position + Vector2(0, rect.size.y),
		rect.position  # Close the loop
	]

	for i in range(4):
		_draw_dashed_line(points[i], points[i + 1], color)


func _draw_dashed_line(start: Vector2, end: Vector2, color: Color) -> void:
	var direction = (end - start).normalized()
	var length = start.distance_to(end)
	var pos = _dash_offset

	while pos < length:
		var dash_start = start + direction * pos
		var dash_end = start + direction * minf(pos + DASH_LENGTH, length)
		draw_line(dash_start, dash_end, color, BORDER_WIDTH, true)
		pos += DASH_LENGTH + DASH_GAP


func _draw_corner_brackets(rect: Rect2) -> void:
	var corner_color = _selection_color
	corner_color.a = 1.0
	var width = BORDER_WIDTH * 1.5

	# Top-left
	var tl = rect.position
	draw_line(tl, tl + Vector2(CORNER_SIZE, 0), corner_color, width)
	draw_line(tl, tl + Vector2(0, CORNER_SIZE), corner_color, width)

	# Top-right
	var top_right = rect.position + Vector2(rect.size.x, 0)
	draw_line(top_right, top_right + Vector2(-CORNER_SIZE, 0), corner_color, width)
	draw_line(top_right, top_right + Vector2(0, CORNER_SIZE), corner_color, width)

	# Bottom-left
	var bl = rect.position + Vector2(0, rect.size.y)
	draw_line(bl, bl + Vector2(CORNER_SIZE, 0), corner_color, width)
	draw_line(bl, bl + Vector2(0, -CORNER_SIZE), corner_color, width)

	# Bottom-right
	var br = rect.position + rect.size
	draw_line(br, br + Vector2(-CORNER_SIZE, 0), corner_color, width)
	draw_line(br, br + Vector2(0, -CORNER_SIZE), corner_color, width)


func _draw_cell_divisions(world_rect: Rect2, cell_rect: Rect2i) -> void:
	if cell_rect.size.x <= 1 and cell_rect.size.y <= 1:
		return

	var div_color = _selection_color
	div_color.a = 0.2

	# Vertical divisions
	for x in range(1, cell_rect.size.x):
		var x_pos = world_rect.position.x + x * GridConstants.CELL_SIZE
		draw_line(
			Vector2(x_pos, world_rect.position.y),
			Vector2(x_pos, world_rect.position.y + world_rect.size.y),
			div_color, 1.0
		)

	# Horizontal divisions
	for y in range(1, cell_rect.size.y):
		var y_pos = world_rect.position.y + y * GridConstants.CELL_SIZE
		draw_line(
			Vector2(world_rect.position.x, y_pos),
			Vector2(world_rect.position.x + world_rect.size.x, y_pos),
			div_color, 1.0
		)


func _draw_info_panel(world_rect: Rect2) -> void:
	var font = ThemeDB.fallback_font

	# Build info text lines
	var lines: Array[String] = []

	# Dimensions
	lines.append("%d x %d" % [_dimensions.x, _dimensions.y])

	# Cell count
	if _valid_cells != _cell_count:
		lines.append("%d / %d cells" % [_valid_cells, _cell_count])
	else:
		lines.append("%d cells" % _cell_count)

	# Cost (if applicable)
	if _total_cost > 0:
		lines.append("$%s" % _format_number(_total_cost))

	# Calculate panel size
	var max_width: float = 0
	var line_height = font.get_height(INFO_FONT_SIZE)
	for line in lines:
		var width = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, INFO_FONT_SIZE).x
		max_width = maxf(max_width, width)

	var panel_size = Vector2(
		max_width + INFO_PANEL_PADDING.x * 2,
		lines.size() * line_height + INFO_PANEL_PADDING.y * 2
	)

	# Position panel at top-right of selection
	var panel_pos = world_rect.position + Vector2(world_rect.size.x, 0) + INFO_PANEL_OFFSET
	panel_pos.x -= panel_size.x

	# Draw panel background
	var panel_rect = Rect2(panel_pos, panel_size)
	draw_rect(panel_rect, INFO_BG_COLOR)
	draw_rect(panel_rect, INFO_BORDER_COLOR, false, 1.0)

	# Draw text
	var text_pos = panel_pos + INFO_PANEL_PADDING + Vector2(0, line_height * 0.75)
	for i in range(lines.size()):
		var line_color = Color.WHITE
		if i == 0:
			line_color = _selection_color.lightened(0.3)
		draw_string(font, text_pos, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, INFO_FONT_SIZE, line_color)
		text_pos.y += line_height


func _format_number(num: int) -> String:
	return FormatUtils.format_number(num)


## Get selection info for external use
func get_selection_info() -> Dictionary:
	return {
		"rect": get_selection_rect(),
		"dimensions": _dimensions,
		"cell_count": _cell_count,
		"valid_cells": _valid_cells,
		"total_cost": _total_cost,
		"operation": _operation_type
	}
