extends TestBase
## Tests for water pipe neighbor detection, zone connectivity, and rendering

const BuildingRendererScript = preload("res://src/systems/building_renderer.gd")
const BuildingDataScript = preload("res://src/resources/building_data.gd")
const TestHelpers = preload("res://tests/helpers.gd")

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


func _make_water_pipe_data() -> Resource:
	var data = BuildingDataScript.new()
	data.id = "water_pipe"
	data.building_type = "water_pipe"
	data.size = Vector2i.ONE
	data.color = Color(0.3, 0.7, 0.9, 1)
	data.requires_road_adjacent = false
	data.build_cost = 30
	return data


func _make_road_data() -> Resource:
	var data = BuildingDataScript.new()
	data.id = "road"
	data.building_type = "road"
	data.size = Vector2i.ONE
	data.color = Color.WHITE
	data.requires_road_adjacent = false
	data.build_cost = 100
	return data


# === Fake Test Helpers ===

class FakeZoningSystem extends RefCounted:
	var _zones: Dictionary = {}

	func get_zone_at(cell: Vector2i) -> int:
		return _zones.get(cell, 0)


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


class FakeBuilding extends Node2D:
	var building_data: Resource


func _make_fake_building(btype: String, water_prod: float = 0.0, water_cons: float = 0.0, power_prod: float = 0.0, power_cons: float = 0.0) -> Node2D:
	var building = _track(FakeBuilding.new())
	var data = BuildingDataScript.new()
	data.id = btype
	data.building_type = btype
	data.size = Vector2i.ONE
	data.color = Color.WHITE
	data.water_production = water_prod
	data.water_consumption = water_cons
	data.power_production = power_prod
	data.power_consumption = power_cons
	building.building_data = data
	return building


# === Water Pipe Neighbor Detection Tests ===

func test_water_pipe_detects_adjacent_water_pipe() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	grid._buildings[Vector2i(11, 10)] = _make_fake_building("water_pipe")

	var neighbors = renderer._get_water_pipe_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["east"], 1, "Should detect water pipe to the east")
	assert_eq(neighbors["west"], 0)
	assert_eq(neighbors["north"], 0)
	assert_eq(neighbors["south"], 0)


func test_water_pipe_ignores_plain_road() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	# Plain road without water pipe overlay should NOT be a neighbor
	grid._roads[Vector2i(10, 9)] = true

	var neighbors = renderer._get_water_pipe_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["north"], 0, "Should not connect to plain road without water pipe overlay")


func test_water_pipe_detects_road_with_water_overlay() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	# Road with a water pipe overlay should be a neighbor
	grid._roads[Vector2i(10, 9)] = true
	grid._overlays[Vector2i(10, 9)] = _make_fake_building("water_pipe")

	var neighbors = renderer._get_water_pipe_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["north"], 1, "Should connect to road with water pipe overlay")


func test_water_pipe_detects_water_producer() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	grid._buildings[Vector2i(10, 11)] = _make_fake_building("water_pump", 200.0)

	var neighbors = renderer._get_water_pipe_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["south"], 1, "Should detect water-producing building to the south")


func test_water_pipe_detects_water_consumer() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	grid._buildings[Vector2i(9, 10)] = _make_fake_building("residential", 0.0, 50.0)

	var neighbors = renderer._get_water_pipe_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["west"], 1, "Should detect water-consuming building to the west")


func test_water_pipe_detects_water_overlay() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	grid._overlays[Vector2i(10, 9)] = _make_fake_building("water_pipe")

	var neighbors = renderer._get_water_pipe_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["north"], 1, "Should detect water pipe overlay to the north")


func test_water_pipe_detects_adjacent_zone() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(FakeGridForNeighbors.new())
	var zoning = FakeZoningSystem.new()
	grid.zoning_system = zoning
	renderer.set_grid_system(grid)

	# Place a residential zone to the south (zone type 1 = RESIDENTIAL_LOW)
	zoning._zones[Vector2i(10, 11)] = 1

	var neighbors = renderer._get_water_pipe_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["south"], 1, "Should detect zone to the south")
	assert_eq(neighbors["north"], 0, "Should not detect zone where there is none")


func test_water_pipe_ignores_non_water_building() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	grid._buildings[Vector2i(11, 10)] = _make_fake_building("power_line")

	var neighbors = renderer._get_water_pipe_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["east"], 0, "Should not detect non-water building")


