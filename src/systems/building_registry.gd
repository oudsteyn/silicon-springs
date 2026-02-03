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

## Data directory path
const DATA_PATH: String = "res://src/data/"
const BUILDING_SCENE_PATH: String = "res://src/entities/building.tscn"


func _init() -> void:
	_building_scene = load(BUILDING_SCENE_PATH)


## Load all building data from the data directory
func load_registry() -> void:
	_registry.clear()

	var dir = DirAccess.open(DATA_PATH)
	if not dir:
		push_error("BuildingRegistry: Cannot open building data directory: " + DATA_PATH)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource = load(DATA_PATH + file_name)
			# Only process BuildingData resources, skip other resource types
			if _is_building_data(resource):
				if validate_building_data(resource):
					_registry[resource.id] = resource
				else:
					push_warning("BuildingRegistry: Invalid building data in " + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

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
	return _registry.get(id, null)


## Returns full building registry dictionary (read-only copy)
func get_all_building_data() -> Dictionary:
	return _registry.duplicate()


## Returns array of BuildingData resources matching category
func get_buildings_by_category(category: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for id in _registry:
		var data: Resource = _registry[id]
		if data.category == category:
			result.append(data)
	return result


## Returns array of BuildingData resources matching building type
func get_buildings_by_type(building_type: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for id in _registry:
		var data: Resource = _registry[id]
		if data.building_type == building_type:
			result.append(data)
	return result


## Get all building IDs
func get_all_ids() -> Array[String]:
	var result: Array[String] = []
	for id in _registry:
		result.append(id)
	return result


## Check if a building ID exists in the registry
func has_building(id: String) -> bool:
	return _registry.has(id)


## Get the building scene for instantiation
func get_building_scene() -> PackedScene:
	return _building_scene


## Get the number of registered buildings
func get_count() -> int:
	return _registry.size()


## Get registry statistics for debugging
func get_stats() -> Dictionary:
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
