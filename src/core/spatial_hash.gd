extends RefCounted
class_name SpatialHash
## Spatial hash for efficient range queries on grid-based data
##
## Uses a bucket-based approach where the grid is divided into cells of BUCKET_SIZE.
## Each bucket stores references to entities within that region.
##
## Coverage masks should be pre-initialized at startup via initialize_coverage_masks()
## using GridConstants.MAX_COVERAGE_RADIUS for the max_radius parameter.

const BUCKET_SIZE: int = 16  # Each bucket covers 16x16 grid cells

var _buckets: Dictionary = {}  # {bucket_key: {entity_id: entity_data}}
var _entity_buckets: Dictionary = {}  # {entity_id: [bucket_keys]}  # Track which buckets each entity is in

## Pre-computed coverage masks for common radii
static var _coverage_masks: Dictionary = {}  # {radius: Array[Vector2i]}
static var _coverage_masks_with_strength: Dictionary = {}  # {radius: Array[{offset: Vector2i, strength: float}]}


## Pre-compute coverage masks for radii 1 to max_radius
## Call this once at game startup with GridConstants.MAX_COVERAGE_RADIUS
## This avoids computing masks on-demand during gameplay
static func initialize_coverage_masks(max_radius: int = 20) -> void:
	for radius in range(1, max_radius + 1):
		_coverage_masks[radius] = _compute_coverage_mask(radius)
		_coverage_masks_with_strength[radius] = _compute_coverage_mask_with_strength(radius)


static func _compute_coverage_mask(radius: int) -> Array[Vector2i]:
	var mask: Array[Vector2i] = []
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var dist_sq = x * x + y * y
			if dist_sq <= radius * radius:
				mask.append(Vector2i(x, y))
	return mask


static func _compute_coverage_mask_with_strength(radius: int) -> Array:
	var mask: Array = []
	var radius_f = float(radius)
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var dist_sq = x * x + y * y
			if dist_sq <= radius * radius:
				var distance = sqrt(dist_sq)
				var strength = 1.0 - (distance / radius_f)
				mask.append({
					"offset": Vector2i(x, y),
					"strength": strength
				})
	return mask


## Get pre-computed coverage mask for a radius
static func get_coverage_mask(radius: int) -> Array[Vector2i]:
	if not _coverage_masks.has(radius):
		_coverage_masks[radius] = _compute_coverage_mask(radius)
	return _coverage_masks[radius]


## Get pre-computed coverage mask with strength values
static func get_coverage_mask_with_strength(radius: int) -> Array:
	if not _coverage_masks_with_strength.has(radius):
		_coverage_masks_with_strength[radius] = _compute_coverage_mask_with_strength(radius)
	return _coverage_masks_with_strength[radius]


## Convert grid cell to bucket key
func _get_bucket_key(cell: Vector2i) -> Vector2i:
	return Vector2i(
		int(floor(float(cell.x) / BUCKET_SIZE)),
		int(floor(float(cell.y) / BUCKET_SIZE))
	)


## Insert an entity at a cell position
func insert(entity_id: Variant, cell: Vector2i, data: Variant = null) -> void:
	var bucket_key = _get_bucket_key(cell)

	if not _buckets.has(bucket_key):
		_buckets[bucket_key] = {}

	_buckets[bucket_key][entity_id] = {
		"cell": cell,
		"data": data
	}

	# Track which bucket this entity is in
	if not _entity_buckets.has(entity_id):
		_entity_buckets[entity_id] = []
	_entity_buckets[entity_id].append(bucket_key)


## Insert an entity that spans multiple cells
func insert_multi(entity_id: Variant, cells: Array[Vector2i], data: Variant = null) -> void:
	var bucket_keys_added: Dictionary = {}

	for cell in cells:
		var bucket_key = _get_bucket_key(cell)

		if not bucket_keys_added.has(bucket_key):
			if not _buckets.has(bucket_key):
				_buckets[bucket_key] = {}

			_buckets[bucket_key][entity_id] = {
				"cells": cells,
				"data": data
			}
			bucket_keys_added[bucket_key] = true

	_entity_buckets[entity_id] = bucket_keys_added.keys()


## Remove an entity
func remove(entity_id: Variant) -> void:
	if not _entity_buckets.has(entity_id):
		return

	for bucket_key in _entity_buckets[entity_id]:
		if _buckets.has(bucket_key):
			_buckets[bucket_key].erase(entity_id)
			if _buckets[bucket_key].is_empty():
				_buckets.erase(bucket_key)

	_entity_buckets.erase(entity_id)


