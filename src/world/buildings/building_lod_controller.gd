extends Node3D
class_name BuildingLodController
## Aggressive LOD switching for modular buildings.

@export var data: ModularBuildingData
@export var target_mesh_instance_path: NodePath

var _target_mesh_instance: MeshInstance3D = null


func _ready() -> void:
	if target_mesh_instance_path != NodePath(""):
		_target_mesh_instance = get_node_or_null(target_mesh_instance_path) as MeshInstance3D
	if _target_mesh_instance == null:
		_target_mesh_instance = _find_first_mesh_instance(self)


func update_lod(camera_position: Vector3) -> void:
	if data == null or _target_mesh_instance == null:
		return
	var distance = global_position.distance_to(camera_position)
	var mesh = data.pick_lod_mesh(distance)
	if mesh and _target_mesh_instance.mesh != mesh:
		_target_mesh_instance.mesh = mesh


func _find_first_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found = _find_first_mesh_instance(child)
		if found:
			return found
	return null
