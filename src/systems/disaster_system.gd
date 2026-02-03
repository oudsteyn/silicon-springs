extends Node
class_name DisasterSystem
## Handles natural and man-made disasters that can affect the city

signal disaster_started(disaster_type: String, center: Vector2i, radius: int)
signal disaster_ended(disaster_type: String)

var grid_system: Node = null
var service_coverage: Node = null
var weather_system: Node = null
var terrain_system: Node = null

# Disaster types and their effects
enum DisasterType {
	FIRE,
	EARTHQUAKE,
	TORNADO,
	FLOOD,
	METEOR,
	MONSTER  # Classic SimCity disaster
}

# Active disasters
var active_disasters: Array[Dictionary] = []

# Disaster settings - Legacy constants, use GameConfig
const EARTHQUAKE_DAMAGE_CHANCE: float = 0.3  # 30% of buildings in radius get damaged
const TORNADO_PATH_LENGTH: int = 15  # How many cells tornado travels
const FLOOD_DURATION: int = 3  # Months
const METEOR_RADIUS: int = 3

## Check if disasters are enabled
func _disasters_enabled() -> bool:
	return GameConfig.disasters_enabled if GameConfig else true

## Get earthquake damage chance from GameConfig
func _get_earthquake_damage_chance() -> float:
	return GameConfig.earthquake_damage_chance if GameConfig else EARTHQUAKE_DAMAGE_CHANCE

## Get tornado path length from GameConfig
func _get_tornado_path_length() -> int:
	return GameConfig.tornado_path_length if GameConfig else TORNADO_PATH_LENGTH

## Get flood duration from GameConfig
func _get_flood_duration() -> int:
	return GameConfig.flood_duration if GameConfig else FLOOD_DURATION

## Get meteor radius from GameConfig
func _get_meteor_radius() -> int:
	return GameConfig.meteor_radius if GameConfig else METEOR_RADIUS


func initialize(grid: Node, coverage: Node) -> void:
	grid_system = grid
	service_coverage = coverage
	# Connect weather events if available
	Events.simulation_event.connect(_on_simulation_event)


func set_weather_system(ws: Node) -> void:
	weather_system = ws


func set_terrain_system(ts: Node) -> void:
	terrain_system = ts


func _on_simulation_event(event_type: String, data: Dictionary) -> void:
	match event_type:
		"storm_damage":
			_apply_storm_damage(data.get("severity", 1.0))
		"flood_damage":
			if data.get("active", false):
				_apply_flood_damage()


func trigger_disaster(type: DisasterType, center: Vector2i = Vector2i(-1, -1)) -> void:
	# Check if disasters are enabled
	if not _disasters_enabled():
		return

	# If no center specified, pick a random location with buildings
	if center == Vector2i(-1, -1):
		center = _get_random_building_location()
		if center == Vector2i(-1, -1):
			return  # No buildings to target

	match type:
		DisasterType.FIRE:
			_start_fire_disaster(center)
		DisasterType.EARTHQUAKE:
			_start_earthquake(center)
		DisasterType.TORNADO:
			_start_tornado(center)
		DisasterType.FLOOD:
			_start_flood(center)
		DisasterType.METEOR:
			_start_meteor(center)
		DisasterType.MONSTER:
			_start_monster_attack(center)


func _get_random_building_location() -> Vector2i:
	if not grid_system or grid_system.buildings.is_empty():
		return Vector2i(-1, -1)

	var cells = grid_system.buildings.keys()
	return cells[randi() % cells.size()]


func _start_fire_disaster(center: Vector2i) -> void:
	# Major fire that spreads
	Events.simulation_event.emit("disaster_fire_major", {"cell": center})
	disaster_started.emit("fire", center, 5)

	# Start fires in a radius
	var fire_cells: Array[Vector2i] = []
	for x in range(-2, 3):
		for y in range(-2, 3):
			var cell = center + Vector2i(x, y)
			if grid_system.buildings.has(cell):
				if randf() < 0.6:  # 60% chance to catch fire
					fire_cells.append(cell)
					Events.fire_started.emit(cell)

	# Damage buildings
	for cell in fire_cells:
		var building = grid_system.buildings.get(cell)
		if building and is_instance_valid(building):
			if building.has_method("take_damage"):
				building.take_damage(30 + randi() % 40)  # 30-70 damage


func _start_earthquake(center: Vector2i) -> void:
	Events.simulation_event.emit("disaster_earthquake", {"cell": center})

	var radius = 10 + randi() % 10  # 10-20 cell radius
	disaster_started.emit("earthquake", center, radius)

	# Damage buildings in radius (use GameConfig damage chance)
	var damage_chance = _get_earthquake_damage_chance()
	var damaged_count = 0
	for cell in grid_system.buildings:
		var distance = (Vector2(cell) - Vector2(center)).length()
		if distance <= radius:
			if randf() < damage_chance:
				var building = grid_system.buildings[cell]
				if building and is_instance_valid(building):
					if building.building_data and building.building_data.category != "infrastructure":
						if building.has_method("take_damage"):
							var damage = int(50 * (1.0 - distance / radius))  # More damage near center
							building.take_damage(damage)
							damaged_count += 1

	# Some buildings may collapse completely
	var collapsed = int(damaged_count * 0.1)
	if collapsed > 0:
		Events.simulation_event.emit("buildings_collapsed", {"count": collapsed})


