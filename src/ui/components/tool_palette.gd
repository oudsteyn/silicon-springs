extends CanvasLayer
class_name ToolPalette
## Photoshop-style vertical tool strip on left edge
## 45px wide, always visible, with flyout menus for complex tools

const PALETTE_WIDTH: int = 56
const BUTTON_SIZE: int = 46
const PADDING: int = 5
const BUTTON_SPACING: int = 3

# Tool definitions with icons
const TOOLS = [
	{"id": "select", "icon": "↖", "tooltip": "Select (Q)", "tool": UIManagerClass.Tool.SELECT},
	{"id": "pan", "icon": "✋", "tooltip": "Pan (Hold Space)", "tool": UIManagerClass.Tool.PAN},
	{"id": "zoom", "icon": "🔍", "tooltip": "Zoom (Scroll)", "tool": UIManagerClass.Tool.ZOOM},
	{"id": "build", "icon": "🏗", "tooltip": "Build", "tool": UIManagerClass.Tool.BUILD, "has_flyout": true},
	{"id": "zone", "icon": "▦", "tooltip": "Zone", "tool": UIManagerClass.Tool.ZONE, "has_flyout": true},
	{"id": "demolish", "icon": "🚜", "tooltip": "Demolish (X)", "tool": UIManagerClass.Tool.DEMOLISH},
	{"id": "terrain", "icon": "⛰", "tooltip": "Terrain", "tool": UIManagerClass.Tool.TERRAIN, "has_flyout": true},
	{"id": "overlay", "icon": "👁", "tooltip": "Overlays", "tool": UIManagerClass.Tool.OVERLAY, "has_flyout": true},
	{"id": "settings", "icon": "⚙", "tooltip": "Settings", "tool": UIManagerClass.Tool.SETTINGS, "has_flyout": true}
]

# Building categories for Build flyout
const BUILD_CATEGORIES = [
	{"id": "infrastructure", "label": "Infrastructure", "icon": "🛤"},
	{"id": "power", "label": "Power", "icon": "⚡"},
	{"id": "water", "label": "Water", "icon": "💧"},
	{"id": "service", "label": "Services", "icon": "🏛"},
	{"id": "transit", "label": "Transit", "icon": "🚌"},
	{"id": "recreation", "label": "Recreation", "icon": "🌳"},
	{"id": "landmark", "label": "Landmarks", "icon": "🏆"},
	{"id": "special", "label": "Special", "icon": "✈"},
	{"id": "data_center", "label": "Data Centers", "icon": "🖥"}
]

# Zone types for Zone flyout
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

# Overlay modes
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

# Settings options
const SETTINGS_OPTIONS = [
	{"id": "dashboard", "label": "Dashboard (D)", "action": "dashboard"},
	{"id": "budget", "label": "Budget (B)", "action": "budget"},
	{"id": "save", "label": "Save Game", "action": "save"},
	{"id": "load", "label": "Load Game", "action": "load"},
	{"id": "options", "label": "Options", "action": "options"}
]

# Signals
signal building_selected(building_id: String)
signal zone_selected(zone_type: int)
signal demolish_selected()
signal overlay_selected(mode: int)
signal setting_selected(action: String)

# Components
var panel: PanelContainer
var button_container: VBoxContainer
var tool_buttons: Dictionary = {}  # tool_id: Button
var active_flyout: FlyoutMenu = null

# Cached building catalog (received via Events)
var _building_catalog: Dictionary = {}

# Pre-created styles for performance
var _style_normal: StyleBoxFlat
var _style_active: StyleBoxFlat

# State
var _current_tool_id: String = "select"
var _closing_flyout: bool = false  # Prevent double-close race condition

# Optional injected references
var _game_world: Node = null
var _events: Node = null


func _ready() -> void:
	layer = 95
	_create_shared_styles()
	_setup_ui()
	_connect_signals()

	# Request building catalog via event bus (decoupled from grid_system)
	call_deferred("_request_building_catalog")


func _exit_tree() -> void:
	# Clean up any open flyout
	if active_flyout and is_instance_valid(active_flyout):
		active_flyout.queue_free()
		active_flyout = null


