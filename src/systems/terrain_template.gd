extends RefCounted
class_name TerrainTemplate
## Save/load system for terrain templates

# Template data
var name: String = ""
var biome_id: String = ""
var seed_value: int = 0
var created_date: String = ""
var grid_size: Vector2i = Vector2i(128, 128)
var elevation: Dictionary = {}  # Vector2i -> int
var water: Dictionary = {}      # Vector2i -> int (WaterType)
var features: Dictionary = {}   # Vector2i -> int (FeatureType)

# Template directories
const TEMPLATE_DIR = "user://terrain_templates/"
const BUNDLED_TEMPLATE_DIR = "res://data/terrain_templates/"
const FILE_EXTENSION = ".terrain"


static func get_template_directory() -> String:
	return TEMPLATE_DIR


## Save template to file
static func save_to_file(template: TerrainTemplate, filename: String) -> bool:
	# Ensure directory exists
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("terrain_templates"):
			dir.make_dir("terrain_templates")

	# Build save data
	var data = {
		"name": template.name,
		"biome_id": template.biome_id,
		"seed": template.seed_value,
		"created": template.created_date,
		"grid_size": [template.grid_size.x, template.grid_size.y],
		"elevation": _dict_to_json_safe(template.elevation),
		"water": _dict_to_json_safe(template.water),
		"features": _dict_to_json_safe(template.features)
	}

	# Sanitize filename
	var safe_filename = filename.replace(" ", "_").replace("/", "_").replace("\\", "_")
	if not safe_filename.ends_with(FILE_EXTENSION):
		safe_filename += FILE_EXTENSION

	var path = TEMPLATE_DIR + safe_filename

	# Write to file
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open file for writing: " + path)
		return false

	var json_string = JSON.stringify(data, "\t")
	file.store_string(json_string)
	file.close()

	return true


## Load template from file
static func load_from_file(path: String) -> TerrainTemplate:
	if not FileAccess.file_exists(path):
		push_error("Template file not found: " + path)
		return null

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open template file: " + path)
		return null

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse template JSON: " + json.get_error_message())
		return null

	var data = json.get_data()
	if not data is Dictionary:
		push_error("Invalid template data format")
		return null

	# Create template from data
	var template = TerrainTemplate.new()
	template.name = data.get("name", "Unnamed")
	template.biome_id = data.get("biome_id", "")
	template.seed_value = data.get("seed", 0)
	template.created_date = data.get("created", "")

	var size = data.get("grid_size", [128, 128])
	template.grid_size = Vector2i(size[0], size[1])

	template.elevation = _json_safe_to_dict(data.get("elevation", {}))
	template.water = _json_safe_to_dict(data.get("water", {}))
	template.features = _json_safe_to_dict(data.get("features", {}))

	return template


## List all saved templates (user and bundled)
static func list_saved_templates() -> Array[Dictionary]:
	var templates: Array[Dictionary] = []

	# List user templates
	var user_dir = DirAccess.open(TEMPLATE_DIR)
	if user_dir:
		user_dir.list_dir_begin()
		var file_name = user_dir.get_next()
		while file_name != "":
			if not user_dir.current_is_dir() and file_name.ends_with(FILE_EXTENSION):
				var full_path = TEMPLATE_DIR + file_name
				var info = _get_template_info(full_path)
				if info:
					info["bundled"] = false
					templates.append(info)
			file_name = user_dir.get_next()
		user_dir.list_dir_end()

	# List bundled templates
	var bundled_dir = DirAccess.open(BUNDLED_TEMPLATE_DIR)
	if bundled_dir:
		bundled_dir.list_dir_begin()
		var file_name = bundled_dir.get_next()
		while file_name != "":
			if not bundled_dir.current_is_dir() and file_name.ends_with(FILE_EXTENSION):
				var full_path = BUNDLED_TEMPLATE_DIR + file_name
				var info = _get_template_info(full_path)
				if info:
					info["bundled"] = true
					templates.append(info)
			file_name = bundled_dir.get_next()
		bundled_dir.list_dir_end()

	# Sort: user templates first (newest first), then bundled (alphabetical)
	templates.sort_custom(func(a, b):
		if a.bundled != b.bundled:
			return not a.bundled  # User templates first
		if a.bundled:
			return a.name < b.name  # Bundled: alphabetical
		return a.created > b.created  # User: newest first
	)

	return templates


