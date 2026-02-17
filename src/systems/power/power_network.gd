class_name PowerNetwork
extends RefCounted
## Handles power connectivity via flood-fill from power sources
## Tracks powered cells and distance from source for efficiency calculations

# Power network tracking
var powered_cells: Dictionary = {}  # {Vector2i: bool}
var power_line_cells: Dictionary = {}  # {Vector2i: true}
var road_cells: Dictionary = {}  # {Vector2i: true} - roads conduct power

# Distance from power source tracking for efficiency penalties
var distance_from_source: Dictionary = {}  # {Vector2i: int}

# Configuration
var max_efficient_distance: int = 30
var efficiency_falloff: float = 0.02
var min_efficiency: float = 0.5


## Update the power network by flood-filling from all power sources
func update_network(power_sources: Array[Node2D], storage_buildings: Array[Node2D], grid_system) -> void:
	powered_cells.clear()
	distance_from_source.clear()

	if not grid_system:
		return

	# Only include roads that conduct utilities (excludes dirt roads)
	road_cells.clear()
	var all_roads = grid_system.get_road_cell_map()
	for cell in all_roads:
		var building = grid_system.get_building_at(cell)
		if is_instance_valid(building) and building.building_data and building.building_data.conducts_utilities:
			road_cells[cell] = true

	# Flood fill from power sources
	for source in power_sources:
		if is_instance_valid(source):
			_flood_fill_power(source.grid_cell, grid_system)

	# Storage buildings also provide power network connectivity
	for storage in storage_buildings:
		if is_instance_valid(storage):
			_flood_fill_power(storage.grid_cell, grid_system)


## Flood fill power from a starting cell
func _flood_fill_power(start_cell: Vector2i, grid_system) -> void:
	var to_visit: Array = [[start_cell, 0]]
	var visited: Dictionary = {}

	while to_visit.size() > 0:
		var current = to_visit.pop_front()
		var cell: Vector2i = current[0]
		var distance: int = current[1]

		if visited.has(cell):
			continue
		visited[cell] = true
		powered_cells[cell] = true

		if not distance_from_source.has(cell) or distance < distance_from_source[cell]:
			distance_from_source[cell] = distance

		if grid_system and grid_system.has_building_at(cell):
			var building = grid_system.get_building_at(cell)
			if is_instance_valid(building) and building.building_data:
				var building_size = building.building_data.size
				var origin = building.grid_cell
				for bx in range(building_size.x):
					for by in range(building_size.y):
						var building_cell = origin + Vector2i(bx, by)
						powered_cells[building_cell] = true
						if not distance_from_source.has(building_cell) or distance < distance_from_source[building_cell]:
							distance_from_source[building_cell] = distance
						if not visited.has(building_cell):
							to_visit.append([building_cell, distance])

		var neighbors = [
			cell + Vector2i(1, 0),
			cell + Vector2i(-1, 0),
			cell + Vector2i(0, 1),
			cell + Vector2i(0, -1)
		]

		for neighbor in neighbors:
			if visited.has(neighbor):
				continue

			if power_line_cells.has(neighbor):
				to_visit.append([neighbor, distance + 1])
				continue

			if road_cells.has(neighbor):
				to_visit.append([neighbor, distance + 1])
				continue

			if grid_system:
				if grid_system.has_building_at(neighbor):
					to_visit.append([neighbor, distance + 1])
					continue
				if grid_system.has_overlay_at(neighbor):
					var overlay = grid_system.get_overlay_at(neighbor)
					if is_instance_valid(overlay) and overlay.building_data:
						if GridConstants.is_power_type(overlay.building_data.building_type):
							to_visit.append([neighbor, distance + 1])


## Check if a cell is powered (including adjacent cells)
func is_cell_powered(cell: Vector2i) -> bool:
	if powered_cells.has(cell):
		return true

	var neighbors = [
		cell + Vector2i(1, 0),
		cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(0, -1)
	]

	for neighbor in neighbors:
		if powered_cells.has(neighbor):
			return true

	return false


## Get power efficiency at a cell based on distance from source
func get_efficiency_at(cell: Vector2i) -> float:
	if not distance_from_source.has(cell):
		return 1.0

	var distance = distance_from_source[cell]
	if distance <= max_efficient_distance:
		return 1.0

	var excess_distance = distance - max_efficient_distance
	var efficiency = 1.0 - (excess_distance * efficiency_falloff)
	return max(min_efficiency, efficiency)


## Get distance from nearest power source
func get_distance_from_source(cell: Vector2i) -> int:
	return distance_from_source.get(cell, -1)


## Calculate total efficiency loss across all powered buildings
func get_total_efficiency_loss(grid_system) -> float:
	if not grid_system or distance_from_source.size() == 0:
		return 0.0

	var total_loss = 0.0
	var counted = {}

	for cell in grid_system.get_building_cells():
		var building = grid_system.get_building_at(cell)
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if building.building_data and building.building_data.power_consumption > 0:
			var efficiency = get_efficiency_at(building.grid_cell)
			if efficiency < 1.0:
				var extra_needed = building.building_data.power_consumption * (1.0 / efficiency - 1.0)
				total_loss += extra_needed

	return total_loss


## Add a power line cell to the network
func add_power_line(cell: Vector2i) -> void:
	power_line_cells[cell] = true


## Remove a power line cell from the network
func remove_power_line(cell: Vector2i) -> void:
	power_line_cells.erase(cell)


## Add a road cell to the network
func add_road(cell: Vector2i) -> void:
	road_cells[cell] = true


## Remove a road cell from the network
func remove_road(cell: Vector2i) -> void:
	road_cells.erase(cell)
