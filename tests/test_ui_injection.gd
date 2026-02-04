extends TestBase
## Tests for UI dependency injection helpers

class FakeGameWorld extends Node:
	var last_terrain_tool = null
	var camera: Camera2D = Camera2D.new()

	func _init() -> void:
		add_child(camera)
		camera.position = Vector2(12, 34)
		camera.zoom = Vector2(2, 2)

	func set_terrain_tool(tool_id) -> void:
		last_terrain_tool = tool_id


class FakeEvents extends Node:
	signal building_placed(cell, building)
	signal building_removed(cell, building)
	signal month_tick()
	signal building_catalog_ready(catalog)
	signal building_catalog_requested()


func test_tool_palette_uses_injected_game_world() -> void:
	var palette = ToolPalette.new()
	var world = FakeGameWorld.new()
	palette.set_game_world(world)

	palette._on_flyout_item_selected("terrain_raise", {"terrain_tool": "raise"}, "terrain")
	assert_eq(world.last_terrain_tool, "raise")

	palette.free()
	world.free()


func test_minimap_uses_injected_game_world() -> void:
	var minimap = MiniMinimap.new()
	var world = FakeGameWorld.new()
	add_child(minimap)
	minimap._setup_ui()
	minimap.set_game_world(world)

	minimap._process(0.0)
	assert_eq(minimap._last_camera_pos, world.camera.position)

	minimap.free()
	world.free()


func test_minimap_connects_injected_events() -> void:
	var minimap = MiniMinimap.new()
	var events = FakeEvents.new()
	minimap.set_events(events)

	minimap._connect_events()

	var placed_connected = events.building_placed.is_connected(Callable(minimap, "_on_building_changed"))
	var removed_connected = events.building_removed.is_connected(Callable(minimap, "_on_building_changed"))
	var month_connected = events.month_tick.is_connected(Callable(minimap, "_update_minimap"))

	assert_true(placed_connected)
	assert_true(removed_connected)
	assert_true(month_connected)

	minimap.free()
	events.free()


func test_tool_palette_connects_injected_events() -> void:
	var palette = ToolPalette.new()
	var events = FakeEvents.new()
	palette.set_events(events)

	palette._connect_signals()

	var connected = events.building_catalog_ready.is_connected(Callable(palette, "_on_building_catalog_ready"))
	assert_true(connected)

	palette.free()
	events.free()
