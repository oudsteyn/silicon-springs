extends Node
class_name World3DBridge
## Bridges 2D city simulation events into modular 3D road/building runtime content.

const ProceduralRoadSegmentScript = preload("res://src/systems/roads/procedural_road_segment.gd")
const ModularBuildingAssemblerScript = preload("res://src/world/buildings/modular_building_assembler.gd")
const RoadsideMultiMeshBatchScript = preload("res://src/world/roads/roadside_multimesh_batch.gd")
const ModularBuildingDataScript = preload("res://src/resources/modular_building_data.gd")

var grid_system: Node = null
var camera_2d: Camera2D = null
var events_bus: Node = null
var modular_data_dir: String = "res://src/data/modular_buildings"
var rendering_enabled: bool = false

var world_root_3d: Node3D = Node3D.new()
var camera_3d: Camera3D = Camera3D.new()
var sun_light: DirectionalLight3D = DirectionalLight3D.new()
var road_root: Node3D = Node3D.new()
var building_root: Node3D = Node3D.new()
var roadside_batch: Node = RoadsideMultiMeshBatchScript.new()
var building_assembler: Node = ModularBuildingAssemblerScript.new()

var _road_segments: Dictionary = {}
var _building_nodes: Dictionary = {}
var _modular_cache: Dictionary = {}


func _ready() -> void:
	set_process(rendering_enabled)
	if world_root_3d.get_parent() == null:
		world_root_3d.name = "World3DRoot"
		add_child(world_root_3d)
	if camera_3d.get_parent() == null:
		camera_3d.name = "RoadsBuildingsCamera3D"
		camera_3d.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera_3d.size = float(GridConstants.WORLD_HEIGHT)
		camera_3d.current = false
		world_root_3d.add_child(camera_3d)
	if sun_light.get_parent() == null:
		sun_light.name = "RoadsBuildingsSun"
		sun_light.light_energy = 1.6
		sun_light.rotation_degrees = Vector3(-58.0, 42.0, 0.0)
		world_root_3d.add_child(sun_light)
	if road_root.get_parent() == null:
		road_root.name = "Roads3D"
		world_root_3d.add_child(road_root)
	if building_root.get_parent() == null:
		building_root.name = "Buildings3D"
		world_root_3d.add_child(building_root)
	if roadside_batch.get_parent() == null:
		roadside_batch.name = "RoadsideBatch3D"
		world_root_3d.add_child(roadside_batch)


func _process(_delta: float) -> void:
	_sync_camera_transform()


func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	if camera_3d and is_instance_valid(camera_3d):
		camera_3d.current = false


func initialize(grid: Node, camera: Camera2D, bus: Node = null) -> void:
	grid_system = grid
	camera_2d = camera
	events_bus = bus if bus != null else _resolve_events_bus()
	_connect_events()


func get_road_segment_count() -> int:
	return _road_segments.size()


func get_modular_building_count() -> int:
	return _building_nodes.size()


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
	# Keep a top-down orthographic camera aligned with the 2D camera.
	var pos = camera_2d.global_position
	var height = 900.0
	camera_3d.global_position = Vector3(pos.x, height, pos.y)
	camera_3d.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	camera_3d.size = float(GridConstants.WORLD_HEIGHT) * camera_2d.zoom.y


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

	if building and is_instance_valid(building):
		var building_id = building.get_instance_id()
		if _building_nodes.has(building_id):
			var node = _building_nodes[building_id]
			if is_instance_valid(node):
				node.queue_free()
			_building_nodes.erase(building_id)


func _spawn_road_segment(cell: Vector2i) -> void:
	var key = _cell_key(cell)
	if _road_segments.has(key):
		return
	var segment = ProceduralRoadSegmentScript.new()
	road_root.add_child(segment)
	var center = GridConstants.grid_to_world(cell) + Vector2(float(GridConstants.CELL_SIZE) * 0.5, float(GridConstants.CELL_SIZE) * 0.5)
	var half = float(GridConstants.CELL_SIZE) * 0.5
	var curve := Curve3D.new()
	curve.add_point(Vector3(center.x - half, 0.0, center.y))
	curve.add_point(Vector3(center.x + half, 0.0, center.y))
	segment.build_from_curve(curve)
	_road_segments[key] = segment


func _spawn_modular_building(cell: Vector2i, building: Node2D, building_data: Resource) -> void:
	var modular_data = _load_modular_data(str(building_data.get("id")))
	if modular_data == null:
		return
	var floors = int(building_data.get("floors")) if building_data.get("floors") != null else modular_data.min_floors
	var assembled = building_assembler.assemble(modular_data, floors)
	var world_pos = GridConstants.grid_to_world(cell) + Vector2(float(GridConstants.CELL_SIZE) * 0.5, float(GridConstants.CELL_SIZE) * 0.5)
	assembled.position = Vector3(world_pos.x, 0.0, world_pos.y)
	building_root.add_child(assembled)
	_building_nodes[building.get_instance_id()] = assembled


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
		_modular_cache[building_id] = loaded
		return loaded
	_modular_cache[building_id] = null
	return null


func _cell_key(cell: Vector2i) -> String:
	return "%d:%d" % [cell.x, cell.y]
