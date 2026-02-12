extends Node
## Main game controller - coordinates new minimalist UI with game world

@onready var game_world = $GameWorld
@onready var world_environment: WorldEnvironment = $WorldEnvironment

# New minimalist UI components
var status_pill: StatusPill
var tool_palette: ToolPalette
var dashboard_panel: DashboardPanel
var toast_system: ToastNotificationSystem
var difficulty_selector: DifficultySelector

# Modal panels (loaded from scenes)
var advisor_panel: AdvisorPanel
var ordinance_panel: OrdinancePanel
var neighbor_deals_panel: NeighborDealsPanel
var save_load_panel: SaveLoadPanel
var options_panel: OptionsPanel

# Terrain editor
var terrain_editor: TerrainEditor = null
var _pending_terrain_system: TerrainSystem = null

# Game state
var _game_started: bool = false


func _ready() -> void:
	# Show difficulty selector first
	_show_difficulty_selector()


func _start_game() -> void:
	if _game_started:
		return
	_game_started = true

	# Create new minimalist UI
	_create_new_ui()

	# Defer grid system setup to ensure all nodes are ready
	call_deferred("_setup_grid_system")

	# Connect UIManager signals
	_connect_ui_manager()
	_configure_runtime_graphics_quality()

	# Reset game state with new difficulty
	GameState.reset_game()


func _show_difficulty_selector() -> void:
	# Pause simulation during selection
	Simulation.is_paused = true

	# Create difficulty selector
	difficulty_selector = DifficultySelector.new()
	difficulty_selector.difficulty_selected.connect(_on_difficulty_selected)
	difficulty_selector.cancelled.connect(_on_difficulty_cancelled)
	add_child(difficulty_selector)

	# Register as modal to hide tooltips etc
	UIManager.open_panel("difficulty")

	# Show as modal
	call_deferred("_position_difficulty_selector")


func _position_difficulty_selector() -> void:
	if difficulty_selector:
		difficulty_selector.show_modal()


func _on_difficulty_selected(difficulty: GameConfigClass.Difficulty) -> void:
	# Apply selected difficulty
	GameConfig.apply_difficulty(difficulty)

	# Reset progression systems for new game
	if UnlockSystem:
		UnlockSystem.reset_unlocks()
	if TeachingSystem:
		TeachingSystem.reset()

	# Remove selector
	if difficulty_selector:
		difficulty_selector.queue_free()
		difficulty_selector = null
	UIManager.close_panel("difficulty")

	# Show terrain editor before starting game
	_show_terrain_editor()


func _show_terrain_editor() -> void:
	# Create terrain editor
	var editor_scene = load("res://src/ui/terrain_editor.tscn")
	if editor_scene:
		terrain_editor = editor_scene.instantiate()
		terrain_editor.editor_closed.connect(_on_terrain_editor_closed)
		add_child(terrain_editor)
		UIManager.open_panel("terrain_editor")
	else:
		# Fallback: start game without terrain editor
		_finish_game_start()


func _on_terrain_editor_closed(start_game: bool, terrain_sys: TerrainSystem) -> void:
	if start_game and terrain_sys:
		_pending_terrain_system = terrain_sys

	# Remove editor (it queues itself for free when not starting)
	if terrain_editor and start_game:
		# Reparent terrain system to preserve it
		if terrain_sys:
			terrain_editor.remove_child(terrain_sys)
		terrain_editor.queue_free()
		terrain_editor = null
	UIManager.close_panel("terrain_editor")

	if start_game:
		_finish_game_start()
	else:
		# User cancelled - go back to difficulty selector
		_show_difficulty_selector()


func _finish_game_start() -> void:
	# Start the game
	_start_game()

	# Apply pending terrain if we have it
	if _pending_terrain_system and game_world.terrain_system:
		# Copy terrain data from editor to game world's terrain system
		var terrain_data = _pending_terrain_system.get_terrain_data()
		game_world.terrain_system.load_terrain_data(terrain_data)
		game_world.terrain_renderer.refresh()

		# Apply biome to weather system and GameState
		if _pending_terrain_system.current_biome:
			GameState.set_biome(_pending_terrain_system.current_biome)
			if game_world.weather_system:
				game_world.weather_system.set_biome(_pending_terrain_system.current_biome)
			if game_world.day_night_system:
				game_world.day_night_system.set_biome(_pending_terrain_system.current_biome)

	_pending_terrain_system = null

	# Unpause simulation
	Simulation.is_paused = false

	# Show welcome notification
	var diff_name = GameConfig.get_difficulty_name()
	Events.simulation_event.emit("generic_success", {"message": "Starting new city on " + diff_name + " difficulty"})


