extends CanvasLayer
class_name TerrainEditor
## Pre-game terrain editor for customizing maps before playing

# Tool types
enum TerrainTool { RAISE, LOWER, FLATTEN, WATER, TREE, ROCK, ERASER }

# Signals
signal editor_closed(start_game: bool, terrain_system: TerrainSystem)

# Systems
var terrain_system: TerrainSystem
var terrain_renderer: TerrainRenderer

# UI Components
var main_panel: PanelContainer
var biome_dropdown: OptionButton
var seed_input: SpinBox
var tool_buttons: Dictionary = {}
var preview_viewport: SubViewport
var preview_camera: Camera2D
var template_selection_panel: PanelContainer

# State
var current_tool: TerrainTool = TerrainTool.RAISE
var current_biome_id: String = ""
var current_seed: int = 12345
var is_painting: bool = false

# Biome presets loaded from resources
var biome_presets: Dictionary = {}  # id -> BiomePreset


func _ready() -> void:
	layer = 100  # On top of everything
	_load_biomes()
	_create_terrain_systems()
	_create_ui()
	_generate_terrain()


func _load_biomes() -> void:
	var biome_dir = "res://src/data/biomes/"
	var dir = DirAccess.open(biome_dir)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var biome = load(biome_dir + file_name) as BiomePreset
				if biome:
					biome_presets[biome.id] = biome
			file_name = dir.get_next()
		dir.list_dir_end()

	# Set default biome
	if biome_presets.has("great_river_valley"):
		current_biome_id = "great_river_valley"
	elif biome_presets.size() > 0:
		current_biome_id = biome_presets.keys()[0]


func _create_terrain_systems() -> void:
	# Create terrain system
	terrain_system = TerrainSystem.new()
	add_child(terrain_system)

	# Create terrain renderer
	terrain_renderer = TerrainRenderer.new()
	terrain_renderer.set_terrain_system(terrain_system)
	# Renderer will be added to preview viewport


func _create_ui() -> void:
	# Main container
	main_panel = PanelContainer.new()
	main_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Use simple panel style with background color
	var style = UIManager.get_panel_style(0)
	style.bg_color = UIManager.COLORS.background
	style.set_border_width_all(0)
	main_panel.add_theme_stylebox_override("panel", style)

	add_child(main_panel)

	# Main layout: VBox with header, content, footer
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 16)
	main_panel.add_child(main_vbox)

	# Header
	_create_header(main_vbox)

	# Content (tools + preview)
	var content = HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(content)

	# Left panel - tools
	_create_tool_panel(content)

	# Center - preview
	_create_preview_panel(content)

	# Right panel - biome info
	_create_info_panel(content)

	# Footer - action buttons
	_create_footer(main_vbox)


func _create_header(parent: Control) -> void:
	var header = HBoxContainer.new()
	header.custom_minimum_size.y = 50
	parent.add_child(header)

	# Back button
	var back_btn = Button.new()
	back_btn.text = "< Back"
	back_btn.pressed.connect(_on_back_pressed)
	_style_button(back_btn)
	header.add_child(back_btn)

	# Title
	var title = Label.new()
	title.text = "Terrain Editor"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", UIManager.COLORS.text)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)

	# Spacer for balance
	var spacer = Control.new()
	spacer.custom_minimum_size.x = 80
	header.add_child(spacer)


