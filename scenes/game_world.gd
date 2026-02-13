extends Node2D
class_name GameWorld
## Main game world containing the grid, systems, and camera

const World3DBridgeScript = preload("res://src/world/world3d_bridge.gd")

# System Manager for dependency injection
var system_manager: SystemManager

# System Groups
@onready var core_systems: SystemGroup = $CoreSystems
@onready var utility_systems: SystemGroup = $UtilitySystems
@onready var city_systems: SystemGroup = $CitySystems
@onready var architect_systems: SystemGroup = $ArchitectSystems
@onready var renderers: SystemGroup = $Renderers

# Core systems (via groups)
@onready var grid_system = $CoreSystems/GridSystem
@onready var terrain_system = $CoreSystems/TerrainSystem
@onready var weather_system = $CoreSystems/WeatherSystem

# Utility systems (via groups)
@onready var power_system = $UtilitySystems/PowerSystem
@onready var water_system = $UtilitySystems/WaterSystem
@onready var pollution_system = $UtilitySystems/PollutionSystem

# City systems (via groups)
@onready var service_coverage = $CitySystems/ServiceCoverage
@onready var traffic_system = $CitySystems/TrafficSystem
@onready var land_value_system = $CitySystems/LandValueSystem
@onready var zoning_system = $CitySystems/ZoningSystem
@onready var disaster_system = $CitySystems/DisasterSystem

# Architect systems (via groups)
@onready var parking_system = $ArchitectSystems/ParkingSystem
@onready var economic_cluster_system = $ArchitectSystems/EconomicClusterSystem
@onready var housing_system = $ArchitectSystems/HousingSystem
@onready var infrastructure_age_system = $ArchitectSystems/InfrastructureAgeSystem
@onready var growth_boundary_system = $ArchitectSystems/GrowthBoundarySystem
@onready var commute_system = $ArchitectSystems/CommuteSystem
@onready var environment_system = $ArchitectSystems/EnvironmentSystem
@onready var district_system = $ArchitectSystems/DistrictSystem

# Renderers (via groups)
@onready var terrain_renderer = $Renderers/TerrainRenderer
@onready var building_renderer = $Renderers/BuildingRenderer
@onready var traffic_visualizer = $Renderers/TrafficVisualizer
@onready var coverage_visualizer = $Renderers/CoverageVisualizer
@onready var grid_overlay = $Renderers/GridOverlay

# UI elements (not in groups)
@onready var day_night_system = $DayNightSystem
@onready var zone_layer = $ZoneLayer
@onready var camera: Camera2D = $Camera2D
@onready var terrain_background: ColorRect = $TerrainBackground
@onready var grid_lines: Node2D = $GridLines
@onready var fine_grid: Node2D = $FineGrid
@onready var ghost_preview: ColorRect = $GhostPreview

# Enhanced grid visualization (Phase 1)
var cell_highlight: CellHighlight = null
var utility_flow_overlay: UtilityFlowOverlay = null
var _utility_flow_visible: bool = false

# Adaptive grid renderer (Phase 2) - replaces grid_lines + fine_grid
var adaptive_grid: AdaptiveGridRenderer = null

# Selection and preview overlays (Phase 3)
var drag_selection_overlay: DragSelectionOverlay = null
var path_preview_overlay: PathPreviewOverlay = null
var placement_preview_overlay: PlacementPreviewOverlay = null

# Heat map, minimap, and coordinate labels (Phase 4)
var heat_map_renderer: HeatMapRenderer = null
var minimap_overlay: MinimapOverlay = null
var grid_coordinate_labels: GridCoordinateLabels = null

# Tooltip, measurement, and feedback effects (Phase 5)
var cell_info_tooltip: CellInfoTooltip = null
var measurement_tool: MeasurementTool = null
var action_feedback_effects: ActionFeedbackEffects = null

# Fine grid settings
const FINE_GRID_RADIUS: int = 8  # Show grid within this many cells of cursor
const TERRAIN_RUNTIME_PIPELINE_ENABLED: bool = true
const TERRAIN_RUNTIME_EROSION_ITERATIONS: int = 1800
const ENABLE_CELL_INFO_TOOLTIP: bool = false

# Tool modes
enum ToolMode { SELECT, PAN, BUILD, DEMOLISH, ZONE, TERRAIN }
var current_tool: ToolMode = ToolMode.SELECT

# Terrain tool state
var current_terrain_tool: String = ""  # "raise", "lower", "flatten", "water", "tree", "rock"

# Zone painting state
var zone_mode: bool = false
var current_zone_type: int = 0  # ZoningSystem.ZoneType
var zone_paint_start: Vector2i = Vector2i(-1, -1)
var is_zone_painting: bool = false

# Build mode state
var build_mode: bool = false
var demolish_mode: bool = false
var current_building_id: String = ""
var current_building_data = null  # BuildingData

# Drag-to-build state
var is_drag_building: bool = false
var is_drag_demolishing: bool = false
var last_drag_cell: Vector2i = Vector2i(-1, -1)

# Camera settings
const CAMERA_SPEED: float = 500.0
const ZOOM_SPEED: float = 0.1
const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.0

# Pan/grabber state
var is_panning: bool = false
var pan_start_mouse: Vector2 = Vector2.ZERO
var pan_start_camera: Vector2 = Vector2.ZERO

# Selection state
var selected_building = null  # Building
var hovered_cell: Vector2i = Vector2i(-1, -1)
var world3d_bridge: Node = null
var _cell_inspector_active: bool = false
var _cell_inspector_cell: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	# Add to group for easy finding
	add_to_group("game_world")

	# Center camera on the game board
	camera.position = Vector2(
		GridConstants.WORLD_WIDTH / 2.0,
		GridConstants.WORLD_HEIGHT / 2.0
	)

	# Connect UIManager tool changes
	UIManager.tool_changed.connect(_on_ui_manager_tool_changed)

	# Initialize SystemManager and register all systems
	_init_system_manager()

	# Additional wiring not handled by SystemManager
	_setup_additional_wiring()

	# Connect simulation to SystemManager for decoupled system access
	Simulation.set_system_manager(system_manager)

	# Set up building renderer for procedural textures
	building_renderer.set_grid_system(grid_system)

	# Setup ghost preview
	ghost_preview.visible = false
	ghost_preview.color = Color(1, 1, 1, 0.5)

	# Setup enhanced grid visualization (Phase 1, 2, 3, 4 & 5)
	_setup_cell_highlight()
	_setup_utility_flow_overlay()
	_setup_adaptive_grid()
	_setup_phase3_overlays()
	_setup_phase4_overlays()
	_setup_phase5_overlays()

	# Setup terrain
	_setup_terrain()
	_setup_world3d_bridge()

	# Connect events
	Events.build_mode_entered.connect(_on_build_mode_entered)
	Events.build_mode_exited.connect(_on_build_mode_exited)
	Events.demolish_mode_entered.connect(_on_demolish_mode_entered)
	Events.demolish_mode_exited.connect(_on_demolish_mode_exited)
	Events.year_tick.connect(_on_year_tick)

	# Connect query signals for decoupled UI data requests
	Events.cell_info_requested.connect(_on_cell_info_requested)
	Events.building_info_requested.connect(_on_building_info_requested)
	Events.building_catalog_requested.connect(_on_building_catalog_requested)
	Events.expense_breakdown_requested.connect(_on_expense_breakdown_requested)

	# Connect command signals for decoupled action execution
	Events.build_requested.connect(_on_build_requested)
	Events.demolish_requested.connect(_on_demolish_requested)
	Events.zone_requested.connect(_on_zone_requested)