func test_water_pipe_detects_all_four_neighbors() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	grid._buildings[Vector2i(10, 9)] = _make_fake_building("water_pipe")
	grid._buildings[Vector2i(10, 11)] = _make_fake_building("water_pipe")
	grid._buildings[Vector2i(9, 10)] = _make_fake_building("water_pipe")
	grid._buildings[Vector2i(11, 10)] = _make_fake_building("water_pipe")

	var neighbors = renderer._get_water_pipe_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["north"], 1)
	assert_eq(neighbors["south"], 1)
	assert_eq(neighbors["east"], 1)
	assert_eq(neighbors["west"], 1)


func test_water_pipe_zone_no_zoning_system() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(FakeGridForNeighbors.new())
	# zoning_system is null
	renderer.set_grid_system(grid)

	var neighbors = renderer._get_water_pipe_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["north"], 0, "Should not detect anything with no zoning system")
	assert_eq(neighbors["south"], 0)
	assert_eq(neighbors["east"], 0)
	assert_eq(neighbors["west"], 0)


# === Rendering Tests ===

func test_water_pipe_renders_transparent_background() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var data = _make_water_pipe_data()
	var texture = renderer._generate_texture(data, 1, {})
	var image = texture.get_image()

	var corner = image.get_pixel(0, 0)
	assert_approx(corner.a, 0.0, 0.01, "Corner should be transparent")


func test_water_pipe_default_renders_horizontal() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var data = _make_water_pipe_data()
	var texture = renderer._generate_texture(data, 1, {
		"north": 0, "south": 0, "east": 0, "west": 0
	})
	var image = texture.get_image()
	var cy = int(image.get_height() * 0.5)

	# Default horizontal pipe should exist at center
	var pipe_pixel = image.get_pixel(5, cy)
	assert_gt(pipe_pixel.a, 0.1, "Default should have horizontal pipe")


func test_water_pipe_north_renders_vertical() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var data = _make_water_pipe_data()
	var texture = renderer._generate_texture(data, 1, {
		"north": 1, "south": 0, "east": 0, "west": 0
	})
	var image = texture.get_image()
	var cx = int(image.get_width() * 0.5)

	# North pipe should have pixels at top center
	var pipe_top = image.get_pixel(cx, 2)
	assert_gt(pipe_top.a, 0.1, "North pipe should reach top edge")


func test_water_pipe_corner_renders_both_directions() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var data = _make_water_pipe_data()
	var texture = renderer._generate_texture(data, 1, {
		"north": 1, "south": 0, "east": 1, "west": 0
	})
	var image = texture.get_image()
	var cx = int(image.get_width() * 0.5)
	var cy = int(image.get_height() * 0.5)

	# North segment should exist at top
	var pipe_north = image.get_pixel(cx, 2)
	assert_gt(pipe_north.a, 0.1, "North pipe should exist for L-corner")

	# East segment should exist at right
	var pipe_east = image.get_pixel(image.get_width() - 3, cy)
	assert_gt(pipe_east.a, 0.1, "East pipe should exist for L-corner")


# === Overlay Placement Tests ===

func test_water_pipe_overlay_on_road() -> void:
	var grid_system = TestHelpers.create_grid_system(self)

	var road_data = _make_road_data()
	var road = grid_system.place_building(Vector2i(20, 20), road_data)
	assert_not_null(road, "Road placement should succeed")

	var wp_data = _make_water_pipe_data()
	var plan = grid_system.plan_building_placement(Vector2i(20, 20), wp_data)
	assert_true(plan.can_place, "Water pipe overlay on road should be allowed")
	assert_size(plan.overlay_cells, 1)

	grid_system.free()


func test_road_on_water_pipe_allowed() -> void:
	var grid_system = TestHelpers.create_grid_system(self)

	var wp_data = _make_water_pipe_data()
	var wp = grid_system.place_building(Vector2i(20, 20), wp_data)
	assert_not_null(wp, "Water pipe placement should succeed")

	var road_data = _make_road_data()
	var plan = grid_system.plan_building_placement(Vector2i(20, 20), road_data)
	assert_true(plan.can_place, "Road on water pipe should be allowed")
	assert_size(plan.overlay_cells, 1)

	grid_system.free()