func _on_difficulty_cancelled() -> void:
	# For now, just start with Normal difficulty if cancelled
	_on_difficulty_selected(GameConfigClass.Difficulty.NORMAL)


func _create_new_ui() -> void:
	# Status Pill (top-left, compact status)
	status_pill = StatusPill.new()
	add_child(status_pill)
	UIManager.status_pill = status_pill

	# Tool Palette (left edge, vertical tool strip)
	tool_palette = ToolPalette.new()
	add_child(tool_palette)
	UIManager.tool_palette = tool_palette

	# Dashboard Panel (modal, hidden by default)
	dashboard_panel = DashboardPanel.new()
	add_child(dashboard_panel)
	UIManager.dashboard_panel = dashboard_panel

	# Toast notification system
	toast_system = ToastNotificationSystem.new()
	add_child(toast_system)

	# Load and add modal panels
	_create_modal_panels()

	# Connect tool palette signals
	tool_palette.building_selected.connect(_on_building_selected)
	tool_palette.zone_selected.connect(_on_zone_selected)
	tool_palette.demolish_selected.connect(_on_demolish_selected)
	tool_palette.overlay_selected.connect(_on_overlay_selected)
	tool_palette.setting_selected.connect(_on_setting_selected)

	# Connect dashboard panel_requested signal
	dashboard_panel.panel_requested.connect(_on_dashboard_panel_requested)


func _create_modal_panels() -> void:
	# Advisor Panel
	var advisor_scene = load("res://src/ui/advisor_panel.tscn")
	if advisor_scene:
		advisor_panel = advisor_scene.instantiate()
		add_child(advisor_panel)
		advisor_panel.closed.connect(func(): UIManager.close_panel("advisors"))

	# Ordinance Panel
	var ordinance_scene = load("res://src/ui/ordinance_panel.tscn")
	if ordinance_scene:
		ordinance_panel = ordinance_scene.instantiate()
		add_child(ordinance_panel)
		ordinance_panel.closed.connect(func(): UIManager.close_panel("ordinances"))
		# Connect to Ordinances autoload
		if Ordinances:
			ordinance_panel.set_ordinance_system(Ordinances)

	# Neighbor Deals Panel
	var deals_scene = load("res://src/ui/neighbor_deals_panel.tscn")
	if deals_scene:
		neighbor_deals_panel = deals_scene.instantiate()
		add_child(neighbor_deals_panel)
		neighbor_deals_panel.closed.connect(func(): UIManager.close_panel("deals"))
		# Connect to NeighborDeals autoload
		if NeighborDeals:
			neighbor_deals_panel.set_neighbor_deals(NeighborDeals)

	# Save/Load Panel
	var save_load_scene = load("res://src/ui/save_load_panel.tscn")
	if save_load_scene:
		save_load_panel = save_load_scene.instantiate()
		add_child(save_load_panel)
		save_load_panel.closed.connect(func(): UIManager.close_panel("save_load"))
		# Connect to SaveManager autoload
		if SaveManager:
			save_load_panel.set_save_system(SaveManager)

	# Options Panel (dynamically created)
	options_panel = OptionsPanel.new()
	if GraphicsSettingsManager:
		options_panel.set_graphics_manager(GraphicsSettingsManager)
	if world_environment and world_environment.environment:
		options_panel.set_graphics_environment(world_environment.environment)
	add_child(options_panel)
	options_panel.closed.connect(func(): UIManager.close_panel("options"))


