extends Node
class_name TestRunner
## Runs all test classes and reports results
##
## Usage:
## 1. Add TestRunner to a scene
## 2. Add test class scripts via add_test_class()
## 3. Call run_all() to execute tests
##
## Or run from command line:
##   godot --headless -s tests/test_runner.gd

const COLOR_PASS = "\u001b[32m"  # Green
const COLOR_FAIL = "\u001b[31m"  # Red
const COLOR_RESET = "\u001b[0m"
const COLOR_BOLD = "\u001b[1m"

var test_classes: Array[Script] = []
var verbose: bool = true
var _has_run: bool = false
var _discovery_failures: Array[String] = []


func _ready() -> void:
	# If running as main scene, auto-run tests
	if not _has_run and (get_tree().current_scene == self or get_tree().current_scene == null):
		_run_from_command_line()


func _run_from_command_line() -> void:
	if _has_run:
		return
	_has_run = true
	print("\n" + COLOR_BOLD + "=== Test Runner ===" + COLOR_RESET + "\n")

	# Auto-discover and load test classes
	_discover_tests()

	# Run tests
	var results = run_all()

	# Print summary
	print("\n" + COLOR_BOLD + "=== Summary ===" + COLOR_RESET)
	print("Total: %d | Passed: %s%d%s | Failed: %s%d%s" % [
		results.total,
		COLOR_PASS, results.passed, COLOR_RESET,
		COLOR_FAIL if results.failed > 0 else "", results.failed, COLOR_RESET
	])

	# Exit with appropriate code
	if results.failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)


func _discover_tests() -> void:
	var test_dir = "res://tests/"
	var dir = DirAccess.open(test_dir)
	if not dir:
		push_error("Could not open tests directory: " + test_dir)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			if file_name != "test_base.gd" and file_name != "test_runner.gd":
				var script_path = test_dir + file_name
				var script = load(script_path)
				if _is_instantiable_test_script(script):
					test_classes.append(script)
					if verbose:
						print("Discovered: " + file_name)
				else:
					_discovery_failures.append(script_path)
		file_name = dir.get_next()

	dir.list_dir_end()


func add_test_class(script: Script) -> void:
	test_classes.append(script)


func run_all() -> Dictionary:
	var total_passed: int = 0
	var total_failed: int = _discovery_failures.size()
	var total_tests: int = _discovery_failures.size()
	var all_results: Array[Dictionary] = []
	for path in _discovery_failures:
		print("  " + COLOR_FAIL + "FAIL" + COLOR_RESET + " " + path.get_file())
		print("       Failed to load or instantiate test script")

	for test_script in test_classes:
		if not _is_instantiable_test_script(test_script):
			total_failed += 1
			total_tests += 1
			print("  " + COLOR_FAIL + "FAIL" + COLOR_RESET + " " + str(test_script))
			print("       Test script is not instantiable")
			continue
		var test_instance = test_script.new()
		if test_instance == null:
			total_failed += 1
			total_tests += 1
			print("  " + COLOR_FAIL + "FAIL" + COLOR_RESET + " " + test_script.resource_path.get_file())
			print("       Could not instantiate test script")
			continue
		add_child(test_instance)

		if verbose:
			print("\n" + COLOR_BOLD + "Running: " + test_script.resource_path.get_file() + COLOR_RESET)

		var results = test_instance.run_all_tests()

		for result in results.results:
			if result.passed:
				if verbose:
					print("  " + COLOR_PASS + "PASS" + COLOR_RESET + " " + result.name)
			else:
				print("  " + COLOR_FAIL + "FAIL" + COLOR_RESET + " " + result.name)
				print("       " + result.message)

		total_passed += results.passed
		total_failed += results.failed
		total_tests += results.total
		all_results.append({
			"class": test_script.resource_path.get_file(),
			"results": results
		})

		test_instance.free()

	return {
		"passed": total_passed,
		"failed": total_failed,
		"total": total_tests,
		"class_results": all_results
	}


func _is_instantiable_test_script(script) -> bool:
	if script == null:
		return false
	if not (script is Script):
		return false
	return script.can_instantiate()
