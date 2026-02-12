extends CanvasLayer
class_name OptionsPanel
## Game options and settings panel

signal closed()

var panel_visible: bool = false

# UI References
var panel: PanelContainer
var content: VBoxContainer
var _graphics_manager: Node = null
var _graphics_environment: Environment = null
var _quality_options: OptionButton = null
var _shadow_quality_options: OptionButton = null
var _ssr_toggle: CheckButton = null
var _ssao_toggle: CheckButton = null
var _volumetric_fog_toggle: CheckButton = null
var _glow_toggle: CheckButton = null
var _auto_quality_toggle: CheckButton = null
var _exposure_slider: HSlider = null
var _white_point_slider: HSlider = null


func _ready() -> void:
	layer = 96
	visible = false
	if _graphics_manager == null and has_node("/root/GraphicsSettingsManager"):
		_graphics_manager = get_node("/root/GraphicsSettingsManager")
	_build_ui()
	_bind_graphics_environment_if_needed()
	_sync_graphics_controls()


func _build_ui() -> void:
	# Create centered container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Main panel
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 350)

	# Use centralized modal style
	var style = UIManager.get_modal_style()
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	# Content
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)

	# Header
	var header = HBoxContainer.new()
	content.add_child(header)

	var title = Label.new()
	title.text = "Options"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UIManager.COLORS.text)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(hide_panel)
	header.add_child(close_btn)

	# Separator
	var sep = HSeparator.new()
	content.add_child(sep)

	# Current Difficulty Display
	_add_section("Game Settings")

	var diff_row = _create_info_row("Difficulty", GameConfig.get_difficulty_name())
	content.add_child(diff_row)

	# Game Speed Default
	var speed_row = HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 10)
	content.add_child(speed_row)

	var speed_label = Label.new()
	speed_label.text = "Default Speed:"
	speed_label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	speed_label.custom_minimum_size.x = 120
	speed_row.add_child(speed_label)

	var speed_options = OptionButton.new()
	speed_options.add_item("Slow (1x)", 1)
	speed_options.add_item("Normal (2x)", 2)
	speed_options.add_item("Fast (3x)", 3)
	speed_options.select(Simulation.current_speed - 1 if Simulation.current_speed > 0 else 0)
	speed_options.item_selected.connect(_on_speed_changed)
	speed_row.add_child(speed_options)

	# Teaching Tips Toggle
	var tips_row = HBoxContainer.new()
	tips_row.add_theme_constant_override("separation", 10)
	content.add_child(tips_row)

	var tips_label = Label.new()
	tips_label.text = "Teaching Tips:"
	tips_label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	tips_label.custom_minimum_size.x = 120
	tips_row.add_child(tips_label)

	var tips_toggle = CheckButton.new()
	tips_toggle.text = "Enabled"
	tips_toggle.button_pressed = TeachingSystem.is_enabled() if TeachingSystem else true
	tips_toggle.toggled.connect(_on_tips_toggled)
	tips_row.add_child(tips_toggle)

	# Separator
	content.add_child(HSeparator.new())

	# Graphics Section
	_add_section("Graphics")

	var quality_row = HBoxContainer.new()
	quality_row.add_theme_constant_override("separation", 10)
	content.add_child(quality_row)

	var quality_label = Label.new()
	quality_label.text = "Quality Preset:"
	quality_label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	quality_label.custom_minimum_size.x = 120
	quality_row.add_child(quality_label)

	_quality_options = OptionButton.new()
	_quality_options.add_item("Low", 0)
	_quality_options.add_item("Medium", 1)
	_quality_options.add_item("High", 2)
	_quality_options.add_item("Ultra", 3)
	_quality_options.item_selected.connect(_on_graphics_quality_selected)
	quality_row.add_child(_quality_options)

	var shadow_row = HBoxContainer.new()
	shadow_row.add_theme_constant_override("separation", 10)
	content.add_child(shadow_row)

	var shadow_label = Label.new()
	shadow_label.text = "Shadow Quality:"
	shadow_label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	shadow_label.custom_minimum_size.x = 120
	shadow_row.add_child(shadow_label)

	_shadow_quality_options = OptionButton.new()
	_shadow_quality_options.add_item("Low", 0)
	_shadow_quality_options.add_item("Medium", 1)
	_shadow_quality_options.add_item("High", 2)
	_shadow_quality_options.add_item("Ultra", 3)
	_shadow_quality_options.item_selected.connect(_on_shadow_quality_selected)
	shadow_row.add_child(_shadow_quality_options)

	_ssr_toggle = CheckButton.new()
	_ssr_toggle.text = "SSR"
	_ssr_toggle.toggled.connect(_on_ssr_toggled)
	content.add_child(_ssr_toggle)

	_ssao_toggle = CheckButton.new()
	_ssao_toggle.text = "SSAO"
	_ssao_toggle.toggled.connect(_on_ssao_toggled)
	content.add_child(_ssao_toggle)

	_volumetric_fog_toggle = CheckButton.new()
	_volumetric_fog_toggle.text = "Volumetric Fog"
	_volumetric_fog_toggle.toggled.connect(_on_volumetric_fog_toggled)
	content.add_child(_volumetric_fog_toggle)

	_glow_toggle = CheckButton.new()
	_glow_toggle.text = "Bloom/Glow"
	_glow_toggle.toggled.connect(_on_glow_toggled)
	content.add_child(_glow_toggle)

	_auto_quality_toggle = CheckButton.new()
	_auto_quality_toggle.text = "Auto Quality Tuning"
	_auto_quality_toggle.toggled.connect(_on_auto_quality_toggled)
	content.add_child(_auto_quality_toggle)

	var exposure_row = HBoxContainer.new()
	exposure_row.add_theme_constant_override("separation", 10)
	content.add_child(exposure_row)

	var exposure_label = Label.new()
	exposure_label.text = "Exposure:"
	exposure_label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	exposure_label.custom_minimum_size.x = 120
	exposure_row.add_child(exposure_label)

	_exposure_slider = HSlider.new()
	_exposure_slider.min_value = 0.7
	_exposure_slider.max_value = 1.6
	_exposure_slider.step = 0.01
	_exposure_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_exposure_slider.value_changed.connect(_on_exposure_changed)
	exposure_row.add_child(_exposure_slider)

	var white_row = HBoxContainer.new()
	white_row.add_theme_constant_override("separation", 10)
	content.add_child(white_row)

	var white_label = Label.new()
	white_label.text = "White Point:"
	white_label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	white_label.custom_minimum_size.x = 120
	white_row.add_child(white_label)

	_white_point_slider = HSlider.new()
	_white_point_slider.min_value = 0.9
	_white_point_slider.max_value = 1.8
	_white_point_slider.step = 0.01
	_white_point_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_white_point_slider.value_changed.connect(_on_white_point_changed)
	white_row.add_child(_white_point_slider)

	# Separator
	content.add_child(HSeparator.new())

	# Audio Section (placeholder)
	_add_section("Audio")

	var audio_note = Label.new()
	audio_note.text = "Audio settings coming soon..."
	audio_note.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	audio_note.add_theme_font_size_override("font_size", 16)
	content.add_child(audio_note)

	# Separator
	content.add_child(HSeparator.new())

	# Keyboard Shortcuts Reference
	_add_section("Keyboard Shortcuts")

	var shortcuts = GridContainer.new()
	shortcuts.columns = 2
	shortcuts.add_theme_constant_override("h_separation", 20)
	shortcuts.add_theme_constant_override("v_separation", 4)
	content.add_child(shortcuts)

	_add_shortcut_row(shortcuts, "Space", "Pause/Resume")
	_add_shortcut_row(shortcuts, "1/2/3", "Set Speed")
	_add_shortcut_row(shortcuts, "D", "Dashboard")
	_add_shortcut_row(shortcuts, "B", "Budget")
	_add_shortcut_row(shortcuts, "A", "Advisors")
	_add_shortcut_row(shortcuts, "O", "Ordinances")
	_add_shortcut_row(shortcuts, "T", "Trade Deals")
	_add_shortcut_row(shortcuts, "ESC", "Close/Cancel")


