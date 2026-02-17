extends PanelContainer
class_name CategorySubPanel
## Slide-up sub-panel showing items for a selected toolbar category
## Used by BottomToolbar to display building/zone/overlay/terrain items

signal item_selected(item_id: String, item_data: Dictionary)
signal closed()

const PANEL_HEIGHT: int = 80
const ITEM_SPACING: int = 6
const ANIM_DURATION: float = 0.2
const TOOLTIP_DELAY: float = 0.3
const PREVIEW_SIZE: int = 48

var _scroll: ScrollContainer
var _item_container: HBoxContainer
var _panel_type: String = ""
var _tween: Tween = null
var _initialized: bool = false

# Tooltip
var _tooltip_panel: PanelContainer
var _tooltip_preview: TextureRect
var _tooltip_name: Label
var _tooltip_desc: Label
var _tooltip_stats: Label
var _tooltip_timer: Timer
var _tooltip_target: Control = null
var _building_renderer: Node = null


func _ready() -> void:
	_ensure_initialized()


func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	visible = false
	clip_contents = true
	custom_minimum_size = Vector2(600, 0)

	# Style
	var style = UIManager.get_panel_style(ThemeConstants.RADIUS_MEDIUM)
	style.bg_color = UIManager.COLORS.panel_bg.darkened(0.1)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, -2)
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.set_content_margin_all(ThemeConstants.PADDING_NORMAL)
	add_theme_stylebox_override("panel", style)

	# ScrollContainer for horizontal overflow
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)

	# Item container
	_item_container = HBoxContainer.new()
	_item_container.add_theme_constant_override("separation", ITEM_SPACING)
	_item_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_item_container)

	# Tooltip hover timer
	_tooltip_timer = Timer.new()
	_tooltip_timer.one_shot = true
	_tooltip_timer.wait_time = TOOLTIP_DELAY
	_tooltip_timer.timeout.connect(_show_tooltip)
	add_child(_tooltip_timer)


func populate(items: Array, panel_type: String) -> void:
	_ensure_initialized()
	clear()
	_panel_type = panel_type

	for item in items:
		match panel_type:
			"building":
				_add_building_item(item)
			"zone":
				_add_zone_item(item)
			"overlay":
				_add_overlay_item(item)
			"terrain":
				_add_terrain_item(item)


func show_panel() -> void:
	_ensure_initialized()
	if _tween and _tween.is_valid():
		_tween.kill()

	visible = true
	custom_minimum_size.y = 0

	if is_inside_tree():
		_tween = create_tween()
		_tween.set_ease(Tween.EASE_OUT)
		_tween.set_trans(Tween.TRANS_CUBIC)
		_tween.tween_property(self, "custom_minimum_size:y", PANEL_HEIGHT, ANIM_DURATION)
	else:
		custom_minimum_size.y = PANEL_HEIGHT


func hide_panel() -> void:
	_hide_tooltip()
	if _tween and _tween.is_valid():
		_tween.kill()

	if is_inside_tree():
		_tween = create_tween()
		_tween.set_ease(Tween.EASE_IN)
		_tween.set_trans(Tween.TRANS_CUBIC)
		_tween.tween_property(self, "custom_minimum_size:y", 0, ANIM_DURATION)
		_tween.tween_callback(func():
			visible = false
			closed.emit()
		)
	else:
		visible = false
		closed.emit()


func clear() -> void:
	_ensure_initialized()
	_hide_tooltip()
	for child in _item_container.get_children():
		_item_container.remove_child(child)
		child.queue_free()
	_panel_type = ""


func get_item_count() -> int:
	_ensure_initialized()
	return _item_container.get_child_count()


# ============================================
# TOOLTIP
# ============================================

func _get_building_renderer() -> Node:
	if _building_renderer and is_instance_valid(_building_renderer):
		return _building_renderer
	var tree = get_tree()
	if tree:
		_building_renderer = tree.get_first_node_in_group("building_renderer")
	return _building_renderer


func _ensure_tooltip() -> void:
	if _tooltip_panel:
		return

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 100
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var tip_style = UIManager.get_tooltip_style()
	tip_style.set_content_margin_all(ThemeConstants.PADDING_NORMAL)
	_tooltip_panel.add_theme_stylebox_override("panel", tip_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", ThemeConstants.PADDING_NORMAL)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_child(hbox)

	# Preview image
	_tooltip_preview = TextureRect.new()
	_tooltip_preview.custom_minimum_size = Vector2(PREVIEW_SIZE, PREVIEW_SIZE)
	_tooltip_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tooltip_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tooltip_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_tooltip_preview)

	# Text column
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vbox)

	_tooltip_name = Label.new()
	_tooltip_name.add_theme_font_size_override("font_size", ThemeConstants.FONT_NORMAL)
	_tooltip_name.add_theme_color_override("font_color", UIManager.COLORS.text)
	_tooltip_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tooltip_name)

	_tooltip_desc = Label.new()
	_tooltip_desc.add_theme_font_size_override("font_size", ThemeConstants.FONT_SMALL)
	_tooltip_desc.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	_tooltip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_tooltip_desc.custom_minimum_size.x = 220
	_tooltip_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tooltip_desc)

	_tooltip_stats = Label.new()
	_tooltip_stats.add_theme_font_size_override("font_size", ThemeConstants.FONT_SMALL)
	_tooltip_stats.add_theme_color_override("font_color", UIManager.COLORS.accent)
	_tooltip_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tooltip_stats)


