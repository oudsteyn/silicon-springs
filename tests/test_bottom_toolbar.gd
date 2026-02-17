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


# ============================================
# ROAD DATA TESTS
# ============================================

const BuildingDataScript = preload("res://src/resources/building_data.gd")


func _make_road_data(id: String, name: String, cost: int, capacity: int, speed: float) -> Resource:
	var data = BuildingDataScript.new()
	data.id = id
	data.display_name = name
	data.description = "Test road"
	data.tooltip = "Test tooltip for %s" % name
	data.category = "infrastructure"
	data.building_type = "road"
	data.build_cost = cost
	data.road_capacity = capacity
	data.road_speed = speed
	data.monthly_maintenance = 2
	data.noise_radius = 0
	data.allows_direct_access = true
	return data


func test_dirt_road_display_name() -> void:
	var data = load("res://src/data/dirt_road.tres")
	assert_eq(data.display_name, "Dirt Road")


func test_road_display_names() -> void:
	var expected = {
		"dirt_road": "Dirt Road",
		"road": "Road",
		"street": "Street",
		"avenue": "Avenue",
		"boulevard": "Boulevard",
		"parkway": "Parkway",
		"streetcar_parkway": "With Streetcars",
		"highway": "Highway"
	}
	for id in expected:
		var data = load("res://src/data/%s.tres" % id)
		assert_not_null(data, "Missing .tres for %s" % id)
		assert_eq(data.display_name, expected[id], "Wrong display_name for %s" % id)


func test_road_capacity_ordering() -> void:
	var ids = ["dirt_road", "road", "street", "avenue", "boulevard", "parkway", "streetcar_parkway"]
	var prev_cap = 0
	for id in ids:
		var data = load("res://src/data/%s.tres" % id)
		assert_gt(data.road_capacity, prev_cap, "%s capacity should exceed previous" % id)
		prev_cap = data.road_capacity


func test_all_roads_have_road_building_type() -> void:
	var ids = ["dirt_road", "road", "street", "avenue", "boulevard", "parkway", "streetcar_parkway"]
	for id in ids:
		var data = load("res://src/data/%s.tres" % id)
		assert_eq(data.building_type, "road", "%s should have building_type road" % id)
	# Highway uses its own building_type
	var hw = load("res://src/data/highway.tres")
	assert_eq(hw.building_type, "highway")


func test_all_roads_in_infrastructure_category() -> void:
	var ids = ["dirt_road", "road", "street", "avenue", "boulevard", "parkway", "streetcar_parkway", "highway"]
	for id in ids:
		var data = load("res://src/data/%s.tres" % id)
		assert_eq(data.category, "infrastructure", "%s should be in infrastructure category" % id)


# ============================================
# BUILDING CATALOG RESOURCE PASS-THROUGH
# ============================================

func test_populate_build_items_passes_building_data() -> void:
	var toolbar = _make_toolbar()
	var road_data = _make_road_data("test_road", "Test Road", 100, 50, 0.8)

	# Simulate catalog with resource
	toolbar._building_catalog = {
		"infrastructure": [
			{"id": "test_road", "display_name": "Test Road", "build_cost": 100, "category": "infrastructure", "resource": road_data}
		]
	}

	toolbar._on_category_pressed("infrastructure")
	var sub = toolbar.get_sub_panel()
	assert_gt(sub.get_item_count(), 0, "Sub-panel should have items")

	toolbar.free()


# ============================================
# TOOLTIP TESTS
# ============================================

func test_sub_panel_tooltip_created_on_hover() -> void:
	var sub_panel = CategorySubPanel.new()
	var road_data = _make_road_data("road", "Road", 100, 50, 0.8)

	sub_panel.populate([
		{"id": "road", "label": "Road", "cost": 100, "locked": false, "building_data": road_data}
	], "building")

	# Simulate hover on the button
	var btn = sub_panel._item_container.get_child(0)
	assert_true(btn.has_meta("tooltip_item") or btn.mouse_entered.get_connections().size() > 0,
		"Button should have tooltip hover connected")

	sub_panel.free()


func test_sub_panel_tooltip_populates_building_data() -> void:
	var sub_panel = CategorySubPanel.new()
	var road_data = _make_road_data("road", "Road", 100, 50, 0.8)
	road_data.noise_radius = 1

	sub_panel.populate([
		{"id": "road", "label": "Road", "cost": 100, "locked": false, "building_data": road_data}
	], "building")

	# Manually trigger tooltip population
	sub_panel._tooltip_target = sub_panel._item_container.get_child(0)
	sub_panel._tooltip_target.set_meta("tooltip_item", {"building_data": road_data})
	sub_panel._ensure_tooltip()
	sub_panel._populate_building_tooltip({"building_data": road_data})

	assert_eq(sub_panel._tooltip_name.text, "Road")
	assert_true(sub_panel._tooltip_stats.text.contains("Capacity: 50"))
	assert_true(sub_panel._tooltip_stats.text.contains("Speed: 0.8x"))
	assert_true(sub_panel._tooltip_stats.text.contains("Noise: 1"))

	sub_panel.free()


