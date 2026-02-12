extends TestBase

const VisualImageDiffScript = preload("res://src/graphics/visual_image_diff.gd")

func _solid_image(color: Color, size: Vector2i = Vector2i(4, 4)) -> Image:
	var img = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return img

func test_compare_identical_images_passes() -> void:
	var diff = VisualImageDiffScript.new()
	var a = _solid_image(Color(0.2, 0.4, 0.6, 1.0))
	var b = _solid_image(Color(0.2, 0.4, 0.6, 1.0))

	var result = diff.compare_images(a, b, {"mse_threshold": 0.0, "max_delta_threshold": 0.0})
	assert_true(bool(result.get("passed", false)))
	assert_eq(int(result.get("changed_pixels", -1)), 0)
	assert_approx(float(result.get("mse", -1.0)), 0.0, 0.000001)


func test_compare_different_images_fails_threshold() -> void:
	var diff = VisualImageDiffScript.new()
	var a = _solid_image(Color(0.0, 0.0, 0.0, 1.0))
	var b = _solid_image(Color(1.0, 1.0, 1.0, 1.0))

	var result = diff.compare_images(a, b, {"mse_threshold": 0.01, "max_delta_threshold": 0.05})
	assert_false(bool(result.get("passed", true)))
	assert_true(float(result.get("mse", 0.0)) > 0.01)
	assert_true(float(result.get("max_delta", 0.0)) > 0.05)
