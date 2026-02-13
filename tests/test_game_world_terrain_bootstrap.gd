extends TestBase

const GameWorldScript = preload("res://scenes/game_world.gd")

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


class DummyTerrainRenderer extends Node:
	var set_terrain_system_called = false
	var set_grid_system_called = false
	var set_camera_called = false
	var runtime_3d_enabled_called = false
	var configure_runtime_called = false
	var refresh_called = false

	func set_terrain_system(_terrain) -> void:
		set_terrain_system_called = true

	func set_grid_system(_grid) -> void:
		set_grid_system_called = true

	func set_camera(_camera) -> void:
		set_camera_called = true

	func set_runtime_3d_enabled(_enabled: bool) -> void:
		runtime_3d_enabled_called = true

	func configure_runtime_terrain_pipeline(_terrain_system) -> void:
		configure_runtime_called = true

	func refresh() -> void:
		refresh_called = true


class DummyTerrainSystem extends Node:
	var set_grid_system_called = false
	var configure_called = false
	var configure_enabled = false
	var generate_called = false

	func set_grid_system(_grid) -> void:
		set_grid_system_called = true

	func configure_runtime_pipeline(enabled: bool, _profile = null, _erosion_iterations: int = -1) -> void:
		configure_called = true
		configure_enabled = enabled

	func generate_initial_terrain(_seed: int, _biome = null) -> void:
		generate_called = true


func test_setup_terrain_configures_runtime_pipeline_before_generation() -> void:
	var world = _track(GameWorldScript.new())
	var terrain_system = _track(DummyTerrainSystem.new())
	var terrain_renderer = _track(DummyTerrainRenderer.new())

	world.grid_system = _track(Node.new())
	world.terrain_system = terrain_system
	world.terrain_renderer = terrain_renderer
	world.camera = _track(Camera2D.new())
	world.terrain_background = _track(ColorRect.new())

	world._setup_terrain()

	assert_true(terrain_renderer.set_terrain_system_called)
	assert_true(terrain_renderer.set_grid_system_called)
	assert_true(terrain_renderer.set_camera_called)
	assert_true(terrain_renderer.runtime_3d_enabled_called)
	assert_true(terrain_renderer.configure_runtime_called)
	assert_true(terrain_system.set_grid_system_called)
	assert_true(terrain_system.configure_called)
	assert_true(terrain_system.configure_enabled)
	assert_true(terrain_system.generate_called)
	assert_true(terrain_renderer.refresh_called)
	assert_false(world.terrain_background.visible)
