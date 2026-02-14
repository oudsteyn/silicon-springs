extends Node2D
class_name ActionFeedbackEffects
## Visual feedback system for game actions like building placement, demolition, zone painting
## Uses pooled particle-like effects drawn with _draw() for efficiency


# Effect types
enum EffectType {
	PLACEMENT_SUCCESS,   # Green pulse/sparkle for building placed
	PLACEMENT_FAIL,      # Red shake/flash for failed placement
	DEMOLITION,          # Orange/red particles flying outward
	ZONE_PAINT,          # Color-coded fill sweep
	PATH_COMPLETE,       # Sequential highlights along path
	MONEY_GAIN,          # Green floating number
	MONEY_LOSS,          # Red floating number
	POWER_CONNECT,       # Yellow/electric spark effect
	WATER_CONNECT,       # Blue ripple effect
	UPGRADE,             # Rising sparkles/stars
	ERROR,               # Red X with shake
}

# Configuration
const MAX_EFFECTS: int = 50
const POOL_SIZE: int = 100

# Colors by effect type
const COLORS: Dictionary = {
	EffectType.PLACEMENT_SUCCESS: Color(0.3, 0.95, 0.5, 1.0),
	EffectType.PLACEMENT_FAIL: Color(0.95, 0.3, 0.3, 1.0),
	EffectType.DEMOLITION: Color(0.95, 0.6, 0.2, 1.0),
	EffectType.ZONE_PAINT: Color(0.6, 0.7, 0.8, 0.8),
	EffectType.PATH_COMPLETE: Color(0.4, 0.9, 0.6, 1.0),
	EffectType.MONEY_GAIN: Color(0.3, 0.9, 0.4, 1.0),
	EffectType.MONEY_LOSS: Color(0.9, 0.3, 0.3, 1.0),
	EffectType.POWER_CONNECT: Color(1.0, 0.9, 0.2, 1.0),
	EffectType.WATER_CONNECT: Color(0.3, 0.6, 0.95, 1.0),
	EffectType.UPGRADE: Color(0.9, 0.8, 0.3, 1.0),
	EffectType.ERROR: Color(0.9, 0.2, 0.2, 1.0),
}

# Effect durations
const DURATIONS: Dictionary = {
	EffectType.PLACEMENT_SUCCESS: 0.6,
	EffectType.PLACEMENT_FAIL: 0.4,
	EffectType.DEMOLITION: 0.8,
	EffectType.ZONE_PAINT: 0.3,
	EffectType.PATH_COMPLETE: 0.8,
	EffectType.MONEY_GAIN: 1.2,
	EffectType.MONEY_LOSS: 1.2,
	EffectType.POWER_CONNECT: 0.5,
	EffectType.WATER_CONNECT: 0.6,
	EffectType.UPGRADE: 1.0,
	EffectType.ERROR: 0.5,
}

# Active effects
var _effects: Array[Dictionary] = []  # {type, pos, time, duration, data, particles}
var _events: Node = null

# Particle structure: {pos: Vector2, vel: Vector2, life: float, size: float, color: Color}


func _ready() -> void:
	z_index = 50  # Above buildings, below UI

	# Connect to game events
	var events = _get_events()
	if events:
		events.building_placed.connect(_on_building_placed)
		events.building_removed.connect(_on_building_removed)
		events.simulation_event.connect(_on_simulation_event)


func set_events(events: Node) -> void:
	_events = events


func _get_events() -> Node:
	if _events:
		return _events
	var tree = get_tree()
	if tree:
		return tree.root.get_node_or_null("Events")
	return null


func _process(delta: float) -> void:
	# Update all effects
	for i in range(_effects.size() - 1, -1, -1):
		var effect = _effects[i]
		effect.time += delta

		# Update particles if any
		if effect.has("particles"):
			_update_particles(effect, delta)

		# Remove completed effects
		if effect.time >= effect.duration:
			_effects.remove_at(i)

	if _effects.size() > 0:
		queue_redraw()


