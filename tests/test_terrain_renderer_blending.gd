extends TestBase

const TerrainRendererScript = preload("res://src/systems/terrain_renderer.gd")
const TerrainSystemScript = preload("res://src/systems/terrain_system.gd")
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


func test_surface_class_prioritizes_water_then_sand_then_rock() -> void:
	var renderer = _track(TerrainRendererScript.new())
	assert_eq(renderer._get_surface_class(0, TerrainSystemScript.WaterType.LAKE), "water")
	assert_eq(renderer._get_surface_class(-1, TerrainSystemScript.WaterType.NONE), "sand")
	assert_eq(renderer._get_surface_class(4, TerrainSystemScript.WaterType.NONE), "rock")
	assert_eq(renderer._get_surface_class(1, TerrainSystemScript.WaterType.NONE), "grass")


func test_blend_surface_color_returns_translucent_midpoint() -> void:
	var renderer = _track(TerrainRendererScript.new())
	var a = Color(0.2, 0.4, 0.6, 1.0)
	var b = Color(0.8, 0.6, 0.2, 1.0)
	var blended = renderer._blend_surface_color(a, b)

	assert_approx(blended.r, 0.5, 0.01)
	assert_approx(blended.g, 0.5, 0.01)
	assert_approx(blended.b, 0.4, 0.01)
	assert_approx(blended.a, TerrainRendererScript.TERRAIN_BLEND_ALPHA, 0.001)


func test_should_blend_transition_for_same_surface_when_color_shift_is_large() -> void:
	var renderer = _track(TerrainRendererScript.new())
	var a = Color(0.30, 0.50, 0.30, 1.0)
	var b = Color(0.45, 0.62, 0.40, 1.0)
	assert_true(renderer._should_blend_transition("grass", a, "grass", b))


func test_should_not_blend_transition_for_same_surface_when_color_shift_is_small() -> void:
	var renderer = _track(TerrainRendererScript.new())
	var a = Color(0.30, 0.50, 0.30, 1.0)
	var b = Color(0.32, 0.52, 0.31, 1.0)
	assert_false(renderer._should_blend_transition("grass", a, "grass", b))


func test_is_isolated_pond_cell_detects_single_tile_water() -> void:
	var renderer = _track(TerrainRendererScript.new())
	var terrain = _track(TerrainSystemScript.new())
	renderer.terrain_system = terrain
	terrain.set_water(Vector2i(10, 10), TerrainSystemScript.WaterType.POND)

	assert_true(renderer._is_isolated_pond_cell(Vector2i(10, 10), TerrainSystemScript.WaterType.POND))


func test_is_isolated_pond_cell_false_when_adjacent_water_exists() -> void:
	var renderer = _track(TerrainRendererScript.new())
	var terrain = _track(TerrainSystemScript.new())
	renderer.terrain_system = terrain
	terrain.set_water(Vector2i(11, 11), TerrainSystemScript.WaterType.POND)
	terrain.set_water(Vector2i(12, 11), TerrainSystemScript.WaterType.POND)

	assert_false(renderer._is_isolated_pond_cell(Vector2i(11, 11), TerrainSystemScript.WaterType.POND))