## Initialize the SystemManager and register all systems with their dependencies
func _init_system_manager() -> void:
	system_manager = SystemManager.new()
	system_manager.name = "SystemManager"
	add_child(system_manager)

	# Register systems with their dependencies
	# Format: SystemManager.SystemMetadata.new(id, required_deps, optional_deps)
	var SM = SystemManager.SystemMetadata

	# Core systems (no dependencies)
	system_manager.register_system(grid_system, SM.new("grid", [], []))
	system_manager.register_system(weather_system, SM.new("weather", [], []))

	# Terrain depends on grid
	system_manager.register_system(terrain_system, SM.new("terrain", ["grid"], []))

	# Utility systems
	system_manager.register_system(power_system, SM.new("power", ["grid"], ["weather", "infrastructure_age"]))
	system_manager.register_system(water_system, SM.new("water", ["grid"], ["weather", "infrastructure_age"]))
	system_manager.register_system(service_coverage, SM.new("service_coverage", ["grid"], []))

	# City systems
	system_manager.register_system(traffic_system, SM.new("traffic", ["grid"], []))
	system_manager.register_system(pollution_system, SM.new("pollution", ["grid", "traffic"], ["weather"]))
	system_manager.register_system(land_value_system, SM.new("land_value", ["grid", "service_coverage", "pollution", "traffic"], ["terrain"]))
	system_manager.register_system(disaster_system, SM.new("disaster", ["grid", "service_coverage"], ["weather", "terrain"]))
	system_manager.register_system(zoning_system, SM.new("zoning", ["grid", "service_coverage"], ["land_value"]))

	# Architect systems
	system_manager.register_system(infrastructure_age_system, SM.new("infrastructure_age", ["grid"], []))
	system_manager.register_system(parking_system, SM.new("parking", ["grid"], ["traffic"]))
	system_manager.register_system(economic_cluster_system, SM.new("economic_cluster", ["grid"], []))
	system_manager.register_system(housing_system, SM.new("housing", ["grid"], []))
	system_manager.register_system(growth_boundary_system, SM.new("growth_boundary", ["grid"], []))
	system_manager.register_system(commute_system, SM.new("commute", ["grid", "traffic"], []))
	system_manager.register_system(environment_system, SM.new("environment", ["grid", "pollution"], []))
	system_manager.register_system(district_system, SM.new("district", ["grid"], []))

	# Initialize all systems in dependency order
	if not system_manager.initialize_all():
		push_error("GameWorld: Failed to initialize systems")


## Additional wiring that SystemManager doesn't handle automatically
func _setup_additional_wiring() -> void:
	# LEGACY: Grid overlay - replaced by HeatMapRenderer (Phase 4)
	# Keep configured but hidden for backward compatibility
	grid_overlay.set_systems(power_system, water_system, pollution_system, land_value_system, service_coverage, traffic_system, zoning_system)
	grid_overlay.visible = false  # Disabled in favor of HeatMapRenderer

	# Traffic visualizer needs systems
	traffic_visualizer.set_systems(traffic_system, grid_system)

	# Zone layer needs zoning system
	zone_layer.set_zoning_system(zoning_system)

	# Day/night system group
	day_night_system.add_to_group("day_night_system")

	# Zoning system special initialization
	zoning_system.initialize(grid_system, service_coverage, land_value_system)

	# Disaster system special initialization
	disaster_system.initialize(grid_system, service_coverage)

	# Land value terrain change listener
	if terrain_system:
		terrain_system.terrain_changed.connect(func(_cells): land_value_system.on_terrain_changed())


func _setup_cell_highlight() -> void:
	cell_highlight = CellHighlight.new()
	cell_highlight.name = "CellHighlight"
	cell_highlight.set_grid_system(grid_system)
	# Add after zone layer but before ghost preview
	add_child(cell_highlight)
	move_child(cell_highlight, zone_layer.get_index() + 1)


func _setup_utility_flow_overlay() -> void:
	utility_flow_overlay = UtilityFlowOverlay.new()
	utility_flow_overlay.name = "UtilityFlowOverlay"
	utility_flow_overlay.set_systems(power_system, water_system, grid_system)
	utility_flow_overlay.set_visible_overlay(false)  # Start hidden, toggle with key
	# Add after zone layer
	add_child(utility_flow_overlay)
	move_child(utility_flow_overlay, zone_layer.get_index() + 1)


func _setup_adaptive_grid() -> void:
	adaptive_grid = AdaptiveGridRenderer.new()
	adaptive_grid.name = "AdaptiveGrid"
	adaptive_grid.set_camera(camera)
	adaptive_grid.set_terrain_system(terrain_system)
	adaptive_grid.set_grid_system(grid_system)
	# Add early so it renders below other overlays
	add_child(adaptive_grid)
	move_child(adaptive_grid, terrain_background.get_index() + 1)

	# Hide legacy grid systems (kept for compatibility but disabled)
	if grid_lines:
		grid_lines.visible = false
	if fine_grid:
		fine_grid.visible = false


func _setup_phase3_overlays() -> void:
	# Drag selection overlay for zone painting and area operations
	drag_selection_overlay = DragSelectionOverlay.new()
	drag_selection_overlay.name = "DragSelectionOverlay"
	drag_selection_overlay.set_grid_system(grid_system)
	drag_selection_overlay.set_zoning_system(zoning_system)
	add_child(drag_selection_overlay)

	# Path preview overlay for roads/utilities drag-building
	path_preview_overlay = PathPreviewOverlay.new()
	path_preview_overlay.name = "PathPreviewOverlay"
	path_preview_overlay.set_grid_system(grid_system)
	path_preview_overlay.set_power_system(power_system)
	path_preview_overlay.set_water_system(water_system)
	add_child(path_preview_overlay)

	# Placement preview overlay for building footprints
	placement_preview_overlay = PlacementPreviewOverlay.new()
	placement_preview_overlay.name = "PlacementPreviewOverlay"
	placement_preview_overlay.set_grid_system(grid_system)
	placement_preview_overlay.set_terrain_system(terrain_system)
	placement_preview_overlay.set_power_system(power_system)
	placement_preview_overlay.set_water_system(water_system)
	placement_preview_overlay.set_zoning_system(zoning_system)
	add_child(placement_preview_overlay)


func _setup_phase4_overlays() -> void:
	# Heat map renderer - efficient replacement for old GridOverlay
	heat_map_renderer = HeatMapRenderer.new()
	heat_map_renderer.name = "HeatMapRenderer"
	heat_map_renderer.set_camera(camera)
	heat_map_renderer.set_systems(
		power_system, water_system, pollution_system,
		land_value_system, service_coverage, traffic_system,
		zoning_system, grid_system
	)
	add_child(heat_map_renderer)
	# Position after terrain but before buildings
	move_child(heat_map_renderer, terrain_background.get_index() + 2)

	# Grid coordinate labels
	grid_coordinate_labels = GridCoordinateLabels.new()
	grid_coordinate_labels.name = "GridCoordinateLabels"
	grid_coordinate_labels.set_camera(camera)
	add_child(grid_coordinate_labels)

	# Minimap overlay - added to CanvasLayer so it stays fixed on screen
	# Note: MinimapOverlay is a Control, needs to be added to UI layer
	_setup_minimap()


