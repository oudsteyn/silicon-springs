extends TestBase
## Tests for game_world.gd refactors: cursor mapping, expense breakdown, data center dedup

const GameWorldScript = preload("res://scenes/game_world.gd")

var _to_free: Array = []


func before_each() -> void:
	GameState.reset_game()


func after_each() -> void:
	for i in range(_to_free.size() - 1, -1, -1):
		var instance = _to_free[i]
		if is_instance_valid(instance):
			instance.free()
	_to_free.clear()


func _track(instance):
	_to_free.append(instance)
	return instance


# ── Mock classes ──────────────────────────────────────────────────────────

class MockBuildingData extends Resource:
	var display_name: String = "Test Building"
	var build_cost: int = 1000
	var category: String = "infrastructure"
	var monthly_maintenance: int = 50
	var data_center_tier: int = 0
	var size: Vector2i = Vector2i(1, 1)
	var id: String = "test_building"
	var score_value: int = 0
	var building_type: String = ""
	var coverage_radius: int = 0
	var service_type: String = ""


class MockBuilding extends Node2D:
	var building_data: Resource = null
	var grid_cell: Vector2i = Vector2i.ZERO

	func _init(data: Resource = null) -> void:
		building_data = data


class MockGridSystem extends Node:
	var buildings: Dictionary = {}
	var _unique_buildings: Dictionary = {}

	func get_building_at(cell: Vector2i):
		return buildings.get(cell)

	func get_all_unique_buildings() -> Array[Node2D]:
		var result: Array[Node2D] = []
		for b in _unique_buildings.values():
			result.append(b)
		return result

	func is_valid_cell(_cell: Vector2i) -> bool:
		return true

	func remove_building(cell: Vector2i) -> bool:
		if buildings.has(cell):
			buildings.erase(cell)
			return true
		return false

	func set_building(cell: Vector2i, building: MockBuilding) -> void:
		buildings[cell] = building
		_unique_buildings[building.get_instance_id()] = building


# ── Cursor mapping tests ─────────────────────────────────────────────────

func test_cursor_shape_for_tool_select() -> void:
	var shape = GameWorld._cursor_shape_for_tool(GameWorld.ToolMode.SELECT)
	assert_eq(shape, Input.CURSOR_ARROW)


func test_cursor_shape_for_tool_pan() -> void:
	var shape = GameWorld._cursor_shape_for_tool(GameWorld.ToolMode.PAN)
	assert_eq(shape, Input.CURSOR_DRAG)


func test_cursor_shape_for_tool_build() -> void:
	var shape = GameWorld._cursor_shape_for_tool(GameWorld.ToolMode.BUILD)
	assert_eq(shape, Input.CURSOR_CROSS)


func test_cursor_shape_for_tool_demolish() -> void:
	var shape = GameWorld._cursor_shape_for_tool(GameWorld.ToolMode.DEMOLISH)
	assert_eq(shape, Input.CURSOR_CROSS)


func test_cursor_shape_for_tool_zone() -> void:
	var shape = GameWorld._cursor_shape_for_tool(GameWorld.ToolMode.ZONE)
	assert_eq(shape, Input.CURSOR_CROSS)


func test_cursor_shape_for_tool_terrain() -> void:
	var shape = GameWorld._cursor_shape_for_tool(GameWorld.ToolMode.TERRAIN)
	assert_eq(shape, Input.CURSOR_CROSS)


# ── Expense breakdown tests ──────────────────────────────────────────────

func test_expense_breakdown_uses_unique_buildings() -> void:
	# A 2x2 building occupies 4 cells but should be counted once
	var world = _track(GameWorldScript.new())
	var grid = _track(MockGridSystem.new())
	world.grid_system = grid

	var data = MockBuildingData.new()
	data.category = "infrastructure"
	data.monthly_maintenance = 100
	var building = _track(MockBuilding.new(data))

	# Place in 4 cells (simulating a 2x2 building)
	grid.set_building(Vector2i(0, 0), building)
	grid.buildings[Vector2i(1, 0)] = building
	grid.buildings[Vector2i(0, 1)] = building
	grid.buildings[Vector2i(1, 1)] = building

	var breakdown = world._compute_expense_breakdown()

	assert_true(breakdown.has("infrastructure"), "Should have infrastructure category")
	assert_eq(breakdown["infrastructure"].count, 1, "Multi-cell building should be counted once")
	assert_eq(breakdown["infrastructure"].total, 100, "Maintenance should not be doubled")


func test_expense_breakdown_multiple_categories() -> void:
	var world = _track(GameWorldScript.new())
	var grid = _track(MockGridSystem.new())
	world.grid_system = grid

	var road_data = MockBuildingData.new()
	road_data.category = "road"
	road_data.monthly_maintenance = 10
	var road = _track(MockBuilding.new(road_data))
	grid.set_building(Vector2i(0, 0), road)

	var power_data = MockBuildingData.new()
	power_data.category = "power"
	power_data.monthly_maintenance = 200
	var power = _track(MockBuilding.new(power_data))
	grid.set_building(Vector2i(1, 0), power)

	var breakdown = world._compute_expense_breakdown()

	assert_true(breakdown.has("road"))
	assert_true(breakdown.has("power"))
	assert_eq(breakdown["road"].count, 1)
	assert_eq(breakdown["power"].count, 1)
	assert_eq(breakdown["road"].total, 10)
	assert_eq(breakdown["power"].total, 200)


# ── Data center tracking dedup tests ─────────────────────────────────────

func test_track_data_center_placement_adds_to_game_state() -> void:
	var world = _track(GameWorldScript.new())
	GameState.reset_game()

	var data = MockBuildingData.new()
	data.category = "data_center"
	data.data_center_tier = 2
	data.score_value = 500

	world._track_data_center_placed(data, Vector2i(5, 5))

	assert_eq(GameState.data_centers_by_tier.get(2, 0), 1)
	assert_eq(GameState.score, 500)
