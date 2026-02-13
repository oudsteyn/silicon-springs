extends TestBase

const MinimapOverlayScript = preload("res://src/ui/grid/minimap_overlay.gd")


func test_map_draw_rect_preserves_world_aspect_ratio() -> void:
	var minimap = MinimapOverlayScript.new()
	add_child(minimap)

	minimap.set_world_cell_size(Vector2i(256, 128))
	minimap.set_minimap_size(Vector2(200, 200))

	var map_rect: Rect2 = minimap.call("_get_map_draw_rect")
	assert_approx(map_rect.position.x, 2.0)
	assert_approx(map_rect.position.y, 51.0)
	assert_approx(map_rect.size.x, 196.0)
	assert_approx(map_rect.size.y, 98.0)
	assert_approx(minimap._scale.x, minimap._scale.y)

	minimap.free()


func test_map_draw_rect_fills_available_space_for_square_world() -> void:
	var minimap = MinimapOverlayScript.new()
	add_child(minimap)

	minimap.set_world_cell_size(Vector2i(128, 128))
	minimap.set_minimap_size(Vector2(200, 200))

	var map_rect: Rect2 = minimap.call("_get_map_draw_rect")
	assert_approx(map_rect.position.x, 2.0)
	assert_approx(map_rect.position.y, 2.0)
	assert_approx(map_rect.size.x, 196.0)
	assert_approx(map_rect.size.y, 196.0)

	minimap.free()