func _add_section(title_text: String) -> void:
	var section = Label.new()
	section.text = title_text
	section.add_theme_font_size_override("font_size", 18)
	section.add_theme_color_override("font_color", UIManager.COLORS.accent)
	content.add_child(section)


func _create_info_row(label_text: String, value_text: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	label.custom_minimum_size.x = 120
	row.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", UIManager.COLORS.text)
	row.add_child(value)

	return row


func _add_shortcut_row(parent: Control, key: String, action: String) -> void:
	var key_label = Label.new()
	key_label.text = key
	key_label.add_theme_color_override("font_color", UIManager.COLORS.accent)
	key_label.add_theme_font_size_override("font_size", 14)
	key_label.custom_minimum_size.x = 70
	parent.add_child(key_label)

	var action_label = Label.new()
	action_label.text = action
	action_label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	action_label.add_theme_font_size_override("font_size", 14)
	parent.add_child(action_label)


func _on_speed_changed(index: int) -> void:
	var speed = index + 1  # 1, 2, or 3
	Simulation.set_speed(speed)


func _on_tips_toggled(enabled: bool) -> void:
	if TeachingSystem:
		if enabled:
			TeachingSystem.enable()
		else:
			TeachingSystem.disable()


func set_graphics_manager(manager: Node) -> void:
	_graphics_manager = manager


func set_graphics_environment(env: Environment) -> void:
	_graphics_environment = env
	_bind_graphics_environment_if_needed()
	_sync_graphics_controls()


func _bind_graphics_environment_if_needed() -> void:
	if _graphics_manager and _graphics_environment and _graphics_manager.has_method("bind_environment"):
		_graphics_manager.bind_environment(_graphics_environment)


func _on_graphics_quality_selected(index: int) -> void:
	if _graphics_manager == null:
		return
	if _graphics_manager.has_method("set_quality_preset"):
		_graphics_manager.set_quality_preset(index, true)
	elif _graphics_environment and _graphics_manager.has_method("apply_preset"):
		_graphics_manager.apply_preset(_graphics_environment, index)
	_sync_graphics_controls()
	_persist_graphics_settings()


func _on_shadow_quality_selected(index: int) -> void:
	if _graphics_manager == null:
		return
	if _graphics_manager.has_method("set_shadow_quality"):
		_graphics_manager.set_shadow_quality(index, true)
	_persist_graphics_settings()


func _on_ssr_toggled(enabled: bool) -> void:
	if _graphics_manager == null:
		return
	if _graphics_manager.has_method("set_ssr_override"):
		_graphics_manager.set_ssr_override(enabled, true)
	elif _graphics_environment and _graphics_manager.has_method("set_ssr_enabled"):
		_graphics_manager.set_ssr_enabled(_graphics_environment, enabled)
	_persist_graphics_settings()


func _on_ssao_toggled(enabled: bool) -> void:
	if _graphics_manager == null:
		return
	if _graphics_manager.has_method("set_ssao_override"):
		_graphics_manager.set_ssao_override(enabled, true)
	elif _graphics_environment and _graphics_manager.has_method("set_ssao_enabled"):
		_graphics_manager.set_ssao_enabled(_graphics_environment, enabled)
	_persist_graphics_settings()


func _on_volumetric_fog_toggled(enabled: bool) -> void:
	if _graphics_manager == null:
		return
	if _graphics_manager.has_method("set_volumetric_fog_override"):
		_graphics_manager.set_volumetric_fog_override(enabled, true)
	elif _graphics_environment and _graphics_manager.has_method("set_volumetric_fog_enabled"):
		_graphics_manager.set_volumetric_fog_enabled(_graphics_environment, enabled)
	_persist_graphics_settings()


func _on_glow_toggled(enabled: bool) -> void:
	if _graphics_manager == null:
		return
	if _graphics_manager.has_method("set_cinematic_grade"):
		var current = _graphics_manager.get_current_settings() if _graphics_manager.has_method("get_current_settings") else {}
		_graphics_manager.set_cinematic_grade(
			float(current.get("tonemap_exposure", 1.0)),
			float(current.get("tonemap_white", 1.0)),
			enabled,
			true
		)
		_persist_graphics_settings()


func _on_exposure_changed(value: float) -> void:
	if _graphics_manager == null:
		return
	if _graphics_manager.has_method("set_cinematic_grade"):
		var current = _graphics_manager.get_current_settings() if _graphics_manager.has_method("get_current_settings") else {}
		_graphics_manager.set_cinematic_grade(
			value,
			float(current.get("tonemap_white", 1.0)),
			bool(current.get("glow_enabled", true)),
			true
		)
		_persist_graphics_settings()


func _on_white_point_changed(value: float) -> void:
	if _graphics_manager == null:
		return
	if _graphics_manager.has_method("set_cinematic_grade"):
		var current = _graphics_manager.get_current_settings() if _graphics_manager.has_method("get_current_settings") else {}
		_graphics_manager.set_cinematic_grade(
			float(current.get("tonemap_exposure", 1.0)),
			value,
			bool(current.get("glow_enabled", true)),
			true
		)
		_persist_graphics_settings()


func _on_auto_quality_toggled(enabled: bool) -> void:
	if _graphics_manager == null:
		return
	if _graphics_manager.has_method("set_auto_quality_enabled"):
		_graphics_manager.set_auto_quality_enabled(enabled)
	_persist_graphics_settings()


func _persist_graphics_settings() -> void:
	if _graphics_manager and _graphics_manager.has_method("save_settings_to_disk"):
		_graphics_manager.save_settings_to_disk()


func _sync_graphics_controls() -> void:
	if _graphics_manager == null:
		return
	if not _graphics_manager.has_method("get_current_settings"):
		return

	var settings = _graphics_manager.get_current_settings()
	if _quality_options:
		var preset = int(settings.get("preset", 2))
		var item_index = _quality_options.get_item_index(preset)
		if item_index >= 0:
			_quality_options.select(item_index)
	if _shadow_quality_options:
		var shadow_quality = int(settings.get("shadow_quality", 2))
		var shadow_index = _shadow_quality_options.get_item_index(shadow_quality)
		if shadow_index >= 0:
			_shadow_quality_options.select(shadow_index)
	if _ssr_toggle:
		_ssr_toggle.button_pressed = bool(settings.get("ssr_enabled", true))
	if _ssao_toggle:
		_ssao_toggle.button_pressed = bool(settings.get("ssao_enabled", true))
	if _volumetric_fog_toggle:
		_volumetric_fog_toggle.button_pressed = bool(settings.get("volumetric_fog_enabled", true))
	if _glow_toggle:
		_glow_toggle.button_pressed = bool(settings.get("glow_enabled", true))
	if _exposure_slider:
		_exposure_slider.value = float(settings.get("tonemap_exposure", 1.0))
	if _white_point_slider:
		_white_point_slider.value = float(settings.get("tonemap_white", 1.0))
	if _auto_quality_toggle:
		_auto_quality_toggle.button_pressed = bool(settings.get("auto_quality_enabled", true))


func show_panel() -> void:
	if panel_visible:
		return
	panel_visible = true
	visible = true


func hide_panel() -> void:
	if not panel_visible:
		return
	panel_visible = false
	visible = false
	closed.emit()


func toggle() -> void:
	if panel_visible:
		hide_panel()
	else:
		show_panel()


func _input(event: InputEvent) -> void:
	if panel_visible and event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			hide_panel()
			get_viewport().set_input_as_handled()
