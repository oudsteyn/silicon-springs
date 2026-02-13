extends TestBase

const ModularBuildingDataScript = preload("res://src/resources/modular_building_data.gd")


func test_floor_count_clamps_to_resource_limits() -> void:
	var data = ModularBuildingDataScript.new()
	data.min_floors = 5
	data.max_floors = 12

	assert_eq(data.get_clamped_floor_count(2), 5)
	assert_eq(data.get_clamped_floor_count(9), 9)
	assert_eq(data.get_clamped_floor_count(20), 12)


func test_pick_lod_mesh_returns_expected_level() -> void:
	var data = ModularBuildingDataScript.new()
	data.lod0_mesh = BoxMesh.new()
	data.lod1_mesh = CylinderMesh.new()
	data.lod2_mesh = SphereMesh.new()
	data.lod3_mesh = PlaneMesh.new()
	data.lod1_distance = 50.0
	data.lod2_distance = 100.0
	data.lod3_distance = 200.0

	assert_true(data.pick_lod_mesh(20.0) is BoxMesh)
	assert_true(data.pick_lod_mesh(70.0) is CylinderMesh)
	assert_true(data.pick_lod_mesh(140.0) is SphereMesh)
	assert_true(data.pick_lod_mesh(300.0) is PlaneMesh)
