extends RefCounted
class_name TerrainPerformanceGate

const DEFAULT_BUDGET := {
	"avg_frame_ms": 16.7,
	"p95_frame_ms": 20.0,
	"chunk_rebuilds_per_second": 18.0,
	"gpu_memory_mb": 3072.0
}


func evaluate(metrics: Dictionary, budget: Dictionary = DEFAULT_BUDGET) -> Dictionary:
	var failures: Array[String] = []
	if float(metrics.get("avg_frame_ms", 9999.0)) > float(budget.get("avg_frame_ms", 16.7)):
		failures.append("avg_frame_ms")
	if float(metrics.get("p95_frame_ms", 9999.0)) > float(budget.get("p95_frame_ms", 20.0)):
		failures.append("p95_frame_ms")
	if float(metrics.get("chunk_rebuilds_per_second", 9999.0)) > float(budget.get("chunk_rebuilds_per_second", 18.0)):
		failures.append("chunk_rebuilds_per_second")
	if float(metrics.get("gpu_memory_mb", 9999.0)) > float(budget.get("gpu_memory_mb", 3072.0)):
		failures.append("gpu_memory_mb")

	return {
		"pass": failures.is_empty(),
		"failures": failures
	}
