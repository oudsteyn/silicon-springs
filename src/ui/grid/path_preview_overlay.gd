extends Node2D
class_name PathPreviewOverlay
## Visual preview for linear path placement (roads, power lines, water pipes)
## Shows planned path, per-cell validity, cost accumulation, and connection indicators

# Visual configuration
const PATH_WIDTH: float = 6.0
const VALID_COLOR: Color = Color(0.3, 0.9, 0.4, 0.7)
const INVALID_COLOR: Color = Color(0.9, 0.3, 0.3, 0.7)
const EXISTING_COLOR: Color = Color(0.5, 0.7, 0.9, 0.5)
const CONNECTION_COLOR: Color = Color(0.2, 0.8, 1.0, 0.9)

# Node markers
const NODE_RADIUS: float = 8.0
const START_NODE_COLOR: Color = Color(0.2, 0.9, 0.3, 0.9)
const END_NODE_COLOR: Color = Color(0.9, 0.7, 0.2, 0.9)

# Connection indicator
const CONNECTION_PULSE_SPEED: float = 4.0
const CONNECTION_RING_COUNT: int = 2

# Cost display
const COST_FONT_SIZE: int = 11
const COST_BG_COLOR: Color = Color(0.1, 0.1, 0.1, 0.85)
const COST_OFFSET: Vector2 = Vector2(8, -24)

# State
var _active: bool = false
var _start_cell: Vector2i = Vector2i(-1, -1)
var _end_cell: Vector2i = Vector2i(-1, -1)
var _path_type: String = "road"  # "road", "power_line", "water_pipe"
var _building_data = null

# Calculated path
var _path_cells: Array[Vector2i] = []
var _cell_validity: Dictionary = {}  # Vector2i -> bool
var _connection_points: Array[Vector2i] = []  # Cells where path connects to existing infrastructure

# Cost tracking
var _cost_per_cell: int = 0
var _total_cost: int = 0
var _valid_count: int = 0

# Animation
var _pulse_phase: float = 0.0

# System references
var grid_system = null
var power_system = null
var water_system = null


func _ready() -> void:
	z_index = 14  # Below drag selection, above game elements
	visible = false


func set_grid_system(gs) -> void:
	grid_system = gs


func set_power_system(ps) -> void:
	power_system = ps


func set_water_system(ws) -> void:
	water_system = ws


func _process(delta: float) -> void:
	if not _active:
		return

	_pulse_phase += delta * CONNECTION_PULSE_SPEED
	if _pulse_phase > TAU:
		_pulse_phase -= TAU

	queue_redraw()


## Start path preview
func start_path(cell: Vector2i, building_data) -> void:
	_active = true
	_start_cell = cell
	_end_cell = cell
	_building_data = building_data
	visible = true

	# Determine path type from building data
	if building_data:
		_cost_per_cell = building_data.build_cost
		var btype = building_data.building_type
		if btype in ["power_line", "power_pole"]:
			_path_type = "power_line"
		elif btype in ["water_pipe", "large_water_pipe"]:
			_path_type = "water_pipe"
		else:
			_path_type = "road"

	_calculate_path()


## Update path end point
func update_path(cell: Vector2i) -> void:
	if not _active:
		return

	if cell != _end_cell:
		_end_cell = cell
		_calculate_path()


## End path preview and return the path
func end_path() -> Array[Vector2i]:
	if not _active:
		return []

	var result = _path_cells.duplicate()
	_active = false
	visible = false
	_path_cells.clear()
	_cell_validity.clear()
	_connection_points.clear()
	return result


## Cancel path preview
func cancel_path() -> void:
	_active = false
	visible = false
	_path_cells.clear()
	_cell_validity.clear()
	_connection_points.clear()


## Check if path preview is active
func is_active() -> bool:
	return _active


## Get valid cells in the current path
func get_valid_path_cells() -> Array[Vector2i]:
	var valid: Array[Vector2i] = []
	for cell in _path_cells:
		if _cell_validity.get(cell, false):
			valid.append(cell)
	return valid


func _calculate_path() -> void:
	_path_cells.clear()
	_cell_validity.clear()
	_connection_points.clear()
	_total_cost = 0
	_valid_count = 0

	if _start_cell == Vector2i(-1, -1) or _end_cell == Vector2i(-1, -1):
		return

	# Calculate linear path (L-shaped: horizontal then vertical, or vice versa)
	# Choose path that has more valid cells
	var path_h_first = _calculate_path_h_first()
	var path_v_first = _calculate_path_v_first()

	var valid_h = _count_valid_cells(path_h_first)
	var valid_v = _count_valid_cells(path_v_first)

	_path_cells = path_h_first if valid_h >= valid_v else path_v_first

	# Calculate validity and connections for chosen path
	for cell in _path_cells:
		var valid = _is_cell_valid(cell)
		_cell_validity[cell] = valid

		if valid:
			_valid_count += 1
			_total_cost += _cost_per_cell

		# Check for connections to existing infrastructure
		if _is_connection_point(cell):
			_connection_points.append(cell)


