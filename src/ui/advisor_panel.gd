extends PanelContainer
class_name AdvisorPanel
## UI panel displaying advisor recommendations

signal closed()

@onready var title_label: Label = $MarginContainer/VBox/TitleBar/TitleLabel
@onready var close_button: Button = $MarginContainer/VBox/TitleBar/CloseButton
@onready var advice_container: VBoxContainer = $MarginContainer/VBox/ScrollContainer/AdviceContainer

const PRIORITY_COLORS = {
	1: Color(0.6, 0.65, 0.7),  # Low - gray (text_dim)
	2: Color(0.85, 0.65, 0.25),  # Medium - warning
	3: Color(0.85, 0.3, 0.3)   # High - danger
}


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	visible = false
	_apply_styling()


func _apply_styling() -> void:
	# Apply centralized panel styling
	var style = UIManager.get_modal_style()
	add_theme_stylebox_override("panel", style)

	# Style title
	if title_label:
		title_label.add_theme_color_override("font_color", UIManager.COLORS.text)
		title_label.add_theme_font_size_override("font_size", 16)

	# Style close button
	if close_button:
		close_button.add_theme_color_override("font_color", UIManager.COLORS.text)


func show_panel() -> void:
	_refresh_advice()
	visible = true


func hide_panel() -> void:
	visible = false


func _refresh_advice() -> void:
	# Clear existing advice
	for child in advice_container.get_children():
		child.queue_free()

	# Get current advice
	var advice_list = Advisors.get_all_current_advice()

	if advice_list.is_empty():
		var label = Label.new()
		label.text = "No pressing concerns at this time.\nYour city is running smoothly!"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Color(0.7, 1.0, 0.7)
		advice_container.add_child(label)
		return

	for advice in advice_list:
		var item = _create_advice_item(advice)
		advice_container.add_child(item)


func _create_advice_item(advice: Dictionary) -> Control:
	var panel = PanelContainer.new()

	var vbox = VBoxContainer.new()

	var header = HBoxContainer.new()

	var advisor_label = Label.new()
	advisor_label.text = advice.advisor
	advisor_label.add_theme_font_size_override("font_size", 12)
	advisor_label.modulate = PRIORITY_COLORS.get(advice.priority, Color.WHITE)
	header.add_child(advisor_label)

	var priority_label = Label.new()
	match advice.priority:
		1: priority_label.text = " [Low]"
		2: priority_label.text = " [Medium]"
		3: priority_label.text = " [Urgent]"
	priority_label.add_theme_font_size_override("font_size", 10)
	priority_label.modulate = PRIORITY_COLORS.get(advice.priority, Color.WHITE)
	header.add_child(priority_label)

	vbox.add_child(header)

	var message_label = Label.new()
	message_label.text = advice.message
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	message_label.custom_minimum_size.x = 280
	vbox.add_child(message_label)

	var separator = HSeparator.new()
	vbox.add_child(separator)

	panel.add_child(vbox)
	return panel


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