func _create_shared_styles() -> void:
	# Normal style (transparent) - using centralized theme
	_style_normal = UIManager.get_button_normal_style()
	_style_normal.bg_color = Color.TRANSPARENT
	_style_normal.set_border_width_all(0)
	_style_normal.set_corner_radius_all(ThemeConstants.RADIUS_MEDIUM)

	# Active/selected style - using centralized theme
	_style_active = UIManager.get_button_active_style()
	_style_active.set_corner_radius_all(ThemeConstants.RADIUS_MEDIUM)


func _request_building_catalog() -> void:
	var events = _get_events()
	if events:
		events.building_catalog_requested.emit()


func _on_building_catalog_ready(catalog: Dictionary) -> void:
	_building_catalog = catalog


func _setup_ui() -> void:
	# Main panel - left edge, vertically centered
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PALETTE_WIDTH, 0)

	# Position on left edge, vertically centered
	panel.anchor_left = 0
	panel.anchor_top = 0.5
	panel.anchor_right = 0
	panel.anchor_bottom = 0.5
	panel.offset_left = 8
	panel.offset_right = 8 + PALETTE_WIDTH

	# Calculate height based on number of tools
	var total_height = (TOOLS.size() * (BUTTON_SIZE + BUTTON_SPACING)) + (PADDING * 2)
	panel.offset_top = -total_height / 2.0
	panel.offset_bottom = total_height / 2.0

	# Style
	var style = UIManager.get_panel_style(ThemeConstants.RADIUS_LARGE)
	style.bg_color = UIManager.COLORS.panel_bg.darkened(0.1)
	style.set_content_margin_all(PADDING)
	# Subtle shadow
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 2)
	panel.add_theme_stylebox_override("panel", style)

	# Button container
	button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", BUTTON_SPACING)
	panel.add_child(button_container)

	# Create tool buttons
	for tool_def in TOOLS:
		var btn = _create_tool_button(tool_def)
		tool_buttons[tool_def.id] = btn
		button_container.add_child(btn)

	add_child(panel)

	# Set initial selection
	_update_tool_highlight("select")


func _create_tool_button(tool_def: Dictionary) -> Button:
	var btn = Button.new()
	btn.text = tool_def.icon
	btn.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	btn.tooltip_text = tool_def.tooltip
	btn.flat = true

	# Font styling
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", UIManager.COLORS.text)
	btn.add_theme_color_override("font_hover_color", UIManager.COLORS.text)
	btn.add_theme_color_override("font_pressed_color", UIManager.COLORS.text)

	# Normal style
	var style_normal = UIManager.get_button_normal_style()
	style_normal.bg_color = Color.TRANSPARENT
	style_normal.set_border_width_all(0)
	btn.add_theme_stylebox_override("normal", style_normal)

	# Hover style
	var style_hover = UIManager.get_button_hover_style()
	style_hover.bg_color = UIManager.COLORS.panel_bg.lightened(0.15)
	btn.add_theme_stylebox_override("hover", style_hover)

	# Pressed style
	var style_pressed = UIManager.get_button_active_style()
	style_pressed.bg_color = UIManager.COLORS.accent.darkened(0.3)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	# Connect signals
	btn.pressed.connect(_on_tool_pressed.bind(tool_def.id))

	return btn


func _connect_signals() -> void:
	UIManager.tool_changed.connect(_on_ui_tool_changed)
	var events = _get_events()
	if events:
		events.building_catalog_ready.connect(_on_building_catalog_ready)


func _on_tool_pressed(tool_id: String) -> void:
	# Close any existing flyout first
	_close_flyout()

	# Find tool definition
	var tool_def = null
	for t in TOOLS:
		if t.id == tool_id:
			tool_def = t
			break

	if not tool_def:
		return

	# Handle tools with flyouts
	if tool_def.get("has_flyout", false):
		_show_flyout(tool_id)
		return

	# Handle direct action tools
	match tool_id:
		"select":
			UIManager.set_tool(UIManagerClass.Tool.SELECT)
		"pan":
			UIManager.set_tool(UIManagerClass.Tool.PAN)
		"zoom":
			UIManager.set_tool(UIManagerClass.Tool.ZOOM)
		"demolish":
			UIManager.set_tool(UIManagerClass.Tool.DEMOLISH)
			demolish_selected.emit()

	_update_tool_highlight(tool_id)


