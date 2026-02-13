extends TestBase

const TerrainPerfCiGateScript = preload("res://src/terrain/terrain_perf_ci_gate.gd")


func test_evaluate_metrics_returns_exit_code_for_ci() -> void:
	var gate = TerrainPerfCiGateScript.new()
	var pass_result = gate.evaluate_metrics({
		"avg_frame_ms": 12.0,
		"p95_frame_ms": 16.0,
		"chunk_rebuilds_per_second": 7.0,
		"gpu_memory_mb": 1024.0
	})
	assert_eq(pass_result.exit_code, 0)

	var fail_result = gate.evaluate_metrics({
		"avg_frame_ms": 33.0,
		"p95_frame_ms": 48.0,
		"chunk_rebuilds_per_second": 55.0,
		"gpu_memory_mb": 6000.0
	})
	assert_eq(fail_result.exit_code, 1)
	assert_gt(String(fail_result.summary_markdown).length(), 0)
