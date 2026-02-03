extends Node2D
class_name AdaptiveGridRenderer
## Efficient adaptive grid rendering with zoom-based density and terrain integration
## Replaces separate sparse grid + fine_grid with single unified rendering system
## Uses _draw() for efficient rendering instead of creating/destroying Line2D nodes

# Zoom-based density thresholds
enum GridDensity { NONE, SPARSE, MEDIUM, FULL }
const ZOOM_THRESHOLD_SPARSE: float = 0.5   # Below: no grid
const ZOOM_THRESHOLD_MEDIUM: float = 0.85  # Below: sparse (every 10 cells)
const ZOOM_THRESHOLD_FULL: float = 1.3     # Below: medium (every 5 cells), Above: full (every cell)

# Grid line appearance
const LINE_WIDTH_MAJOR: float = 1.5
const LINE_WIDTH_MINOR: float = 1.0
const LINE_WIDTH_CELL: float = 0.5

# Base colors (modified by terrain)
const COLOR_MAJOR: Color = Color(0.3, 0.5, 0.3, 0.6)
const COLOR_MINOR: Color = Color(0.25, 0.4, 0.25, 0.4)
const COLOR_CELL: Color = Color(0.2, 0.35, 0.2, 0.25)

# Terrain color modifiers
const WATER_TINT: Color = Color(0.3, 0.5, 0.8, 1.0)
const HILL_TINT: Color = Color(0.7, 0.6, 0.5, 1.0)
const VALLEY_TINT: Color = Color(0.15, 0.25, 0.15, 1.0)

# Build mode enhancement
const BUILD_MODE_BOOST: float = 1.5  # Alpha multiplier in build mode
const BUILD_HIGHLIGHT_RADIUS: int = 12  # Cells around cursor with enhanced visibility

# System references
var camera: Camera2D = null
var terrain_system = null
var grid_system = null

# Current state
var _current_density: GridDensity = GridDensity.MEDIUM
var _target_density: GridDensity = GridDensity.MEDIUM
var _density_transition: float = 1.0  # 0-1 for smooth transitions
var _density_transition_speed: float = 8.0

# Interaction state
var _build_mode: bool = false
var _cursor_cell: Vector2i = Vector2i(-1, -1)

# Viewport culling
var _visible_rect: Rect2 = Rect2()
var _visible_cells: Rect2i = Rect2i()

# Cached terrain colors per cell (rebuilt when terrain changes)
var _terrain_color_cache: Dictionary = {}  # Vector2i -> Color modifier
var _terrain_cache_dirty: bool = true

# Performance: skip rendering when camera hasn't moved
var _last_camera_pos: Vector2 = Vector2.ZERO
var _last_camera_zoom: float = 1.0
var _needs_redraw: bool = true


func _ready() -> void:
	z_index = ZLayers.GRID_LINES  # Above terrain, below buildings

	# Connect to terrain changes
	Events.terrain_changed.connect(_on_terrain_changed)
	Events.build_mode_entered.connect(_on_build_mode_entered)
	Events.build_mode_exited.connect(_on_build_mode_exited)
	Events.cell_hovered.connect(_on_cell_hovered)


func set_camera(cam: Camera2D) -> void:
	camera = cam


func set_terrain_system(ts) -> void:
	terrain_system = ts
	_terrain_cache_dirty = true


func set_grid_system(gs) -> void:
	grid_system = gs


func _process(delta: float) -> void:
	if not camera:
		return

	# Check if camera moved or zoomed
	var camera_changed = false
	if camera.position != _last_camera_pos or camera.zoom.x != _last_camera_zoom:
		_last_camera_pos = camera.position
		_last_camera_zoom = camera.zoom.x
		camera_changed = true
		_needs_redraw = true

	# Update grid density based on zoom
	var new_density = _calculate_density_for_zoom(camera.zoom.x)
	if new_density != _target_density:
		_target_density = new_density
		_density_transition = 0.0

	# Animate density transition
	if _density_transition < 1.0:
		_density_transition = minf(_density_transition + delta * _density_transition_speed, 1.0)
		_current_density = _target_density if _density_transition > 0.5 else _current_density
		_needs_redraw = true

	# Update visible area
	if camera_changed:
		_update_visible_area()

	# Rebuild terrain cache if needed
	if _terrain_cache_dirty:
		_rebuild_terrain_color_cache()

	if _needs_redraw:
		queue_redraw()
		_needs_redraw = false


