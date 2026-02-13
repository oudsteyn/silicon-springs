extends Node
class_name TerrainSystem
## Core terrain data and logic for elevation, water, and natural features

const ProceduralTerrainGeneratorScript = preload("res://src/terrain/procedural_terrain_generator.gd")
const TerrainNoiseProfileScript = preload("res://src/terrain/terrain_noise_profile.gd")
const HydraulicErosionScript = preload("res://src/terrain/hydraulic_erosion.gd")
const TerrainLodManagerScript = preload("res://src/terrain/terrain_lod_manager.gd")

# Terrain type enums
enum WaterType { NONE, POND, LAKE, RIVER }
enum FeatureType { NONE, TREE_SPARSE, TREE_DENSE, ROCK_SMALL, ROCK_LARGE, BEACH }

# Elevation limits
const MIN_ELEVATION: int = -3
const MAX_ELEVATION: int = 5

# Terrain data dictionaries
var elevation: Dictionary = {}   # Vector2i -> int (-3 to +5)
var water: Dictionary = {}       # Vector2i -> WaterType
var features: Dictionary = {}    # Vector2i -> FeatureType

# Current biome (optional, for weather/gameplay effects)
var current_biome: Resource = null  # BiomePreset

# Reference to grid system for building checks
var grid_system: Node = null

# Runtime terrain pipeline components
var _runtime_pipeline_enabled: bool = false
var _runtime_erosion_iterations: int = 0
var _runtime_noise_profile: Resource = null
var _terrain_generator = ProceduralTerrainGeneratorScript.new()
var _hydraulic_erosion = HydraulicErosionScript.new()
var _lod_manager = TerrainLodManagerScript.new()
var _runtime_heightmap: PackedFloat32Array = PackedFloat32Array()
var _runtime_heightmap_size: int = 0
var _runtime_sea_level: float = 0.0

# Signals
signal terrain_changed(cells: Array)
signal runtime_heightmap_generated(heightmap: PackedFloat32Array, size: int, sea_level: float)


func _ready() -> void:
	# Initialize all cells to default (elevation 0, no water, no features)
	_initialize_terrain()


func _initialize_terrain() -> void:
	for x in range(GridConstants.GRID_WIDTH):
		for y in range(GridConstants.GRID_HEIGHT):
			var cell = Vector2i(x, y)
			elevation[cell] = 0
			# Water and features are sparse - only store non-empty values


func set_grid_system(gs: Node) -> void:
	grid_system = gs


func set_biome(biome: Resource) -> void:
	current_biome = biome


func configure_runtime_pipeline(enabled: bool, profile: Resource = null, erosion_iterations: int = -1) -> void:
	_runtime_pipeline_enabled = enabled
	_runtime_noise_profile = profile
	if erosion_iterations >= 0:
		_runtime_erosion_iterations = erosion_iterations


func is_runtime_pipeline_enabled() -> bool:
	return _runtime_pipeline_enabled


func get_runtime_lod_plan(camera_world_pos: Vector3, chunk_size_m: float = 128.0) -> Dictionary:
	if _lod_manager == null:
		return {}
	return _lod_manager.compute_visible_chunks(camera_world_pos, chunk_size_m)


func get_runtime_heightmap() -> PackedFloat32Array:
	return _runtime_heightmap


func get_runtime_heightmap_size() -> int:
	return _runtime_heightmap_size


func get_runtime_sea_level() -> float:
	return _runtime_sea_level


# ============================================
# ELEVATION METHODS
# ============================================

func get_elevation(cell: Vector2i) -> int:
	return elevation.get(cell, 0)


