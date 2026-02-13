extends TestBase

const World3DBridgeScript = preload("res://src/world/world3d_bridge.gd")
const BuildingDataScript = preload("res://src/resources/building_data.gd")

var _to_free: Array = []


func after_each() -> void:
	for i in range(_to_free.size() - 1, -1, -1):
		var instance = _to_free[i]
		if is_instance_valid(instance):
			instance.free()
	_to_free.clear()


func _track(instance):
	_to_free.append(instance)
	return instance


class DummyEventsBus:
	extends Node
	signal building_placed(cell: Vector2i, building: Node2D)
	signal building_removed(cell: Vector2i, building: Node2D)


class DummyBuilding:
	extends Node2D
	var building_data: Resource = null
	var grid_cell: Vector2i = Vector2i.ZERO


class DummyGridSystem:
	extends Node
	var _buildings: Array[Node2D] = []

	func set_buildings(buildings: Array[Node2D]) -> void:
		_buildings = buildings

	func get_all_unique_buildings() -> Array[Node2D]:
		return _buildings


func test_bridge_creates_and_removes_road_segments_from_events() -> void:
	var bridge = _track(World3DBridgeScript.new())
	var bus = _track(DummyEventsBus.new())
	var root = _track(Node.new())
	root.add_child(bridge)

	bridge.initialize(_track(Node.new()), _track(Camera2D.new()), bus)

	var building_data = BuildingDataScript.new()
	building_data.id = "road"
	building_data.building_type = "road"
	var building = _track(DummyBuilding.new())
	building.building_data = building_data

	bus.emit_signal("building_placed", Vector2i(10, 10), building)
	assert_eq(bridge.get_road_segment_count(), 1)

	bus.emit_signal("building_removed", Vector2i(10, 10), building)
	assert_eq(bridge.get_road_segment_count(), 0)


func test_bridge_builds_junction_and_decals_for_connected_roads() -> void:
	var bridge = _track(World3DBridgeScript.new())
	var bus = _track(DummyEventsBus.new())
	var root = _track(Node.new())
	root.add_child(bridge)
	bridge.initialize(_track(Node.new()), _track(Camera2D.new()), bus)

	var road_data = BuildingDataScript.new()
	road_data.id = "road"
	road_data.building_type = "road"

	var a = _track(DummyBuilding.new()); a.building_data = road_data
	var b = _track(DummyBuilding.new()); b.building_data = road_data
	var c = _track(DummyBuilding.new()); c.building_data = road_data

	bus.emit_signal("building_placed", Vector2i(0, 0), a)
	bus.emit_signal("building_placed", Vector2i(1, 0), b)
	bus.emit_signal("building_placed", Vector2i(0, 1), c)

	var stats: Dictionary = bridge.get_live_runtime_stats()
	assert_gt(int(stats.get("road_decals", 0)), 0)
	assert_gt(int(stats.get("road_junctions", 0)), 0)
	assert_eq(str(bridge.get_junction_kind(Vector2i(0, 0))), "corner")


func test_bridge_spawns_modular_building_for_known_resource() -> void:
	var bridge = _track(World3DBridgeScript.new())
	var bus = _track(DummyEventsBus.new())
	var root = _track(Node.new())
	root.add_child(bridge)
	bridge.initialize(_track(Node.new()), _track(Camera2D.new()), bus)

	var building_data = BuildingDataScript.new()
	building_data.id = "residential_low"
	building_data.building_type = "residential"
	building_data.floors = 6

	var building = _track(DummyBuilding.new())
	building.building_data = building_data

	bus.emit_signal("building_placed", Vector2i(5, 5), building)
	assert_eq(bridge.get_modular_building_count(), 1)
	assert_eq(int(bridge.get_live_runtime_stats().get("texture_layers", 0)), 3)


func test_bridge_rebuilds_existing_grid_state_on_initialize() -> void:
	var bridge = _track(World3DBridgeScript.new())
	var root = _track(Node.new())
	root.add_child(bridge)
	var bus = _track(DummyEventsBus.new())
	var grid = _track(DummyGridSystem.new())
	var road_data = BuildingDataScript.new()
	road_data.id = "road"
	road_data.building_type = "road"
	var house_data = BuildingDataScript.new()
	house_data.id = "residential_low"
	house_data.building_type = "residential"

	var road = _track(DummyBuilding.new())
	road.grid_cell = Vector2i(1, 1)
	road.building_data = road_data
	var house = _track(DummyBuilding.new())
	house.grid_cell = Vector2i(2, 2)
	house.building_data = house_data
	var seed_buildings: Array[Node2D] = [road, house]
	grid.set_buildings(seed_buildings)

	bridge.initialize(grid, _track(Camera2D.new()), bus)

	assert_eq(bridge.get_road_segment_count(), 1)
	assert_eq(bridge.get_modular_building_count(), 1)


func test_initialize_rebinds_events_bus_without_stale_connections() -> void:
	var bridge = _track(World3DBridgeScript.new())
	var root = _track(Node.new())
	root.add_child(bridge)
	var grid = _track(DummyGridSystem.new())
	var bus_a = _track(DummyEventsBus.new())
	var bus_b = _track(DummyEventsBus.new())

	bridge.initialize(grid, _track(Camera2D.new()), bus_a)
	bridge.initialize(grid, _track(Camera2D.new()), bus_b)

	var road_data = BuildingDataScript.new()
	road_data.id = "road"
	road_data.building_type = "road"
	var road = _track(DummyBuilding.new())
	road.building_data = road_data

	bus_a.emit_signal("building_placed", Vector2i(9, 9), road)
	assert_eq(bridge.get_road_segment_count(), 0)

	bus_b.emit_signal("building_placed", Vector2i(9, 9), road)
	assert_eq(bridge.get_road_segment_count(), 1)
