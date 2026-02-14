extends Node2D
class_name CellHighlight
## Unified cell highlighting system that provides visual feedback in all interaction modes
## Shows the currently hovered cell with contextual coloring and smooth animations

# Visual configuration
const BORDER_WIDTH: float = 2.0
const CORNER_RADIUS: float = 4.0
const PULSE_DURATION: float = 0.4
const TRANSITION_DURATION: float = 0.08

# Highlight state colors
const COLORS = {
	"default": {
		"fill": Color(1, 1, 1, 0.08),
		"border": Color(1, 1, 1, 0.4),
	},
	"valid_build": {
		"fill": Color(0.2, 0.9, 0.3, 0.12),
		"border": Color(0.3, 1.0, 0.4, 0.7),
	},
	"invalid_build": {
		"fill": Color(0.9, 0.2, 0.2, 0.12),
		"border": Color(1.0, 0.3, 0.3, 0.7),
	},
	"zone_paint": {
		"fill": Color(0.3, 0.6, 0.9, 0.15),
		"border": Color(0.4, 0.7, 1.0, 0.8),
	},
	"demolish": {
		"fill": Color(0.9, 0.4, 0.1, 0.15),
		"border": Color(1.0, 0.5, 0.2, 0.8),
	},
	"select_building": {
		"fill": Color(0.2, 0.8, 1.0, 0.1),
		"border": Color(0.3, 0.9, 1.0, 0.6),
	},
	"terrain": {
		"fill": Color(0.6, 0.5, 0.3, 0.12),
		"border": Color(0.8, 0.7, 0.4, 0.7),
	},
}

# Current state
var target_cell: Vector2i = Vector2i(-1, -1)
var current_state: String = "default"
var building_size: Vector2i = Vector2i(1, 1)

# Animation state
var _current_fill_color: Color = COLORS.default.fill
var _current_border_color: Color = COLORS.default.border
var _target_fill_color: Color = COLORS.default.fill
var _target_border_color: Color = COLORS.default.border
var _pulse_phase: float = 0.0
var _is_pulsing: bool = false
var _transition_progress: float = 1.0

# Visual position (smoothly interpolated)
var _visual_position: Vector2 = Vector2.ZERO
var _visual_size: Vector2 = Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE)

# Corner indicators for multi-cell buildings
var _show_corners: bool = false

# Demolish cost label
var demolish_cost_text: String = ""  # e.g. "$500", "Free", "+$250" (refund)

# References
var grid_system = null


func _ready() -> void:
	# Ensure we draw on top of terrain but below UI
	z_index = 10


func set_grid_system(gs) -> void:
	grid_system = gs


func _process(delta: float) -> void:
	# Animate pulse
	if _is_pulsing:
		_pulse_phase += delta / PULSE_DURATION * TAU
		if _pulse_phase >= TAU:
			_pulse_phase = 0.0
			_is_pulsing = false

	# Animate color transition
	if _transition_progress < 1.0:
		_transition_progress = minf(_transition_progress + delta / TRANSITION_DURATION, 1.0)
		var t = _ease_out_cubic(_transition_progress)
		_current_fill_color = _current_fill_color.lerp(_target_fill_color, t)
		_current_border_color = _current_border_color.lerp(_target_border_color, t)

	# Smooth position transition
	var target_pos = Vector2(target_cell) * GridConstants.CELL_SIZE
	var target_size = Vector2(building_size) * GridConstants.CELL_SIZE
	_visual_position = _visual_position.lerp(target_pos, 0.3)
	_visual_size = _visual_size.lerp(target_size, 0.3)

	queue_redraw()


func _draw() -> void:
	if target_cell == Vector2i(-1, -1):
		return

	# Calculate pulse effect
	var pulse_intensity = 0.0
	if _is_pulsing:
		pulse_intensity = sin(_pulse_phase) * 0.3

	# Apply pulse to colors
	var fill_color = _current_fill_color
	var border_color = _current_border_color
	if pulse_intensity > 0:
		fill_color = fill_color.lightened(pulse_intensity)
		border_color = border_color.lightened(pulse_intensity * 0.5)

	var rect = Rect2(_visual_position, _visual_size)

	# Draw inner fill with slight inset
	var fill_rect = rect.grow(-BORDER_WIDTH * 0.5)
	_draw_rounded_rect(fill_rect, fill_color, CORNER_RADIUS)

	# Draw border
	_draw_rounded_border(rect, border_color, BORDER_WIDTH, CORNER_RADIUS)

	# Draw corner indicators for multi-cell buildings
	if _show_corners and building_size != Vector2i(1, 1):
		_draw_corner_indicators(rect, border_color)

	# Draw demolish cost label
	if demolish_cost_text != "" and current_state == "demolish":
		_draw_demolish_cost(rect)

	# Draw cell coordinate hint (subtle)
	if current_state == "default":
		_draw_cell_coords(rect)


func _draw_rounded_rect(rect: Rect2, color: Color, _radius: float) -> void:
	# Simple filled rectangle - radius parameter reserved for future rounded corners
	# True rounded corners would require polygon or shader
	draw_rect(rect, color)


func _draw_rounded_border(rect: Rect2, color: Color, width: float, radius: float) -> void:
	var points: PackedVector2Array = []

	# Top edge
	points.append(Vector2(rect.position.x + radius, rect.position.y))
	points.append(Vector2(rect.position.x + rect.size.x - radius, rect.position.y))

	# Top-right corner (approximated)
	points.append(Vector2(rect.position.x + rect.size.x, rect.position.y + radius))

	# Right edge
	points.append(Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y - radius))

	# Bottom-right corner
	points.append(Vector2(rect.position.x + rect.size.x - radius, rect.position.y + rect.size.y))

	# Bottom edge
	points.append(Vector2(rect.position.x + radius, rect.position.y + rect.size.y))

	# Bottom-left corner
	points.append(Vector2(rect.position.x, rect.position.y + rect.size.y - radius))

	# Left edge
	points.append(Vector2(rect.position.x, rect.position.y + radius))

	# Close the shape
	points.append(points[0])

	# Draw as polyline for border effect
	draw_polyline(points, color, width, true)


