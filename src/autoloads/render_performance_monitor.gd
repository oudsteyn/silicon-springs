extends Node
const TerrainPerformanceGateScript = preload("res://src/terrain/terrain_performance_gate.gd")

signal quality_recommendation_changed(recommended_tier: int, avg_frame_ms: float)

enum QualityTier {
	LOW,
	MEDIUM,
	HIGH
}

@export var sample_window_size: int = 120
@export var enabled: bool = true
@export var target_fps: int = 60
@export var check_interval_seconds: float = 1.0
@export var min_seconds_between_changes: float = 4.0
@export var upgrade_margin: float = 0.82
@export var downgrade_margin: float = 1.18

var _frame_times_ms: Array[float] = []
var _graphics_apply_callback: Callable = Callable()
var _last_recommendation: int = -1
var _seconds_since_last_change: float = 9999.0
var _seconds_since_check: float = 0.0
var _terrain_gate = TerrainPerformanceGateScript.new()

func _process(delta: float) -> void:
	if not enabled:
		return
	ingest_frame_time_ms(delta * 1000.0)
	_seconds_since_last_change += maxf(delta, 0.0)
	_seconds_since_check += maxf(delta, 0.0)
	if _seconds_since_check >= check_interval_seconds:
		_seconds_since_check = 0.0
		apply_auto_tuning(target_fps, 0.0)

func ingest_frame_time_ms(frame_time_ms: float) -> void:
	_frame_times_ms.append(maxf(0.01, frame_time_ms))
	if _frame_times_ms.size() > sample_window_size:
		_frame_times_ms.remove_at(0)

func get_average_frame_time_ms() -> float:
	if _frame_times_ms.is_empty():
		return 0.0
	var total := 0.0
	for t in _frame_times_ms:
		total += t
	return total / float(_frame_times_ms.size())

func recommend_quality_preset(target_fps: int = 60) -> int:
	var avg_ms = get_average_frame_time_ms()
	if avg_ms <= 0.0:
		return QualityTier.HIGH

	var target_ms = 1000.0 / float(max(target_fps, 1))
	if avg_ms <= target_ms * upgrade_margin:
		return QualityTier.HIGH
	if avg_ms <= target_ms * downgrade_margin:
		return QualityTier.MEDIUM
	return QualityTier.LOW

func set_graphics_apply_callback(callback: Callable) -> void:
	_graphics_apply_callback = callback

func apply_auto_tuning(target_fps: int = 60, elapsed_seconds: float = 0.0) -> void:
	_seconds_since_last_change += maxf(elapsed_seconds, 0.0)
	var recommended = recommend_quality_preset(target_fps)
	if _last_recommendation >= 0:
		recommended = _apply_hysteresis(_last_recommendation, recommended)
	if recommended == _last_recommendation:
		return
	if _seconds_since_last_change < min_seconds_between_changes:
		return

	_last_recommendation = recommended
	_seconds_since_last_change = 0.0

	var avg_ms = get_average_frame_time_ms()
	quality_recommendation_changed.emit(recommended, avg_ms)
	if _graphics_apply_callback.is_valid():
		_graphics_apply_callback.call(recommended)


func _apply_hysteresis(current_tier: int, recommended_tier: int) -> int:
	# Require a stronger signal to upgrade than to downgrade to avoid visual flapping.
	if recommended_tier > current_tier and get_average_frame_time_ms() > (1000.0 / 60.0) * 0.72:
		return current_tier
	return recommended_tier


func evaluate_terrain_runtime_budget(metrics: Dictionary) -> Dictionary:
	return _terrain_gate.evaluate(metrics)
