extends TestBase

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


func test_runtime_pipeline_configuration_enables_aaa_generation() -> void:
	var terrain = _track(TerrainSystemScript.new())
	assert_true(terrain.has_method("configure_runtime_pipeline"))
	terrain.call("configure_runtime_pipeline", true, null, 128)
	terrain.generate_initial_terrain(777)

	var any_water = false
	var any_land = false
	for x in range(GridConstants.GRID_WIDTH):
		for y in range(GridConstants.GRID_HEIGHT):
			var cell = Vector2i(x, y)
			if terrain.get_water(cell) != TerrainSystemScript.WaterType.NONE:
				any_water = true
			if terrain.get_elevation(cell) > 0:
				any_land = true
			if any_water and any_land:
				break
		if any_water and any_land:
			break

	assert_true(any_water)
	assert_true(any_land)


func test_runtime_lod_plan_uses_lod_manager() -> void:
	var terrain = _track(TerrainSystemScript.new())
	assert_true(terrain.has_method("configure_runtime_pipeline"))
	assert_true(terrain.has_method("get_runtime_lod_plan"))
	terrain.call("configure_runtime_pipeline", true, null, 0)

	var plan = terrain.call("get_runtime_lod_plan", Vector3(0.0, 0.0, 0.0), 128.0)

	assert_true(plan.has(0))
	assert_true(plan[0].has("chunks"))
	assert_not_empty(plan[0]["chunks"])
