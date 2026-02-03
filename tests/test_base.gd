extends Node
class_name TestBase
## Simple unit test base class for Godot 4
##
## Usage:
## 1. Extend this class
## 2. Add methods starting with "test_"
## 3. Use assert_* methods to validate expectations
## 4. Run via TestRunner

signal test_completed(test_name: String, passed: bool, message: String)

var _current_test: String = ""
var _test_passed: bool = true
var _failure_message: String = ""

# Test counters
var passed_count: int = 0
var failed_count: int = 0
var total_count: int = 0


## Override to set up test fixtures before each test
func before_each() -> void:
	pass


## Override to clean up after each test
func after_each() -> void:
	pass


## Override to set up once before all tests
func before_all() -> void:
	pass


## Override to clean up once after all tests
func after_all() -> void:
	pass


## Run all test methods in this class
func run_all_tests() -> Dictionary:
	passed_count = 0
	failed_count = 0
	total_count = 0

	var results: Array[Dictionary] = []

	before_all()

	# Find all methods starting with "test_"
	var methods = get_method_list()
	for method in methods:
		var method_name: String = method.name
		if method_name.begins_with("test_"):
			var result = _run_single_test(method_name)
			results.append(result)

	after_all()

	return {
		"passed": passed_count,
		"failed": failed_count,
		"total": total_count,
		"results": results
	}


func _run_single_test(test_name: String) -> Dictionary:
	_current_test = test_name
	_test_passed = true
	_failure_message = ""
	total_count += 1

	before_each()

	# Run the test
	call(test_name)

	after_each()

	if _test_passed:
		passed_count += 1
	else:
		failed_count += 1

	var result = {
		"name": test_name,
		"passed": _test_passed,
		"message": _failure_message
	}

	test_completed.emit(test_name, _test_passed, _failure_message)
	return result


# =============================================================================
# ASSERTIONS
# =============================================================================

func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_fail("Expected true, got false. " + message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_fail("Expected false, got true. " + message)


func assert_eq(actual, expected, message: String = "") -> void:
	if actual != expected:
		_fail("Expected %s, got %s. %s" % [str(expected), str(actual), message])


func assert_ne(actual, not_expected, message: String = "") -> void:
	if actual == not_expected:
		_fail("Expected not %s, but got it. %s" % [str(not_expected), message])


func assert_null(value, message: String = "") -> void:
	if value != null:
		_fail("Expected null, got %s. %s" % [str(value), message])


func assert_not_null(value, message: String = "") -> void:
	if value == null:
		_fail("Expected non-null value. " + message)


func assert_gt(actual, expected, message: String = "") -> void:
	if actual <= expected:
		_fail("Expected %s > %s. %s" % [str(actual), str(expected), message])


func assert_gte(actual, expected, message: String = "") -> void:
	if actual < expected:
		_fail("Expected %s >= %s. %s" % [str(actual), str(expected), message])


func assert_lt(actual, expected, message: String = "") -> void:
	if actual >= expected:
		_fail("Expected %s < %s. %s" % [str(actual), str(expected), message])


func assert_lte(actual, expected, message: String = "") -> void:
	if actual > expected:
		_fail("Expected %s <= %s. %s" % [str(actual), str(expected), message])


func assert_in(item, collection, message: String = "") -> void:
	if item not in collection:
		_fail("Expected %s in collection. %s" % [str(item), message])


func assert_not_in(item, collection, message: String = "") -> void:
	if item in collection:
		_fail("Expected %s not in collection. %s" % [str(item), message])


func assert_empty(collection, message: String = "") -> void:
	if collection.size() > 0:
		_fail("Expected empty collection, got size %d. %s" % [collection.size(), message])


func assert_not_empty(collection, message: String = "") -> void:
	if collection.size() == 0:
		_fail("Expected non-empty collection. " + message)


func assert_size(collection, expected_size: int, message: String = "") -> void:
	if collection.size() != expected_size:
		_fail("Expected size %d, got %d. %s" % [expected_size, collection.size(), message])


func assert_approx(actual: float, expected: float, epsilon: float = 0.0001, message: String = "") -> void:
	if abs(actual - expected) > epsilon:
		_fail("Expected ~%f, got %f (epsilon: %f). %s" % [expected, actual, epsilon, message])


func assert_vector2i_eq(actual: Vector2i, expected: Vector2i, message: String = "") -> void:
	if actual != expected:
		_fail("Expected Vector2i%s, got Vector2i%s. %s" % [str(expected), str(actual), message])


func _fail(message: String) -> void:
	_test_passed = false
	_failure_message = message
