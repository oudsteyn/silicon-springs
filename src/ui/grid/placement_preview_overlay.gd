extends Node2D
class_name PlacementPreviewOverlay
## Enhanced building placement preview with per-cell validity, infrastructure status,
## adjacency indicators, and terrain compatibility warnings
## Replaces the simple ghost_preview ColorRect

# Cell state colors
const VALID_FILL: Color = Color(0.2, 0.9, 0.3, 0.25)
const VALID_BORDER: Color = Color(0.3, 1.0, 0.4, 0.8)
const INVALID_FILL: Color = Color(0.9, 0.2, 0.2, 0.25)
const INVALID_BORDER: Color = Color(1.0, 0.3, 0.3, 0.8)
const BLOCKED_FILL: Color = Color(0.6, 0.1, 0.1, 0.35)
const TERRAIN_WARNING_COLOR: Color = Color(0.9, 0.6, 0.2, 0.3)

# Infrastructure indicators
const POWER_CONNECTED_COLOR: Color = Color(1.0, 0.9, 0.2, 0.8)
const POWER_MISSING_COLOR: Color = Color(0.5, 0.45, 0.1, 0.5)
const WATER_CONNECTED_COLOR: Color = Color(0.3, 0.6, 0.95, 0.8)
const WATER_MISSING_COLOR: Color = Color(0.15, 0.3, 0.5, 0.5)

# Adjacency indicators
const ADJACENCY_BONUS_COLOR: Color = Color(0.2, 0.9, 0.5, 0.6)
const ADJACENCY_PENALTY_COLOR: Color = Color(0.9, 0.4, 0.2, 0.6)
const ADJACENCY_ICON_SIZE: float = 16.0

# Visual configuration
const BORDER_WIDTH: float = 2.5
const ICON_SIZE: float = 12.0
const INFO_FONT_SIZE: int = 10
const CORNER_BRACKET_SIZE: float = 10.0

# Animation
const PULSE_SPEED: float = 3.0
const ICON_PULSE_SPEED: float = 4.0

# State
var _active: bool = false
var _cell: Vector2i = Vector2i(-1, -1)
var _building_data = null
var _can_afford: bool = true

# Per-cell analysis
var _cell_states: Dictionary = {}  # Vector2i -> CellState
var _overall_valid: bool = false
var _terrain_warnings: Array[String] = []
var _adjacency_effects: Array[Dictionary] = []  # [{type, direction, value}]

# Infrastructure status
var _has_power_nearby: bool = false
var _has_water_nearby: bool = false
var _needs_power: bool = false
var _needs_water: bool = false

# Animation
var _pulse_phase: float = 0.0

# System references
var grid_system = null
var terrain_system = null
var power_system = null
var water_system = null
var zoning_system = null

# Cell analysis result
class CellState:
	var valid: bool = true
	var blocked_by: String = ""  # "building", "terrain", "water", "bounds"
	var terrain_type: String = ""  # "normal", "hill", "water", "mountain"
	var elevation: int = 0


func _ready() -> void:
	z_index = 13  # Below path preview, above game elements
	visible = false


func set_grid_system(gs) -> void:
	grid_system = gs


func set_terrain_system(ts) -> void:
	terrain_system = ts


func set_power_system(ps) -> void:
	power_system = ps


func set_water_system(ws) -> void:
	water_system = ws


func set_zoning_system(zs) -> void:
	zoning_system = zs


func _process(delta: float) -> void:
	if not _active:
		return

	_pulse_phase += delta * PULSE_SPEED
	if _pulse_phase > TAU:
		_pulse_phase -= TAU

	queue_redraw()


## Show placement preview for a building at a cell
func show_preview(cell: Vector2i, building_data, can_afford: bool = true) -> void:
	_active = true
	_cell = cell
	_building_data = building_data
	_can_afford = can_afford
	visible = true

	_analyze_placement()


## Update preview position
func update_position(cell: Vector2i, can_afford: bool = true) -> void:
	if not _active:
		return

	if cell != _cell or can_afford != _can_afford:
		_cell = cell
		_can_afford = can_afford
		_analyze_placement()


## Hide the preview
func hide_preview() -> void:
	_active = false
	visible = false
	_cell_states.clear()
	_adjacency_effects.clear()
	_terrain_warnings.clear()


## Check if preview is active
func is_active() -> bool:
	return _active


## Check if current placement is valid
func is_valid() -> bool:
	return _overall_valid and _can_afford


