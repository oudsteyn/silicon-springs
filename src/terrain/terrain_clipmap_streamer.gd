extends RefCounted
class_name TerrainClipmapStreamer

const TerrainLodManagerScript = preload("res://src/terrain/terrain_lod_manager.gd")

var chunk_size_meters: float = 128.0
var lod_manager = TerrainLodManagerScript.new()
var _last_camera_position: Vector3 = Vector3.INF
var _last_plan: Dictionary = {}
var _pending_chunk_commands: Array[Dictionary] = []
var _active_chunk_lods: Dictionary = {}


func update_camera(camera_world_pos: Vector3) -> Dictionary:
	var rebuilt = _last_camera_position == Vector3.INF \
		or lod_manager.should_rebuild_clipmap(_last_camera_position, camera_world_pos, chunk_size_meters)

	if rebuilt:
		_last_plan = lod_manager.compute_visible_chunks(camera_world_pos, chunk_size_meters)
		_build_stream_commands(_last_plan)
		_last_camera_position = camera_world_pos

	return {
		"rebuilt": rebuilt,
		"visible_chunks": _last_plan
	}


func get_pending_chunk_commands() -> Array[Dictionary]:
	return _pending_chunk_commands.duplicate(true)


func _build_stream_commands(plan: Dictionary) -> void:
	_pending_chunk_commands.clear()
	var next_chunk_lods: Dictionary = {}

	for lod in plan.keys():
		var entry = plan.get(lod, {})
		var chunks = entry.get("chunks", [])
		for chunk in chunks:
			next_chunk_lods[chunk] = int(lod)
			if not _active_chunk_lods.has(chunk) or int(_active_chunk_lods[chunk]) != int(lod):
				_pending_chunk_commands.append({
					"op": "add",
					"lod": int(lod),
					"chunk": chunk,
					"seam_mask": _compute_seam_mask(plan, int(lod), chunk)
				})

	for chunk in _active_chunk_lods.keys():
		if not next_chunk_lods.has(chunk):
			_pending_chunk_commands.append({
				"op": "remove",
				"chunk": chunk
			})

	_active_chunk_lods = next_chunk_lods


func _compute_seam_mask(plan: Dictionary, lod: int, chunk: Vector2i) -> int:
	var mask = 0
	mask |= _edge_seam(plan, lod, chunk + Vector2i(0, -1), 1) # north
	mask |= _edge_seam(plan, lod, chunk + Vector2i(1, 0), 2) # east
	mask |= _edge_seam(plan, lod, chunk + Vector2i(0, 1), 4) # south
	mask |= _edge_seam(plan, lod, chunk + Vector2i(-1, 0), 8) # west
	return mask


func _edge_seam(plan: Dictionary, lod: int, neighbor: Vector2i, bit: int) -> int:
	for other_lod in plan.keys():
		if int(other_lod) < lod:
			continue
		var chunks = plan[other_lod].get("chunks", [])
		if neighbor in chunks and int(other_lod) > lod:
			return bit
	return 0
