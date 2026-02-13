extends Node
class_name World3DBridge
## Bridges 2D city simulation events into modular 3D road/building runtime content.

const ProceduralRoadSegmentScript = preload("res://src/systems/roads/procedural_road_segment.gd")
const ModularBuildingAssemblerScript = preload("res://src/world/buildings/modular_building_assembler.gd")
const RoadsideMultiMeshBatchScript = preload("res://src/world/roads/roadside_multimesh_batch.gd")
const ModularBuildingDataScript = preload("res://src/resources/modular_building_data.gd")
const RoadIntersectionLibraryScript = preload("res://src/systems/roads/road_intersection_library.gd")
const BuildingLodControllerScript = preload("res://src/world/buildings/building_lod_controller.gd")
const BuildingLodManagerScript = preload("res://src/world/buildings/building_lod_manager.gd")
const TextureArrayLibraryScript = preload("res://src/graphics/materials/building_texture_array_library.gd")

const ROAD_SHADER = preload("res://src/graphics/shaders/road_wet_asphalt.gdshader")
const GLASS_SHADER = preload("res://src/graphics/shaders/skyscraper_glass.gdshader")

var grid_system: Node = null
var camera_2d: Camera2D = null
var events_bus: Node = null
var modular_data_dir: String = "res://src/data/modular_buildings"
var rendering_enabled: bool = false

var world_root_3d: Node3D = null
var camera_3d: Camera3D = null
var sun_light: DirectionalLight3D = null
var road_root: Node3D = null
var building_root: Node3D = null
var roadside_batch: Node = null
var building_assembler: Node = null
var intersection_library: Resource = null
var lod_manager: RefCounted = BuildingLodManagerScript.new()
var texture_array_library: RefCounted = TextureArrayLibraryScript.new()
var texture_manifest: Dictionary = {}

var _road_segments: Dictionary = {}
var _building_nodes: Dictionary = {}
var _building_lod_controllers: Dictionary = {}
var _modular_cache: Dictionary = {}
var _road_cells: Dictionary = {}
var _road_decals: Dictionary = {}
var _junction_nodes: Dictionary = {}
var _junction_kinds: Dictionary = {}
var _last_lod_updates: int = 0


func _ready() -> void:
	set_process(rendering_enabled)
	_ensure_runtime_nodes()


func _ensure_runtime_nodes() -> void:
	if world_root_3d == null:
		world_root_3d = Node3D.new()
	if world_root_3d.get_parent() == null:
		world_root_3d.name = "World3DRoot"
		add_child(world_root_3d)
	if camera_3d == null:
		camera_3d = Camera3D.new()
	if camera_3d.get_parent() == null:
		camera_3d.name = "RoadsBuildingsCamera3D"
		camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera_3d.size = float(GridConstants.WORLD_HEIGHT)
		camera_3d.current = false
		world_root_3d.add_child(camera_3d)
	if sun_light == null:
		sun_light = DirectionalLight3D.new()
	if sun_light.get_parent() == null:
		sun_light.name = "RoadsBuildingsSun"
		sun_light.light_energy = 1.6
		sun_light.rotation_degrees = Vector3(-58.0, 42.0, 0.0)
		world_root_3d.add_child(sun_light)
	if road_root == null:
		road_root = Node3D.new()
	if road_root.get_parent() == null:
		road_root.name = "Roads3D"
		world_root_3d.add_child(road_root)
	if building_root == null:
		building_root = Node3D.new()
	if building_root.get_parent() == null:
		building_root.name = "Buildings3D"
		world_root_3d.add_child(building_root)
	if roadside_batch == null:
		roadside_batch = RoadsideMultiMeshBatchScript.new()
	if roadside_batch.get_parent() == null:
		roadside_batch.name = "RoadsideBatch3D"
		world_root_3d.add_child(roadside_batch)
	if building_assembler == null:
		building_assembler = ModularBuildingAssemblerScript.new()
	if intersection_library == null:
		intersection_library = RoadIntersectionLibraryScript.new()


