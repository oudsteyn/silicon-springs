extends TestBase

const BuildingRegistryScript = preload("res://src/systems/building_registry.gd")

func before_each() -> void:
	BuildingRegistry.clear_shared_cache_for_tests()

func after_each() -> void:
	BuildingRegistry.clear_shared_cache_for_tests()

func test_get_building_data_lazy_loads_registry() -> void:
	var registry = BuildingRegistryScript.new()
	var road = registry.get_building_data("road")

	assert_not_null(road)
	assert_true(registry.get_count() > 0)
	assert_true(registry.has_building("road"))

func test_subsequent_instances_reuse_shared_cache() -> void:
	var registry1 = BuildingRegistryScript.new()
	registry1.load_registry()
	var stats_after_first = BuildingRegistry.get_shared_cache_stats()

	var registry2 = BuildingRegistryScript.new()
	registry2.load_registry()
	var stats_after_second = BuildingRegistry.get_shared_cache_stats()

	assert_eq(int(stats_after_first.get("load_cycles", -1)), 1)
	assert_eq(int(stats_after_second.get("load_cycles", -1)), 1)
	assert_true(registry2.get_count() > 0)

func test_force_reload_increments_load_cycles() -> void:
	var registry = BuildingRegistryScript.new()
	registry.load_registry()
	registry.load_registry(true)

	var stats = BuildingRegistry.get_shared_cache_stats()
	assert_eq(int(stats.get("load_cycles", -1)), 2)
