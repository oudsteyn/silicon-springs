extends TestBase

const MainScript = preload("res://scenes/main.gd")

var _to_free: Array = []


class DummyGameWorld extends Node:
	var build_mode: bool = false
	var current_building_id: String = ""
	var requested: Array[String] = []

	func enter_build_mode(building_id: String) -> void:
		requested.append(building_id)
		build_mode = true
		current_building_id = building_id


func after_each() -> void:
	for i in range(_to_free.size() - 1, -1, -1):
		var instance = _to_free[i]
		if is_instance_valid(instance):
			instance.free()
	_to_free.clear()


func _track(instance):
	_to_free.append(instance)
	return instance


func test_hud_build_mode_maps_category_to_building_id() -> void:
	var main = _track(MainScript.new())
	var world = _track(DummyGameWorld.new())
	main.game_world = world

	main._on_city_build_mode_changed("roads")
	assert_eq(world.requested, ["road"])


func test_hud_build_mode_ignores_passthrough_building_id() -> void:
	var main = _track(MainScript.new())
	var world = _track(DummyGameWorld.new())
	main.game_world = world

	main._on_city_build_mode_changed("road")
	assert_empty(world.requested)


func test_hud_build_mode_skips_duplicate_reentry() -> void:
	var main = _track(MainScript.new())
	var world = _track(DummyGameWorld.new())
	world.build_mode = true
	world.current_building_id = "road"
	main.game_world = world

	main._on_city_build_mode_changed("roads")
	assert_empty(world.requested)