func _process(_delta: float) -> void:
	_sync_camera_transform()
	if rendering_enabled and camera_3d and is_instance_valid(camera_3d):
		_last_lod_updates = lod_manager.update_budgeted(camera_3d.global_position)


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if camera_3d and is_instance_valid(camera_3d):
		camera_3d.current = false
	if events_bus and events_bus.has_signal("building_placed") and events_bus.building_placed.is_connected(_on_building_placed):
		events_bus.building_placed.disconnect(_on_building_placed)
	if events_bus and events_bus.has_signal("building_removed") and events_bus.building_removed.is_connected(_on_building_removed):
		events_bus.building_removed.disconnect(_on_building_removed)
	_free_if_orphan(camera_3d)
	_free_if_orphan(sun_light)
	_free_if_orphan(road_root)
	_free_if_orphan(building_root)
	_free_if_orphan(roadside_batch)
	_free_if_orphan(building_assembler)
	_free_if_orphan(world_root_3d)
	camera_3d = null
	sun_light = null
	road_root = null
	building_root = null
	roadside_batch = null
	building_assembler = null
	world_root_3d = null
	intersection_library = null
	_building_lod_controllers.clear()
	_road_cells.clear()
	_road_decals.clear()
	_junction_nodes.clear()
	_junction_kinds.clear()


func initialize(grid: Node, camera: Camera2D, bus: Node = null) -> void:
	_ensure_runtime_nodes()
	grid_system = grid
	camera_2d = camera
	events_bus = bus if bus != null else _resolve_events_bus()
	if texture_manifest.is_empty():
		texture_manifest = texture_array_library.build_manifest([
			{"building_id": "residential_low"},
			{"building_id": "commercial_low"},
			{"building_id": "industrial_low"}
		])
	_connect_events()
	rebuild_from_grid()


func get_road_segment_count() -> int:
	return _road_segments.size()


func get_modular_building_count() -> int:
	return _building_nodes.size()


func get_live_runtime_stats() -> Dictionary:
	return {
		"roads": _road_segments.size(),
		"modular_buildings": _building_nodes.size(),
		"road_decals": _count_decal_nodes(),
		"road_junctions": _junction_nodes.size(),
		"lod_updates_last_frame": _last_lod_updates,
		"texture_layers": int(texture_manifest.get("entries", []).size())
	}


func get_junction_kind(cell: Vector2i) -> String:
	return str(_junction_kinds.get(_cell_key(cell), ""))


func set_rendering_enabled(enabled: bool) -> void:
	rendering_enabled = enabled
	set_process(rendering_enabled)
	if camera_3d and is_instance_valid(camera_3d):
		camera_3d.current = rendering_enabled


func _resolve_events_bus() -> Node:
	if has_node("/root/Events"):
		return get_node("/root/Events")
	return null


func _connect_events() -> void:
	if events_bus == null:
		return
	if events_bus.has_signal("building_placed") and not events_bus.building_placed.is_connected(_on_building_placed):
		events_bus.building_placed.connect(_on_building_placed)
	if events_bus.has_signal("building_removed") and not events_bus.building_removed.is_connected(_on_building_removed):
		events_bus.building_removed.connect(_on_building_removed)


func _sync_camera_transform() -> void:
	if camera_2d == null or not is_instance_valid(camera_2d):
		return
	if camera_3d == null or not is_instance_valid(camera_3d):
		return
	# Keep a top-down orthographic camera aligned with the 2D camera.
	var pos = camera_2d.global_position
	var height = 900.0
	camera_3d.global_position = Vector3(pos.x, height, pos.y)
	camera_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	camera_3d.size = float(GridConstants.WORLD_HEIGHT) * camera_2d.zoom.y


