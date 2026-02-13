extends Node3D
class_name TerrainDetailRenderer3D

var _grass_instance: MultiMeshInstance3D = null
var _rock_instance: MultiMeshInstance3D = null


func configure_instances(
	grass_transforms: Array,
	rock_transforms: Array,
	grass_mesh: Mesh,
	rock_mesh: Mesh
) -> void:
	_grass_instance = _ensure_multimesh(_grass_instance, "GrassDetail")
	_rock_instance = _ensure_multimesh(_rock_instance, "RockDetail")

	_setup_multimesh(_grass_instance, grass_mesh, grass_transforms, 250.0)
	_setup_multimesh(_rock_instance, rock_mesh, rock_transforms, 500.0)


func get_grass_count() -> int:
	if _grass_instance == null or _grass_instance.multimesh == null:
		return 0
	return _grass_instance.multimesh.instance_count


func get_rock_count() -> int:
	if _rock_instance == null or _rock_instance.multimesh == null:
		return 0
	return _rock_instance.multimesh.instance_count


func _ensure_multimesh(inst: MultiMeshInstance3D, node_name: String) -> MultiMeshInstance3D:
	if inst != null and is_instance_valid(inst):
		return inst
	var node = MultiMeshInstance3D.new()
	node.name = node_name
	add_child(node)
	return node


func _setup_multimesh(node: MultiMeshInstance3D, mesh: Mesh, transforms: Array, visibility_range_end: float) -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = transforms.size()
	mm.mesh = mesh
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	node.multimesh = mm
	node.visibility_range_end = visibility_range_end
