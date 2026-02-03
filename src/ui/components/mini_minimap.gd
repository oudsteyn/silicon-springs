extends CanvasLayer
class_name MiniMinimap
## Compact 120px minimap with hover expansion
## Always visible, subtle opacity, expands on hover

const MINIMAP_SIZE: int = 120
const EXPANDED_SIZE: int = 180
const GRID_SIZE: int = GridConstants.GRID_WIDTH
const DEFAULT_OPACITY: float = 0.7
const HOVER_OPACITY: float = 1.0
const TRANSITION_DURATION: float = 0.2  # Matches ThemeConstants.ANIM_PANEL_SLIDE

var minimap_container: PanelContainer
var minimap_texture: TextureRect
var viewport_rect: ColorRect
var image: Image
var texture: ImageTexture

var is_dragging: bool = false
var is_hovered: bool = false
var _current_size: int = MINIMAP_SIZE
var _transition_tween: Tween = null

# Cached references for performance
var _game_world: Node = null
var _last_camera_pos: Vector2 = Vector2.ZERO
var _last_camera_zoom: float = 0.0

# Color mapping for building types
const TYPE_COLORS = {
	"road": Color(0.4, 0.4, 0.4),
	"collector": Color(0.5, 0.5, 0.5),
	"arterial": Color(0.6, 0.6, 0.6),
	"highway": Color(0.7, 0.7, 0.7),
	"residential": Color(0.3, 0.7, 0.3),
	"commercial": Color(0.3, 0.5, 0.9),
	"industrial": Color(0.8, 0.6, 0.2),
	"heavy_industrial": Color(0.6, 0.4, 0.1),
	"power": Color(1.0, 0.9, 0.2),
	"water": Color(0.3, 0.7, 1.0),
	"service": Color(0.9, 0.3, 0.3),
	"data_center": Color(0.5, 1.0, 0.8),
	"park": Color(0.2, 0.6, 0.2),
	"default": Color(0.5, 0.5, 0.5)
}


func _ready() -> void:
	layer = 85
	_setup_ui()
	_connect_events()
	call_deferred("_update_minimap")


func _exit_tree() -> void:
	# Clean up transition tween
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()
		_transition_tween = null


func _setup_ui() -> void:
	# Create main container - bottom right corner
	minimap_container = PanelContainer.new()
	minimap_container.anchor_left = 1.0
	minimap_container.anchor_right = 1.0
	minimap_container.anchor_top = 1.0
	minimap_container.anchor_bottom = 1.0
	_update_container_position(MINIMAP_SIZE)

	# Style the panel using centralized theme
	var stylebox = UIManager.get_panel_style(ThemeConstants.RADIUS_LARGE)
	stylebox.set_content_margin_all(ThemeConstants.MARGIN_SMALL)
	stylebox.shadow_color = Color(0, 0, 0, 0.3)
	stylebox.shadow_size = ThemeConstants.SHADOW_SIZE_SMALL
	stylebox.shadow_offset = Vector2(-2, -2)
	minimap_container.add_theme_stylebox_override("panel", stylebox)

	# Set default opacity
	minimap_container.modulate.a = DEFAULT_OPACITY

	add_child(minimap_container)

	# Create minimap texture directly (no header)
	minimap_texture = TextureRect.new()
	minimap_texture.custom_minimum_size = Vector2(MINIMAP_SIZE, MINIMAP_SIZE)
	minimap_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	minimap_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap_container.add_child(minimap_texture)

	# Create viewport indicator
	viewport_rect = ColorRect.new()
	viewport_rect.color = Color(1, 1, 1, 0.3)
	viewport_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap_texture.add_child(viewport_rect)

	# Initialize image
	image = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.15, 0.25, 0.15))  # Dark grass
	texture = ImageTexture.create_from_image(image)
	minimap_texture.texture = texture

	# Make minimap interactive
	minimap_texture.gui_input.connect(_on_minimap_input)
	minimap_container.mouse_entered.connect(_on_mouse_entered)
	minimap_container.mouse_exited.connect(_on_mouse_exited)


func _update_container_position(size: int) -> void:
	minimap_container.offset_left = -(size + 18)
	minimap_container.offset_right = -10
	minimap_container.offset_top = -(size + 18)
	minimap_container.offset_bottom = -10


func _connect_events() -> void:
	Events.building_placed.connect(_on_building_changed)
	Events.building_removed.connect(_on_building_changed)
	Events.month_tick.connect(_update_minimap)


func _process(_delta: float) -> void:
	# Cache game_world reference
	if not _game_world or not is_instance_valid(_game_world):
		_game_world = get_tree().get_first_node_in_group("game_world")
		if not _game_world:
			return

	# Only update if camera has moved
	if _game_world.camera:
		var cam_pos = _game_world.camera.position
		var cam_zoom = _game_world.camera.zoom.x
		if cam_pos != _last_camera_pos or cam_zoom != _last_camera_zoom:
			_last_camera_pos = cam_pos
			_last_camera_zoom = cam_zoom
			_update_viewport_rect()


func _on_mouse_entered() -> void:
	is_hovered = true
	_animate_to_expanded()


func _on_mouse_exited() -> void:
	is_hovered = false
	if not is_dragging:
		_animate_to_compact()