func set_elevation(cell: Vector2i, level: int) -> void:
	if not _is_valid_cell(cell):
		return

	# Check if cell has a building (cannot modify terrain under buildings)
	if _has_building(cell):
		return

	level = clampi(level, MIN_ELEVATION, MAX_ELEVATION)
	var old_level = elevation.get(cell, 0)

	if old_level != level:
		elevation[cell] = level

		# Auto-manage water based on elevation
		if level <= -2:
			# Deep/shallow water - auto-add water
			if level == -3:
				water[cell] = WaterType.LAKE
			elif level == -2:
				water[cell] = WaterType.POND
		elif level >= 0 and water.has(cell):
			# Remove water from raised terrain
			water.erase(cell)

		# Remove features if elevation changed dramatically
		if abs(old_level - level) > 2 and features.has(cell):
			features.erase(cell)

		# Auto-add beach at water edges
		_update_beaches_around(cell)

		_emit_terrain_changed([cell])


func raise_elevation(cell: Vector2i) -> void:
	var current = get_elevation(cell)
	set_elevation(cell, current + 1)


func lower_elevation(cell: Vector2i) -> void:
	var current = get_elevation(cell)
	set_elevation(cell, current - 1)


func flatten(cell: Vector2i) -> void:
	set_elevation(cell, 0)


# ============================================
# WATER METHODS
# ============================================

func get_water(cell: Vector2i) -> WaterType:
	return water.get(cell, WaterType.NONE)


func set_water(cell: Vector2i, type: WaterType) -> void:
	if not _is_valid_cell(cell):
		return

	if _has_building(cell):
		return

	if type == WaterType.NONE:
		water.erase(cell)
		# Raise elevation if it was water level
		if elevation.get(cell, 0) < 0:
			elevation[cell] = 0
	else:
		water[cell] = type
		# Lower elevation for water cells
		match type:
			WaterType.LAKE:
				elevation[cell] = -3
			WaterType.RIVER:
				elevation[cell] = -2
			WaterType.POND:
				elevation[cell] = -2

	# Update beaches around water
	_update_beaches_around(cell)
	_emit_terrain_changed([cell])


func toggle_water(cell: Vector2i) -> void:
	if water.has(cell):
		set_water(cell, WaterType.NONE)
	else:
		set_water(cell, WaterType.POND)


## Check if there's water within a certain radius of a cell
func has_water_nearby(cell: Vector2i, radius: int = 2) -> bool:
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var check = cell + Vector2i(x, y)
			if water.has(check):
				return true
	return false


## Check if a cell is flood-prone based on elevation and water proximity
func is_flood_prone(cell: Vector2i) -> bool:
	var elev = get_elevation(cell)

	# Very low elevations are always flood-prone
	if elev <= -1:
		return true

	# Ground level near water is flood-prone
	if elev == 0 and has_water_nearby(cell, 3):
		return true

	return false


## Get flood severity at a cell (0.0 = no flood risk, 1.0 = maximum flood risk)
func get_flood_severity(cell: Vector2i) -> float:
	var elev = get_elevation(cell)

	# Base severity from elevation
	var severity = 0.0
	if elev <= -2:
		severity = 1.0  # Underwater - maximum flood risk
	elif elev == -1:
		severity = 0.7  # Beach/wetland - high risk
	elif elev == 0:
		severity = 0.3  # Ground level - moderate risk
	elif elev == 1:
		severity = 0.1  # Low hill - slight risk
	# Higher elevations = no flood risk

	# Increase severity if near water
	if severity > 0 and has_water_nearby(cell, 2):
		severity = minf(1.0, severity * 1.3)

	return severity


# ============================================
# FEATURE METHODS
# ============================================

func get_feature(cell: Vector2i) -> FeatureType:
	return features.get(cell, FeatureType.NONE)


func add_feature(cell: Vector2i, type: FeatureType) -> void:
	if not _is_valid_cell(cell):
		return

	if _has_building(cell):
		return

	# Don't place features on water
	if water.has(cell):
		return

	var elev = get_elevation(cell)

	# Feature placement rules based on elevation
	match type:
		FeatureType.TREE_SPARSE, FeatureType.TREE_DENSE:
			# Trees only on ground level to low hills (0-2)
			if elev < 0 or elev > 2:
				return
		FeatureType.ROCK_SMALL, FeatureType.ROCK_LARGE:
			# Rocks on hills and mountains (2-5)
			if elev < 2:
				return
		FeatureType.BEACH:
			# Beaches only at water edges (-1)
			if elev != -1:
				return

	if type == FeatureType.NONE:
		features.erase(cell)
	else:
		features[cell] = type

	_emit_terrain_changed([cell])


