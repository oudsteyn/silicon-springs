extends RefCounted
class_name BuildingTextureArrayLibrary
## Manages mapping from building IDs to texture-array layers.

func build_manifest(entries: Array) -> Dictionary:
	var manifest := {
		"entries": [],
		"layers": {}
	}
	var layer = 0
	for raw in entries:
		if not (raw is Dictionary):
			continue
		var id = str(raw.get("building_id", ""))
		if id == "":
			continue
		if manifest.layers.has(id):
			continue
		var normalized = {
			"building_id": id,
			"layer": layer,
			"albedo": str(raw.get("albedo", "")),
			"normal": str(raw.get("normal", "")),
			"orm": str(raw.get("orm", "")),
			"emission": str(raw.get("emission", ""))
		}
		manifest.entries.append(normalized)
		manifest.layers[id] = layer
		layer += 1
	return manifest
