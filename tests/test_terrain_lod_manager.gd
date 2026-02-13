extends TestBase

const LodScript = preload("res://src/terrain/terrain_lod_manager.gd")


func test_compute_visible_chunks_returns_ring_sets() -> void:
	var lod = LodScript.new()
	var result = lod.compute_visible_chunks(Vector3.ZERO, 128.0)

	assert_true(result.has(0))
	assert_true(result.has(3))
	assert_true(result[0].has("chunks"))
	assert_true(result[3].has("chunks"))
	assert_true(result[0]["chunks"].size() > 0)
	assert_true(result[3]["chunks"].size() > result[0]["chunks"].size())


func test_should_rebuild_when_crossing_chunk_boundary() -> void:
	var lod = LodScript.new()
	assert_false(lod.should_rebuild_clipmap(Vector3(10, 0, 10), Vector3(100, 0, 100), 256.0))
	assert_true(lod.should_rebuild_clipmap(Vector3(10, 0, 10), Vector3(300, 0, 300), 256.0))
