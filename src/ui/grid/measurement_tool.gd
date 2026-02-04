extends Node2D
class_name MeasurementTool
## Tool for measuring distances and areas on the grid
## Activated via keyboard shortcut, allows multi-point measurements


# Visual configuration
const LINE_WIDTH: float = 2.0
const POINT_RADIUS: float = 6.0
const LABEL_FONT_SIZE: int = 12
const LABEL_PADDING: Vector2 = Vector2(6, 4)
const CORNER_RADIUS: float = 4.0

# Colors
const LINE_COLOR: Color = Color(0.2, 0.9, 0.6, 0.9)
const POINT_COLOR: Color = Color(0.3, 1.0, 0.7, 1.0)
const POINT_OUTLINE: Color = Color(0.1, 0.2, 0.1, 0.9)
const AREA_FILL_COLOR: Color = Color(0.2, 0.9, 0.6, 0.15)
const AREA_BORDER_COLOR: Color = Color(0.2, 0.9, 0.6, 0.5)
const LABEL_BG_COLOR: Color = Color(0.05, 0.1, 0.05, 0.9)
const LABEL_TEXT_COLOR: Color = Color(0.9, 0.95, 0.9, 1.0)
const PREVIEW_COLOR: Color = Color(0.2, 0.9, 0.6, 0.5)

# Measurement modes
enum MeasureMode { NONE, DISTANCE, AREA }

# State
var _active: bool = false
var _mode: MeasureMode = MeasureMode.NONE
var _points: Array[Vector2i] = []
var _preview_point: Vector2i = Vector2i(-1, -1)
var _camera: Camera2D = null
var _animation_time: float = 0.0
var _events: Node = null

# Calculated values
var _total_distance: float = 0.0
var _area_cells: int = 0
var _bounding_rect: Rect2i = Rect2i()


func _ready() -> void:
	z_index = 25  # Above most game elements but below tooltip
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
	_camera = cam


func _process(delta: float) -> void:
	if not _active:
		return

	_animation_time += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not _active:
		return

	# Handle mouse clicks
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_add_point(_preview_point)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _points.size() > 0:
				_remove_last_point()
			else:
				deactivate()

	# Handle keyboard
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				deactivate()
			KEY_BACKSPACE:
				_remove_last_point()
			KEY_ENTER, KEY_KP_ENTER:
				# Finalize measurement
				if _mode == MeasureMode.AREA and _points.size() >= 2:
					_calculate_area()
			KEY_TAB:
				# Toggle between distance and area mode
				_toggle_mode()


func activate(mode: MeasureMode = MeasureMode.DISTANCE) -> void:
	_active = true
	_mode = mode
	_points.clear()
	_preview_point = Vector2i(-1, -1)
	_total_distance = 0.0
	_area_cells = 0
	visible = true
	var events = _get_events()
	if events:
		events.simulation_event.emit("measurement_started", {"mode": "distance" if mode == MeasureMode.DISTANCE else "area"})


func deactivate() -> void:
	_active = false
	_mode = MeasureMode.NONE
	_points.clear()
	_preview_point = Vector2i(-1, -1)
	visible = false
	var events = _get_events()
	if events:
		events.simulation_event.emit("measurement_ended", {})


func is_active() -> bool:
	return _active


func get_mode() -> MeasureMode:
	return _mode


func set_preview_point(cell: Vector2i) -> void:
	_preview_point = cell


func _toggle_mode() -> void:
	if _mode == MeasureMode.DISTANCE:
		_mode = MeasureMode.AREA
		_points.clear()
		_total_distance = 0.0
	else:
		_mode = MeasureMode.DISTANCE
		_points.clear()
		_area_cells = 0
	var events = _get_events()
	if events:
		events.simulation_event.emit("measurement_mode_changed", {
			"mode": "distance" if _mode == MeasureMode.DISTANCE else "area"
		})


func _add_point(cell: Vector2i) -> void:
	if cell == Vector2i(-1, -1):
		return

	if _mode == MeasureMode.DISTANCE:
		_points.append(cell)
		_recalculate_distance()
	elif _mode == MeasureMode.AREA:
		if _points.size() < 2:
			_points.append(cell)
			if _points.size() == 2:
				_calculate_area()


func _remove_last_point() -> void:
	if _points.size() > 0:
		_points.pop_back()
		if _mode == MeasureMode.DISTANCE:
			_recalculate_distance()
		elif _mode == MeasureMode.AREA:
			_area_cells = 0


func _recalculate_distance() -> void:
	_total_distance = 0.0
	for i in range(1, _points.size()):
		_total_distance += _get_distance(_points[i - 1], _points[i])


func _get_distance(a: Vector2i, b: Vector2i) -> float:
	var dx = abs(b.x - a.x)
	var dy = abs(b.y - a.y)
	# Use Chebyshev distance for grid (allows diagonal movement)
	return maxf(dx, dy) as float


