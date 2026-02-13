extends TestBase

const NotificationBridgeScript = preload("res://src/autoloads/notification_bridge.gd")

var _to_free: Array = []


func after_each() -> void:
	for i in range(_to_free.size() - 1, -1, -1):
		var instance = _to_free[i]
		if is_instance_valid(instance):
			instance.free()
	_to_free.clear()


func _track(instance):
	_to_free.append(instance)
	return instance


func test_weather_info_event_is_suppressed_without_direct_impact() -> void:
	var bridge = _track(NotificationBridgeScript.new())
	assert_false(bridge._should_emit_city_impact_notification("air_quality_changed", {}, "info"))


func test_weather_warning_event_is_suppressed_without_direct_impact() -> void:
	var bridge = _track(NotificationBridgeScript.new())
	assert_false(bridge._should_emit_city_impact_notification("storm_started", {}, "warning"))


func test_weather_event_with_direct_city_impact_is_allowed() -> void:
	var bridge = _track(NotificationBridgeScript.new())
	assert_true(bridge._should_emit_city_impact_notification("air_quality_changed", {"affected_percent": 12.5}, "warning"))


func test_city_impact_event_is_allowed() -> void:
	var bridge = _track(NotificationBridgeScript.new())
	assert_true(bridge._should_emit_city_impact_notification("storm_building_damage", {"count": 3}, "warning"))


func test_zero_impact_payload_is_suppressed() -> void:
	var bridge = _track(NotificationBridgeScript.new())
	assert_false(bridge._should_emit_city_impact_notification("wildfire_ongoing", {"count": 0}, "info"))
