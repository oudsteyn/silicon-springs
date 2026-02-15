extends PanelContainer
class_name CategorySubPanel
## Slide-up sub-panel showing items for a selected toolbar category
## Used by BottomToolbar to display building/zone/overlay/terrain items

signal item_selected(item_id: String, item_data: Dictionary)
signal closed()

const PANEL_HEIGHT: int = 80
const ITEM_SPACING: int = 6
const ANIM_DURATION: float = 0.2

var _scroll: ScrollContainer
var _item_container: HBoxContainer
var _panel_type: String = ""
var _tween: Tween = null
var _initialized: bool = false


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
	for child in _item_container.get_children():
		_item_container.remove_child(child)
		child.queue_free()
	_panel_type = ""


func get_item_count() -> int:
	_ensure_initialized()
	return _item_container.get_child_count()


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