func _show_flyout(tool_id: String) -> void:
	# Get button position for flyout placement
	var btn = tool_buttons.get(tool_id)
	if not btn:
		return

	var flyout_pos = Vector2(
		panel.global_position.x + panel.size.x + 4,
		btn.global_position.y
	)

	# Create flyout based on tool type
	var menu_items: Array[Dictionary] = []

	match tool_id:
		"build":
			menu_items = _get_build_menu_items()
		"zone":
			menu_items = _get_zone_menu_items()
		"terrain":
			menu_items = _get_terrain_menu_items()
		"overlay":
			menu_items = _get_overlay_menu_items()
		"settings":
			menu_items = _get_settings_menu_items()

	if menu_items.is_empty():
		return

	active_flyout = FlyoutMenu.new()
	active_flyout.setup(menu_items, tool_id, flyout_pos)
	active_flyout.item_selected.connect(_on_flyout_item_selected.bind(tool_id))
	active_flyout.closed.connect(_on_flyout_closed)
	add_child(active_flyout)

	UIManager.open_flyout(tool_id)
	_update_tool_highlight(tool_id)


func _close_flyout() -> void:
	if active_flyout and not _closing_flyout:
		_closing_flyout = true
		var flyout_id = active_flyout.flyout_id
		var flyout = active_flyout
		active_flyout = null
		flyout.close_menu()
		UIManager.close_flyout(flyout_id)
		_closing_flyout = false


func _on_flyout_closed() -> void:
	active_flyout = null
	# Return highlight to actual current tool
	_update_tool_highlight(_current_tool_id)


func _on_flyout_item_selected(_item_id: String, item_data: Dictionary, tool_id: String) -> void:
	match tool_id:
		"build":
			if item_data.has("building_id"):
				building_selected.emit(item_data.building_id)
				UIManager.set_tool(UIManagerClass.Tool.BUILD)
				_current_tool_id = "build"
		"zone":
			if item_data.has("zone_type"):
				zone_selected.emit(item_data.zone_type)
				UIManager.set_tool(UIManagerClass.Tool.ZONE)
				_current_tool_id = "zone"
		"terrain":
			if item_data.has("terrain_tool"):
				var game_world = _get_game_world()
				if game_world and game_world.has_method("set_terrain_tool"):
					game_world.set_terrain_tool(item_data.terrain_tool)
				UIManager.set_tool(UIManagerClass.Tool.TERRAIN)
				_current_tool_id = "terrain"
		"overlay":
			if item_data.has("mode"):
				overlay_selected.emit(item_data.mode)
				# Don't change tool - overlays are toggles
		"settings":
			if item_data.has("action"):
				setting_selected.emit(item_data.action)
				_handle_setting_action(item_data.action)

	_close_flyout()


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


func _handle_setting_action(action: String) -> void:
	match action:
		"dashboard":
			UIManager.toggle_panel("dashboard")
		"budget":
			UIManager.toggle_panel("budget")
		"save":
			UIManager.toggle_panel("save_load")
		"load":
			UIManager.toggle_panel("save_load")
		"options":
			UIManager.toggle_panel("options")


func _get_build_menu_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []

	for cat in BUILD_CATEGORIES:
		var children: Array[Dictionary] = []
		var has_unlocked_items = false

		# Get buildings for this category from cached catalog
		if _building_catalog.has(cat.id):
			for building_info in _building_catalog[cat.id]:
				# Check if building is unlocked via UnlockSystem
				var is_unlocked = true
				var unlock_population = 0

				if UnlockSystem:
					is_unlocked = UnlockSystem.is_building_unlocked(building_info.id)
					unlock_population = UnlockSystem.get_unlock_population(building_info.id)

				# Also check landmark unlocks (legacy system)
				if cat.id == "landmark" and is_unlocked:
					is_unlocked = GameState.is_landmark_unlocked(building_info.id)

				if is_unlocked:
					has_unlocked_items = true

				children.append({
					"id": building_info.id,
					"label": building_info.display_name,
					"cost": building_info.build_cost,
					"building_id": building_info.id,
					"locked": not is_unlocked,
					"unlock_population": unlock_population
				})

		# Sort children: unlocked first, then by cost, then locked by unlock population
		children.sort_custom(func(a, b):
			# Unlocked items come first
			if a.locked != b.locked:
				return not a.locked  # unlocked (false) comes before locked (true)
			# Within same lock state, sort by cost (or unlock population for locked)
			if a.locked:
				return a.unlock_population < b.unlock_population
			return a.cost < b.cost
		)

		# Only add category if it has any items (locked or unlocked)
		if children.size() > 0:
			items.append({
				"id": cat.id,
				"label": cat.label,
				"icon": cat.icon,
				"children": children,
				"has_unlocked": has_unlocked_items
			})

	return items


