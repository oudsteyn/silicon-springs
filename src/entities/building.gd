extends Node2D
class_name Building
## Base building entity that represents a placed building in the world

@onready var sprite: TextureRect = $Sprite2D
@onready var color_overlay: ColorRect = $Sprite2D/ColorOverlay
@onready var selection_indicator: Node2D = $SelectionIndicator
@onready var click_area: Area2D = $ClickArea
@onready var collision_shape: CollisionShape2D = $ClickArea/CollisionShape2D
@onready var status_icons: Node2D = $StatusIcons

# Renderer reference (lazily resolved via tree lookup)
var _building_renderer: Node = null

## Get building renderer, resolving via tree if needed
func _get_renderer() -> Node:
	if _building_renderer and is_instance_valid(_building_renderer):
		return _building_renderer
	# Find renderer in tree via group
	var renderers = get_tree().get_nodes_in_group("building_renderer")
	if renderers.size() > 0:
		_building_renderer = renderers[0]
		return _building_renderer
	return null

var building_data: Resource = null  # BuildingData resource
var grid_cell: Vector2i = Vector2i.ZERO

# Operational status
var is_operational: bool = true
var is_powered: bool = true
var is_watered: bool = true
var health: int = 100

# Development level (for zones: 1=small, 2=medium, 3=large)
var development_level: int = 1
var development_progress: float = 0.0  # 0 to 100, grows to next level at 100

# Construction state (for zones - they need to be built before becoming operational)
var is_under_construction: bool = false
var construction_progress: float = 0.0  # 0 to 100
const CONSTRUCTION_RATE: float = 25.0  # Progress per month (4 months to complete)

# Abandonment tracking
var is_abandoned: bool = false
var months_without_power: int = 0
var months_without_water: int = 0
const ABANDONMENT_THRESHOLD: int = 6  # Months without utilities before abandonment

# Infrastructure condition tracking (synced from InfrastructureAgeSystem)
var infrastructure_condition: float = 100.0  # 0-100, affects visual appearance

# Visual state
var is_selected: bool = false
var is_hovered: bool = false
var _base_modulate: Color = Color.WHITE
var _hover_tween: Tween = null
var _base_scale: Vector2 = Vector2.ONE

# Hover effect configuration
const HOVER_BRIGHTNESS: float = 0.35
const HOVER_SCALE: float = 1.025

# Age/condition visual settings
const CONDITION_DESATURATION_START: float = 70.0  # Start desaturating below this
const CONDITION_DESATURATION_MAX: float = 0.35    # Maximum desaturation amount
const CONDITION_DARKENING_START: float = 40.0     # Start darkening below this
const CONDITION_DARKENING_MAX: float = 0.25       # Maximum darkening amount
const HOVER_ANIM_DURATION: float = 0.12
const HOVER_OUTLINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
const HOVER_OUTLINE_WIDTH: float = 2.0

# Hover outline reference
var _hover_outline: Line2D = null

# Status icon references
var power_icon: Label = null
var water_icon: Label = null
var abandoned_icon: Label = null
var construction_icon: Label = null
var condition_icon: Label = null  # Shows poor infrastructure condition


func _ready() -> void:
	add_to_group("buildings")
	z_index = ZLayers.BUILDINGS  # Ensure buildings render above terrain
	_setup_hover_outline()
	_setup_status_icons()
	_connect_infrastructure_events()
	_base_scale = scale
	_base_modulate = Color.WHITE
	_update_visual()


func _connect_infrastructure_events() -> void:
	# Subscribe to infrastructure network changes for neighbor-aware visuals
	Events.road_network_changed.connect(_on_road_network_changed)
	Events.water_pipe_network_changed.connect(_on_water_pipe_network_changed)
	Events.power_line_network_changed.connect(_on_power_line_network_changed)


func _on_road_network_changed(cell: Vector2i, _added: bool) -> void:
	# Only roads need to update when adjacent roads change
	if not building_data or not GridConstants.is_road_type(building_data.building_type):
		return
	if _is_adjacent_cell(cell):
		_update_visual()


