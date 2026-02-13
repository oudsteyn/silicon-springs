extends TestBase

const TerrainRuntime3DManagerScript = preload("res://src/terrain/terrain_runtime_3d_manager.gd")

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


func _make_height(size: int, value: float = 5.0) -> PackedFloat32Array:
	var h := PackedFloat32Array()
	h.resize(size * size)
	for i in h.size():
		h[i] = value
	return h


func test_sync_clipmap_creates_and_reuses_chunk_instances() -> void:
	var manager = _track(TerrainRuntime3DManagerScript.new())
	var height = _make_height(64, 12.0)

	var plan_a = {
		0: {"settings": {"meters_per_vertex": 1.0}, "chunks": [Vector2i(0, 0), Vector2i(1, 0)]},
		1: {"settings": {"meters_per_vertex": 2.0}, "chunks": [Vector2i(2, 0)]}
	}
	manager.sync_clipmap(height, 64, plan_a, 16)
	assert_eq(manager.get_active_chunk_count(), 3)

	var plan_b = {
		0: {"settings": {"meters_per_vertex": 1.0}, "chunks": [Vector2i(0, 0)]}
	}
	manager.sync_clipmap(height, 64, plan_b, 16)
	assert_eq(manager.get_active_chunk_count(), 1)
	assert_gt(manager.get_pool_size(), 0)


func test_chunk_metadata_includes_seam_mask() -> void:
	var manager = _track(TerrainRuntime3DManagerScript.new())
	var height = _make_height(64, 8.0)
	var plan = {
		0: {"settings": {"meters_per_vertex": 1.0}, "chunks": [Vector2i(0, 0), Vector2i(1, 0)]},
		1: {"settings": {"meters_per_vertex": 2.0}, "chunks": [Vector2i(0, 1)]}
	}

	manager.sync_clipmap(height, 64, plan, 16)
	var meta = manager.get_chunk_metadata(Vector2i(0, 0), 0)
	assert_true(meta.has("seam_mask"))
