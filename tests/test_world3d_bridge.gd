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