func _on_water_pipe_network_changed(cell: Vector2i, _added: bool) -> void:
	# Only water pipes need to update when adjacent pipes change
	if not building_data or not GridConstants.is_water_type(building_data.building_type):
		return
	if _is_adjacent_cell(cell):
		_update_visual()


func _on_power_line_network_changed(cell: Vector2i, _added: bool) -> void:
	# Only power lines need to update when adjacent lines change
	if not building_data or not GridConstants.is_power_type(building_data.building_type):
		return
	if _is_adjacent_cell(cell):
		_update_visual()


func _is_adjacent_cell(cell: Vector2i) -> bool:
	# Check if cell is adjacent to this building's grid cell
	# For multi-cell buildings, check all cells
	if not building_data:
		return false

	var size = building_data.size
	for x in range(size.x):
		for y in range(size.y):
			var building_cell = grid_cell + Vector2i(x, y)
			# Check 4-directional adjacency
			if abs(cell.x - building_cell.x) + abs(cell.y - building_cell.y) == 1:
				return true
	return false


func _setup_hover_outline() -> void:
	# Create hover outline as Line2D for glow effect
	_hover_outline = Line2D.new()
	_hover_outline.name = "HoverOutline"
	_hover_outline.width = HOVER_OUTLINE_WIDTH
	_hover_outline.default_color = HOVER_OUTLINE_COLOR
	_hover_outline.visible = false
	_hover_outline.z_index = 1  # Above sprite
	_hover_outline.joint_mode = Line2D.LINE_JOINT_ROUND
	_hover_outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_hover_outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_hover_outline)


func _setup_status_icons() -> void:
	# Create status icons container if it doesn't exist
	if not status_icons:
		status_icons = Node2D.new()
		status_icons.name = "StatusIcons"
		add_child(status_icons)

	# Power icon (lightning bolt)
	power_icon = Label.new()
	power_icon.text = "⚡"
	power_icon.add_theme_font_size_override("font_size", 16)
	power_icon.modulate = Color.YELLOW
	power_icon.visible = false
	power_icon.position = Vector2(2, 2)
	status_icons.add_child(power_icon)

	# Water icon (droplet)
	water_icon = Label.new()
	water_icon.text = "💧"
	water_icon.add_theme_font_size_override("font_size", 16)
	water_icon.modulate = Color.CYAN
	water_icon.visible = false
	water_icon.position = Vector2(18, 2)
	status_icons.add_child(water_icon)

	# Abandoned icon
	abandoned_icon = Label.new()
	abandoned_icon.text = "🏚️"
	abandoned_icon.add_theme_font_size_override("font_size", 20)
	abandoned_icon.modulate = Color(0.6, 0.4, 0.2)
	abandoned_icon.visible = false
	abandoned_icon.position = Vector2(34, 0)
	status_icons.add_child(abandoned_icon)

	# Construction icon
	construction_icon = Label.new()
	construction_icon.text = "🚧"
	construction_icon.add_theme_font_size_override("font_size", 20)
	construction_icon.modulate = Color.ORANGE
	construction_icon.visible = false
	construction_icon.position = Vector2(2, 20)
	status_icons.add_child(construction_icon)

	# Condition/maintenance icon (wrench for poor condition)
	condition_icon = Label.new()
	condition_icon.text = "🔧"
	condition_icon.add_theme_font_size_override("font_size", 16)
	condition_icon.modulate = Color(0.85, 0.65, 0.25)  # Warning orange
	condition_icon.visible = false
	condition_icon.position = Vector2(18, 20)
	status_icons.add_child(condition_icon)


