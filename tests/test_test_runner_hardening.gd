extends TestBase

const TestRunnerScript = preload("res://tests/test_runner.gd")
var _runner: Node = null


func after_each() -> void:
	if is_instance_valid(_runner):
		_runner.free()
	_runner = null


func test_is_instantiable_test_script_filters_invalid_values() -> void:
	_runner = TestRunnerScript.new()
	assert_false(_runner._is_instantiable_test_script(null))
	assert_false(_runner._is_instantiable_test_script("not_script"))


func test_is_instantiable_test_script_accepts_valid_test_script() -> void:
	_runner = TestRunnerScript.new()
	var valid = preload("res://tests/test_grid_constants.gd")
	assert_true(_runner._is_instantiable_test_script(valid))
