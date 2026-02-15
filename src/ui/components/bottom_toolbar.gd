extends CanvasLayer
class_name BottomToolbar
## Cities: Skylines-style bottom toolbar replacing ToolPalette and StatusPill
## Centered horizontal category bar with slide-up sub-panel
## and small utility icons in the top-right.

const TOOLBAR_BAR_HEIGHT: int = 44
const TOOLBAR_WIDTH: int = 620
const SETTINGS_BTN_SIZE: int = 30

# Toolbar categories (12 buttons)
const TOOLBAR_CATEGORIES = [
	{"id": "infrastructure", "icon": "🛤", "label": "Roads", "type": "build"},
	{"id": "zoning", "icon": "▦", "label": "Zoning", "type": "zone"},
	{"id": "power", "icon": "⚡", "label": "Power", "type": "build"},
	{"id": "water", "icon": "💧", "label": "Water", "type": "build"},
	{"id": "service", "icon": "🏛", "label": "Services", "type": "build"},
	{"id": "transit", "icon": "🚌", "label": "Transit", "type": "build"},
	{"id": "recreation", "icon": "🌳", "label": "Recreation", "type": "build"},
	{"id": "landmark", "icon": "🏆", "label": "Landmarks", "type": "build"},
	{"id": "data_center", "icon": "🖥", "label": "Data Centers", "type": "build"},
	{"id": "terrain", "icon": "⛰", "label": "Terrain", "type": "terrain"},
	{"id": "overlay", "icon": "👁", "label": "Overlays", "type": "overlay"},
	{"id": "demolish", "icon": "🚜", "label": "Demolish", "type": "demolish"}
]

# Zone types (from ToolPalette)
const ZONE_TYPES = [
	{"id": "res_low", "label": "Residential Low", "type": 1, "color": Color(0.2, 0.8, 0.2)},
	{"id": "res_med", "label": "Residential Med", "type": 2, "color": Color(0.1, 0.6, 0.1)},
	{"id": "res_high", "label": "Residential High", "type": 3, "color": Color(0.0, 0.4, 0.0)},
	{"id": "com_low", "label": "Commercial Low", "type": 4, "color": Color(0.2, 0.2, 0.8)},
	{"id": "com_med", "label": "Commercial Med", "type": 5, "color": Color(0.1, 0.1, 0.6)},
	{"id": "com_high", "label": "Commercial High", "type": 6, "color": Color(0.0, 0.0, 0.4)},
	{"id": "ind_low", "label": "Industrial Low", "type": 7, "color": Color(0.8, 0.8, 0.2)},
	{"id": "ind_med", "label": "Industrial Med", "type": 8, "color": Color(0.6, 0.6, 0.1)},
	{"id": "ind_high", "label": "Industrial High", "type": 9, "color": Color(0.4, 0.4, 0.0)},
	{"id": "agri", "label": "Agricultural", "type": 10, "color": Color(0.6, 0.5, 0.2)},
	{"id": "dezone", "label": "De-zone", "type": 0, "color": Color(0.5, 0.5, 0.5)}
]

# Overlay modes (from ToolPalette)
const OVERLAY_MODES = [
	{"id": "none", "label": "None (0)", "mode": 0},
	{"id": "power", "label": "Power (1)", "mode": 1},
	{"id": "water", "label": "Water (2)", "mode": 2},
	{"id": "pollution", "label": "Pollution (3)", "mode": 3},
	{"id": "land_value", "label": "Land Value (4)", "mode": 4},
	{"id": "services", "label": "Services (5)", "mode": 5},
	{"id": "traffic", "label": "Traffic (6)", "mode": 6},
	{"id": "zones", "label": "Zones (7)", "mode": 7}
]

# Terrain tools
const TERRAIN_TOOLS = [
	{"id": "raise", "label": "Raise Terrain", "icon": "▲", "terrain_tool": "raise"},
	{"id": "lower", "label": "Lower Terrain", "icon": "▼", "terrain_tool": "lower"},
	{"id": "flatten", "label": "Flatten", "icon": "━", "terrain_tool": "flatten"},
	{"id": "water", "label": "Add Water", "icon": "〰", "terrain_tool": "water"},
	{"id": "tree", "label": "Plant Trees", "icon": "🌲", "terrain_tool": "tree"},
]

