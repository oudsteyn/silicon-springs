extends Node

signal quality_recommendation_changed(recommended_tier: int, avg_frame_ms: float)

enum QualityTier {
	LOW,
	MEDIUM,
	HIGH
}

@export var sample_window_size: int = 120
@export var enabled: bool = true

var _frame_times_ms: Array[float] = []
var _graphics_apply_callback: Callable = Callable()
var _last_recommendation: int = -1

func _process(delta: float) -> void:
	if not enabled:
		return
	ingest_frame_time_ms(delta * 1000.0)

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
	if avg_ms <= target_ms * 0.82:
		return QualityTier.HIGH
	if avg_ms <= target_ms * 1.18:
		return QualityTier.MEDIUM
	return QualityTier.LOW

func set_graphics_apply_callback(callback: Callable) -> void:
	_graphics_apply_callback = callback

func apply_auto_tuning(target_fps: int = 60) -> void:
	var recommended = recommend_quality_preset(target_fps)
	if recommended == _last_recommendation:
		return
	_last_recommendation = recommended

	var avg_ms = get_average_frame_time_ms()
	quality_recommendation_changed.emit(recommended, avg_ms)
	if _graphics_apply_callback.is_valid():
		_graphics_apply_callback.call(recommended)
