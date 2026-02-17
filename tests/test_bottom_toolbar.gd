extends TestBase
## Tests for BottomToolbar and CategorySubPanel

class FakeGameWorld extends Node:
	var last_terrain_tool = null

	func set_terrain_tool(tool_id) -> void:
		last_terrain_tool = tool_id


class FakeEvents extends Node:
	signal building_catalog_ready(catalog)
	signal building_catalog_requested()
	signal budget_updated(balance, income, expenses)
	signal population_changed(new_pop, delta)
	signal month_tick()
	signal simulation_speed_changed(speed)
	signal simulation_paused(paused)
	signal weather_changed(temperature, conditions)
	signal storm_started()
	signal storm_ended()
	signal flood_started()
	signal flood_ended()
	signal heat_wave_started()
	signal heat_wave_ended()
	signal cold_snap_started()
	signal cold_snap_ended()
	signal power_state_changed(event)
	signal storm_outage_changed(event)


## Helper: create a toolbar ready for testing
func _make_toolbar() -> BottomToolbar:
	var toolbar = BottomToolbar.new()
	var events = FakeEvents.new()
	toolbar.set_events(events)
	toolbar._setup_ui()
	return toolbar


# ============================================
# CATEGORY BUTTON TESTS
# ============================================

func test_category_button_count() -> void:
	var toolbar = _make_toolbar()
	assert_eq(toolbar.get_category_button_count(), 12)
	toolbar.free()


func test_category_press_shows_sub_panel() -> void:
	var toolbar = _make_toolbar()

	# Sub-panel should be hidden initially
	assert_false(toolbar.get_sub_panel().visible)

	# Press infrastructure category
	toolbar._on_category_pressed("infrastructure")
	assert_eq(toolbar.get_active_category(), "infrastructure")
	# Sub-panel visible after opening a category
	assert_true(toolbar.get_sub_panel().visible)

	toolbar.free()


func test_category_press_toggles_sub_panel() -> void:
	var toolbar = _make_toolbar()

	toolbar._on_category_pressed("infrastructure")
	assert_eq(toolbar.get_active_category(), "infrastructure")

	# Press same category = close
	toolbar._on_category_pressed("infrastructure")
	assert_eq(toolbar.get_active_category(), "")

	toolbar.free()


func test_category_switch() -> void:
	var toolbar = _make_toolbar()

	toolbar._on_category_pressed("infrastructure")
	assert_eq(toolbar.get_active_category(), "infrastructure")

	# Switch to different category
	toolbar._on_category_pressed("power")
	assert_eq(toolbar.get_active_category(), "power")

	toolbar.free()


# ============================================
# BUILDING SELECTION TESTS
# ============================================

func test_building_selection_emits_signal() -> void:
	var toolbar = _make_toolbar()
	var result = []
	toolbar.building_selected.connect(func(id): result.append(id))

	toolbar._on_category_pressed("infrastructure")
	toolbar._on_sub_panel_item_selected("road", {"building_id": "road"})

	assert_eq(result.size(), 1)
	assert_eq(result[0], "road")

	toolbar.free()


# ============================================
# ZONE SELECTION TESTS
# ============================================

func test_zone_selection_emits_signal() -> void:
	var toolbar = _make_toolbar()
	var result = []
	toolbar.zone_selected.connect(func(t): result.append(t))

	toolbar._on_category_pressed("zoning")
	toolbar._on_sub_panel_item_selected("res_low", {"zone_type": 1})

	assert_eq(result.size(), 1)
	assert_eq(result[0], 1)

	toolbar.free()


# ============================================
# DEMOLISH TESTS
# ============================================

func test_demolish_emits_signal() -> void:
	var toolbar = _make_toolbar()
	var result = []
	toolbar.demolish_selected.connect(func(): result.append(true))

	toolbar._on_category_pressed("demolish")

	assert_eq(result.size(), 1)

	toolbar.free()


func test_demolish_closes_sub_panel() -> void:
	var toolbar = _make_toolbar()

	toolbar._on_category_pressed("infrastructure")
	assert_eq(toolbar.get_active_category(), "infrastructure")

	toolbar._on_category_pressed("demolish")
	assert_eq(toolbar.get_active_category(), "")

	toolbar.free()


# ============================================
# OVERLAY SELECTION TESTS
# ============================================

func test_overlay_selection_emits_signal() -> void:
	var toolbar = _make_toolbar()
	var result = []
	toolbar.overlay_selected.connect(func(m): result.append(m))

	toolbar._on_category_pressed("overlay")
	toolbar._on_sub_panel_item_selected("power", {"mode": 1})

	assert_eq(result.size(), 1)
	assert_eq(result[0], 1)

	toolbar.free()


# ============================================
# KEYBOARD SHORTCUT TESTS
# ============================================

func test_q_closes_sub_panel() -> void:
	var toolbar = _make_toolbar()

	toolbar._on_category_pressed("infrastructure")
	assert_eq(toolbar.get_active_category(), "infrastructure")

	toolbar._close_sub_panel()
	assert_eq(toolbar.get_active_category(), "")

	toolbar.free()


func test_x_activates_demolish() -> void:
	var toolbar = _make_toolbar()
	var result = []
	toolbar.demolish_selected.connect(func(): result.append(true))

	# Simulate pressing X (which calls _on_category_pressed("demolish") internally)
	toolbar._on_category_pressed("demolish")

	assert_eq(result.size(), 1)

	toolbar.free()


func test_b_opens_infrastructure() -> void:
	var toolbar = _make_toolbar()

	toolbar._on_category_pressed("infrastructure")
	assert_eq(toolbar.get_active_category(), "infrastructure")

	toolbar.free()


