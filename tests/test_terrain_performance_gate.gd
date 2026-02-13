extends TestBase

const TerrainPerfGateScript = preload("res://src/terrain/terrain_performance_gate.gd")


func test_evaluate_passes_when_metrics_within_budget() -> void:
	var gate = TerrainPerfGateScript.new()
	var result = gate.evaluate({
		"avg_frame_ms": 12.5,
		"p95_frame_ms": 16.2,
		"chunk_rebuilds_per_second": 5.0,
		"gpu_memory_mb": 1600.0
	})
	assert_true(result.pass)


func test_evaluate_fails_when_budget_violated() -> void:
	var gate = TerrainPerfGateScript.new()
	var result = gate.evaluate({
		"avg_frame_ms": 23.0,
		"p95_frame_ms": 35.0,
		"chunk_rebuilds_per_second": 42.0,
		"gpu_memory_mb": 4800.0
	})
	assert_false(result.pass)
	assert_not_empty(result.failures)

