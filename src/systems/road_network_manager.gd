class_name RoadNetworkManager
extends RefCounted
## Manages road network topology and pathfinding
##
## Handles:
## - Road cell tracking
## - AStar pathfinding for connectivity queries
## - Road network change event emission

## Signal emitted when road network topology changes
signal road_changed(cell: Vector2i, added: bool)

## Cells that contain roads: {Vector2i: true}
var road_cells: Dictionary = {}

## AStar pathfinding for road connectivity
var _astar: AStar2D = AStar2D.new()

## Maps cell positions to AStar point IDs: {Vector2i: true}
## Used to track which cells have AStar points
var _astar_cells: Dictionary = {}


## Convert cell to AStar point ID (deterministic, based on position)
func _cell_to_astar_id(cell: Vector2i) -> int:
	return cell.x + cell.y * GridConstants.GRID_WIDTH


## Add a road at the given cell
func add_road(cell: Vector2i) -> void:
	road_cells[cell] = true

	# Add to AStar pathfinding using cell-based ID
	var point_id = _cell_to_astar_id(cell)

	if not _astar.has_point(point_id):
		_astar.add_point(point_id, Vector2(cell.x, cell.y))
		_astar_cells[cell] = true

	# Connect to adjacent road cells
	var neighbors = GridConstants.get_adjacent_cells(cell)
	for neighbor in neighbors:
		if road_cells.has(neighbor):
			var neighbor_id = _cell_to_astar_id(neighbor)
			if _astar.has_point(neighbor_id) and not _astar.are_points_connected(point_id, neighbor_id):
				_astar.connect_points(point_id, neighbor_id)

	# Emit local signal and global event
	road_changed.emit(cell, true)
	Events.road_network_changed.emit(cell, true)


## Remove a road at the given cell
func remove_road(cell: Vector2i) -> void:
	road_cells.erase(cell)

	var point_id = _cell_to_astar_id(cell)
	if _astar.has_point(point_id):
		_astar.remove_point(point_id)
		_astar_cells.erase(cell)

	# Emit local signal and global event
	road_changed.emit(cell, false)
	Events.road_network_changed.emit(cell, false)


## Check if a cell has a road
func has_road_at(cell: Vector2i) -> bool:
	return road_cells.has(cell)


## Check if two cells are connected by road network
func is_connected_by_road(from: Vector2i, to: Vector2i) -> bool:
	var from_id = _cell_to_astar_id(from)
	var to_id = _cell_to_astar_id(to)

	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return false

	var path = _astar.get_id_path(from_id, to_id)
	return path.size() > 0


## Get the path between two cells (returns array of Vector2i)
func get_road_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var from_id = _cell_to_astar_id(from)
	var to_id = _cell_to_astar_id(to)

	if not _astar.has_point(from_id) or not _astar.has_point(to_id):
		return result

	var path = _astar.get_point_path(from_id, to_id)
	for point in path:
		result.append(Vector2i(int(point.x), int(point.y)))
	return result


## Get the distance (in cells) between two road-connected cells
## Returns -1 if not connected
func get_road_distance(from: Vector2i, to: Vector2i) -> int:
	var path = get_road_path(from, to)
	if path.size() == 0:
		return -1
	return path.size() - 1  # Path includes start cell


## Get all road cells
func get_road_cells() -> Dictionary:
	return road_cells


## Get the number of road cells
func get_road_count() -> int:
	return road_cells.size()


## Clear all road data (for loading/resetting)
func clear() -> void:
	road_cells.clear()
	_astar.clear()
	_astar_cells.clear()


## Bulk load roads from a dictionary (for save/load)
func load_roads(cells: Dictionary) -> void:
	clear()
	for cell in cells:
		if cells[cell]:
			add_road(cell)


## Get statistics for debugging
func get_stats() -> Dictionary:
	return {
		"road_cells": road_cells.size(),
		"astar_points": _astar.get_point_count(),
		"astar_cells": _astar_cells.size()
	}