func _create_tool_panel(parent: Control) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 200
	var panel_style = UIManager.get_panel_style(ThemeConstants.RADIUS_LARGE)
	panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Biome selector
	var biome_label = Label.new()
	biome_label.text = "Biome"
	biome_label.add_theme_color_override("font_color", UIManager.COLORS.text)
	vbox.add_child(biome_label)

	biome_dropdown = OptionButton.new()
	var idx = 0
	var selected_idx = 0
	for biome_id in biome_presets:
		var biome = biome_presets[biome_id]
		biome_dropdown.add_item(biome.display_name, idx)
		biome_dropdown.set_item_metadata(idx, biome_id)
		if biome_id == current_biome_id:
			selected_idx = idx
		idx += 1
	biome_dropdown.selected = selected_idx
	biome_dropdown.item_selected.connect(_on_biome_selected)
	vbox.add_child(biome_dropdown)

	# Seed input
	var seed_label = Label.new()
	seed_label.text = "Seed"
	seed_label.add_theme_color_override("font_color", UIManager.COLORS.text)
	vbox.add_child(seed_label)

	var seed_hbox = HBoxContainer.new()
	vbox.add_child(seed_hbox)

	seed_input = SpinBox.new()
	seed_input.min_value = 0
	seed_input.max_value = 999999
	seed_input.value = current_seed
	seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_input.value_changed.connect(_on_seed_changed)
	seed_hbox.add_child(seed_input)

	var regen_btn = Button.new()
	regen_btn.text = "Regen"
	regen_btn.pressed.connect(_on_regenerate_pressed)
	_style_button(regen_btn)
	seed_hbox.add_child(regen_btn)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Tools label
	var tools_label = Label.new()
	tools_label.text = "Tools"
	tools_label.add_theme_color_override("font_color", UIManager.COLORS.text)
	vbox.add_child(tools_label)

	# Tool buttons
	var tools = [
		{"id": TerrainTool.RAISE, "label": "Raise", "icon": "^"},
		{"id": TerrainTool.LOWER, "label": "Lower", "icon": "v"},
		{"id": TerrainTool.FLATTEN, "label": "Flatten", "icon": "-"},
		{"id": TerrainTool.WATER, "label": "Water", "icon": "~"},
		{"id": TerrainTool.TREE, "label": "Tree", "icon": "T"},
		{"id": TerrainTool.ROCK, "label": "Rock", "icon": "O"},
		{"id": TerrainTool.ERASER, "label": "Eraser", "icon": "X"},
	]

	for tool_def in tools:
		var btn = Button.new()
		btn.text = "%s %s" % [tool_def.icon, tool_def.label]
		btn.toggle_mode = true
		btn.pressed.connect(_on_tool_selected.bind(tool_def.id))
		_style_button(btn)
		vbox.add_child(btn)
		tool_buttons[tool_def.id] = btn

	# Set initial tool
	tool_buttons[TerrainTool.RAISE].button_pressed = true


func _create_preview_panel(parent: Control) -> void:
	var container = PanelContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var container_style = UIManager.get_panel_style(ThemeConstants.RADIUS_LARGE)
	container_style.bg_color = Color(0.1, 0.1, 0.1)
	container.add_theme_stylebox_override("panel", container_style)
	parent.add_child(container)

	# SubViewportContainer for the preview
	var viewport_container = SubViewportContainer.new()
	viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	viewport_container.stretch = true
	container.add_child(viewport_container)

	# SubViewport
	preview_viewport = SubViewport.new()
	preview_viewport.size = Vector2i(800, 600)
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(preview_viewport)

	# Add terrain renderer to viewport
	preview_viewport.add_child(terrain_renderer)

	# Camera for preview
	preview_camera = Camera2D.new()
	preview_camera.position = Vector2(GridConstants.GRID_WIDTH * GridConstants.CELL_SIZE * 0.5, GridConstants.GRID_HEIGHT * GridConstants.CELL_SIZE * 0.5)
	preview_camera.zoom = Vector2(0.15, 0.15)  # Zoom out to see full map
	preview_viewport.add_child(preview_camera)
	terrain_renderer.set_camera(preview_camera)

	# Connect input for painting
	viewport_container.gui_input.connect(_on_viewport_input)


func _create_info_panel(parent: Control) -> void:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = 250
	var panel_style = UIManager.get_panel_style(ThemeConstants.RADIUS_LARGE)
	panel.add_theme_stylebox_override("panel", panel_style)
	parent.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# Info header
	var header = Label.new()
	header.text = "Biome Info"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", UIManager.COLORS.text)
	vbox.add_child(header)

	# Biome description
	var desc_label = Label.new()
	desc_label.name = "BiomeDescription"
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
	vbox.add_child(desc_label)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Stats
	var stats_label = Label.new()
	stats_label.name = "BiomeStats"
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.add_theme_color_override("font_color", UIManager.COLORS.text)
	vbox.add_child(stats_label)

	# Update info
	_update_biome_info()


func _create_footer(parent: Control) -> void:
	var footer = HBoxContainer.new()
	footer.custom_minimum_size.y = 60
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 16)
	parent.add_child(footer)

	# Save template button
	var save_btn = Button.new()
	save_btn.text = "Save Template"
	save_btn.pressed.connect(_on_save_template_pressed)
	_style_button(save_btn)
	footer.add_child(save_btn)

	# Load template button
	var load_btn = Button.new()
	load_btn.text = "Load Template"
	load_btn.pressed.connect(_on_load_template_pressed)
	_style_button(load_btn)
	footer.add_child(load_btn)

	# Spacer
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	# Start game button
	var start_btn = Button.new()
	start_btn.text = "Start Game"
	start_btn.custom_minimum_size.x = 150
	start_btn.pressed.connect(_on_start_game_pressed)
	_style_button(start_btn, true)
	footer.add_child(start_btn)