func remove_feature(cell: Vector2i) -> void:
	if features.has(cell):
		features.erase(cell)
		_emit_terrain_changed([cell])


func toggle_feature(cell: Vector2i, type: FeatureType) -> void:
	if features.get(cell, FeatureType.NONE) == type:
		remove_feature(cell)
	else:
		add_feature(cell, type)


# ============================================
# BUILDABILITY CHECKS
# ============================================

func is_buildable(cell: Vector2i, building_data = null) -> Dictionary:
	var result = {
		"can_build": true,
		"reason": ""
	}

	if not _is_valid_cell(cell):
		result.can_build = false
		result.reason = "Outside map bounds"
		return result

	# Check building size if provided
	var building_size = Vector2i(1, 1)
	var building_type = ""
	if building_data:
		building_size = building_data.size if building_data.get("size") else Vector2i(1, 1)
		building_type = building_data.building_type if building_data.get("building_type") else ""

	# Check all cells the building would occupy
	for x in range(building_size.x):
		for y in range(building_size.y):
			var check_cell = cell + Vector2i(x, y)
			var cell_result = _check_cell_buildable(check_cell, building_type, building_size)
			if not cell_result.can_build:
				return cell_result

	return result


func _check_cell_buildable(cell: Vector2i, building_type: String, building_size: Vector2i) -> Dictionary:
	var result = {
		"can_build": true,
		"reason": ""
	}

	if not _is_valid_cell(cell):
		result.can_build = false
		result.reason = "Outside map bounds"
		return result

	var elev = get_elevation(cell)
	var water_type = get_water(cell)

	# Deep water (-3): No buildings
	if elev == -3:
		result.can_build = false
		result.reason = "Cannot build on deep water"
		return result

	# Shallow water (-2): Only bridges, docks, water pumps
	if elev == -2 or water_type in [WaterType.POND, WaterType.RIVER, WaterType.LAKE]:
		var water_allowed = ["bridge", "dock", "water_pump", "large_water_pump", "desalination_plant"]
		if building_type not in water_allowed:
			result.can_build = false
			result.reason = "Only water infrastructure allowed here"
			return result

	# Beach/Wetland (-1): Small buildings only
	if elev == -1:
		if building_size.x > 2 or building_size.y > 2:
			result.can_build = false
			result.reason = "Only small buildings on beach/wetland"
			return result

	# Mountain peak (+5): No buildings
	if elev == 5:
		result.can_build = false
		result.reason = "Cannot build on mountain peak"
		return result

	# Mountain base (+4): Small buildings only
	if elev == 4:
		if building_size.x > 2 or building_size.y > 2:
			result.can_build = false
			result.reason = "Only small buildings on mountain base"
			return result

	# High hill (+3): Limited buildings (no large infrastructure)
	if elev == 3:
		if building_size.x > 3 or building_size.y > 3:
			result.can_build = false
			result.reason = "Building too large for high hill"
			return result

	return result


# ============================================
# TERRAIN GENERATION
# ============================================

func generate_initial_terrain(map_seed: int, biome: Resource = null) -> void:
	if _runtime_pipeline_enabled:
		_generate_runtime_pipeline_terrain(map_seed, biome)
		return
	_generate_legacy_initial_terrain(map_seed, biome)


