extends TestBase


func test_default_modular_building_resources_exist() -> void:
	assert_true(FileAccess.file_exists("res://src/data/modular_buildings/residential_low.tres"))
	assert_true(FileAccess.file_exists("res://src/data/modular_buildings/commercial_low.tres"))
	assert_true(FileAccess.file_exists("res://src/data/modular_buildings/industrial_low.tres"))
