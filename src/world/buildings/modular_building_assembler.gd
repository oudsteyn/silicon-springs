extends Node3D
class_name ModularBuildingAssembler
## Builds stacked modular meshes from a ModularBuildingData resource.

func assemble(data: Resource, floor_count: int, rng: RandomNumberGenerator = null) -> Node3D:
	var container := Node3D.new()
	container.name = data.building_id if data and data.building_id != "" else "ModularBuilding"
	if data == null:
		return container

	var local_rng = rng
	if local_rng == null:
		local_rng = RandomNumberGenerator.new()
		local_rng.randomize()

	var clamped_floors = data.get_clamped_floor_count(floor_count)
	var y_offset = 0.0

	if data.ground_floor_mesh:
		y_offset = _add_mesh(container, data.ground_floor_mesh, y_offset, "GroundFloor")

	for i in range(maxi(0, clamped_floors - 1)):
		var middle = data.pick_middle_mesh(local_rng)
		if middle:
			y_offset = _add_mesh(container, middle, y_offset, "MiddleFloor_%d" % i)

	if data.roof_mesh:
		_add_mesh(container, data.roof_mesh, y_offset, "Roof")

	return container


func _add_mesh(parent: Node3D, mesh: Mesh, y_offset: float, node_name: String) -> float:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.mesh = mesh
	mesh_instance.position = Vector3(0.0, y_offset, 0.0)
	parent.add_child(mesh_instance)
	var height = _estimate_mesh_height(mesh)
	return y_offset + height


func _estimate_mesh_height(mesh: Mesh) -> float:
	if mesh == null:
		return 0.0
	var aabb = mesh.get_aabb()
	if aabb.size.y <= 0.01:
		return 3.0
	return aabb.size.y