func _draw() -> void:
	for effect in _effects:
		var progress = effect.time / effect.duration
		var alpha = _ease_out(1.0 - progress)

		match effect.type:
			EffectType.PLACEMENT_SUCCESS:
				_draw_placement_success(effect, progress, alpha)
			EffectType.PLACEMENT_FAIL:
				_draw_placement_fail(effect, progress, alpha)
			EffectType.DEMOLITION:
				_draw_demolition(effect, progress, alpha)
			EffectType.ZONE_PAINT:
				_draw_zone_paint(effect, progress, alpha)
			EffectType.PATH_COMPLETE:
				_draw_path_complete(effect, progress, alpha)
			EffectType.MONEY_GAIN, EffectType.MONEY_LOSS:
				_draw_money_popup(effect, progress, alpha)
			EffectType.POWER_CONNECT:
				_draw_power_connect(effect, progress, alpha)
			EffectType.WATER_CONNECT:
				_draw_water_connect(effect, progress, alpha)
			EffectType.UPGRADE:
				_draw_upgrade(effect, progress, alpha)
			EffectType.ERROR:
				_draw_error(effect, progress, alpha)


func _draw_placement_success(effect: Dictionary, progress: float, alpha: float) -> void:
	var pos = effect.pos
	var size = effect.data.get("size", Vector2i(1, 1))
	var cell_size = Vector2(size) * GridConstants.CELL_SIZE
	var center = pos + cell_size * 0.5

	var color = COLORS[EffectType.PLACEMENT_SUCCESS]
	color.a = alpha

	# Expanding ring
	var ring_radius = (cell_size.x * 0.5 + 20) * _ease_out(progress)
	var ring_width = maxf(3.0 * (1.0 - progress), 0.5)
	draw_arc(center, ring_radius, 0, TAU, 32, color, ring_width)

	# Corner sparkles
	var corners = [
		pos,
		pos + Vector2(cell_size.x, 0),
		pos + Vector2(0, cell_size.y),
		pos + cell_size
	]

	for i in range(corners.size()):
		var corner = corners[i]
		var sparkle_progress = clampf((progress - 0.1 * i) * 1.5, 0.0, 1.0)
		if sparkle_progress > 0:
			var sparkle_alpha = alpha * (1.0 - sparkle_progress)
			var sparkle_size = 8.0 * (1.0 - sparkle_progress * 0.5)
			_draw_sparkle(corner, sparkle_size, Color(color.r, color.g, color.b, sparkle_alpha))

	# Draw particles
	if effect.has("particles"):
		for p in effect.particles:
			var p_color = p.color
			p_color.a *= p.life
			draw_circle(p.pos, p.size * p.life, p_color)


func _draw_placement_fail(effect: Dictionary, progress: float, alpha: float) -> void:
	var pos = effect.pos
	var size = effect.data.get("size", Vector2i(1, 1))
	var cell_size = Vector2(size) * GridConstants.CELL_SIZE

	var color = COLORS[EffectType.PLACEMENT_FAIL]
	color.a = alpha * 0.6

	# Shake offset
	var shake = sin(progress * TAU * 8) * 4 * (1.0 - progress)
	var shake_offset = Vector2(shake, 0)

	# Draw X mark
	var center = pos + cell_size * 0.5 + shake_offset
	var x_size = minf(cell_size.x, cell_size.y) * 0.3

	var line_color = COLORS[EffectType.PLACEMENT_FAIL]
	line_color.a = alpha

	draw_line(center + Vector2(-x_size, -x_size), center + Vector2(x_size, x_size), line_color, 4.0)
	draw_line(center + Vector2(x_size, -x_size), center + Vector2(-x_size, x_size), line_color, 4.0)

	# Flash overlay
	if progress < 0.3:
		var flash_alpha = (1.0 - progress / 0.3) * 0.4
		draw_rect(Rect2(pos + shake_offset, cell_size), Color(color.r, color.g, color.b, flash_alpha))


func _draw_demolition(effect: Dictionary, progress: float, alpha: float) -> void:
	var pos = effect.pos
	var size = effect.data.get("size", Vector2i(1, 1))
	var cell_size = Vector2(size) * GridConstants.CELL_SIZE
	var center = pos + cell_size * 0.5

	# Draw particles flying outward
	if effect.has("particles"):
		for p in effect.particles:
			var p_color = p.color
			p_color.a *= p.life * alpha
			# Draw as small rectangles for debris effect
			var rect_size = Vector2(p.size, p.size) * p.life * 1.5
			var rect = Rect2(p.pos - rect_size * 0.5, rect_size)
			draw_rect(rect, p_color)

	# Initial flash
	if progress < 0.15:
		var flash_progress = progress / 0.15
		var flash_color = COLORS[EffectType.DEMOLITION]
		flash_color.a = (1.0 - flash_progress) * 0.5
		draw_rect(Rect2(pos, cell_size), flash_color)

	# Dust cloud effect
	if progress > 0.2:
		var dust_progress = (progress - 0.2) / 0.8
		var dust_radius = cell_size.x * 0.4 * (1.0 + dust_progress * 0.5)
		var dust_color = Color(0.6, 0.5, 0.4, alpha * 0.3 * (1.0 - dust_progress))
		draw_circle(center, dust_radius, dust_color)