func _setup_minimap() -> void:
	# Create a CanvasLayer for UI elements that should stay fixed
	var ui_layer = CanvasLayer.new()
	ui_layer.name = "MinimapLayer"
	ui_layer.layer = 10  # Above game world
	add_child(ui_layer)

	minimap_overlay = MinimapOverlay.new()
	minimap_overlay.name = "MinimapOverlay"
	minimap_overlay.set_camera(camera)
	minimap_overlay.set_terrain_system(terrain_system)
	minimap_overlay.set_grid_system(grid_system)
	minimap_overlay.set_zoning_system(zoning_system)
	_sync_minimap_world_size()
	_bind_minimap_world_size_updates()
	ui_layer.add_child(minimap_overlay)


func _sync_minimap_world_size() -> void:
	if minimap_overlay and minimap_overlay.has_method("set_world_cell_size"):
		minimap_overlay.set_world_cell_size(_resolve_world_cell_size())


func _resolve_world_cell_size() -> Vector2i:
	var configured_grid_size = _get_configured_grid_cell_size()

	if terrain_system:
		if terrain_system.has_method("get_runtime_heightmap_size"):
			var runtime_size = int(terrain_system.get_runtime_heightmap_size())
			if runtime_size > 0 and runtime_size == configured_grid_size.x and runtime_size == configured_grid_size.y:
				return Vector2i(runtime_size, runtime_size)
		if terrain_system.has_method("get_grid_size"):
			var terrain_grid_size = terrain_system.get_grid_size()
			if terrain_grid_size is Vector2i and terrain_grid_size.x > 0 and terrain_grid_size.y > 0:
				return terrain_grid_size
	return configured_grid_size


func _get_configured_grid_cell_size() -> Vector2i:
	if grid_system:
		if grid_system.has_method("get_grid_size"):
			var grid_size = grid_system.get_grid_size()
			if grid_size is Vector2i and grid_size.x > 0 and grid_size.y > 0:
				return grid_size
		if grid_system.has_method("get_world_cell_size"):
			var world_cell_size = grid_system.get_world_cell_size()
			if world_cell_size is Vector2i and world_cell_size.x > 0 and world_cell_size.y > 0:
				return world_cell_size
	return Vector2i(GridConstants.GRID_WIDTH, GridConstants.GRID_HEIGHT)


func _bind_minimap_world_size_updates() -> void:
	if not terrain_system or not terrain_system.has_signal("runtime_heightmap_generated"):
		return
	if not terrain_system.runtime_heightmap_generated.is_connected(_on_minimap_runtime_heightmap_generated):
		terrain_system.runtime_heightmap_generated.connect(_on_minimap_runtime_heightmap_generated)


func _on_minimap_runtime_heightmap_generated(_heightmap: PackedFloat32Array, size: int, _sea_level: float) -> void:
	if size <= 0:
		return
	var configured_grid_size = _get_configured_grid_cell_size()
	if size != configured_grid_size.x or size != configured_grid_size.y:
		return
	if minimap_overlay and minimap_overlay.has_method("set_world_cell_size"):
		minimap_overlay.set_world_cell_size(Vector2i(size, size))


func _setup_phase5_overlays() -> void:
	# Action feedback effects - visual particles for placement, demolition, etc.
	action_feedback_effects = ActionFeedbackEffects.new()
	action_feedback_effects.name = "ActionFeedbackEffects"
	add_child(action_feedback_effects)

	# Measurement tool - distance and area calculation
	measurement_tool = MeasurementTool.new()
	measurement_tool.name = "MeasurementTool"
	measurement_tool.set_camera(camera)
	add_child(measurement_tool)

	# Cell info tooltip (disabled by default)
	if ENABLE_CELL_INFO_TOOLTIP:
		var tooltip_layer = CanvasLayer.new()
		tooltip_layer.name = "TooltipLayer"
		tooltip_layer.layer = 9  # Above world content, below minimap/hud canvas layers
		add_child(tooltip_layer)

		cell_info_tooltip = CellInfoTooltip.new()
		cell_info_tooltip.name = "CellInfoTooltip"
		cell_info_tooltip.set_camera(camera)
		cell_info_tooltip.set_systems(
			grid_system, terrain_system, power_system, water_system,
			pollution_system, land_value_system, service_coverage,
			zoning_system, traffic_system
		)
		tooltip_layer.add_child(cell_info_tooltip)


func _setup_world3d_bridge() -> void:
	if world3d_bridge == null:
		world3d_bridge = World3DBridgeScript.new()
		world3d_bridge.name = "World3DBridge"
		add_child(world3d_bridge)
	if world3d_bridge.has_method("initialize"):
		world3d_bridge.initialize(grid_system, camera, Events)
	if world3d_bridge.has_method("set_rendering_enabled"):
		world3d_bridge.set_rendering_enabled(true)


func _setup_terrain() -> void:
	# Setup terrain background (fallback if terrain system not ready)
	var world_size = Vector2(GridConstants.GRID_WIDTH, GridConstants.GRID_HEIGHT) * GridConstants.CELL_SIZE
	terrain_background.size = world_size
	terrain_background.color = Color(0.2, 0.35, 0.2)  # Dark grass green

	# Initialize terrain systems
	if terrain_system and terrain_renderer:
		terrain_renderer.set_terrain_system(terrain_system)
		terrain_renderer.set_grid_system(grid_system)
		terrain_renderer.set_camera(camera)
		if terrain_renderer.has_method("set_runtime_3d_enabled"):
			terrain_renderer.set_runtime_3d_enabled(TERRAIN_RUNTIME_PIPELINE_ENABLED)
		if terrain_renderer.has_method("configure_runtime_terrain_pipeline"):
			terrain_renderer.configure_runtime_terrain_pipeline(terrain_system)
		terrain_system.set_grid_system(grid_system)
		if terrain_system.has_method("configure_runtime_pipeline"):
			terrain_system.configure_runtime_pipeline(
				TERRAIN_RUNTIME_PIPELINE_ENABLED,
				null,
				TERRAIN_RUNTIME_EROSION_ITERATIONS
			)

		# Generate initial terrain with default seed
		terrain_system.generate_initial_terrain(randi())
		terrain_renderer.refresh()

		# Hide the old terrain background, use renderer instead
		terrain_background.visible = false

	# Legacy grid line setup - disabled in favor of AdaptiveGridRenderer
	# _draw_grid_lines() - now handled by AdaptiveGridRenderer


