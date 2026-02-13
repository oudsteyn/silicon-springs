extends TestBase

const RenderPerfMonitorScript = preload("res://src/autoloads/render_performance_monitor.gd")

var _nodes_to_free: Array[Node] = []
var _applied_presets: Array[int] = []

func _track_node(node: Node) -> Node:
	_nodes_to_free.append(node)
	return node

func after_each() -> void:
	for node in _nodes_to_free:
		if is_instance_valid(node):
			node.free()
	_nodes_to_free.clear()
	_applied_presets.clear()

func _capture_quality_preset(preset: int) -> void:
	_applied_presets.append(preset)

func test_recommendation_high_when_frame_times_are_low() -> void:
	var monitor = _track_node(RenderPerfMonitorScript.new())
	for i in range(60):
		monitor.ingest_frame_time_ms(8.0)

	assert_eq(monitor.recommend_quality_preset(60), monitor.QualityTier.HIGH)

func test_recommendation_low_when_frame_times_are_high() -> void:
	var monitor = _track_node(RenderPerfMonitorScript.new())
	for i in range(60):
		monitor.ingest_frame_time_ms(38.0)

	assert_eq(monitor.recommend_quality_preset(60), monitor.QualityTier.LOW)

func test_apply_auto_tuning_uses_manager() -> void:
	var monitor = _track_node(RenderPerfMonitorScript.new())
	monitor.set_graphics_apply_callback(Callable(self, "_capture_quality_preset"))

	for i in range(90):
		monitor.ingest_frame_time_ms(28.0)
	monitor.apply_auto_tuning(60)

	assert_size(_applied_presets, 1)
	assert_eq(_applied_presets[0], monitor.QualityTier.LOW)


func test_hysteresis_prevents_quality_flapping() -> void:
	var monitor = _track_node(RenderPerfMonitorScript.new())
	monitor.min_seconds_between_changes = 2.0
	monitor.set_graphics_apply_callback(Callable(self, "_capture_quality_preset"))

	for i in range(90):
		monitor.ingest_frame_time_ms(38.0)
	monitor.apply_auto_tuning(60, 0.1)

	for i in range(90):
		monitor.ingest_frame_time_ms(8.0)
	monitor.apply_auto_tuning(60, 0.1)

	assert_size(_applied_presets, 1)
	assert_eq(_applied_presets[0], monitor.QualityTier.LOW)


func test_cooldown_allows_next_change_after_threshold() -> void:
	var monitor = _track_node(RenderPerfMonitorScript.new())
	monitor.min_seconds_between_changes = 1.0
	monitor.set_graphics_apply_callback(Callable(self, "_capture_quality_preset"))

	for i in range(90):
		monitor.ingest_frame_time_ms(38.0)
	monitor.apply_auto_tuning(60, 0.1)

	for i in range(240):
		monitor.ingest_frame_time_ms(8.0)
	monitor.apply_auto_tuning(60, 1.2)

	assert_size(_applied_presets, 2)
	if _applied_presets.size() >= 2:
		assert_eq(_applied_presets[0], monitor.QualityTier.LOW)
		assert_eq(_applied_presets[1], monitor.QualityTier.HIGH)


func test_evaluate_terrain_runtime_budget_surfaces_failures() -> void:
	var monitor = _track_node(RenderPerfMonitorScript.new())
	var result = monitor.evaluate_terrain_runtime_budget({
		"avg_frame_ms": 30.0,
		"p95_frame_ms": 45.0,
		"chunk_rebuilds_per_second": 50.0,
		"gpu_memory_mb": 5000.0
	})

	assert_false(bool(result.get("pass", true)))
	assert_not_empty(result.get("failures", []))
