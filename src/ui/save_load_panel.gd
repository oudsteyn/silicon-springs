extends PanelContainer
class_name SaveLoadPanel
## UI panel for saving and loading games

signal closed()

enum Mode { SAVE, LOAD }
var current_mode: Mode = Mode.SAVE

var save_system: SaveSystem = null

@onready var title_label: Label = $MarginContainer/VBox/TitleBar/TitleLabel
@onready var close_button: Button = $MarginContainer/VBox/TitleBar/CloseButton
@onready var save_name_container: HBoxContainer = $MarginContainer/VBox/SaveNameContainer
@onready var save_name_input: LineEdit = $MarginContainer/VBox/SaveNameContainer/SaveNameInput
@onready var saves_container: VBoxContainer = $MarginContainer/VBox/ScrollContainer/SavesContainer
@onready var action_button: Button = $MarginContainer/VBox/ActionButton
@onready var mode_tabs: HBoxContainer = $MarginContainer/VBox/ModeTabs
@onready var save_tab: Button = $MarginContainer/VBox/ModeTabs/SaveTab
@onready var load_tab: Button = $MarginContainer/VBox/ModeTabs/LoadTab

var selected_save_path: String = ""


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	action_button.pressed.connect(_on_action_pressed)
	save_tab.pressed.connect(_on_save_tab_pressed)
	load_tab.pressed.connect(_on_load_tab_pressed)
	visible = false
	_apply_styling()


func _apply_styling() -> void:
	# Apply centralized panel styling
	var style = UIManager.get_modal_style()
	add_theme_stylebox_override("panel", style)

	# Style title using theme constants
	if title_label:
		title_label.add_theme_color_override("font_color", UIManager.COLORS.text)
		title_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_LARGE)

	# Style action button with centralized styling
	if action_button:
		var btn_style = UIManager.get_button_active_style()
		btn_style.set_content_margin_all(ThemeConstants.MARGIN_NORMAL)
		action_button.add_theme_stylebox_override("normal", btn_style)
		action_button.add_theme_color_override("font_color", UIManager.COLORS.text)


func set_save_system(system: SaveSystem) -> void:
	save_system = system


func show_panel(mode: Mode = Mode.SAVE) -> void:
	current_mode = mode
	_update_mode_ui()
	_refresh_saves_list()
	visible = true


func hide_panel() -> void:
	visible = false


func _update_mode_ui() -> void:
	match current_mode:
		Mode.SAVE:
			title_label.text = "Save Game"
			save_name_container.visible = true
			action_button.text = "Save"
			save_tab.button_pressed = true
			load_tab.button_pressed = false
			save_name_input.text = "City_%s" % GameState.get_date_string().replace(" ", "_")
		Mode.LOAD:
			title_label.text = "Load Game"
			save_name_container.visible = false
			action_button.text = "Load"
			save_tab.button_pressed = false
			load_tab.button_pressed = true

	selected_save_path = ""
	_update_action_button()


func _refresh_saves_list() -> void:
	# Clear existing saves
	for child in saves_container.get_children():
		child.queue_free()

	if not save_system:
		return

	var saves = save_system.get_save_files()

	if saves.is_empty():
		var label = Label.new()
		label.text = "No saved games found."
		label.modulate = Color(0.7, 0.7, 0.7)
		saves_container.add_child(label)
		return

	for save_info in saves:
		var item = _create_save_item(save_info)
		saves_container.add_child(item)


func _create_save_item(info: Dictionary) -> Control:
	var panel = PanelContainer.new()

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label = Label.new()
	name_label.text = info.name
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	var details_label = Label.new()
	details_label.text = "Pop: %d | %s" % [info.population, info.date]
	details_label.add_theme_font_size_override("font_size", 11)
	details_label.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(details_label)

	hbox.add_child(vbox)

	var button_container = VBoxContainer.new()

	var select_button = Button.new()
	select_button.text = "Select"
	select_button.custom_minimum_size = Vector2(60, 0)
	select_button.pressed.connect(_on_save_selected.bind(info.path, info.name))
	button_container.add_child(select_button)

	var delete_button = Button.new()
	delete_button.text = "Delete"
	delete_button.custom_minimum_size = Vector2(60, 0)
	delete_button.modulate = Color(1.0, 0.5, 0.5)
	delete_button.pressed.connect(_on_delete_pressed.bind(info.path))
	button_container.add_child(delete_button)

	hbox.add_child(button_container)
	panel.add_child(hbox)

	return panel


func _on_save_selected(path: String, save_name: String) -> void:
	selected_save_path = path
	if current_mode == Mode.SAVE:
		save_name_input.text = save_name
	_update_action_button()


func _update_action_button() -> void:
	match current_mode:
		Mode.SAVE:
			action_button.disabled = save_name_input.text.strip_edges().is_empty()
		Mode.LOAD:
			action_button.disabled = selected_save_path.is_empty()


func _on_action_pressed() -> void:
	if not save_system:
		return

	match current_mode:
		Mode.SAVE:
			var save_name = save_name_input.text.strip_edges()
			if save_name.is_empty():
				return
			if save_system.save_game(save_name):
				hide_panel()
		Mode.LOAD:
			if selected_save_path.is_empty():
				return
			if save_system.load_game(selected_save_path):
				hide_panel()


func _on_delete_pressed(path: String) -> void:
	if save_system and save_system.delete_save(path):
		_refresh_saves_list()
		if selected_save_path == path:
			selected_save_path = ""
			_update_action_button()


func _on_save_tab_pressed() -> void:
	current_mode = Mode.SAVE
	_update_mode_ui()
	_refresh_saves_list()


func _on_load_tab_pressed() -> void:
	current_mode = Mode.LOAD
	_update_mode_ui()
	_refresh_saves_list()


func _on_close_pressed() -> void:
	visible = false
	closed.emit()