func _calculate_path_h_first() -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = _start_cell

	# Horizontal segment
	var dir_x = 1 if _end_cell.x > _start_cell.x else -1
	while current.x != _end_cell.x:
		path.append(current)
		current.x += dir_x

	# Vertical segment
	var dir_y = 1 if _end_cell.y > _start_cell.y else -1
	while current.y != _end_cell.y:
		path.append(current)
		current.y += dir_y

	path.append(_end_cell)
	return path


func _calculate_path_v_first() -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var current = _start_cell

	# Vertical segment
	var dir_y = 1 if _end_cell.y > _start_cell.y else -1
	while current.y != _end_cell.y:
		path.append(current)
		current.y += dir_y

	# Horizontal segment
	var dir_x = 1 if _end_cell.x > _start_cell.x else -1
	while current.x != _end_cell.x:
		path.append(current)
		current.x += dir_x

	path.append(_end_cell)
	return path


func _count_valid_cells(path: Array[Vector2i]) -> int:
	var count = 0
	for cell in path:
		if _is_cell_valid(cell):
			count += 1
	return count


func _is_cell_valid(cell: Vector2i) -> bool:
	if not grid_system:
		return true

	if not grid_system.is_valid_cell(cell):
		return false

	# Check if building can be placed
	if _building_data:
		var check = grid_system.can_place_building(cell, _building_data)
		return check.can_place

	return true


func _is_connection_point(cell: Vector2i) -> bool:
	if not grid_system:
		return false

	# Check adjacent cells for existing infrastructure of same type
	var neighbors = [
		cell + Vector2i(1, 0), cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1), cell + Vector2i(0, -1)
	]

	for neighbor in neighbors:
		# Skip if neighbor is in our path
		if neighbor in _path_cells:
			continue

		var building = grid_system.get_building_at(neighbor)
		if building and building.building_data:
			var neighbor_type = building.building_data.building_type

			match _path_type:
				"power_line":
					if neighbor_type in ["power_line", "power_pole", "power_plant", "coal_plant",
										 "nuclear_plant", "solar_farm", "wind_farm", "battery_storage"]:
						return true
				"water_pipe":
					if neighbor_type in ["water_pipe", "large_water_pipe", "water_pump",
										 "large_water_pump", "water_tower", "desalination_plant"]:
						return true
				"road":
					if neighbor_type in ["road", "collector", "arterial", "highway"]:
						return true

	return false


func _draw() -> void:
	if not _active or _path_cells.is_empty():
		return

	# Draw path segments
	_draw_path_segments()

	# Draw connection indicators
	_draw_connection_indicators()

	# Draw start/end nodes
	_draw_endpoint_nodes()

	# Draw cost display
	_draw_cost_display()


func _draw_path_segments() -> void:
	for i in range(_path_cells.size()):
		var cell = _path_cells[i]
		var center = Vector2(cell) * GridConstants.CELL_SIZE + Vector2(GridConstants.CELL_SIZE * 0.5, GridConstants.CELL_SIZE * 0.5)

		var is_valid = _cell_validity.get(cell, false)
		var color = VALID_COLOR if is_valid else INVALID_COLOR

		# Check if this cell already has the same type of infrastructure
		if _has_existing_infrastructure(cell):
			color = EXISTING_COLOR

		# Draw cell marker
		var rect = Rect2(
			Vector2(cell) * GridConstants.CELL_SIZE + Vector2(4, 4),
			Vector2(GridConstants.CELL_SIZE - 8, GridConstants.CELL_SIZE - 8)
		)
		draw_rect(rect, color)

		# Draw connection line to next cell
		if i < _path_cells.size() - 1:
			var next_cell = _path_cells[i + 1]
			var next_center = Vector2(next_cell) * GridConstants.CELL_SIZE + Vector2(GridConstants.CELL_SIZE * 0.5, GridConstants.CELL_SIZE * 0.5)
			var line_color = color
			line_color.a *= 0.6
			draw_line(center, next_center, line_color, PATH_WIDTH * 0.5, true)