## LEGACY: Replaced by AdaptiveGridRenderer
## Kept for reference but no longer called
func _draw_grid_lines() -> void:
	# Create grid lines using Line2D nodes (sparse grid for performance)
	var grid_spacing = 10  # Draw a line every 10 cells
	var cell_size = GridConstants.CELL_SIZE
	var world_width = GridConstants.GRID_WIDTH * cell_size
	var world_height = GridConstants.GRID_HEIGHT * cell_size

	# Vertical lines
	for x in range(0, GridConstants.GRID_WIDTH + 1, grid_spacing):
		var line = Line2D.new()
		line.points = [Vector2(x * cell_size, 0), Vector2(x * cell_size, world_height)]
		line.width = 1
		line.default_color = Color(0.15, 0.3, 0.15, 0.5)
		grid_lines.add_child(line)

	# Horizontal lines
	for y in range(0, GridConstants.GRID_HEIGHT + 1, grid_spacing):
		var line = Line2D.new()
		line.points = [Vector2(0, y * cell_size), Vector2(world_width, y * cell_size)]
		line.width = 1
		line.default_color = Color(0.15, 0.3, 0.15, 0.5)
		grid_lines.add_child(line)


func _process(delta: float) -> void:
	_handle_camera_input(delta)
	_update_hovered_cell()
	_update_ghost_preview()
	# _update_fine_grid() - replaced by AdaptiveGridRenderer
	_update_cell_highlight()


func _handle_camera_input(delta: float) -> void:
	var direction = Vector2.ZERO

	if Input.is_action_pressed("camera_pan_up"):
		direction.y -= 1
	if Input.is_action_pressed("camera_pan_down"):
		direction.y += 1
	if Input.is_action_pressed("camera_pan_left"):
		direction.x -= 1
	if Input.is_action_pressed("camera_pan_right"):
		direction.x += 1

	if direction != Vector2.ZERO:
		camera.position += direction.normalized() * CAMERA_SPEED * delta / camera.zoom.x


func _input(event: InputEvent) -> void:
	# Zoom handling
	if event.is_action_pressed("camera_zoom_in"):
		var new_zoom = camera.zoom.x + ZOOM_SPEED
		camera.zoom = Vector2(min(new_zoom, MAX_ZOOM), min(new_zoom, MAX_ZOOM))
	elif event.is_action_pressed("camera_zoom_out"):
		var new_zoom = camera.zoom.x - ZOOM_SPEED
		camera.zoom = Vector2(max(new_zoom, MIN_ZOOM), max(new_zoom, MIN_ZOOM))

	# Cancel build mode / return to select tool
	if event.is_action_pressed("build_cancel"):
		if build_mode or demolish_mode:
			exit_build_mode()
		elif current_tool == ToolMode.PAN:
			set_tool(ToolMode.SELECT)

	# Tool shortcuts
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			# Overlay toggles (number keys) - Phase 4: use HeatMapRenderer
			KEY_1: _toggle_heat_map(HeatMapRenderer.OverlayMode.POWER)
			KEY_2: _toggle_heat_map(HeatMapRenderer.OverlayMode.WATER)
			KEY_3: _toggle_heat_map(HeatMapRenderer.OverlayMode.POLLUTION)
			KEY_4: _toggle_heat_map(HeatMapRenderer.OverlayMode.LAND_VALUE)
			KEY_5: _toggle_heat_map(HeatMapRenderer.OverlayMode.SERVICES)
			KEY_6: _toggle_heat_map(HeatMapRenderer.OverlayMode.TRAFFIC)
			KEY_7: _toggle_heat_map(HeatMapRenderer.OverlayMode.ZONES)
			KEY_8: _toggle_utility_flow_overlay()
			KEY_9: _toggle_heat_map(HeatMapRenderer.OverlayMode.DESIRABILITY)
			KEY_0: _toggle_heat_map(HeatMapRenderer.OverlayMode.NONE)
			KEY_M: _toggle_minimap()  # M for minimap
			KEY_R: _toggle_measurement_tool()  # R for ruler/measurement
			# Tool shortcuts
			KEY_SPACE: set_tool(ToolMode.PAN)  # Hold space for pan
			KEY_Q: set_tool(ToolMode.SELECT)   # Q for pointer/select
			KEY_X: enter_demolish_mode()       # X for demolish
			# N toggles day/night cycle
			KEY_N:
				if not event.shift_pressed:
					day_night_system.toggle()
					var state = "enabled" if day_night_system.enabled else "disabled"
					Events.simulation_event.emit("day_night_toggled", {"state": state})
			# Disaster shortcuts (Shift + D for menu, Shift + number to trigger)
			KEY_D:
				if event.shift_pressed:
					_show_disaster_menu()
		# Shift + number triggers disasters (only when shift is held)
		if event.shift_pressed:
			match event.keycode:
				KEY_1: trigger_disaster_debug(1)  # Fire
				KEY_2: trigger_disaster_debug(2)  # Earthquake
				KEY_3: trigger_disaster_debug(3)  # Tornado
				KEY_4: trigger_disaster_debug(4)  # Flood
				KEY_5: trigger_disaster_debug(5)  # Meteor
				KEY_6: trigger_disaster_debug(6)  # Monster

	# Space release returns to previous tool
	if event is InputEventKey and not event.pressed:
		if event.keycode == KEY_SPACE and current_tool == ToolMode.PAN:
			if build_mode:
				set_tool(ToolMode.BUILD)
			elif demolish_mode:
				set_tool(ToolMode.DEMOLISH)
			else:
				set_tool(ToolMode.SELECT)

	# Mouse handling for pan mode
	# Skip if mouse is over UI elements (like minimap)
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		if _is_mouse_over_ui():
			return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if current_tool == ToolMode.PAN:
					_start_pan(event.position)
				else:
					_handle_left_click()
					# Start drag building/demolishing
					if build_mode and current_building_data:
						is_drag_building = true
						last_drag_cell = hovered_cell
						# Start path preview for linear infrastructure (Phase 3)
						if _is_linear_infrastructure(current_building_data) and path_preview_overlay:
							path_preview_overlay.start_path(hovered_cell, current_building_data)
					elif demolish_mode:
						is_drag_demolishing = true
						last_drag_cell = hovered_cell
			else:
				if is_panning:
					_end_pan()
				if is_zone_painting:
					_end_zone_paint()
				# End drag building/demolishing
				if is_drag_building and _is_linear_infrastructure(current_building_data):
					_end_path_build()  # Phase 3: complete path placement
				is_drag_building = false
				is_drag_demolishing = false
				last_drag_cell = Vector2i(-1, -1)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_handle_right_click()
		# Middle mouse button always pans
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_start_pan(event.position)
			else:
				_end_pan()

	# Mouse motion for panning
	if event is InputEventMouseMotion and is_panning:
		_update_pan(event.position)

	# Mouse motion for drag building/demolishing/terrain
	if event is InputEventMouseMotion:
		if is_drag_building and build_mode and current_building_data:
			_handle_drag_build()
		elif is_drag_demolishing and demolish_mode:
			_handle_drag_demolish()
		elif current_tool == ToolMode.TERRAIN and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_apply_terrain_tool(hovered_cell)


func _update_hovered_cell() -> void:
	var mouse_pos = get_global_mouse_position()
	var new_cell = grid_system.world_to_grid(mouse_pos)

	if new_cell != hovered_cell:
		hovered_cell = new_cell
		Events.cell_hovered.emit(hovered_cell)

		# Update coverage visualization for service buildings
		if build_mode and current_building_data and current_building_data.coverage_radius > 0:
			coverage_visualizer.show_coverage(hovered_cell, current_building_data.coverage_radius, current_building_data.service_type)

		# Update measurement tool preview (Phase 5)
		if measurement_tool and measurement_tool.is_active():
			measurement_tool.set_preview_point(hovered_cell)


