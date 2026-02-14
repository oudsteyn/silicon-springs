extends TestBase
## Tests for power line placement, neighbor detection, and rendering

const BuildingRendererScript = preload("res://src/systems/building_renderer.gd")
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


func _make_power_line_data() -> Resource:
	return TestHelpers.make_building_data("power_line", "power_line", {
		"color": Color(0.9, 0.7, 0.1, 1), "build_cost": 50
	})


func _make_road_data() -> Resource:
	return TestHelpers.make_building_data("road")


func _color_close(a: Color, b: Color, eps: float = 0.02) -> bool:
	return abs(a.r - b.r) <= eps and abs(a.g - b.g) <= eps and abs(a.b - b.b) <= eps and abs(a.a - b.a) <= eps


func _make_fake_building(btype: String, power_prod: float = 0.0, power_cons: float = 0.0, water_prod: float = 0.0, water_cons: float = 0.0) -> Node2D:
	var building = _track(TestHelpers.FakeBuilding.new())
	building.building_data = TestHelpers.make_building_data(btype, btype, {
		"power_production": power_prod, "power_consumption": power_cons,
		"water_production": water_prod, "water_consumption": water_cons
	})
	return building


# === Overlay Placement Tests ===

func test_overlay_on_road_skips_terrain_check() -> void:
	var grid_system = TestHelpers.create_grid_system(self)

	var road_data = _make_road_data()
	var road = grid_system.place_building(Vector2i(20, 20), road_data)
	assert_not_null(road, "Road placement should succeed")

	var pl_data = _make_power_line_data()
	var plan = grid_system.plan_building_placement(Vector2i(20, 20), pl_data)
	assert_true(plan.can_place, "Power line overlay on road should be allowed")
	assert_size(plan.overlay_cells, 1)

	grid_system.free()


func test_overlay_blocked_when_overlay_already_exists() -> void:
	var grid_system = TestHelpers.create_grid_system(self)

	var road_data = _make_road_data()
	grid_system.place_building(Vector2i(20, 20), road_data)

	var pl_data = _make_power_line_data()
	grid_system.place_building(Vector2i(20, 20), pl_data)

	var plan = grid_system.plan_building_placement(Vector2i(20, 20), pl_data)
	assert_false(plan.can_place, "Should not allow second overlay")

	grid_system.free()


func test_power_line_detects_adjacent_power_line_building() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(TestHelpers.FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	# Place a power line to the east
	grid._buildings[Vector2i(11, 10)] = _make_fake_building("power_line")

	var neighbors = renderer._get_power_line_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["east"], 1, "Should detect power line to the east")
	assert_eq(neighbors["west"], 0)
	assert_eq(neighbors["north"], 0)
	assert_eq(neighbors["south"], 0)


func test_power_line_detects_power_overlay() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(TestHelpers.FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	# Place a power line overlay to the north
	grid._overlays[Vector2i(10, 9)] = _make_fake_building("power_line")

	var neighbors = renderer._get_power_line_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["north"], 1, "Should detect power line overlay to the north")


func test_power_line_detects_generator() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(TestHelpers.FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	# Place a generator (power-producing building) to the south
	grid._buildings[Vector2i(10, 11)] = _make_fake_building("generator", 100.0)

	var neighbors = renderer._get_power_line_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["south"], 1, "Should detect power-producing building to the south")


func test_power_line_ignores_non_power_building() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(TestHelpers.FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	# Place a non-power building to the west
	grid._buildings[Vector2i(9, 10)] = _make_fake_building("residential")

	var neighbors = renderer._get_power_line_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["west"], 0, "Should not detect non-power building")


func test_power_line_detects_power_consumer() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(TestHelpers.FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	# Place a power-consuming building (e.g. commercial zone) to the north
	grid._buildings[Vector2i(10, 9)] = _make_fake_building("commercial", 0.0, 50.0)

	var neighbors = renderer._get_power_line_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["north"], 1, "Should detect power-consuming building to the north")


