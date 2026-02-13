extends TestBase

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

class MockBuilding extends Node2D:
	var building_data: Resource = null
	var grid_cell: Vector2i = Vector2i.ZERO

	func _init(data: Resource = null) -> void:
		building_data = data


class MockBuildingData extends Resource:
	var display_name: String = "Test Building"
	var build_cost: int = 1000
	var category: String = "infrastructure"
	var data_center_tier: int = 0
	var size: Vector2i = Vector2i(1, 1)


class MockGridSystem extends Node:
	var _buildings: Dictionary = {}  # cell -> MockBuilding
	var _removed_cells: Array = []

	func get_building_at(cell: Vector2i):
		return _buildings.get(cell)

	func remove_building(cell: Vector2i) -> bool:
		if _buildings.has(cell):
			_buildings.erase(cell)
			_removed_cells.append(cell)
			return true
		return false

	func is_valid_cell(_cell: Vector2i) -> bool:
		return true

	func place_building(cell: MockBuildingData, _data) -> Node2D:
		return null

	func set_building(cell: Vector2i, building: MockBuilding) -> void:
		_buildings[cell] = building


class MockZoningSystem extends Node:
	var _zones: Dictionary = {}  # cell -> int

	func get_zone_at(cell: Vector2i) -> int:
		return _zones.get(cell, 0)

	func set_zone(cell: Vector2i, zone_type: int) -> bool:
		if zone_type == 0:
			_zones.erase(cell)
		else:
			_zones[cell] = zone_type
		return true


class MockTerrainSystem extends Node:
	var _features: Dictionary = {}  # cell -> FeatureType
	var _cleared_rocks: Array = []
	var _cleared_trees: Array = []
	var _removed_features: Array = []

	func get_feature(cell: Vector2i) -> int:
		return _features.get(cell, TerrainSystem.FeatureType.NONE)

	func clear_rocks(cell: Vector2i) -> bool:
		_cleared_rocks.append(cell)
		_features.erase(cell)
		return true

	func clear_trees(cell: Vector2i) -> bool:
		_cleared_trees.append(cell)
		_features.erase(cell)
		return true

	func remove_feature(cell: Vector2i) -> void:
		_removed_features.append(cell)
		_features.erase(cell)


# ── Helper ────────────────────────────────────────────────────────────────

func _make_world() -> GameWorld:
	var world = _track(GameWorldScript.new())
	world.grid_system = _track(MockGridSystem.new())
	world.zoning_system = _track(MockZoningSystem.new())
	world.terrain_system = _track(MockTerrainSystem.new())
	return world


# ── Tests ─────────────────────────────────────────────────────────────────

func test_bulldoze_cell_removes_building() -> void:
	var world = _make_world()
	var data = MockBuildingData.new()
	data.display_name = "Road"
	data.build_cost = 200
	var building = _track(MockBuilding.new(data))
	var cell = Vector2i(5, 5)
	world.grid_system.set_building(cell, building)

	var result = world._bulldoze_cell(cell)

	assert_true(result.cleared, "Building should be cleared")
	assert_eq(result.type, "building_demolished")
	assert_eq(result.data.name, "Road")
	assert_eq(result.data.refund, 100)  # 50% of 200


func test_bulldoze_cell_removes_zone() -> void:
	var world = _make_world()
	var cell = Vector2i(3, 3)
	world.zoning_system._zones[cell] = 1  # residential

	var result = world._bulldoze_cell(cell)

	assert_true(result.cleared, "Zone should be cleared")
	assert_eq(result.type, "zone_cleared")
	assert_eq(result.cost, 0)
	assert_false(world.zoning_system._zones.has(cell), "Zone should be erased")


func test_bulldoze_cell_clears_rock_small() -> void:
	var world = _make_world()
	var cell = Vector2i(4, 4)
	world.terrain_system._features[cell] = TerrainSystem.FeatureType.ROCK_SMALL
	GameState.budget = 10000

	var result = world._bulldoze_cell(cell)

	assert_true(result.cleared, "Rock should be cleared")
	assert_eq(result.type, "rocks_cleared")
	assert_eq(result.cost, GridConstants.BULLDOZE_COST_ROCK_SMALL)
	assert_eq(GameState.budget, 10000 - GridConstants.BULLDOZE_COST_ROCK_SMALL)


