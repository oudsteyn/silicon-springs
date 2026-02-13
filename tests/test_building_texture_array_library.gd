extends TestBase

const TextureArrayLibraryScript = preload("res://src/graphics/materials/building_texture_array_library.gd")


func test_manifest_assigns_stable_layers() -> void:
	var lib = TextureArrayLibraryScript.new()
	var manifest = lib.build_manifest([
		{"building_id": "residential_low", "albedo": "res://a.png", "normal": "res://an.png", "orm": "res://ao.png", "emission": "res://ae.png"},
		{"building_id": "commercial_low", "albedo": "res://b.png", "normal": "res://bn.png", "orm": "res://bo.png", "emission": "res://be.png"}
	])

	assert_eq(int(manifest.layers.get("residential_low", -1)), 0)
	assert_eq(int(manifest.layers.get("commercial_low", -1)), 1)
	assert_eq(int(manifest.entries.size()), 2)
