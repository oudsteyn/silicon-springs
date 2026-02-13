extends SceneTree

const VisualParityCliScript = preload("res://src/graphics/visual_parity_cli.gd")
const VisualParityMatrixRunnerScript = preload("res://src/graphics/visual_parity_matrix_runner.gd")


func _init() -> void:
	var baseline_root = "user://visual_parity_matrix_baselines"
	var artifact_root = "user://visual_parity_matrix_artifacts"

	var cli = VisualParityCliScript.new()
	var matrix_runner = VisualParityMatrixRunnerScript.new()
	var result = matrix_runner.run_matrix(baseline_root, artifact_root, cli)

	print(JSON.stringify(result, "\t", true, true))
	quit(int(result.get("exit_code", 1)))
