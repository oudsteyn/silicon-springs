extends TestBase

const VisualRegressionHarnessScript = preload("res://src/graphics/visual_regression_harness.gd")

class FakeGraphicsSettingsManager extends Node:
	enum QualityPreset { LOW, MEDIUM, HIGH, ULTRA }
	func get_preset_contract(preset: int) -> Dictionary:
		match preset:
			QualityPreset.LOW:
				return {"ssr_enabled": false, "ssao_enabled": false, "shadow_quality": 0, "tonemap_exposure": 0.95}
			QualityPreset.MEDIUM:
				return {"ssr_enabled": false, "ssao_enabled": true, "shadow_quality": 1, "tonemap_exposure": 1.0}
			QualityPreset.HIGH:
				return {"ssr_enabled": true, "ssao_enabled": true, "shadow_quality": 2, "tonemap_exposure": 1.05}
			_:
				return {"ssr_enabled": true, "ssao_enabled": true, "shadow_quality": 3, "tonemap_exposure": 1.1}

class FakeDaylightController extends Node:
	var _t: float = 0.0
	func set_time_normalized(v: float) -> void:
		_t = v
	func get_visual_state() -> Dictionary:
		return {
			"day_factor": _t,
			"sun_energy": 0.1 + _t,
			"fog_density": 0.02 - _t * 0.005
		}

var _nodes_to_free: Array[Node] = []

func _track_node(node: Node) -> Node:
	_nodes_to_free.append(node)
	return node

func after_each() -> void:
	for node in _nodes_to_free:
		if is_instance_valid(node):
			node.free()
	_nodes_to_free.clear()

func test_signature_rounds_floats_for_stability() -> void:
	var harness = VisualRegressionHarnessScript.new()
	var sig_a = harness.make_signature({"x": 1.00004}, {"y": 0.50004})
	var sig_b = harness.make_signature({"x": 1.00005}, {"y": 0.50005})
	assert_eq(sig_a, sig_b)

func test_compare_detects_drift() -> void:
	var harness = VisualRegressionHarnessScript.new()
	var baseline = {"profile": "abc"}
	var result = harness.compare_against_baseline("profile", "xyz", baseline)
	assert_false(bool(result.get("passed", true)))

func test_generate_profile_signatures_builds_expected_matrix() -> void:
	var harness = VisualRegressionHarnessScript.new()
	var mgr = _track_node(FakeGraphicsSettingsManager.new())
	var daylight = _track_node(FakeDaylightController.new())
	var out = harness.generate_profile_signatures(mgr, daylight)
	assert_eq(out.size(), 12)
	assert_true(out.has("LOW_noon"))
	assert_true(out.has("ULTRA_dusk"))

func test_baseline_file_round_trip() -> void:
	var harness = VisualRegressionHarnessScript.new()
	var path = "user://visual_baseline_test.json"
	var baseline = {"A": "one", "B": "two"}
	assert_true(harness.save_baseline(path, baseline))
	var loaded = harness.load_baseline(path)
	assert_eq(loaded, baseline)
