extends CanvasLayer
class_name DashboardPanel
## City dashboard panel with modular tab components
##
## Uses DashboardTabBase subclasses for each tab:
## - DashboardOverviewTab
## - DashboardInfrastructureTab
## - DashboardEconomyTab
## - DashboardEnvironmentTab
## - DashboardDistrictsTab

signal panel_requested(panel_name: String)

# Tab state
var current_tab: int = 0
var panel_visible: bool = false

# UI References
var main_panel: PanelContainer
var tab_bar: HBoxContainer
var content_container: VBoxContainer
var tabs: Dictionary = {}

# Modular tab components cache
var _tab_components: Dictionary = {}  # {tab_index: DashboardTabBase}


func _ready() -> void:
	layer = 95
	visible = false

	# Create centered panel container
	var center_container = CenterContainer.new()
	center_container.anchor_left = 0.0
	center_container.anchor_right = 1.0
	center_container.anchor_top = 0.0
	center_container.anchor_bottom = 1.0
	add_child(center_container)

	main_panel = PanelContainer.new()
	main_panel.custom_minimum_size = Vector2(650, 450)

	# Style the panel using centralized theme
	var stylebox = UIManager.get_modal_style()
	stylebox.bg_color = Color(0.08, 0.10, 0.14, 0.98)
	stylebox.content_margin_top = ThemeConstants.PADDING_LARGE - 4
	main_panel.add_theme_stylebox_override("panel", stylebox)
	center_container.add_child(main_panel)

	_build_ui()
	_connect_signals()


func toggle() -> void:
	if panel_visible:
		hide_panel()
	else:
		show_panel()


func show_panel() -> void:
	if panel_visible:
		return
	panel_visible = true
	visible = true
	_update_current_tab()


func hide_panel() -> void:
	if not panel_visible:
		return
	panel_visible = false
	visible = false


func _build_ui() -> void:
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	main_panel.add_child(main_vbox)

	# Header with title and close button
	var header = _create_header()
	main_vbox.add_child(header)

	# Tab bar
	tab_bar = _create_tab_bar()
	main_vbox.add_child(tab_bar)

	# Separator
	var sep = HSeparator.new()
	main_vbox.add_child(sep)

	# Content area with scroll
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 350)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	content_container = VBoxContainer.new()
	content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_container.add_theme_constant_override("separation", 12)
	scroll.add_child(content_container)

	# Build initial tab content
	_update_current_tab()


func _create_header() -> HBoxContainer:
	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)

	var title = Label.new()
	title.text = "City Dashboard"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(toggle)
	header.add_child(close_btn)

	return header


func _create_tab_bar() -> HBoxContainer:
	var bar = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)

	var tab_names = ["Overview", "Infrastructure", "Economy", "Environment", "Districts"]

	for i in range(tab_names.size()):
		var btn = Button.new()
		btn.text = tab_names[i]
		btn.toggle_mode = true
		btn.button_pressed = (i == 0)
		btn.custom_minimum_size = Vector2(100, 32)
		btn.pressed.connect(_on_tab_pressed.bind(i))
		bar.add_child(btn)
		tabs[i] = btn

	return bar


func _on_tab_pressed(index: int) -> void:
	current_tab = index

	# Update button states
	for i in tabs:
		tabs[i].button_pressed = (i == index)

	_update_current_tab()


func _update_current_tab() -> void:
	# Clear existing content
	for child in content_container.get_children():
		child.queue_free()

	# Build tab content using modular component
	var tab_component = _get_or_create_tab(current_tab)
	if tab_component:
		tab_component.build_content(content_container)


func _get_or_create_tab(index: int) -> DashboardTabBase:
	if _tab_components.has(index):
		return _tab_components[index]

	var tab: DashboardTabBase = null
	match index:
		0:
			tab = DashboardOverviewTab.new()
			if tab.has_signal("panel_requested"):
				tab.panel_requested.connect(func(panel_name): panel_requested.emit(panel_name))
		1:
			tab = DashboardInfrastructureTab.new()
		2:
			tab = DashboardEconomyTab.new()
		3:
			tab = DashboardEnvironmentTab.new()
		4:
			tab = DashboardDistrictsTab.new()

	if tab:
		_tab_components[index] = tab

	return tab


func _connect_signals() -> void:
	Events.month_tick.connect(_on_data_changed)
	Events.budget_updated.connect(func(_a, _b, _c): _on_data_changed())
	Events.population_changed.connect(func(_a, _b): _on_data_changed())


func _on_data_changed() -> void:
	if not panel_visible:
		return
	_update_current_tab()
