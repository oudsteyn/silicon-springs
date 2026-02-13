extends Node2D
class_name TerrainRenderer
## Procedural terrain rendering with viewport culling for performance

const TerrainMeshBridgeScript = preload("res://src/terrain/terrain_mesh_bridge.gd")
const TerrainClipmapStreamerScript = preload("res://src/terrain/terrain_clipmap_streamer.gd")
const TerrainDetailScatterScript = preload("res://src/terrain/terrain_detail_scatter.gd")

# References
var terrain_system: TerrainSystem = null
var grid_system: Node = null

# Cached camera for viewport culling
var camera: Camera2D = null

# Chunk-based rendering for performance
const CHUNK_SIZE: int = 16  # Render in 16x16 cell chunks
var dirty_chunks: Dictionary = {}  # Vector2i -> bool (chunk needs redraw)
var chunk_textures: Dictionary = {}  # Vector2i -> ImageTexture

# Track camera position to detect movement and trigger redraws
var _last_camera_position: Vector2 = Vector2.ZERO
var _last_camera_zoom: float = 1.0
var _runtime_heightmap: PackedFloat32Array = PackedFloat32Array()
var _runtime_heightmap_size: int = 0
var _runtime_sea_level: float = 0.0
var _runtime_visible_chunks: Dictionary = {}
var _runtime_detail_transforms: Dictionary = {"grass": [], "rocks": []}
var _mesh_bridge = TerrainMeshBridgeScript.new()
var _clipmap_streamer = TerrainClipmapStreamerScript.new()
var _detail_scatter = TerrainDetailScatterScript.new()

# Color palette for elevation levels
const ELEVATION_COLORS = {
	-3: Color(0.1, 0.2, 0.5),    # Deep water
	-2: Color(0.2, 0.4, 0.7),    # Shallow water
	-1: Color(0.76, 0.7, 0.5),   # Beach/sand
	0:  Color(0.25, 0.45, 0.25), # Grass (default)
	1:  Color(0.3, 0.5, 0.28),   # Low hill
	2:  Color(0.4, 0.5, 0.3),    # Hill
	3:  Color(0.5, 0.48, 0.35),  # High hill
	4:  Color(0.55, 0.5, 0.45),  # Mountain base
	5:  Color(0.85, 0.85, 0.9),  # Mountain peak (snow)
}

# Water overlay colors
const WATER_COLORS = {
	TerrainSystem.WaterType.NONE: Color.TRANSPARENT,
	TerrainSystem.WaterType.POND: Color(0.2, 0.4, 0.7, 0.8),
	TerrainSystem.WaterType.LAKE: Color(0.1, 0.2, 0.5, 0.9),
	TerrainSystem.WaterType.RIVER: Color(0.15, 0.35, 0.65, 0.85),
}

# Feature colors/shapes
const TREE_COLOR: Color = Color(0.15, 0.35, 0.15)
const ROCK_COLOR: Color = Color(0.45, 0.45, 0.48)
const BEACH_COLOR: Color = Color(0.85, 0.8, 0.6)


func _ready() -> void:
	# Ensure terrain renders behind buildings (lower z_index = further back)
	z_index = ZLayers.TERRAIN  # Behind zone layer (-1) and buildings (1)

	# Connect to terrain changes
	Events.terrain_changed.connect(_on_terrain_changed)


func set_terrain_system(ts: TerrainSystem) -> void:
	terrain_system = ts
	if terrain_system:
		terrain_system.terrain_changed.connect(_on_terrain_changed)
		if terrain_system.has_signal("runtime_heightmap_generated") and not terrain_system.runtime_heightmap_generated.is_connected(_on_runtime_heightmap_generated):
			terrain_system.runtime_heightmap_generated.connect(_on_runtime_heightmap_generated)
	# Mark all chunks as dirty for initial render
	_mark_all_chunks_dirty()