func _style_button(btn: Button, primary: bool = false) -> void:
	if primary:
		btn.add_theme_stylebox_override("normal", UIManager.get_button_active_style())
		var hover = UIManager.get_button_active_style()
		hover.bg_color = hover.bg_color.lightened(0.15)
		btn.add_theme_stylebox_override("hover", hover)
	else:
		btn.add_theme_stylebox_override("normal", UIManager.get_button_normal_style())
		btn.add_theme_stylebox_override("hover", UIManager.get_button_hover_style())

	var style_pressed = UIManager.get_button_normal_style()
	style_pressed.bg_color = style_pressed.bg_color.darkened(0.1)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	btn.add_theme_color_override("font_color", UIManager.COLORS.text)


func _update_biome_info() -> void:
	if not current_biome_id or not biome_presets.has(current_biome_id):
		return

	var biome = biome_presets[current_biome_id]

	# Update description
	var desc_label = main_panel.find_child("BiomeDescription", true, false)
	if desc_label:
		desc_label.text = biome.description

	# Update stats
	var stats_label = main_panel.find_child("BiomeStats", true, false)
	if stats_label:
		var stats = """Temperature: %.0f C (%.0f to %.0f)
Precipitation: %.0f%%
Water Scarcity: %.1fx
Heating Cost: %.1fx
Cooling Cost: %.1fx
Storm Chance: %.0f%%
Flood Risk: %.0f%%
Solar Intensity: %.1fx""" % [
			biome.avg_temperature,
			biome.avg_temperature - biome.temp_variation,
			biome.avg_temperature + biome.temp_variation,
			biome.precipitation * 100,
			biome.water_scarcity,
			biome.heating_cost_mult,
			biome.cooling_cost_mult,
			biome.storm_chance * 100,
			biome.flood_risk * 100,
			biome.sun_intensity
		]
		stats_label.text = stats


# ============================================
# INPUT HANDLING
# ============================================

func _on_viewport_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_painting = event.pressed
			if is_painting:
				_apply_tool_at_mouse(event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			preview_camera.zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			preview_camera.zoom /= 1.1

	elif event is InputEventMouseMotion and is_painting:
		_apply_tool_at_mouse(event.position)


func _apply_tool_at_mouse(mouse_pos: Vector2) -> void:
	# Convert mouse position to world coordinates
	var viewport_size = preview_viewport.size
	var world_pos = preview_camera.position + (mouse_pos - Vector2(viewport_size) / 2) / preview_camera.zoom
	var cell = Vector2i(int(world_pos.x / GridConstants.CELL_SIZE), int(world_pos.y / GridConstants.CELL_SIZE))

	if cell.x < 0 or cell.x >= GridConstants.GRID_WIDTH or cell.y < 0 or cell.y >= GridConstants.GRID_HEIGHT:
		return

	match current_tool:
		TerrainTool.RAISE:
			terrain_system.raise_elevation(cell)
		TerrainTool.LOWER:
			terrain_system.lower_elevation(cell)
		TerrainTool.FLATTEN:
			terrain_system.flatten(cell)
		TerrainTool.WATER:
			terrain_system.toggle_water(cell)
		TerrainTool.TREE:
			terrain_system.toggle_feature(cell, TerrainSystem.FeatureType.TREE_SPARSE)
		TerrainTool.ROCK:
			terrain_system.toggle_feature(cell, TerrainSystem.FeatureType.ROCK_SMALL)
		TerrainTool.ERASER:
			terrain_system.flatten(cell)
			terrain_system.set_water(cell, TerrainSystem.WaterType.NONE)
			terrain_system.remove_feature(cell)


# ============================================
# CALLBACKS
# ============================================

func _on_biome_selected(index: int) -> void:
	current_biome_id = biome_dropdown.get_item_metadata(index)
	_update_biome_info()
	_generate_terrain()


func _on_seed_changed(value: float) -> void:
	current_seed = int(value)


func _on_regenerate_pressed() -> void:
	_generate_terrain()


func _on_tool_selected(tool: TerrainTool) -> void:
	current_tool = tool
	# Update button states
	for tool_id in tool_buttons:
		tool_buttons[tool_id].button_pressed = (tool_id == tool)


func _on_back_pressed() -> void:
	editor_closed.emit(false, null)
	queue_free()


func _on_start_game_pressed() -> void:
	# Pass the terrain system to the game
	editor_closed.emit(true, terrain_system)
	# Don't free - main.gd will handle cleanup after getting terrain


func _on_save_template_pressed() -> void:
	# Create template from current terrain
	var template = TerrainTemplate.create_from_terrain(terrain_system, "Custom Map")
	template.seed_value = current_seed
	template.biome_id = current_biome_id

	# Generate filename
	var filename = TerrainTemplate.generate_filename("custom_map")

	# Save
	if TerrainTemplate.save_to_file(template, filename):
		Events.simulation_event.emit("template_saved", {"name": "Custom Map"})
	else:
		Events.simulation_event.emit("generic_error", {"message": "Failed to save template"})


func _on_load_template_pressed() -> void:
	# Get list of templates
	var templates = TerrainTemplate.list_saved_templates()

	if templates.is_empty():
		Events.simulation_event.emit("generic_info", {"message": "No saved templates found"})
		return

	_show_template_selection_dialog(templates)


func _show_template_selection_dialog(templates: Array[Dictionary]) -> void:
	# Remove existing dialog if present
	if template_selection_panel and is_instance_valid(template_selection_panel):
		template_selection_panel.queue_free()

	# Create overlay panel
	template_selection_panel = PanelContainer.new()
	template_selection_panel.set_anchors_preset(Control.PRESET_CENTER)
	template_selection_panel.custom_minimum_size = Vector2(400, 350)

	var style = UIManager.get_panel_style(ThemeConstants.RADIUS_MEDIUM)
	style.bg_color = Color(0.1, 0.12, 0.16, 0.98)
	style.border_color = Color(0.3, 0.35, 0.4)
	style.set_border_width_all(1)
	template_selection_panel.add_theme_stylebox_override("panel", style)

	add_child(template_selection_panel)

	# Content layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	template_selection_panel.add_child(vbox)

	# Header
	var header = Label.new()
	header.text = "Load Template"
	header.add_theme_font_size_override("font_size", ThemeConstants.FONT_LARGE)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Scrollable template list
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 220)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list_vbox = VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", 6)
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_vbox)

	# Add template entries
	for template_info in templates:
		var entry = _create_template_entry(template_info)
		list_vbox.add_child(entry)

	# Cancel button
	var button_row = HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_row)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 32)
	cancel_btn.pressed.connect(_close_template_selection_dialog)
	button_row.add_child(cancel_btn)


