extends Node
class_name GrowthBoundarySystem
## Manages urban growth boundaries and sprawl control

var grid_system = null

# Growth boundary (cells inside this boundary can be developed)
var boundary_cells: Dictionary = {}  # {Vector2i: true}

# Greenbelts (protected areas that cannot be developed)
var greenbelt_cells: Dictionary = {}  # {Vector2i: true}

# Starting boundary size (tiles from center)
const INITIAL_BOUNDARY_RADIUS: int = 25

# Annexation cost per tile
const ANNEXATION_COST_PER_TILE: int = 500

# Infill bonus (development speed multiplier for vacant lots within developed areas)
const INFILL_DEVELOPMENT_BONUS: float = 1.5

# Sprawl penalty (development outside core area)
const SPRAWL_DEVELOPMENT_PENALTY: float = 0.5


func _ready() -> void:
	# Initialize default boundary
	_initialize_default_boundary()


func set_grid_system(system) -> void:
	grid_system = system


func _initialize_default_boundary() -> void:
	# Create circular initial boundary
	var center = Vector2i(50, 50)  # Center of 100x100 grid

	for x in range(-INITIAL_BOUNDARY_RADIUS, INITIAL_BOUNDARY_RADIUS + 1):
		for y in range(-INITIAL_BOUNDARY_RADIUS, INITIAL_BOUNDARY_RADIUS + 1):
			var distance = sqrt(x * x + y * y)
			if distance <= INITIAL_BOUNDARY_RADIUS:
				boundary_cells[center + Vector2i(x, y)] = true


func is_within_boundary(cell: Vector2i) -> bool:
	return boundary_cells.has(cell)


func is_greenbelt(cell: Vector2i) -> bool:
	return greenbelt_cells.has(cell)


func can_develop(cell: Vector2i) -> bool:
	# Can only develop within boundary and not in greenbelt
	return is_within_boundary(cell) and not is_greenbelt(cell)


func get_development_modifier(cell: Vector2i) -> float:
	if not can_develop(cell):
		return 0.0  # Cannot develop outside boundary

	# Check if this is infill development
	if is_infill_location(cell):
		return INFILL_DEVELOPMENT_BONUS

	# Check distance from city center
	var distance_from_center = _get_distance_from_developed_core(cell)
	if distance_from_center > 10:
		return SPRAWL_DEVELOPMENT_PENALTY

	return 1.0


func is_infill_location(cell: Vector2i) -> bool:
	if not grid_system:
		return false

	# Infill = vacant cell surrounded by developed cells
	if grid_system.has_building_at(cell):
		return false  # Already developed

	var developed_neighbors = 0
	var offsets = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1),
		Vector2i(1, -1), Vector2i(-1, 1)
	]

	for offset in offsets:
		var neighbor = cell + offset
		if grid_system.has_building_at(neighbor):
			developed_neighbors += 1

	return developed_neighbors >= 4  # At least half surrounded


func _get_distance_from_developed_core(cell: Vector2i) -> float:
	if not grid_system:
		return 0.0

	# Find distance to nearest developed cell
	var min_distance = 999.0

	for developed_cell in grid_system.get_building_cells():
		var dx = cell.x - developed_cell.x
		var dy = cell.y - developed_cell.y
		var distance = sqrt(dx * dx + dy * dy)
		min_distance = min(min_distance, distance)

	return min_distance


func annex_area(center: Vector2i, radius: int) -> int:
	# Expand boundary to include new area
	var cells_added = 0
	var total_cost = 0

	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var distance = sqrt(x * x + y * y)
			if distance <= radius:
				var cell = center + Vector2i(x, y)
				if not boundary_cells.has(cell) and not greenbelt_cells.has(cell):
					# Check if valid grid cell
					if cell.x >= 0 and cell.x < 100 and cell.y >= 0 and cell.y < 100:
						boundary_cells[cell] = true
						cells_added += 1
						total_cost += ANNEXATION_COST_PER_TILE

	if cells_added > 0 and GameState.can_afford(total_cost):
		GameState.spend(total_cost)
		Events.simulation_event.emit("territory_annexed", {
			"tiles": cells_added,
			"cost": total_cost
		})
		return cells_added
	elif cells_added > 0:
		# Revert if can't afford
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var distance = sqrt(x * x + y * y)
				if distance <= radius:
					var cell = center + Vector2i(x, y)
					boundary_cells.erase(cell)
		Events.simulation_event.emit("insufficient_funds", {"cost": total_cost})
		return 0

	return 0


func designate_greenbelt(center: Vector2i, radius: int) -> int:
	# Create protected greenbelt area
	var cells_protected = 0

	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var distance = sqrt(x * x + y * y)
			if distance <= radius:
				var cell = center + Vector2i(x, y)

				# Can't protect already developed areas
				if grid_system and grid_system.has_building_at(cell):
					continue

				if not greenbelt_cells.has(cell):
					greenbelt_cells[cell] = true
					cells_protected += 1

	if cells_protected > 0:
		Events.simulation_event.emit("greenbelt_designated", {"tiles": cells_protected})

	return cells_protected


func remove_greenbelt(center: Vector2i, radius: int) -> int:
	# Remove greenbelt protection (controversial!)
	var cells_removed = 0

	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var distance = sqrt(x * x + y * y)
			if distance <= radius:
				var cell = center + Vector2i(x, y)
				if greenbelt_cells.has(cell):
					greenbelt_cells.erase(cell)
					cells_removed += 1

	if cells_removed > 0:
		# Removing greenbelt causes happiness penalty
		GameState.happiness -= 0.05

		Events.simulation_event.emit("greenbelt_removed", {"tiles": cells_removed})

	return cells_removed


func get_boundary_size() -> int:
	return boundary_cells.size()


func get_greenbelt_size() -> int:
	return greenbelt_cells.size()


func get_developed_ratio() -> float:
	# Ratio of developed land to available land
	if boundary_cells.size() == 0:
		return 0.0

	if not grid_system:
		return 0.0

	var developed = 0
	for cell in boundary_cells:
		if grid_system.has_building_at(cell):
			developed += 1

	return float(developed) / float(boundary_cells.size())


func get_sprawl_index() -> float:
	# Measure of how sprawled the city is (0 = compact, 1 = sprawling)
	if not grid_system:
		return 0.0

	var total_distance = 0.0
	var building_count = 0
	var center = Vector2i(50, 50)

	var counted = {}
	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if counted.has(building):
			continue
		counted[building] = true

		var dx = cell.x - center.x
		var dy = cell.y - center.y
		total_distance += sqrt(dx * dx + dy * dy)
		building_count += 1

	if building_count == 0:
		return 0.0

	var avg_distance = total_distance / building_count
	return min(1.0, avg_distance / 40.0)  # Normalize to 0-1


func get_greenbelt_happiness_bonus() -> float:
	# Greenbelts make residents happy
	var greenbelt_ratio = float(greenbelt_cells.size()) / float(max(1, boundary_cells.size()))
	return min(0.05, greenbelt_ratio * 0.5)  # Up to 5% bonus