func _generate_legacy_initial_terrain(map_seed: int, biome: Resource = null) -> void:
	var noise = FastNoiseLite.new()
	noise.seed = map_seed
	noise.frequency = 0.015  # Good frequency for 128x128 map
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.fractal_octaves = 4

	# Apply biome settings if provided
	var base_elevation: int = 0
	var elevation_variation: float = 0.5
	var water_coverage: float = 0.15
	var tree_density: float = 0.2
	var rock_density: float = 0.1
	var biome_id: String = ""

	if biome:
		set_biome(biome)
		base_elevation = biome.base_elevation if biome.get("base_elevation") != null else 0
		elevation_variation = biome.elevation_variation if biome.get("elevation_variation") != null else 0.5
		water_coverage = biome.water_coverage if biome.get("water_coverage") != null else 0.15
		tree_density = biome.tree_density if biome.get("tree_density") != null else 0.2
		rock_density = biome.rock_density if biome.get("rock_density") != null else 0.1
		biome_id = biome.id if biome.get("id") else ""

	# Clear existing terrain
	elevation.clear()
	water.clear()
	features.clear()

	# Generate base elevation
	for x in range(GridConstants.GRID_WIDTH):
		for y in range(GridConstants.GRID_HEIGHT):
			var cell = Vector2i(x, y)
			var noise_val = noise.get_noise_2d(float(x), float(y))
			# Map noise (-1 to 1) to elevation based on variation
			var elev = base_elevation + int(noise_val * 4.0 * elevation_variation)
			elevation[cell] = clampi(elev, MIN_ELEVATION, MAX_ELEVATION)

	# Apply biome-specific terrain modifications
	match biome_id:
		"great_river_valley":
			_generate_river(map_seed)
		"coastal_shelf":
			_generate_coastal_ocean(map_seed)
		"high_desert":
			_generate_mesas(map_seed, noise)

	# Create water bodies in low areas (unless biome has special water handling)
	if biome_id not in ["great_river_valley", "coastal_shelf"]:
		_create_water_bodies(water_coverage)

	# Add beaches at water edges
	_create_beaches()

	# Scatter natural features
	_scatter_features(tree_density, rock_density, map_seed)

	# Emit change for all cells
	var all_cells: Array = []
	for x in range(GridConstants.GRID_WIDTH):
		for y in range(GridConstants.GRID_HEIGHT):
			all_cells.append(Vector2i(x, y))
	_emit_terrain_changed(all_cells)


func _generate_runtime_pipeline_terrain(map_seed: int, biome: Resource = null) -> void:
	if biome:
		set_biome(biome)

	var profile = _runtime_noise_profile
	if profile == null:
		profile = TerrainNoiseProfileScript.new()
	if profile.get("seed") != null:
		profile.seed = map_seed

	var size = GridConstants.GRID_WIDTH
	var height = _terrain_generator.generate_heightmap(size, profile)
	if _runtime_erosion_iterations > 0:
		_hydraulic_erosion.erode(height, size, _runtime_erosion_iterations, map_seed + 13)
	_runtime_heightmap = height
	_runtime_heightmap_size = size

	elevation.clear()
	water.clear()
	features.clear()

	var sea_level = float(profile.sea_level) if profile.get("sea_level") != null else 28.0
	_runtime_sea_level = sea_level
	var max_height = float(profile.height_scale) if profile.get("height_scale") != null else 450.0
	var height_span = max(max_height - sea_level, 1.0)
	for y in range(size):
		for x in range(size):
			var cell = Vector2i(x, y)
			var h = height[y * size + x]
			var depth = sea_level - h
			if depth > 0.0:
				elevation[cell] = -3 if depth > sea_level * 0.35 else -2
				water[cell] = WaterType.LAKE
			else:
				var normalized = clamp((h - sea_level) / height_span, 0.0, 1.0)
				elevation[cell] = clampi(int(round(normalized * float(MAX_ELEVATION))), 0, MAX_ELEVATION)

	_create_beaches()
	_scatter_features(0.18, 0.1, map_seed + 41)

	var all_cells: Array = []
	for x in range(GridConstants.GRID_WIDTH):
		for y in range(GridConstants.GRID_HEIGHT):
			all_cells.append(Vector2i(x, y))
	_emit_terrain_changed(all_cells)
	runtime_heightmap_generated.emit(_runtime_heightmap, _runtime_heightmap_size, _runtime_sea_level)