func _draw_zone_paint(effect: Dictionary, progress: float, alpha: float) -> void:
	var rect = effect.data.get("rect", Rect2i())
	var zone_color = effect.data.get("color", COLORS[EffectType.ZONE_PAINT])

	var world_rect = Rect2(
		Vector2(rect.position) * GridConstants.CELL_SIZE,
		Vector2(rect.size) * GridConstants.CELL_SIZE
	)

	# Sweep fill animation
	var fill_progress = _ease_out(progress)
	var fill_rect = Rect2(
		world_rect.position,
		Vector2(world_rect.size.x * fill_progress, world_rect.size.y)
	)

	var fill_color = zone_color
	fill_color.a = alpha * 0.4
	draw_rect(fill_rect, fill_color)

	# Border highlight
	var border_color = zone_color
	border_color.a = alpha * 0.8
	draw_rect(world_rect, border_color, false, 2.0)


func _draw_path_complete(effect: Dictionary, progress: float, alpha: float) -> void:
	var cells: Array = effect.data.get("cells", [])
	if cells.size() == 0:
		return

	var color = COLORS[EffectType.PATH_COMPLETE]

	# Sequential highlight along path
	var highlight_index = int(progress * cells.size() * 1.5)

	for i in range(cells.size()):
		var cell = cells[i] as Vector2i
		var cell_pos = Vector2(cell) * GridConstants.CELL_SIZE
		var cell_center = cell_pos + Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE) * 0.5

		# Calculate cell-specific alpha
		var cell_progress = clampf(float(highlight_index - i) / 3.0, 0.0, 1.0)
		var cell_alpha = alpha * cell_progress * (1.0 - float(i) / cells.size() * 0.3)

		if cell_alpha > 0.01:
			var cell_color = color
			cell_color.a = cell_alpha * 0.5
			draw_rect(Rect2(cell_pos + Vector2(2, 2), Vector2(GridConstants.CELL_SIZE - 4, GridConstants.CELL_SIZE - 4)), cell_color)

			# Connecting line to next cell
			if i < cells.size() - 1 and cell_progress > 0.5:
				var next_cell = cells[i + 1] as Vector2i
				var next_center = Vector2(next_cell) * GridConstants.CELL_SIZE + Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE) * 0.5
				var line_color = color
				line_color.a = cell_alpha * 0.7
				draw_line(cell_center, next_center, line_color, 2.0)


func _draw_money_popup(effect: Dictionary, progress: float, alpha: float) -> void:
	var pos = effect.pos
	var amount = effect.data.get("amount", 0)
	var is_gain = effect.type == EffectType.MONEY_GAIN

	var font = ThemeDB.fallback_font
	var text = ("+$%d" if is_gain else "-$%d") % abs(amount)
	var color = COLORS[effect.type]
	color.a = alpha

	# Float upward
	var float_offset = Vector2(0, -40 * _ease_out(progress))
	var text_pos = pos + float_offset

	# Scale effect
	var text_scale = 1.0 + 0.3 * (1.0 - progress)

	# Draw with slight outline for readability
	var outline_color = Color(0, 0, 0, alpha * 0.5)
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, text_pos + offset, text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(14 * text_scale), outline_color)

	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(14 * text_scale), color)