func test_sub_panel_tooltip_road_stats_always_show_speed() -> void:
	var sub_panel = CategorySubPanel.new()
	var road_data = _make_road_data("avenue", "Avenue", 350, 150, 1.0)

	sub_panel._ensure_tooltip()
	sub_panel._populate_building_tooltip({"building_data": road_data})

	assert_true(sub_panel._tooltip_stats.text.contains("Speed: 1.0x"),
		"Speed should show even when 1.0x for roads")

	sub_panel.free()


func test_sub_panel_tooltip_locked_item_no_hover() -> void:
	var sub_panel = CategorySubPanel.new()

	sub_panel.populate([
		{"id": "locked", "label": "Locked", "cost": 999, "locked": true, "unlock_population": 5000, "building_data": null}
	], "building")

	var btn = sub_panel._item_container.get_child(0)
	assert_true(btn.disabled, "Locked button should be disabled")
	# Locked items should have plain tooltip_text, not rich hover
	assert_true(btn.tooltip_text.contains("5"), "Should show unlock population")

	sub_panel.free()


func test_sub_panel_tooltip_hides_on_clear() -> void:
	var sub_panel = CategorySubPanel.new()
	sub_panel._ensure_tooltip()
	sub_panel._tooltip_panel.visible = true

	sub_panel.clear()
	assert_false(sub_panel._tooltip_panel.visible)

	sub_panel.free()


func test_sub_panel_tooltip_hides_on_hide_panel() -> void:
	var sub_panel = CategorySubPanel.new()
	sub_panel._ensure_tooltip()
	sub_panel._tooltip_panel.visible = true

	sub_panel.hide_panel()
	assert_false(sub_panel._tooltip_panel.visible)

	sub_panel.free()


# ============================================
# ZONE TOOLTIP TESTS
# ============================================

func test_zone_types_have_descriptions() -> void:
	for zone in BottomToolbar.ZONE_TYPES:
		assert_true(zone.has("desc"), "Zone %s should have desc" % zone.id)
		if zone.id != "dezone":
			assert_true(zone.desc.length() > 0, "Zone %s desc should not be empty" % zone.id)


func test_zone_types_have_stats() -> void:
	for zone in BottomToolbar.ZONE_TYPES:
		assert_true(zone.has("stats"), "Zone %s should have stats" % zone.id)


func test_sub_panel_zone_tooltip_populates() -> void:
	var sub_panel = CategorySubPanel.new()
	sub_panel._ensure_tooltip()

	var item = {
		"id": "res_low", "label": "Residential Low",
		"zone_type": 1, "color": Color(0.2, 0.8, 0.2),
		"desc": "Small houses and duplexes.",
		"stats": "Low traffic | Low land value"
	}

	sub_panel._populate_zone_tooltip(item)

	assert_eq(sub_panel._tooltip_name.text, "Residential Low")
	assert_eq(sub_panel._tooltip_desc.text, "Small houses and duplexes.")
	assert_eq(sub_panel._tooltip_stats.text, "Low traffic | Low land value")
	assert_true(sub_panel._tooltip_preview.visible, "Zone should show color swatch preview")

	sub_panel.free()


func test_sub_panel_zone_hover_connected() -> void:
	var sub_panel = CategorySubPanel.new()

	sub_panel.populate([
		{"id": "res_low", "label": "Residential Low", "zone_type": 1,
		 "color": Color.GREEN, "desc": "Test desc", "stats": "Test stats"}
	], "zone")

	var btn = sub_panel._item_container.get_child(0)
	assert_gt(btn.mouse_entered.get_connections().size(), 0,
		"Zone button should have mouse_entered connected for tooltip")

	sub_panel.free()


func test_sub_panel_dezone_no_tooltip() -> void:
	var sub_panel = CategorySubPanel.new()

	sub_panel.populate([
		{"id": "dezone", "label": "De-zone", "zone_type": 0,
		 "color": Color.GRAY, "desc": "", "stats": ""}
	], "zone")

	var btn = sub_panel._item_container.get_child(0)
	# De-zone has empty desc so tooltip hover should not be connected
	assert_eq(btn.mouse_entered.get_connections().size(), 0,
		"De-zone should not have tooltip hover")

	sub_panel.free()


# ============================================
# MINIMAP ROAD COLOR TESTS
# ============================================

func test_minimap_road_colors_defined() -> void:
	var expected_roads = ["dirt_road", "road", "street", "avenue", "boulevard", "highway", "parkway", "streetcar_parkway"]
	for road_id in expected_roads:
		assert_true(MiniMinimap.ROAD_COLORS.has(road_id),
			"ROAD_COLORS should include %s" % road_id)


