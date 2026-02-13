extends Node3D
class_name RoadsideMultiMeshBatch
## Batches repeated roadside props (lamps, barriers, bollards) into MultiMeshes.

var _groups: Dictionary = {}


func configure_group(group_id: String, mesh: Mesh, material: Material = null) -> void:
	var instance: MultiMeshInstance3D = _groups.get(group_id, null)
	if instance == null:
		instance = MultiMeshInstance3D.new()
		instance.name = "MM_%s" % group_id
		instance.multimesh = MultiMesh.new()
		instance.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		add_child(instance)
		_groups[group_id] = instance
	instance.multimesh.mesh = mesh
	if material:
		instance.material_override = material


func set_instances(group_id: String, transforms: Array[Transform3D], cull_distance: float = 300.0) -> void:
	var instance: MultiMeshInstance3D = _groups.get(group_id, null)
	if instance == null:
		return
	var mm = instance.multimesh
	if mm == null:
		return
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	instance.visibility_range_end = cull_distance


func clear_group(group_id: String) -> void:
	var instance: MultiMeshInstance3D = _groups.get(group_id, null)
	if instance == null:
		return
	if instance.get_parent():
		instance.get_parent().remove_child(instance)
	instance.free()
	_groups.erase(group_id)


func clear_all() -> void:
	for key in _groups.keys():
		clear_group(str(key))
