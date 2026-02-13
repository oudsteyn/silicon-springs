extends TestBase

const TerrainRendererScript = preload("res://src/systems/terrain_renderer.gd")
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


func _build_height(size: int, value: float = 8.0) -> PackedFloat32Array:
	var h := PackedFloat32Array()
	h.resize(size * size)
	for i in h.size():
		h[i] = value
	return h


func test_runtime_3d_pipeline_syncs_chunks_and_details() -> void:
	var renderer = _track(TerrainRendererScript.new())
	renderer.set_runtime_3d_enabled(true)

	var height = _build_height(64, 12.0)
	renderer._on_runtime_heightmap_generated(height, 64, 4.0)

	var stats = renderer.get_runtime_3d_stats()
	assert_true(bool(stats.get("enabled", false)))
	assert_gt(int(stats.get("active_chunks", 0)), 0)
	assert_gt(int(stats.get("grass_instances", 0)) + int(stats.get("rock_instances", 0)), 0)


func test_runtime_3d_pipeline_releases_internal_nodes_on_free() -> void:
	var renderer = TerrainRendererScript.new()
	var manager_ref = weakref(renderer._runtime_3d_manager)
	var detail_ref = weakref(renderer._runtime_detail_renderer)

	renderer.free()

	assert_eq(manager_ref.get_ref(), null)
	assert_eq(detail_ref.get_ref(), null)
