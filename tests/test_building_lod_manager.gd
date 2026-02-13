extends TestBase

const BuildingLodManagerScript = preload("res://src/world/buildings/building_lod_manager.gd")


class DummyController:
	extends RefCounted
	var calls: int = 0
	func update_lod(_camera_position: Vector3) -> void:
		calls += 1


func test_update_budget_limits_per_frame_work() -> void:
	var manager = BuildingLodManagerScript.new()
	manager.max_updates_per_frame = 2

	var c1 = DummyController.new()
	var c2 = DummyController.new()
	var c3 = DummyController.new()
	manager.register_controller(c1)
	manager.register_controller(c2)
	manager.register_controller(c3)

	var updated = manager.update_budgeted(Vector3.ZERO)
	assert_eq(updated, 2)
	assert_eq(c1.calls + c2.calls + c3.calls, 2)