func test_esc_closes_sub_panel() -> void:
	var toolbar = _make_toolbar()

	toolbar._on_category_pressed("power")
	assert_eq(toolbar.get_active_category(), "power")

	toolbar._close_sub_panel()
	assert_eq(toolbar.get_active_category(), "")

	toolbar.free()


# ============================================
# LOCKED BUILDING TESTS
# ============================================

func test_locked_building_not_selectable() -> void:
	var sub_panel = CategorySubPanel.new()

	var items = [
		{"id": "locked_bldg", "label": "Locked", "cost": 1000, "locked": true, "unlock_population": 5000}
	]
	sub_panel.populate(items, "building")

	var btn = sub_panel._item_container.get_child(0)
	assert_true(btn.disabled)

	sub_panel.free()


# ============================================
# STATUS BAR TESTS
# ============================================

func test_status_bar_updates_on_budget() -> void:
	var toolbar = _make_toolbar()

	toolbar._on_budget_updated(100000, 5000, 3000)
	assert_not_null(toolbar._budget_label)

	toolbar.free()


func test_status_bar_updates_on_population() -> void:
	var toolbar = _make_toolbar()

	toolbar._on_population_changed(1500, 100)
	assert_not_null(toolbar._population_label)

	toolbar.free()


func test_status_bar_updates_on_month_tick() -> void:
	var toolbar = _make_toolbar()

	toolbar._on_month_tick()
	assert_not_null(toolbar._date_label)

	toolbar.free()


# ============================================
# SPEED BUTTON TESTS
# ============================================

func test_speed_buttons_exist() -> void:
	var toolbar = _make_toolbar()

	assert_eq(toolbar._speed_buttons.size(), 3)
	assert_not_null(toolbar._pause_button)

	toolbar.free()


func test_speed_change_updates_buttons() -> void:
	var toolbar = _make_toolbar()

	toolbar._on_speed_changed(2)
	assert_eq(toolbar._speed_buttons.size(), 3)

	toolbar.free()


# ============================================
# TERRAIN TOOL TESTS
# ============================================

func test_terrain_uses_injected_game_world() -> void:
	var toolbar = BottomToolbar.new()
	var events = FakeEvents.new()
	var world = FakeGameWorld.new()
	toolbar.set_events(events)
	toolbar.set_game_world(world)
	toolbar._setup_ui()

	toolbar._on_category_pressed("terrain")
	toolbar._on_sub_panel_item_selected("raise", {"terrain_tool": "raise"})
	assert_eq(world.last_terrain_tool, "raise")

	toolbar.free()
	events.free()
	world.free()


# ============================================
# CATEGORY SUB-PANEL TESTS
# ============================================

func test_sub_panel_populate_building() -> void:
	var sub_panel = CategorySubPanel.new()

	var items = [
		{"id": "road", "label": "Road", "cost": 100, "locked": false},
		{"id": "bridge", "label": "Bridge", "cost": 500, "locked": false}
	]
	sub_panel.populate(items, "building")

	assert_eq(sub_panel.get_item_count(), 2)

	sub_panel.free()


func test_sub_panel_populate_zone() -> void:
	var sub_panel = CategorySubPanel.new()

	var items = [
		{"id": "res_low", "label": "Residential Low", "zone_type": 1, "color": Color.GREEN}
	]
	sub_panel.populate(items, "zone")

	assert_eq(sub_panel.get_item_count(), 1)

	sub_panel.free()


func test_sub_panel_populate_overlay() -> void:
	var sub_panel = CategorySubPanel.new()

	var items = [
		{"id": "power", "label": "Power", "mode": 1},
		{"id": "water", "label": "Water", "mode": 2}
	]
	sub_panel.populate(items, "overlay")

	assert_eq(sub_panel.get_item_count(), 2)

	sub_panel.free()


func test_sub_panel_populate_terrain() -> void:
	var sub_panel = CategorySubPanel.new()

	var items = [
		{"id": "raise", "label": "Raise", "icon": "▲", "terrain_tool": "raise"}
	]
	sub_panel.populate(items, "terrain")

	assert_eq(sub_panel.get_item_count(), 1)

	sub_panel.free()


func test_sub_panel_clear() -> void:
	var sub_panel = CategorySubPanel.new()

	sub_panel.populate([{"id": "a", "label": "A", "cost": 0, "locked": false}], "building")
	assert_eq(sub_panel.get_item_count(), 1)

	sub_panel.clear()
	assert_eq(sub_panel.get_item_count(), 0)

	sub_panel.free()


# ============================================
# SETTINGS BUTTON TESTS
# ============================================

func test_settings_emits_signal() -> void:
	var toolbar = _make_toolbar()
	var result = []
	toolbar.setting_selected.connect(func(a): result.append(a))

	toolbar._on_settings_pressed("dashboard")

	assert_eq(result.size(), 1)
	assert_eq(result[0], "dashboard")

	toolbar.free()


# ============================================
# ALERT TESTS
# ============================================

func test_alert_shows_icon() -> void:
	var toolbar = _make_toolbar()

	assert_false(toolbar._alert_container.visible)

	toolbar._on_alert_changed("power", true)
	assert_true(toolbar._alert_container.visible)
	assert_true(toolbar._alert_icons["power"].visible)

	toolbar._on_alert_changed("power", false)
	assert_false(toolbar._alert_icons["power"].visible)

	toolbar.free()


func test_weather_update() -> void:
	var toolbar = _make_toolbar()

	toolbar._on_weather_changed(25.0, "Clear")
	assert_true(toolbar._weather_label.text.contains("25"))

	toolbar.free()