func _get_manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(b.x - a.x) + abs(b.y - a.y)


func _get_euclidean_distance(a: Vector2i, b: Vector2i) -> float:
	var dx = b.x - a.x
	var dy = b.y - a.y
	return sqrt(dx * dx + dy * dy)


func _calculate_area() -> void:
	if _points.size() < 2:
		_area_cells = 0
		return

	var p1 = _points[0]
	var p2 = _points[1]

	var min_x = mini(p1.x, p2.x)
	var max_x = maxi(p1.x, p2.x)
	var min_y = mini(p1.y, p2.y)
	var max_y = maxi(p1.y, p2.y)

	_bounding_rect = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	_area_cells = _bounding_rect.size.x * _bounding_rect.size.y


func _draw() -> void:
	if not _active:
		return

	var font = ThemeDB.fallback_font

	if _mode == MeasureMode.DISTANCE:
		_draw_distance_measurement(font)
	elif _mode == MeasureMode.AREA:
		_draw_area_measurement(font)

	# Draw mode indicator
	_draw_mode_indicator(font)


func _draw_distance_measurement(font: Font) -> void:
	# Draw lines between points
	for i in range(1, _points.size()):
		var start = _cell_to_world(_points[i - 1])
		var end = _cell_to_world(_points[i])
		_draw_measurement_line(start, end, font, _points[i - 1], _points[i])

	# Draw preview line to cursor
	if _points.size() > 0 and _preview_point != Vector2i(-1, -1):
		var start = _cell_to_world(_points[_points.size() - 1])
		var end = _cell_to_world(_preview_point)
		_draw_measurement_line(start, end, font, _points[_points.size() - 1], _preview_point, true)

	# Draw points
	for i in range(_points.size()):
		var pos = _cell_to_world(_points[i])
		_draw_point(pos, i == 0)

	# Draw total distance label
	if _points.size() >= 2:
		var last_pos = _cell_to_world(_points[_points.size() - 1])
		_draw_total_label(font, last_pos + Vector2(15, -30))


func _draw_measurement_line(start: Vector2, end: Vector2, font: Font, cell_a: Vector2i, cell_b: Vector2i, is_preview: bool = false) -> void:
	var color = PREVIEW_COLOR if is_preview else LINE_COLOR

	# Draw line with dashed pattern for long distances
	var dist = start.distance_to(end)
	if dist > 200:
		# Draw dashed line
		var dash_length = 12.0
		var gap_length = 6.0
		var dir = (end - start).normalized()
		var current = start
		var drawn = 0.0
		var is_dash = true

		while drawn < dist:
			var segment_length = dash_length if is_dash else gap_length
			segment_length = minf(segment_length, dist - drawn)
			var next = current + dir * segment_length

			if is_dash:
				draw_line(current, next, color, LINE_WIDTH)

			current = next
			drawn += segment_length
			is_dash = not is_dash
	else:
		draw_line(start, end, color, LINE_WIDTH)

	# Draw distance label at midpoint
	var mid = (start + end) * 0.5
	var grid_dist = _get_distance(cell_a, cell_b)
	var label_text = "%d" % int(grid_dist)

	if not is_preview or _points.size() == 0:
		_draw_label(font, mid + Vector2(0, -15), label_text, is_preview)


func _draw_area_measurement(font: Font) -> void:
	if _points.size() == 0:
		return

	var p1 = _points[0]
	var p2 = _preview_point if _points.size() < 2 else _points[1]

	if p2 == Vector2i(-1, -1):
		# Just draw the first point
		_draw_point(_cell_to_world(p1), true)
		return

	# Calculate bounds
	var min_x = mini(p1.x, p2.x)
	var max_x = maxi(p1.x, p2.x)
	var min_y = mini(p1.y, p2.y)
	var max_y = maxi(p1.y, p2.y)

	var rect_start = Vector2(min_x, min_y) * GridConstants.CELL_SIZE
	var rect_end = Vector2(max_x + 1, max_y + 1) * GridConstants.CELL_SIZE
	var rect = Rect2(rect_start, rect_end - rect_start)

	# Draw area fill with animated pulse
	var pulse = (sin(_animation_time * 2.0) + 1.0) * 0.5
	var fill_color = AREA_FILL_COLOR
	fill_color.a *= 0.7 + pulse * 0.3
	draw_rect(rect, fill_color)

	# Draw border
	var is_preview = _points.size() < 2
	var border_color = PREVIEW_COLOR if is_preview else AREA_BORDER_COLOR
	draw_rect(rect, border_color, false, LINE_WIDTH)

	# Draw corner points
	_draw_point(_cell_to_world(p1), true)
	if not is_preview:
		_draw_point(_cell_to_world(p2), false)

	# Draw dimension labels
	var width = max_x - min_x + 1
	var height = max_y - min_y + 1
	var area = width * height

	# Width label (top)
	var top_mid = Vector2((min_x + max_x + 1) * 0.5 * GridConstants.CELL_SIZE, min_y * GridConstants.CELL_SIZE - 10)
	_draw_label(font, top_mid, "%d" % width, is_preview)

	# Height label (left)
	var left_mid = Vector2(min_x * GridConstants.CELL_SIZE - 20, (min_y + max_y + 1) * 0.5 * GridConstants.CELL_SIZE)
	_draw_label(font, left_mid, "%d" % height, is_preview)

	# Area label (center)
	var center = rect_start + rect.size * 0.5
	_draw_area_label(font, center, area, is_preview)