# Settings options
const SETTINGS_OPTIONS = [
	{"id": "dashboard", "label": "📊", "action": "dashboard", "tooltip": "Dashboard (D)"},
	{"id": "save", "label": "💾", "action": "save", "tooltip": "Save Game"},
	{"id": "overlay_toggle", "label": "👁", "action": "overlay_toggle", "tooltip": "Overlays"},
	{"id": "options", "label": "⚙", "action": "options", "tooltip": "Options"}
]

# Signals (identical to ToolPalette)
signal building_selected(building_id: String)
signal zone_selected(zone_type: int)
signal demolish_selected()
signal overlay_selected(mode: int)
signal setting_selected(action: String)

# Components
var _root: Control
var _toolbar_bar: PanelContainer
var _sub_panel: CategorySubPanel
var _settings_container: HBoxContainer

# Toolbar category buttons
var _category_buttons: Dictionary = {}  # category_id: Button
var _active_category: String = ""

# Cached building catalog
var _building_catalog: Dictionary = {}

# Optional injected references
var _game_world: Node = null
var _events: Node = null


func _ready() -> void:
	layer = 95
	_setup_ui()
	_connect_signals()
	call_deferred("_request_building_catalog")


func _exit_tree() -> void:
	pass


func set_game_world(world: Node) -> void:
	_game_world = world


func set_events(events: Node) -> void:
	_events = events


func _get_game_world() -> Node:
	if _game_world and is_instance_valid(_game_world):
		return _game_world
	var tree = get_tree()
	if tree:
		return tree.get_first_node_in_group("game_world")
	return null


func _get_events() -> Node:
	if _events and is_instance_valid(_events):
		return _events
	var tree = get_tree()
	if tree:
		return tree.root.get_node_or_null("Events")
	return null


func _request_building_catalog() -> void:
	var events = _get_events()
	if events:
		events.building_catalog_requested.emit()


func _on_building_catalog_ready(catalog: Dictionary) -> void:
	_building_catalog = catalog


# ============================================
# UI SETUP
# ============================================

func _setup_ui() -> void:
	# Root control - full screen, ignores mouse
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_setup_toolbar_bar()
	_setup_sub_panel()
	_setup_settings_buttons()


func _setup_toolbar_bar() -> void:
	_toolbar_bar = PanelContainer.new()
	_toolbar_bar.anchor_left = 0.5
	_toolbar_bar.anchor_right = 0.5
	_toolbar_bar.anchor_top = 1
	_toolbar_bar.anchor_bottom = 1
	_toolbar_bar.offset_left = -TOOLBAR_WIDTH / 2.0
	_toolbar_bar.offset_right = TOOLBAR_WIDTH / 2.0
	_toolbar_bar.offset_top = -TOOLBAR_BAR_HEIGHT
	_toolbar_bar.offset_bottom = 0

	var style = UIManager.get_panel_style(ThemeConstants.RADIUS_MEDIUM)
	style.bg_color = UIManager.COLORS.panel_bg
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, -1)
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.set_content_margin_all(ThemeConstants.PADDING_SMALL)
	_toolbar_bar.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 2)
	_toolbar_bar.add_child(hbox)

	for cat in TOOLBAR_CATEGORIES:
		var btn = _create_category_button(cat)
		_category_buttons[cat.id] = btn
		hbox.add_child(btn)

	_root.add_child(_toolbar_bar)


func _setup_sub_panel() -> void:
	_sub_panel = CategorySubPanel.new()
	_sub_panel._ensure_initialized()
	_sub_panel.anchor_left = 0.5
	_sub_panel.anchor_right = 0.5
	_sub_panel.anchor_top = 1
	_sub_panel.anchor_bottom = 1
	_sub_panel.offset_left = -TOOLBAR_WIDTH / 2.0
	_sub_panel.offset_right = TOOLBAR_WIDTH / 2.0
	_sub_panel.offset_top = -(TOOLBAR_BAR_HEIGHT + CategorySubPanel.PANEL_HEIGHT)
	_sub_panel.offset_bottom = -TOOLBAR_BAR_HEIGHT

	_sub_panel.item_selected.connect(_on_sub_panel_item_selected)
	_sub_panel.closed.connect(_on_sub_panel_closed)

	_root.add_child(_sub_panel)