func _start_tornado(center: Vector2i) -> void:
	Events.simulation_event.emit("disaster_tornado", {"cell": center})
	disaster_started.emit("tornado", center, 2)

	# Tornado travels in a random direction
	var directions = [
		Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, -1),
		Vector2i(1, -1), Vector2i(-1, 1)
	]
	var direction = directions[randi() % directions.size()]
	var current_pos = center

	# Use GameConfig path length
	var path_length = _get_tornado_path_length()
	for i in range(path_length):
		# Damage buildings in 2-cell radius around tornado
		for x in range(-2, 3):
			for y in range(-2, 3):
				var cell = current_pos + Vector2i(x, y)
				if grid_system.buildings.has(cell):
					var building = grid_system.buildings[cell]
					if building and is_instance_valid(building):
						if building.has_method("take_damage"):
							building.take_damage(20 + randi() % 30)

		# Move tornado
		current_pos += direction
		# Slight random deviation
		if randf() < 0.3:
			current_pos += Vector2i(randi() % 3 - 1, randi() % 3 - 1)


func _start_flood(center: Vector2i) -> void:
	Events.simulation_event.emit("disaster_flood", {"cell": center})

	var radius = 8 + randi() % 8
	disaster_started.emit("flood", center, radius)

	# Floods don't destroy but make buildings non-operational temporarily
	var flooded_buildings: Array[Node] = []
	for cell in grid_system.buildings:
		var distance = (Vector2(cell) - Vector2(center)).length()
		if distance <= radius:
			var building = grid_system.buildings[cell]
			if building and is_instance_valid(building):
				flooded_buildings.append(building)
				# Flood damage is mostly to operations
				if building.has_method("take_damage"):
					building.take_damage(10)

	# Track flood for duration (use GameConfig duration)
	active_disasters.append({
		"type": "flood",
		"buildings": flooded_buildings,
		"months_remaining": _get_flood_duration()
	})


func _start_meteor(center: Vector2i) -> void:
	# Use GameConfig meteor radius
	var radius = _get_meteor_radius()
	Events.simulation_event.emit("disaster_meteor", {"cell": center})
	disaster_started.emit("meteor", center, radius)

	# Meteor destroys everything in small radius
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var cell = center + Vector2i(x, y)
			var distance = (Vector2(cell) - Vector2(center)).length()
			if distance <= radius:
				if grid_system.buildings.has(cell):
					var building = grid_system.buildings[cell]
					if building and is_instance_valid(building):
						# Central impact destroys, outer ring damages
						if distance <= 1:
							grid_system.remove_building(cell)
						elif building.has_method("take_damage"):
							building.take_damage(80)


func _start_monster_attack(center: Vector2i) -> void:
	Events.simulation_event.emit("disaster_monster", {"cell": center})
	disaster_started.emit("monster", center, 5)

	# Monster wanders and destroys
	var current_pos = center
	var path_length = 10 + randi() % 10

	for i in range(path_length):
		# Destroy buildings at current position
		for x in range(-1, 2):
			for y in range(-1, 2):
				var cell = current_pos + Vector2i(x, y)
				if grid_system.buildings.has(cell):
					var building = grid_system.buildings[cell]
					if building and is_instance_valid(building):
						if randf() < 0.5:  # 50% chance to destroy
							grid_system.remove_building(cell)
						elif building.has_method("take_damage"):
							building.take_damage(50)

		# Monster moves toward populated areas
		var best_dir = Vector2i.ZERO
		var best_count = -1
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var check_pos = current_pos + dir * 3
			var count = 0
			for cx in range(-2, 3):
				for cy in range(-2, 3):
					if grid_system.buildings.has(check_pos + Vector2i(cx, cy)):
						count += 1
			if count > best_count:
				best_count = count
				best_dir = dir

		current_pos += best_dir if best_dir != Vector2i.ZERO else Vector2i(randi() % 3 - 1, randi() % 3 - 1)


func process_monthly() -> void:
	# Process ongoing disasters
	var to_remove: Array[int] = []
	for i in range(active_disasters.size()):
		var disaster = active_disasters[i]
		disaster.months_remaining -= 1
		if disaster.months_remaining <= 0:
			to_remove.append(i)
			disaster_ended.emit(disaster.type)
			Events.simulation_event.emit("disaster_ended", {"disaster_type": disaster.type.capitalize()})

	# Remove finished disasters (in reverse order)
	for i in range(to_remove.size() - 1, -1, -1):
		active_disasters.remove_at(to_remove[i])