func _setup_grid_system() -> void:
	# Set grid system references
	# Note: ToolPalette uses event-driven queries
	SaveManager.set_grid_system(game_world.grid_system)
	SaveManager.set_terrain_system(game_world.terrain_system)
	SaveManager.set_weather_system(game_world.weather_system)
	SaveManager.set_power_system(game_world.power_system)
	SaveManager.set_water_system(game_world.water_system)
	SaveManager.set_pollution_system(game_world.pollution_system)
	SaveManager.set_infrastructure_age_system(game_world.infrastructure_age_system)

	# Connect info panel events
	Events.info_panel_requested.connect(_on_info_panel_requested)

	# Initial power/water calculation
	await get_tree().process_frame
	game_world.power_system.calculate_power()
	game_world.water_system.calculate_water()


func _connect_ui_manager() -> void:
	UIManager.panel_opened.connect(_on_panel_opened)
	UIManager.panel_closed.connect(_on_panel_closed)


func _configure_runtime_graphics_quality() -> void:
	if GraphicsSettingsManager and world_environment and world_environment.environment:
		GraphicsSettingsManager.bind_environment(world_environment.environment)
	if RenderPerformanceMonitor and GraphicsSettingsManager:
		RenderPerformanceMonitor.set_graphics_apply_callback(_apply_recommended_quality)


func _apply_recommended_quality(tier: int) -> void:
	if GraphicsSettingsManager == null:
		return
	if GraphicsSettingsManager.has_method("is_auto_quality_enabled") and not GraphicsSettingsManager.is_auto_quality_enabled():
		return
	match tier:
		0:
			GraphicsSettingsManager.set_quality_preset(GraphicsSettingsManager.QualityPreset.LOW, true)
		1:
			GraphicsSettingsManager.set_quality_preset(GraphicsSettingsManager.QualityPreset.MEDIUM, true)
		_:
			GraphicsSettingsManager.set_quality_preset(GraphicsSettingsManager.QualityPreset.HIGH, true)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		# Don't process shortcuts if a modal is capturing input
		var no_modifiers = not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed

		# B key opens budget panel
		if event.keycode == KEY_B and no_modifiers:
			UIManager.toggle_panel("budget")
			get_viewport().set_input_as_handled()

		# D key opens dashboard panel
		if event.keycode == KEY_D and no_modifiers and not event.shift_pressed:
			UIManager.toggle_panel("dashboard")
			get_viewport().set_input_as_handled()

		# A key opens advisors panel
		if event.keycode == KEY_A and no_modifiers:
			_toggle_advisor_panel()
			get_viewport().set_input_as_handled()

		# O key opens ordinances panel
		if event.keycode == KEY_O and no_modifiers:
			_toggle_ordinance_panel()
			get_viewport().set_input_as_handled()

		# T key opens trade/deals panel
		if event.keycode == KEY_T and no_modifiers:
			_toggle_deals_panel()
			get_viewport().set_input_as_handled()

		# ESC closes modals or cancels current action
		if event.keycode == KEY_ESCAPE:
			if UIManager.is_modal_open():
				UIManager.close_all_panels()
				get_viewport().set_input_as_handled()
			elif UIManager.get_open_flyouts().size() > 0:
				UIManager.close_all_flyouts()
				get_viewport().set_input_as_handled()


# Tool Palette signal handlers
func _on_building_selected(building_id: String) -> void:
	game_world.enter_build_mode(building_id)


func _on_zone_selected(zone_type: int) -> void:
	game_world.enter_zone_mode(zone_type)


func _on_demolish_selected() -> void:
	game_world.enter_demolish_mode()


func _on_overlay_selected(mode: int) -> void:
	# Toggle overlay mode
	if mode == 0:
		game_world.grid_overlay.set_overlay_mode(game_world.grid_overlay.OverlayMode.NONE)
	else:
		# Map mode numbers to overlay methods
		match mode:
			1: game_world.grid_overlay.toggle_power_overlay()
			2: game_world.grid_overlay.toggle_water_overlay()
			3: game_world.grid_overlay.toggle_pollution_overlay()
			4: game_world.grid_overlay.toggle_land_value_overlay()
			5: game_world.grid_overlay.toggle_services_overlay()
			6: game_world.grid_overlay.toggle_traffic_overlay()
			7: game_world.grid_overlay.toggle_zones_overlay()


func _on_setting_selected(action: String) -> void:
	# Handle settings actions
	match action:
		"dashboard":
			UIManager.toggle_panel("dashboard")
		"budget":
			UIManager.toggle_panel("budget")
		"save":
			_show_save_dialog()
		"load":
			_show_load_dialog()
		"options":
			_show_options_dialog()