func _on_building_hover(btn: Control, item: Dictionary) -> void:
	_tooltip_target = btn
	btn.set_meta("tooltip_item", item)
	_tooltip_timer.start()


func _on_building_hover_exit(_btn: Control) -> void:
	_tooltip_timer.stop()
	_tooltip_target = null
	_hide_tooltip()


func _show_tooltip() -> void:
	if not _tooltip_target or not is_instance_valid(_tooltip_target):
		return

	var item: Dictionary = _tooltip_target.get_meta("tooltip_item", {})
	if item.is_empty():
		return

	_ensure_tooltip()

	# Determine tooltip type from item contents
	if item.has("building_data") and item.get("building_data") != null:
		_populate_building_tooltip(item)
	elif item.has("zone_type"):
		_populate_zone_tooltip(item)
	else:
		return

	# Add tooltip to CanvasLayer parent so it floats above the panel
	if not _tooltip_panel.get_parent():
		var canvas = _find_parent_canvas_layer()
		if canvas:
			canvas.add_child(_tooltip_panel)
		else:
			add_child(_tooltip_panel)

	_tooltip_panel.visible = true
	_tooltip_panel.reset_size()

	# Position above the button (deferred so size is computed)
	call_deferred("_position_tooltip")


func _populate_building_tooltip(item: Dictionary) -> void:
	var data: Resource = item.get("building_data")

	_tooltip_name.text = data.display_name
	_tooltip_desc.text = data.tooltip if data.tooltip != "" else data.description

	# Build stats
	var is_road = data.building_type == "road"
	var stats_parts: Array[String] = []
	stats_parts.append("$%s" % UIManager.format_number(data.build_cost))
	if data.monthly_maintenance > 0:
		stats_parts.append("$%s/mo" % UIManager.format_number(data.monthly_maintenance))
	if is_road:
		stats_parts.append("Capacity: %d" % data.road_capacity)
		stats_parts.append("Speed: %.1fx" % data.road_speed)
		if data.noise_radius > 0:
			stats_parts.append("Noise: %d" % data.noise_radius)
		if not data.allows_direct_access:
			stats_parts.append("No direct access")
	else:
		if data.power_production > 0:
			stats_parts.append("+%d MW" % int(data.power_production))
		if data.power_consumption > 0:
			stats_parts.append("-%d MW" % int(data.power_consumption))
		if data.water_production > 0:
			stats_parts.append("+%d ML" % int(data.water_production))
		if data.water_consumption > 0:
			stats_parts.append("-%d ML" % int(data.water_consumption))
		if data.coverage_radius > 0:
			stats_parts.append("%d tile radius" % data.coverage_radius)
		if data.population_capacity > 0:
			stats_parts.append("%d pop" % data.population_capacity)
		if data.jobs_provided > 0:
			stats_parts.append("%d jobs" % data.jobs_provided)
	_tooltip_stats.text = " | ".join(stats_parts)

	# Generate tile preview
	var renderer = _get_building_renderer()
	if renderer:
		var tex = renderer.get_building_texture(data, 1)
		_tooltip_preview.texture = tex
		_tooltip_preview.visible = true
	else:
		_tooltip_preview.visible = false


