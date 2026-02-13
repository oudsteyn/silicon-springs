extends TestBase
## Tests for DashboardInfrastructureTab road condition lookup and InfrastructureAgeSystem

const InfraTabScript = preload("res://src/ui/dashboard/infrastructure_tab.gd")
const InfraAgeScript = preload("res://src/systems/infrastructure_age_system.gd")

var _to_free: Array = []


func after_each() -> void:
	for i in range(_to_free.size() - 1, -1, -1):
		var instance = _to_free[i]
		if is_instance_valid(instance) and not (instance is RefCounted):
			instance.free()
	_to_free.clear()


func _track(instance):
	_to_free.append(instance)
	return instance


func test_get_road_condition_returns_fallback_when_no_system() -> void:
	var tab = _track(InfraTabScript.new())
	var condition = tab._get_road_condition()
	assert_approx(condition, 85.0, 0.1)


func test_get_average_condition_road_averages_road_types() -> void:
	var sys = _track(InfraAgeScript.new())
	# Inject fake infrastructure data
	sys.infrastructure_age[100] = {"age": 5, "condition": 80.0, "cell": Vector2i(0,0), "type": "road"}
	sys.infrastructure_age[101] = {"age": 5, "condition": 60.0, "cell": Vector2i(1,0), "type": "highway"}

	var avg = sys.get_average_condition("road")
	assert_approx(avg, 70.0, 0.01)


func test_get_average_condition_utility_averages_pipes_and_lines() -> void:
	var sys = _track(InfraAgeScript.new())
	sys.infrastructure_age[200] = {"age": 3, "condition": 90.0, "cell": Vector2i(0,0), "type": "power_line"}
	sys.infrastructure_age[201] = {"age": 3, "condition": 50.0, "cell": Vector2i(1,0), "type": "water_pipe"}

	var avg = sys.get_average_condition("utility")
	assert_approx(avg, 70.0, 0.01)


func test_get_average_condition_returns_100_when_no_matches() -> void:
	var sys = _track(InfraAgeScript.new())
	var avg = sys.get_average_condition("road")
	assert_approx(avg, 100.0, 0.01)


func test_get_average_condition_specific_type() -> void:
	var sys = _track(InfraAgeScript.new())
	sys.infrastructure_age[300] = {"age": 1, "condition": 75.0, "cell": Vector2i(0,0), "type": "power_line"}
	sys.infrastructure_age[301] = {"age": 1, "condition": 50.0, "cell": Vector2i(1,0), "type": "road"}

	# Querying specific type should only match that type
	var avg = sys.get_average_condition("power_line")
	assert_approx(avg, 75.0, 0.01)