func _setup_settings_buttons() -> void:
	_settings_container = HBoxContainer.new()
	_settings_container.anchor_left = 1
	_settings_container.anchor_right = 1
	_settings_container.anchor_top = 0
	_settings_container.anchor_bottom = 0
	_settings_container.offset_left = -(SETTINGS_OPTIONS.size() * (SETTINGS_BTN_SIZE + 4) + 12)
	_settings_container.offset_right = -8
	_settings_container.offset_top = 8
	_settings_container.offset_bottom = 8 + SETTINGS_BTN_SIZE
	_settings_container.add_theme_constant_override("separation", 4)

	for opt in SETTINGS_OPTIONS:
		var btn = Button.new()
		btn.text = opt.label
		btn.custom_minimum_size = Vector2(SETTINGS_BTN_SIZE, SETTINGS_BTN_SIZE)
		btn.flat = true
		btn.tooltip_text = opt.tooltip
		btn.add_theme_font_size_override("font_size", ThemeConstants.FONT_SMALL)
		btn.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
		btn.add_theme_color_override("font_hover_color", UIManager.COLORS.text)

		var style_normal = UIManager.get_button_normal_style()
		style_normal.bg_color = UIManager.COLORS.panel_bg.darkened(0.1)
		style_normal.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
		btn.add_theme_stylebox_override("normal", style_normal)

		var style_hover = UIManager.get_button_hover_style()
		style_hover.bg_color = UIManager.COLORS.panel_bg.lightened(0.1)
		btn.add_theme_stylebox_override("hover", style_hover)

		btn.pressed.connect(_on_settings_pressed.bind(opt.action))
		_settings_container.add_child(btn)

	_root.add_child(_settings_container)


# ============================================
# BUTTON CREATION HELPERS
# ============================================

func _create_category_button(cat: Dictionary) -> Button:
	var btn = Button.new()
	btn.text = cat.icon
	btn.custom_minimum_size = Vector2(46, 34)
	btn.flat = true
	btn.tooltip_text = cat.label
	btn.add_theme_font_size_override("font_size", ThemeConstants.FONT_NORMAL)
	btn.add_theme_color_override("font_color", UIManager.COLORS.text)
	btn.add_theme_color_override("font_hover_color", UIManager.COLORS.text)

	var style_normal = UIManager.get_button_normal_style()
	style_normal.bg_color = Color.TRANSPARENT
	style_normal.set_border_width_all(0)
	style_normal.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = UIManager.get_button_hover_style()
	style_hover.bg_color = UIManager.COLORS.panel_bg.lightened(0.15)
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = UIManager.get_button_pressed_style()
	style_pressed.bg_color = UIManager.COLORS.accent.darkened(0.3)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.pressed.connect(_on_category_pressed.bind(cat.id))
	return btn


# ============================================
# SIGNAL CONNECTIONS
# ============================================

func _connect_signals() -> void:
	UIManager.tool_changed.connect(_on_ui_tool_changed)

	var events = _get_events()
	if events:
		events.building_catalog_ready.connect(_on_building_catalog_ready)


# ============================================
# CATEGORY HANDLING
# ============================================

func _on_category_pressed(category_id: String) -> void:
	# Demolish is a direct-action button
	if category_id == "demolish":
		_close_sub_panel()
		UIManager.set_tool(UIManagerClass.Tool.DEMOLISH)
		demolish_selected.emit()
		_update_category_highlight(category_id)
		return

	# Toggle: same category = close, different = switch
	if _active_category == category_id:
		_close_sub_panel()
	else:
		_open_category(category_id)


func _open_category(category_id: String) -> void:
	_active_category = category_id
	_update_category_highlight(category_id)

	# Find category definition
	var cat_def = null
	for cat in TOOLBAR_CATEGORIES:
		if cat.id == category_id:
			cat_def = cat
			break
	if not cat_def:
		return

	# Populate sub-panel based on type
	match cat_def.type:
		"build":
			_populate_build_items(category_id)
		"zone":
			_populate_zone_items()
		"overlay":
			_populate_overlay_items()
		"terrain":
			_populate_terrain_items()

	_sub_panel.show_panel()


func _close_sub_panel() -> void:
	if _active_category != "":
		_active_category = ""
		_sub_panel.hide_panel()
		_update_category_highlight("")


func _populate_build_items(category_id: String) -> void:
	var items: Array = []

	if _building_catalog.has(category_id):
		for building_info in _building_catalog[category_id]:
			var is_unlocked = true
			var unlock_population = 0

			if UnlockSystem:
				is_unlocked = UnlockSystem.is_building_unlocked(building_info.id)
				unlock_population = UnlockSystem.get_unlock_population(building_info.id)

			if category_id == "landmark" and is_unlocked:
				is_unlocked = GameState.is_landmark_unlocked(building_info.id)

			items.append({
				"id": building_info.id,
				"label": building_info.display_name,
				"cost": building_info.build_cost,
				"building_id": building_info.id,
				"locked": not is_unlocked,
				"unlock_population": unlock_population
			})

	# Sort: unlocked first, then by cost, locked by unlock population
	items.sort_custom(func(a, b):
		if a.locked != b.locked:
			return not a.locked
		if a.locked:
			return a.unlock_population < b.unlock_population
		return a.cost < b.cost
	)

	_sub_panel.populate(items, "building")


