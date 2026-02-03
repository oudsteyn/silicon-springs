extends CanvasLayer
class_name OptionsPanel
## Game options and settings panel

signal closed()

var panel_visible: bool = false

# UI References
var panel: PanelContainer
var content: VBoxContainer


func _ready() -> void:
	layer = 96
	visible = false
	_build_ui()


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
	title.add_theme_font_size_override("font_size", 18)
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

	# Audio Section (placeholder)
	_add_section("Audio")

	var audio_note = Label.new()
	audio_note.text = "Audio settings coming soon..."
	audio_note.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	audio_note.add_theme_font_size_override("font_size", 12)
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
	section.add_theme_font_size_override("font_size", 14)
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
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.custom_minimum_size.x = 60
	parent.add_child(key_label)

	var action_label = Label.new()
	action_label.text = action
	action_label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	action_label.add_theme_font_size_override("font_size", 11)
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
