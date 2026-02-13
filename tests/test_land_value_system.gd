extends TestBase
## Tests for LandValueSystem value calculations

const LandValueScript = preload("res://src/systems/land_value_system.gd")

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


func _make_system() -> Node:
	return _track(LandValueScript.new())


func test_base_value_is_0_5() -> void:
	var sys = _make_system()
	# No systems connected, so value = base 0.5 - crime penalty (depends on GameState)
	GameState.city_crime_rate = 0.0
	var val = sys._calculate_cell_value(Vector2i(5, 5))
	assert_approx(val, 0.5, 0.01)


func test_park_boost_increases_value() -> void:
	var sys = _make_system()
	GameState.city_crime_rate = 0.0
	sys.park_boost_map[Vector2i(5, 5)] = 0.2
	var val = sys._calculate_cell_value(Vector2i(5, 5))
	assert_approx(val, 0.7, 0.01)


func test_transit_premium_increases_value() -> void:
	var sys = _make_system()
	GameState.city_crime_rate = 0.0
	sys.transit_premium_map[Vector2i(5, 5)] = 0.15
	var val = sys._calculate_cell_value(Vector2i(5, 5))
	assert_approx(val, 0.65, 0.01)


func test_crime_penalty_reduces_value() -> void:
	var sys = _make_system()
	GameState.city_crime_rate = 0.5  # High crime
	var val = sys._calculate_cell_value(Vector2i(5, 5))
	# penalty = (0.5 - 0.1) * 0.3 = 0.12, so value = 0.5 - 0.12 = 0.38
	assert_approx(val, 0.38, 0.01)
	GameState.city_crime_rate = 0.0  # Reset


func test_water_proximity_bonus() -> void:
	var sys = _make_system()
	GameState.city_crime_rate = 0.0
	sys.water_proximity_map[Vector2i(5, 5)] = 0.2
	var val = sys._calculate_cell_value(Vector2i(5, 5))
	assert_approx(val, 0.7, 0.01)


func test_elevation_view_bonus() -> void:
	var sys = _make_system()
	GameState.city_crime_rate = 0.0
	sys.elevation_bonus_map[Vector2i(5, 5)] = 0.1
	var val = sys._calculate_cell_value(Vector2i(5, 5))
	assert_approx(val, 0.6, 0.01)


func test_value_clamped_to_range() -> void:
	var sys = _make_system()
	GameState.city_crime_rate = 0.0
	# Stack a lot of bonuses
	sys.park_boost_map[Vector2i(5, 5)] = 0.5
	sys.transit_premium_map[Vector2i(5, 5)] = 0.35
	sys.water_proximity_map[Vector2i(5, 5)] = 0.3
	sys.elevation_bonus_map[Vector2i(5, 5)] = 0.1
	var val = sys._calculate_cell_value(Vector2i(5, 5))
	assert_true(val <= 1.0, "Value should be clamped to 1.0")
	assert_true(val >= 0.1, "Value should be at least 0.1")


func test_get_average_land_value_empty() -> void:
	var sys = _make_system()
	assert_approx(sys.get_average_land_value(), 0.5, 0.01)


func test_get_average_land_value_computed() -> void:
	var sys = _make_system()
	sys.land_value_map[Vector2i(0, 0)] = 0.4
	sys.land_value_map[Vector2i(1, 0)] = 0.6
	assert_approx(sys.get_average_land_value(), 0.5, 0.01)


func test_get_tax_multiplier_at_low_value() -> void:
	var sys = _make_system()
	sys.land_value_map[Vector2i(0, 0)] = 0.1
	var mult = sys.get_tax_multiplier_at(Vector2i(0, 0))
	# 0.5 + 0.1 * 1.0 = 0.6
	assert_approx(mult, 0.6, 0.01)


func test_get_tax_multiplier_at_high_value() -> void:
	var sys = _make_system()
	sys.land_value_map[Vector2i(0, 0)] = 1.0
	var mult = sys.get_tax_multiplier_at(Vector2i(0, 0))
	# 0.5 + 1.0 * 1.0 = 1.5
	assert_approx(mult, 1.5, 0.01)