func _analyze_placement() -> void:
	_cell_states.clear()
	_adjacency_effects.clear()
	_terrain_warnings.clear()
	_overall_valid = true

	if not _building_data:
		return

	var size = _building_data.size if _building_data.get("size") else Vector2i(1, 1)

	# Analyze each cell in the footprint
	for x in range(size.x):
		for y in range(size.y):
			var check_cell = _cell + Vector2i(x, y)
			var state = _analyze_cell(check_cell)
			_cell_states[check_cell] = state

			if not state.valid:
				_overall_valid = false

	# Check infrastructure requirements
	_needs_power = _building_data.power_consumption > 0 if _building_data.get("power_consumption") else false
	_needs_water = _building_data.water_consumption > 0 if _building_data.get("water_consumption") else false

	if power_system:
		_has_power_nearby = _check_power_nearby()
	if water_system:
		_has_water_nearby = _check_water_nearby()

	# Analyze adjacency effects
	if zoning_system and _building_data.get("building_type"):
		_analyze_adjacency_effects()


func _analyze_cell(cell: Vector2i) -> CellState:
	var state = CellState.new()

	# Check bounds
	if grid_system and not grid_system.is_valid_cell(cell):
		state.valid = false
		state.blocked_by = "bounds"
		return state

	# Check terrain
	if terrain_system:
		state.elevation = terrain_system.get_elevation(cell)
		var water_type = terrain_system.get_water(cell)

		if water_type != 0:  # Has water
			state.terrain_type = "water"
			# Only certain buildings can be on water
			var water_allowed = ["bridge", "dock", "water_pump", "large_water_pump", "desalination_plant"]
			var btype = _building_data.building_type if _building_data.get("building_type") else ""
			if btype not in water_allowed:
				state.valid = false
				state.blocked_by = "water"
				if "Cannot build on water" not in _terrain_warnings:
					_terrain_warnings.append("Cannot build on water")
		elif state.elevation >= 4:
			state.terrain_type = "mountain"
			var bsize = _building_data.size if _building_data.get("size") else Vector2i(1, 1)
			if bsize.x > 2 or bsize.y > 2:
				state.valid = false
				state.blocked_by = "terrain"
				if "Too steep for large buildings" not in _terrain_warnings:
					_terrain_warnings.append("Too steep for large buildings")
		elif state.elevation >= 2:
			state.terrain_type = "hill"
		else:
			state.terrain_type = "normal"

	# Check for existing building
	if grid_system and grid_system.get_building_at(cell):
		state.valid = false
		state.blocked_by = "building"

	return state


func _check_power_nearby() -> bool:
	if not power_system or not power_system.has_method("is_cell_powered"):
		return true  # Assume available if we can't check

	# Check if any cell in footprint or adjacent has power
	var size = _building_data.size if _building_data.get("size") else Vector2i(1, 1)

	for x in range(-1, size.x + 1):
		for y in range(-1, size.y + 1):
			var check = _cell + Vector2i(x, y)
			if power_system.is_cell_powered(check):
				return true

	return false


func _check_water_nearby() -> bool:
	if not water_system or not water_system.has_method("is_cell_watered"):
		return true

	var size = _building_data.size if _building_data.get("size") else Vector2i(1, 1)

	for x in range(-1, size.x + 1):
		for y in range(-1, size.y + 1):
			var check = _cell + Vector2i(x, y)
			if water_system.is_cell_watered(check):
				return true

	return false


func _analyze_adjacency_effects() -> void:
	if not zoning_system or not grid_system:
		return

	var btype = _building_data.building_type if _building_data.get("building_type") else ""
	var our_zone = zoning_system.get_building_zone_type(btype)

	if our_zone == "":
		return

	var size = _building_data.size if _building_data.get("size") else Vector2i(1, 1)
	var checked_buildings = {}

	# Check perimeter cells
	for x in range(-1, size.x + 1):
		for y in range(-1, size.y + 1):
			# Skip interior cells
			if x >= 0 and x < size.x and y >= 0 and y < size.y:
				continue

			var neighbor_cell = _cell + Vector2i(x, y)
			var neighbor = grid_system.get_building_at(neighbor_cell)

			if neighbor and not checked_buildings.has(neighbor):
				checked_buildings[neighbor] = true

				if neighbor.building_data:
					var neighbor_zone = zoning_system.get_building_zone_type(neighbor.building_data.building_type)
					if neighbor_zone != "":
						var compat = zoning_system.get_compatibility(our_zone, neighbor_zone)

						if compat < 1.0:
							# Determine direction
							var dir = Vector2i(x, y)
							if dir.x != 0 and dir.y != 0:
								# Diagonal - normalize to cardinal
								if abs(dir.x) > abs(dir.y):
									dir.y = 0
								else:
									dir.x = 0

							_adjacency_effects.append({
								"type": "penalty" if compat < 0.8 else "warning",
								"direction": dir,
								"value": compat,
								"zone": neighbor_zone
							})