func _update_ghost_preview() -> void:
	# Zone painting preview - use drag_selection_overlay (Phase 3)
	if zone_mode:
		ghost_preview.visible = false  # Disable legacy preview
		if is_zone_painting:
			# Drag selection overlay handles the visualization
			if drag_selection_overlay:
				drag_selection_overlay.update_selection(hovered_cell)
		else:
			# Show single cell preview using placement_preview when not dragging
			# (drag_selection_overlay only activates on mouse down)
			pass
		return

	# Build mode preview - use placement_preview_overlay (Phase 3)
	if not build_mode or not current_building_data:
		ghost_preview.visible = false
		if placement_preview_overlay:
			placement_preview_overlay.hide_preview()
		if path_preview_overlay and path_preview_overlay.is_active():
			path_preview_overlay.update_path(hovered_cell)
		return

	# Check if this is a drag-building operation for linear infrastructure
	if is_drag_building and _is_linear_infrastructure(current_building_data):
		ghost_preview.visible = false
		if placement_preview_overlay:
			placement_preview_overlay.hide_preview()
		# Path preview handles linear drag-building
		if path_preview_overlay:
			path_preview_overlay.update_path(hovered_cell)
		return

	# Standard building preview - use PlacementPreviewOverlay
	ghost_preview.visible = false  # Disable legacy preview
	var can_afford = GameState.can_afford(current_building_data.build_cost)

	if placement_preview_overlay:
		placement_preview_overlay.update_position(hovered_cell, can_afford)


## Check if mouse is over UI elements that should block game input
func _is_mouse_over_ui() -> bool:
	var hovered_control: Control = get_viewport().gui_get_hovered_control()
	if hovered_control and hovered_control.is_visible_in_tree():
		return true

	# Check if minimap is being dragged
	if minimap_overlay and minimap_overlay._is_dragging:
		return true

	# Check if mouse is within minimap bounds
	if minimap_overlay and minimap_overlay.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		var minimap_rect = minimap_overlay.get_global_rect()
		if minimap_rect.has_point(mouse_pos):
			return true

	return false


## Check if building is linear infrastructure (roads, power lines, water pipes)
func _is_linear_infrastructure(building_data) -> bool:
	if not building_data:
		return false
	var btype = building_data.building_type if building_data.get("building_type") else ""
	return GridConstants.is_linear_infrastructure(btype)


## LEGACY: Replaced by AdaptiveGridRenderer
## Was extremely inefficient - created/destroyed Line2D nodes every frame
## Kept for reference but no longer called
func _update_fine_grid() -> void:
	if not fine_grid:
		return

	# Only show fine grid in build or demolish mode
	if not build_mode and not demolish_mode:
		fine_grid.visible = false
		return

	fine_grid.visible = true

	# Clear existing grid lines
	for child in fine_grid.get_children():
		child.queue_free()

	# Draw fine grid around cursor
	var start_x = max(0, hovered_cell.x - FINE_GRID_RADIUS)
	var end_x = min(GridConstants.GRID_WIDTH, hovered_cell.x + FINE_GRID_RADIUS + 1)
	var start_y = max(0, hovered_cell.y - FINE_GRID_RADIUS)
	var end_y = min(GridConstants.GRID_HEIGHT, hovered_cell.y + FINE_GRID_RADIUS + 1)

	var grid_color = Color(0.5, 0.5, 0.5, 0.3)

	# Vertical lines
	for x in range(start_x, end_x + 1):
		var line = Line2D.new()
		line.points = [
			Vector2(x * GridConstants.CELL_SIZE, start_y * GridConstants.CELL_SIZE),
			Vector2(x * GridConstants.CELL_SIZE, end_y * GridConstants.CELL_SIZE)
		]
		line.width = 1
		line.default_color = grid_color
		fine_grid.add_child(line)

	# Horizontal lines
	for y in range(start_y, end_y + 1):
		var line = Line2D.new()
		line.points = [
			Vector2(start_x * GridConstants.CELL_SIZE, y * GridConstants.CELL_SIZE),
			Vector2(end_x * GridConstants.CELL_SIZE, y * GridConstants.CELL_SIZE)
		]
		line.width = 1
		line.default_color = grid_color
		fine_grid.add_child(line)


func _update_cell_highlight() -> void:
	if not cell_highlight:
		return

	# Hide highlight when modal dialogs are open or pointer is over UI
	if UIManager.is_modal_open() or _is_mouse_over_ui():
		cell_highlight.visible = false
		return

	if not _should_show_cell_highlight():
		cell_highlight.visible = false
		return

	cell_highlight.visible = true
	var target_cell := _get_active_highlight_cell()
	cell_highlight.set_cell(target_cell)

	# Determine highlight state based on context
	var can_place = false
	var has_building = grid_system.get_building_at(target_cell) != null

	if build_mode and current_building_data:
		var check = grid_system.can_place_building(target_cell, current_building_data)
		can_place = check.can_place and GameState.can_afford(current_building_data.build_cost)
		cell_highlight.set_building_size(current_building_data.size)
	else:
		cell_highlight.reset_building_size()

	var state = CellHighlight.get_state_for_context(
		current_tool,
		build_mode,
		demolish_mode,
		zone_mode,
		can_place,
		has_building
	)
	cell_highlight.set_state(state)


func _should_show_cell_highlight() -> bool:
	return build_mode or demolish_mode or zone_mode or current_tool == ToolMode.TERRAIN or _cell_inspector_active


func _get_active_highlight_cell() -> Vector2i:
	if _cell_inspector_active and not build_mode and not demolish_mode and not zone_mode:
		return _cell_inspector_cell
	return hovered_cell


func _handle_left_click() -> void:
	_clear_cell_inspector()

	if build_mode and current_building_data:
		_try_place_building()
	elif demolish_mode:
		_try_demolish()
	elif zone_mode:
		_start_zone_paint()
	elif current_tool == ToolMode.TERRAIN:
		_apply_terrain_tool(hovered_cell)
	else:
		_try_select_building()


func _start_zone_paint() -> void:
	zone_paint_start = hovered_cell
	is_zone_painting = true

	# Start drag selection overlay (Phase 3)
	if drag_selection_overlay:
		var zone_color = zoning_system.get_zone_color(current_zone_type)
		drag_selection_overlay.set_zone_type(current_zone_type)
		drag_selection_overlay.start_selection(hovered_cell, "zone", zone_color)


func _end_zone_paint() -> void:
	if is_zone_painting and zone_paint_start != Vector2i(-1, -1):
		var count = zoning_system.paint_zone(zone_paint_start, hovered_cell, current_zone_type)
		if count > 0:
			Events.simulation_event.emit("zone_painted", {"count": count})

			# Phase 5: Spawn zone paint visual effect
			if action_feedback_effects:
				var min_x = mini(zone_paint_start.x, hovered_cell.x)
				var max_x = maxi(zone_paint_start.x, hovered_cell.x)
				var min_y = mini(zone_paint_start.y, hovered_cell.y)
				var max_y = maxi(zone_paint_start.y, hovered_cell.y)
				var zone_rect = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
				var zone_color = zoning_system.get_zone_color(current_zone_type)
				action_feedback_effects.spawn_zone_effect(zone_rect, zone_color)

	# End drag selection overlay (Phase 3)
	if drag_selection_overlay:
		drag_selection_overlay.end_selection()

	is_zone_painting = false
	zone_paint_start = Vector2i(-1, -1)