func _calculate_density_for_zoom(zoom: float) -> GridDensity:
	if zoom < ZOOM_THRESHOLD_SPARSE:
		return GridDensity.NONE
	elif zoom < ZOOM_THRESHOLD_MEDIUM:
		return GridDensity.SPARSE
	elif zoom < ZOOM_THRESHOLD_FULL:
		return GridDensity.MEDIUM
	else:
		return GridDensity.FULL


func _update_visible_area() -> void:
	if not camera:
		return

	var viewport_size = get_viewport_rect().size
	var half_size = viewport_size / (2.0 * camera.zoom.x)

	# Calculate visible world rect with padding
	var padding = GridConstants.CELL_SIZE * 2  # Extra cells for smooth scrolling
	_visible_rect = Rect2(
		camera.position - half_size - Vector2(padding, padding),
		half_size * 2 + Vector2(padding * 2, padding * 2)
	)

	# Convert to cell coordinates
	var min_cell = Vector2i(
		maxi(0, int(_visible_rect.position.x / GridConstants.CELL_SIZE)),
		maxi(0, int(_visible_rect.position.y / GridConstants.CELL_SIZE))
	)
	var max_cell = Vector2i(
		mini(GridConstants.GRID_WIDTH, int((_visible_rect.position.x + _visible_rect.size.x) / GridConstants.CELL_SIZE) + 1),
		mini(GridConstants.GRID_HEIGHT, int((_visible_rect.position.y + _visible_rect.size.y) / GridConstants.CELL_SIZE) + 1)
	)

	_visible_cells = Rect2i(min_cell, max_cell - min_cell)


func _rebuild_terrain_color_cache() -> void:
	_terrain_color_cache.clear()

	if not terrain_system:
		_terrain_cache_dirty = false
		return

	# Only cache visible cells + buffer
	var cache_rect = _visible_cells.grow(5)

	for x in range(cache_rect.position.x, cache_rect.position.x + cache_rect.size.x):
		for y in range(cache_rect.position.y, cache_rect.position.y + cache_rect.size.y):
			var cell = Vector2i(x, y)
			if x >= 0 and x < GridConstants.GRID_WIDTH and y >= 0 and y < GridConstants.GRID_HEIGHT:
				_terrain_color_cache[cell] = _calculate_terrain_color_modifier(cell)

	_terrain_cache_dirty = false


func _calculate_terrain_color_modifier(cell: Vector2i) -> Color:
	if not terrain_system:
		return Color.WHITE

	var elevation = terrain_system.get_elevation(cell)
	var water_type = terrain_system.get_water(cell)

	# Water cells get blue tint
	if water_type != 0:  # Not WaterType.NONE
		return WATER_TINT

	# Elevation-based tinting
	if elevation >= 3:
		# High elevation - lighter/warmer
		var t = (elevation - 3) / 2.0  # 0-1 for elevation 3-5
		return HILL_TINT.lerp(Color(0.8, 0.75, 0.7, 1.0), t)
	elif elevation <= -1:
		# Low elevation - darker
		var t = (-1 - elevation) / 2.0  # 0-1 for elevation -1 to -3
		return VALLEY_TINT.lerp(Color(0.1, 0.15, 0.1, 1.0), t)
	elif elevation >= 1:
		# Low hills - slight warm tint
		var t = elevation / 2.0
		return Color.WHITE.lerp(HILL_TINT, t * 0.3)

	return Color.WHITE