func _generate_river(map_seed: int) -> void:
	# Generate a meandering river through the center of the map
	var rng = RandomNumberGenerator.new()
	rng.seed = map_seed + 9999

	# River starts from one edge and flows to the opposite
	var start_y = rng.randi_range(20, GridConstants.GRID_HEIGHT - 20)
	var river_width = rng.randi_range(3, 5)

	# Create meandering path using sine wave with noise
	var meander_freq = rng.randf_range(0.03, 0.06)
	var meander_amp = rng.randf_range(15, 25)

	for x in range(GridConstants.GRID_WIDTH):
		# Calculate river center y position with meandering
		var meander = sin(x * meander_freq) * meander_amp
		var center_y = start_y + meander + rng.randf_range(-2, 2)

		# Carve river channel
		for dy in range(-river_width, river_width + 1):
			var y = int(center_y + dy)
			if y >= 0 and y < GridConstants.GRID_HEIGHT:
				var cell = Vector2i(x, y)
				var dist_from_center = abs(dy)

				# Deep water in center, shallow at edges
				if dist_from_center <= 1:
					elevation[cell] = -3
					water[cell] = WaterType.RIVER
				elif dist_from_center <= river_width - 1:
					elevation[cell] = -2
					water[cell] = WaterType.RIVER
				else:
					# Flood plain
					elevation[cell] = mini(elevation.get(cell, 0), -1)

	# Add some ponds/lakes along the river (flood plains)
	for _i in range(rng.randi_range(3, 6)):
		var lake_x = rng.randi_range(10, GridConstants.GRID_WIDTH - 10)
		var meander = sin(lake_x * meander_freq) * meander_amp
		var lake_y = int(start_y + meander + rng.randf_range(-15, 15))
		_create_pond(Vector2i(lake_x, lake_y), rng.randi_range(4, 8), rng)


func _create_pond(center: Vector2i, radius: int, rng: RandomNumberGenerator) -> void:
	# Create an irregular pond shape
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var dist = sqrt(dx * dx + dy * dy)
			if dist <= radius + rng.randf_range(-1, 1):
				var cell = center + Vector2i(dx, dy)
				if cell.x >= 0 and cell.x < GridConstants.GRID_WIDTH and cell.y >= 0 and cell.y < GridConstants.GRID_HEIGHT:
					if dist <= radius * 0.5:
						elevation[cell] = -2
						water[cell] = WaterType.POND
					else:
						elevation[cell] = mini(elevation.get(cell, 0), -1)


func _generate_coastal_ocean(map_seed: int) -> void:
	# Create ocean on one edge of the map
	var rng = RandomNumberGenerator.new()
	rng.seed = map_seed + 8888

	# Determine which edge has the ocean (left or bottom typically)
	var ocean_edge = rng.randi_range(0, 1)  # 0 = left, 1 = bottom

	# Create irregular coastline
	var coastline_base = rng.randi_range(20, 35)  # Distance from edge
	var coast_noise = FastNoiseLite.new()
	coast_noise.seed = map_seed + 7777
	coast_noise.frequency = 0.05

	for x in range(GridConstants.GRID_WIDTH):
		for y in range(GridConstants.GRID_HEIGHT):
			var cell = Vector2i(x, y)
			var dist_from_edge: float

			if ocean_edge == 0:  # Left edge ocean
				dist_from_edge = x
			else:  # Bottom edge ocean
				dist_from_edge = GridConstants.GRID_HEIGHT - 1 - y

			# Add noise to coastline
			var noise_offset = coast_noise.get_noise_2d(float(x), float(y)) * 12

			if dist_from_edge < coastline_base + noise_offset:
				# Ocean zone
				if dist_from_edge < coastline_base + noise_offset - 8:
					elevation[cell] = -3
					water[cell] = WaterType.LAKE  # Deep ocean
				elif dist_from_edge < coastline_base + noise_offset - 3:
					elevation[cell] = -2
					water[cell] = WaterType.POND  # Shallow ocean
				else:
					elevation[cell] = -1  # Beach
			else:
				# Inland - create hills/mountains rising from coast
				var inland_dist = dist_from_edge - coastline_base
				var height_boost = int(inland_dist / 20)
				elevation[cell] = clampi(elevation.get(cell, 0) + height_boost, MIN_ELEVATION, MAX_ELEVATION)


