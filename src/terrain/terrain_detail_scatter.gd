extends RefCounted
class_name TerrainDetailScatter


func build_scatter_transforms(
	heightmap: PackedFloat32Array,
	heightmap_size: int,
	meters_per_vertex: float,
	sea_level: float,
	seed: int = 1337
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var grass: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []

	for y in range(1, heightmap_size - 1):
		for x in range(1, heightmap_size - 1):
			var h = _sample(heightmap, heightmap_size, x, y)
			if h <= sea_level:
				continue
			var slope = _slope(heightmap, heightmap_size, x, y)
			var world_pos = Vector3(float(x) * meters_per_vertex, h, float(y) * meters_per_vertex)
			var basis = Basis.from_euler(Vector3(0.0, rng.randf_range(0.0, TAU), 0.0))
			var xform = Transform3D(basis, world_pos)

			# Grass prefers flatter surfaces above shoreline.
			if slope < 0.85 and rng.randf() < 0.055:
				grass.append(xform)

			# Rocks prefer steeper terrain.
			if slope >= 0.45 and rng.randf() < 0.03:
				rocks.append(xform)

	return {
		"grass": grass,
		"rocks": rocks
	}


func _sample(heightmap: PackedFloat32Array, size: int, x: int, y: int) -> float:
	var sx = clampi(x, 0, size - 1)
	var sy = clampi(y, 0, size - 1)
	return heightmap[sy * size + sx]


func _slope(heightmap: PackedFloat32Array, size: int, x: int, y: int) -> float:
	var hx = _sample(heightmap, size, x + 1, y) - _sample(heightmap, size, x - 1, y)
	var hy = _sample(heightmap, size, x, y + 1) - _sample(heightmap, size, x, y - 1)
	return minf(sqrt(hx * hx + hy * hy), 1.0)
