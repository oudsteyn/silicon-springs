extends Node3D
class_name TerrainRuntime3DManager

const TerrainMeshBridgeScript = preload("res://src/terrain/terrain_mesh_bridge.gd")

var _mesh_bridge = TerrainMeshBridgeScript.new()
var _active_chunks: Dictionary = {}
var _chunk_pool: Array[MeshInstance3D] = []
var _chunk_metadata: Dictionary = {}


func sync_clipmap(heightmap: PackedFloat32Array, heightmap_size: int, plan: Dictionary, chunk_resolution: int = 16) -> void:
	var next_keys: Dictionary = {}
	for lod in plan.keys():
		var entry = plan.get(lod, {})
		var settings = entry.get("settings", {})
		var m_per_vertex = float(settings.get("meters_per_vertex", 1.0))
		var chunks = entry.get("chunks", [])
		for chunk in chunks:
			var key = _chunk_key(chunk, int(lod))
			next_keys[key] = true
			if not _active_chunks.has(key):
				var inst = _acquire_chunk_instance()
				_active_chunks[key] = inst
				_add_chunk_instance(inst)
			_update_chunk_mesh(_active_chunks[key], heightmap, heightmap_size, chunk, chunk_resolution, m_per_vertex)
			_chunk_metadata[key] = {
				"lod": int(lod),
				"chunk": chunk,
				"seam_mask": _compute_seam_mask(plan, int(lod), chunk)
			}

	for key in _active_chunks.keys():
		if not next_keys.has(key):
			var inst: MeshInstance3D = _active_chunks[key]
			_active_chunks.erase(key)
			_chunk_metadata.erase(key)
			_release_chunk_instance(inst)


func get_active_chunk_count() -> int:
	return _active_chunks.size()


func get_pool_size() -> int:
	return _chunk_pool.size()


func get_chunk_metadata(chunk: Vector2i, lod: int) -> Dictionary:
	var key = _chunk_key(chunk, lod)
	return _chunk_metadata.get(key, {})


func clear_chunks() -> void:
	for inst in _active_chunks.values():
		_free_chunk_instance(inst)
	for inst in _chunk_pool:
		_free_chunk_instance(inst)
	_active_chunks.clear()
	_chunk_pool.clear()
	_chunk_metadata.clear()


func _chunk_key(chunk: Vector2i, lod: int) -> String:
	return "%d:%d:%d" % [lod, chunk.x, chunk.y]


func _acquire_chunk_instance() -> MeshInstance3D:
	if not _chunk_pool.is_empty():
		return _chunk_pool.pop_back()
	var inst = MeshInstance3D.new()
	inst.name = "TerrainChunk"
	return inst


func _release_chunk_instance(inst: MeshInstance3D) -> void:
	inst.visible = false
	inst.mesh = null
	_chunk_pool.append(inst)


func _add_chunk_instance(inst: MeshInstance3D) -> void:
	if inst.get_parent() != self:
		add_child(inst)
	inst.visible = true


func _free_chunk_instance(inst: MeshInstance3D) -> void:
	if not is_instance_valid(inst):
		return
	inst.mesh = null
	if inst.get_parent():
		inst.get_parent().remove_child(inst)
	inst.free()


func _update_chunk_mesh(
	inst: MeshInstance3D,
	heightmap: PackedFloat32Array,
	heightmap_size: int,
	chunk: Vector2i,
	chunk_resolution: int,
	meters_per_vertex: float
) -> void:
	var origin = Vector2i(chunk.x * chunk_resolution, chunk.y * chunk_resolution)
	var data = _mesh_bridge.generate_chunk_mesh_data(
		heightmap,
		heightmap_size,
		origin,
		chunk_resolution,
		meters_per_vertex,
		1.0
	)
	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data.vertices
	arrays[Mesh.ARRAY_NORMAL] = data.normals
	arrays[Mesh.ARRAY_TEX_UV] = data.uvs
	arrays[Mesh.ARRAY_INDEX] = data.indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	inst.mesh = mesh
	inst.position = Vector3(float(origin.x) * meters_per_vertex, 0.0, float(origin.y) * meters_per_vertex)


func _compute_seam_mask(plan: Dictionary, lod: int, chunk: Vector2i) -> int:
	var mask = 0
	mask |= _edge_seam(plan, lod, chunk + Vector2i(0, -1), 1)
	mask |= _edge_seam(plan, lod, chunk + Vector2i(1, 0), 2)
	mask |= _edge_seam(plan, lod, chunk + Vector2i(0, 1), 4)
	mask |= _edge_seam(plan, lod, chunk + Vector2i(-1, 0), 8)
	return mask


func _edge_seam(plan: Dictionary, lod: int, neighbor: Vector2i, bit: int) -> int:
	for other_lod in plan.keys():
		if int(other_lod) <= lod:
			continue
		var chunks = plan[other_lod].get("chunks", [])
		if neighbor in chunks:
			return bit
	return 0