func _free_if_orphan(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node.get_parent() == null:
		node.free()


func _on_building_placed(cell: Vector2i, building: Node2D) -> void:
	if not is_instance_valid(building):
		return
	var building_data = building.get("building_data")
	if building_data == null:
		return
	var building_type = str(building_data.get("building_type")) if building_data.get("building_type") != null else ""
	if GridConstants.is_road_type(building_type):
		_spawn_road_segment(cell)
	else:
		_spawn_modular_building(cell, building, building_data)


func _on_building_removed(cell: Vector2i, building: Node2D) -> void:
	var road_key = _cell_key(cell)
	if _road_segments.has(road_key):
		var road_segment = _road_segments[road_key]
		if is_instance_valid(road_segment):
			road_segment.queue_free()
		_road_segments.erase(road_key)
	_road_cells.erase(road_key)
	_clear_road_decals(cell)
	_refresh_intersections_around(cell)

	if building and is_instance_valid(building):
		var building_id = building.get_instance_id()
		if _building_nodes.has(building_id):
			var node = _building_nodes[building_id]
			if is_instance_valid(node):
				node.queue_free()
			_building_nodes.erase(building_id)
		if _building_lod_controllers.has(building_id):
			var ctrl = _building_lod_controllers[building_id]
			lod_manager.unregister_controller(ctrl)
			if is_instance_valid(ctrl):
				ctrl.queue_free()
			_building_lod_controllers.erase(building_id)


func _spawn_road_segment(cell: Vector2i) -> void:
	_ensure_runtime_nodes()
	var key = _cell_key(cell)
	if _road_segments.has(key):
		return
	var segment = ProceduralRoadSegmentScript.new()
	road_root.add_child(segment)
	segment.width_meters = float(GridConstants.CELL_SIZE) * 0.75
	var center = GridConstants.grid_to_world(cell) + Vector2(float(GridConstants.CELL_SIZE) * 0.5, float(GridConstants.CELL_SIZE) * 0.5)
	var half = float(GridConstants.CELL_SIZE) * 0.5
	var curve := Curve3D.new()
	curve.add_point(Vector3(center.x - half, 0.0, center.y))
	curve.add_point(Vector3(center.x + half, 0.0, center.y))
	segment.build_from_curve(curve)
	_assign_road_material(segment)
	_road_segments[key] = segment
	_road_cells[key] = true
	_spawn_road_decals(cell, segment)
	_refresh_intersections_around(cell)


func _spawn_modular_building(cell: Vector2i, building: Node2D, building_data: Resource) -> void:
	_ensure_runtime_nodes()
	var modular_data = _load_modular_data(str(building_data.get("id")))
	if modular_data == null:
		return
	var floors = int(building_data.get("floors")) if building_data.get("floors") != null else modular_data.min_floors
	var assembled = building_assembler.assemble(modular_data, floors)
	var world_pos = GridConstants.grid_to_world(cell) + Vector2(float(GridConstants.CELL_SIZE) * 0.5, float(GridConstants.CELL_SIZE) * 0.5)
	assembled.position = Vector3(world_pos.x, 0.0, world_pos.y)
	building_root.add_child(assembled)
	_building_nodes[building.get_instance_id()] = assembled
	_assign_building_materials(assembled, modular_data)
	_register_lod_controller(building.get_instance_id(), assembled, modular_data)


func _load_modular_data(building_id: String) -> Resource:
	if building_id == "":
		return null
	if _modular_cache.has(building_id):
		return _modular_cache[building_id]
	var path = "%s/%s.tres" % [modular_data_dir, building_id]
	if not ResourceLoader.exists(path):
		_modular_cache[building_id] = null
		return null
	var loaded = load(path)
	if loaded is Resource and loaded.get_script() == ModularBuildingDataScript:
		var layer = int(texture_manifest.get("layers", {}).get(building_id, 0))
		loaded.set("facade_texture_layer", layer)
		loaded.set("emission_texture_layer", layer)
		_modular_cache[building_id] = loaded
		return loaded
	_modular_cache[building_id] = null
	return null


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]


