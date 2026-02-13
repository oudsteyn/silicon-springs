extends TestBase

const ErosionScript = preload("res://src/terrain/hydraulic_erosion.gd")


func _make_slope(size: int) -> PackedFloat32Array:
	var data := PackedFloat32Array()
	data.resize(size * size)
	for y in size:
		for x in size:
			data[y * size + x] = float(size - y) + float(size - x) * 0.2
	return data


func test_erosion_changes_heightfield() -> void:
	var size = 64
	var height = _make_slope(size)
	var before = height.duplicate()
	var erosion = ErosionScript.new()
	erosion.erode(height, size, 3000, 99)

	var changed = false
	for i in height.size():
		if abs(height[i] - before[i]) > 0.0001:
			changed = true
			break
	assert_true(changed)


func test_erosion_keeps_non_negative_heights() -> void:
	var size = 64
	var height = _make_slope(size)
	var erosion = ErosionScript.new()
	erosion.erode(height, size, 2000, 123)

	var min_h = INF
	for h in height:
		min_h = min(min_h, h)
	assert_gte(min_h, 0.0)