func _show_save_dialog() -> void:
	if save_load_panel:
		save_load_panel.show_panel(SaveLoadPanel.Mode.SAVE)
		UIManager.open_panel("save_load")
	else:
		# Fallback to autosave
		SaveManager.save_game("autosave")
		Events.simulation_event.emit("game_saved", {"name": "autosave"})


func _show_load_dialog() -> void:
	if save_load_panel:
		save_load_panel.show_panel(SaveLoadPanel.Mode.LOAD)
		UIManager.open_panel("save_load")
	else:
		# Fallback to autosave
		if SaveManager.load_game("autosave"):
			Events.simulation_event.emit("game_loaded", {"name": "autosave"})
		else:
			Events.simulation_event.emit("game_load_failed", {})


func _show_options_dialog() -> void:
	if options_panel:
		options_panel.show_panel()
		UIManager.open_panel("options")


# Panel management
func _on_panel_opened(panel_name: String) -> void:
	match panel_name:
		"dashboard":
			if dashboard_panel.has_method("show_panel"):
				dashboard_panel.show_panel()
			elif not dashboard_panel.is_visible:
				dashboard_panel.toggle()
		"budget":
			if CityEventBus:
				CityEventBus.finance_panel_toggled.emit(true)
		"advisors":
			if advisor_panel and not advisor_panel.visible:
				advisor_panel.show_panel()
		"ordinances":
			if ordinance_panel and not ordinance_panel.visible:
				ordinance_panel.show_panel()
		"deals":
			if neighbor_deals_panel and not neighbor_deals_panel.visible:
				neighbor_deals_panel.show_panel()
		"save_load":
			if save_load_panel and not save_load_panel.visible:
				save_load_panel.show_panel()
		"options":
			if options_panel and not options_panel.is_visible:
				options_panel.show_panel()


func _on_panel_closed(panel_name: String) -> void:
	match panel_name:
		"dashboard":
			if dashboard_panel.has_method("hide_panel"):
				dashboard_panel.hide_panel()
			elif dashboard_panel.is_visible:
				dashboard_panel.toggle()
		"budget":
			if CityEventBus:
				CityEventBus.finance_panel_toggled.emit(false)
		"advisors":
			if advisor_panel and advisor_panel.visible:
				advisor_panel.hide_panel()
		"ordinances":
			if ordinance_panel and ordinance_panel.visible:
				ordinance_panel.hide_panel()
		"deals":
			if neighbor_deals_panel and neighbor_deals_panel.visible:
				neighbor_deals_panel.hide_panel()
		"save_load":
			if save_load_panel and save_load_panel.visible:
				save_load_panel.hide_panel()
		"options":
			if options_panel and options_panel.is_visible:
				options_panel.hide_panel()


func _on_info_panel_requested(data: Dictionary) -> void:
	# Legacy info panel retired; ignore request for now.
	_ = data


func _on_dashboard_panel_requested(panel_name: String) -> void:
	# Handle opening panels from dashboard quick actions
	match panel_name:
		"budget":
			UIManager.toggle_panel("budget")
		"advisors":
			_toggle_advisor_panel()
		"ordinances":
			_toggle_ordinance_panel()
		"deals":
			_toggle_deals_panel()


# Panel toggle helpers (used by both keyboard shortcuts and dashboard buttons)
func _toggle_advisor_panel() -> void:
	if advisor_panel:
		if advisor_panel.visible:
			advisor_panel.hide_panel()
			UIManager.close_panel("advisors")
		else:
			advisor_panel.show_panel()
			UIManager.open_panel("advisors")


func _toggle_ordinance_panel() -> void:
	if ordinance_panel:
		if ordinance_panel.visible:
			ordinance_panel.hide_panel()
			UIManager.close_panel("ordinances")
		else:
			ordinance_panel.show_panel()
			UIManager.open_panel("ordinances")


func _toggle_deals_panel() -> void:
	if neighbor_deals_panel:
		if neighbor_deals_panel.visible:
			neighbor_deals_panel.hide_panel()
			UIManager.close_panel("deals")
		else:
			neighbor_deals_panel.show_panel()
			UIManager.open_panel("deals")