func initialize(data: Resource, cell: Vector2i) -> void:
	building_data = data
	grid_cell = cell
	name = "%s_%d_%d" % [data.id, cell.x, cell.y]

	# Zones start under construction (except agricultural — crops grow, not built)
	if data.category == "zone" and data.building_type != "agricultural":
		is_under_construction = true
		construction_progress = 0.0

	var pixel_size = Vector2(data.size) * GridConstants.CELL_SIZE

	# Set sprite size based on building size
	if sprite:
		sprite.offset_right = pixel_size.x
		sprite.offset_bottom = pixel_size.y
		sprite.size = pixel_size

		# Generate texture using renderer
		var renderer = _get_renderer()
		if renderer:
			sprite.texture = renderer.get_building_texture(data, development_level, cell)

	# Update selection indicator size
	if selection_indicator:
		var sel_rect = selection_indicator.get_node_or_null("SelectionRect")
		if sel_rect and sel_rect is ColorRect:
			sel_rect.offset_right = pixel_size.x
			sel_rect.offset_bottom = pixel_size.y

	# Update collision shape
	if collision_shape:
		var shape = collision_shape.shape
		if shape == null:
			shape = RectangleShape2D.new()
			collision_shape.shape = shape
		if shape is RectangleShape2D:
			shape.size = pixel_size
			collision_shape.position = pixel_size / 2

	# Update hover outline to match building size
	_update_hover_outline_shape(pixel_size)

	_update_visual()
	_update_operational_status()


func _update_hover_outline_shape(pixel_size: Vector2) -> void:
	if not _hover_outline:
		return

	# Create outline points with slight inset
	var inset = HOVER_OUTLINE_WIDTH * 0.5
	var w = pixel_size.x - inset * 2
	var h = pixel_size.y - inset * 2

	_hover_outline.clear_points()
	_hover_outline.add_point(Vector2(inset, inset))
	_hover_outline.add_point(Vector2(inset + w, inset))
	_hover_outline.add_point(Vector2(inset + w, inset + h))
	_hover_outline.add_point(Vector2(inset, inset + h))
	_hover_outline.add_point(Vector2(inset, inset))  # Close the loop


func _update_visual() -> void:
	if not sprite or not building_data:
		return

	# Update texture if development level changed (zones) or if road/power_line/water_pipe needs neighbor update
	var renderer = _get_renderer()
	if renderer:
		if building_data.category == "zone":
			sprite.texture = renderer.get_building_texture(building_data, development_level, grid_cell)
		elif GridConstants.is_road_type(building_data.building_type):
			sprite.texture = renderer.get_building_texture(building_data, development_level, grid_cell)
		elif GridConstants.is_power_type(building_data.building_type):
			sprite.texture = renderer.get_building_texture(building_data, development_level, grid_cell)
		elif GridConstants.is_water_type(building_data.building_type):
			sprite.texture = renderer.get_building_texture(building_data, development_level, grid_cell)

	# Show dark overlay if not operational
	if color_overlay:
		color_overlay.visible = not is_operational

	# Update selection indicator
	if selection_indicator:
		selection_indicator.visible = is_selected

	# Update status icons
	_update_status_icons()


func _update_status_icons() -> void:
	if not building_data:
		return

	# Show construction icon if under construction
	if construction_icon:
		construction_icon.visible = is_under_construction

	# Show power icon if building needs power but doesn't have it (not during construction)
	if power_icon:
		power_icon.visible = building_data.requires_power and not is_powered and not is_abandoned and not is_under_construction

	# Show water icon if building needs water but doesn't have it (not during construction)
	if water_icon:
		water_icon.visible = building_data.requires_water and not is_watered and not is_abandoned and not is_under_construction

	# Show abandoned icon
	if abandoned_icon:
		abandoned_icon.visible = is_abandoned

	# Show condition icon for poor/critical infrastructure
	if condition_icon:
		# Show wrench icon when condition is poor (below 40%)
		condition_icon.visible = infrastructure_condition < 40.0 and not is_abandoned and not is_under_construction
		# Color based on severity: orange for poor, red for critical
		if infrastructure_condition < 20.0:
			condition_icon.modulate = Color(0.85, 0.30, 0.30)  # Critical red
		else:
			condition_icon.modulate = Color(0.85, 0.65, 0.25)  # Warning orange


func _update_operational_status() -> void:
	var was_operational = is_operational

	# Buildings under construction are never operational
	if is_under_construction:
		is_operational = false
		if was_operational:
			_update_visual()
		return

	# Abandoned buildings are never operational
	if is_abandoned:
		is_operational = false
		if was_operational:
			_update_visual()
		return

	# Building is operational if it has power (if required) and water (if required)
	is_operational = true

	if building_data:
		if building_data.requires_power and not is_powered:
			is_operational = false
		if building_data.requires_water and not is_watered:
			is_operational = false

	# Health check
	if health <= 0:
		is_operational = false

	if was_operational != is_operational:
		_update_visual()
	else:
		# Still update icons even if operational status didn't change
		_update_status_icons()


