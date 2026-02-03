extends Node2D
class_name GridOverlay
## LEGACY: Replaced by HeatMapRenderer (Phase 4)
## Kept for backward compatibility but should not be used directly
## Visualizes various overlays: power, water, pollution, land value
##
## NOTE: This file previously had INCORRECT grid dimensions (100x100).
## Now uses GridConstants for correct values.

enum OverlayMode {
	NONE,
	POWER,
	WATER,
	POLLUTION,
	LAND_VALUE,
	SERVICES,
	TRAFFIC,
	ZONES
}

var current_mode: OverlayMode = OverlayMode.NONE
var overlay_tiles: Dictionary = {}  # {Vector2i: ColorRect}

var power_system = null
var water_system = null
var pollution_system = null
var land_value_system = null
var service_coverage = null
var traffic_system = null
var zoning_system = null


func _ready() -> void:
	visible = false
	Events.power_updated.connect(_on_power_updated)
	Events.water_updated.connect(_on_water_updated)
	Events.pollution_updated.connect(_on_pollution_updated)
	Events.coverage_updated.connect(_on_coverage_updated)


func set_systems(power, water, pollution, land_value, services, traffic = null, zoning = null) -> void:
	power_system = power
	water_system = water
	pollution_system = pollution
	land_value_system = land_value
	service_coverage = services
	traffic_system = traffic
	zoning_system = zoning


func set_overlay_mode(mode: OverlayMode) -> void:
	if current_mode == mode:
		# Toggle off if clicking same mode
		current_mode = OverlayMode.NONE
		visible = false
		_clear_overlay()
		Events.simulation_event.emit("overlay_changed", {"mode": "Off"})
		return

	current_mode = mode
	visible = (mode != OverlayMode.NONE)

	if visible:
		_update_overlay()
		var mode_name = _get_mode_name(mode)
		Events.simulation_event.emit("overlay_changed", {"mode": mode_name})
	else:
		_clear_overlay()


func _get_mode_name(mode: OverlayMode) -> String:
	match mode:
		OverlayMode.POWER: return "Power Grid"
		OverlayMode.WATER: return "Water Network"
		OverlayMode.POLLUTION: return "Pollution"
		OverlayMode.LAND_VALUE: return "Land Value"
		OverlayMode.SERVICES: return "Service Coverage"
		OverlayMode.TRAFFIC: return "Traffic"
		OverlayMode.ZONES: return "Zoning"
		_: return "None"


func _clear_overlay() -> void:
	for tile in overlay_tiles.values():
		if is_instance_valid(tile):
			tile.queue_free()
	overlay_tiles.clear()


func _update_overlay() -> void:
	_clear_overlay()

	match current_mode:
		OverlayMode.POWER:
			_draw_power_overlay()
		OverlayMode.WATER:
			_draw_water_overlay()
		OverlayMode.POLLUTION:
			_draw_pollution_overlay()
		OverlayMode.LAND_VALUE:
			_draw_land_value_overlay()
		OverlayMode.SERVICES:
			_draw_services_overlay()
		OverlayMode.TRAFFIC:
			_draw_traffic_overlay()
		OverlayMode.ZONES:
			_draw_zones_overlay()


func _draw_power_overlay() -> void:
	if not power_system:
		return

	var powered_cells = power_system.get_powered_cells()
	for cell in powered_cells:
		_add_overlay_tile(cell, Color(1, 1, 0, 0.3))  # Yellow for power


func _draw_water_overlay() -> void:
	if not water_system:
		return

	var watered_cells = water_system.get_watered_cells()
	for cell in watered_cells:
		_add_overlay_tile(cell, Color(0, 0.5, 1, 0.3))  # Blue for water


func _draw_pollution_overlay() -> void:
	if not pollution_system:
		return

	var pollution_map = pollution_system.get_pollution_map()
	for cell in pollution_map:
		var pollution = pollution_map[cell]
		# Red intensity based on pollution level
		var color = Color(pollution, 0, 0, 0.4 * pollution)
		_add_overlay_tile(cell, color)