func _draw_corner_indicators(rect: Rect2, color: Color) -> void:
	var indicator_size = 8.0
	var corner_color = color.lightened(0.2)

	# Top-left corner bracket
	draw_line(rect.position, rect.position + Vector2(indicator_size, 0), corner_color, 2.0)
	draw_line(rect.position, rect.position + Vector2(0, indicator_size), corner_color, 2.0)

	# Top-right corner bracket
	var top_right = rect.position + Vector2(rect.size.x, 0)
	draw_line(top_right, top_right + Vector2(-indicator_size, 0), corner_color, 2.0)
	draw_line(top_right, top_right + Vector2(0, indicator_size), corner_color, 2.0)

	# Bottom-left corner bracket
	var bl = rect.position + Vector2(0, rect.size.y)
	draw_line(bl, bl + Vector2(indicator_size, 0), corner_color, 2.0)
	draw_line(bl, bl + Vector2(0, -indicator_size), corner_color, 2.0)

	# Bottom-right corner bracket
	var br = rect.position + rect.size
	draw_line(br, br + Vector2(-indicator_size, 0), corner_color, 2.0)
	draw_line(br, br + Vector2(0, -indicator_size), corner_color, 2.0)


func _draw_cell_coords(rect: Rect2) -> void:
	# Draw subtle cell coordinates in corner
	if target_cell.x >= 0 and target_cell.y >= 0:
		var coord_text = "%d,%d" % [target_cell.x, target_cell.y]
		var font = ThemeDB.fallback_font
		var font_size = 9
		var text_pos = rect.position + Vector2(4, rect.size.y - 4)
		draw_string(font, text_pos, coord_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.25))


func _draw_demolish_cost(rect: Rect2) -> void:
	var font = ThemeDB.fallback_font
	var font_size = 11
	# Position below the cell
	var text_pos = rect.position + Vector2(rect.size.x * 0.5, rect.size.y + 14)
	# Green tint for refunds, white for costs, gray for "Free"
	var color: Color
	if demolish_cost_text.begins_with("+"):
		color = Color(0.4, 1.0, 0.5, 0.9)  # Green for refund
	elif demolish_cost_text == "Free":
		color = Color(0.8, 0.8, 0.8, 0.7)  # Gray
	else:
		color = Color(1.0, 0.7, 0.3, 0.9)  # Orange for cost
	# Outline for readability
	var outline_color = Color(0, 0, 0, color.a * 0.5)
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, text_pos + offset, demolish_cost_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, outline_color)
	draw_string(font, text_pos, demolish_cost_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


## Update the highlighted cell position
func set_cell(cell: Vector2i) -> void:
	if cell == target_cell:
		return

	var was_valid = target_cell != Vector2i(-1, -1)
	target_cell = cell

	# Trigger pulse on cell change
	if was_valid and cell != Vector2i(-1, -1):
		_trigger_pulse()


## Set the highlight state (determines colors)
func set_state(state: String) -> void:
	if state == current_state:
		return

	current_state = state

	# Get target colors for the new state
	var colors = COLORS.get(state, COLORS.default)
	_target_fill_color = colors.fill
	_target_border_color = colors.border

	# Start transition animation
	_transition_progress = 0.0


## Set the building size for multi-cell highlight
func set_building_size(size: Vector2i) -> void:
	building_size = size
	_show_corners = size != Vector2i(1, 1)


## Reset to single cell
func reset_building_size() -> void:
	building_size = Vector2i(1, 1)
	_show_corners = false


## Trigger a pulse animation (called on cell change or action)
func _trigger_pulse() -> void:
	_is_pulsing = true
	_pulse_phase = 0.0


## Trigger a strong pulse (for placement/action feedback)
func pulse_feedback(success: bool = true) -> void:
	_is_pulsing = true
	_pulse_phase = 0.0

	# Briefly flash the appropriate color
	if success:
		_current_fill_color = Color(0.3, 1.0, 0.4, 0.3)
		_current_border_color = Color(0.4, 1.0, 0.5, 1.0)
	else:
		_current_fill_color = Color(1.0, 0.3, 0.3, 0.3)
		_current_border_color = Color(1.0, 0.4, 0.4, 1.0)


## Set the demolish cost/info text shown below the cell
func set_demolish_info(text: String) -> void:
	demolish_cost_text = text


## Clear the demolish cost/info text
func clear_demolish_info() -> void:
	demolish_cost_text = ""


## Hide the highlight
func hide_highlight() -> void:
	target_cell = Vector2i(-1, -1)


## Get appropriate state based on game context
static func get_state_for_context(
	tool_mode: int,
	is_build_mode: bool,
	is_demolish_mode: bool,
	is_zone_mode: bool,
	can_place: bool,
	has_building: bool
) -> String:
	# ToolMode enum: SELECT=0, PAN=1, BUILD=2, DEMOLISH=3, ZONE=4, TERRAIN=5

	if is_demolish_mode or tool_mode == 3:  # DEMOLISH
		return "demolish"

	if is_zone_mode or tool_mode == 4:  # ZONE
		return "zone_paint"

	if is_build_mode or tool_mode == 2:  # BUILD
		if can_place:
			return "valid_build"
		else:
			return "invalid_build"

	if tool_mode == 5:  # TERRAIN
		return "terrain"

	if has_building:
		return "select_building"

	return "default"
