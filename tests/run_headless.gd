extends SceneTree
## Headless test entry point for CLI execution

func _initialize() -> void:
	var logs_dir := "user://logs"
	var dir := DirAccess.open("user://")
	if dir:
		dir.make_dir_recursive_absolute(logs_dir)
	call_deferred("_start_tests")


func _start_tests() -> void:
	var runner_script = load("res://tests/test_runner.gd")
	var runner = runner_script.new()
	root.add_child(runner)
	runner._run_from_command_line()
