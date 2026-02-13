extends Control
class_name MinimapOverlay
## Minimap showing overview of the game world with click-to-navigate functionality
## Displays terrain, buildings, zones, and camera viewport indicator


# Minimap configuration
const DEFAULT_SIZE: Vector2 = Vector2(200, 200)
const MIN_SIZE: Vector2 = Vector2(120, 120)
const MAX_SIZE: Vector2 = Vector2(400, 400)
const MARGIN: float = 16.0
const BORDER_WIDTH: float = 2.0
const CORNER_RADIUS: float = 4.0

# Colors
const BG_COLOR: Color = Color(0.05, 0.08, 0.05, 0.85)
const BORDER_COLOR: Color = Color(0.3, 0.4, 0.3, 0.9)
const VIEWPORT_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)
const VIEWPORT_FILL_COLOR: Color = Color(1.0, 1.0, 1.0, 0.1)

# Terrain colors
const TERRAIN_WATER: Color = Color(0.2, 0.4, 0.7, 1.0)
const TERRAIN_BEACH: Color = Color(0.8, 0.75, 0.5, 1.0)
const TERRAIN_GRASS: Color = Color(0.25, 0.45, 0.25, 1.0)
const TERRAIN_HILL: Color = Color(0.4, 0.5, 0.35, 1.0)
const TERRAIN_MOUNTAIN: Color = Color(0.5, 0.5, 0.5, 1.0)

# Building category colors
const BUILDING_COLORS: Dictionary = {
	"infrastructure": Color(0.5, 0.5, 0.5, 1.0),
	"power": Color(1.0, 0.9, 0.2, 1.0),
	"water": Color(0.3, 0.6, 0.95, 1.0),
	"service": Color(0.9, 0.3, 0.3, 1.0),
	"data_center": Color(0.2, 0.9, 0.5, 1.0),
	"residential": Color(0.3, 0.7, 0.3, 1.0),
	"commercial": Color(0.3, 0.3, 0.8, 1.0),
	"industrial": Color(0.7, 0.7, 0.2, 1.0),
	"zone": Color(0.5, 0.5, 0.5, 0.5),
}

# State
var _minimap_size: Vector2 = DEFAULT_SIZE
var _scale: Vector2 = Vector2.ONE  # World to minimap scale
var _world_cell_size: Vector2i = Vector2i(GridConstants.GRID_WIDTH, GridConstants.GRID_HEIGHT)
var _terrain_texture: ImageTexture = null
var _terrain_dirty: bool = true
var _buildings_dirty: bool = true

# Cached building positions
var _building_markers: Array[Dictionary] = []  # [{pos: Vector2, color: Color, size: float}]

# System references
var camera: Camera2D = null
var terrain_system = null
var grid_system = null
var zoning_system = null

# Interaction
var _is_dragging: bool = false
var _show_zones: bool = false
var _events: Node = null


func _ready() -> void:
	# Position in top-right corner
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -_minimap_size.x - MARGIN
	offset_right = -MARGIN
	offset_top = MARGIN
	offset_bottom = _minimap_size.y + MARGIN

	custom_minimum_size = _minimap_size
	size = _minimap_size

	# Calculate scale
	_recalculate_scale()

	# Connect to events
	var events = _get_events()
	if events:
		events.building_placed.connect(_on_building_changed)
		events.building_removed.connect(_on_building_changed)
		events.terrain_changed.connect(_on_terrain_changed)

	mouse_filter = Control.MOUSE_FILTER_STOP


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


func set_terrain_system(ts) -> void:
	terrain_system = ts
	_terrain_dirty = true


func set_grid_system(gs) -> void:
	grid_system = gs
	_buildings_dirty = true


func set_zoning_system(zs) -> void:
	zoning_system = zs


func _process(_delta: float) -> void:
	# Rebuild terrain texture if dirty
	if _terrain_dirty:
		_rebuild_terrain_texture()

	# Rebuild building markers if dirty
	if _buildings_dirty:
		_rebuild_building_markers()

	queue_redraw()


