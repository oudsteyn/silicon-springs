extends Resource
class_name ModularBuildingData
## Data-driven modular building definition for high-density city assets.

@export var building_id: String = ""
@export var display_name: String = ""
@export var footprint_cells: Vector2i = Vector2i(2, 2)
@export var min_floors: int = 4
@export var max_floors: int = 24

@export_group("Modular Parts")
@export var ground_floor_mesh: Mesh
@export var middle_floor_variant_a: Mesh
@export var middle_floor_variant_b: Mesh
@export var middle_floor_variant_c: Mesh
@export var roof_mesh: Mesh

@export_group("Material Layers")
@export var facade_texture_layer: int = 0
@export var emission_texture_layer: int = 0
@export var normal_texture_layer: int = 0

@export_group("LOD Meshes")
@export var lod0_mesh: Mesh
@export var lod1_mesh: Mesh
@export var lod2_mesh: Mesh
@export var lod3_mesh: Mesh

@export_group("LOD Distances")
@export var lod1_distance: float = 80.0
@export var lod2_distance: float = 180.0
@export var lod3_distance: float = 420.0


func get_clamped_floor_count(target_floors: int) -> int:
	return clampi(target_floors, min_floors, max_floors)


func pick_middle_mesh(rng: RandomNumberGenerator) -> Mesh:
	var candidates: Array[Mesh] = []
	if middle_floor_variant_a:
		candidates.append(middle_floor_variant_a)
	if middle_floor_variant_b:
		candidates.append(middle_floor_variant_b)
	if middle_floor_variant_c:
		candidates.append(middle_floor_variant_c)
	if candidates.is_empty():
		return null
	return candidates[rng.randi() % candidates.size()]


func pick_lod_mesh(camera_distance: float) -> Mesh:
	if camera_distance >= lod3_distance and lod3_mesh:
		return lod3_mesh
	if camera_distance >= lod2_distance and lod2_mesh:
		return lod2_mesh
	if camera_distance >= lod1_distance and lod1_mesh:
		return lod1_mesh
	if lod0_mesh:
		return lod0_mesh
	return ground_floor_mesh
