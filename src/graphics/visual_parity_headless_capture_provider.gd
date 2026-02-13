class_name VisualParityHeadlessCaptureProvider
extends RefCounted

const FRAME_SIZE := 64

func capture_profile_frame(profile_id: String) -> Image:
	var image = Image.create(FRAME_SIZE, FRAME_SIZE, false, Image.FORMAT_RGBA8)
	if image == null:
		return null

	var seed = _seed_from_profile(profile_id)
	var base_r: float = float((seed >> 16) & 0xFF) / 255.0
	var base_g: float = float((seed >> 8) & 0xFF) / 255.0
	var base_b: float = float(seed & 0xFF) / 255.0

	for y in FRAME_SIZE:
		var yf = float(y) / float(FRAME_SIZE - 1)
		for x in FRAME_SIZE:
			var xf = float(x) / float(FRAME_SIZE - 1)
			var pulse = sin((xf + yf) * PI * 2.0 + float(seed % 17)) * 0.08
			var r = clampf(base_r * 0.7 + xf * 0.3 + pulse, 0.0, 1.0)
			var g = clampf(base_g * 0.7 + yf * 0.3 - pulse, 0.0, 1.0)
			var b = clampf(base_b * 0.6 + (1.0 - xf) * 0.2 + (1.0 - yf) * 0.2, 0.0, 1.0)
			image.set_pixel(x, y, Color(r, g, b, 1.0))
	return image


func _seed_from_profile(profile_id: String) -> int:
	var hash_value := 216613626
	for i in profile_id.length():
		hash_value = int(((hash_value ^ profile_id.unicode_at(i)) * 16777619) & 0x7fffffff)
	return hash_value
