extends Node2D
class_name GridCoordinateLabels
## Displays coordinate labels along the edges of the visible grid area
## Shows X coordinates along the top and Y coordinates along the left


# Visual configuration
const LABEL_FONT_SIZE: int = 10
const LABEL_COLOR: Color = Color(0.7, 0.75, 0.7, 0.6)
const LABEL_BG_COLOR: Color = Color(0.1, 0.12, 0.1, 0.5)
const LABEL_PADDING: Vector2 = Vector2(4, 2)
const MAJOR_INTERVAL: int = 10  # Show labels every N cells
const MINOR_INTERVAL: int = 5   # Show tick marks every N cells

# Zoom thresholds
const ZOOM_HIDE_THRESHOLD: float = 0.4  # Hide labels below this zoom
const ZOOM_ALL_LABELS_THRESHOLD: float = 1.5  # Show all cell labels above this zoom

# State
var camera: Camera2D = null
var _visible_rect: Rect2i = Rect2i()
var _needs_update: bool = true
var _last_camera_pos: Vector2 = Vector2.ZERO
var _last_camera_zoom: float = 1.0


func _ready() -> void:
	z_index = 20  # Above most game elements


func set_camera(cam: Camera2D) -> void:
	camera = cam


func _process(_delta: float) -> void:
	if not camera:
		return

	# Check if camera changed
	if camera.position != _last_camera_pos or camera.zoom.x != _last_camera_zoom:
		_last_camera_pos = camera.position
		_last_camera_zoom = camera.zoom.x
		_needs_update = true

	if _needs_update:
		_update_visible_area()
		_needs_update = false
		queue_redraw()


func _update_visible_area() -> void:
	if not camera:
		return

	var viewport_size = get_viewport_rect().size
	var half_size = viewport_size / (2.0 * camera.zoom.x)

	var min_x = maxi(0, int((camera.position.x - half_size.x) / GridConstants.CELL_SIZE) - 1)
	var min_y = maxi(0, int((camera.position.y - half_size.y) / GridConstants.CELL_SIZE) - 1)
	var max_x = mini(GridConstants.GRID_WIDTH - 1, int((camera.position.x + half_size.x) / GridConstants.CELL_SIZE) + 1)
	var max_y = mini(GridConstants.GRID_HEIGHT - 1, int((camera.position.y + half_size.y) / GridConstants.CELL_SIZE) + 1)

	_visible_rect = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _draw() -> void:
	if not camera or camera.zoom.x < ZOOM_HIDE_THRESHOLD:
		return

	var font = ThemeDB.fallback_font
	var viewport_size = get_viewport_rect().size
	var half_size = viewport_size / (2.0 * camera.zoom.x)

	# Determine label interval based on zoom
	var interval = MAJOR_INTERVAL
	if camera.zoom.x >= ZOOM_ALL_LABELS_THRESHOLD:
		interval = 1
	elif camera.zoom.x >= 1.0:
		interval = MINOR_INTERVAL

	# Calculate visible range edges in world coordinates
	var view_left = camera.position.x - half_size.x
	var view_top = camera.position.y - half_size.y

	# Draw X coordinate labels along top edge
	_draw_x_labels(font, view_left, view_top, interval)

	# Draw Y coordinate labels along left edge
	_draw_y_labels(font, view_left, view_top, interval)

	# Draw corner coordinate indicator
	_draw_corner_indicator(font, view_left, view_top)


func _draw_x_labels(font: Font, _view_left: float, view_top: float, interval: int) -> void:
	# Round to nearest interval
	var start_x = (int(_visible_rect.position.x / float(interval)) * interval)
	if start_x < _visible_rect.position.x:
		start_x += interval

	var label_y = view_top + 8  # Fixed distance from top of view

	for x in range(start_x, _visible_rect.position.x + _visible_rect.size.x + 1, interval):
		if x < 0 or x > GridConstants.GRID_WIDTH:
			continue

		var world_x = x * GridConstants.CELL_SIZE + GridConstants.CELL_SIZE * 0.5
		var label_text = str(x)

		# Draw background
		var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
		var bg_rect = Rect2(
			Vector2(world_x - text_size.x * 0.5 - LABEL_PADDING.x, label_y - LABEL_PADDING.y),
			text_size + LABEL_PADDING * 2
		)
		draw_rect(bg_rect, LABEL_BG_COLOR)

		# Draw text
		var text_pos = Vector2(world_x - text_size.x * 0.5, label_y + LABEL_FONT_SIZE * 0.8)
		draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, LABEL_COLOR)

		# Draw tick mark
		var tick_start = Vector2(world_x, label_y + text_size.y + LABEL_PADDING.y * 2)
		var tick_end = tick_start + Vector2(0, 6)
		draw_line(tick_start, tick_end, LABEL_COLOR, 1.0)


func _draw_y_labels(font: Font, view_left: float, _view_top: float, interval: int) -> void:
	# Round to nearest interval
	var start_y = (int(_visible_rect.position.y / float(interval)) * interval)
	if start_y < _visible_rect.position.y:
		start_y += interval

	var label_x = view_left + 8  # Fixed distance from left of view

	for y in range(start_y, _visible_rect.position.y + _visible_rect.size.y + 1, interval):
		if y < 0 or y > GridConstants.GRID_HEIGHT:
			continue

		var world_y = y * GridConstants.CELL_SIZE + GridConstants.CELL_SIZE * 0.5
		var label_text = str(y)

		# Draw background
		var text_size = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
		var bg_rect = Rect2(
			Vector2(label_x - LABEL_PADDING.x, world_y - text_size.y * 0.5 - LABEL_PADDING.y),
			text_size + LABEL_PADDING * 2
		)
		draw_rect(bg_rect, LABEL_BG_COLOR)

		# Draw text
		var text_pos = Vector2(label_x, world_y + LABEL_FONT_SIZE * 0.3)
		draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, LABEL_COLOR)

		# Draw tick mark
		var tick_start = Vector2(label_x + text_size.x + LABEL_PADDING.x * 2, world_y)
		var tick_end = tick_start + Vector2(6, 0)
		draw_line(tick_start, tick_end, LABEL_COLOR, 1.0)


func _draw_corner_indicator(font: Font, view_left: float, view_top: float) -> void:
	# Draw coordinate at top-left corner showing current view position
	var corner_x = int((view_left + 50) / GridConstants.CELL_SIZE)
	var corner_y = int((view_top + 50) / GridConstants.CELL_SIZE)

	corner_x = clampi(corner_x, 0, GridConstants.GRID_WIDTH - 1)
	corner_y = clampi(corner_y, 0, GridConstants.GRID_HEIGHT - 1)

	var indicator_text = "(%d, %d)" % [corner_x, corner_y]
	var text_size = font.get_string_size(indicator_text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)

	# Position in top-left corner of view
	var indicator_pos = Vector2(view_left + 8, view_top + 8)

	# Background with slightly more opacity
	var bg_color = LABEL_BG_COLOR
	bg_color.a = 0.7
	var bg_rect = Rect2(
		indicator_pos - LABEL_PADDING,
		text_size + LABEL_PADDING * 2
	)
	draw_rect(bg_rect, bg_color)

	# Draw border
	draw_rect(bg_rect, LABEL_COLOR * Color(1, 1, 1, 0.5), false, 1.0)

	# Draw text
	var text_color = LABEL_COLOR
	text_color.a = 0.9
	draw_string(font, indicator_pos + Vector2(0, LABEL_FONT_SIZE * 0.8), indicator_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, text_color)


## Force a refresh of labels
func refresh() -> void:
	_needs_update = true
	queue_redraw()