func _draw_power_connect(effect: Dictionary, progress: float, alpha: float) -> void:
	var pos = effect.pos
	var center = pos + Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE) * 0.5
	var color = COLORS[EffectType.POWER_CONNECT]

	# Electric spark effect
	var num_sparks = 6
	for i in range(num_sparks):
		var angle = (TAU / num_sparks) * i + progress * TAU * 2
		var spark_progress = fmod(progress * 3 + float(i) / num_sparks, 1.0)
		var spark_length = 20.0 * (1.0 - spark_progress)
		var spark_offset = Vector2(cos(angle), sin(angle)) * (15 + spark_progress * 25)

		var spark_color = color
		spark_color.a = alpha * (1.0 - spark_progress)

		var spark_start = center + spark_offset
		var spark_end = spark_start + Vector2(cos(angle), sin(angle)) * spark_length

		# Jagged lightning effect
		var mid = (spark_start + spark_end) * 0.5 + Vector2(randf_range(-5, 5), randf_range(-5, 5))
		draw_line(spark_start, mid, spark_color, 2.0)
		draw_line(mid, spark_end, spark_color, 2.0)

	# Central glow
	var glow_color = color
	glow_color.a = alpha * 0.3 * (1.0 - progress)
	draw_circle(center, 25 * (1.0 + progress * 0.5), glow_color)


func _draw_water_connect(effect: Dictionary, progress: float, alpha: float) -> void:
	var pos = effect.pos
	var center = pos + Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE) * 0.5
	var color = COLORS[EffectType.WATER_CONNECT]

	# Expanding ripple rings
	for i in range(3):
		var ring_progress = fmod(progress + float(i) * 0.3, 1.0)
		var ring_radius = 10 + ring_progress * 35
		var ring_alpha = alpha * (1.0 - ring_progress) * 0.7

		var ring_color = color
		ring_color.a = ring_alpha
		draw_arc(center, ring_radius, 0, TAU, 24, ring_color, 2.0 * (1.0 - ring_progress * 0.5))

	# Water droplets
	if effect.has("particles"):
		for p in effect.particles:
			var p_color = p.color
			p_color.a *= p.life * alpha
			# Draw as teardrop shape
			draw_circle(p.pos, p.size * p.life, p_color)


func _draw_upgrade(effect: Dictionary, progress: float, alpha: float) -> void:
	var pos = effect.pos
	var size = effect.data.get("size", Vector2i(1, 1))
	var cell_size = Vector2(size) * GridConstants.CELL_SIZE
	var center = pos + cell_size * 0.5

	var color = COLORS[EffectType.UPGRADE]

	# Rising stars/sparkles
	if effect.has("particles"):
		for p in effect.particles:
			var p_color = p.color
			p_color.a *= p.life * alpha
			_draw_star(p.pos, p.size * p.life * 1.5, p_color)

	# Upward arrow indicator
	var arrow_y = center.y - progress * 40
	var arrow_alpha = alpha * (1.0 - progress * 0.5)
	var arrow_color = color
	arrow_color.a = arrow_alpha

	var arrow_size = 12.0
	draw_line(Vector2(center.x, arrow_y), Vector2(center.x, arrow_y - arrow_size), arrow_color, 3.0)
	draw_line(Vector2(center.x, arrow_y - arrow_size), Vector2(center.x - arrow_size * 0.5, arrow_y - arrow_size * 0.5), arrow_color, 3.0)
	draw_line(Vector2(center.x, arrow_y - arrow_size), Vector2(center.x + arrow_size * 0.5, arrow_y - arrow_size * 0.5), arrow_color, 3.0)


func _draw_error(effect: Dictionary, progress: float, alpha: float) -> void:
	var pos = effect.pos
	var color = COLORS[EffectType.ERROR]
	color.a = alpha

	# Shake
	var shake = sin(progress * TAU * 6) * 5 * (1.0 - progress)
	var shake_pos = pos + Vector2(shake, 0)

	# X mark
	var x_size = 15.0
	draw_line(shake_pos + Vector2(-x_size, -x_size), shake_pos + Vector2(x_size, x_size), color, 4.0)
	draw_line(shake_pos + Vector2(x_size, -x_size), shake_pos + Vector2(-x_size, x_size), color, 4.0)

	# Circle around X
	var ring_color = color
	ring_color.a = alpha * 0.5
	draw_arc(shake_pos, x_size + 8, 0, TAU, 24, ring_color, 2.0)


func _draw_sparkle(pos: Vector2, size: float, color: Color) -> void:
	# Four-pointed star shape
	var points: PackedVector2Array = []
	for i in range(8):
		var angle = (TAU / 8) * i
		var dist = size if i % 2 == 0 else size * 0.4
		points.append(pos + Vector2(cos(angle), sin(angle)) * dist)
	points.append(points[0])  # Close the shape
	draw_polyline(points, color, 2.0)