func test_power_line_detects_adjacent_zone() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(TestHelpers.FakeGridForNeighbors.new())
	var zoning = TestHelpers.FakeZoningSystem.new()
	grid.zoning_system = zoning
	renderer.set_grid_system(grid)

	# Place a commercial zone to the north (zone type 4 = COMMERCIAL_LOW)
	zoning._zones[Vector2i(10, 9)] = 4

	var neighbors = renderer._get_power_line_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["north"], 1, "Should detect zone to the north")
	assert_eq(neighbors["south"], 0, "Should not detect zone where there is none")


func test_power_line_zone_no_zoning_system() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(TestHelpers.FakeGridForNeighbors.new())
	# zoning_system is null — should not crash
	renderer.set_grid_system(grid)

	var neighbors = renderer._get_power_line_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["north"], 0, "Should not detect zone with null zoning system")


func test_power_line_zone_cleared_removes_neighbor() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(TestHelpers.FakeGridForNeighbors.new())
	var zoning = TestHelpers.FakeZoningSystem.new()
	grid.zoning_system = zoning
	renderer.set_grid_system(grid)

	# Zone to the east
	zoning._zones[Vector2i(11, 10)] = 4
	var neighbors = renderer._get_power_line_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["east"], 1, "Should detect zone to the east")

	# Clear the zone (type 0 = NONE)
	zoning._zones[Vector2i(11, 10)] = 0
	neighbors = renderer._get_power_line_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["east"], 0, "Should not detect cleared zone")


