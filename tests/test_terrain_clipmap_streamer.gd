extends TestBase

const TerrainClipmapStreamerScript = preload("res://src/terrain/terrain_clipmap_streamer.gd")


func test_update_camera_rebuilds_on_chunk_boundary_crossing() -> void:
	var streamer = TerrainClipmapStreamerScript.new()
	streamer.chunk_size_meters = 128.0

	var first = streamer.update_camera(Vector3(10.0, 0.0, 10.0))
	var second = streamer.update_camera(Vector3(20.0, 0.0, 20.0))
	var third = streamer.update_camera(Vector3(140.0, 0.0, 10.0))

	assert_true(first.rebuilt)
	assert_false(second.rebuilt)
	assert_true(third.rebuilt)
	assert_true(third.visible_chunks.has(0))