## Delete a template file
static func delete_template(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false

	var dir = DirAccess.open(TEMPLATE_DIR)
	if dir:
		return dir.remove(path.get_file()) == OK
	return false


## Get template info without loading full data
static func _get_template_info(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_string) != OK:
		return {}

	var data = json.get_data()
	if not data is Dictionary:
		return {}

	return {
		"path": path,
		"name": data.get("name", "Unnamed"),
		"biome_id": data.get("biome_id", ""),
		"created": data.get("created", ""),
		"seed": data.get("seed", 0)
	}


## Create template from current terrain system state
static func create_from_terrain(terrain_system: TerrainSystem, template_name: String) -> TerrainTemplate:
	var template = TerrainTemplate.new()
	template.name = template_name
	template.created_date = Time.get_datetime_string_from_system()
	template.seed_value = 0  # Will be set by caller if known
	template.grid_size = Vector2i(GridConstants.GRID_WIDTH, GridConstants.GRID_HEIGHT)

	# Copy terrain data
	template.elevation = terrain_system.elevation.duplicate()
	template.water = terrain_system.water.duplicate()
	template.features = terrain_system.features.duplicate()

	# Get biome ID if set
	if terrain_system.current_biome and terrain_system.current_biome.get("id"):
		template.biome_id = terrain_system.current_biome.id

	return template


## Apply template to terrain system
static func apply_to_terrain(template: TerrainTemplate, terrain_system: TerrainSystem) -> void:
	# If template has minimal/no terrain data but has biome+seed, regenerate
	if template.elevation.size() == 0 and template.biome_id != "":
		# Load biome and regenerate terrain
		var biome_path = "res://src/data/biomes/%s.tres" % template.biome_id
		var biome = null
		if ResourceLoader.exists(biome_path):
			biome = load(biome_path)
		terrain_system.generate_initial_terrain(template.seed_value, biome)
		return

	# Clear and load elevation
	terrain_system.elevation.clear()
	for key in template.elevation:
		terrain_system.elevation[key] = template.elevation[key]

	# Clear and load water
	terrain_system.water.clear()
	for key in template.water:
		terrain_system.water[key] = template.water[key]

	# Clear and load features
	terrain_system.features.clear()
	for key in template.features:
		terrain_system.features[key] = template.features[key]

	# Emit terrain changed for all cells
	var all_cells: Array = []
	for cell in terrain_system.elevation.keys():
		all_cells.append(cell)
	Events.terrain_changed.emit(all_cells)


## Convert Dictionary with Vector2i keys to JSON-safe format
static func _dict_to_json_safe(d: Dictionary) -> Dictionary:
	var result = {}
	for key in d:
		if key is Vector2i:
			result["%d,%d" % [key.x, key.y]] = d[key]
		else:
			result[str(key)] = d[key]
	return result


## Convert JSON-safe Dictionary back to Vector2i keys
static func _json_safe_to_dict(d: Dictionary) -> Dictionary:
	var result = {}
	for key in d:
		if typeof(key) == TYPE_STRING and "," in key:
			var parts = key.split(",")
			if parts.size() == 2:
				var vec = Vector2i(int(parts[0]), int(parts[1]))
				result[vec] = d[key]
		else:
			result[key] = d[key]
	return result


## Generate a unique filename for a new template
static func generate_filename(template_name: String) -> String:
	var base = template_name.to_lower().replace(" ", "_")
	var timestamp = Time.get_unix_time_from_system()
	return "%s_%d%s" % [base, timestamp, FILE_EXTENSION]
