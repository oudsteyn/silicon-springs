extends PanelContainer
class_name DifficultySelector
## Modal panel for selecting game difficulty

signal difficulty_selected(difficulty: GameConfigClass.Difficulty)
signal cancelled()

const DIFFICULTY_INFO: Dictionary = {
	GameConfigClass.Difficulty.EASY: {
		"name": "Easy",
		"icon": "lightbulb",
		"color": Color(0.3, 0.8, 0.3),
		"description": "Perfect for learning the basics.",
		"details": [
			"$200,000 starting budget",
			"Faster city growth",
			"No disasters",
			"Lower maintenance costs",
			"Longer bankruptcy grace period"
		]
	},
	GameConfigClass.Difficulty.NORMAL: {
		"name": "Normal",
		"icon": "city",
		"color": Color(0.3, 0.6, 0.9),
		"description": "Balanced challenge for most players.",
		"details": [
			"$100,000 starting budget",
			"Standard growth rates",
			"Random disasters enabled",
			"Normal maintenance costs",
			"12-month bankruptcy threshold"
		]
	},
	GameConfigClass.Difficulty.HARD: {
		"name": "Hard",
		"icon": "warning",
		"color": Color(0.9, 0.5, 0.2),
		"description": "For experienced city builders.",
		"details": [
			"$50,000 starting budget",
			"Slower city growth",
			"More frequent disasters",
			"Higher maintenance costs",
			"6-month bankruptcy threshold"
		]
	},
	GameConfigClass.Difficulty.SANDBOX: {
		"name": "Sandbox",
		"icon": "palette",
		"color": Color(0.7, 0.5, 0.9),
		"description": "Build freely without restrictions.",
		"details": [
			"$10,000,000 starting budget",
			"Rapid city growth",
			"No disasters",
			"No maintenance costs",
			"Unlimited experimentation"
		]
	}
}

var _selected_difficulty: GameConfigClass.Difficulty = GameConfigClass.Difficulty.NORMAL
var _difficulty_buttons: Dictionary = {}
var _start_button: Button
var _cancel_button: Button
var _details_label: RichTextLabel


func _ready() -> void:
	_setup_ui()
	_select_difficulty(GameConfigClass.Difficulty.NORMAL)


func _setup_ui() -> void:
	# Panel styling
	custom_minimum_size = Vector2(600, 500)

	var style = UIManager.get_modal_style()
	style.set_corner_radius_all(ThemeConstants.RADIUS_LARGE + 4)
	style.set_content_margin_all(24)
	add_theme_stylebox_override("panel", style)

	# Main layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "SELECT DIFFICULTY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UIManager.COLORS.text)
	vbox.add_child(title)

	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Choose how challenging you want your city-building experience"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", ThemeConstants.FONT_MEDIUM)
	subtitle.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	vbox.add_child(subtitle)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size.y = 8
	vbox.add_child(spacer1)

	# Difficulty buttons grid
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	# Create difficulty buttons
	for diff in DIFFICULTY_INFO:
		var btn = _create_difficulty_button(diff)
		grid.add_child(btn)
		_difficulty_buttons[diff] = btn

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 8
	vbox.add_child(spacer2)

	# Details panel
	var details_panel = PanelContainer.new()
	var details_style = UIManager.get_panel_style(ThemeConstants.RADIUS_LARGE)
	details_style.bg_color = UIManager.COLORS.background
	details_style.set_content_margin_all(ThemeConstants.MARGIN_LARGE)
	details_panel.add_theme_stylebox_override("panel", details_style)
	details_panel.custom_minimum_size.y = 120
	vbox.add_child(details_panel)

	_details_label = RichTextLabel.new()
	_details_label.bbcode_enabled = true
	_details_label.fit_content = true
	_details_label.scroll_active = false
	details_panel.add_child(_details_label)

	# Button row
	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(button_row)

	# Cancel button
	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(100, 40)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	button_row.add_child(_cancel_button)

	# Start button
	_start_button = Button.new()
	_start_button.text = "Start Game"
	_start_button.custom_minimum_size = Vector2(140, 40)
	_start_button.pressed.connect(_on_start_pressed)
	button_row.add_child(_start_button)

	# Style the start button
	var start_style = UIManager.get_button_active_style()
	start_style.bg_color = ThemeConstants.STATUS_GOOD.darkened(0.3)
	_start_button.add_theme_stylebox_override("normal", start_style)

	var start_hover = start_style.duplicate()
	start_hover.bg_color = ThemeConstants.STATUS_GOOD.darkened(0.15)
	_start_button.add_theme_stylebox_override("hover", start_hover)