func test_bulldoze_cell_clears_rock_large() -> void:
	var world = _make_world()
	var cell = Vector2i(4, 4)
	world.terrain_system._features[cell] = TerrainSystem.FeatureType.ROCK_LARGE
	GameState.budget = 10000

	var result = world._bulldoze_cell(cell)

	assert_true(result.cleared, "Large rock should be cleared")
	assert_eq(result.type, "rocks_cleared")
	assert_eq(result.cost, GridConstants.BULLDOZE_COST_ROCK_LARGE)
	assert_eq(GameState.budget, 10000 - GridConstants.BULLDOZE_COST_ROCK_LARGE)


func test_bulldoze_cell_clears_tree() -> void:
	var world = _make_world()
	var cell = Vector2i(6, 6)
	world.terrain_system._features[cell] = TerrainSystem.FeatureType.TREE_SPARSE
	GameState.budget = 10000

	var result = world._bulldoze_cell(cell)

	assert_true(result.cleared, "Tree should be cleared")
	assert_eq(result.type, "trees_cleared")
	assert_eq(result.cost, GridConstants.BULLDOZE_COST_TREE)
	assert_eq(GameState.budget, 10000 - GridConstants.BULLDOZE_COST_TREE)


func test_bulldoze_cell_clears_beach() -> void:
	var world = _make_world()
	var cell = Vector2i(7, 7)
	world.terrain_system._features[cell] = TerrainSystem.FeatureType.BEACH

	var result = world._bulldoze_cell(cell)

	assert_true(result.cleared, "Beach should be cleared")
	assert_eq(result.type, "beach_cleared")
	assert_eq(result.cost, 0)


func test_bulldoze_cell_nothing_clearable() -> void:
	var world = _make_world()
	var cell = Vector2i(10, 10)

	var result = world._bulldoze_cell(cell)

	assert_false(result.cleared, "Nothing should be cleared on empty cell")
	assert_eq(result.type, "")
	assert_eq(result.cost, 0)


func test_bulldoze_cell_rock_unaffordable() -> void:
	var world = _make_world()
	var cell = Vector2i(4, 4)
	world.terrain_system._features[cell] = TerrainSystem.FeatureType.ROCK_SMALL
	GameState.budget = 0

	var result = world._bulldoze_cell(cell)

	assert_false(result.cleared, "Rock should not be cleared when unaffordable")
	assert_eq(result.type, "insufficient_funds")
	assert_eq(result.cost, 0)
	# Rock should still be there
	assert_eq(world.terrain_system.get_feature(cell), TerrainSystem.FeatureType.ROCK_SMALL)


func test_bulldoze_cell_tree_unaffordable() -> void:
	var world = _make_world()
	var cell = Vector2i(6, 6)
	world.terrain_system._features[cell] = TerrainSystem.FeatureType.TREE_DENSE
	GameState.budget = 0

	var result = world._bulldoze_cell(cell)

	assert_false(result.cleared, "Tree should not be cleared when unaffordable")
	assert_eq(result.type, "insufficient_funds")
	assert_eq(result.cost, 0)
	# Tree should still be there
	assert_eq(world.terrain_system.get_feature(cell), TerrainSystem.FeatureType.TREE_DENSE)


func test_bulldoze_cell_building_before_zone() -> void:
	var world = _make_world()
	var cell = Vector2i(5, 5)
	var data = MockBuildingData.new()
	var building = _track(MockBuilding.new(data))
	world.grid_system.set_building(cell, building)
	world.zoning_system._zones[cell] = 2  # commercial

	var result = world._bulldoze_cell(cell)

	assert_true(result.cleared)
	assert_eq(result.type, "building_demolished", "Building should be cleared before zone")
	# Zone should still exist
	assert_eq(world.zoning_system.get_zone_at(cell), 2)


func test_bulldoze_cell_zone_before_rock() -> void:
	var world = _make_world()
	var cell = Vector2i(5, 5)
	world.zoning_system._zones[cell] = 1  # residential
	world.terrain_system._features[cell] = TerrainSystem.FeatureType.ROCK_SMALL

	var result = world._bulldoze_cell(cell)

	assert_true(result.cleared)
	assert_eq(result.type, "zone_cleared", "Zone should be cleared before rock")
	# Rock should still be there
	assert_eq(world.terrain_system.get_feature(cell), TerrainSystem.FeatureType.ROCK_SMALL)