func test_minimap_no_stale_road_types() -> void:
	assert_false(MiniMinimap.TYPE_COLORS.has("collector"), "TYPE_COLORS should not have collector")
	assert_false(MiniMinimap.TYPE_COLORS.has("arterial"), "TYPE_COLORS should not have arterial")


# ============================================
# UNLOCK SYSTEM ROAD TIER TESTS
# ============================================

func test_unlock_tiers_contain_new_roads() -> void:
	# Flatten all building IDs from all tiers
	var all_tiered: Array[String] = []
	for tier in UnlockSystemClass.UNLOCK_TIERS:
		for bid in UnlockSystemClass.UNLOCK_TIERS[tier].buildings:
			all_tiered.append(bid)

	assert_in("dirt_road", all_tiered, "dirt_road should be in unlock tiers")
	assert_in("road", all_tiered, "road should be in unlock tiers")
	assert_in("street", all_tiered, "street should be in unlock tiers")
	assert_in("avenue", all_tiered, "avenue should be in unlock tiers")
	assert_in("boulevard", all_tiered, "boulevard should be in unlock tiers")
	assert_in("parkway", all_tiered, "parkway should be in unlock tiers")
	assert_in("streetcar_parkway", all_tiered, "streetcar_parkway should be in unlock tiers")


func test_unlock_tiers_no_stale_roads() -> void:
	var all_tiered: Array[String] = []
	for tier in UnlockSystemClass.UNLOCK_TIERS:
		for bid in UnlockSystemClass.UNLOCK_TIERS[tier].buildings:
			all_tiered.append(bid)

	assert_not_in("collector_road", all_tiered, "collector_road should not be in unlock tiers")
	assert_not_in("arterial_road", all_tiered, "arterial_road should not be in unlock tiers")


# ============================================
# CONDUCTS UTILITIES TESTS
# ============================================

func test_dirt_road_does_not_conduct_utilities() -> void:
	var data = load("res://src/data/dirt_road.tres")
	assert_false(data.conducts_utilities, "Dirt road should not conduct utilities")


func test_paved_roads_conduct_utilities() -> void:
	var ids = ["road", "street", "avenue", "boulevard", "parkway", "streetcar_parkway", "highway"]
	for id in ids:
		var data = load("res://src/data/%s.tres" % id)
		assert_true(data.conducts_utilities, "%s should conduct utilities" % id)


func test_road_types_no_stale_entries() -> void:
	assert_not_in("collector", GridConstants.ROAD_TYPES, "ROAD_TYPES should not contain collector")
	assert_not_in("arterial", GridConstants.ROAD_TYPES, "ROAD_TYPES should not contain arterial")


# ============================================
# FARMING BOOTSTRAP TESTS
# ============================================

func test_well_building_data() -> void:
	var data = load("res://src/data/well.tres")
	assert_not_null(data, "well.tres should exist")
	assert_eq(data.category, "water")
	assert_eq(data.building_type, "water_source")
	assert_false(data.requires_road_adjacent, "Well should not require road")
	assert_false(data.requires_power, "Well should not require power")
	assert_eq(data.water_production, 100.0)


func test_windmill_building_data() -> void:
	var data = load("res://src/data/windmill.tres")
	assert_not_null(data, "windmill.tres should exist")
	assert_eq(data.category, "power")
	assert_eq(data.building_type, "generator")
	assert_false(data.requires_road_adjacent, "Windmill should not require road")
	assert_false(data.requires_power, "Windmill should not require power")
	assert_eq(data.power_production, 2.0)


func test_farm_no_road_required() -> void:
	var data = load("res://src/data/farm.tres")
	assert_not_null(data, "farm.tres should exist")
	assert_false(data.requires_road_adjacent, "Farm should not require road adjacency")


func test_farm_in_starter_tier() -> void:
	var tier0 = UnlockSystemClass.UNLOCK_TIERS[0]
	assert_in("farm", tier0.buildings, "Farm should be in Tier 0")
	# Also verify well and windmill are in Tier 0
	assert_in("well", tier0.buildings, "Well should be in Tier 0")
	assert_in("windmill", tier0.buildings, "Windmill should be in Tier 0")


func test_agricultural_demand_capped_by_population() -> void:
	var zoning = ZoningSystem.new()
	# With 0 population, 1 farm (9 tiles) still allowed
	var old_pop = GameState.population
	GameState.population = 0
	assert_gt(zoning._get_zone_demand(ZoningSystem.ZoneType.AGRICULTURAL), 0.0,
		"Ag demand should be positive at 0 pop (1 free farm)")

	# With 20 population (1 house), limit is 18 → demand > 0 with no developed farms
	GameState.population = 20
	assert_gt(zoning._get_zone_demand(ZoningSystem.ZoneType.AGRICULTURAL), 0.0,
		"Ag demand should be positive with population and no developed farms")

	GameState.population = old_pop
	zoning.free()