func _populate_zone_tooltip(item: Dictionary) -> void:
	_tooltip_name.text = item.get("label", "")
	_tooltip_desc.text = item.get("desc", "")
	_tooltip_stats.text = item.get("stats", "")

	# Generate a color swatch preview for the zone
	var zone_color: Color = item.get("color", Color.GRAY)
	var img = Image.create(PREVIEW_SIZE, PREVIEW_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(zone_color)
	# Draw a subtle border
	var border_color = zone_color.lightened(0.3)
	for i in range(PREVIEW_SIZE):
		img.set_pixel(i, 0, border_color)
		img.set_pixel(i, PREVIEW_SIZE - 1, border_color)
		img.set_pixel(0, i, border_color)
		img.set_pixel(PREVIEW_SIZE - 1, i, border_color)
	_tooltip_preview.texture = ImageTexture.create_from_image(img)
	_tooltip_preview.visible = true


func _position_tooltip() -> void:
	if not _tooltip_target or not is_instance_valid(_tooltip_target) or not _tooltip_panel:
		return
	if not _tooltip_panel.visible:
		return

	var btn_rect = _tooltip_target.get_global_rect()
	var tip_size = _tooltip_panel.size

	# Position centered above the button with a small gap
	var x = btn_rect.position.x + (btn_rect.size.x - tip_size.x) * 0.5
	var y = btn_rect.position.y - tip_size.y - 8

	# Clamp to screen
	var viewport_size = get_viewport().get_visible_rect().size
	x = clampf(x, 4, viewport_size.x - tip_size.x - 4)
	y = maxf(y, 4)

	_tooltip_panel.position = Vector2(x, y)


func _hide_tooltip() -> void:
	if _tooltip_panel:
		_tooltip_panel.visible = false


func _find_parent_canvas_layer() -> CanvasLayer:
	var node = get_parent()
	while node:
		if node is CanvasLayer:
			return node
		node = node.get_parent()
	return null


# ============================================
# BUILDING ITEMS
# ============================================

func _add_building_item(item: Dictionary) -> void:
	var btn = Button.new()
	var label_text = item.get("label", item.get("id", "?"))
	var cost = item.get("cost", 0)
	var is_locked = item.get("locked", false)

	btn.text = "%s\n$%s" % [label_text, UIManager.format_number(cost)]
	btn.custom_minimum_size = Vector2(90, 60)
	btn.flat = true
	_apply_item_style(btn)

	if is_locked:
		btn.disabled = true
		var unlock_pop = item.get("unlock_population", 0)
		btn.tooltip_text = "Unlocks at %s population" % UIManager.format_number(unlock_pop)
		btn.add_theme_color_override("font_color", UIManager.COLORS.text_disabled)
		btn.add_theme_color_override("font_disabled_color", UIManager.COLORS.text_disabled)
	else:
		btn.pressed.connect(func():
			item_selected.emit(item.get("id", ""), item)
		)
		# Rich tooltip on hover (only for unlocked items with building_data)
		if item.has("building_data"):
			btn.mouse_entered.connect(_on_building_hover.bind(btn, item))
			btn.mouse_exited.connect(_on_building_hover_exit.bind(btn))

	_item_container.add_child(btn)


func _add_zone_item(item: Dictionary) -> void:
	var btn = Button.new()
	btn.text = item.get("label", "?")
	btn.custom_minimum_size = Vector2(100, 60)
	btn.flat = true

	var zone_color = item.get("color", UIManager.COLORS.accent)
	var style_normal = UIManager.get_button_normal_style(zone_color.darkened(0.5))
	style_normal.border_color = zone_color
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = UIManager.get_button_hover_style(zone_color.darkened(0.3))
	style_hover.border_color = zone_color.lightened(0.2)
	style_hover.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = UIManager.get_button_pressed_style(zone_color.darkened(0.2))
	style_pressed.border_color = zone_color.lightened(0.3)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.add_theme_color_override("font_color", UIManager.COLORS.text)
	btn.add_theme_color_override("font_hover_color", UIManager.COLORS.text)
	btn.add_theme_font_size_override("font_size", ThemeConstants.FONT_SMALL)

	btn.pressed.connect(func():
		item_selected.emit(item.get("id", ""), item)
	)

	# Tooltip on hover
	if item.get("desc", "") != "":
		btn.mouse_entered.connect(_on_building_hover.bind(btn, item))
		btn.mouse_exited.connect(_on_building_hover_exit.bind(btn))

	_item_container.add_child(btn)


func _add_overlay_item(item: Dictionary) -> void:
	var btn = Button.new()
	btn.text = item.get("label", "?")
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(90, 60)
	btn.flat = true
	_apply_item_style(btn)

	btn.toggled.connect(func(_pressed: bool):
		item_selected.emit(item.get("id", ""), item)
	)

	_item_container.add_child(btn)


func _add_terrain_item(item: Dictionary) -> void:
	var btn = Button.new()
	var icon = item.get("icon", "")
	var label_text = item.get("label", "?")
	btn.text = "%s %s" % [icon, label_text]
	btn.custom_minimum_size = Vector2(100, 60)
	btn.flat = true
	_apply_item_style(btn)

	btn.pressed.connect(func():
		item_selected.emit(item.get("id", ""), item)
	)

	_item_container.add_child(btn)


func _apply_item_style(btn: Button) -> void:
	btn.add_theme_font_size_override("font_size", ThemeConstants.FONT_SMALL)
	btn.add_theme_color_override("font_color", UIManager.COLORS.text)
	btn.add_theme_color_override("font_hover_color", UIManager.COLORS.text)
	btn.add_theme_color_override("font_pressed_color", UIManager.COLORS.accent)

	var style_normal = UIManager.get_button_normal_style()
	style_normal.bg_color = UIManager.COLORS.panel_bg.lightened(0.05)
	style_normal.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = UIManager.get_button_hover_style()
	style_hover.bg_color = UIManager.COLORS.panel_bg.lightened(0.15)
	btn.add_theme_stylebox_override("hover", style_hover)

	var style_pressed = UIManager.get_button_pressed_style()
	style_pressed.bg_color = UIManager.COLORS.accent.darkened(0.3)
	btn.add_theme_stylebox_override("pressed", style_pressed)
