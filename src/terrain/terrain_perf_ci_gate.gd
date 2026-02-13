extends RefCounted
class_name TerrainPerfCiGate

const TerrainPerformanceGateScript = preload("res://src/terrain/terrain_performance_gate.gd")

var _gate = TerrainPerformanceGateScript.new()


func evaluate_metrics(metrics: Dictionary) -> Dictionary:
	var result = _gate.evaluate(metrics)
	var exit_code = 0 if bool(result.get("pass", false)) else 1
	return {
		"exit_code": exit_code,
		"result": result,
		"summary_markdown": _to_markdown(metrics, result)
	}


func _to_markdown(metrics: Dictionary, result: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append("# Terrain Perf Gate")
	lines.append("")
	lines.append("- pass: %s" % [str(result.get("pass", false))])
	lines.append("- avg_frame_ms: %.2f" % [float(metrics.get("avg_frame_ms", 0.0))])
	lines.append("- p95_frame_ms: %.2f" % [float(metrics.get("p95_frame_ms", 0.0))])
	lines.append("- chunk_rebuilds_per_second: %.2f" % [float(metrics.get("chunk_rebuilds_per_second", 0.0))])
	lines.append("- gpu_memory_mb: %.2f" % [float(metrics.get("gpu_memory_mb", 0.0))])
	var failures = result.get("failures", [])
	if failures.size() > 0:
		lines.append("- failures: %s" % [", ".join(failures)])
	return "\n".join(lines)