func _rebuild_terrain_texture() -> void:
	if not terrain_system:
		_terrain_dirty = false
		return

	# Create an image for the terrain
	var world_size = _get_world_cell_size()
	var img = Image.create(world_size.x, world_size.y, false, Image.FORMAT_RGBA8)

	for x in range(world_size.x):
		for y in range(world_size.y):
			var cell = Vector2i(x, y)
			var color = _get_terrain_color(cell)
			img.set_pixel(x, y, color)

	_terrain_texture = ImageTexture.create_from_image(img)
	_terrain_dirty = false


func _get_terrain_color(cell: Vector2i) -> Color:
	if not terrain_system:
		return TERRAIN_GRASS

	var elevation = terrain_system.get_elevation(cell)
	var water_type = terrain_system.get_water(cell)

	if water_type != 0:  # Has water
		return TERRAIN_WATER

	match elevation:
		-1:
			return TERRAIN_BEACH
		0, 1:
			return TERRAIN_GRASS
		2, 3:
			return TERRAIN_HILL
		_:
			if elevation >= 4:
				return TERRAIN_MOUNTAIN
			elif elevation <= -2:
				return TERRAIN_WATER
			return TERRAIN_GRASS


func _rebuild_building_markers() -> void:
	_building_markers.clear()
	var map_origin = _get_map_draw_rect().position

	if not grid_system:
		_buildings_dirty = false
		return

	var counted: Dictionary = {}

	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if not building.building_data:
			continue

		var category = building.building_data.category
		var color = BUILDING_COLORS.get(category, Color.WHITE)

		# Determine marker size based on building size
		var bsize = building.building_data.size
		var marker_size = maxf(bsize.x, bsize.y) * 1.5

		# Calculate position on minimap
		var world_pos = Vector2(cell) * GridConstants.CELL_SIZE + Vector2(bsize) * GridConstants.CELL_SIZE * 0.5
		var minimap_pos = map_origin + world_pos * _scale

		_building_markers.append({
			"pos": minimap_pos,
			"color": color,
			"size": marker_size
		})

	_buildings_dirty = false


func _draw() -> void:
	# Draw background
	draw_rect(Rect2(Vector2.ZERO, _minimap_size), BG_COLOR)
	var map_rect = _get_map_draw_rect()

	# Draw terrain texture
	if _terrain_texture:
		draw_texture_rect(_terrain_texture, map_rect, false)

	# Draw zones if enabled
	if _show_zones:
		_draw_zones()

	# Draw building markers
	_draw_building_markers()

	# Draw camera viewport
	_draw_viewport_indicator()

	# Draw border
	draw_rect(Rect2(Vector2.ZERO, _minimap_size), BORDER_COLOR, false, BORDER_WIDTH)

	# Draw corner accents
	_draw_corner_accents()


func _draw_zones() -> void:
	if not zoning_system:
		return

	var map_origin = _get_map_draw_rect().position
	var zones = zoning_system.get_all_zones()
	for cell in zones:
		var zone_data = zones[cell]
		var color = zoning_system.get_zone_color(zone_data.type)
		color.a = 0.4

		var minimap_pos = map_origin + Vector2(cell) * GridConstants.CELL_SIZE * _scale
		var minimap_size = Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE) * _scale
		draw_rect(Rect2(minimap_pos, minimap_size), color)


func _draw_building_markers() -> void:
	for marker in _building_markers:
		var pos = marker.pos as Vector2
		var color = marker.color as Color
		var marker_size = marker.size as float

		# Scale marker size
		var scaled_size = maxf(marker_size * _scale.x * 0.8, 1.5)
		draw_circle(pos, scaled_size, color)


func _draw_viewport_indicator() -> void:
	if not camera:
		return
	var map_rect = _get_map_draw_rect()

	var viewport_size = get_viewport_rect().size
	var half_size = viewport_size / (2.0 * camera.zoom.x)

	# Calculate viewport rectangle in minimap coordinates
	var vp_min = map_rect.position + (camera.position - half_size) * _scale
	var vp_max = map_rect.position + (camera.position + half_size) * _scale

	# Clamp to minimap bounds
	vp_min = vp_min.clamp(map_rect.position, map_rect.end)
	vp_max = vp_max.clamp(map_rect.position, map_rect.end)

	var vp_rect = Rect2(vp_min, vp_max - vp_min)

	# Draw fill
	draw_rect(vp_rect, VIEWPORT_FILL_COLOR)

	# Draw border
	draw_rect(vp_rect, VIEWPORT_COLOR, false, 1.5)


