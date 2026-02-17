class_name GridConstants
extends RefCounted
## Centralized grid constants and coordinate conversion utilities
##
## This file is the single source of truth for all grid-related constants.
## All other files should reference these constants instead of defining their own.

# =============================================================================
# GRID DIMENSIONS
# =============================================================================

## Size of each grid cell in pixels
const CELL_SIZE: int = 64

## Number of cells horizontally
const GRID_WIDTH: int = 128

## Number of cells vertically
const GRID_HEIGHT: int = 128

## Total world width in pixels (GRID_WIDTH * CELL_SIZE)
const WORLD_WIDTH: int = GRID_WIDTH * CELL_SIZE  # 8192

## Total world height in pixels (GRID_HEIGHT * CELL_SIZE)
const WORLD_HEIGHT: int = GRID_HEIGHT * CELL_SIZE  # 8192

## Half cell size for centering calculations
const HALF_CELL: int = 32  # CELL_SIZE / 2


# =============================================================================
# BUILDING TYPE CONSTANTS
# =============================================================================

## All road building types (for checking road adjacency, connectivity, etc.)
const ROAD_TYPES: Array[String] = ["road", "highway"]

## Utility building types that can overlay on roads
const UTILITY_TYPES: Array[String] = ["power_line", "water_pipe", "large_water_pipe"]

## Power infrastructure types
const POWER_TYPES: Array[String] = ["power_line", "power_pole"]

## Water infrastructure types
const WATER_TYPES: Array[String] = ["water_pipe", "large_water_pipe"]

## Linear infrastructure (1x1 drag-build types)
const LINEAR_INFRASTRUCTURE: Array[String] = [
	"road", "highway",
	"power_line", "power_pole",
	"water_pipe", "large_water_pipe"
]

## Terrain action types (not real buildings - perform terrain modifications)
const TERRAIN_ACTION_TYPES: Array[String] = []

## Bulldozer costs for clearing terrain features
const BULLDOZE_COST_ROCK_SMALL: int = 500
const BULLDOZE_COST_ROCK_LARGE: int = 1000
const BULLDOZE_COST_TREE: int = 100


# =============================================================================
# COORDINATE CONVERSION
# =============================================================================

## Convert world position to grid cell coordinates
static func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor(world_pos.x / CELL_SIZE)),
		int(floor(world_pos.y / CELL_SIZE))
	)


## Convert grid cell to world position (top-left corner of cell)
static func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * CELL_SIZE, grid_pos.y * CELL_SIZE)


## Convert grid cell to world position (center of cell)
static func grid_to_world_center(grid_pos: Vector2i) -> Vector2:
	return Vector2(
		grid_pos.x * CELL_SIZE + HALF_CELL,
		grid_pos.y * CELL_SIZE + HALF_CELL
	)


# =============================================================================
# CELL VALIDATION
# =============================================================================

## Check if a cell is within valid grid bounds
static func is_valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT


## Clamp a cell to valid grid bounds
static func clamp_cell(cell: Vector2i) -> Vector2i:
	return Vector2i(
		clampi(cell.x, 0, GRID_WIDTH - 1),
		clampi(cell.y, 0, GRID_HEIGHT - 1)
	)


## Clamp a world position to valid grid bounds
static func clamp_world(world_pos: Vector2) -> Vector2:
	return Vector2(
		clampf(world_pos.x, 0.0, WORLD_WIDTH - 1.0),
		clampf(world_pos.y, 0.0, WORLD_HEIGHT - 1.0)
	)


# =============================================================================
# CELL UTILITIES
# =============================================================================