func configure_runtime_terrain_pipeline(ts: TerrainSystem) -> void:
	set_terrain_system(ts)
	if terrain_system and terrain_system.has_method("get_runtime_heightmap"):
		var heightmap = terrain_system.get_runtime_heightmap()
		if heightmap.size() > 0:
			var size = terrain_system.get_runtime_heightmap_size()
			var sea_level = terrain_system.get_runtime_sea_level()
			_on_runtime_heightmap_generated(heightmap, size, sea_level)


func set_grid_system(gs: Node) -> void:
	grid_system = gs


func set_camera(cam: Camera2D) -> void:
	camera = cam
	if camera:
		_last_camera_position = camera.position
		_last_camera_zoom = camera.zoom.x


func _process(_delta: float) -> void:
	# Check if camera has moved and trigger redraw
	if camera:
		var position_changed = camera.position != _last_camera_position
		var zoom_changed = camera.zoom.x != _last_camera_zoom

		if position_changed or zoom_changed:
			_last_camera_position = camera.position
			_last_camera_zoom = camera.zoom.x
			var camera3 = Vector3(camera.position.x, 0.0, camera.position.y)
			var update = _clipmap_streamer.update_camera(camera3)
			_runtime_visible_chunks = update.get("visible_chunks", {})
			queue_redraw()


func get_runtime_visible_chunks() -> Dictionary:
	return _runtime_visible_chunks


func get_runtime_detail_counts() -> Dictionary:
	return {
		"grass": _runtime_detail_transforms.get("grass", []).size(),
		"rocks": _runtime_detail_transforms.get("rocks", []).size()
	}


func _mark_all_chunks_dirty() -> void:
	var chunks_x = ceili(float(GridConstants.GRID_WIDTH) / CHUNK_SIZE)
	var chunks_y = ceili(float(GridConstants.GRID_HEIGHT) / CHUNK_SIZE)
	for cx in range(chunks_x):
		for cy in range(chunks_y):
			dirty_chunks[Vector2i(cx, cy)] = true
	queue_redraw()


func _on_terrain_changed(cells: Array) -> void:
	# Mark affected chunks as dirty
	for cell in cells:
		if cell is Vector2i:
			var chunk = Vector2i(int(cell.x / CHUNK_SIZE), int(cell.y / CHUNK_SIZE))
			dirty_chunks[chunk] = true
	queue_redraw()


func _draw() -> void:
	if not terrain_system:
		# Fallback: draw basic green background
		draw_rect(Rect2(0, 0, GridConstants.GRID_WIDTH * GridConstants.CELL_SIZE, GridConstants.GRID_HEIGHT * GridConstants.CELL_SIZE), ELEVATION_COLORS[0])
		return

	# Get visible area for culling
	var visible_rect = _get_visible_rect()

	# Calculate which chunks are visible
	var start_chunk = Vector2i(
		maxi(0, int(visible_rect.position.x / GridConstants.CELL_SIZE / CHUNK_SIZE)),
		maxi(0, int(visible_rect.position.y / GridConstants.CELL_SIZE / CHUNK_SIZE))
	)
	var end_chunk = Vector2i(
		mini(ceili(float(GridConstants.GRID_WIDTH) / CHUNK_SIZE) - 1, int(visible_rect.end.x / GridConstants.CELL_SIZE / CHUNK_SIZE)),
		mini(ceili(float(GridConstants.GRID_HEIGHT) / CHUNK_SIZE) - 1, int(visible_rect.end.y / GridConstants.CELL_SIZE / CHUNK_SIZE))
	)

	# Draw visible chunks
	for cx in range(start_chunk.x, end_chunk.x + 1):
		for cy in range(start_chunk.y, end_chunk.y + 1):
			var chunk_pos = Vector2i(cx, cy)
			_draw_chunk(chunk_pos)


func _on_runtime_heightmap_generated(heightmap: PackedFloat32Array, size: int, sea_level: float) -> void:
	_runtime_heightmap = heightmap
	_runtime_heightmap_size = size
	_runtime_sea_level = sea_level
	_runtime_detail_transforms = _detail_scatter.build_scatter_transforms(heightmap, size, 1.0, sea_level, 1337)
	_runtime_visible_chunks = _clipmap_streamer.update_camera(Vector3.ZERO).get("visible_chunks", {})