func _handle_right_click() -> void:
	if build_mode or demolish_mode:
		exit_build_mode()
	else:
		_deselect_building()
		_toggle_cell_inspector(hovered_cell)


func _toggle_cell_inspector(cell: Vector2i) -> void:
	if not ENABLE_CELL_INFO_TOOLTIP:
		_clear_cell_inspector()
		return

	if not grid_system or not grid_system.is_valid_cell(cell):
		_clear_cell_inspector()
		return

	if _cell_inspector_active and _cell_inspector_cell == cell:
		_clear_cell_inspector()
		return

	_cell_inspector_active = true
	_cell_inspector_cell = cell
	if cell_info_tooltip and cell_info_tooltip.has_method("show_cell"):
		cell_info_tooltip.show_cell(cell)


func _clear_cell_inspector() -> void:
	_cell_inspector_active = false
	_cell_inspector_cell = Vector2i(-1, -1)
	if cell_info_tooltip:
		cell_info_tooltip.hide_tooltip()


func _try_place_building() -> void:
	if not current_building_data:
		return

	# Check data center requirements
	if current_building_data.category == "data_center":
		if not _check_data_center_requirements(hovered_cell, current_building_data):
			if cell_highlight:
				cell_highlight.pulse_feedback(false)
			# Phase 5: Show placement fail effect
			if action_feedback_effects:
				action_feedback_effects.spawn_effect(
					ActionFeedbackEffects.EffectType.PLACEMENT_FAIL,
					hovered_cell,
					{"size": current_building_data.size}
				)
			return

	var building = grid_system.place_building(hovered_cell, current_building_data)
	if building:
		# Visual feedback for successful placement
		if cell_highlight:
			cell_highlight.pulse_feedback(true)
		# Note: Phase 5 ActionFeedbackEffects already listens to building_placed signal

		# Track data center placement
		if current_building_data.category == "data_center":
			GameState.add_data_center(current_building_data.data_center_tier)
			GameState.score += current_building_data.score_value
			Events.data_center_placed.emit(current_building_data.data_center_tier, hovered_cell)
			Events.simulation_event.emit("data_center_placed_success", {
				"score": current_building_data.score_value
			})
	else:
		# Visual feedback for failed placement
		if cell_highlight:
			cell_highlight.pulse_feedback(false)
		# Phase 5: Show placement fail effect
		if action_feedback_effects:
			action_feedback_effects.spawn_effect(
				ActionFeedbackEffects.EffectType.PLACEMENT_FAIL,
				hovered_cell,
				{"size": current_building_data.size}
			)


func _check_data_center_requirements(cell: Vector2i, data) -> bool:
	var tier = data.data_center_tier
	var messages: Array[String] = []

	# Check power
	var power_needed = 0.0
	match tier:
		1: power_needed = 5.0
		2: power_needed = 25.0
		3: power_needed = 100.0

	if GameState.get_available_power() < power_needed:
		messages.append("Need %d MW available power" % int(power_needed))

	# Check water
	var water_needed = 0.0
	match tier:
		1: water_needed = 100.0
		2: water_needed = 500.0
		3: water_needed = 2000.0

	if GameState.get_available_water() < water_needed:
		messages.append("Need %d ML available water" % int(water_needed))

	# Check population
	var pop_needed = 0
	match tier:
		1: pop_needed = 10
		2: pop_needed = 100
		3: pop_needed = 500

	if GameState.population < pop_needed:
		messages.append("Need %d population" % pop_needed)

	# Check education (tier 2+)
	if tier >= 2:
		var edu_needed = 0.2 if tier == 2 else 0.4
		if GameState.education_rate < edu_needed:
			messages.append("Need %d%% educated" % int(edu_needed * 100))

	# Check fire coverage
	if not service_coverage.has_fire_coverage(cell):
		messages.append("Need fire station coverage")

	# Check police coverage (tier 2+)
	if tier >= 2 and not service_coverage.has_police_coverage(cell):
		messages.append("Need police station coverage")

	if messages.size() > 0:
		for msg in messages:
			Events.simulation_event.emit("data_center_requirement_failed", {"requirement": msg})
		return false

	return true


func _try_demolish() -> void:
	var building = grid_system.get_building_at(hovered_cell)
	if building:
		var building_data = building.building_data
		var building_name = building_data.display_name if building_data else "Building"
		var refund = int(building_data.build_cost * 0.5) if building_data else 0

		# Track data center removal
		if building_data and building_data.category == "data_center":
			GameState.remove_data_center(building_data.data_center_tier)

		grid_system.remove_building(hovered_cell)
		Events.simulation_event.emit("building_demolished", {"name": building_name, "refund": refund})

		# Visual feedback for successful demolition
		if cell_highlight:
			cell_highlight.pulse_feedback(true)


func _handle_drag_build() -> void:
	# Only place if we moved to a new cell
	if hovered_cell == last_drag_cell:
		return

	# Only allow drag placement for 1x1 buildings (roads, power lines, water pipes)
	if current_building_data.size != Vector2i(1, 1):
		return

	# For linear infrastructure with path preview, don't place individually
	# (placement happens on mouse release via _end_path_build)
	if _is_linear_infrastructure(current_building_data) and path_preview_overlay and path_preview_overlay.is_active():
		# Path preview updates in _update_ghost_preview
		return

	# Standard drag placement (cell by cell)
	var check = grid_system.can_place_building(hovered_cell, current_building_data)
	if check.can_place and GameState.can_afford(current_building_data.build_cost):
		var building = grid_system.place_building(hovered_cell, current_building_data)
		if building:
			last_drag_cell = hovered_cell


## End path building and place all valid cells along the path (Phase 3)
func _end_path_build() -> void:
	if not path_preview_overlay or not path_preview_overlay.is_active():
		return

	var valid_cells = path_preview_overlay.get_valid_path_cells()
	var placed_count = 0
	var placed_cells: Array[Vector2i] = []

	for cell in valid_cells:
		if GameState.can_afford(current_building_data.build_cost):
			var check = grid_system.can_place_building(cell, current_building_data)
			if check.can_place:
				var building = grid_system.place_building(cell, current_building_data)
				if building:
					placed_count += 1
					placed_cells.append(cell)

	# End path preview
	path_preview_overlay.end_path()

	# Feedback
	if placed_count > 0:
		Events.simulation_event.emit("path_built", {
			"count": placed_count,
			"type": current_building_data.building_type
		})
		if cell_highlight:
			cell_highlight.pulse_feedback(true)
		# Phase 5: Spawn path completion effect
		if action_feedback_effects and placed_cells.size() > 0:
			action_feedback_effects.spawn_path_effect(placed_cells)
	elif valid_cells.size() > 0:
		# Had valid cells but couldn't afford them all
		if cell_highlight:
			cell_highlight.pulse_feedback(false)