func test_power_line_detects_all_four_neighbors() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(TestHelpers.FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	grid._buildings[Vector2i(10, 9)] = _make_fake_building("power_line")
	grid._buildings[Vector2i(10, 11)] = _make_fake_building("power_line")
	grid._buildings[Vector2i(9, 10)] = _make_fake_building("power_line")
	grid._buildings[Vector2i(11, 10)] = _make_fake_building("power_line")

	var neighbors = renderer._get_power_line_neighbors(Vector2i(10, 10))
	assert_eq(neighbors["north"], 1)
	assert_eq(neighbors["south"], 1)
	assert_eq(neighbors["east"], 1)
	assert_eq(neighbors["west"], 1)


# === Rendering Tests ===

func test_power_line_renders_transparent_background() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var data = _make_power_line_data()
	var texture = renderer._generate_texture(data, 1, {})
	var image = texture.get_image()

	# Corners should be transparent (no wires/poles there)
	var corner = image.get_pixel(0, 0)
	assert_approx(corner.a, 0.0, 0.01, "Corner should be transparent")


func test_power_line_default_renders_horizontal() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var data = _make_power_line_data()
	# No neighbors → default horizontal wires
	var texture = renderer._generate_texture(data, 1, {
		"north": 0, "south": 0, "east": 0, "west": 0
	})
	var image = texture.get_image()
	var w = image.get_width()
	var cy = int(w * 0.5)

	# Horizontal wires should exist at the midline area
	var wire_pixel = image.get_pixel(5, cy - 6)
	assert_gt(wire_pixel.a, 0.1, "Default should have horizontal wires")


func test_power_line_vertical_renders_north_south_wires() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var data = _make_power_line_data()
	var texture = renderer._generate_texture(data, 1, {
		"north": 1, "south": 1, "east": 0, "west": 0
	})
	var image = texture.get_image()
	var cx = int(image.get_width() * 0.5)

	# Vertical wires at cx ± wire_offset (6) should run from top
	var wire_top = image.get_pixel(cx - 6, 2)
	assert_gt(wire_top.a, 0.1, "Vertical wires should reach top edge")


func test_power_line_corner_renders_both_directions() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var data = _make_power_line_data()
	# L-shaped: north + east
	var texture = renderer._generate_texture(data, 1, {
		"north": 1, "south": 0, "east": 1, "west": 0
	})
	var image = texture.get_image()
	var cx = int(image.get_width() * 0.5)
	var cy = int(image.get_height() * 0.5)

	# North segment wires should exist at top
	var wire_north = image.get_pixel(cx - 6, 2)
	assert_gt(wire_north.a, 0.1, "North wires should exist for L-corner")

	# East segment wires should exist at right
	var wire_east = image.get_pixel(image.get_width() - 3, cy - 6)
	assert_gt(wire_east.a, 0.1, "East wires should exist for L-corner")


func test_power_line_tee_renders_three_directions() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var data = _make_power_line_data()
	# T-shaped: north + south + east
	var texture = renderer._generate_texture(data, 1, {
		"north": 1, "south": 1, "east": 1, "west": 0
	})
	var image = texture.get_image()
	var cx = int(image.get_width() * 0.5)
	var cy = int(image.get_height() * 0.5)

	# All three connected directions should have wires
	assert_gt(image.get_pixel(cx - 6, 2).a, 0.1, "North wire")
	assert_gt(image.get_pixel(cx - 6, image.get_height() - 3).a, 0.1, "South wire")
	assert_gt(image.get_pixel(image.get_width() - 3, cy - 6).a, 0.1, "East wire")

	# West edge also has wire (full-axis rendering spans entire tile width)
	var west_edge = image.get_pixel(2, cy - 6)
	assert_gt(west_edge.a, 0.1, "West edge should have wire from full-axis horizontal rendering")


func test_power_line_cross_renders_all_four_directions() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var data = _make_power_line_data()
	# Plus-shaped: all four directions
	var texture = renderer._generate_texture(data, 1, {
		"north": 1, "south": 1, "east": 1, "west": 1
	})
	var image = texture.get_image()
	var cx = int(image.get_width() * 0.5)
	var cy = int(image.get_height() * 0.5)

	assert_gt(image.get_pixel(cx - 6, 2).a, 0.1, "North wire for cross")
	assert_gt(image.get_pixel(cx - 6, image.get_height() - 3).a, 0.1, "South wire for cross")
	assert_gt(image.get_pixel(image.get_width() - 3, cy - 6).a, 0.1, "East wire for cross")
	assert_gt(image.get_pixel(2, cy - 6).a, 0.1, "West wire for cross")


func test_power_line_size_reduced() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var data = _make_power_line_data()
	# Single neighbor to get a known wire position
	var texture = renderer._generate_texture(data, 1, {
		"north": 0, "south": 0, "east": 1, "west": 0
	})
	var image = texture.get_image()
	var cx = int(image.get_width() * 0.5)
	var cy = int(image.get_height() * 0.5)

	# Wire offset should be 6 (50% of old 12). Check pixel at old offset is empty.
	var old_offset_pixel = image.get_pixel(image.get_width() - 3, cy - 12)
	assert_approx(old_offset_pixel.a, 0.0, 0.01, "Old wire offset (12) should be empty — size reduced")

	# Wire at new offset (6) should be visible
	var new_offset_pixel = image.get_pixel(image.get_width() - 3, cy - 6)
	assert_gt(new_offset_pixel.a, 0.1, "New wire offset (6) should have wire")


func test_power_line_pole_at_center() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var data = _make_power_line_data()
	var texture = renderer._generate_texture(data, 1, {
		"north": 1, "south": 0, "east": 0, "west": 0
	})
	var image = texture.get_image()
	var cx = int(image.get_width() * 0.5)
	var cy = int(image.get_height() * 0.5)

	# Pole center should be opaque
	var center = image.get_pixel(cx, cy)
	assert_gt(center.a, 0.9, "Pole at center should be opaque")

	# Pole color should be brownish
	var pole_color = Color(0.55, 0.48, 0.35)
	assert_true(_color_close(center, pole_color), "Center should be pole color")


# === Road-on-Utility Placement Tests ===

func test_road_on_power_line_allowed() -> void:
	var grid_system = TestHelpers.create_grid_system(self)

	# Place a standalone power line
	var pl_data = _make_power_line_data()
	var pl = grid_system.place_building(Vector2i(20, 20), pl_data)
	assert_not_null(pl, "Power line placement should succeed")

	# Road overlay on existing power line should be allowed
	var road_data = _make_road_data()
	var plan = grid_system.plan_building_placement(Vector2i(20, 20), road_data)
	assert_true(plan.can_place, "Road on power line should be allowed")
	assert_size(plan.overlay_cells, 1)

	grid_system.free()


func test_road_on_power_line_places_correctly() -> void:
	var grid_system = TestHelpers.create_grid_system(self)

	# Place a standalone power line
	var pl_data = _make_power_line_data()
	grid_system.place_building(Vector2i(20, 20), pl_data)

	# Place road on top — power line should become overlay
	var road_data = _make_road_data()
	var road = grid_system.place_building(Vector2i(20, 20), road_data)
	assert_not_null(road, "Road placement on power line should succeed")

	# Road should be in buildings
	var base = grid_system.get_building_at(Vector2i(20, 20))
	assert_not_null(base, "Should have a base building")
	assert_eq(base.building_data.building_type, "road")

	# Power line should be in overlays
	assert_true(grid_system.has_overlay_at(Vector2i(20, 20)), "Power line should be overlay")
	var overlay = grid_system.get_overlay_at(Vector2i(20, 20))
	assert_eq(overlay.building_data.building_type, "power_line")

	grid_system.free()


# === Generic Utility Neighbor Tests ===

func test_get_utility_neighbors_power_detects_overlay() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(TestHelpers.FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	grid._overlays[Vector2i(10, 9)] = _make_fake_building("power_line")

	var neighbors = renderer._get_utility_neighbors(Vector2i(10, 10), "power")
	assert_eq(neighbors["north"], 1, "Generic power should detect overlay")


func test_get_utility_neighbors_water_detects_overlay() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(TestHelpers.FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	grid._overlays[Vector2i(10, 11)] = _make_fake_building("water_pipe")

	var neighbors = renderer._get_utility_neighbors(Vector2i(10, 10), "water")
	assert_eq(neighbors["south"], 1, "Generic water should detect overlay")


func test_get_utility_neighbors_power_detects_zone() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(TestHelpers.FakeGridForNeighbors.new())
	var zoning = TestHelpers.FakeZoningSystem.new()
	grid.zoning_system = zoning
	renderer.set_grid_system(grid)

	zoning._zones[Vector2i(11, 10)] = 4

	var neighbors = renderer._get_utility_neighbors(Vector2i(10, 10), "power")
	assert_eq(neighbors["east"], 1, "Generic power should detect zone")


func test_get_utility_neighbors_water_detects_connectable() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var grid = _track(TestHelpers.FakeGridForNeighbors.new())
	renderer.set_grid_system(grid)

	grid._buildings[Vector2i(9, 10)] = _make_fake_building("water_pump", 0.0, 0.0, 200.0)

	var neighbors = renderer._get_utility_neighbors(Vector2i(10, 10), "water")
	assert_eq(neighbors["west"], 1, "Generic water should detect connectable building")


func test_get_utility_neighbors_returns_empty_without_grid() -> void:
	var renderer = _track(BuildingRendererScript.new())

	var neighbors = renderer._get_utility_neighbors(Vector2i(10, 10), "power")
	assert_eq(neighbors["north"], 0)
	assert_eq(neighbors["south"], 0)
	assert_eq(neighbors["east"], 0)
	assert_eq(neighbors["west"], 0)


# === Bulldoze Overlay Tests ===

func test_bulldoze_removes_overlay_before_base() -> void:
	var grid_system = TestHelpers.create_grid_system(self)

	# Place road + power line overlay
	var road_data = _make_road_data()
	grid_system.place_building(Vector2i(20, 20), road_data)
	var pl_data = _make_power_line_data()
	grid_system.place_building(Vector2i(20, 20), pl_data)

	assert_true(grid_system.has_overlay_at(Vector2i(20, 20)), "Should have overlay")

	# First remove should take the overlay
	grid_system.remove_building(Vector2i(20, 20))
	assert_false(grid_system.has_overlay_at(Vector2i(20, 20)), "Overlay should be removed")
	assert_true(grid_system.has_building_at(Vector2i(20, 20)), "Road should still exist")

	# Second remove should take the road
	grid_system.remove_building(Vector2i(20, 20))
	assert_false(grid_system.has_building_at(Vector2i(20, 20)), "Road should be removed")

	grid_system.free()