func _generate_mesas(map_seed: int, base_noise: FastNoiseLite) -> void:
	# Create distinct mesa/plateau formations
	var rng = RandomNumberGenerator.new()
	rng.seed = map_seed + 6666

	# Generate several mesas
	var num_mesas = rng.randi_range(4, 7)

	for _i in range(num_mesas):
		var mesa_x = rng.randi_range(15, GridConstants.GRID_WIDTH - 15)
		var mesa_y = rng.randi_range(15, GridConstants.GRID_HEIGHT - 15)
		var mesa_radius = rng.randi_range(8, 18)
		var mesa_height = rng.randi_range(3, 5)

		# Create mesa with steep edges
		for dx in range(-mesa_radius - 3, mesa_radius + 4):
			for dy in range(-mesa_radius - 3, mesa_radius + 4):
				var cell = Vector2i(mesa_x + dx, mesa_y + dy)
				if cell.x < 0 or cell.x >= GridConstants.GRID_WIDTH or cell.y < 0 or cell.y >= GridConstants.GRID_HEIGHT:
					continue

				var dist = sqrt(dx * dx + dy * dy)
				var noise_offset = base_noise.get_noise_2d(float(cell.x) * 2, float(cell.y) * 2) * 3

				if dist < mesa_radius + noise_offset:
					# Top of mesa - flat
					elevation[cell] = mesa_height
				elif dist < mesa_radius + noise_offset + 2:
					# Steep cliff edge
					elevation[cell] = maxi(elevation.get(cell, 0), mesa_height - 2)
				elif dist < mesa_radius + noise_offset + 4:
					# Talus slope
					elevation[cell] = maxi(elevation.get(cell, 0), 1)

	# Create some dry washes/arroyos (occasional very low areas)
	for _j in range(rng.randi_range(2, 4)):
		var wash_start_x = rng.randi_range(0, GridConstants.GRID_WIDTH - 1)
		var wash_y = rng.randi_range(20, GridConstants.GRID_HEIGHT - 20)
		var wash_length = rng.randi_range(30, 60)

		for wx in range(wash_length):
			var x = wash_start_x + wx
			if x >= GridConstants.GRID_WIDTH:
				break
			wash_y += rng.randi_range(-1, 1)
			wash_y = clampi(wash_y, 5, GridConstants.GRID_HEIGHT - 5)

			for wy in range(-1, 2):
				var cell = Vector2i(x, wash_y + wy)
				if cell.x >= 0 and cell.x < GridConstants.GRID_WIDTH and cell.y >= 0 and cell.y < GridConstants.GRID_HEIGHT:
					elevation[cell] = mini(elevation.get(cell, 0), 0)


func _create_water_bodies(_coverage: float) -> void:
	# Find cells at or below sea level and create water
	# Note: Coverage is determined by elevation generation, not by limiting water placement
	# The _coverage parameter is reserved for future use with procedural water features
	var water_cells: Array = []

	for x in range(GridConstants.GRID_WIDTH):
		for y in range(GridConstants.GRID_HEIGHT):
			var cell = Vector2i(x, y)
			var elev = elevation.get(cell, 0)
			if elev <= -2:
				water_cells.append(cell)

	# Add water to low-lying cells
	for cell in water_cells:
		var elev = elevation.get(cell, 0)
		if elev == -3:
			water[cell] = WaterType.LAKE
		elif elev == -2:
			water[cell] = WaterType.POND


func _create_beaches() -> void:
	# Add beach features at water edges
	for x in range(GridConstants.GRID_WIDTH):
		for y in range(GridConstants.GRID_HEIGHT):
			var cell = Vector2i(x, y)
			if _is_water_edge(cell):
				var elev = elevation.get(cell, 0)
				if elev == -1 or elev == 0:
					elevation[cell] = -1
					features[cell] = FeatureType.BEACH