func _draw_land_value_overlay() -> void:
	if not land_value_system:
		return

	var land_value_map = land_value_system.get_land_value_map()
	for cell in land_value_map:
		var value = land_value_map[cell]
		# Green for high value, red for low value
		var color: Color
		if value >= 0.7:
			color = Color(0, 0.8, 0, 0.3)  # Green
		elif value >= 0.5:
			color = Color(0.8, 0.8, 0, 0.3)  # Yellow
		else:
			color = Color(0.8, 0, 0, 0.3)  # Red
		_add_overlay_tile(cell, color)


func _draw_services_overlay() -> void:
	if not service_coverage:
		return

	# Combine all service coverages
	var cells_to_draw: Dictionary = {}

	# Fire coverage (red tint)
	for cell in service_coverage.fire_coverage:
		if not cells_to_draw.has(cell):
			cells_to_draw[cell] = Color(0, 0, 0, 0)
		cells_to_draw[cell].r += 0.3

	# Police coverage (blue tint)
	for cell in service_coverage.police_coverage:
		if not cells_to_draw.has(cell):
			cells_to_draw[cell] = Color(0, 0, 0, 0)
		cells_to_draw[cell].b += 0.3

	# Education coverage (green tint)
	for cell in service_coverage.education_coverage:
		if not cells_to_draw.has(cell):
			cells_to_draw[cell] = Color(0, 0, 0, 0)
		cells_to_draw[cell].g += 0.3

	for cell in cells_to_draw:
		var color = cells_to_draw[cell]
		color.a = 0.25
		_add_overlay_tile(cell, color)


func _draw_traffic_overlay() -> void:
	if not traffic_system:
		return

	var traffic_map = traffic_system.get_traffic_map()
	for cell in traffic_map:
		var congestion = traffic_system.get_congestion_at(cell)
		# Green = light, Yellow = moderate, Red = heavy
		var color: Color
		if congestion < 0.3:
			color = Color(0, 0.8, 0, 0.3)  # Green - light traffic
		elif congestion < 0.6:
			color = Color(0.8, 0.8, 0, 0.4)  # Yellow - moderate
		elif congestion < 0.8:
			color = Color(0.8, 0.4, 0, 0.4)  # Orange - heavy
		else:
			color = Color(0.8, 0, 0, 0.5)  # Red - gridlock
		_add_overlay_tile(cell, color)


func _draw_zones_overlay() -> void:
	if not zoning_system:
		return

	var all_zones = zoning_system.get_all_zones()
	for cell in all_zones:
		var zone_data = all_zones[cell]
		var color = zoning_system.get_zone_color(zone_data.type)
		# Increase alpha for better visibility on overlay
		color.a = 0.5
		_add_overlay_tile(cell, color)


func _add_overlay_tile(cell: Vector2i, color: Color) -> void:
	if overlay_tiles.has(cell):
		return

	var tile = ColorRect.new()
	tile.position = Vector2(cell.x * GridConstants.CELL_SIZE, cell.y * GridConstants.CELL_SIZE)
	tile.size = Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE)
	tile.color = color
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tile)
	overlay_tiles[cell] = tile


func _on_power_updated(_supply: float, _demand: float) -> void:
	if current_mode == OverlayMode.POWER:
		_update_overlay()


func _on_water_updated(_supply: float, _demand: float) -> void:
	if current_mode == OverlayMode.WATER:
		_update_overlay()


func _on_pollution_updated() -> void:
	if current_mode == OverlayMode.POLLUTION:
		_update_overlay()


func _on_coverage_updated(_service_type: String) -> void:
	if current_mode == OverlayMode.SERVICES:
		_update_overlay()


func toggle_power_overlay() -> void:
	set_overlay_mode(OverlayMode.POWER)


func toggle_water_overlay() -> void:
	set_overlay_mode(OverlayMode.WATER)


func toggle_pollution_overlay() -> void:
	set_overlay_mode(OverlayMode.POLLUTION)


func toggle_land_value_overlay() -> void:
	set_overlay_mode(OverlayMode.LAND_VALUE)


func toggle_services_overlay() -> void:
	set_overlay_mode(OverlayMode.SERVICES)


func toggle_traffic_overlay() -> void:
	set_overlay_mode(OverlayMode.TRAFFIC)


func toggle_zones_overlay() -> void:
	set_overlay_mode(OverlayMode.ZONES)


func cycle_overlay() -> void:
	var next_mode = (current_mode + 1) % OverlayMode.size()
	set_overlay_mode(next_mode)
