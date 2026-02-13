extends SceneTree

const TerrainPerfCiGateScript = preload("res://src/terrain/terrain_perf_ci_gate.gd")


func _init() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() < 1:
		printerr("Usage: godot --headless -s res://scripts/terrain_perf_gate.gd <metrics.json>")
		quit(2)
		return

	var metrics_path = args[0]
	var metrics = _load_metrics(metrics_path)
	if metrics.is_empty():
		printerr("terrain_perf_gate: metrics file is empty or invalid: %s" % metrics_path)
		quit(2)
		return

	var gate = TerrainPerfCiGateScript.new()
	var result = gate.evaluate_metrics(metrics)
	print(result.get("summary_markdown", ""))
	quit(int(result.get("exit_code", 1)))


func _load_metrics(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text = file.get_as_text()
	var json = JSON.new()
	if json.parse(text) != OK:
		return {}
	var data = json.data
	if data is Dictionary:
		return data
	return {}