func _animate_to_expanded() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.set_trans(Tween.TRANS_CUBIC)

	# Expand size
	_transition_tween.tween_property(minimap_texture, "custom_minimum_size",
		Vector2(EXPANDED_SIZE, EXPANDED_SIZE), TRANSITION_DURATION)

	# Increase opacity
	_transition_tween.tween_property(minimap_container, "modulate:a",
		HOVER_OPACITY, TRANSITION_DURATION)

	# Update position
	_transition_tween.tween_method(_update_container_position, _current_size, EXPANDED_SIZE, TRANSITION_DURATION)

	_current_size = EXPANDED_SIZE


func _animate_to_compact() -> void:
	if _transition_tween and _transition_tween.is_valid():
		_transition_tween.kill()

	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.set_trans(Tween.TRANS_CUBIC)

	# Shrink size
	_transition_tween.tween_property(minimap_texture, "custom_minimum_size",
		Vector2(MINIMAP_SIZE, MINIMAP_SIZE), TRANSITION_DURATION)

	# Decrease opacity
	_transition_tween.tween_property(minimap_container, "modulate:a",
		DEFAULT_OPACITY, TRANSITION_DURATION)

	# Update position
	_transition_tween.tween_method(_update_container_position, _current_size, MINIMAP_SIZE, TRANSITION_DURATION)

	_current_size = MINIMAP_SIZE


func _update_minimap() -> void:
	# Use cached reference or fetch it
	if not _game_world or not is_instance_valid(_game_world):
		_game_world = get_tree().get_first_node_in_group("game_world")
	if not _game_world or not _game_world.grid_system:
		return

	var grid_system = _game_world.grid_system

	# Clear to base color
	image.fill(Color(0.15, 0.25, 0.15))

	# Draw buildings
	var drawn = {}
	for cell in grid_system.buildings:
		var building = grid_system.buildings[cell]
		if not is_instance_valid(building) or drawn.has(building):
			continue
		drawn[building] = true

		if not building.building_data:
			continue

		var color = _get_building_color(building.building_data)
		var bsize = building.building_data.size

		# Draw building footprint
		for x in range(bsize.x):
			for y in range(bsize.y):
				var px = cell.x + x
				var py = cell.y + y
				if px >= 0 and px < GRID_SIZE and py >= 0 and py < GRID_SIZE:
					image.set_pixel(px, py, color)

	# Update texture
	texture.update(image)


func _get_building_color(data) -> Color:
	# Check category first
	if data.category == "data_center":
		return TYPE_COLORS["data_center"]

	# Check building type
	var btype = data.building_type
	if TYPE_COLORS.has(btype):
		return TYPE_COLORS[btype]

	# Check specific types
	if btype in ["coal_plant", "solar_farm", "power_line"]:
		return TYPE_COLORS["power"]
	if btype in ["water_tower", "treatment_plant", "water_pipe"]:
		return TYPE_COLORS["water"]
	if btype in ["police_station", "fire_station", "hospital", "school"]:
		return TYPE_COLORS["service"]

	return TYPE_COLORS["default"]


func _on_building_changed(_cell: Vector2i, _building: Node2D) -> void:
	_update_minimap()


func _update_viewport_rect() -> void:
	# Use cached reference
	if not _game_world or not is_instance_valid(_game_world) or not _game_world.camera:
		return

	var camera = _game_world.camera
	var viewport_size = get_viewport().get_visible_rect().size

	# Calculate view bounds in grid coordinates
	var cam_pos = camera.position
	var zoom = camera.zoom.x
	var view_width = viewport_size.x / zoom / GridConstants.CELL_SIZE
	var view_height = viewport_size.y / zoom / GridConstants.CELL_SIZE

	var grid_x = cam_pos.x / GridConstants.CELL_SIZE - view_width / 2
	var grid_y = cam_pos.y / GridConstants.CELL_SIZE - view_height / 2

	# Convert to minimap coordinates (scale based on current displayed size)
	var display_size = minimap_texture.custom_minimum_size.x
	var map_scale = display_size / float(GRID_SIZE)
	viewport_rect.position = Vector2(grid_x, grid_y) * map_scale
	viewport_rect.size = Vector2(view_width, view_height) * map_scale


func _on_minimap_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				_navigate_to_position(event.position)
			else:
				is_dragging = false
				if not is_hovered:
					_animate_to_compact()
	elif event is InputEventMouseMotion and is_dragging:
		_navigate_to_position(event.position)


func _navigate_to_position(local_pos: Vector2) -> void:
	# Use cached reference
	if not _game_world or not is_instance_valid(_game_world) or not _game_world.camera:
		return

	# Convert minimap position to world position (scale based on displayed size)
	var display_size = minimap_texture.custom_minimum_size.x
	var nav_scale = float(GRID_SIZE) / display_size
	var grid_pos = local_pos * nav_scale
	var world_pos = grid_pos * GridConstants.CELL_SIZE

	# Clamp to map bounds (0 to GRID_SIZE * GridConstants.CELL_SIZE)
	var max_world = GRID_SIZE * GridConstants.CELL_SIZE
	world_pos.x = clampf(world_pos.x, 0, max_world)
	world_pos.y = clampf(world_pos.y, 0, max_world)

	# Move camera
	_game_world.camera.position = world_pos