func _is_water_edge(cell: Vector2i) -> bool:
	# Check if this cell is adjacent to water but not water itself
	if water.has(cell):
		return false

	var neighbors = _get_neighbors(cell)
	for neighbor in neighbors:
		if water.has(neighbor):
			return true
	return false


func _scatter_features(tree_density: float, rock_density: float, seed_val: int) -> void:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_val + 12345  # Offset from terrain seed

	for x in range(GridConstants.GRID_WIDTH):
		for y in range(GridConstants.GRID_HEIGHT):
			var cell = Vector2i(x, y)
			var elev = elevation.get(cell, 0)

			# Skip water cells and cells with existing features
			if water.has(cell) or features.has(cell):
				continue

			# Trees on ground level (0-2)
			if elev >= 0 and elev <= 2:
				if rng.randf() < tree_density:
					features[cell] = FeatureType.TREE_SPARSE if rng.randf() > 0.3 else FeatureType.TREE_DENSE

			# Rocks on hills/mountains (2-5)
			elif elev >= 2 and elev <= 4:
				if rng.randf() < rock_density:
					features[cell] = FeatureType.ROCK_SMALL if rng.randf() > 0.3 else FeatureType.ROCK_LARGE


func _update_beaches_around(cell: Vector2i) -> void:
	var neighbors = _get_neighbors(cell)
	for neighbor in neighbors:
		if _is_water_edge(neighbor):
			var elev = elevation.get(neighbor, 0)
			if elev >= -1 and elev <= 0:
				elevation[neighbor] = -1
				features[neighbor] = FeatureType.BEACH
		elif features.get(neighbor, FeatureType.NONE) == FeatureType.BEACH:
			# Remove beach if no longer at water edge
			if not _is_water_edge(neighbor):
				features.erase(neighbor)


# ============================================
# SERIALIZATION (for save/load)
# ============================================

func get_terrain_data() -> Dictionary:
	return {
		"elevation": _dict_to_serializable(elevation),
		"water": _dict_to_serializable(water),
		"features": _dict_to_serializable(features),
		"biome_id": current_biome.id if current_biome and current_biome.get("id") else ""
	}


func load_terrain_data(data: Dictionary) -> void:
	elevation = _serializable_to_dict(data.get("elevation", {}))
	water = _serializable_to_dict(data.get("water", {}))
	features = _serializable_to_dict(data.get("features", {}))

	# Biome loading would need to be handled by the caller

	# Emit change for all loaded cells
	var all_cells: Array = []
	for cell in elevation.keys():
		all_cells.append(cell)
	_emit_terrain_changed(all_cells)


func _dict_to_serializable(d: Dictionary) -> Dictionary:
	# Convert Vector2i keys to string keys for JSON serialization
	var result = {}
	for key in d:
		if key is Vector2i:
			result["%d,%d" % [key.x, key.y]] = d[key]
		else:
			result[str(key)] = d[key]
	return result


func _serializable_to_dict(d: Dictionary) -> Dictionary:
	# Convert string keys back to Vector2i
	var result = {}
	for key in d:
		if typeof(key) == TYPE_STRING and "," in key:
			var parts = key.split(",")
			if parts.size() == 2:
				var vec = Vector2i(int(parts[0]), int(parts[1]))
				result[vec] = d[key]
		else:
			result[key] = d[key]
	return result


# ============================================
# UTILITY METHODS
# ============================================

func _is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GridConstants.GRID_WIDTH and cell.y >= 0 and cell.y < GridConstants.GRID_HEIGHT


func _has_building(cell: Vector2i) -> bool:
	if grid_system and grid_system.has_method("get_building_at"):
		return grid_system.get_building_at(cell) != null
	return false


func _get_neighbors(cell: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var offsets = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for offset in offsets:
		var neighbor = cell + offset
		if _is_valid_cell(neighbor):
			neighbors.append(neighbor)
	return neighbors


func _emit_terrain_changed(cells: Array) -> void:
	terrain_changed.emit(cells)
	Events.terrain_changed.emit(cells)
