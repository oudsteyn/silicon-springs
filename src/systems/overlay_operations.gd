class_name OverlayOperations
extends RefCounted
## Handles utility overlay registration/removal and related side effects.


static func _get_events() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return loop.root.get_node_or_null("Events")
	return null


static func _get_game_state() -> Node:
	var loop = Engine.get_main_loop()
	if loop and loop is SceneTree:
		return loop.root.get_node_or_null("GameState")
	return null


static func add_overlay(cell: Vector2i, overlay: Node2D, utility_overlays: Dictionary) -> void:
	utility_overlays[cell] = overlay


static func remove_overlay_at(
	cell: Vector2i,
	utility_overlays: Dictionary,
	unique_buildings: Dictionary,
	refund_percentage: float
) -> Dictionary:
	var overlay = utility_overlays.get(cell)
	if not is_instance_valid(overlay):
		utility_overlays.erase(cell)
		return {"success": false, "refund": 0, "was_overlay": true, "error": "Invalid overlay reference"}

	return remove_overlay_instance(overlay, utility_overlays, unique_buildings, refund_percentage)


static func remove_overlay_instance(
	overlay: Node2D,
	utility_overlays: Dictionary,
	unique_buildings: Dictionary,
	refund_percentage: float
) -> Dictionary:
	if not is_instance_valid(overlay):
		return {"success": false, "refund": 0, "was_overlay": true, "error": "Invalid overlay reference"}

	var overlay_data = overlay.building_data
	var overlay_origin = overlay.grid_cell

	# Remove overlay from all its cells
	for occupied_cell in GridConstants.get_building_cells(overlay_origin, overlay_data.size):
		if utility_overlays.get(occupied_cell) == overlay:
			utility_overlays.erase(occupied_cell)

	# Emit network change events
	var overlay_type = overlay_data.building_type if overlay_data.get("building_type") else ""
	if GridConstants.is_water_type(overlay_type):
		var events = _get_events()
		if events:
			events.water_pipe_network_changed.emit(overlay_origin, false)
	elif GridConstants.is_power_type(overlay_type):
		var events = _get_events()
		if events:
			events.power_line_network_changed.emit(overlay_origin, false)

	# Calculate and apply refund
	var refund = int(overlay_data.build_cost * refund_percentage)
	var game_state = _get_game_state()
	if game_state:
		game_state.earn(refund)
		game_state.decrement_building_count(overlay_data.id)

	# Remove from unique buildings cache
	unique_buildings.erase(overlay.get_instance_id())

	# Emit event and cleanup
	var events = _get_events()
	if events:
		events.building_removed.emit(overlay_origin, overlay)
	overlay.queue_free()

	return {"success": true, "refund": refund, "was_overlay": true, "error": ""}