func _draw() -> void:
	if _current_density == GridDensity.NONE:
		return

	# Calculate alpha based on transition
	var alpha_multiplier = 1.0
	if _density_transition < 1.0:
		# Fade during transitions
		alpha_multiplier = 0.7 + 0.3 * _ease_out_cubic(_density_transition)

	# Build mode boost
	if _build_mode:
		alpha_multiplier *= BUILD_MODE_BOOST

	# Draw grid based on current density
	match _current_density:
		GridDensity.SPARSE:
			_draw_sparse_grid(alpha_multiplier)
		GridDensity.MEDIUM:
			_draw_medium_grid(alpha_multiplier)
		GridDensity.FULL:
			_draw_full_grid(alpha_multiplier)


func _draw_sparse_grid(alpha_mult: float) -> void:
	# Draw major grid lines every 10 cells
	_draw_grid_at_interval(10, COLOR_MAJOR, LINE_WIDTH_MAJOR, alpha_mult)


func _draw_medium_grid(alpha_mult: float) -> void:
	# Draw minor grid lines every 5 cells
	_draw_grid_at_interval(5, COLOR_MINOR, LINE_WIDTH_MINOR, alpha_mult * 0.7)
	# Draw major grid lines every 10 cells
	_draw_grid_at_interval(10, COLOR_MAJOR, LINE_WIDTH_MAJOR, alpha_mult)


func _draw_full_grid(alpha_mult: float) -> void:
	# Draw cell grid (every cell)
	_draw_cell_grid(alpha_mult)
	# Draw minor grid lines every 5 cells
	_draw_grid_at_interval(5, COLOR_MINOR, LINE_WIDTH_MINOR, alpha_mult * 0.8)
	# Draw major grid lines every 10 cells
	_draw_grid_at_interval(10, COLOR_MAJOR, LINE_WIDTH_MAJOR, alpha_mult)


func _draw_grid_at_interval(interval: int, base_color: Color, width: float, alpha_mult: float) -> void:
	var min_x: int = int(_visible_cells.position.x / float(interval)) * interval
	var min_y: int = int(_visible_cells.position.y / float(interval)) * interval
	var max_x = _visible_cells.position.x + _visible_cells.size.x
	var max_y = _visible_cells.position.y + _visible_cells.size.y

	# Vertical lines
	for x in range(min_x, max_x + 1, interval):
		if x < 0 or x > GridConstants.GRID_WIDTH:
			continue

		var color = base_color
		color.a *= alpha_mult

		# Apply terrain tinting at line intersections
		if terrain_system:
			var sample_y: int = _visible_cells.position.y + int(_visible_cells.size.y * 0.5)
			var terrain_mod = _terrain_color_cache.get(Vector2i(x, sample_y), Color.WHITE)
			color = _apply_terrain_tint(color, terrain_mod)

		var start = Vector2(x * GridConstants.CELL_SIZE, _visible_cells.position.y * GridConstants.CELL_SIZE)
		var end = Vector2(x * GridConstants.CELL_SIZE, (max_y + 1) * GridConstants.CELL_SIZE)
		draw_line(start, end, color, width, true)

	# Horizontal lines
	for y in range(min_y, max_y + 1, interval):
		if y < 0 or y > GridConstants.GRID_HEIGHT:
			continue

		var color = base_color
		color.a *= alpha_mult

		# Apply terrain tinting
		if terrain_system:
			var sample_x: int = _visible_cells.position.x + int(_visible_cells.size.x * 0.5)
			var terrain_mod = _terrain_color_cache.get(Vector2i(sample_x, y), Color.WHITE)
			color = _apply_terrain_tint(color, terrain_mod)

		var start = Vector2(_visible_cells.position.x * GridConstants.CELL_SIZE, y * GridConstants.CELL_SIZE)
		var end = Vector2((max_x + 1) * GridConstants.CELL_SIZE, y * GridConstants.CELL_SIZE)
		draw_line(start, end, color, width, true)


