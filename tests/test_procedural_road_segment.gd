extends TestBase

const ProceduralRoadSegmentScript = preload("res://src/systems/roads/procedural_road_segment.gd")
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


func test_build_from_curve_generates_mesh_and_decal_points() -> void:
	var road = _track(ProceduralRoadSegmentScript.new())
	var curve := Curve3D.new()
	curve.add_point(Vector3(0, 0, 0))
	curve.add_point(Vector3(0, 0, 20))
	curve.add_point(Vector3(10, 0, 40))

	road.build_from_curve(curve)

	assert_not_null(road.mesh_instance.mesh)
	assert_gt(road.get_decal_mark_positions().size(), 0)
