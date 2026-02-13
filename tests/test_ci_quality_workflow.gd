extends TestBase


func test_quality_workflow_exists_and_runs_required_gates() -> void:
	var path = "res://.github/workflows/quality-gates.yml"
	assert_true(FileAccess.file_exists(path))

	var file = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var content = file.get_as_text()
	file.close()

	assert_true(content.find("GODOT_VERSION: \"4.6-stable\"") >= 0)
	assert_true(content.find("Godot_v4.6-stable_linux.x86_64.zip") >= 0)
	assert_true(content.find("\"${GODOT_BIN}\" --headless -s tests/run_headless.gd") >= 0)
	assert_true(content.find("\"${GODOT_BIN}\" --headless -s res://scripts/terrain_perf_gate.gd") >= 0)
	assert_true(content.find("\"${GODOT_BIN}\" --headless -s res://scripts/run_visual_parity_matrix_ci.gd") >= 0)
