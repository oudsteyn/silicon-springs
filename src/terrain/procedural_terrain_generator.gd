extends RefCounted
class_name ProceduralTerrainGenerator

const TerrainNoiseProfileScript = preload("res://src/terrain/terrain_noise_profile.gd")


func generate_heightmap(size: int, profile = null) -> PackedFloat32Array:
	var cfg = profile if profile != null else TerrainNoiseProfileScript.new()
	cfg.normalize_weights()

	var mountain = _make_noise(
		cfg.seed + 11,
		FastNoiseLite.TYPE_SIMPLEX,
		cfg.mountain_frequency,
		cfg.mountain_octaves,
		cfg.mountain_lacunarity,
		cfg.mountain_gain
	)
	var hills = _make_noise(
		cfg.seed + 23,
		FastNoiseLite.TYPE_PERLIN,
		cfg.hills_frequency,
		cfg.hills_octaves,
		cfg.hills_lacunarity,
		cfg.hills_gain
	)
	var plains = _make_noise(
		cfg.seed + 37,
		FastNoiseLite.TYPE_PERLIN,
		cfg.plains_frequency,
		cfg.plains_octaves,
		cfg.plains_lacunarity,
		cfg.plains_gain
	)

	var output := PackedFloat32Array()
	output.resize(size * size)

	var half = float(size) * 0.5
	for y in size:
		for x in size:
			var idx = y * size + x

			var m = 0.5 + 0.5 * mountain.get_noise_2d(x, y)
			var h = 0.5 + 0.5 * hills.get_noise_2d(x, y)
			var p = 0.5 + 0.5 * plains.get_noise_2d(x, y)
			var base = m * cfg.mountain_weight + h * cfg.hills_weight + p * cfg.plains_weight
			var falloff = calculate_island_falloff(x, y, half, cfg.falloff_start, cfg.falloff_range, cfg.falloff_power)

			output[idx] = max(base * falloff * cfg.height_scale, 0.0)
	return output


func calculate_island_falloff(
	x: float,
	y: float,
	half_size: float,
	start: float,
	falloff_range: float,
	power: float
) -> float:
	var nx = (x - half_size) / half_size
	var ny = (y - half_size) / half_size
	var d = sqrt(nx * nx + ny * ny)
	var t = clamp((d - start) / max(falloff_range, 0.00001), 0.0, 1.0)
	return clamp(1.0 - pow(t, power), 0.0, 1.0)


func _make_noise(seed: int, noise_type: int, frequency: float, octaves: int, lacunarity: float, gain: float) -> FastNoiseLite:
	var noise = FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = noise_type
	noise.frequency = frequency
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = gain
	return noise
