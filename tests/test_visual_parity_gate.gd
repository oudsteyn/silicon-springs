extends TestBase

const GraphicsSettingsManagerScript = preload("res://src/autoloads/graphics_settings_manager.gd")

var _nodes_to_free: Array[Node] = []

func _track_node(node: Node) -> Node:
	_nodes_to_free.append(node)
	return node

func after_each() -> void:
	for node in _nodes_to_free:
		if is_instance_valid(node):
			node.free()
	_nodes_to_free.clear()

func test_quality_contract_has_required_fields() -> void:
	var mgr = _track_node(GraphicsSettingsManagerScript.new())
	var settings = mgr.get_current_settings()
	for key in [
		"preset",
		"shadow_quality",
		"ssao_enabled",
		"ssr_enabled",
		"volumetric_fog_enabled",
		"glow_enabled",
		"tonemap_exposure",
		"tonemap_white",
		"auto_quality_enabled"
	]:
		assert_true(settings.has(key), "Missing settings field: %s" % key)

func test_visual_target_doc_contains_gate_sections() -> void:
	var f = FileAccess.open("res://src/ui/hud/README_UI_ARCHITECTURE.md", FileAccess.READ)
	assert_not_null(f)
	var txt = f.get_as_text()
	f.close()
	assert_true(txt.find("Visual Target Baseline") >= 0)
	assert_true(txt.find("Quality Tier Contract") >= 0)