func _draw_corner_accents() -> void:
	var accent_color = BORDER_COLOR.lightened(0.2)
	var accent_length = 8.0
	var accent_width = 2.0

	# Top-left
	draw_line(Vector2.ZERO, Vector2(accent_length, 0), accent_color, accent_width)
	draw_line(Vector2.ZERO, Vector2(0, accent_length), accent_color, accent_width)

	# Top-right
	draw_line(Vector2(_minimap_size.x, 0), Vector2(_minimap_size.x - accent_length, 0), accent_color, accent_width)
	draw_line(Vector2(_minimap_size.x, 0), Vector2(_minimap_size.x, accent_length), accent_color, accent_width)

	# Bottom-left
	draw_line(Vector2(0, _minimap_size.y), Vector2(accent_length, _minimap_size.y), accent_color, accent_width)
	draw_line(Vector2(0, _minimap_size.y), Vector2(0, _minimap_size.y - accent_length), accent_color, accent_width)

	# Bottom-right
	draw_line(_minimap_size, _minimap_size - Vector2(accent_length, 0), accent_color, accent_width)
	draw_line(_minimap_size, _minimap_size - Vector2(0, accent_length), accent_color, accent_width)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_dragging = true
				_navigate_to_position(event.position)
			else:
				_is_dragging = false
			accept_event()  # Consume event to prevent building placement

	elif event is InputEventMouseMotion and _is_dragging:
		_navigate_to_position(event.position)
		accept_event()  # Consume event to prevent building placement


func _navigate_to_position(minimap_pos: Vector2) -> void:
	if not camera:
		return

	var map_rect = _get_map_draw_rect()
	# Clamp position to map drawing bounds
	minimap_pos = minimap_pos.clamp(map_rect.position, map_rect.end)

	# Convert minimap position to world position
	var world_pos = (minimap_pos - map_rect.position) / _scale

	# Move camera
	camera.position = world_pos


# Public API
func set_minimap_size(new_size: Vector2) -> void:
	_minimap_size = new_size.clamp(MIN_SIZE, MAX_SIZE)
	_recalculate_scale()

	custom_minimum_size = _minimap_size
	size = _minimap_size

	offset_left = -_minimap_size.x - MARGIN
	offset_bottom = _minimap_size.y + MARGIN

	_buildings_dirty = true


func set_world_cell_size(world_cell_size: Vector2i) -> void:
	_world_cell_size = Vector2i(maxi(1, world_cell_size.x), maxi(1, world_cell_size.y))
	_recalculate_scale()
	_terrain_dirty = true
	_buildings_dirty = true


func _get_map_draw_rect() -> Rect2:
	var inset = BORDER_WIDTH
	var available_size = _get_map_draw_size()
	var world_size = _get_world_pixel_size()
	var world_aspect = world_size.x / world_size.y
	var available_aspect = available_size.x / available_size.y
	var map_size = available_size
	if world_aspect > available_aspect:
		map_size.y = available_size.x / world_aspect
	else:
		map_size.x = available_size.y * world_aspect
	var map_pos = Vector2(inset, inset) + (available_size - map_size) * 0.5
	return Rect2(map_pos, map_size)


func _get_map_draw_size() -> Vector2:
	var inset = BORDER_WIDTH * 2.0
	return Vector2(maxf(1.0, _minimap_size.x - inset), maxf(1.0, _minimap_size.y - inset))


func _get_world_cell_size() -> Vector2i:
	return _world_cell_size


func _get_world_pixel_size() -> Vector2:
	var world_size = _get_world_cell_size()
	return Vector2(world_size.x * GridConstants.CELL_SIZE, world_size.y * GridConstants.CELL_SIZE)


func _recalculate_scale() -> void:
	_scale = _get_map_draw_rect().size / _get_world_pixel_size()


func toggle_zones() -> void:
	_show_zones = not _show_zones


func show_zones(should_show: bool) -> void:
	_show_zones = should_show


func refresh() -> void:
	_terrain_dirty = true
	_buildings_dirty = true


# Event handlers
func _on_building_changed(_cell: Vector2i, _building = null) -> void:
	_buildings_dirty = true


func _on_terrain_changed(_cells: Array) -> void:
	_terrain_dirty = true
