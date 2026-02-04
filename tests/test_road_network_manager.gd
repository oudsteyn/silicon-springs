extends TestBase
## Tests for RoadNetworkManager batching behavior

var manager: RoadNetworkManager
var events: Array[Dictionary] = []


func before_each() -> void:
	manager = RoadNetworkManager.new()
	events.clear()
	manager.road_changed.connect(_on_road_changed)


func after_each() -> void:
	manager = null


func _on_road_changed(cell: Vector2i, added: bool) -> void:
	events.append({"cell": cell, "added": added})


func test_batch_add_emits_once_per_cell() -> void:
	var cell = Vector2i(1, 1)
	manager.begin_batch()
	manager.add_road(cell)
	manager.add_road(cell)
	manager.end_batch()

	assert_size(events, 1)
	assert_vector2i_eq(events[0].cell, cell)
	assert_true(events[0].added)


func test_batch_add_and_remove_no_event() -> void:
	var cell = Vector2i(2, 2)
	manager.begin_batch()
	manager.add_road(cell)
	manager.remove_road(cell)
	manager.end_batch()

	assert_empty(events)


func test_batch_multiple_cells_emits_each() -> void:
	var cell_a = Vector2i(3, 3)
	var cell_b = Vector2i(4, 4)
	manager.begin_batch()
	manager.add_road(cell_a)
	manager.add_road(cell_b)
	manager.end_batch()

	assert_size(events, 2)
	var seen: Dictionary = {}
	for entry in events:
		seen[entry.cell] = entry.added
	assert_true(seen.get(cell_a, false))
	assert_true(seen.get(cell_b, false))
