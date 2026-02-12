class_name BuildingRegistry
extends RefCounted
## Manages building data definitions loaded from resource files
##
## This is a standalone registry that loads and provides access to all BuildingData
## resources. It has no external dependencies and can be used independently.

## Signal emitted when registry finishes loading
signal registry_loaded(building_count: int)

## Building data registry: {id: BuildingData}
var _registry: Dictionary = {}

## Building scene template for instantiation
var _building_scene: PackedScene = null

## Shared cache to avoid reloading all .tres files for every registry instance.
static var _shared_registry: Dictionary = {}
static var _shared_building_scene: PackedScene = null
static var _shared_loaded: bool = false
static var _shared_load_cycles: int = 0
static var _shared_data_paths: Array[String] = []
static var _shared_path_scan_cycles: int = 0

## Data directory path
const DATA_PATH: String = "res://src/data/"
const BUILDING_SCENE_PATH: String = "res://src/entities/building.tscn"


func _init() -> void:
	_building_scene = _get_building_scene_cached()


## Load all building data from the data directory
func load_registry(force_reload: bool = false) -> void:
	if _shared_loaded and not force_reload:
		_registry = _shared_registry.duplicate()
		_building_scene = _get_building_scene_cached()
		registry_loaded.emit(_registry.size())
		return

	_registry.clear()

	for path in _get_building_resource_paths():
		var resource = load(path)
		# Only process BuildingData resources, skip other resource types
		if _is_building_data(resource):
			if validate_building_data(resource):
				_registry[resource.id] = resource
			else:
				push_warning("BuildingRegistry: Invalid building data in " + path.get_file())

	_shared_registry = _registry.duplicate()
	_shared_loaded = true
	_shared_load_cycles += 1
	_building_scene = _get_building_scene_cached()
	registry_loaded.emit(_registry.size())


## Check if a resource is a BuildingData
func _is_building_data(resource: Resource) -> bool:
	if not resource:
		return false
	if not resource.get_script():
		return false
	return resource.get_script().get_global_name() == "BuildingData"


## Validate building data has required fields
static func validate_building_data(data: Resource) -> bool:
	if data.get("id") == null or data.id == "":
		return false
	if not data.get("size") is Vector2i:
		return false
	if data.size.x <= 0 or data.size.y <= 0:
		return false
	if not data.get("build_cost") is int:
		return false
	if data.build_cost < 0:
		return false
	if data.get("display_name") == null:
		return false
	return true


## Returns BuildingData resource or null if not found
func get_building_data(id: String) -> Resource:
	_ensure_registry_loaded()
	return _registry.get(id, null)


## Returns full building registry dictionary (read-only copy)
func get_all_building_data() -> Dictionary:
	_ensure_registry_loaded()
	return _registry.duplicate()


## Returns array of BuildingData resources matching category
func get_buildings_by_category(category: String) -> Array[Resource]:
	_ensure_registry_loaded()
	var result: Array[Resource] = []
	for id in _registry:
		var data: Resource = _registry[id]
		if data.category == category:
			result.append(data)
	return result


## Returns array of BuildingData resources matching building type
func get_buildings_by_type(building_type: String) -> Array[Resource]:
	_ensure_registry_loaded()
	var result: Array[Resource] = []
	for id in _registry:
		var data: Resource = _registry[id]
		if data.building_type == building_type:
			result.append(data)
	return result


## Get all building IDs
func get_all_ids() -> Array[String]:
	_ensure_registry_loaded()
	var result: Array[String] = []
	for id in _registry:
		result.append(id)
	return result


## Check if a building ID exists in the registry
func has_building(id: String) -> bool:
	_ensure_registry_loaded()
	return _registry.has(id)


## Get the building scene for instantiation
func get_building_scene() -> PackedScene:
	_building_scene = _get_building_scene_cached()
	return _building_scene


## Get the number of registered buildings
func get_count() -> int:
	_ensure_registry_loaded()
	return _registry.size()


## Get registry statistics for debugging
func get_stats() -> Dictionary:
	_ensure_registry_loaded()
	var categories: Dictionary = {}
	var types: Dictionary = {}

	for id in _registry:
		var data: Resource = _registry[id]
		var cat: String = data.category if data.get("category") else "unknown"
		var btype: String = data.building_type if data.get("building_type") else "unknown"

		categories[cat] = categories.get(cat, 0) + 1
		types[btype] = types.get(btype, 0) + 1

	return {
		"total_buildings": _registry.size(),
		"categories": categories,
		"building_types": types
	}


func _ensure_registry_loaded() -> void:
	if _registry.is_empty():
		load_registry()


static func _get_building_scene_cached() -> PackedScene:
	if _shared_building_scene == null:
		_shared_building_scene = load(BUILDING_SCENE_PATH)
	return _shared_building_scene


static func get_shared_cache_stats() -> Dictionary:
	return {
		"loaded": _shared_loaded,
		"entry_count": _shared_registry.size(),
		"load_cycles": _shared_load_cycles,
		"has_scene": _shared_building_scene != null,
		"path_scan_cycles": _shared_path_scan_cycles,
		"path_count": _shared_data_paths.size()
	}


static func clear_shared_cache_for_tests() -> void:
	_shared_registry.clear()
	_shared_building_scene = null
	_shared_loaded = false
	_shared_load_cycles = 0
	_shared_data_paths.clear()
	_shared_path_scan_cycles = 0


static func _get_building_resource_paths() -> Array[String]:
	if not _shared_data_paths.is_empty():
		return _shared_data_paths

	var dir = DirAccess.open(DATA_PATH)
	if not dir:
		push_error("BuildingRegistry: Cannot open building data directory: " + DATA_PATH)
		return []

	var paths: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			paths.append(DATA_PATH + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	_shared_data_paths = paths
	_shared_path_scan_cycles += 1
	return _shared_data_paths