func _populate_zone_items() -> void:
	var items: Array = []
	for zone in ZONE_TYPES:
		items.append({
			"id": zone.id,
			"label": zone.label,
			"zone_type": zone.type,
			"color": zone.color
		})
	_sub_panel.populate(items, "zone")


func _populate_overlay_items() -> void:
	var items: Array = []
	for overlay in OVERLAY_MODES:
		items.append({
			"id": overlay.id,
			"label": overlay.label,
			"mode": overlay.mode
		})
	_sub_panel.populate(items, "overlay")


func _populate_terrain_items() -> void:
	var items: Array = []
	for tool_def in TERRAIN_TOOLS:
		items.append(tool_def.duplicate())
	_sub_panel.populate(items, "terrain")


# ============================================
# SUB-PANEL ITEM SELECTION
# ============================================

func _on_sub_panel_item_selected(item_id: String, item_data: Dictionary) -> void:
	match _active_category:
		"zoning":
			if item_data.has("zone_type"):
				zone_selected.emit(item_data.zone_type)
				UIManager.set_tool(UIManagerClass.Tool.ZONE)
		"overlay":
			if item_data.has("mode"):
				overlay_selected.emit(item_data.mode)
		"terrain":
			if item_data.has("terrain_tool"):
				var game_world = _get_game_world()
				if game_world and game_world.has_method("set_terrain_tool"):
					game_world.set_terrain_tool(item_data.terrain_tool)
				UIManager.set_tool(UIManagerClass.Tool.TERRAIN)
		_:
			# Build categories
			if item_data.has("building_id"):
				building_selected.emit(item_data.building_id)
				UIManager.set_tool(UIManagerClass.Tool.BUILD)


func _on_sub_panel_closed() -> void:
	_active_category = ""
	_update_category_highlight("")


# ============================================
# SETTINGS BUTTONS
# ============================================

func _on_settings_pressed(action: String) -> void:
	setting_selected.emit(action)
	match action:
		"dashboard":
			UIManager.toggle_panel("dashboard")
		"save":
			UIManager.toggle_panel("save_load")
		"options":
			UIManager.toggle_panel("options")


# ============================================
# CATEGORY HIGHLIGHT
# ============================================

func _update_category_highlight(active_id: String) -> void:
	for id in _category_buttons:
		var btn = _category_buttons[id]
		if id == active_id:
			var active_style = UIManager.get_button_active_style()
			active_style.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
			btn.add_theme_stylebox_override("normal", active_style)
			btn.add_theme_color_override("font_color", UIManager.COLORS.accent.lightened(0.3))
		else:
			var normal_style = UIManager.get_button_normal_style()
			normal_style.bg_color = Color.TRANSPARENT
			normal_style.set_border_width_all(0)
			normal_style.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
			btn.add_theme_stylebox_override("normal", normal_style)
			btn.add_theme_color_override("font_color", UIManager.COLORS.text)


func _on_ui_tool_changed(_tool: int) -> void:
	pass


# ============================================
# KEYBOARD SHORTCUTS
# ============================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var handled := false
		match event.keycode:
			KEY_Q:
				# Deselect / close sub-panel
				_close_sub_panel()
				UIManager.set_tool(UIManagerClass.Tool.SELECT)
				handled = true
			KEY_X:
				_close_sub_panel()
				UIManager.set_tool(UIManagerClass.Tool.DEMOLISH)
				demolish_selected.emit()
				_update_category_highlight("demolish")
				handled = true
			KEY_B:
				if not event.ctrl_pressed:
					_on_category_pressed("infrastructure")
					handled = true
			KEY_ESCAPE:
				if _active_category != "":
					_close_sub_panel()
					handled = true

		if handled:
			get_viewport().set_input_as_handled()


# ============================================
# PUBLIC API
# ============================================

func get_category_button_count() -> int:
	return _category_buttons.size()


func get_active_category() -> String:
	return _active_category


func get_sub_panel() -> CategorySubPanel:
	return _sub_panel