func _draw_star(pos: Vector2, size: float, color: Color) -> void:
	# Five-pointed star
	var points: PackedVector2Array = []
	for i in range(10):
		var angle = (TAU / 10) * i - PI * 0.5
		var dist = size if i % 2 == 0 else size * 0.4
		points.append(pos + Vector2(cos(angle), sin(angle)) * dist)
	points.append(points[0])
	draw_polygon(points, [color])


func _update_particles(effect: Dictionary, delta: float) -> void:
	var particles = effect.particles as Array
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		p.pos += p.vel * delta
		p.vel.y += 150.0 * delta  # Gravity
		p.life -= delta / (effect.duration * 0.8)

		if p.life <= 0:
			particles.remove_at(i)


func _create_particles(pos: Vector2, count: int, color: Color, spread: float = 100.0, size_range: Vector2 = Vector2(3, 8)) -> Array:
	var particles: Array = []
	for i in range(count):
		var angle = randf() * TAU
		var speed = randf_range(50, spread)
		particles.append({
			"pos": pos,
			"vel": Vector2(cos(angle), sin(angle)) * speed + Vector2(0, -50),
			"life": 1.0,
			"size": randf_range(size_range.x, size_range.y),
			"color": color.lightened(randf_range(-0.2, 0.2))
		})
	return particles


func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3)


# === Public API ===

## Spawn a visual effect at cell position
func spawn_effect(type: EffectType, cell: Vector2i, data: Dictionary = {}) -> void:
	if _effects.size() >= MAX_EFFECTS:
		_effects.pop_front()

	var pos = Vector2(cell) * GridConstants.CELL_SIZE
	var size = data.get("size", Vector2i(1, 1))
	var center = pos + Vector2(size) * GridConstants.CELL_SIZE * 0.5

	var effect: Dictionary = {
		"type": type,
		"pos": pos,
		"time": 0.0,
		"duration": DURATIONS.get(type, 0.5),
		"data": data
	}

	# Create particles for certain effects
	match type:
		EffectType.PLACEMENT_SUCCESS:
			effect["particles"] = _create_particles(center, 12, COLORS[type], 80.0)
		EffectType.DEMOLITION:
			effect["particles"] = _create_particles(center, 20, COLORS[type], 150.0, Vector2(4, 12))
		EffectType.WATER_CONNECT:
			effect["particles"] = _create_particles(center, 8, COLORS[type], 60.0, Vector2(2, 5))
		EffectType.UPGRADE:
			effect["particles"] = _create_particles(center, 10, COLORS[type], 50.0, Vector2(3, 7))

	_effects.append(effect)


## Spawn effect at world position (for money popups, etc.)
func spawn_effect_at_world(type: EffectType, world_pos: Vector2, data: Dictionary = {}) -> void:
	if _effects.size() >= MAX_EFFECTS:
		_effects.pop_front()

	var effect: Dictionary = {
		"type": type,
		"pos": world_pos,
		"time": 0.0,
		"duration": DURATIONS.get(type, 0.5),
		"data": data
	}

	_effects.append(effect)


## Spawn path completion effect for array of cells
func spawn_path_effect(cells: Array[Vector2i]) -> void:
	if cells.size() == 0:
		return

	spawn_effect(EffectType.PATH_COMPLETE, cells[0], {"cells": cells})


## Spawn zone paint effect for a rectangle
func spawn_zone_effect(rect: Rect2i, zone_color: Color) -> void:
	spawn_effect(EffectType.ZONE_PAINT, rect.position, {"rect": rect, "color": zone_color})


# === Event Handlers ===

func _on_building_placed(cell: Vector2i, building) -> void:
	var size = Vector2i(1, 1)
	if building and building.building_data:
		size = building.building_data.size
	spawn_effect(EffectType.PLACEMENT_SUCCESS, cell, {"size": size})


func _on_building_removed(cell: Vector2i, _building) -> void:
	spawn_effect(EffectType.DEMOLITION, cell)


func _on_simulation_event(event_type: String, data: Dictionary) -> void:
	var cell = data.get("cell", Vector2i(-1, -1))
	if cell == Vector2i(-1, -1):
		return

	match event_type:
		"insufficient_funds":
			spawn_effect(EffectType.PLACEMENT_FAIL, cell)
		"rocks_cleared", "trees_cleared", "zone_cleared", "beach_cleared":
			spawn_effect(EffectType.DEMOLITION, cell)
		"building_upgraded":
			spawn_effect(EffectType.UPGRADE, cell, data)
