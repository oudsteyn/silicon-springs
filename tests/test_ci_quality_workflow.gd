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
	assert_true(content.find("./scripts/run_tests_strict.sh \"${GODOT_BIN}\"") >= 0)
	assert_true(content.find("\"${GODOT_BIN}\" --headless -s res://scripts/terrain_perf_gate.gd") >= 0)
	assert_true(content.find("\"${GODOT_BIN}\" --headless -s res://scripts/run_visual_parity_matrix_ci.gd") >= 0)


func test_strict_test_runner_script_exists_and_scans_for_runtime_errors() -> void:
	var path = "res://scripts/run_tests_strict.sh"
	assert_true(FileAccess.file_exists(path))
	var file = FileAccess.open(path, FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return
	var content = file.get_as_text()
	file.close()
	assert_true(content.find("SCRIPT ERROR:") >= 0)
	assert_true(content.find("ObjectDB instances leaked at exit") >= 0)
