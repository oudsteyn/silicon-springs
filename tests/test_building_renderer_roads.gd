extends TestBase

const BuildingRendererScript = preload("res://src/systems/building_renderer.gd")
const BuildingDataScript = preload("res://src/resources/building_data.gd")
var _to_free: Array = []


func after_each() -> void:
	for i in range(_to_free.size() - 1, -1, -1):
		var instance = _to_free[i]
		if is_instance_valid(instance):
			instance.free()
	_to_free.clear()


func _track(instance):
	_to_free.append(instance)
	return instance


func _color_close(a: Color, b: Color, eps: float = 0.02) -> bool:
	return abs(a.r - b.r) <= eps and abs(a.g - b.g) <= eps and abs(a.b - b.b) <= eps and abs(a.a - b.a) <= eps


func test_corner_roads_carve_inner_quadrant_for_rounded_turn() -> void:
	var renderer = _track(BuildingRendererScript.new())
	var data = BuildingDataScript.new()
	data.id = "road"
	data.building_type = "road"
	data.size = Vector2i.ONE
	data.color = Color.WHITE

	var texture = renderer._generate_texture(data, 1, {
		"north": 1,
		"south": 0,
		"east": 1,
		"west": 0
	})
	var image = texture.get_image()
	var w = image.get_width()
	var h = image.get_height()

	var sidewalk = Color(0.45, 0.45, 0.42, 1.0)
	var carved_pixel = image.get_pixel(4, h - 5)
	assert_true(_color_close(carved_pixel, sidewalk), "Expected carved inner corner to be sidewalk")

	var road_pixel = image.get_pixel(w - 6, 6)
	assert_false(_color_close(road_pixel, sidewalk), "Expected connected arm to remain road")


func test_corner_quadrant_mapping_matches_connection_orientation() -> void:
	var renderer = _track(BuildingRendererScript.new())
	assert_eq(renderer._get_corner_quadrant(true, false, true, false), "sw")
	assert_eq(renderer._get_corner_quadrant(false, true, true, false), "nw")
	assert_eq(renderer._get_corner_quadrant(false, true, false, true), "ne")
	assert_eq(renderer._get_corner_quadrant(true, false, false, true), "se")