func _assign_road_material(segment: Node) -> void:
	if segment == null or not is_instance_valid(segment):
		return
	var mesh_instance = segment.get("mesh_instance")
	if mesh_instance == null or not (mesh_instance is MeshInstance3D):
		return
	var mat := ShaderMaterial.new()
	mat.shader = ROAD_SHADER
	mat.set_shader_parameter("wetness", 0.0)
	(mesh_instance as MeshInstance3D).material_override = mat


func _spawn_road_decals(cell: Vector2i, segment: Node) -> void:
	_clear_road_decals(cell)
	if segment == null or not is_instance_valid(segment):
		return
	if not segment.has_method("get_decal_mark_positions"):
		return
	var decals: Array = []
	var anchors: PackedVector3Array = segment.get_decal_mark_positions()
	for anchor in anchors:
		var decal := Decal.new()
		decal.name = "RoadMarkDecal"
		decal.size = Vector3(float(GridConstants.CELL_SIZE) * 0.8, 1.0, 1.2)
		decal.position = anchor + Vector3(0.0, 0.02, 0.0)
		segment.add_child(decal)
		decals.append(decal)
	_road_decals[_cell_key(cell)] = decals


func _clear_road_decals(cell: Vector2i) -> void:
	var key = _cell_key(cell)
	if not _road_decals.has(key):
		return
	for decal in _road_decals[key]:
		if is_instance_valid(decal):
			decal.queue_free()
	_road_decals.erase(key)


func _refresh_intersections_around(cell: Vector2i) -> void:
	var candidates = [cell, cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]
	for c in candidates:
		_refresh_intersection(c)


func _refresh_intersection(cell: Vector2i) -> void:
	var key = _cell_key(cell)
	if not _road_cells.has(key):
		if _junction_nodes.has(key):
			var old = _junction_nodes[key]
			if is_instance_valid(old):
				old.queue_free()
			_junction_nodes.erase(key)
			_junction_kinds.erase(key)
		return
	var north = _road_cells.has(_cell_key(cell + Vector2i.UP))
	var east = _road_cells.has(_cell_key(cell + Vector2i.RIGHT))
	var south = _road_cells.has(_cell_key(cell + Vector2i.DOWN))
	var west = _road_cells.has(_cell_key(cell + Vector2i.LEFT))
	var neighbors = int(north) + int(east) + int(south) + int(west)
	var kind = _classify_junction_kind(north, east, south, west)
	if neighbors < 2:
		if _junction_nodes.has(key):
			var existing = _junction_nodes[key]
			if is_instance_valid(existing):
				existing.queue_free()
			_junction_nodes.erase(key)
			_junction_kinds.erase(key)
		return
	if kind == "":
		if _junction_nodes.has(key):
			var old_kind = _junction_nodes[key]
			if is_instance_valid(old_kind):
				old_kind.queue_free()
			_junction_nodes.erase(key)
			_junction_kinds.erase(key)
		return
	if _junction_nodes.has(key):
		if _junction_kinds.get(key, "") == kind:
			return
		var prev = _junction_nodes[key]
		if is_instance_valid(prev):
			prev.queue_free()
		_junction_nodes.erase(key)
		_junction_kinds.erase(key)

	var instance: Node3D = null
	if intersection_library and intersection_library.has_method("get_junction"):
		var scene = intersection_library.get_junction(kind, 2)
		if scene and scene is PackedScene:
			instance = scene.instantiate()
	if instance == null:
		instance = MeshInstance3D.new()
		var fallback := BoxMesh.new()
		fallback.size = Vector3(float(GridConstants.CELL_SIZE) * 0.9, 0.2, float(GridConstants.CELL_SIZE) * 0.9)
		(instance as MeshInstance3D).mesh = fallback
		_assign_mesh_road_material(instance as MeshInstance3D)

	var world = GridConstants.grid_to_world(cell) + Vector2(float(GridConstants.CELL_SIZE) * 0.5, float(GridConstants.CELL_SIZE) * 0.5)
	instance.position = Vector3(world.x, 0.01, world.y)
	road_root.add_child(instance)
	_junction_nodes[key] = instance
	_junction_kinds[key] = kind