func trigger_random_disaster() -> void:
	# Check if disasters are enabled
	if not _disasters_enabled():
		return

	# Weighted random disaster selection
	var roll = randf()
	if roll < 0.4:
		trigger_disaster(DisasterType.FIRE)
	elif roll < 0.6:
		trigger_disaster(DisasterType.EARTHQUAKE)
	elif roll < 0.75:
		trigger_disaster(DisasterType.TORNADO)
	elif roll < 0.9:
		trigger_disaster(DisasterType.FLOOD)
	elif roll < 0.98:
		trigger_disaster(DisasterType.METEOR)
	else:
		trigger_disaster(DisasterType.MONSTER)


## Apply storm damage from weather system
## Storms can damage buildings based on biome storm_damage_mult
func _apply_storm_damage(severity: float) -> void:
	if not grid_system:
		return

	# Storm damage affects random buildings across the map
	var damage_chance = 0.02 * severity  # 2% base chance per building, scaled by severity
	var damaged_count = 0

	var checked_buildings: Dictionary = {}
	for cell in grid_system.buildings:
		var building = grid_system.buildings[cell]
		if not is_instance_valid(building) or checked_buildings.has(building):
			continue
		checked_buildings[building] = true

		# Skip infrastructure (underground/protected)
		if building.building_data and building.building_data.category == "infrastructure":
			continue

		if randf() < damage_chance:
			if building.has_method("take_damage"):
				var damage = int(10 + randf() * 20 * severity)  # 10-30 damage scaled
				building.take_damage(damage)
				damaged_count += 1

	if damaged_count > 0:
		Events.simulation_event.emit("storm_building_damage", {"count": damaged_count})


## Apply flood damage from weather system
## Floods affect buildings at low elevation (beach/wetland and water-adjacent)
func _apply_flood_damage() -> void:
	if not grid_system:
		return

	var damaged_count = 0
	var checked_buildings: Dictionary = {}
	var flooded_cells: Array[Vector2i] = []

	for cell in grid_system.buildings:
		var building = grid_system.buildings[cell]
		if not is_instance_valid(building) or checked_buildings.has(building):
			continue
		checked_buildings[building] = true

		# Skip infrastructure
		if building.building_data and building.building_data.category == "infrastructure":
			continue

		# Calculate flood risk based on terrain
		var flood_risk = _calculate_flood_risk_at(cell)

		if flood_risk > 0 and randf() < flood_risk:
			if building.has_method("take_damage"):
				# Damage scales with elevation - lower = more damage
				var base_damage = 15
				if terrain_system:
					var elevation = terrain_system.get_elevation(cell)
					if elevation <= -2:
						base_damage = 35  # Severe flooding in low areas
					elif elevation <= -1:
						base_damage = 25  # Moderate flooding
					elif elevation == 0:
						base_damage = 15  # Normal flood damage
					else:
						base_damage = 10  # Minor splash damage on higher ground

				building.take_damage(base_damage)
				damaged_count += 1
				flooded_cells.append(cell)

	if damaged_count > 0:
		Events.simulation_event.emit("flood_building_damage", {
			"count": damaged_count,
			"cells": flooded_cells
		})


## Calculate flood risk at a specific cell based on terrain
func _calculate_flood_risk_at(cell: Vector2i) -> float:
	var base_risk = 0.0

	if terrain_system and terrain_system.has_method("get_elevation"):
		var elevation = terrain_system.get_elevation(cell)

		# Very low elevations are almost certain to flood
		if elevation <= -2:
			base_risk = 0.8  # 80% chance
		elif elevation == -1:
			base_risk = 0.5  # 50% chance
		elif elevation == 0:
			base_risk = 0.2  # 20% chance
		elif elevation == 1:
			base_risk = 0.05  # 5% chance on slight hills
		# Higher elevations don't flood

		# Check proximity to water bodies (increases risk)
		if terrain_system.has_method("has_water_nearby"):
			if terrain_system.has_water_nearby(cell, 3):
				base_risk *= 1.5  # 50% more risk near water
		elif _is_near_water(cell):
			base_risk *= 1.3

	else:
		# Without terrain system, use simple random chance
		base_risk = 0.1

	return clampf(base_risk, 0.0, 0.9)


## Check if a cell is near water (fallback without terrain system)
func _is_near_water(cell: Vector2i) -> bool:
	if not terrain_system:
		return false

	# Check adjacent cells for water
	for x in range(-2, 3):
		for y in range(-2, 3):
			var check = cell + Vector2i(x, y)
			if terrain_system.has_method("get_water") and terrain_system.get_water(check) != 0:  # Not NONE
				return true
			elif terrain_system.water.has(check):
				return true

	return false
