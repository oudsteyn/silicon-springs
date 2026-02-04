extends Node
class_name SaveSystem
## Handles saving and loading game state

const SaveBuildingCodec = preload("res://src/systems/save_building_codec.gd")

signal save_completed(success: bool, message: String)
signal load_completed(success: bool, message: String)

const SAVE_DIR = "user://saves/"
const SAVE_EXTENSION = ".dccity"
const SAVE_VERSION = 3  # Bumped for power/water/pollution system state

var grid_system: Node = null
var terrain_system: Node = null
var weather_system: Node = null
var power_system: Node = null
var water_system: Node = null
var pollution_system: Node = null
var infrastructure_age_system: Node = null


func _ready() -> void:
	# Ensure save directory exists
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _get_events() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return loop.root.get_node_or_null("Events")
	return null


func set_grid_system(system: Node) -> void:
	grid_system = system


func set_terrain_system(system: Node) -> void:
	terrain_system = system


func set_weather_system(system: Node) -> void:
	weather_system = system


func set_power_system(system: Node) -> void:
	power_system = system


func set_water_system(system: Node) -> void:
	water_system = system


func set_pollution_system(system: Node) -> void:
	pollution_system = system


func set_infrastructure_age_system(system: Node) -> void:
	infrastructure_age_system = system