func _create_template_entry(template_info: Dictionary) -> PanelContainer:
	var entry = PanelContainer.new()
	entry.custom_minimum_size = Vector2(360, 50)

	var entry_style = StyleBoxFlat.new()
	entry_style.bg_color = Color(0.15, 0.17, 0.22, 0.9)
	entry_style.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
	entry_style.content_margin_left = ThemeConstants.PADDING_NORMAL
	entry_style.content_margin_right = ThemeConstants.PADDING_NORMAL
	entry_style.content_margin_top = ThemeConstants.PADDING_SMALL
	entry_style.content_margin_bottom = ThemeConstants.PADDING_SMALL
	entry.add_theme_stylebox_override("panel", entry_style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	entry.add_child(hbox)

	# Template info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = template_info.get("name", "Unnamed")
	if template_info.get("bundled", false):
		name_label.text += " (Built-in)"
	name_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_NORMAL)
	info_vbox.add_child(name_label)

	var details_label = Label.new()
	var biome_name = template_info.get("biome_id", "unknown").replace("_", " ").capitalize()
	var created = template_info.get("created", "")
	if created.length() > 10:
		created = created.substr(0, 10)  # Just the date part
	details_label.text = "%s | Seed: %d" % [biome_name, template_info.get("seed", 0)]
	if created:
		details_label.text += " | %s" % created
	details_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SMALL)
	details_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
	info_vbox.add_child(details_label)

	# Load button
	var load_btn = Button.new()
	load_btn.text = "Load"
	load_btn.custom_minimum_size = Vector2(70, 30)
	load_btn.pressed.connect(_load_selected_template.bind(template_info.get("path", "")))
	hbox.add_child(load_btn)

	return entry


func _load_selected_template(path: String) -> void:
	_close_template_selection_dialog()

	var template = TerrainTemplate.load_from_file(path)
	if template:
		TerrainTemplate.apply_to_terrain(template, terrain_system)
		current_biome_id = template.biome_id
		current_seed = template.seed_value
		seed_input.value = current_seed

		# Update biome dropdown
		for i in range(biome_dropdown.item_count):
			if biome_dropdown.get_item_metadata(i) == current_biome_id:
				biome_dropdown.selected = i
				break

		_update_biome_info()
		Events.simulation_event.emit("template_loaded", {"name": template.name})


func _close_template_selection_dialog() -> void:
	if template_selection_panel and is_instance_valid(template_selection_panel):
		template_selection_panel.queue_free()
		template_selection_panel = null


func _generate_terrain() -> void:
	var biome = biome_presets.get(current_biome_id)
	terrain_system.generate_initial_terrain(current_seed, biome)
	terrain_renderer.refresh()