func _create_difficulty_button(difficulty: GameConfigClass.Difficulty) -> Button:
	var info = DIFFICULTY_INFO[difficulty]
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(260, 80)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.text = "  " + info.name + "\n  " + info.description
	btn.pressed.connect(_on_difficulty_pressed.bind(difficulty))

	# Base style
	var style = UIManager.get_panel_style(ThemeConstants.RADIUS_LARGE)
	style.bg_color = UIManager.COLORS.panel_bg.lightened(0.05)
	style.border_width_left = 3
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0
	style.border_color = info.color
	style.set_content_margin_all(12)
	btn.add_theme_stylebox_override("normal", style)

	# Hover style
	var hover_style = style.duplicate()
	hover_style.bg_color = UIManager.COLORS.panel_bg.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_style)

	# Pressed/selected style
	var pressed_style = style.duplicate()
	pressed_style.bg_color = UIManager.COLORS.panel_bg.lightened(0.2)
	pressed_style.border_width_left = 4
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn


func _on_difficulty_pressed(difficulty: GameConfigClass.Difficulty) -> void:
	_select_difficulty(difficulty)


func _select_difficulty(difficulty: GameConfigClass.Difficulty) -> void:
	_selected_difficulty = difficulty

	# Update button states
	for diff in _difficulty_buttons:
		var btn: Button = _difficulty_buttons[diff]
		var info = DIFFICULTY_INFO[diff]

		if diff == difficulty:
			# Selected state
			var style = UIManager.get_panel_style(ThemeConstants.RADIUS_LARGE)
			style.bg_color = UIManager.COLORS.panel_bg.lightened(0.2)
			style.border_width_left = 4
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1
			style.border_color = info.color
			btn.add_theme_stylebox_override("normal", style)
			btn.add_theme_stylebox_override("hover", style)
		else:
			# Normal state
			var style = UIManager.get_panel_style(ThemeConstants.RADIUS_LARGE)
			style.bg_color = UIManager.COLORS.panel_bg.lightened(0.05)
			style.border_width_left = 3
			style.border_color = info.color
			btn.add_theme_stylebox_override("normal", style)

			var hover_style = style.duplicate()
			hover_style.bg_color = UIManager.COLORS.panel_bg.lightened(0.15)
			btn.add_theme_stylebox_override("hover", hover_style)

	# Update details
	_update_details(difficulty)


func _update_details(difficulty: GameConfigClass.Difficulty) -> void:
	var info = DIFFICULTY_INFO[difficulty]
	var color_hex = info.color.to_html(false)

	var text = "[color=#" + color_hex + "][b]" + info.name + "[/b][/color]\n\n"

	for detail in info.details:
		text += "[color=#8a9199]\u2022[/color] " + detail + "\n"

	_details_label.text = text


func _on_start_pressed() -> void:
	difficulty_selected.emit(_selected_difficulty)


func _on_cancel_pressed() -> void:
	cancelled.emit()


## Show the selector as a modal
func show_modal() -> void:
	# Center on screen
	var viewport_size = get_viewport().get_visible_rect().size
	position = (viewport_size - custom_minimum_size) / 2
	visible = true
	# Grab focus
	_difficulty_buttons[_selected_difficulty].grab_focus()


## Hide the selector
func hide_modal() -> void:
	visible = false


## Get the currently selected difficulty
func get_selected_difficulty() -> GameConfigClass.Difficulty:
	return _selected_difficulty