func _draw_chunk(chunk_pos: Vector2i) -> void:
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_y = chunk_pos.y * CHUNK_SIZE
	var end_x = mini(start_x + CHUNK_SIZE, GridConstants.GRID_WIDTH)
	var end_y = mini(start_y + CHUNK_SIZE, GridConstants.GRID_HEIGHT)

	for x in range(start_x, end_x):
		for y in range(start_y, end_y):
			var cell = Vector2i(x, y)
			_draw_cell(cell)


func _draw_cell(cell: Vector2i) -> void:
	var pos = Vector2(cell.x * GridConstants.CELL_SIZE, cell.y * GridConstants.CELL_SIZE)

	# Get terrain data
	var elev = terrain_system.get_elevation(cell)
	var water_type = terrain_system.get_water(cell)
	var feature = terrain_system.get_feature(cell)

	# Draw base terrain color
	var base_color = _elevation_to_color(elev)
	draw_rect(Rect2(pos, Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE)), base_color)

	# Draw water overlay if present
	if water_type != TerrainSystem.WaterType.NONE:
		var water_color = WATER_COLORS.get(water_type, Color.TRANSPARENT)
		draw_rect(Rect2(pos, Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE)), water_color)
		# Add subtle wave pattern
		_draw_water_detail(pos, water_type)

	# Draw features on top
	if feature != TerrainSystem.FeatureType.NONE:
		_draw_feature(pos, feature)

	# Draw elevation contour lines (optional, for visual clarity)
	if elev > 0:
		_draw_elevation_hint(pos, elev)


func _elevation_to_color(level: int) -> Color:
	return ELEVATION_COLORS.get(level, ELEVATION_COLORS[0])


func _draw_water_detail(pos: Vector2, water_type: TerrainSystem.WaterType) -> void:
	# Add subtle wave lines for water
	# Vary wave color intensity based on water type
	var base_alpha = 0.15
	if water_type == TerrainSystem.WaterType.RIVER:
		base_alpha = 0.2  # Rivers have more visible waves
	elif water_type == TerrainSystem.WaterType.LAKE:
		base_alpha = 0.12  # Lakes have subtler waves
	var wave_color = Color(1, 1, 1, base_alpha)

	# Simple wave pattern
	var offset = fmod(Time.get_ticks_msec() / 1000.0, 1.0) * 8
	draw_line(
		pos + Vector2(8, 24 + offset),
		pos + Vector2(56, 24 + offset),
		wave_color, 1.0
	)
	draw_line(
		pos + Vector2(12, 40 - offset),
		pos + Vector2(52, 40 - offset),
		wave_color, 1.0
	)


func _draw_feature(pos: Vector2, feature: TerrainSystem.FeatureType) -> void:
	var center = pos + Vector2(GridConstants.CELL_SIZE * 0.5, GridConstants.CELL_SIZE * 0.5)

	match feature:
		TerrainSystem.FeatureType.TREE_SPARSE:
			_draw_tree(center, false)
		TerrainSystem.FeatureType.TREE_DENSE:
			_draw_tree(center, true)
		TerrainSystem.FeatureType.ROCK_SMALL:
			_draw_rock(center, false)
		TerrainSystem.FeatureType.ROCK_LARGE:
			_draw_rock(center, true)
		TerrainSystem.FeatureType.BEACH:
			_draw_beach_detail(pos)


func _draw_tree(center: Vector2, dense: bool) -> void:
	var tree_color = TREE_COLOR
	var trunk_color = Color(0.4, 0.25, 0.15)

	if dense:
		# Dense forest - multiple overlapping trees
		for i in range(3):
			var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
			var tree_center = center + offset
			# Trunk
			draw_rect(Rect2(tree_center.x - 2, tree_center.y, 4, 12), trunk_color)
			# Foliage (triangle)
			var points = PackedVector2Array([
				tree_center + Vector2(0, -16),
				tree_center + Vector2(-12, 4),
				tree_center + Vector2(12, 4)
			])
			draw_colored_polygon(points, tree_color.darkened(randf_range(0, 0.2)))
	else:
		# Single tree
		# Trunk
		draw_rect(Rect2(center.x - 3, center.y + 4, 6, 14), trunk_color)
		# Foliage (triangle)
		var points = PackedVector2Array([
			center + Vector2(0, -18),
			center + Vector2(-14, 6),
			center + Vector2(14, 6)
		])
		draw_colored_polygon(points, tree_color)


