class_name TestHelpers
extends RefCounted
## Shared test helpers for common setup.

const BuildingDataScript = preload("res://src/resources/building_data.gd")


static func create_grid_system(parent: Node = null) -> Node:
	var grid_system = GridSystem.new()
	grid_system._building_registry.load_registry()
	if parent:
		parent.add_child(grid_system)
	return grid_system


## Fake zoning system for testing zone detection
class FakeZoningSystem extends RefCounted:
	var _zones: Dictionary = {}

	func get_zone_at(cell: Vector2i) -> int:
		return _zones.get(cell, 0)


## Fake grid system for neighbor detection tests
class FakeGridForNeighbors extends Node:
	var _buildings: Dictionary = {}
	var _overlays: Dictionary = {}
	var _roads: Dictionary = {}
	var zoning_system: RefCounted = null

	func has_building_at(cell: Vector2i) -> bool:
		return _buildings.has(cell)

	func get_building_at(cell: Vector2i) -> Node2D:
		return _buildings.get(cell)

	func has_overlay_at(cell: Vector2i) -> bool:
		return _overlays.has(cell)

	func get_overlay_at(cell: Vector2i) -> Node2D:
		return _overlays.get(cell)

	func get_road_cell_map() -> Dictionary:
		return _roads

	func has_road_at(cell: Vector2i) -> bool:
		return _roads.has(cell)


## Fake building node for tests
class FakeBuilding extends Node2D:
	var building_data: Resource


## Create a BuildingData resource with given properties
static func make_building_data(id: String, btype: String = "", opts: Dictionary = {}) -> Resource:
	var data = BuildingDataScript.new()
	data.id = id
	data.building_type = btype if btype != "" else id
	data.size = opts.get("size", Vector2i.ONE)
	data.color = opts.get("color", Color.WHITE)
	data.requires_road_adjacent = opts.get("requires_road_adjacent", false)
	data.build_cost = opts.get("build_cost", 100)
	data.power_production = opts.get("power_production", 0.0)
	data.power_consumption = opts.get("power_consumption", 0.0)
	data.water_production = opts.get("water_production", 0.0)
	data.water_consumption = opts.get("water_consumption", 0.0)
	return data
