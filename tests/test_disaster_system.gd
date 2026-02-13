extends TestBase
## Tests for DisasterSystem logic

const DisasterScript = preload("res://src/systems/disaster_system.gd")

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


class MockGridSystem:
	var _buildings: Dictionary = {}
	var _cells: Array[Vector2i] = []

	func has_building_at(cell: Vector2i) -> bool:
		return _buildings.has(cell)

	func get_building_at(cell: Vector2i):
		return _buildings.get(cell)

	func get_building_count() -> int:
		return _buildings.size()

	func get_building_cells() -> Array[Vector2i]:
		return _cells

	func remove_building(_cell: Vector2i) -> void:
		pass


class MockTerrainSystem:
	var _elevations: Dictionary = {}
	var _water: Dictionary = {}
	var water: Dictionary = {}

	func get_elevation(cell: Vector2i) -> int:
		return _elevations.get(cell, 0)

	func has_water_nearby(_cell: Vector2i, _radius: int) -> bool:
		return false


func _make_system() -> Node:
	var sys = _track(DisasterScript.new())
	sys.grid_system = MockGridSystem.new()
	return sys


func test_process_monthly_decrements_disaster_duration() -> void:
	var sys = _make_system()
	sys.active_disasters.append({
		"type": "flood",
		"buildings": [],
		"months_remaining": 3
	})

	sys.process_monthly()

	assert_eq(sys.active_disasters[0].months_remaining, 2)


func test_process_monthly_removes_expired_disasters() -> void:
	var sys = _make_system()
	sys.active_disasters.append({
		"type": "flood",
		"buildings": [],
		"months_remaining": 1
	})

	sys.process_monthly()

	assert_eq(sys.active_disasters.size(), 0)


func test_process_monthly_emits_ended_signal() -> void:
	var sys = _make_system()
	var ended_types: Array = []
	sys.disaster_ended.connect(func(t): ended_types.append(t))

	sys.active_disasters.append({
		"type": "flood",
		"buildings": [],
		"months_remaining": 1
	})

	sys.process_monthly()

	assert_eq(ended_types.size(), 1)
	assert_eq(ended_types[0], "flood")


func test_trigger_disaster_respects_disabled() -> void:
	var sys = _make_system()
	GameConfig.disasters_enabled = false

	var started = false
	sys.disaster_started.connect(func(_t, _c, _r): started = true)

	sys.trigger_disaster(DisasterSystem.DisasterType.FIRE, Vector2i(5, 5))

	assert_false(started, "Disaster should not start when disabled")

	# Restore
	GameConfig.disasters_enabled = true


func test_get_random_building_location_no_buildings() -> void:
	var sys = _make_system()
	var loc = sys._get_random_building_location()
	assert_eq(loc, Vector2i(-1, -1))


func test_calculate_flood_risk_low_elevation() -> void:
	var sys = _make_system()
	var terrain = MockTerrainSystem.new()
	terrain._elevations[Vector2i(5, 5)] = -2
	sys.terrain_system = terrain

	var risk = sys._calculate_flood_risk_at(Vector2i(5, 5))
	assert_approx(risk, 0.8, 0.01)


func test_calculate_flood_risk_high_elevation() -> void:
	var sys = _make_system()
	var terrain = MockTerrainSystem.new()
	terrain._elevations[Vector2i(5, 5)] = 3
	sys.terrain_system = terrain

	var risk = sys._calculate_flood_risk_at(Vector2i(5, 5))
	assert_approx(risk, 0.0, 0.01)


func test_calculate_flood_risk_no_terrain() -> void:
	var sys = _make_system()
	sys.terrain_system = null

	var risk = sys._calculate_flood_risk_at(Vector2i(5, 5))
	assert_approx(risk, 0.1, 0.01)


func test_on_simulation_event_routes_storm_damage() -> void:
	var sys = _make_system()
	# Should not crash even with empty grid
	sys._on_simulation_event("storm_damage", {"severity": 1.0})
	assert_true(true, "Did not crash")


func test_on_simulation_event_ignores_unknown() -> void:
	var sys = _make_system()
	sys._on_simulation_event("unknown_event", {})
	assert_true(true, "Did not crash")
