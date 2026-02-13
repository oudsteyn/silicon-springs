extends TestBase

const TerrainDetailRenderer3DScript = preload("res://src/terrain/terrain_detail_renderer_3d.gd")

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


func test_configure_instances_builds_multimesh_nodes() -> void:
	var renderer = _track(TerrainDetailRenderer3DScript.new())
	var grass_mesh = QuadMesh.new()
	var rock_mesh = BoxMesh.new()
	var grass_xforms = [
		Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)),
		Transform3D(Basis.IDENTITY, Vector3(2, 0, 1))
	]
	var rock_xforms = [
		Transform3D(Basis.IDENTITY, Vector3(5, 0, 5))
	]

	renderer.configure_instances(grass_xforms, rock_xforms, grass_mesh, rock_mesh)

	assert_eq(renderer.get_grass_count(), 2)
	assert_eq(renderer.get_rock_count(), 1)
