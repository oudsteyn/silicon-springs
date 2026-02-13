extends Resource
class_name TerrainNoiseProfile

@export var seed: int = 1337
@export var world_size_meters: float = 4096.0
@export var height_scale: float = 450.0
@export var sea_level: float = 28.0

@export var mountain_frequency: float = 0.00085
@export var mountain_octaves: int = 6
@export var mountain_lacunarity: float = 2.1
@export var mountain_gain: float = 0.48
@export var mountain_weight: float = 0.65

@export var hills_frequency: float = 0.0028
@export var hills_octaves: int = 5
@export var hills_lacunarity: float = 2.0
@export var hills_gain: float = 0.50
@export var hills_weight: float = 0.28

@export var plains_frequency: float = 0.0090
@export var plains_octaves: int = 3
@export var plains_lacunarity: float = 2.0
@export var plains_gain: float = 0.55
@export var plains_weight: float = 0.07

@export var falloff_start: float = 0.62
@export var falloff_range: float = 0.45
@export var falloff_power: float = 2.4


func normalize_weights() -> void:
	var total = mountain_weight + hills_weight + plains_weight
	if total <= 0.00001:
		mountain_weight = 0.65
		hills_weight = 0.28
		plains_weight = 0.07
		return
	mountain_weight /= total
	hills_weight /= total
	plains_weight /= total