func set_powered(powered: bool) -> void:
	var was_powered = is_powered
	is_powered = powered
	_update_operational_status()
	if was_powered != powered:
		_update_status_icons()


func set_watered(watered: bool) -> void:
	var was_watered = is_watered
	is_watered = watered
	_update_operational_status()
	if was_watered != watered:
		_update_status_icons()


func set_selected(selected: bool) -> void:
	is_selected = selected
	if selection_indicator:
		selection_indicator.visible = selected


func set_hovered(hovered: bool) -> void:
	if is_hovered == hovered:
		return

	is_hovered = hovered

	# Kill any existing hover tween
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	_hover_tween = create_tween()
	_hover_tween.set_parallel(true)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.set_trans(Tween.TRANS_CUBIC)

	if hovered and not is_selected:
		# Animate to hover state
		var target_modulate = _get_base_modulate().lightened(HOVER_BRIGHTNESS)
		var target_scale = _base_scale * HOVER_SCALE

		if sprite:
			_hover_tween.tween_property(sprite, "modulate", target_modulate, HOVER_ANIM_DURATION)

		_hover_tween.tween_property(self, "scale", target_scale, HOVER_ANIM_DURATION)

		# Show and animate outline
		if _hover_outline:
			_hover_outline.visible = true
			_hover_outline.modulate.a = 0.0
			_hover_tween.tween_property(_hover_outline, "modulate:a", 1.0, HOVER_ANIM_DURATION)
	else:
		# Animate back to normal state
		var target_modulate = _get_base_modulate()

		if sprite:
			_hover_tween.tween_property(sprite, "modulate", target_modulate, HOVER_ANIM_DURATION)

		_hover_tween.tween_property(self, "scale", _base_scale, HOVER_ANIM_DURATION)

		# Hide outline
		if _hover_outline:
			_hover_tween.tween_property(_hover_outline, "modulate:a", 0.0, HOVER_ANIM_DURATION * 0.5)
			_hover_tween.tween_callback(func(): _hover_outline.visible = false).set_delay(HOVER_ANIM_DURATION * 0.5)


func _get_base_modulate() -> Color:
	# Return the appropriate base modulate based on building state
	if is_abandoned:
		return Color(0.5, 0.5, 0.5, 0.8)

	# Apply age-based visual degradation
	var result = _base_modulate
	if infrastructure_condition < CONDITION_DESATURATION_START:
		# Calculate desaturation based on condition
		var desat_factor = (CONDITION_DESATURATION_START - infrastructure_condition) / CONDITION_DESATURATION_START
		desat_factor = clampf(desat_factor, 0.0, 1.0)
		var desat_amount = desat_factor * CONDITION_DESATURATION_MAX

		# Desaturate by moving toward gray
		var gray = (result.r + result.g + result.b) / 3.0
		result.r = lerpf(result.r, gray, desat_amount)
		result.g = lerpf(result.g, gray, desat_amount)
		result.b = lerpf(result.b, gray, desat_amount)

	if infrastructure_condition < CONDITION_DARKENING_START:
		# Calculate darkening based on condition
		var dark_factor = (CONDITION_DARKENING_START - infrastructure_condition) / CONDITION_DARKENING_START
		dark_factor = clampf(dark_factor, 0.0, 1.0)
		var dark_amount = dark_factor * CONDITION_DARKENING_MAX

		# Darken
		result = result.darkened(dark_amount)

	return result


## Update infrastructure condition from InfrastructureAgeSystem
func set_infrastructure_condition(condition: float) -> void:
	var old_condition = infrastructure_condition
	infrastructure_condition = clampf(condition, 0.0, 100.0)

	# Update visuals if condition changed significantly
	if abs(old_condition - infrastructure_condition) > 5.0:
		_update_status_icons()
		# Update sprite modulate if not in hover state
		if not is_hovered and sprite:
			sprite.modulate = _get_base_modulate()


