extends RefCounted
class_name TerrainClipmapStreamer

const TerrainLodManagerScript = preload("res://src/terrain/terrain_lod_manager.gd")

var chunk_size_meters: float = 128.0
var lod_manager = TerrainLodManagerScript.new()
var _last_camera_position: Vector3 = Vector3.INF
var _last_plan: Dictionary = {}


func update_camera(camera_world_pos: Vector3) -> Dictionary:
	var rebuilt = _last_camera_position == Vector3.INF \
		or lod_manager.should_rebuild_clipmap(_last_camera_position, camera_world_pos, chunk_size_meters)

	if rebuilt:
		_last_plan = lod_manager.compute_visible_chunks(camera_world_pos, chunk_size_meters)
		_last_camera_position = camera_world_pos

	return {
		"rebuilt": rebuilt,
		"visible_chunks": _last_plan
	}
