extends TestBase
## Tests for SaveSystem delegating to system save/load interfaces.


class FakeSystem extends Node:
	var saved: bool = false
	var loaded: bool = false
	var loaded_data = null

	func get_save_data() -> Dictionary:
		saved = true
		return {"marker": 1}

	func load_save_data(data: Dictionary) -> void:
		loaded = true
		loaded_data = data


func test_save_system_uses_get_save_data_for_power() -> void:
	var save_system = SaveSystem.new()
	var power = FakeSystem.new()
	save_system.set_power_system(power)

	var data = save_system._serialize_power_system()
	assert_true(power.saved)
	assert_eq(data.marker, 1)


func test_save_system_uses_get_save_data_for_water() -> void:
	var save_system = SaveSystem.new()
	var water = FakeSystem.new()
	save_system.set_water_system(water)

	var data = save_system._serialize_water_system()
	assert_true(water.saved)
	assert_eq(data.marker, 1)


func test_save_system_uses_get_save_data_for_pollution() -> void:
	var save_system = SaveSystem.new()
	var pollution = FakeSystem.new()
	save_system.set_pollution_system(pollution)

	var data = save_system._serialize_pollution_system()
	assert_true(pollution.saved)
	assert_eq(data.marker, 1)


func test_save_system_uses_get_save_data_for_infrastructure_age() -> void:
	var save_system = SaveSystem.new()
	var infra = FakeSystem.new()
	save_system.set_infrastructure_age_system(infra)

	var data = save_system._serialize_infrastructure_age()
	assert_true(infra.saved)
	assert_eq(data.marker, 1)


func test_save_system_uses_load_save_data_for_power() -> void:
	var save_system = SaveSystem.new()
	var power = FakeSystem.new()
	save_system.set_power_system(power)

	save_system._restore_power_system({"marker": 2})
	assert_true(power.loaded)
	assert_eq(power.loaded_data.marker, 2)


func test_save_system_uses_load_save_data_for_water() -> void:
	var save_system = SaveSystem.new()
	var water = FakeSystem.new()
	save_system.set_water_system(water)

	save_system._restore_water_system({"marker": 2})
	assert_true(water.loaded)
	assert_eq(water.loaded_data.marker, 2)


func test_save_system_uses_load_save_data_for_pollution() -> void:
	var save_system = SaveSystem.new()
	var pollution = FakeSystem.new()
	save_system.set_pollution_system(pollution)

	save_system._restore_pollution_system({"marker": 2})
	assert_true(pollution.loaded)
	assert_eq(pollution.loaded_data.marker, 2)


func test_save_system_uses_load_save_data_for_infrastructure_age() -> void:
	var save_system = SaveSystem.new()
	var infra = FakeSystem.new()
	save_system.set_infrastructure_age_system(infra)

	save_system._restore_infrastructure_age({"marker": 2})
	assert_true(infra.loaded)
	assert_eq(infra.loaded_data.marker, 2)