func _draw() -> void:
	if not _active or not _building_data:
		return

	var size = _building_data.size if _building_data.get("size") else Vector2i(1, 1)
	var pulse = sin(_pulse_phase) * 0.3 + 0.7

	# Draw per-cell states
	_draw_cell_states(size, pulse)

	# Draw building outline
	_draw_building_outline(size, pulse)

	# Draw infrastructure indicators
	_draw_infrastructure_indicators(size)

	# Draw adjacency indicators
	_draw_adjacency_indicators(size)

	# Draw info panel
	_draw_info_panel(size)


func _draw_cell_states(size: Vector2i, pulse: float) -> void:
	for x in range(size.x):
		for y in range(size.y):
			var cell = _cell + Vector2i(x, y)
			var state = _cell_states.get(cell)

			if not state:
				continue

			var rect = Rect2(Vector2(cell) * GridConstants.CELL_SIZE, Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE))

			# Determine fill color
			var fill_color: Color
			if not state.valid:
				match state.blocked_by:
					"building":
						fill_color = BLOCKED_FILL
					"water", "terrain":
						fill_color = TERRAIN_WARNING_COLOR
					_:
						fill_color = INVALID_FILL
			elif state.terrain_type == "hill":
				# Slight warning tint for hills
				fill_color = VALID_FILL.lerp(TERRAIN_WARNING_COLOR, 0.3)
			else:
				fill_color = VALID_FILL

			if not _can_afford:
				fill_color = INVALID_FILL

			fill_color.a *= pulse
			draw_rect(rect, fill_color)

			# Draw cell border for multi-cell buildings
			if size.x > 1 or size.y > 1:
				var border_color = VALID_BORDER if state.valid else INVALID_BORDER
				border_color.a *= 0.3
				draw_rect(rect, border_color, false, 1.0)


func _draw_building_outline(size: Vector2i, pulse: float) -> void:
	var rect = Rect2(
		Vector2(_cell) * GridConstants.CELL_SIZE,
		Vector2(size) * GridConstants.CELL_SIZE
	)

	var border_color = VALID_BORDER if _overall_valid and _can_afford else INVALID_BORDER
	border_color.a *= pulse

	# Draw main border
	draw_rect(rect, border_color, false, BORDER_WIDTH)

	# Draw corner brackets
	_draw_corner_brackets(rect, border_color)


func _draw_corner_brackets(rect: Rect2, color: Color) -> void:
	var bracket_color = color
	bracket_color.a = 1.0
	var width = BORDER_WIDTH * 1.2

	# Top-left
	var tl = rect.position
	draw_line(tl, tl + Vector2(CORNER_BRACKET_SIZE, 0), bracket_color, width)
	draw_line(tl, tl + Vector2(0, CORNER_BRACKET_SIZE), bracket_color, width)

	# Top-right
	var top_right = rect.position + Vector2(rect.size.x, 0)
	draw_line(top_right, top_right + Vector2(-CORNER_BRACKET_SIZE, 0), bracket_color, width)
	draw_line(top_right, top_right + Vector2(0, CORNER_BRACKET_SIZE), bracket_color, width)

	# Bottom-left
	var bl = rect.position + Vector2(0, rect.size.y)
	draw_line(bl, bl + Vector2(CORNER_BRACKET_SIZE, 0), bracket_color, width)
	draw_line(bl, bl + Vector2(0, -CORNER_BRACKET_SIZE), bracket_color, width)

	# Bottom-right
	var br = rect.position + rect.size
	draw_line(br, br + Vector2(-CORNER_BRACKET_SIZE, 0), bracket_color, width)
	draw_line(br, br + Vector2(0, -CORNER_BRACKET_SIZE), bracket_color, width)


func _draw_infrastructure_indicators(_size: Vector2i) -> void:
	var icon_pulse = sin(_pulse_phase * 1.5) * 0.3 + 0.7
	var base_pos = Vector2(_cell) * GridConstants.CELL_SIZE + Vector2(-ICON_SIZE - 4, 4)

	var icon_y_offset = 0.0

	# Power indicator
	if _needs_power:
		var color = POWER_CONNECTED_COLOR if _has_power_nearby else POWER_MISSING_COLOR
		color.a *= icon_pulse
		_draw_power_icon(base_pos + Vector2(0, icon_y_offset), color)
		icon_y_offset += ICON_SIZE + 4

	# Water indicator
	if _needs_water:
		var color = WATER_CONNECTED_COLOR if _has_water_nearby else WATER_MISSING_COLOR
		color.a *= icon_pulse
		_draw_water_icon(base_pos + Vector2(0, icon_y_offset), color)


func _draw_power_icon(pos: Vector2, color: Color) -> void:
	# Lightning bolt shape
	var points: PackedVector2Array = [
		pos + Vector2(6, 0),
		pos + Vector2(2, 5),
		pos + Vector2(5, 5),
		pos + Vector2(3, 12),
		pos + Vector2(8, 4),
		pos + Vector2(5, 4),
	]
	draw_colored_polygon(points, color)