func _draw_rock(center: Vector2, large: bool) -> void:
	var rock_color = ROCK_COLOR
	var shadow_color = rock_color.darkened(0.3)

	if large:
		# Large rock formation - draw shadow first
		var shadow_points = PackedVector2Array([
			center + Vector2(-16, 12),
			center + Vector2(-12, -8),
			center + Vector2(4, -14),
			center + Vector2(18, -4),
			center + Vector2(20, 10),
			center + Vector2(8, 16),
			center + Vector2(-6, 14)
		])
		draw_colored_polygon(shadow_points, shadow_color)
		# Main rock
		var points = PackedVector2Array([
			center + Vector2(-18, 8),
			center + Vector2(-14, -12),
			center + Vector2(2, -18),
			center + Vector2(16, -8),
			center + Vector2(18, 6),
			center + Vector2(6, 12),
			center + Vector2(-8, 10)
		])
		draw_colored_polygon(points, rock_color)
		# Highlight
		draw_line(center + Vector2(-10, -8), center + Vector2(4, -14), Color(1, 1, 1, 0.2), 2)
	else:
		# Small rock - draw shadow first
		var shadow_points = PackedVector2Array([
			center + Vector2(-8, 8),
			center + Vector2(-4, -4),
			center + Vector2(6, -6),
			center + Vector2(12, 2),
			center + Vector2(10, 10),
			center + Vector2(-2, 12)
		])
		draw_colored_polygon(shadow_points, shadow_color)
		# Main rock
		var points = PackedVector2Array([
			center + Vector2(-10, 4),
			center + Vector2(-6, -8),
			center + Vector2(4, -10),
			center + Vector2(10, -2),
			center + Vector2(8, 6),
			center + Vector2(-4, 8)
		])
		draw_colored_polygon(points, rock_color)


func _draw_beach_detail(pos: Vector2) -> void:
	# Add sandy texture dots
	var sand_light = Color(0.9, 0.85, 0.7)
	var rng = RandomNumberGenerator.new()
	rng.seed = int(pos.x + pos.y * 1000)

	for _i in range(5):
		var dot_pos = pos + Vector2(rng.randf_range(8, 56), rng.randf_range(8, 56))
		draw_circle(dot_pos, 2, sand_light)


func _draw_elevation_hint(pos: Vector2, elev: int) -> void:
	# Draw subtle contour/shadow on elevated terrain
	if elev >= 2:
		var shadow_color = Color(0, 0, 0, 0.1)
		# Bottom edge shadow
		draw_line(pos + Vector2(0, GridConstants.CELL_SIZE - 2), pos + Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE - 2), shadow_color, 2)
		# Right edge shadow
		draw_line(pos + Vector2(GridConstants.CELL_SIZE - 2, 0), pos + Vector2(GridConstants.CELL_SIZE - 2, GridConstants.CELL_SIZE), shadow_color, 2)


func _get_visible_rect() -> Rect2:
	if camera:
		var viewport_size = get_viewport_rect().size
		var zoom = camera.zoom
		var visible_size = viewport_size / zoom
		var top_left = camera.position - visible_size / 2
		return Rect2(top_left, visible_size)

	# Fallback: assume entire map is visible
	return Rect2(0, 0, GridConstants.GRID_WIDTH * GridConstants.CELL_SIZE, GridConstants.GRID_HEIGHT * GridConstants.CELL_SIZE)


# Force redraw of entire terrain
func refresh() -> void:
	_mark_all_chunks_dirty()
	queue_redraw()