func _handle_drag_demolish() -> void:
	# Only demolish if we moved to a new cell
	if hovered_cell == last_drag_cell:
		return

	var building = grid_system.get_building_at(hovered_cell)
	if building:
		var building_data = building.building_data

		# Track data center removal
		if building_data and building_data.category == "data_center":
			GameState.remove_data_center(building_data.data_center_tier)

		grid_system.remove_building(hovered_cell)
		last_drag_cell = hovered_cell


func _apply_terrain_tool(cell: Vector2i) -> void:
	if not terrain_system or not grid_system.is_valid_cell(cell):
		return

	match current_terrain_tool:
		"raise":
			terrain_system.raise_elevation(cell)
		"lower":
			terrain_system.lower_elevation(cell)
		"flatten":
			terrain_system.flatten(cell)
		"water":
			terrain_system.toggle_water(cell)
		"tree":
			terrain_system.toggle_feature(cell, TerrainSystem.FeatureType.TREE_SPARSE)
		"rock":
			terrain_system.toggle_feature(cell, TerrainSystem.FeatureType.ROCK_SMALL)


func set_terrain_tool(tool_id: String) -> void:
	current_terrain_tool = tool_id
	set_tool(ToolMode.TERRAIN)
	Events.terrain_tool_selected.emit(tool_id)


func _try_select_building() -> void:
	_deselect_building()

	var building = grid_system.get_building_at(hovered_cell)
	if building and building.has_method("set_selected"):
		selected_building = building
		selected_building.set_selected(true)
		Events.building_selected.emit(building)

		# Show coverage for service buildings when selected
		if building.building_data and building.building_data.coverage_radius > 0:
			coverage_visualizer.show_coverage(
				building.grid_cell,
				building.building_data.coverage_radius,
				building.building_data.service_type
			)
	else:
		# Show cell info instead
		var coverage = service_coverage.get_coverage_at_cell(hovered_cell)
		Events.info_panel_requested.emit({
			"type": "cell",
			"cell": hovered_cell,
			"coverage": coverage
		})


func _deselect_building() -> void:
	if selected_building:
		selected_building.set_selected(false)
		selected_building = null
		Events.building_deselected.emit()
	coverage_visualizer.clear_coverage()


func enter_build_mode(building_id: String) -> void:
	_clear_cell_inspector()
	current_building_id = building_id
	current_building_data = grid_system.get_building_data(building_id)
	build_mode = true
	demolish_mode = false
	set_tool(ToolMode.BUILD)

	# Show placement preview (Phase 3)
	if placement_preview_overlay and current_building_data:
		var can_afford = GameState.can_afford(current_building_data.build_cost)
		placement_preview_overlay.show_preview(hovered_cell, current_building_data, can_afford)

	# Hide tooltip while in build mode (Phase 5)
	if cell_info_tooltip:
		cell_info_tooltip.hide_tooltip()

	Events.build_mode_entered.emit(building_id)


func enter_demolish_mode() -> void:
	_clear_cell_inspector()
	demolish_mode = true
	build_mode = false
	current_building_id = ""
	current_building_data = null
	ghost_preview.visible = false
	coverage_visualizer.clear_coverage()
	set_tool(ToolMode.DEMOLISH)

	# Hide tooltip while in demolish mode (Phase 5)
	if cell_info_tooltip:
		cell_info_tooltip.hide_tooltip()

	Events.demolish_mode_entered.emit()


func exit_build_mode() -> void:
	_clear_cell_inspector()
	build_mode = false
	demolish_mode = false
	zone_mode = false
	current_building_id = ""
	current_building_data = null
	current_zone_type = 0
	is_zone_painting = false
	is_drag_building = false
	is_drag_demolishing = false
	last_drag_cell = Vector2i(-1, -1)
	ghost_preview.visible = false
	coverage_visualizer.clear_coverage()

	# Hide Phase 3 overlays
	if placement_preview_overlay:
		placement_preview_overlay.hide_preview()
	if path_preview_overlay:
		path_preview_overlay.cancel_path()
	if drag_selection_overlay:
		drag_selection_overlay.cancel_selection()

	set_tool(ToolMode.SELECT)
	Events.build_mode_exited.emit()
	Events.demolish_mode_exited.emit()


func enter_zone_mode(zone_type: int) -> void:
	_clear_cell_inspector()
	zone_mode = true
	build_mode = false
	demolish_mode = false
	current_zone_type = zone_type
	current_building_id = ""
	current_building_data = null
	set_tool(ToolMode.ZONE)
	Events.simulation_event.emit("zone_mode_entered", {})


func _on_build_mode_entered(_building_id: String) -> void:
	pass


func _on_build_mode_exited() -> void:
	coverage_visualizer.clear_coverage()


func _on_demolish_mode_entered() -> void:
	pass


func _on_demolish_mode_exited() -> void:
	pass


# Tool management
func set_tool(tool: ToolMode) -> void:
	current_tool = tool
	is_panning = false

	# Update cursor based on tool
	match tool:
		ToolMode.SELECT:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		ToolMode.PAN:
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		ToolMode.BUILD:
			Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		ToolMode.DEMOLISH:
			Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		ToolMode.ZONE:
			Input.set_default_cursor_shape(Input.CURSOR_CROSS)
		ToolMode.TERRAIN:
			Input.set_default_cursor_shape(Input.CURSOR_CROSS)

	Events.tool_changed.emit(tool)

	# Sync with UIManager
	UIManager.set_tool(UIManager.from_game_tool(tool))


# Handle tool changes from UIManager (e.g., from ToolPalette)
func _on_ui_manager_tool_changed(ui_tool: int) -> void:
	var game_tool = UIManager.to_game_tool(ui_tool)
	if game_tool != current_tool:
		# Update internal state without re-emitting to UIManager
		current_tool = game_tool as ToolMode
		is_panning = false

		# Update cursor
		match current_tool:
			ToolMode.SELECT:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
			ToolMode.PAN:
				Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			ToolMode.BUILD:
				Input.set_default_cursor_shape(Input.CURSOR_CROSS)
			ToolMode.DEMOLISH:
				Input.set_default_cursor_shape(Input.CURSOR_CROSS)
			ToolMode.ZONE:
				Input.set_default_cursor_shape(Input.CURSOR_CROSS)
			ToolMode.TERRAIN:
				Input.set_default_cursor_shape(Input.CURSOR_CROSS)


func get_tool() -> ToolMode:
	return current_tool


func get_tool_name() -> String:
	match current_tool:
		ToolMode.SELECT: return "Select"
		ToolMode.PAN: return "Pan"
		ToolMode.BUILD: return "Build"
		ToolMode.DEMOLISH: return "Demolish"
		ToolMode.ZONE: return "Zone"
		ToolMode.TERRAIN: return "Terrain"
	return "Unknown"


# Pan/grabber functions
func _start_pan(mouse_pos: Vector2) -> void:
	is_panning = true
	pan_start_mouse = mouse_pos
	pan_start_camera = camera.position
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)


func _update_pan(mouse_pos: Vector2) -> void:
	if not is_panning:
		return
	var delta = (pan_start_mouse - mouse_pos) / camera.zoom.x
	camera.position = pan_start_camera + delta


func _end_pan() -> void:
	is_panning = false
	# Restore cursor based on current tool
	set_tool(current_tool)