func _get_zone_menu_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []

	for zone in ZONE_TYPES:
		items.append({
			"id": zone.id,
			"label": zone.label,
			"zone_type": zone.type
		})

	return items


func _get_terrain_menu_items() -> Array[Dictionary]:
	return [
		{"id": "raise", "label": "Raise Terrain", "icon": "▲", "terrain_tool": "raise"},
		{"id": "lower", "label": "Lower Terrain", "icon": "▼", "terrain_tool": "lower"},
		{"id": "flatten", "label": "Flatten", "icon": "━", "terrain_tool": "flatten"},
		{"id": "water", "label": "Add Water", "icon": "〰", "terrain_tool": "water"},
		{"id": "tree", "label": "Plant Trees", "icon": "T", "terrain_tool": "tree"},
		{"id": "rock", "label": "Place Rocks", "icon": "O", "terrain_tool": "rock"},
	]


func _get_overlay_menu_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []

	for overlay in OVERLAY_MODES:
		items.append({
			"id": overlay.id,
			"label": overlay.label,
			"mode": overlay.mode
		})

	return items


func _get_settings_menu_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []

	for opt in SETTINGS_OPTIONS:
		items.append({
			"id": opt.id,
			"label": opt.label,
			"action": opt.action
		})

	return items


func _update_tool_highlight(tool_id: String) -> void:
	for id in tool_buttons:
		var btn = tool_buttons[id]
		if id == tool_id:
			# Active style - reuse pre-created style
			btn.add_theme_stylebox_override("normal", _style_active)
			btn.add_theme_color_override("font_color", UIManager.COLORS.accent.lightened(0.3))
		else:
			# Normal style - reuse pre-created style
			btn.add_theme_stylebox_override("normal", _style_normal)
			btn.add_theme_color_override("font_color", UIManager.COLORS.text)


func _on_ui_tool_changed(tool: int) -> void:
	# Map UIManager.Tool to our tool_id
	var tool_id = "select"
	match tool:
		UIManagerClass.Tool.SELECT: tool_id = "select"
		UIManagerClass.Tool.PAN: tool_id = "pan"
		UIManagerClass.Tool.ZOOM: tool_id = "zoom"
		UIManagerClass.Tool.BUILD: tool_id = "build"
		UIManagerClass.Tool.ZONE: tool_id = "zone"
		UIManagerClass.Tool.DEMOLISH: tool_id = "demolish"
		UIManagerClass.Tool.TERRAIN: tool_id = "terrain"
		UIManagerClass.Tool.OVERLAY: tool_id = "overlay"
		UIManagerClass.Tool.SETTINGS: tool_id = "settings"

	_current_tool_id = tool_id
	_update_tool_highlight(tool_id)


func _input(event: InputEvent) -> void:
	# Handle keyboard shortcuts for tools
	if event is InputEventKey and event.pressed and not event.echo:
		var handled := false
		match event.keycode:
			KEY_Q:
				_on_tool_pressed("select")
				handled = true
			KEY_X:
				_on_tool_pressed("demolish")
				handled = true
			KEY_B:
				if not event.ctrl_pressed:
					_show_flyout("build")
					handled = true
			KEY_ESCAPE:
				if active_flyout:
					_close_flyout()
					handled = true

		if handled:
			get_viewport().set_input_as_handled()