func _draw_water_icon(pos: Vector2, color: Color) -> void:
	# Water drop shape
	var center = pos + Vector2(5, 7)
	draw_circle(center, 4, color)
	# Top point of drop
	var drop_points: PackedVector2Array = [
		center + Vector2(-3, -2),
		center + Vector2(0, -7),
		center + Vector2(3, -2),
	]
	draw_colored_polygon(drop_points, color)


func _draw_adjacency_indicators(size: Vector2i) -> void:
	for effect in _adjacency_effects:
		var dir = effect.direction as Vector2i
		var is_penalty = effect.type == "penalty"
		var color = ADJACENCY_PENALTY_COLOR if is_penalty else ADJACENCY_BONUS_COLOR

		# Calculate position at edge of building
		var edge_pos: Vector2
		if dir.x < 0:
			edge_pos = Vector2(_cell.x * GridConstants.CELL_SIZE - 8, (_cell.y + size.y / 2.0) * GridConstants.CELL_SIZE)
		elif dir.x > 0:
			edge_pos = Vector2((_cell.x + size.x) * GridConstants.CELL_SIZE + 8, (_cell.y + size.y / 2.0) * GridConstants.CELL_SIZE)
		elif dir.y < 0:
			edge_pos = Vector2((_cell.x + size.x / 2.0) * GridConstants.CELL_SIZE, _cell.y * GridConstants.CELL_SIZE - 8)
		else:
			edge_pos = Vector2((_cell.x + size.x / 2.0) * GridConstants.CELL_SIZE, (_cell.y + size.y) * GridConstants.CELL_SIZE + 8)

		# Draw indicator
		if is_penalty:
			# X mark for penalty
			var half = 4.0
			draw_line(edge_pos + Vector2(-half, -half), edge_pos + Vector2(half, half), color, 2.0)
			draw_line(edge_pos + Vector2(half, -half), edge_pos + Vector2(-half, half), color, 2.0)
		else:
			# Warning triangle
			var tri_points: PackedVector2Array = [
				edge_pos + Vector2(0, -5),
				edge_pos + Vector2(-4, 4),
				edge_pos + Vector2(4, 4),
			]
			draw_colored_polygon(tri_points, color)


func _draw_info_panel(size: Vector2i) -> void:
	var font = ThemeDB.fallback_font
	var lines: Array[String] = []

	# Building name
	if _building_data.get("display_name"):
		lines.append(_building_data.display_name)

	# Cost
	if _building_data.get("build_cost"):
		lines.append("$%s" % _format_number(_building_data.build_cost))

	# Warnings
	for warning in _terrain_warnings:
		lines.append(warning)

	# Infrastructure status
	if _needs_power and not _has_power_nearby:
		lines.append("No power nearby")
	if _needs_water and not _has_water_nearby:
		lines.append("No water nearby")

	if lines.is_empty():
		return

	# Calculate panel size
	var max_width: float = 0
	var line_height = font.get_height(INFO_FONT_SIZE)
	for line in lines:
		var width = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, INFO_FONT_SIZE).x
		max_width = maxf(max_width, width)

	var padding = Vector2(6, 4)
	var panel_size = Vector2(max_width + padding.x * 2, lines.size() * line_height + padding.y * 2)

	# Position above building
	var building_top = Vector2(_cell) * GridConstants.CELL_SIZE
	var panel_pos = building_top + Vector2(size.x * GridConstants.CELL_SIZE * 0.5 - panel_size.x * 0.5, -panel_size.y - 8)

	# Draw background
	draw_rect(Rect2(panel_pos, panel_size), Color(0.1, 0.1, 0.1, 0.85))
	draw_rect(Rect2(panel_pos, panel_size), Color(0.4, 0.4, 0.4, 0.6), false, 1.0)

	# Draw text
	var text_pos = panel_pos + padding + Vector2(0, line_height * 0.75)
	for i in range(lines.size()):
		var color = Color.WHITE
		if i == 0:
			color = Color(0.9, 0.9, 0.7)  # Building name
		elif lines[i].begins_with("$"):
			color = Color(0.9, 0.8, 0.3) if _can_afford else Color(1.0, 0.4, 0.4)
		elif lines[i] in _terrain_warnings or "No " in lines[i]:
			color = Color(1.0, 0.6, 0.3)  # Warnings

		draw_string(font, text_pos, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, INFO_FONT_SIZE, color)
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


## Get placement analysis for external use
func get_placement_info() -> Dictionary:
	return {
		"valid": _overall_valid and _can_afford,
		"can_afford": _can_afford,
		"has_power": _has_power_nearby,
		"has_water": _has_water_nearby,
		"terrain_warnings": _terrain_warnings.duplicate(),
		"adjacency_effects": _adjacency_effects.duplicate()
	}