## Get the 4 orthogonally adjacent cells (N, S, E, W)
static func get_adjacent_cells(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var offsets = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for offset in offsets:
		var neighbor = cell + offset
		if is_valid_cell(neighbor):
			result.append(neighbor)
	return result


## Get the 8 surrounding cells (including diagonals)
static func get_surrounding_cells(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(-1, 2):
		for y in range(-1, 2):
			if x == 0 and y == 0:
				continue
			var neighbor = cell + Vector2i(x, y)
			if is_valid_cell(neighbor):
				result.append(neighbor)
	return result


## Calculate Manhattan distance between two cells
static func manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(b.x - a.x) + abs(b.y - a.y)


## Calculate Chebyshev distance (allows diagonal movement)
static func chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(abs(b.x - a.x), abs(b.y - a.y))


## Calculate Euclidean distance between two cells
static func euclidean_distance(a: Vector2i, b: Vector2i) -> float:
	var dx = b.x - a.x
	var dy = b.y - a.y
	return sqrt(dx * dx + dy * dy)


# =============================================================================
# RECT UTILITIES
# =============================================================================

## Create a Rect2i from two corner cells (handles any order)
static func rect_from_cells(a: Vector2i, b: Vector2i) -> Rect2i:
	var min_x = mini(a.x, b.x)
	var min_y = mini(a.y, b.y)
	var max_x = maxi(a.x, b.x)
	var max_y = maxi(a.y, b.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


## Convert a cell rect to world rect
static func cell_rect_to_world(cell_rect: Rect2i) -> Rect2:
	return Rect2(
		Vector2(cell_rect.position) * CELL_SIZE,
		Vector2(cell_rect.size) * CELL_SIZE
	)


## Get visible cell rect from camera position and viewport
static func get_visible_cells(camera_pos: Vector2, viewport_size: Vector2, zoom: float, padding: int = 1) -> Rect2i:
	var half_size = viewport_size / (2.0 * zoom)

	var min_cell = Vector2i(
		maxi(0, int((camera_pos.x - half_size.x) / CELL_SIZE) - padding),
		maxi(0, int((camera_pos.y - half_size.y) / CELL_SIZE) - padding)
	)
	var max_cell = Vector2i(
		mini(GRID_WIDTH - 1, int((camera_pos.x + half_size.x) / CELL_SIZE) + padding),
		mini(GRID_HEIGHT - 1, int((camera_pos.y + half_size.y) / CELL_SIZE) + padding)
	)

	return Rect2i(min_cell, max_cell - min_cell + Vector2i.ONE)


# =============================================================================
# TYPE CHECKING
# =============================================================================

## Check if a building type is a road
static func is_road_type(building_type: String) -> bool:
	return building_type in ROAD_TYPES


## Check if a building type is a utility that can overlay on roads
static func is_utility_type(building_type: String) -> bool:
	return building_type in UTILITY_TYPES


## Check if a building type is linear infrastructure (1x1 drag-build)
static func is_linear_infrastructure(building_type: String) -> bool:
	return building_type in LINEAR_INFRASTRUCTURE


## Check if a building type is power-related
static func is_power_type(building_type: String) -> bool:
	return building_type in POWER_TYPES


## Check if a building type is water-related
static func is_water_type(building_type: String) -> bool:
	return building_type in WATER_TYPES


## Check if a building type is a terrain action (not a real building)
static func is_terrain_action(building_type: String) -> bool:
	return building_type in TERRAIN_ACTION_TYPES


# =============================================================================
# COVERAGE SYSTEM CONSTANTS
# =============================================================================

## Maximum coverage radius used by any building (university = 30)
## SpatialHash pre-computes coverage masks up to this radius for performance
const MAX_COVERAGE_RADIUS: int = 32

## Common service coverage radii for reference:
## - Small park: 6
## - Bus stop: 8
## - Mayor's house: 10
## - Fire station, community center, rail station, large park: 12
## - Police station, library, subway station, city hall: 15
## - School, hospital, stadium, bus depot: 20
## - University: 30


# =============================================================================
# ROAD ACCESS MANAGEMENT
# =============================================================================

## Road types that allow direct building access
## Highways and arterials should not allow direct access - use collectors/local roads
const ROAD_ACCESS_TYPES: Dictionary = {
	"road": true,       # Local road - full access
	"highway": false,   # Highway - no direct access
}

## Check if a road type allows direct building access
static func road_allows_access(road_type: String) -> bool:
	return ROAD_ACCESS_TYPES.get(road_type, true)


# =============================================================================
# DIRECTIONAL NEIGHBOR UTILITIES
# =============================================================================

## Cardinal direction offsets for neighbor checking
const DIRECTIONS: Dictionary = {
	"north": Vector2i(0, -1),
	"south": Vector2i(0, 1),
	"east": Vector2i(1, 0),
	"west": Vector2i(-1, 0)
}

## Get directional neighbors as a dictionary with 0/1 values
## cell_sets: Array of dictionaries/sets to check (e.g., [road_cells, buildings])
## Returns: {"north": 0/1, "south": 0/1, "east": 0/1, "west": 0/1}
static func get_directional_neighbors(cell: Vector2i, cell_sets: Array) -> Dictionary:
	var neighbors = {"north": 0, "south": 0, "east": 0, "west": 0}
	for dir_name in DIRECTIONS:
		var neighbor_cell = cell + DIRECTIONS[dir_name]
		for cell_set in cell_sets:
			if cell_set.has(neighbor_cell):
				neighbors[dir_name] = 1
				break
	return neighbors


## Unpack a neighbor dictionary into boolean flags
## Returns: {"has_north": bool, "has_south": bool, "has_east": bool, "has_west": bool,
##           "has_vertical": bool, "has_horizontal": bool, "connection_count": int}
static func unpack_neighbors(neighbors: Dictionary) -> Dictionary:
	var has_north = neighbors.get("north", 0) == 1
	var has_south = neighbors.get("south", 0) == 1
	var has_east = neighbors.get("east", 0) == 1
	var has_west = neighbors.get("west", 0) == 1
	return {
		"has_north": has_north,
		"has_south": has_south,
		"has_east": has_east,
		"has_west": has_west,
		"has_vertical": has_north or has_south,
		"has_horizontal": has_east or has_west,
		"connection_count": int(has_north) + int(has_south) + int(has_east) + int(has_west)
	}


# =============================================================================
# MULTI-CELL BUILDING UTILITIES
# =============================================================================

## Get all cells occupied by a building at the given origin
static func get_building_cells(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for x in range(size.x):
		for y in range(size.y):
			cells.append(origin + Vector2i(x, y))
	return cells


## Get all cells on the perimeter around a building (for road access checks)
static func get_building_perimeter(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var perimeter: Array[Vector2i] = []
	# Top and bottom edges
	for x in range(-1, size.x + 1):
		var top = origin + Vector2i(x, -1)
		var bottom = origin + Vector2i(x, size.y)
		if is_valid_cell(top):
			perimeter.append(top)
		if is_valid_cell(bottom):
			perimeter.append(bottom)
	# Left and right edges (excluding corners already added)
	for y in range(size.y):
		var left = origin + Vector2i(-1, y)
		var right = origin + Vector2i(size.x, y)
		if is_valid_cell(left):
			perimeter.append(left)
		if is_valid_cell(right):
			perimeter.append(right)
	return perimeter
