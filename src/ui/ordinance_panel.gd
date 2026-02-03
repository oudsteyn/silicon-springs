extends PanelContainer
class_name OrdinancePanel
## UI panel for managing city ordinances

signal closed()

var ordinance_system: OrdinanceSystem = null

@onready var title_label: Label = $MarginContainer/VBox/TitleBar/TitleLabel
@onready var close_button: Button = $MarginContainer/VBox/TitleBar/CloseButton
@onready var category_tabs: TabContainer = $MarginContainer/VBox/CategoryTabs
@onready var total_cost_label: Label = $MarginContainer/VBox/Footer/TotalCostLabel

const CATEGORIES = ["safety", "environment", "economy", "education", "transportation", "quality"]
const CATEGORY_NAMES = {
	"safety": "Safety",
	"environment": "Environment",
	"economy": "Economy",
	"education": "Education",
	"transportation": "Transportation",
	"quality": "Quality of Life"
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

	# Style footer
	if total_cost_label:
		total_cost_label.add_theme_color_override("font_color", UIManager.COLORS.warning)


func set_ordinance_system(system: OrdinanceSystem) -> void:
	ordinance_system = system
	ordinance_system.ordinance_enacted.connect(_on_ordinance_changed)
	ordinance_system.ordinance_repealed.connect(_on_ordinance_changed)
	_build_ui()


func _build_ui() -> void:
	if not ordinance_system:
		return

	# Clear existing tabs
	for child in category_tabs.get_children():
		child.queue_free()

	# Create tab for each category
	for category in CATEGORIES:
		var scroll = ScrollContainer.new()
		scroll.name = CATEGORY_NAMES[category]
		scroll.custom_minimum_size = Vector2(350, 250)

		var vbox = VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var ordinances = ordinance_system.get_ordinances_by_category(category)
		for ordinance in ordinances:
			var item = _create_ordinance_item(ordinance.id, ordinance.data)
			vbox.add_child(item)

		scroll.add_child(vbox)
		category_tabs.add_child(scroll)

	_update_total_cost()


func _create_ordinance_item(ordinance_id: String, data: Dictionary) -> Control:
	var panel = PanelContainer.new()

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = data.name
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = data.description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.modulate = Color(0.7, 0.7, 0.7)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.custom_minimum_size.x = 250
	vbox.add_child(desc_label)

	var cost_label = Label.new()
	cost_label.text = "Cost: $%d/mo" % data.monthly_cost
	cost_label.add_theme_font_size_override("font_size", 11)
	cost_label.modulate = Color(1.0, 0.8, 0.3)
	vbox.add_child(cost_label)

	hbox.add_child(vbox)

	var button = Button.new()
	button.custom_minimum_size = Vector2(80, 0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if ordinance_system.is_enacted(ordinance_id):
		button.text = "Repeal"
		button.modulate = Color(1.0, 0.5, 0.5)
		button.pressed.connect(_on_repeal_pressed.bind(ordinance_id))
	else:
		button.text = "Enact"
		button.modulate = Color(0.5, 1.0, 0.5)
		button.pressed.connect(_on_enact_pressed.bind(ordinance_id))

		var check = ordinance_system.can_enact(ordinance_id)
		if not check.can_enact:
			button.disabled = true
			button.modulate = Color(0.5, 0.5, 0.5)

	hbox.add_child(button)
	panel.add_child(hbox)

	return panel


func _on_enact_pressed(ordinance_id: String) -> void:
	ordinance_system.enact_ordinance(ordinance_id)


func _on_repeal_pressed(ordinance_id: String) -> void:
	ordinance_system.repeal_ordinance(ordinance_id)


func _on_ordinance_changed(_ordinance_id: String) -> void:
	_build_ui()


func _update_total_cost() -> void:
	if ordinance_system:
		var cost = ordinance_system.get_total_monthly_cost()
		total_cost_label.text = "Total Ordinance Cost: $%d/mo" % cost


func _on_close_pressed() -> void:
	visible = false
	closed.emit()


func show_panel() -> void:
	_build_ui()
	visible = true


func hide_panel() -> void:
	visible = false