## Update an entity's position
func update(entity_id: Variant, new_cell: Vector2i, data: Variant = null) -> void:
	remove(entity_id)
	insert(entity_id, new_cell, data)


## Query all entities within a radius of a center cell
## Properly handles multi-cell buildings by checking if ANY cell is in range
func query_radius(center: Vector2i, radius: int) -> Array:
	var result: Array = []
	var seen: Dictionary = {}

	# Calculate which buckets could contain entities in range
	var min_bucket = _get_bucket_key(center - Vector2i(radius, radius))
	var max_bucket = _get_bucket_key(center + Vector2i(radius, radius))

	var radius_sq = radius * radius

	for bx in range(min_bucket.x, max_bucket.x + 1):
		for by in range(min_bucket.y, max_bucket.y + 1):
			var bucket_key = Vector2i(bx, by)
			if not _buckets.has(bucket_key):
				continue

			for entity_id in _buckets[bucket_key]:
				if seen.has(entity_id):
					continue
				seen[entity_id] = true

				var entity_info = _buckets[bucket_key][entity_id]

				# Handle multi-cell buildings (inserted via insert_multi)
				if entity_info.has("cells"):
					var cells: Array = entity_info.get("cells")
					var min_dist_sq: int = -1
					var closest_cell: Vector2i = Vector2i.ZERO

					for cell in cells:
						var delta = cell - center
						var dist_sq = delta.x * delta.x + delta.y * delta.y
						if dist_sq <= radius_sq:
							if min_dist_sq < 0 or dist_sq < min_dist_sq:
								min_dist_sq = dist_sq
								closest_cell = cell

					if min_dist_sq >= 0:
						result.append({
							"id": entity_id,
							"cell": closest_cell,
							"cells": cells,
							"data": entity_info.get("data"),
							"distance_sq": min_dist_sq
						})
				else:
					# Single-cell entity (inserted via insert)
					var cell = entity_info.get("cell", Vector2i.ZERO)
					var delta = cell - center
					var dist_sq = delta.x * delta.x + delta.y * delta.y
					if dist_sq <= radius_sq:
						result.append({
							"id": entity_id,
							"cell": cell,
							"data": entity_info.get("data"),
							"distance_sq": dist_sq
						})

	return result


## Query all entities within a rectangular region
## Properly handles multi-cell buildings by checking if ANY cell is in the rect
func query_rect(min_cell: Vector2i, max_cell: Vector2i) -> Array:
	var result: Array = []
	var seen: Dictionary = {}

	var min_bucket = _get_bucket_key(min_cell)
	var max_bucket = _get_bucket_key(max_cell)

	for bx in range(min_bucket.x, max_bucket.x + 1):
		for by in range(min_bucket.y, max_bucket.y + 1):
			var bucket_key = Vector2i(bx, by)
			if not _buckets.has(bucket_key):
				continue

			for entity_id in _buckets[bucket_key]:
				if seen.has(entity_id):
					continue
				seen[entity_id] = true

				var entity_info = _buckets[bucket_key][entity_id]

				# Handle multi-cell buildings (inserted via insert_multi)
				if entity_info.has("cells"):
					var cells: Array = entity_info.get("cells")
					var found_cell: Vector2i = Vector2i.ZERO
					var is_in_rect: bool = false

					for cell in cells:
						if cell.x >= min_cell.x and cell.x <= max_cell.x and \
						   cell.y >= min_cell.y and cell.y <= max_cell.y:
							found_cell = cell
							is_in_rect = true
							break

					if is_in_rect:
						result.append({
							"id": entity_id,
							"cell": found_cell,
							"cells": cells,
							"data": entity_info.get("data")
						})
				else:
					# Single-cell entity (inserted via insert)
					var cell = entity_info.get("cell", Vector2i.ZERO)
					if cell.x >= min_cell.x and cell.x <= max_cell.x and \
					   cell.y >= min_cell.y and cell.y <= max_cell.y:
						result.append({
							"id": entity_id,
							"cell": cell,
							"data": entity_info.get("data")
						})

	return result


## Get all entities in a specific bucket
func get_bucket_entities(bucket_key: Vector2i) -> Dictionary:
	return _buckets.get(bucket_key, {})


## Clear all data
func clear() -> void:
	_buckets.clear()
	_entity_buckets.clear()


## Get count of entities
func size() -> int:
	return _entity_buckets.size()


## Check if entity exists
func has_entity(entity_id: Variant) -> bool:
	return _entity_buckets.has(entity_id)