func _assign_mesh_road_material(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance == null:
		return
	var mat := ShaderMaterial.new()
	mat.shader = ROAD_SHADER
	mesh_instance.material_override = mat


func _assign_building_materials(root: Node3D, modular_data: Resource) -> void:
	var emissive_layer = int(modular_data.get("emission_texture_layer")) if modular_data else 0
	var facade_layer = int(modular_data.get("facade_texture_layer")) if modular_data else 0
	var layer_value = float(emissive_layer + facade_layer)
	for node in _find_mesh_instances(root):
		var mat := ShaderMaterial.new()
		mat.shader = GLASS_SHADER
		mat.set_shader_parameter("city_time_norm", 0.5)
		mat.set_shader_parameter("night_emission_boost", 2.0 + layer_value * 0.01)
		node.material_override = mat


func _find_mesh_instances(root: Node) -> Array:
	var result: Array = []
	if root == null:
		return result
	if root is MeshInstance3D:
		result.append(root)
	for child in root.get_children():
		result.append_array(_find_mesh_instances(child))
	return result


func _register_lod_controller(building_id: int, assembled: Node3D, modular_data: Resource) -> void:
	if assembled == null or modular_data == null:
		return
	var ctrl = BuildingLodControllerScript.new()
	ctrl.data = modular_data
	assembled.add_child(ctrl)
	var mesh_node = _find_first_mesh(assembled)
	if mesh_node:
		ctrl.target_mesh_instance_path = ctrl.get_path_to(mesh_node)
	lod_manager.register_controller(ctrl)
	_building_lod_controllers[building_id] = ctrl


func _find_first_mesh(root: Node) -> MeshInstance3D:
	if root == null:
		return null
	if root is MeshInstance3D:
		return root as MeshInstance3D
	for child in root.get_children():
		var found = _find_first_mesh(child)
		if found:
			return found
	return null


func _count_decal_nodes() -> int:
	var count = 0
	for key in _road_decals.keys():
		for decal in _road_decals[key]:
			if is_instance_valid(decal):
				count += 1
	return count


func rebuild_from_grid() -> void:
	_clear_runtime_state()
	if grid_system == null or not grid_system.has_method("get_all_unique_buildings"):
		return
	var placed = grid_system.get_all_unique_buildings()
	if not (placed is Array):
		return
	for building in placed:
		if building == null or not is_instance_valid(building):
			continue
		var cell = building.get("grid_cell")
		var data = building.get("building_data")
		if cell is Vector2i and data is Resource:
			_on_building_placed(cell, building)


func _clear_runtime_state() -> void:
	for key in _road_segments.keys():
		var segment = _road_segments[key]
		if is_instance_valid(segment):
			segment.queue_free()
	_road_segments.clear()
	_road_cells.clear()
	for key in _road_decals.keys():
		for decal in _road_decals[key]:
			if is_instance_valid(decal):
				decal.queue_free()
	_road_decals.clear()
	for key in _junction_nodes.keys():
		var node = _junction_nodes[key]
		if is_instance_valid(node):
			node.queue_free()
	_junction_nodes.clear()
	_junction_kinds.clear()
	for id in _building_nodes.keys():
		var bnode = _building_nodes[id]
		if is_instance_valid(bnode):
			bnode.queue_free()
	_building_nodes.clear()
	for id in _building_lod_controllers.keys():
		var ctrl = _building_lod_controllers[id]
		lod_manager.unregister_controller(ctrl)
		if is_instance_valid(ctrl):
			ctrl.queue_free()
	_building_lod_controllers.clear()


func _classify_junction_kind(north: bool, east: bool, south: bool, west: bool) -> String:
	var degree = int(north) + int(east) + int(south) + int(west)
	if degree < 2:
		return ""
	if degree == 2:
		var opposite = (north and south) or (east and west)
		if opposite:
			return ""
		return "corner"
	if degree == 3:
		return "t"
	return "x"
