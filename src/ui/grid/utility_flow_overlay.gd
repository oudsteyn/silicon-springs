extends Node2D
class_name UtilityFlowOverlay
## Animated overlay showing power and water flow through utility infrastructure
## Uses pooled visual elements for performance with large utility networks

# Flow animation configuration
const POWER_FLOW_SPEED: float = 80.0  # Pixels per second
const WATER_FLOW_SPEED: float = 50.0
const PULSE_LENGTH: float = 20.0
const PULSE_GAP: float = 40.0
const FLOW_LINE_WIDTH: float = 3.0

# Colors
const POWER_ACTIVE_COLOR: Color = Color(1.0, 0.9, 0.2, 0.7)
const POWER_INACTIVE_COLOR: Color = Color(0.4, 0.4, 0.3, 0.4)
const POWER_DAMAGED_COLOR: Color = Color(0.9, 0.3, 0.2, 0.8)
const WATER_ACTIVE_COLOR: Color = Color(0.3, 0.6, 0.95, 0.7)
const WATER_INACTIVE_COLOR: Color = Color(0.3, 0.4, 0.5, 0.4)
const WATER_LOW_PRESSURE_COLOR: Color = Color(0.4, 0.5, 0.6, 0.5)

# System references
var power_system = null
var water_system = null
var grid_system = null

# Tracking
var _power_line_cells: Dictionary = {}  # {Vector2i: true}
var _water_pipe_cells: Dictionary = {}  # {Vector2i: true}
var _damaged_cells: Dictionary = {}  # {Vector2i: true}

# Animation state
var _flow_offset: float = 0.0
var _visible: bool = true

# Visual element pools
var _power_flow_lines: Array[Line2D] = []
var _water_flow_lines: Array[Line2D] = []
const MAX_FLOW_LINES: int = 100

# Cached network data for efficient rendering
var _power_segments: Array = []  # [{start: Vector2i, end: Vector2i, active: bool, damaged: bool}]
var _water_segments: Array = []
var _segments_dirty: bool = true


func _ready() -> void:
	z_index = 5  # Above terrain, below buildings
	_init_flow_line_pools()

	# Connect to building events
	Events.building_placed.connect(_on_building_changed)
	Events.building_removed.connect(_on_building_changed)
	Events.month_tick.connect(_on_month_tick)


func _init_flow_line_pools() -> void:
	# Pre-create flow line objects for reuse
	for i in range(MAX_FLOW_LINES):
		var power_line = _create_flow_line(POWER_ACTIVE_COLOR)
		power_line.visible = false
		_power_flow_lines.append(power_line)
		add_child(power_line)

		var water_line = _create_flow_line(WATER_ACTIVE_COLOR)
		water_line.visible = false
		_water_flow_lines.append(water_line)
		add_child(water_line)


func _create_flow_line(color: Color) -> Line2D:
	var line = Line2D.new()
	line.width = FLOW_LINE_WIDTH
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	return line


func set_systems(power, water, grid) -> void:
	power_system = power
	water_system = water
	grid_system = grid
	_rebuild_utility_cache()


func _on_building_changed(_cell: Vector2i, _building) -> void:
	_segments_dirty = true


func _on_month_tick() -> void:
	# Refresh damaged cell tracking
	_update_damaged_cells()
	_segments_dirty = true


func _update_damaged_cells() -> void:
	_damaged_cells.clear()
	if power_system and power_system.has_method("get_storm_damaged_cells"):
		var damaged = power_system.get_storm_damaged_cells()
		for cell in damaged:
			_damaged_cells[cell] = true


func _rebuild_utility_cache() -> void:
	_power_line_cells.clear()
	_water_pipe_cells.clear()

	if not grid_system:
		return

	# Scan utility overlays for power lines and water pipes
	if grid_system.utility_overlays:
		for cell in grid_system.utility_overlays:
			var building = grid_system.utility_overlays[cell]
			if is_instance_valid(building) and building.building_data:
				match building.building_data.building_type:
					"power_line":
						_power_line_cells[cell] = true
					"water_pipe":
						_water_pipe_cells[cell] = true

	_rebuild_segments()


