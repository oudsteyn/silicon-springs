extends RefCounted
class_name TerrainLodManager

const DEFAULT_RINGS := [
	{"radius_m": 256.0, "meters_per_vertex": 1.0, "collision": true},
	{"radius_m": 512.0, "meters_per_vertex": 2.0, "collision": true},
	{"radius_m": 1024.0, "meters_per_vertex": 4.0, "collision": false},
	{"radius_m": 2048.0, "meters_per_vertex": 8.0, "collision": false}
]


func get_default_rings() -> Array:
	return DEFAULT_RINGS.duplicate(true)


func compute_visible_chunks(
	camera_world_pos: Vector3,
	chunk_size_m: float,
	rings: Array = DEFAULT_RINGS
) -> Dictionary:
	var result := {}
	var center_chunk = Vector2i(
		int(floor(camera_world_pos.x / chunk_size_m)),
		int(floor(camera_world_pos.z / chunk_size_m))
	)

	for i in rings.size():
		var ring = rings[i]
		var radius_m = float(ring.get("radius_m", 0.0))
		var radius_chunks = int(ceil(radius_m / chunk_size_m))
		var ring_chunks: Array[Vector2i] = []
		for y in range(center_chunk.y - radius_chunks, center_chunk.y + radius_chunks + 1):
			for x in range(center_chunk.x - radius_chunks, center_chunk.x + radius_chunks + 1):
				var chunk = Vector2i(x, y)
				var dx = float(chunk.x - center_chunk.x) * chunk_size_m
				var dz = float(chunk.y - center_chunk.y) * chunk_size_m
				if sqrt(dx * dx + dz * dz) <= radius_m:
					ring_chunks.append(chunk)
		result[i] = {
			"settings": ring.duplicate(true),
			"chunks": ring_chunks
		}
	return result


func should_rebuild_clipmap(previous_camera: Vector3, current_camera: Vector3, chunk_size_m: float) -> bool:
	var prev_chunk = Vector2i(int(floor(previous_camera.x / chunk_size_m)), int(floor(previous_camera.z / chunk_size_m)))
	var curr_chunk = Vector2i(int(floor(current_camera.x / chunk_size_m)), int(floor(current_camera.z / chunk_size_m)))
	return prev_chunk != curr_chunk