func _draw_cell_grid(alpha_mult: float) -> void:
	# Optimized cell grid drawing for full density mode
	# Only draw cells near cursor in build mode, or a subset otherwise

	var min_x = _visible_cells.position.x
	var min_y = _visible_cells.position.y
	var max_x = min_x + _visible_cells.size.x
	var max_y = min_y + _visible_cells.size.y

	# In build mode, restrict to cells near cursor for performance
	if _build_mode and _cursor_cell != Vector2i(-1, -1):
		min_x = maxi(min_x, _cursor_cell.x - BUILD_HIGHLIGHT_RADIUS)
		max_x = mini(max_x, _cursor_cell.x + BUILD_HIGHLIGHT_RADIUS + 1)
		min_y = maxi(min_y, _cursor_cell.y - BUILD_HIGHLIGHT_RADIUS)
		max_y = mini(max_y, _cursor_cell.y + BUILD_HIGHLIGHT_RADIUS + 1)

	# Vertical lines
	for x in range(min_x, max_x + 1):
		if x < 0 or x > GridConstants.GRID_WIDTH:
			continue

		# Calculate distance-based alpha for build mode
		var dist_alpha = 1.0
		if _build_mode and _cursor_cell != Vector2i(-1, -1):
			var dx = abs(x - _cursor_cell.x)
			dist_alpha = 1.0 - (float(dx) / BUILD_HIGHLIGHT_RADIUS) * 0.6

		var color = COLOR_CELL
		color.a *= alpha_mult * dist_alpha

		# Sample terrain color at midpoint
		if terrain_system:
			var sample_y: int = int((min_y + max_y) * 0.5)
			var terrain_mod = _terrain_color_cache.get(Vector2i(x, sample_y), Color.WHITE)
			color = _apply_terrain_tint(color, terrain_mod)

		var start_y = mini(min_y, 0) * GridConstants.CELL_SIZE
		var end_y = (max_y + 1) * GridConstants.CELL_SIZE
		draw_line(Vector2(x * GridConstants.CELL_SIZE, start_y), Vector2(x * GridConstants.CELL_SIZE, end_y), color, LINE_WIDTH_CELL, true)

	# Horizontal lines
	for y in range(min_y, max_y + 1):
		if y < 0 or y > GridConstants.GRID_HEIGHT:
			continue

		var dist_alpha = 1.0
		if _build_mode and _cursor_cell != Vector2i(-1, -1):
			var dy = abs(y - _cursor_cell.y)
			dist_alpha = 1.0 - (float(dy) / BUILD_HIGHLIGHT_RADIUS) * 0.6

		var color = COLOR_CELL
		color.a *= alpha_mult * dist_alpha

		if terrain_system:
			var sample_x: int = int((min_x + max_x) * 0.5)
			var terrain_mod = _terrain_color_cache.get(Vector2i(sample_x, y), Color.WHITE)
			color = _apply_terrain_tint(color, terrain_mod)

		var start_x = mini(min_x, 0) * GridConstants.CELL_SIZE
		var end_x = (max_x + 1) * GridConstants.CELL_SIZE
		draw_line(Vector2(start_x, y * GridConstants.CELL_SIZE), Vector2(end_x, y * GridConstants.CELL_SIZE), color, LINE_WIDTH_CELL, true)


func _apply_terrain_tint(base_color: Color, terrain_mod: Color) -> Color:
	# Blend base grid color with terrain modifier
	var result = base_color
	result.r *= terrain_mod.r
	result.g *= terrain_mod.g
	result.b *= terrain_mod.b
	return result


func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


# Event handlers
func _on_terrain_changed(_cells: Array) -> void:
	_terrain_cache_dirty = true
	_needs_redraw = true


func _on_build_mode_entered(_building_id: String) -> void:
	_build_mode = true
	_needs_redraw = true


func _on_build_mode_exited() -> void:
	_build_mode = false
	_needs_redraw = true


func _on_cell_hovered(cell: Vector2i) -> void:
	if _cursor_cell != cell:
		_cursor_cell = cell
		if _build_mode:
			_needs_redraw = true


## Force a full redraw (e.g., after loading)
func refresh() -> void:
	_terrain_cache_dirty = true
	_needs_redraw = true
	queue_redraw()


## Get current grid density level
func get_density() -> GridDensity:
	return _current_density


## Get the density name for UI display
func get_density_name() -> String:
	match _current_density:
		GridDensity.NONE: return "Hidden"
		GridDensity.SPARSE: return "Sparse"
		GridDensity.MEDIUM: return "Medium"
		GridDensity.FULL: return "Full"
	return "Unknown"