func _rebuild_segments() -> void:
	_power_segments.clear()
	_water_segments.clear()

	# Build connected segments for power lines
	_build_connected_segments(_power_line_cells, _power_segments, true)

	# Build connected segments for water pipes
	_build_connected_segments(_water_pipe_cells, _water_segments, false)

	_segments_dirty = false


func _build_connected_segments(cells: Dictionary, segments: Array, is_power: bool) -> void:
	if cells.is_empty():
		return

	var visited: Dictionary = {}

	for cell in cells:
		if visited.has(cell):
			continue

		# Check horizontal connection
		if cells.has(cell + Vector2i(1, 0)):
			var segment_start = cell
			var segment_end = cell

			# Extend left
			while cells.has(segment_start + Vector2i(-1, 0)) and not visited.has(segment_start + Vector2i(-1, 0)):
				segment_start = segment_start + Vector2i(-1, 0)

			# Extend right
			while cells.has(segment_end + Vector2i(1, 0)):
				segment_end = segment_end + Vector2i(1, 0)

			# Mark all cells in segment as visited
			var current = segment_start
			while current.x <= segment_end.x:
				visited[current] = true
				current.x += 1

			# Check if segment is active and damaged
			var is_active = _is_segment_active(segment_start, segment_end, is_power)
			var is_damaged = _is_segment_damaged(segment_start, segment_end)

			segments.append({
				"start": segment_start,
				"end": segment_end,
				"horizontal": true,
				"active": is_active,
				"damaged": is_damaged
			})

		# Check vertical connection
		if cells.has(cell + Vector2i(0, 1)) and not visited.has(cell):
			var segment_start = cell
			var segment_end = cell

			# Extend up
			while cells.has(segment_start + Vector2i(0, -1)) and not visited.has(segment_start + Vector2i(0, -1)):
				segment_start = segment_start + Vector2i(0, -1)

			# Extend down
			while cells.has(segment_end + Vector2i(0, 1)):
				segment_end = segment_end + Vector2i(0, 1)

			# Mark all cells in segment as visited
			var current = segment_start
			while current.y <= segment_end.y:
				visited[current] = true
				current.y += 1

			var is_active = _is_segment_active(segment_start, segment_end, is_power)
			var is_damaged = _is_segment_damaged(segment_start, segment_end)

			segments.append({
				"start": segment_start,
				"end": segment_end,
				"horizontal": false,
				"active": is_active,
				"damaged": is_damaged
			})

		# Single cell (no connections)
		if not visited.has(cell):
			visited[cell] = true
			var is_active = _is_cell_powered(cell) if is_power else _is_cell_watered(cell)
			var is_damaged = _damaged_cells.has(cell)

			segments.append({
				"start": cell,
				"end": cell,
				"horizontal": true,
				"active": is_active,
				"damaged": is_damaged
			})


func _is_segment_active(start: Vector2i, end: Vector2i, is_power: bool) -> bool:
	# Check if any cell in the segment is active
	if is_power:
		return _is_cell_powered(start) or _is_cell_powered(end)
	else:
		return _is_cell_watered(start) or _is_cell_watered(end)


func _is_segment_damaged(start: Vector2i, end: Vector2i) -> bool:
	# Check if any cell in the segment is damaged
	var current = start
	if start.x != end.x:
		while current.x <= end.x:
			if _damaged_cells.has(current):
				return true
			current.x += 1
	else:
		while current.y <= end.y:
			if _damaged_cells.has(current):
				return true
			current.y += 1
	return false


func _is_cell_powered(cell: Vector2i) -> bool:
	if power_system and power_system.has_method("is_cell_powered"):
		return power_system.is_cell_powered(cell)
	return false


func _is_cell_watered(cell: Vector2i) -> bool:
	if water_system and water_system.has_method("is_cell_watered"):
		return water_system.is_cell_watered(cell)
	return false


func _process(delta: float) -> void:
	if not _visible:
		return

	# Update flow animation offset
	_flow_offset += delta * POWER_FLOW_SPEED
	if _flow_offset > (PULSE_LENGTH + PULSE_GAP):
		_flow_offset -= (PULSE_LENGTH + PULSE_GAP)

	# Rebuild segments if dirty
	if _segments_dirty:
		_rebuild_utility_cache()

	# Update visual elements
	_update_flow_visuals()


