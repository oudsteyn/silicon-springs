extends Node2D
class_name TrafficVisualizer
## Displays animated vehicle sprites on roads based on traffic levels

# References
var traffic_system = null
var grid_system = null

# Vehicle sprites storage
var vehicles: Array[Node2D] = []
var vehicle_pool: Array[Node2D] = []
const MAX_VEHICLES: int = 200

# Update timing
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 1.0  # Update positions every second

# Deferred action timers (for cleanup)
var _pending_timers: Array[Timer] = []

# Vehicle colors (for variety)
var vehicle_colors: Array[Color] = [
	Color(0.8, 0.2, 0.2),  # Red car
	Color(0.2, 0.2, 0.8),  # Blue car
	Color(0.2, 0.6, 0.2),  # Green car
	Color(0.9, 0.9, 0.9),  # White car
	Color(0.3, 0.3, 0.3),  # Gray car
	Color(0.9, 0.7, 0.2),  # Yellow car
]


func _ready() -> void:
	Events.building_placed.connect(_on_building_changed)
	Events.building_removed.connect(_on_building_changed)
	Events.month_tick.connect(_on_month_tick)

	# Pre-create vehicle pool
	for i in range(MAX_VEHICLES):
		var vehicle = _create_vehicle()
		vehicle.visible = false
		vehicle_pool.append(vehicle)
		add_child(vehicle)


func _exit_tree() -> void:
	# Clean up any pending timers
	for timer in _pending_timers:
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
	_pending_timers.clear()


func _deferred_call(delay: float, callback: Callable) -> void:
	if not is_inside_tree():
		return
	var timer = Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	timer.timeout.connect(func():
		_pending_timers.erase(timer)
		timer.queue_free()
		if is_inside_tree():
			callback.call()
	)
	add_child(timer)
	_pending_timers.append(timer)
	timer.start()


func _on_month_tick() -> void:
	# Update vehicles after traffic is recalculated during monthly tick
	_deferred_call(0.2, _update_vehicles)


func set_systems(traffic: Node, grid: Node) -> void:
	traffic_system = traffic
	grid_system = grid
	# Initial update delayed to allow traffic calculation
	_deferred_call(0.5, _update_vehicles)


func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		_animate_vehicles()


func _on_building_changed(_cell: Vector2i, _building: Node2D) -> void:
	# Delay update to let traffic system recalculate first
	_deferred_call(0.1, _update_vehicles)


func _update_vehicles() -> void:
	if not traffic_system or not grid_system:
		return

	# Hide all vehicles first
	for vehicle in vehicles:
		vehicle.visible = false
	vehicles.clear()

	var traffic_map = traffic_system.get_traffic_map()
	if traffic_map.size() == 0:
		return

	var pool_index = 0

	# Place vehicles on roads based on traffic
	for cell in traffic_map:
		if pool_index >= MAX_VEHICLES:
			break

		var congestion = traffic_system.get_congestion_at(cell)

		# Number of vehicles based on congestion (1-4 vehicles per road cell)
		var num_vehicles = 1 + int(congestion * 3)

		# Determine road orientation for vehicle rotation
		var road_rotation = _get_road_rotation(cell)

		for i in range(num_vehicles):
			if pool_index >= MAX_VEHICLES:
				break

			var vehicle = vehicle_pool[pool_index]
			pool_index += 1

			# Position vehicle on this road cell with some offset
			var base_pos = Vector2(cell.x * GridConstants.CELL_SIZE, cell.y * GridConstants.CELL_SIZE)
			var offset: Vector2
			if road_rotation == 0:  # Horizontal road
				# Spread along x axis, on lanes
				offset = Vector2(
					randf_range(10, GridConstants.CELL_SIZE - 10),
					randf_range(20, GridConstants.CELL_SIZE - 20)
				)
			else:  # Vertical road
				# Spread along y axis, on lanes
				offset = Vector2(
					randf_range(20, GridConstants.CELL_SIZE - 20),
					randf_range(10, GridConstants.CELL_SIZE - 10)
				)
			vehicle.position = base_pos + offset

			# Random color
			var color = vehicle_colors[randi() % vehicle_colors.size()]
			var sprite = vehicle.get_node("Sprite")
			if sprite:
				sprite.color = color

			# Rotation based on road direction with slight variation
			vehicle.rotation = road_rotation + randf_range(-0.1, 0.1)
			# 50% chance to face opposite direction
			if randf() > 0.5:
				vehicle.rotation += PI

			# Visible based on having traffic
			vehicle.visible = true
			vehicles.append(vehicle)


func _get_road_rotation(cell: Vector2i) -> float:
	# Check road neighbors to determine direction
	var has_north = grid_system.has_road_at(cell + Vector2i(0, -1))
	var has_south = grid_system.has_road_at(cell + Vector2i(0, 1))
	var has_east = grid_system.has_road_at(cell + Vector2i(1, 0))
	var has_west = grid_system.has_road_at(cell + Vector2i(-1, 0))

	var has_vertical = has_north or has_south
	var has_horizontal = has_east or has_west

	if has_vertical and not has_horizontal:
		return PI / 2  # Vertical road - cars point up/down
	elif has_horizontal and not has_vertical:
		return 0  # Horizontal road - cars point left/right
	else:
		# Intersection or corner - random direction
		if randf() > 0.5:
			return PI / 2
		else:
			return 0


func _animate_vehicles() -> void:
	# Simple animation - slight position jitter to simulate movement
	for vehicle in vehicles:
		if not vehicle.visible:
			continue

		# Small random movement
		var jitter = Vector2(randf_range(-2, 2), randf_range(-2, 2))
		vehicle.position += jitter

		# Ensure still within cell bounds
		var cell_x = int(vehicle.position.x / GridConstants.CELL_SIZE)
		var cell_y = int(vehicle.position.y / GridConstants.CELL_SIZE)
		var cell = Vector2i(cell_x, cell_y)

		# If moved out of a road cell, move back
		if grid_system and not grid_system.has_road_at(cell):
			vehicle.position -= jitter * 2


func _create_vehicle() -> Node2D:
	var vehicle = Node2D.new()

	# Simple car shape (rectangle with shadow)
	# Shadow
	var shadow = ColorRect.new()
	shadow.name = "Shadow"
	shadow.size = Vector2(12, 6)
	shadow.position = Vector2(-5, -2)
	shadow.color = Color(0, 0, 0, 0.3)
	vehicle.add_child(shadow)

	# Car body
	var sprite = ColorRect.new()
	sprite.name = "Sprite"
	sprite.size = Vector2(12, 6)
	sprite.position = Vector2(-6, -3)  # Center the sprite
	sprite.color = Color.WHITE
	vehicle.add_child(sprite)

	# Car roof/window (smaller rectangle on top)
	var roof = ColorRect.new()
	roof.name = "Roof"
	roof.size = Vector2(6, 4)
	roof.position = Vector2(-3, -2)
	roof.color = Color(0.2, 0.2, 0.25, 0.8)
	vehicle.add_child(roof)

	return vehicle