# Disaster functions
func _on_year_tick() -> void:
	# Small chance of random disaster each year (increases with city size)
	var disaster_chance = 0.05 + (GameState.population / 100000.0) * 0.1  # 5-15% based on pop
	if randf() < disaster_chance:
		disaster_system.trigger_random_disaster()


func _show_disaster_menu() -> void:
	# Debug function to trigger disasters - show notification with options
	Events.simulation_event.emit("disaster_debug_hint", {})


func trigger_disaster_debug(type: int) -> void:
	match type:
		1: disaster_system.trigger_disaster(DisasterSystem.DisasterType.FIRE)
		2: disaster_system.trigger_disaster(DisasterSystem.DisasterType.EARTHQUAKE)
		3: disaster_system.trigger_disaster(DisasterSystem.DisasterType.TORNADO)
		4: disaster_system.trigger_disaster(DisasterSystem.DisasterType.FLOOD)
		5: disaster_system.trigger_disaster(DisasterSystem.DisasterType.METEOR)
		6: disaster_system.trigger_disaster(DisasterSystem.DisasterType.MONSTER)


# Utility flow overlay toggle (KEY_8)
func _toggle_utility_flow_overlay() -> void:
	if not utility_flow_overlay:
		return

	_utility_flow_visible = not _utility_flow_visible
	utility_flow_overlay.set_visible_overlay(_utility_flow_visible)

	var state = "enabled" if _utility_flow_visible else "disabled"
	Events.simulation_event.emit("utility_flow_overlay_toggled", {"state": state})


# Heat map overlay toggle (Phase 4)
func _toggle_heat_map(mode: int) -> void:
	if not heat_map_renderer:
		return

	# If NONE, hide the overlay
	if mode == HeatMapRenderer.OverlayMode.NONE:
		heat_map_renderer.set_overlay_mode(HeatMapRenderer.OverlayMode.NONE)
		heat_map_renderer.visible = false
	else:
		heat_map_renderer.set_overlay_mode(mode as HeatMapRenderer.OverlayMode)


# Minimap toggle (KEY_M)
func _toggle_minimap() -> void:
	if not minimap_overlay:
		return

	minimap_overlay.visible = not minimap_overlay.visible
	var state = "enabled" if minimap_overlay.visible else "disabled"
	Events.simulation_event.emit("minimap_toggled", {"state": state})


# Measurement tool toggle (KEY_R)
func _toggle_measurement_tool() -> void:
	if not measurement_tool:
		return

	if measurement_tool.is_active():
		measurement_tool.deactivate()
	else:
		# Exit other modes when entering measurement
		if build_mode or demolish_mode:
			exit_build_mode()
		# Hide tooltip while measuring
		if cell_info_tooltip:
			cell_info_tooltip.hide_tooltip()
		measurement_tool.activate(MeasurementTool.MeasureMode.DISTANCE)


# === Query Handlers for Decoupled UI ===
# These aggregate data from multiple systems and emit responses

func _on_cell_info_requested(cell: Vector2i) -> void:
	var info: Dictionary = {
		"cell": cell,
		"coverage": service_coverage.get_coverage_at_cell(cell),
		"has_power": power_system.is_cell_powered(cell),
		"has_water": water_system.is_cell_watered(cell),
		"pollution": pollution_system.get_pollution_at(cell),
		"land_value": land_value_system.get_land_value_at(cell),
		"congestion": traffic_system.get_congestion_at(cell),
	}
	Events.cell_info_ready.emit(cell, info)


func _on_building_info_requested(building: Node2D) -> void:
	if not building or not building.has_method("get_info"):
		return

	var base_info = building.get_info()
	var cell = base_info.get("cell", Vector2i.ZERO)

	# Augment with environmental data from systems
	var info: Dictionary = base_info.duplicate()
	info["pollution"] = pollution_system.get_pollution_at(cell)
	info["land_value"] = land_value_system.get_land_value_at(cell)
	info["congestion"] = traffic_system.get_congestion_at(cell)

	Events.building_info_ready.emit(building, info)


func _on_building_catalog_requested() -> void:
	# Build catalog organized by category
	var catalog: Dictionary = {}

	# Get all building data from grid system's registry
	var all_buildings = grid_system.get_all_building_data()
	for building_id in all_buildings:
		var building_data = all_buildings[building_id]
		var category = building_data.category

		if not catalog.has(category):
			catalog[category] = []

		# Convert BuildingData to dictionary for event transport
		catalog[category].append({
			"id": building_data.id,
			"display_name": building_data.display_name,
			"build_cost": building_data.build_cost,
			"category": category
		})

	Events.building_catalog_ready.emit(catalog)


func _on_expense_breakdown_requested() -> void:
	# Aggregate maintenance costs by category
	var by_category: Dictionary = {}
	var counted: Dictionary = {}

	for cell in grid_system.buildings:
		var building = grid_system.buildings[cell]
		if not is_instance_valid(building) or counted.has(building):
			continue
		counted[building] = true

		if building.building_data:
			var cat = building.building_data.category
			var maint = building.building_data.monthly_maintenance
			if not by_category.has(cat):
				by_category[cat] = {"count": 0, "total": 0}
			by_category[cat].count += 1
			by_category[cat].total += maint

	Events.expense_breakdown_ready.emit(by_category)


# === Command Handlers for Decoupled Actions ===
# These execute user actions requested via command signals
# Enables replay/undo by recording commands

func _on_build_requested(building_id: String, cell: Vector2i) -> void:
	var building_data = grid_system.get_building_data(building_id)
	if not building_data:
		Events.simulation_event.emit("generic_error", {"message": "Unknown building type"})
		return

	# Validate placement
	var check = grid_system.can_place_building(cell, building_data)
	if not check.can_place:
		Events.simulation_event.emit("generic_error", {"message": check.reason})
		return

	# Check affordability
	if not GameState.can_afford(building_data.build_cost):
		Events.simulation_event.emit("insufficient_funds", {"cost": building_data.build_cost})
		return

	# Check data center requirements
	if building_data.category == "data_center":
		if not _check_data_center_requirements(cell, building_data):
			return

	# Execute placement
	var building = grid_system.place_building(cell, building_data)
	if building:
		# Track data center placement
		if building_data.category == "data_center":
			GameState.add_data_center(building_data.data_center_tier)
			GameState.score += building_data.score_value
			Events.data_center_placed.emit(building_data.data_center_tier, cell)
			Events.simulation_event.emit("data_center_placed_success", {
				"score": building_data.score_value
			})


func _on_demolish_requested(cell: Vector2i) -> void:
	var building = grid_system.get_building_at(cell)
	if not building:
		return

	var building_data = building.building_data
	var building_name = building_data.display_name if building_data else "Building"
	var refund = int(building_data.build_cost * 0.5) if building_data else 0

	# Track data center removal
	if building_data and building_data.category == "data_center":
		GameState.remove_data_center(building_data.data_center_tier)

	grid_system.remove_building(cell)
	Events.simulation_event.emit("building_demolished", {"name": building_name, "refund": refund})


func _on_zone_requested(zone_type: int, cells: Array) -> void:
	if cells.size() < 2:
		return

	var start_cell = cells[0] as Vector2i
	var end_cell = cells[1] as Vector2i

	var count = zoning_system.paint_zone(start_cell, end_cell, zone_type)
	if count > 0:
		Events.simulation_event.emit("zone_painted", {"count": count})