func get_save_files() -> Array:
	var files: Array = []
	var dir = DirAccess.open(SAVE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(SAVE_EXTENSION):
				var full_path = SAVE_DIR + file_name
				var info = _get_save_info(full_path)
				if info:
					files.append(info)
			file_name = dir.get_next()
		dir.list_dir_end()

	# Sort by modification time (newest first)
	files.sort_custom(func(a, b): return a.modified > b.modified)
	return files


func _get_save_info(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		return {}

	var data = json.get_data()
	if not data is Dictionary:
		return {}

	return {
		"path": path,
		"name": data.get("city_name", "Unknown"),
		"population": data.get("population", 0),
		"date": data.get("date_string", "Unknown"),
		"modified": FileAccess.get_modified_time(path)
	}


func save_game(save_name: String) -> bool:
	if not grid_system:
		save_completed.emit(false, "Grid system not available")
		return false

	var save_data = _create_save_data(save_name)
	var file_path = SAVE_DIR + _sanitize_filename(save_name) + SAVE_EXTENSION

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		save_completed.emit(false, "Could not create save file")
		return false

	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()

	save_completed.emit(true, "Game saved successfully!")
	var events = _get_events()
	if events:
		events.simulation_event.emit("game_saved", {"name": save_name})
	return true


func load_game(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		load_completed.emit(false, "Could not open save file")
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		load_completed.emit(false, "Invalid save file format")
		return false

	var data = json.get_data()
	if not data is Dictionary:
		load_completed.emit(false, "Invalid save data")
		return false

	# Check version compatibility
	var version = data.get("version", 0)
	if version > SAVE_VERSION:
		load_completed.emit(false, "Save file is from a newer game version")
		return false

	# Apply save data
	if not _apply_save_data(data):
		load_completed.emit(false, "Failed to load save data")
		return false

	load_completed.emit(true, "Game loaded successfully!")
	var events = _get_events()
	if events:
		events.simulation_event.emit("game_loaded", {"name": data.get("city_name", "City")})
	return true


func _create_save_data(save_name: String) -> Dictionary:
	var data = {
		"version": SAVE_VERSION,
		"city_name": save_name,
		"date_string": GameState.get_date_string(),

		# Game State
		"budget": GameState.budget,
		"population": GameState.population,
		"educated_population": GameState.educated_population,
		"happiness": GameState.happiness,
		"current_month": GameState.current_month,
		"current_year": GameState.current_year,
		"total_months": GameState.total_months,
		"score": GameState.score,
		"tax_rate": GameState.tax_rate,
		"residential_zones": GameState.residential_zones,
		"commercial_zones": GameState.commercial_zones,
		"industrial_zones": GameState.industrial_zones,
		"months_in_debt": GameState.months_in_debt,
		"data_centers_by_tier": GameState.data_centers_by_tier.duplicate(),
		"unlocked_landmarks": GameState.unlocked_landmarks.duplicate(),

		# Ordinances
		"active_ordinances": Ordinances.active_ordinances.keys(),

		# Buildings
		"buildings": _serialize_buildings(),

		# Biome
		"biome_id": GameState.current_biome_id,

		# Terrain
		"terrain": _serialize_terrain(),

		# Weather
		"weather": _serialize_weather(),

		# Power system (storm outages, storage, grid stability)
		"power_system": _serialize_power_system(),

		# Water system (pressure state)
		"water_system": _serialize_water_system(),

		# Pollution system (AQI, wildfires, inversions)
		"pollution_system": _serialize_pollution_system(),

		# Infrastructure aging
		"infrastructure_age": _serialize_infrastructure_age()
	}

	return data


func _serialize_terrain() -> Dictionary:
	if not terrain_system or not terrain_system.has_method("get_terrain_data"):
		return {}
	return terrain_system.get_terrain_data()


func _serialize_weather() -> Dictionary:
	if not weather_system or not weather_system.has_method("get_save_data"):
		return {}
	return weather_system.get_save_data()


func _serialize_power_system() -> Dictionary:
	if not power_system:
		return {}

	# Serialize storm outage state
	var storm_damaged_cells_data: Dictionary = {}
	if power_system.get("storm_damaged_cells"):
		for cell in power_system.storm_damaged_cells:
			var key = "%d,%d" % [cell.x, cell.y]
			storm_damaged_cells_data[key] = power_system.storm_damaged_cells[cell]

	# Serialize storage state
	var storage_data: Dictionary = {}
	if power_system.get("storage_state"):
		for id in power_system.storage_state:
			storage_data[str(id)] = power_system.storage_state[id].duplicate()

	return {
		"storm_outage_active": power_system.storm_outage_active if power_system.get("storm_outage_active") != null else false,
		"storm_outage_severity": power_system.storm_outage_severity if power_system.get("storm_outage_severity") != null else 0.0,
		"storm_damaged_cells": storm_damaged_cells_data,
		"storm_repair_rate": power_system.storm_repair_rate if power_system.get("storm_repair_rate") != null else 0.0,
		"outage_restoration_progress": power_system.outage_restoration_progress if power_system.get("outage_restoration_progress") != null else 0.0,
		"grid_stability": power_system.grid_stability if power_system.get("grid_stability") != null else 1.0,
		"is_brownout": power_system.is_brownout if power_system.get("is_brownout") != null else false,
		"brownout_severity": power_system.brownout_severity if power_system.get("brownout_severity") != null else 0.0,
		"storage_state": storage_data,
		"total_stored_energy": power_system.total_stored_energy if power_system.get("total_stored_energy") != null else 0.0
	}


func _serialize_water_system() -> Dictionary:
	if not water_system:
		return {}

	return {
		"system_pressure": water_system.system_pressure if water_system.get("system_pressure") != null else 1.0,
		"pressure_ratio": water_system.pressure_ratio if water_system.get("pressure_ratio") != null else 1.0,
		"pressure_boost": water_system.pressure_boost if water_system.get("pressure_boost") != null else 0.0
	}


func _serialize_pollution_system() -> Dictionary:
	if not pollution_system or not pollution_system.has_method("get_save_data"):
		return {}
	return pollution_system.get_save_data()


func _serialize_infrastructure_age() -> Dictionary:
	if not infrastructure_age_system:
		return {}

	if infrastructure_age_system.has_method("get_save_data"):
		return infrastructure_age_system.get_save_data()

	# Manual serialization if no get_save_data method
	var data: Dictionary = {}
	if infrastructure_age_system.get("infrastructure_age"):
		for id in infrastructure_age_system.infrastructure_age:
			data[str(id)] = infrastructure_age_system.infrastructure_age[id].duplicate()

	return {"infrastructure_age": data}


func _serialize_buildings() -> Array:
	return SaveBuildingCodec.serialize_buildings(grid_system)


func _apply_save_data(data: Dictionary) -> bool:
	# Reset game state
	GameState.reset_game()

	# Apply game state
	GameState.budget = data.get("budget", GameState.STARTING_BUDGET)
	GameState.population = data.get("population", 0)
	GameState.educated_population = data.get("educated_population", 0)
	GameState.happiness = data.get("happiness", 0.5)
	GameState.current_month = data.get("current_month", 1)
	GameState.current_year = data.get("current_year", 2024)
	GameState.total_months = data.get("total_months", 0)
	GameState.score = data.get("score", 0)
	GameState.tax_rate = data.get("tax_rate", 0.1)
	GameState.residential_zones = data.get("residential_zones", 0)
	GameState.commercial_zones = data.get("commercial_zones", 0)
	GameState.industrial_zones = data.get("industrial_zones", 0)
	GameState.months_in_debt = data.get("months_in_debt", 0)

	var dc_tiers = data.get("data_centers_by_tier", {})
	for tier in dc_tiers:
		GameState.data_centers_by_tier[int(tier)] = dc_tiers[tier]

	var landmarks = data.get("unlocked_landmarks", {})
	for landmark in landmarks:
		GameState.unlocked_landmarks[landmark] = true

	# Apply ordinances
	Ordinances.active_ordinances.clear()
	var active_ords = data.get("active_ordinances", [])
	for ord_id in active_ords:
		Ordinances.active_ordinances[ord_id] = true

	# Restore biome
	var biome_id = data.get("biome_id", "")
	if biome_id != "":
		_restore_biome(biome_id)

	# Restore terrain
	var terrain_data = data.get("terrain", {})
	if terrain_data.size() > 0:
		_restore_terrain(terrain_data)

	# Restore weather
	var weather_data = data.get("weather", {})
	if weather_data.size() > 0:
		_restore_weather(weather_data)

	# Restore power system state (storm outages, storage)
	var power_data = data.get("power_system", {})
	if power_data.size() > 0:
		_restore_power_system(power_data)

	# Restore water system state (pressure)
	var water_data = data.get("water_system", {})
	if water_data.size() > 0:
		_restore_water_system(water_data)

	# Restore pollution system state (AQI, wildfires)
	var pollution_data = data.get("pollution_system", {})
	if pollution_data.size() > 0:
		_restore_pollution_system(pollution_data)

	# Restore infrastructure age
	var infra_data = data.get("infrastructure_age", {})
	if infra_data.size() > 0:
		_restore_infrastructure_age(infra_data)

	# Clear existing buildings
	_clear_all_buildings()

	# Rebuild buildings
	var buildings = data.get("buildings", [])
	var road_entries: Array = []
	var utility_entries: Array = []
	var other_entries: Array = []

	for building_entry in buildings:
		var building_id = building_entry.get("id", "")
		var building_data = grid_system.get_building_data(building_id)
		if not building_data:
			continue

		var building_type = building_data.building_type if building_data.get("building_type") else ""
		if GridConstants.is_road_type(building_type):
			road_entries.append(building_entry)
		elif GridConstants.is_utility_type(building_type):
			utility_entries.append(building_entry)
		else:
			other_entries.append(building_entry)

	# Load roads first, then utilities (including overlays), then everything else
	for building_entry in road_entries:
		_restore_building(building_entry)
	for building_entry in utility_entries:
		_restore_building(building_entry)
	for building_entry in other_entries:
		_restore_building(building_entry)

	return true


func _restore_biome(biome_id: String) -> void:
	# Load biome from resources
	var biome_path = "res://src/data/biomes/%s.tres" % biome_id
	if ResourceLoader.exists(biome_path):
		var biome = load(biome_path)
		if biome:
			GameState.set_biome(biome)
			if weather_system and weather_system.has_method("set_biome"):
				weather_system.set_biome(biome)


func _restore_terrain(data: Dictionary) -> void:
	if terrain_system and terrain_system.has_method("load_terrain_data"):
		terrain_system.load_terrain_data(data)


func _restore_weather(data: Dictionary) -> void:
	if weather_system and weather_system.has_method("load_save_data"):
		weather_system.load_save_data(data)


func _restore_power_system(data: Dictionary) -> void:
	if not power_system:
		return

	# Restore storm outage state
	power_system.storm_outage_active = data.get("storm_outage_active", false)
	power_system.storm_outage_severity = data.get("storm_outage_severity", 0.0)
	power_system.storm_repair_rate = data.get("storm_repair_rate", 0.0)
	power_system.outage_restoration_progress = data.get("outage_restoration_progress", 0.0)

	# Restore damaged cells
	power_system.storm_damaged_cells.clear()
	var damaged_cells_data = data.get("storm_damaged_cells", {})
	for key in damaged_cells_data:
		var parts = key.split(",")
		if parts.size() == 2:
			var cell = Vector2i(int(parts[0]), int(parts[1]))
			power_system.storm_damaged_cells[cell] = damaged_cells_data[key]

	# Restore grid stability
	power_system.grid_stability = data.get("grid_stability", 1.0)
	power_system.is_brownout = data.get("is_brownout", false)
	power_system.brownout_severity = data.get("brownout_severity", 0.0)

	# Restore storage state
	power_system.total_stored_energy = data.get("total_stored_energy", 0.0)
	var storage_data = data.get("storage_state", {})
	for id_str in storage_data:
		var id = int(id_str)
		if power_system.storage_state.has(id):
			var saved = storage_data[id_str]
			power_system.storage_state[id].charge = saved.get("charge", 0.0)
			power_system.storage_state[id].cycles = saved.get("cycles", 0)


func _restore_water_system(data: Dictionary) -> void:
	if not water_system:
		return

	water_system.system_pressure = data.get("system_pressure", 1.0)
	water_system.pressure_ratio = data.get("pressure_ratio", 1.0)
	water_system.pressure_boost = data.get("pressure_boost", 0.0)


func _restore_pollution_system(data: Dictionary) -> void:
	if not pollution_system:
		return

	if pollution_system.has_method("load_save_data"):
		pollution_system.load_save_data(data)


func _restore_infrastructure_age(data: Dictionary) -> void:
	if not infrastructure_age_system:
		return

	if infrastructure_age_system.has_method("load_save_data"):
		infrastructure_age_system.load_save_data(data)
	elif data.has("infrastructure_age"):
		# Manual restoration
		infrastructure_age_system.infrastructure_age.clear()
		var age_data = data.get("infrastructure_age", {})
		for id_str in age_data:
			var id = int(id_str)
			infrastructure_age_system.infrastructure_age[id] = age_data[id_str].duplicate()


func _clear_all_buildings() -> void:
	if not grid_system:
		return

	# Get all unique buildings
	var to_remove: Array = []
	var seen: Dictionary = {}
	for cell in grid_system.buildings:
		var building = grid_system.buildings[cell]
		if is_instance_valid(building) and not seen.has(building):
			seen[building] = true
			to_remove.append(building)

	for cell in grid_system.utility_overlays:
		var overlay = grid_system.utility_overlays[cell]
		if is_instance_valid(overlay) and not seen.has(overlay):
			seen[overlay] = true
			to_remove.append(overlay)

	# Free all buildings
	for building in to_remove:
		building.queue_free()

	# Clear dictionaries and internal caches
	grid_system.clear_all_buildings_state()


func _restore_building(data: Dictionary) -> void:
	SaveBuildingCodec.restore_building(grid_system, data)


func delete_save(file_path: String) -> bool:
	var error = DirAccess.remove_absolute(file_path)
	return error == OK


func _sanitize_filename(filename: String) -> String:
	var sanitized = filename.strip_edges()
	sanitized = sanitized.replace(" ", "_")
	sanitized = sanitized.replace("/", "_")
	sanitized = sanitized.replace("\\", "_")
	sanitized = sanitized.replace(":", "_")
	sanitized = sanitized.replace("*", "_")
	sanitized = sanitized.replace("?", "_")
	sanitized = sanitized.replace("\"", "_")
	sanitized = sanitized.replace("<", "_")
	sanitized = sanitized.replace(">", "_")
	sanitized = sanitized.replace("|", "_")
	return sanitized
