extends TestBase
## Tests for ActionFeedbackEffects simulation event handling

const ActionFeedbackScript = preload("res://src/ui/grid/action_feedback_effects.gd")

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


func _make_effects() -> ActionFeedbackEffects:
	var effects = _track(ActionFeedbackScript.new())
	return effects


# === Simulation Event → Effect Spawning Tests ===

func test_rocks_cleared_spawns_demolition_effect() -> void:
	var effects = _make_effects()
	var cell = Vector2i(5, 5)

	effects._on_simulation_event("rocks_cleared", {"cell": cell})

	assert_eq(effects._effects.size(), 1, "Should spawn one effect")
	assert_eq(effects._effects[0].type, ActionFeedbackEffects.EffectType.DEMOLITION)


func test_trees_cleared_spawns_demolition_effect() -> void:
	var effects = _make_effects()
	var cell = Vector2i(6, 6)

	effects._on_simulation_event("trees_cleared", {"cell": cell})

	assert_eq(effects._effects.size(), 1, "Should spawn one effect")
	assert_eq(effects._effects[0].type, ActionFeedbackEffects.EffectType.DEMOLITION)


func test_zone_cleared_spawns_demolition_effect() -> void:
	var effects = _make_effects()
	var cell = Vector2i(7, 7)

	effects._on_simulation_event("zone_cleared", {"cell": cell})

	assert_eq(effects._effects.size(), 1, "Should spawn one effect")
	assert_eq(effects._effects[0].type, ActionFeedbackEffects.EffectType.DEMOLITION)


func test_beach_cleared_spawns_demolition_effect() -> void:
	var effects = _make_effects()
	var cell = Vector2i(8, 8)

	effects._on_simulation_event("beach_cleared", {"cell": cell})

	assert_eq(effects._effects.size(), 1, "Should spawn one effect")
	assert_eq(effects._effects[0].type, ActionFeedbackEffects.EffectType.DEMOLITION)


func test_insufficient_funds_spawns_placement_fail_effect() -> void:
	var effects = _make_effects()
	var cell = Vector2i(3, 3)

	effects._on_simulation_event("insufficient_funds", {"cell": cell})

	assert_eq(effects._effects.size(), 1, "Should spawn one effect")
	assert_eq(effects._effects[0].type, ActionFeedbackEffects.EffectType.PLACEMENT_FAIL)


func test_building_upgraded_spawns_upgrade_effect() -> void:
	var effects = _make_effects()
	var cell = Vector2i(4, 4)

	effects._on_simulation_event("building_upgraded", {"cell": cell})

	assert_eq(effects._effects.size(), 1, "Should spawn one effect")
	assert_eq(effects._effects[0].type, ActionFeedbackEffects.EffectType.UPGRADE)


func test_event_with_invalid_cell_spawns_nothing() -> void:
	var effects = _make_effects()

	effects._on_simulation_event("rocks_cleared", {})

	assert_eq(effects._effects.size(), 0, "Should not spawn effect without valid cell")


func test_unknown_event_spawns_nothing() -> void:
	var effects = _make_effects()

	effects._on_simulation_event("some_unknown_event", {"cell": Vector2i(1, 1)})

	assert_eq(effects._effects.size(), 0, "Unknown event should not spawn any effect")


func test_zone_painted_spawns_nothing() -> void:
	var effects = _make_effects()

	effects._on_simulation_event("zone_painted", {"cell": Vector2i(1, 1)})

	assert_eq(effects._effects.size(), 0, "zone_painted handled separately, should not spawn here")


func test_path_built_spawns_nothing() -> void:
	var effects = _make_effects()

	effects._on_simulation_event("path_built", {"cell": Vector2i(1, 1)})

	assert_eq(effects._effects.size(), 0, "path_built handled separately, should not spawn here")