func _draw_point(pos: Vector2, is_start: bool) -> void:
	# Animated pulse for start point
	var radius = POINT_RADIUS
	if is_start:
		var pulse = (sin(_animation_time * 3.0) + 1.0) * 0.5
		radius += pulse * 2.0

	# Draw outer ring
	draw_circle(pos, radius + 2, POINT_OUTLINE)
	# Draw inner fill
	draw_circle(pos, radius, POINT_COLOR)

	# Draw inner dot for start point
	if is_start:
		draw_circle(pos, 3, POINT_OUTLINE)


func _draw_label(font: Font, pos: Vector2, text: String, is_preview: bool = false) -> void:
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	var bg_rect = Rect2(
		pos - text_size * 0.5 - LABEL_PADDING,
		text_size + LABEL_PADDING * 2
	)

	var bg_color = LABEL_BG_COLOR
	if is_preview:
		bg_color.a *= 0.7

	draw_rect(bg_rect, bg_color)

	var text_color = LABEL_TEXT_COLOR
	if is_preview:
		text_color.a *= 0.7

	draw_string(font, pos + Vector2(-text_size.x * 0.5, text_size.y * 0.3), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, text_color)


func _draw_area_label(font: Font, pos: Vector2, area: int, is_preview: bool) -> void:
	var text = "%d cells" % area
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE + 2)
	var bg_rect = Rect2(
		pos - text_size * 0.5 - LABEL_PADDING * 1.5,
		text_size + LABEL_PADDING * 3
	)

	var bg_color = LABEL_BG_COLOR
	bg_color.a = 0.95 if not is_preview else 0.7

	draw_rect(bg_rect, bg_color)
	draw_rect(bg_rect, LINE_COLOR * Color(1, 1, 1, 0.5 if is_preview else 0.8), false, 1.5)

	var text_color = LABEL_TEXT_COLOR
	if is_preview:
		text_color.a *= 0.7

	draw_string(font, pos + Vector2(-text_size.x * 0.5, text_size.y * 0.3), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE + 2, text_color)


func _draw_total_label(font: Font, pos: Vector2) -> void:
	var text = "Total: %d cells" % int(_total_distance)
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	var bg_rect = Rect2(
		pos - LABEL_PADDING,
		text_size + LABEL_PADDING * 2
	)

	draw_rect(bg_rect, LABEL_BG_COLOR)
	draw_rect(bg_rect, LINE_COLOR * Color(1, 1, 1, 0.8), false, 1.5)

	draw_string(font, pos + Vector2(0, text_size.y * 0.8), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, LABEL_TEXT_COLOR)


func _draw_mode_indicator(font: Font) -> void:
	if not _camera:
		return

	# Draw mode indicator in top-left of viewport
	var viewport_size = get_viewport_rect().size
	var half_size = viewport_size / (2.0 * _camera.zoom.x)
	var top_left = _camera.position - half_size

	var mode_text = "Distance Mode (Tab to switch)" if _mode == MeasureMode.DISTANCE else "Area Mode (Tab to switch)"
	var hint_text = "Click to add points, Right-click to remove, Esc to exit"

	var pos = top_left + Vector2(20, 60)

	# Background
	var text_size = font.get_string_size(mode_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	var bg_rect = Rect2(pos - LABEL_PADDING, Vector2(maxf(text_size.x, 280), 45) + LABEL_PADDING * 2)
	draw_rect(bg_rect, LABEL_BG_COLOR)
	draw_rect(bg_rect, LINE_COLOR * Color(1, 1, 1, 0.6), false, 1.5)

	# Mode text
	draw_string(font, pos + Vector2(0, 14), mode_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, LINE_COLOR)

	# Hint text
	draw_string(font, pos + Vector2(0, 32), hint_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LABEL_TEXT_COLOR * Color(1, 1, 1, 0.7))


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * GridConstants.CELL_SIZE + Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE) * 0.5


## Get the current total distance measured
func get_total_distance() -> float:
	return _total_distance


## Get the current area in cells
func get_area() -> int:
	return _area_cells


## Get all measurement points
func get_points() -> Array[Vector2i]:
	return _points.duplicate()


## Clear all points but keep tool active
func clear_points() -> void:
	_points.clear()
	_total_distance = 0.0
	_area_cells = 0
