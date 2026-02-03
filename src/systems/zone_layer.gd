extends Node2D
class_name ZoneLayer
## Permanently displays zone colors on the grid

var zoning_system = null
var zone_tiles: Dictionary = {}  # {Vector2i: ColorRect}


func _ready() -> void:
	# Ensure this layer is behind buildings but above terrain
	z_index = -1


func set_zoning_system(system) -> void:
	zoning_system = system
	if zoning_system:
		zoning_system.zone_changed.connect(_on_zone_changed)
		# Draw any existing zones
		_refresh_all_zones()


func _on_zone_changed(cell: Vector2i, _zone_name: String) -> void:
	_update_zone_tile(cell)


func _update_zone_tile(cell: Vector2i) -> void:
	if not zoning_system:
		return

	# Remove existing tile if any
	if zone_tiles.has(cell):
		var old_tile = zone_tiles[cell]
		if is_instance_valid(old_tile):
			old_tile.queue_free()
		zone_tiles.erase(cell)

	# Get zone at this cell
	var zone_type = zoning_system.get_zone_at(cell)
	if zone_type == 0:  # ZoneType.NONE
		return

	# Create new tile with zone color
	var color = zoning_system.get_zone_color(zone_type)
	# Make it more visible
	color.a = 0.5

	var tile = ColorRect.new()
	tile.position = Vector2(cell.x * GridConstants.CELL_SIZE, cell.y * GridConstants.CELL_SIZE)
	tile.size = Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE)
	tile.color = color
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tile)
	zone_tiles[cell] = tile


func _refresh_all_zones() -> void:
	if not zoning_system:
		return

	# Clear all existing tiles
	for tile in zone_tiles.values():
		if is_instance_valid(tile):
			tile.queue_free()
	zone_tiles.clear()

	# Draw all zones
	var all_zones = zoning_system.get_all_zones()
	for cell in all_zones:
		_update_zone_tile(cell)


func clear() -> void:
	for tile in zone_tiles.values():
		if is_instance_valid(tile):
			tile.queue_free()
	zone_tiles.clear()
