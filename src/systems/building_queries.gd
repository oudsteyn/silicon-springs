class_name BuildingQueries
extends RefCounted
## Static utility class for building queries
##
## Provides query functions that operate on building data structures.
## All methods are static and take the data structures as parameters,
## making them easily testable and reusable.


## Get a building at a specific cell
static func get_building_at(cell: Vector2i, buildings: Dictionary) -> Node2D:
	return buildings.get(cell)


## Get all unique buildings from the unique buildings cache
static func get_all_unique_buildings(unique_buildings: Dictionary) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for building in unique_buildings.values():
		if is_instance_valid(building):
			result.append(building)
	return result


## Get buildings of a specific type
static func get_buildings_of_type(building_type: String, unique_buildings: Dictionary) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for building in unique_buildings.values():
		if is_instance_valid(building) and building.building_data:
			if building.building_data.building_type == building_type:
				result.append(building)
	return result


## Get buildings matching a category
static func get_buildings_by_category(category: String, unique_buildings: Dictionary) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for building in unique_buildings.values():
		if is_instance_valid(building) and building.building_data:
			if building.building_data.category == category:
				result.append(building)
	return result


## Get buildings that require power
static func get_buildings_requiring_power(unique_buildings: Dictionary) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for building in unique_buildings.values():
		if is_instance_valid(building) and building.building_data:
			if building.building_data.requires_power:
				result.append(building)
	return result


## Get buildings that require water
static func get_buildings_requiring_water(unique_buildings: Dictionary) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for building in unique_buildings.values():
		if is_instance_valid(building) and building.building_data:
			if building.building_data.requires_water:
				result.append(building)
	return result


## Get total maintenance cost for all buildings
static func get_total_maintenance(unique_buildings: Dictionary, traffic_system: Node = null) -> int:
	var total = 0
	for building in unique_buildings.values():
		if not is_instance_valid(building) or not building.building_data:
			continue

		var base_maintenance = building.building_data.monthly_maintenance

		# Roads have additional maintenance based on traffic
		if GridConstants.is_road_type(building.building_data.building_type) and traffic_system:
			var cell = building.grid_cell
			if traffic_system.has_method("get_congestion_at"):
				var congestion = traffic_system.get_congestion_at(cell)
				if congestion > 0.5:
					var traffic_multiplier = 1.0 + (congestion - 0.5) * 2.0
					base_maintenance = int(base_maintenance * traffic_multiplier)
					base_maintenance = max(base_maintenance, int(5 * congestion))

		total += base_maintenance
	return total


## Get total power production from all buildings
static func get_total_power_production(unique_buildings: Dictionary) -> float:
	var total = 0.0
	for building in unique_buildings.values():
		if is_instance_valid(building) and building.building_data:
			if building.is_operational:
				total += building.building_data.power_production
	return total


## Get total power consumption from all buildings
static func get_total_power_consumption(unique_buildings: Dictionary) -> float:
	var total = 0.0
	for building in unique_buildings.values():
		if is_instance_valid(building) and building.building_data:
			total += building.building_data.power_consumption
	return total


## Get total water production from all buildings
static func get_total_water_production(unique_buildings: Dictionary) -> float:
	var total = 0.0
	for building in unique_buildings.values():
		if is_instance_valid(building) and building.building_data:
			if building.is_operational:
				total += building.building_data.water_production
	return total


## Get total water consumption from all buildings
static func get_total_water_consumption(unique_buildings: Dictionary) -> float:
	var total = 0.0
	for building in unique_buildings.values():
		if is_instance_valid(building) and building.building_data:
			total += building.building_data.water_consumption
	return total


## Get buildings within a radius using spatial index
static func get_buildings_in_radius(center: Vector2i, radius: int, spatial_index: Node) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not spatial_index or not spatial_index.has_method("query_radius"):
		return result

	var query_result = spatial_index.query_radius(center, radius)
	for entry in query_result:
		var building = entry.get("data")
		if is_instance_valid(building):
			result.append(building)
	return result


## Get buildings within a rectangular region using spatial index
static func get_buildings_in_region(min_cell: Vector2i, max_cell: Vector2i, spatial_index: Node) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not spatial_index or not spatial_index.has_method("query_rect"):
		return result

	var query_result = spatial_index.query_rect(min_cell, max_cell)
	for entry in query_result:
		var building = entry.get("data")
		if is_instance_valid(building):
			result.append(building)
	return result


## Get buildings of a specific type within a radius
static func get_buildings_of_type_in_radius(center: Vector2i, radius: int, building_type: String, spatial_index: Node) -> Array[Node2D]:
	var result: Array[Node2D] = []
	var all_nearby = get_buildings_in_radius(center, radius, spatial_index)

	for building in all_nearby:
		if building.building_data and building.building_data.building_type == building_type:
			result.append(building)
	return result


## Get count of buildings in a radius
static func get_building_count_in_radius(center: Vector2i, radius: int, spatial_index: Node) -> int:
	return get_buildings_in_radius(center, radius, spatial_index).size()


## Get count of operational buildings
static func get_operational_count(unique_buildings: Dictionary) -> int:
	var count = 0
	for building in unique_buildings.values():
		if is_instance_valid(building) and building.is_operational:
			count += 1
	return count


## Get count of non-operational buildings (no power/water)
static func get_non_operational_count(unique_buildings: Dictionary) -> int:
	var count = 0
	for building in unique_buildings.values():
		if is_instance_valid(building) and not building.is_operational:
			count += 1
	return count


## Get buildings grouped by category
static func get_buildings_grouped_by_category(unique_buildings: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for building in unique_buildings.values():
		if is_instance_valid(building) and building.building_data:
			var category = building.building_data.category
			if not result.has(category):
				result[category] = []
			result[category].append(building)
	return result


## Get building statistics
static func get_building_stats(unique_buildings: Dictionary) -> Dictionary:
	var total = 0
	var operational = 0
	var powered = 0
	var watered = 0
	var under_construction = 0
	var abandoned = 0

	for building in unique_buildings.values():
		if not is_instance_valid(building):
			continue
		total += 1
		if building.is_operational:
			operational += 1
		if building.is_powered:
			powered += 1
		if building.is_watered:
			watered += 1
		if building.get("is_under_construction") and building.is_under_construction:
			under_construction += 1
		if building.get("is_abandoned") and building.is_abandoned:
			abandoned += 1

	return {
		"total": total,
		"operational": operational,
		"powered": powered,
		"watered": watered,
		"under_construction": under_construction,
		"abandoned": abandoned
	}