func _has_existing_infrastructure(cell: Vector2i) -> bool:
	if not grid_system:
		return false

	var building = grid_system.get_building_at(cell)
	if not building or not building.building_data:
		return false

	var btype = building.building_data.building_type

	match _path_type:
		"power_line":
			return btype in ["power_line", "power_pole"]
		"water_pipe":
			return btype in ["water_pipe", "large_water_pipe"]
		"road":
			return btype in ["road", "collector", "arterial", "highway"]

	return false


func _draw_connection_indicators() -> void:
	for cell in _connection_points:
		var center = Vector2(cell) * GridConstants.CELL_SIZE + Vector2(GridConstants.CELL_SIZE * 0.5, GridConstants.CELL_SIZE * 0.5)

		# Draw pulsing rings
		for i in range(CONNECTION_RING_COUNT):
			var ring_phase = fmod(_pulse_phase + i * PI / CONNECTION_RING_COUNT, TAU)
			var ring_scale = (ring_phase / TAU)
			var ring_alpha = 1.0 - ring_scale

			var color = CONNECTION_COLOR
			color.a *= ring_alpha * 0.6

			var radius = NODE_RADIUS * (1.0 + ring_scale * 2.0)
			draw_arc(center, radius, 0, TAU, 24, color, 2.0, true)

		# Draw solid center
		draw_circle(center, NODE_RADIUS * 0.6, CONNECTION_COLOR)


func _draw_endpoint_nodes() -> void:
	if _path_cells.is_empty():
		return

	# Start node
	var start_center = Vector2(_start_cell) * GridConstants.CELL_SIZE + Vector2(GridConstants.CELL_SIZE * 0.5, GridConstants.CELL_SIZE * 0.5)
	draw_circle(start_center, NODE_RADIUS, START_NODE_COLOR)
	draw_circle(start_center, NODE_RADIUS * 0.5, Color.WHITE)

	# End node (if different from start)
	if _end_cell != _start_cell:
		var end_center = Vector2(_end_cell) * GridConstants.CELL_SIZE + Vector2(GridConstants.CELL_SIZE * 0.5, GridConstants.CELL_SIZE * 0.5)
		draw_circle(end_center, NODE_RADIUS, END_NODE_COLOR)
		draw_circle(end_center, NODE_RADIUS * 0.5, Color.WHITE)


func _draw_cost_display() -> void:
	if _path_cells.is_empty():
		return

	var font = ThemeDB.fallback_font

	# Build display text
	var lines: Array[String] = []
	lines.append("%d cells" % _path_cells.size())

	if _valid_count != _path_cells.size():
		lines.append("%d valid" % _valid_count)

	if _total_cost > 0:
		lines.append("$%s" % _format_number(_total_cost))

	if _connection_points.size() > 0:
		lines.append("%d connections" % _connection_points.size())

	# Calculate panel size
	var max_width: float = 0
	var line_height = font.get_height(COST_FONT_SIZE)
	for line in lines:
		var width = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, COST_FONT_SIZE).x
		max_width = maxf(max_width, width)

	var padding = Vector2(6, 4)
	var panel_size = Vector2(max_width + padding.x * 2, lines.size() * line_height + padding.y * 2)

	# Position near end cell
	var end_center = Vector2(_end_cell) * GridConstants.CELL_SIZE + Vector2(GridConstants.CELL_SIZE * 0.5, GridConstants.CELL_SIZE * 0.5)
	var panel_pos = end_center + COST_OFFSET

	# Draw background
	var panel_rect = Rect2(panel_pos, panel_size)
	draw_rect(panel_rect, COST_BG_COLOR)
	draw_rect(panel_rect, Color(0.4, 0.4, 0.4, 0.6), false, 1.0)

	# Draw text
	var text_pos = panel_pos + padding + Vector2(0, line_height * 0.75)
	for i in range(lines.size()):
		var color = Color.WHITE
		if i == lines.size() - 1 and _total_cost > 0:
			color = Color(0.9, 0.8, 0.3)  # Gold for cost
		elif i == lines.size() - 1 and _connection_points.size() > 0:
			color = CONNECTION_COLOR
		draw_string(font, text_pos, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, COST_FONT_SIZE, color)
		text_pos.y += line_height


func _format_number(num: int) -> String:
	var str_num = str(num)
	var result = ""
	var count = 0
	for i in range(str_num.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = str_num[i] + result
		count += 1
	return result


## Get path info for external use
func get_path_info() -> Dictionary:
	return {
		"path": _path_cells.duplicate(),
		"valid_count": _valid_count,
		"total_cost": _total_cost,
		"connection_count": _connection_points.size(),
		"path_type": _path_type
	}
