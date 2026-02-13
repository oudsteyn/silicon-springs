extends Node2D
class_name TerrainRenderer
## Procedural terrain rendering with viewport culling for performance

const TerrainMeshBridgeScript = preload("res://src/terrain/terrain_mesh_bridge.gd")
const TerrainClipmapStreamerScript = preload("res://src/terrain/terrain_clipmap_streamer.gd")
const TerrainDetailScatterScript = preload("res://src/terrain/terrain_detail_scatter.gd")
const TerrainRuntime3DManagerScript = preload("res://src/terrain/terrain_runtime_3d_manager.gd")
const TerrainDetailRenderer3DScript = preload("res://src/terrain/terrain_detail_renderer_3d.gd")

# References
var terrain_system: Node = null
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
var _runtime_3d_manager = TerrainRuntime3DManagerScript.new()
var _runtime_detail_renderer = TerrainDetailRenderer3DScript.new()
var _runtime_3d_enabled: bool = false

# Color palette for elevation levels - realistic terrain colors
const ELEVATION_COLORS = {
	-3: Color(0.08, 0.15, 0.42),   # Deep water - dark ocean blue
	-2: Color(0.18, 0.35, 0.58),   # Shallow water - lighter blue
	-1: Color(0.78, 0.72, 0.52),   # Beach/sand - warm tan
	0:  Color(0.28, 0.52, 0.22),   # Lush grassland - vibrant green
	1:  Color(0.35, 0.50, 0.25),   # Slightly drier grass - olive green
	2:  Color(0.48, 0.46, 0.30),   # Scrubland - brown-green
	3:  Color(0.52, 0.44, 0.32),   # Exposed rock/dirt - warm brown
	4:  Color(0.58, 0.56, 0.52),   # Grey rock - stone grey
	5:  Color(0.92, 0.90, 0.95),   # Snow-cap - bright white
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
const TERRAIN_BLEND_ALPHA: float = 0.28
const TERRAIN_BLEND_EDGE_WIDTH: float = 9.0
const TERRAIN_BLEND_CORNER_RADIUS: float = 12.0
const TERRAIN_BLEND_COLOR_DELTA: float = 0.025


func _ready() -> void:
	# Ensure terrain renders behind buildings (lower z_index = further back)
	z_index = ZLayers.TERRAIN  # Behind zone layer (-1) and buildings (1)

	# Connect to terrain changes
	Events.terrain_changed.connect(_on_terrain_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_runtime_3d_nodes()


func set_terrain_system(ts: Node) -> void:
	if terrain_system and is_instance_valid(terrain_system):
		if terrain_system.terrain_changed.is_connected(_on_terrain_changed):
			terrain_system.terrain_changed.disconnect(_on_terrain_changed)
		if terrain_system.has_signal("runtime_heightmap_generated") and terrain_system.runtime_heightmap_generated.is_connected(_on_runtime_heightmap_generated):
			terrain_system.runtime_heightmap_generated.disconnect(_on_runtime_heightmap_generated)
	terrain_system = ts
	if terrain_system:
		if not terrain_system.terrain_changed.is_connected(_on_terrain_changed):
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


func set_runtime_3d_enabled(enabled: bool) -> void:
	_runtime_3d_enabled = enabled
	if _runtime_3d_enabled:
		_sync_runtime_3d_pipeline()


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
			_sync_runtime_3d_pipeline()
			queue_redraw()


func get_runtime_visible_chunks() -> Dictionary:
	return _runtime_visible_chunks


func get_runtime_detail_counts() -> Dictionary:
	return {
		"grass": _runtime_detail_transforms.get("grass", []).size(),
		"rocks": _runtime_detail_transforms.get("rocks", []).size()
	}


func get_runtime_3d_stats() -> Dictionary:
	var active_chunks = 0
	var chunk_pool = 0
	var grass_instances = 0
	var rock_instances = 0
	if _runtime_3d_manager and is_instance_valid(_runtime_3d_manager):
		active_chunks = _runtime_3d_manager.get_active_chunk_count()
		chunk_pool = _runtime_3d_manager.get_pool_size()
	if _runtime_detail_renderer and is_instance_valid(_runtime_detail_renderer):
		grass_instances = _runtime_detail_renderer.get_grass_count()
		rock_instances = _runtime_detail_renderer.get_rock_count()
	return {
		"enabled": _runtime_3d_enabled,
		"active_chunks": active_chunks,
		"chunk_pool": chunk_pool,
		"grass_instances": grass_instances,
		"rock_instances": rock_instances
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
	_sync_runtime_3d_pipeline()


func _sync_runtime_3d_pipeline() -> void:
	if not _runtime_3d_enabled:
		return
	if _runtime_heightmap_size <= 0 or _runtime_heightmap.is_empty():
		return
	if _runtime_visible_chunks.is_empty():
		return
	_runtime_3d_manager.sync_clipmap(_runtime_heightmap, _runtime_heightmap_size, _runtime_visible_chunks, CHUNK_SIZE)
	_runtime_detail_renderer.configure_instances(
		_runtime_detail_transforms.get("grass", []),
		_runtime_detail_transforms.get("rocks", []),
		QuadMesh.new(),
		BoxMesh.new()
	)


func _cleanup_runtime_3d_nodes() -> void:
	if _runtime_3d_manager and is_instance_valid(_runtime_3d_manager):
		_runtime_3d_manager.clear_chunks()
		_runtime_3d_manager.free()
	_runtime_3d_manager = null
	if _runtime_detail_renderer and is_instance_valid(_runtime_detail_renderer):
		_runtime_detail_renderer.clear_instances()
		_runtime_detail_renderer.free()
	_runtime_detail_renderer = null


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
	_draw_cell_blend(cell, pos, elev, water_type)

	# Draw water overlay if present
	if water_type != TerrainSystem.WaterType.NONE:
		var water_color = WATER_COLORS.get(water_type, Color.TRANSPARENT)
		if _is_isolated_pond_cell(cell, water_type):
			_draw_round_pond(pos, water_color)
		else:
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
	var cs = float(GridConstants.CELL_SIZE)
	var base_alpha = 0.15
	var wave_angle = 0.0  # Horizontal by default

	if water_type == TerrainSystem.WaterType.RIVER:
		base_alpha = 0.22
		wave_angle = 0.3  # Slight angle for current direction
	elif water_type == TerrainSystem.WaterType.LAKE:
		base_alpha = 0.10

	var wave_color = Color(1, 1, 1, base_alpha)

	# Animated wave pattern
	var offset = fmod(Time.get_ticks_msec() / 1000.0, 1.0) * 8
	var dy1 = sin(wave_angle) * cs * 0.3
	var dy2 = sin(wave_angle) * cs * 0.3
	draw_line(
		pos + Vector2(cs * 0.12, cs * 0.38 + offset),
		pos + Vector2(cs * 0.88, cs * 0.38 + offset + dy1),
		wave_color, 1.0
	)
	draw_line(
		pos + Vector2(cs * 0.18, cs * 0.62 - offset),
		pos + Vector2(cs * 0.82, cs * 0.62 - offset + dy2),
		wave_color, 1.0
	)

	# Shore foam: draw bright edge where water meets land
	if terrain_system:
		var cell = GridConstants.world_to_grid(pos)
		for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var neighbor = cell + dir
			if GridConstants.is_valid_cell(neighbor) and terrain_system.get_water(neighbor) == TerrainSystem.WaterType.NONE:
				var foam_color = Color(0.85, 0.9, 0.95, 0.35)
				var foam_width = 3.0
				if dir == Vector2i.UP:
					draw_rect(Rect2(pos, Vector2(cs, foam_width)), foam_color)
				elif dir == Vector2i.DOWN:
					draw_rect(Rect2(pos + Vector2(0, cs - foam_width), Vector2(cs, foam_width)), foam_color)
				elif dir == Vector2i.LEFT:
					draw_rect(Rect2(pos, Vector2(foam_width, cs)), foam_color)
				elif dir == Vector2i.RIGHT:
					draw_rect(Rect2(pos + Vector2(cs - foam_width, 0), Vector2(foam_width, cs)), foam_color)


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

	# Elevation-based size variation: smaller trees at higher elevations
	var elev_scale = 1.0
	if terrain_system:
		var cell = GridConstants.world_to_grid(center)
		var elev = terrain_system.get_elevation(cell)
		elev_scale = clampf(1.0 - float(elev) * 0.15, 0.6, 1.0)

	# Fixed sun direction shadow offset (sun from upper-left)
	var shadow_offset = Vector2(3, 4) * elev_scale

	if dense:
		# Dense forest - multiple overlapping trees
		for i in range(3):
			var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
			var tree_center = center + offset
			var s = elev_scale

			# Shadow
			var shadow_points = PackedVector2Array([
				tree_center + (Vector2(0, -16) + shadow_offset) * s,
				tree_center + (Vector2(-12, 4) + shadow_offset) * s,
				tree_center + (Vector2(12, 4) + shadow_offset) * s
			])
			draw_colored_polygon(shadow_points, Color(0, 0, 0, 0.12))

			# Trunk
			draw_rect(Rect2(tree_center.x - 2 * s, tree_center.y, 4 * s, 12 * s), trunk_color)
			# Foliage (triangle)
			var points = PackedVector2Array([
				tree_center + Vector2(0, -16) * s,
				tree_center + Vector2(-12, 4) * s,
				tree_center + Vector2(12, 4) * s
			])
			draw_colored_polygon(points, tree_color.darkened(randf_range(0, 0.2)))
	else:
		# Single tree
		var s = elev_scale

		# Shadow
		var shadow_points = PackedVector2Array([
			center + (Vector2(0, -18) + shadow_offset) * s,
			center + (Vector2(-14, 6) + shadow_offset) * s,
			center + (Vector2(14, 6) + shadow_offset) * s
		])
		draw_colored_polygon(shadow_points, Color(0, 0, 0, 0.12))

		# Trunk
		draw_rect(Rect2(center.x - 3 * s, center.y + 4 * s, 6 * s, 14 * s), trunk_color)
		# Foliage (triangle)
		var points = PackedVector2Array([
			center + Vector2(0, -18) * s,
			center + Vector2(-14, 6) * s,
			center + Vector2(14, 6) * s
		])
		draw_colored_polygon(points, tree_color)


func _draw_rock(center: Vector2, large: bool) -> void:
	var rock_color = ROCK_COLOR
	var shadow_color = rock_color.darkened(0.3)

	# Elevation-based size variation
	var elev_scale = 1.0
	if terrain_system:
		var cell = GridConstants.world_to_grid(center)
		var elev = terrain_system.get_elevation(cell)
		# Rocks get slightly larger at higher elevations (more imposing)
		elev_scale = clampf(0.9 + float(elev) * 0.05, 0.85, 1.2)

	# Fixed sun direction shadow offset (sun from upper-left)
	var shadow_offset = Vector2(4, 5) * elev_scale
	var s = elev_scale

	if large:
		# Large rock formation - cast shadow
		var cast_shadow = PackedVector2Array([
			center + (Vector2(-12, 4) + shadow_offset) * s,
			center + (Vector2(2, -10) + shadow_offset) * s,
			center + (Vector2(18, -2) + shadow_offset) * s,
			center + (Vector2(20, 14) + shadow_offset) * s,
			center + (Vector2(-6, 16) + shadow_offset) * s
		])
		draw_colored_polygon(cast_shadow, Color(0, 0, 0, 0.15))

		# Shadow face of rock
		var shadow_points = PackedVector2Array([
			center + Vector2(-16, 12) * s,
			center + Vector2(-12, -8) * s,
			center + Vector2(4, -14) * s,
			center + Vector2(18, -4) * s,
			center + Vector2(20, 10) * s,
			center + Vector2(8, 16) * s,
			center + Vector2(-6, 14) * s
		])
		draw_colored_polygon(shadow_points, shadow_color)
		# Main lit face
		var points = PackedVector2Array([
			center + Vector2(-18, 8) * s,
			center + Vector2(-14, -12) * s,
			center + Vector2(2, -18) * s,
			center + Vector2(16, -8) * s,
			center + Vector2(18, 6) * s,
			center + Vector2(6, 12) * s,
			center + Vector2(-8, 10) * s
		])
		draw_colored_polygon(points, rock_color)
		# Secondary rock detail for large formations
		var detail_points = PackedVector2Array([
			center + Vector2(-6, -14) * s,
			center + Vector2(4, -20) * s,
			center + Vector2(12, -12) * s,
			center + Vector2(6, -6) * s,
		])
		draw_colored_polygon(detail_points, rock_color.lightened(0.08))
		# Highlight edge
		draw_line(center + Vector2(-10, -8) * s, center + Vector2(4, -14) * s, Color(1, 1, 1, 0.22), 2)
	else:
		# Small rock - cast shadow
		var cast_shadow = PackedVector2Array([
			center + (Vector2(-4, 0) + shadow_offset) * s,
			center + (Vector2(4, -6) + shadow_offset) * s,
			center + (Vector2(10, 2) + shadow_offset) * s,
			center + (Vector2(6, 10) + shadow_offset) * s,
		])
		draw_colored_polygon(cast_shadow, Color(0, 0, 0, 0.12))

		# Shadow face
		var shadow_points = PackedVector2Array([
			center + Vector2(-8, 8) * s,
			center + Vector2(-4, -4) * s,
			center + Vector2(6, -6) * s,
			center + Vector2(12, 2) * s,
			center + Vector2(10, 10) * s,
			center + Vector2(-2, 12) * s
		])
		draw_colored_polygon(shadow_points, shadow_color)
		# Main rock
		var points = PackedVector2Array([
			center + Vector2(-10, 4) * s,
			center + Vector2(-6, -8) * s,
			center + Vector2(4, -10) * s,
			center + Vector2(10, -2) * s,
			center + Vector2(8, 6) * s,
			center + Vector2(-4, 8) * s
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
	var cs = float(GridConstants.CELL_SIZE)

	# Contour lines at every 2 elevation levels
	if elev >= 2 and elev % 2 == 0:
		var contour_color = Color(0, 0, 0, 0.08)
		# Draw contour along bottom and right edges
		draw_line(pos + Vector2(0, cs - 1), pos + Vector2(cs, cs - 1), contour_color, 1.5)
		draw_line(pos + Vector2(cs - 1, 0), pos + Vector2(cs - 1, cs), contour_color, 1.5)

	# Directional hillshade: simulate sun from upper-left
	# Darker on south/east faces, lighter on north/west faces
	if elev >= 1 and terrain_system:
		var cell = GridConstants.world_to_grid(pos)
		var east_elev = terrain_system.get_elevation(cell + Vector2i(1, 0))
		var south_elev = terrain_system.get_elevation(cell + Vector2i(0, 1))

		# South-facing slope shadow (cell is higher than cell below)
		if elev > south_elev:
			var shade_alpha = clampf(float(elev - south_elev) * 0.06, 0.0, 0.18)
			draw_rect(Rect2(pos + Vector2(0, cs - 4), Vector2(cs, 4)), Color(0, 0, 0, shade_alpha))

		# East-facing slope shadow (cell is higher than cell to right)
		if elev > east_elev:
			var shade_alpha = clampf(float(elev - east_elev) * 0.05, 0.0, 0.15)
			draw_rect(Rect2(pos + Vector2(cs - 4, 0), Vector2(4, cs)), Color(0, 0, 0, shade_alpha))

		# North-west highlight (cell is higher than neighbors above/left)
		var west_elev = terrain_system.get_elevation(cell + Vector2i(-1, 0))
		var north_elev = terrain_system.get_elevation(cell + Vector2i(0, -1))
		if elev > north_elev:
			var highlight_alpha = clampf(float(elev - north_elev) * 0.04, 0.0, 0.12)
			draw_rect(Rect2(pos, Vector2(cs, 3)), Color(1, 1, 1, highlight_alpha))
		if elev > west_elev:
			var highlight_alpha = clampf(float(elev - west_elev) * 0.03, 0.0, 0.10)
			draw_rect(Rect2(pos, Vector2(3, cs)), Color(1, 1, 1, highlight_alpha))


func _draw_cell_blend(cell: Vector2i, pos: Vector2, elev: int, water_type: TerrainSystem.WaterType) -> void:
	if terrain_system == null:
		return
	var current_surface = _get_surface_class(elev, water_type)
	var current_color = _surface_color(current_surface, elev, water_type)

	var north_diff = _draw_surface_blend_toward_neighbor(cell, pos, Vector2i.UP, current_surface, current_color)
	var south_diff = _draw_surface_blend_toward_neighbor(cell, pos, Vector2i.DOWN, current_surface, current_color)
	var east_diff = _draw_surface_blend_toward_neighbor(cell, pos, Vector2i.RIGHT, current_surface, current_color)
	var west_diff = _draw_surface_blend_toward_neighbor(cell, pos, Vector2i.LEFT, current_surface, current_color)

	if north_diff and east_diff:
		_draw_blend_corner(pos + Vector2(GridConstants.CELL_SIZE, 0.0), current_color)
	if south_diff and east_diff:
		_draw_blend_corner(pos + Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE), current_color)
	if south_diff and west_diff:
		_draw_blend_corner(pos + Vector2(0.0, GridConstants.CELL_SIZE), current_color)
	if north_diff and west_diff:
		_draw_blend_corner(pos, current_color)


func _draw_surface_blend_toward_neighbor(
	cell: Vector2i,
	pos: Vector2,
	dir: Vector2i,
	current_surface: String,
	current_color: Color
) -> bool:
	var neighbor = cell + dir
	if not GridConstants.is_valid_cell(neighbor):
		return false

	var neighbor_elev = terrain_system.get_elevation(neighbor)
	var neighbor_water = terrain_system.get_water(neighbor)
	var neighbor_surface = _get_surface_class(neighbor_elev, neighbor_water)
	var neighbor_color = _surface_color(neighbor_surface, neighbor_elev, neighbor_water)
	if not _should_blend_transition(current_surface, current_color, neighbor_surface, neighbor_color):
		return false

	var color = _blend_surface_color(current_color, neighbor_color)
	_draw_edge_band_with_jitter(cell, pos, dir, color)

	return true


func _draw_blend_corner(corner_pos: Vector2, current_color: Color) -> void:
	draw_circle(corner_pos, TERRAIN_BLEND_CORNER_RADIUS, Color(current_color.r, current_color.g, current_color.b, TERRAIN_BLEND_ALPHA * 0.75))


func _get_surface_class(elev: int, water_type: TerrainSystem.WaterType) -> String:
	if water_type != TerrainSystem.WaterType.NONE:
		return "water"
	if elev <= -1:
		return "sand"
	if elev >= 3:
		return "rock"
	return "grass"


func _surface_color(surface: String, elev: int, water_type: TerrainSystem.WaterType) -> Color:
	match surface:
		"water":
			return WATER_COLORS.get(water_type, WATER_COLORS[TerrainSystem.WaterType.LAKE])
		"sand":
			return ELEVATION_COLORS[-1]
		"rock":
			return _elevation_to_color(elev)
		_:
			return _elevation_to_color(elev)


func _blend_surface_color(a: Color, b: Color) -> Color:
	var mixed = a.lerp(b, 0.5)
	return Color(mixed.r, mixed.g, mixed.b, TERRAIN_BLEND_ALPHA)


func _should_blend_transition(current_surface: String, current_color: Color, neighbor_surface: String, neighbor_color: Color) -> bool:
	if neighbor_surface != current_surface:
		return true
	return _color_delta(current_color, neighbor_color) >= TERRAIN_BLEND_COLOR_DELTA


func _color_delta(a: Color, b: Color) -> float:
	return maxf(maxf(abs(a.r - b.r), abs(a.g - b.g)), abs(a.b - b.b))


func _draw_edge_band_with_jitter(cell: Vector2i, pos: Vector2, dir: Vector2i, color: Color) -> void:
	var width = TERRAIN_BLEND_EDGE_WIDTH
	if dir == Vector2i.UP:
		draw_rect(Rect2(pos, Vector2(GridConstants.CELL_SIZE, width)), color)
	elif dir == Vector2i.DOWN:
		draw_rect(Rect2(pos + Vector2(0.0, GridConstants.CELL_SIZE - width), Vector2(GridConstants.CELL_SIZE, width)), color)
	elif dir == Vector2i.RIGHT:
		draw_rect(Rect2(pos + Vector2(GridConstants.CELL_SIZE - width, 0.0), Vector2(width, GridConstants.CELL_SIZE)), color)
	else:
		draw_rect(Rect2(pos, Vector2(width, GridConstants.CELL_SIZE)), color)

	# Avoid painterly dabs for water transitions to keep pond/lake edges clean.
	if _is_water_like_color(color):
		return

	# Break straight lines with deterministic painterly noise along the edge.
	var steps = 6
	for i in range(steps):
		var t = float(i + 1) / float(steps + 1)
		var jitter = (_edge_hash01(cell, dir, i) - 0.5) * width * 0.9
		var radius = width * (0.28 + _edge_hash01(cell, dir, i + 17) * 0.35)
		var p = pos
		if dir == Vector2i.UP:
			p += Vector2(t * GridConstants.CELL_SIZE, width + jitter)
		elif dir == Vector2i.DOWN:
			p += Vector2(t * GridConstants.CELL_SIZE, GridConstants.CELL_SIZE - width + jitter)
		elif dir == Vector2i.RIGHT:
			p += Vector2(GridConstants.CELL_SIZE - width + jitter, t * GridConstants.CELL_SIZE)
		else:
			p += Vector2(width + jitter, t * GridConstants.CELL_SIZE)
		draw_circle(p, radius, Color(color.r, color.g, color.b, color.a * 0.52))


func _edge_hash01(cell: Vector2i, dir: Vector2i, salt: int) -> float:
	var h = int(cell.x) * 73856093
	h ^= int(cell.y) * 19349663
	h ^= int(dir.x + 2) * 83492791
	h ^= int(dir.y + 2) * 2654435761
	h ^= salt * 374761393
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	var positive = abs(h % 10000)
	return float(positive) / 9999.0


func _is_isolated_pond_cell(cell: Vector2i, water_type: TerrainSystem.WaterType) -> bool:
	if water_type == TerrainSystem.WaterType.NONE or terrain_system == null:
		return false
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor = cell + dir
		if GridConstants.is_valid_cell(neighbor) and terrain_system.get_water(neighbor) != TerrainSystem.WaterType.NONE:
			return false
	return true


func _draw_round_pond(pos: Vector2, water_color: Color) -> void:
	var center = pos + Vector2(GridConstants.CELL_SIZE * 0.5, GridConstants.CELL_SIZE * 0.5)
	var outer_r = GridConstants.CELL_SIZE * 0.42
	var inner_r = GridConstants.CELL_SIZE * 0.34
	draw_circle(center, outer_r, Color(water_color.r * 0.8, water_color.g * 0.82, water_color.b * 0.85, 0.85))
	draw_circle(center, inner_r, water_color)


func _is_water_like_color(c: Color) -> bool:
	return c.b > c.g and c.b > c.r and c.a >= (TERRAIN_BLEND_ALPHA * 0.7)


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
