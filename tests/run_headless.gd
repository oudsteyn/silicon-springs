extends SceneTree
## Headless test entry point for CLI execution

func _initialize() -> void:
	call_deferred("_start_tests")


func _start_tests() -> void:
	var runner_script = load("res://tests/test_runner.gd")
	var runner = runner_script.new()
	root.add_child(runner)
	runner._run_from_command_line()
