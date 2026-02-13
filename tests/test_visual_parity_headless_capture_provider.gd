extends TestBase

const ProviderScript = preload("res://src/graphics/visual_parity_headless_capture_provider.gd")

func test_capture_profile_frame_returns_image() -> void:
	var provider = ProviderScript.new()
	var frame = provider.capture_profile_frame("HIGH_noon")
	assert_true(frame is Image)
	assert_eq(frame.get_width(), 64)
	assert_eq(frame.get_height(), 64)


func test_capture_profile_frame_is_deterministic_per_profile() -> void:
	var provider = ProviderScript.new()
	var a = provider.capture_profile_frame("LOW_dawn")
	var b = provider.capture_profile_frame("LOW_dawn")
	var c = provider.capture_profile_frame("ULTRA_dusk")
	assert_eq(a.get_data().hex_encode(), b.get_data().hex_encode())
	assert_false(a.get_data().hex_encode() == c.get_data().hex_encode())