func _update_flow_visuals() -> void:
	var power_idx = 0
	var water_idx = 0

	# Update power flow lines
	for segment in _power_segments:
		if power_idx >= _power_flow_lines.size():
			break

		var line = _power_flow_lines[power_idx]
		_configure_flow_line(line, segment, true)
		power_idx += 1

	# Hide unused power lines
	for i in range(power_idx, _power_flow_lines.size()):
		_power_flow_lines[i].visible = false

	# Update water flow lines
	for segment in _water_segments:
		if water_idx >= _water_flow_lines.size():
			break

		var line = _water_flow_lines[water_idx]
		_configure_flow_line(line, segment, false)
		water_idx += 1

	# Hide unused water lines
	for i in range(water_idx, _water_flow_lines.size()):
		_water_flow_lines[i].visible = false


func _configure_flow_line(line: Line2D, segment: Dictionary, is_power: bool) -> void:
	var start_pos = Vector2(segment.start) * GridConstants.CELL_SIZE + Vector2(GridConstants.CELL_SIZE * 0.5, GridConstants.CELL_SIZE * 0.5)
	var end_pos = Vector2(segment.end) * GridConstants.CELL_SIZE + Vector2(GridConstants.CELL_SIZE * 0.5, GridConstants.CELL_SIZE * 0.5)

	# Extend end position to include full cell
	if segment.horizontal and segment.start != segment.end:
		end_pos.x += 0  # Already centered
	elif segment.start != segment.end:
		end_pos.y += 0

	line.clear_points()

	# Determine color based on state
	var color: Color
	if segment.damaged:
		color = POWER_DAMAGED_COLOR if is_power else WATER_LOW_PRESSURE_COLOR
	elif segment.active:
		color = POWER_ACTIVE_COLOR if is_power else WATER_ACTIVE_COLOR
	else:
		color = POWER_INACTIVE_COLOR if is_power else WATER_INACTIVE_COLOR

	line.default_color = color
	line.visible = true

	# For active segments, create animated pulse pattern
	if segment.active and not segment.damaged:
		_draw_animated_pulse(line, start_pos, end_pos, is_power)
	else:
		# Static line for inactive/damaged
		line.add_point(start_pos)
		line.add_point(end_pos)
		line.width = FLOW_LINE_WIDTH * 0.6


func _draw_animated_pulse(line: Line2D, start: Vector2, end: Vector2, is_power: bool) -> void:
	var direction = (end - start).normalized()
	var length = start.distance_to(end)

	if length < 1:
		line.add_point(start)
		line.visible = true
		return

	var flow_speed = POWER_FLOW_SPEED if is_power else WATER_FLOW_SPEED
	var offset = fmod(_flow_offset * (flow_speed / POWER_FLOW_SPEED), PULSE_LENGTH + PULSE_GAP)

	line.width = FLOW_LINE_WIDTH

	# Draw pulses along the line
	var pulse_start = -offset
	while pulse_start < length:
		var p_start = maxf(pulse_start, 0)
		var p_end = minf(pulse_start + PULSE_LENGTH, length)

		if p_end > p_start:
			var point_start = start + direction * p_start
			var point_end = start + direction * p_end

			line.add_point(point_start)
			line.add_point(point_end)

			# Add gap between pulses (as separate segment after gradient)
			if pulse_start + PULSE_LENGTH < length:
				# Add invisible gap by repeating the end point
				line.add_point(point_end)

		pulse_start += PULSE_LENGTH + PULSE_GAP


func set_visible_overlay(should_show: bool) -> void:
	_visible = should_show
	visible = should_show

	if should_show:
		_segments_dirty = true


func refresh() -> void:
	_segments_dirty = true
	_rebuild_utility_cache()


## Get info about utility at cell
func get_utility_info_at(cell: Vector2i) -> Dictionary:
	var info = {
		"has_power_line": _power_line_cells.has(cell),
		"has_water_pipe": _water_pipe_cells.has(cell),
		"is_powered": _is_cell_powered(cell),
		"is_watered": _is_cell_watered(cell),
		"is_damaged": _damaged_cells.has(cell)
	}
	return info