func take_damage(amount: int) -> void:
	health = max(0, health - amount)
	_update_operational_status()

	if health <= 0:
		Events.simulation_event.emit("building_destroyed", {"name": building_data.display_name})


func repair(amount: int) -> void:
	health = min(100, health + amount)
	_update_operational_status()


func add_construction_progress(amount: float) -> void:
	if not is_under_construction:
		return

	construction_progress += amount
	if construction_progress >= 100.0:
		construction_progress = 100.0
		_complete_construction()


func _complete_construction() -> void:
	is_under_construction = false
	_update_operational_status()
	_update_visual()

	Events.simulation_event.emit("building_constructed", {"name": building_data.display_name})
	Events.building_constructed.emit(self)


func add_development_progress(amount: float) -> void:
	# Can't develop while under construction
	if is_under_construction:
		return

	if development_level >= 3:
		return  # Max level

	development_progress += amount
	if development_progress >= 100.0:
		development_progress = 0.0
		development_level += 1
		_on_level_up()


func _on_level_up() -> void:
	_update_visual()
	Events.simulation_event.emit("building_upgrade_success", {
		"name": building_data.display_name,
		"level": development_level
	})
	Events.building_upgraded.emit(self, development_level)


func get_effective_capacity() -> int:
	# Higher development = more capacity (for residential)
	if building_data and building_data.population_capacity > 0:
		return int(building_data.population_capacity * (0.5 + 0.25 * development_level))
	return 0


func get_effective_jobs() -> int:
	# Higher development = more jobs (for commercial/industrial)
	if building_data and building_data.jobs_provided > 0:
		return int(building_data.jobs_provided * (0.5 + 0.25 * development_level))
	return 0


func get_info() -> Dictionary:
	var info = {
		"name": building_data.display_name if building_data else "Unknown",
		"description": building_data.description if building_data else "",
		"category": building_data.category if building_data else "",
		"cell": grid_cell,
		"operational": is_operational,
		"powered": is_powered,
		"watered": is_watered,
		"health": health,
		"maintenance": building_data.monthly_maintenance if building_data else 0
	}

	if building_data:
		if building_data.power_production > 0:
			info["power_production"] = building_data.power_production
		if building_data.power_consumption > 0:
			info["power_consumption"] = building_data.power_consumption
		if building_data.water_production > 0:
			info["water_production"] = building_data.water_production
		if building_data.water_consumption > 0:
			info["water_consumption"] = building_data.water_consumption
		if building_data.coverage_radius > 0:
			info["coverage_radius"] = building_data.coverage_radius
			info["service_type"] = building_data.service_type

	return info


func _on_mouse_entered() -> void:
	set_hovered(true)


func _on_mouse_exited() -> void:
	set_hovered(false)


func process_monthly_abandonment() -> void:
	# Only zone buildings can be abandoned
	if not building_data or building_data.category != "zone":
		return

	# Skip if already abandoned
	if is_abandoned:
		return

	# Track months without utilities
	if building_data.requires_power and not is_powered:
		months_without_power += 1
	else:
		months_without_power = 0

	if building_data.requires_water and not is_watered:
		months_without_water += 1
	else:
		months_without_water = 0

	# Check for abandonment
	if months_without_power >= ABANDONMENT_THRESHOLD or months_without_water >= ABANDONMENT_THRESHOLD:
		_become_abandoned()


func _become_abandoned() -> void:
	is_abandoned = true
	is_operational = false

	# Visual feedback - animate to abandoned state
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", Color(0.5, 0.5, 0.5, 0.8), 0.3)

	_update_visual()
	_update_status_icons()

	Events.simulation_event.emit("building_abandoned", {"name": building_data.display_name})
	Events.building_abandoned.emit(self)


func restore_from_abandonment() -> void:
	# Can be called when utilities are restored - player might want to restore building
	if not is_abandoned:
		return

	is_abandoned = false
	months_without_power = 0
	months_without_water = 0

	# Animate back to normal
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", _base_modulate, 0.3)

	_update_operational_status()
	_update_visual()
