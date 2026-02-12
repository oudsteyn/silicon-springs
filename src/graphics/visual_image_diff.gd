class_name VisualImageDiff
extends RefCounted

func compare_images(expected: Image, actual: Image, options: Dictionary = {}) -> Dictionary:
	if expected == null or actual == null:
		return {
			"passed": false,
			"reason": "missing_image",
			"mse": INF,
			"max_delta": INF,
			"changed_pixels": 0,
			"total_pixels": 0
		}

	if expected.get_width() != actual.get_width() or expected.get_height() != actual.get_height():
		return {
			"passed": false,
			"reason": "size_mismatch",
			"mse": INF,
			"max_delta": INF,
			"changed_pixels": 0,
			"total_pixels": 0
		}

	var mse_threshold: float = float(options.get("mse_threshold", 0.001))
	var max_delta_threshold: float = float(options.get("max_delta_threshold", 0.08))
	var expected_rgba = expected.duplicate()
	var actual_rgba = actual.duplicate()
	expected_rgba.convert(Image.FORMAT_RGBA8)
	actual_rgba.convert(Image.FORMAT_RGBA8)

	var w = expected_rgba.get_width()
	var h = expected_rgba.get_height()
	var total_pixels = w * h
	var total_sq_error := 0.0
	var max_delta := 0.0
	var changed_pixels := 0

	for y in range(h):
		for x in range(w):
			var c0: Color = expected_rgba.get_pixel(x, y)
			var c1: Color = actual_rgba.get_pixel(x, y)
			var dr: float = c0.r - c1.r
			var dg: float = c0.g - c1.g
			var db: float = c0.b - c1.b
			var da: float = c0.a - c1.a
			var sq := dr * dr + dg * dg + db * db + da * da
			total_sq_error += sq
			var delta := maxf(maxf(absf(dr), absf(dg)), maxf(absf(db), absf(da)))
			max_delta = maxf(max_delta, delta)
			if delta > 0.0:
				changed_pixels += 1

	var mse := total_sq_error / float(total_pixels * 4)
	return {
		"passed": mse <= mse_threshold and max_delta <= max_delta_threshold,
		"mse": mse,
		"max_delta": max_delta,
		"changed_pixels": changed_pixels,
		"total_pixels": total_pixels
	}


func load_png(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	return img if img.load(path) == OK else null


func save_png(path: String, image: Image) -> bool:
	if image == null:
		return false
	var dir_path = path.get_base_dir()
	var dir = DirAccess.open("user://")
	if dir:
		dir.make_dir_recursive_absolute(dir_path)
	return image.save_png(path) == OK
