extends Node
class_name BuildingRenderer
## Generates procedural textures for buildings based on type and level

# Cached textures
var texture_cache: Dictionary = {}

# Cache management
const MAX_CACHE_SIZE: int = 500  # Maximum textures to cache
var _cache_access_order: Array[String] = []  # LRU tracking

# Reference to grid system for neighbor checks
var grid_system = null


func _ready() -> void:
	# Add to group so Building entities can find us without static reference
	add_to_group("building_renderer")


func set_grid_system(system) -> void:
	grid_system = system


## Cache a texture with LRU eviction
func _cache_texture(cache_key: String, texture: ImageTexture) -> void:
	# Evict oldest entry if cache is full
	if texture_cache.size() >= MAX_CACHE_SIZE:
		if _cache_access_order.size() > 0:
			var oldest_key = _cache_access_order.pop_front()
			texture_cache.erase(oldest_key)

	texture_cache[cache_key] = texture
	_cache_access_order.append(cache_key)


## Get texture from cache, updating LRU order
func _get_cached_texture(cache_key: String) -> ImageTexture:
	if texture_cache.has(cache_key):
		# Move to end of access order (most recently used)
		_cache_access_order.erase(cache_key)
		_cache_access_order.append(cache_key)
		return texture_cache[cache_key]
	return null


## Get cache statistics
func get_cache_stats() -> Dictionary:
	return {
		"size": texture_cache.size(),
		"max_size": MAX_CACHE_SIZE,
		"hit_rate": 0.0  # Could track this if needed
	}


## Clear the texture cache
func clear_cache() -> void:
	texture_cache.clear()
	_cache_access_order.clear()


func get_building_texture(building_data, development_level: int = 1, grid_cell: Vector2i = Vector2i(-1, -1)) -> ImageTexture:
	var cache_key: String
	var neighbors: Dictionary = {}

	# Determine cache key based on building type
	if building_data.building_type == "road" and grid_cell != Vector2i(-1, -1):
		neighbors = _get_road_neighbors(grid_cell)
		cache_key = "%s_%d_%d_%d_%d_%d" % [building_data.id, development_level, neighbors.north, neighbors.south, neighbors.east, neighbors.west]
	elif building_data.building_type == "power_line" and grid_cell != Vector2i(-1, -1):
		neighbors = _get_road_neighbors(grid_cell)
		cache_key = "%s_%d_%d_%d_%d_%d" % [building_data.id, development_level, neighbors.north, neighbors.south, neighbors.east, neighbors.west]
	elif building_data.building_type == "water_pipe" and grid_cell != Vector2i(-1, -1):
		neighbors = _get_water_pipe_neighbors(grid_cell)
		cache_key = "%s_%d_%d_%d_%d_%d" % [building_data.id, development_level, neighbors.north, neighbors.south, neighbors.east, neighbors.west]
	else:
		cache_key = "%s_%d" % [building_data.id, development_level]

	# Check cache first (with LRU update)
	var cached = _get_cached_texture(cache_key)
	if cached:
		return cached

	# Generate and cache the texture
	var texture = _generate_texture(building_data, development_level, neighbors)
	_cache_texture(cache_key, texture)
	return texture


func _get_road_neighbors(cell: Vector2i) -> Dictionary:
	var neighbors = {"north": 0, "south": 0, "east": 0, "west": 0}
	if not grid_system:
		return neighbors

	# Check each direction for roads
	if grid_system.road_cells.has(cell + Vector2i(0, -1)):
		neighbors.north = 1
	if grid_system.road_cells.has(cell + Vector2i(0, 1)):
		neighbors.south = 1
	if grid_system.road_cells.has(cell + Vector2i(1, 0)):
		neighbors.east = 1
	if grid_system.road_cells.has(cell + Vector2i(-1, 0)):
		neighbors.west = 1

	return neighbors


func _get_water_pipe_neighbors(cell: Vector2i) -> Dictionary:
	# For water pipes, check roads, other water pipes, and water buildings as neighbors
	var neighbors = {"north": 0, "south": 0, "east": 0, "west": 0}
	if not grid_system:
		return neighbors

	var directions = {
		"north": Vector2i(0, -1),
		"south": Vector2i(0, 1),
		"east": Vector2i(1, 0),
		"west": Vector2i(-1, 0)
	}

	for dir_name in directions:
		var neighbor_cell = cell + directions[dir_name]

		# Check for roads
		if grid_system.road_cells.has(neighbor_cell):
			neighbors[dir_name] = 1
			continue

		# Check for buildings (water pipes, water sources, water towers, etc.)
		if grid_system.buildings.has(neighbor_cell):
			var building = grid_system.buildings[neighbor_cell]
			if is_instance_valid(building) and building.building_data:
				var btype = building.building_data.building_type
				# Connect to water pipes and water infrastructure
				if btype == "water_pipe" or btype == "water_source" or btype == "water_tower":
					neighbors[dir_name] = 1
					continue
				# Also connect to any building that produces or consumes water
				if building.building_data.water_production > 0 or building.building_data.water_consumption > 0:
					neighbors[dir_name] = 1
					continue

		# Check for water pipes in utility overlays
		if grid_system.utility_overlays.has(neighbor_cell):
			var overlay = grid_system.utility_overlays[neighbor_cell]
			if is_instance_valid(overlay) and overlay.building_data:
				if overlay.building_data.building_type == "water_pipe":
					neighbors[dir_name] = 1

	return neighbors


func _generate_texture(building_data, level: int, road_neighbors: Dictionary = {}) -> ImageTexture:
	var size = building_data.size
	var width = size.x * GridConstants.CELL_SIZE
	var height = size.y * GridConstants.CELL_SIZE

	var image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var base_color = building_data.color

	# Fill based on building type
	match building_data.building_type:
		"road":
			_draw_road(image, width, height, road_neighbors)
		"power_line":
			_draw_power_line(image, width, height, base_color, road_neighbors)
		"water_pipe":
			_draw_water_pipe(image, width, height, base_color, road_neighbors)
		"generator":
			_draw_power_plant(image, width, height, base_color, building_data.id)
		"water_source":
			_draw_water_facility(image, width, height, base_color, building_data.id)
		"residential":
			_draw_residential(image, width, height, base_color, level)
		"commercial":
			_draw_commercial(image, width, height, base_color, level)
		"industrial":
			_draw_industrial(image, width, height, base_color, level)
		"agricultural":
			_draw_farm(image, width, height, base_color)
		"park":
			_draw_park(image, width, height, base_color, size)
		"data_center":
			_draw_data_center(image, width, height, base_color, building_data.data_center_tier)
		"bus_stop":
			_draw_bus_stop(image, width, height, base_color)
		"bus_depot":
			_draw_bus_depot(image, width, height, base_color)
		"subway_station":
			_draw_subway_station(image, width, height, base_color)
		"rail_station":
			_draw_rail_station(image, width, height, base_color)
		"airport":
			_draw_airport(image, width, height, base_color)
		"seaport":
			_draw_seaport(image, width, height, base_color)
		"landmark":
			_draw_landmark(image, width, height, base_color, building_data.id)
		_:
			# Service buildings and others
			_draw_service_building(image, width, height, base_color, building_data.service_type)

	var texture = ImageTexture.create_from_image(image)
	return texture


func _draw_road(image: Image, w: int, h: int, neighbors: Dictionary = {}) -> void:
	var road_color = Color(0.25, 0.25, 0.28)
	var line_color = Color(0.9, 0.85, 0.3)
	var sidewalk_color = Color(0.45, 0.45, 0.42)

	# Fill with road color
	image.fill(road_color)

	# Determine road configuration
	var has_north = neighbors.get("north", 0) == 1
	var has_south = neighbors.get("south", 0) == 1
	var has_east = neighbors.get("east", 0) == 1
	var has_west = neighbors.get("west", 0) == 1

	var connection_count = int(has_north) + int(has_south) + int(has_east) + int(has_west)
	var has_vertical = has_north or has_south
	var has_horizontal = has_east or has_west

	var cx: int = int(w * 0.5)
	var cy: int = int(h * 0.5)
	var edge_width = 4
	var dash_len = 8
	var gap_len = 6

	# Draw sidewalk/edges where there are no connections
	if not has_north:
		for x in range(w):
			for y in range(edge_width):
				image.set_pixel(x, y, sidewalk_color)

	if not has_south:
		for x in range(w):
			for y in range(edge_width):
				image.set_pixel(x, h - 1 - y, sidewalk_color)

	if not has_west:
		for y in range(h):
			for x in range(edge_width):
				image.set_pixel(x, y, sidewalk_color)

	if not has_east:
		for y in range(h):
			for x in range(edge_width):
				image.set_pixel(w - 1 - x, y, sidewalk_color)

	# Determine road type and draw appropriate lane lines
	if connection_count >= 3:
		# Intersection (3-way or 4-way) - draw crosswalks
		var crosswalk_color = Color(0.9, 0.9, 0.9)
		var stripe_width = 4
		var stripe_gap = 4
		var crosswalk_offset = 8  # Distance from edge

		# Draw crosswalks on sides that have connections
		if has_north:
			# Crosswalk at north edge
			for x in range(crosswalk_offset, w - crosswalk_offset, stripe_width + stripe_gap):
				for dx in range(min(stripe_width, w - crosswalk_offset - x)):
					for y in range(2, 10):
						if x + dx < w and y < h:
							image.set_pixel(x + dx, y, crosswalk_color)

		if has_south:
			# Crosswalk at south edge
			for x in range(crosswalk_offset, w - crosswalk_offset, stripe_width + stripe_gap):
				for dx in range(min(stripe_width, w - crosswalk_offset - x)):
					for y in range(h - 10, h - 2):
						if x + dx < w and y >= 0:
							image.set_pixel(x + dx, y, crosswalk_color)

		if has_west:
			# Crosswalk at west edge
			for y in range(crosswalk_offset, h - crosswalk_offset, stripe_width + stripe_gap):
				for dy in range(min(stripe_width, h - crosswalk_offset - y)):
					for x in range(2, 10):
						if y + dy < h and x < w:
							image.set_pixel(x, y + dy, crosswalk_color)

		if has_east:
			# Crosswalk at east edge
			for y in range(crosswalk_offset, h - crosswalk_offset, stripe_width + stripe_gap):
				for dy in range(min(stripe_width, h - crosswalk_offset - y)):
					for x in range(w - 10, w - 2):
						if y + dy < h and x >= 0:
							image.set_pixel(x, y + dy, crosswalk_color)
	elif has_vertical and has_horizontal and connection_count == 2:
		# Corner piece (2 connections at 90 degrees) - draw curved lane line
		_draw_curved_lane(image, w, h, has_north, has_south, has_east, has_west, line_color)
	elif has_vertical and not has_horizontal:
		# Straight vertical road (north-south) - vertical dashed line
		var start_y = 0 if has_north else edge_width
		var end_y = h if has_south else h - edge_width

		for y in range(start_y, end_y, dash_len + gap_len):
			for dy in range(min(dash_len, end_y - y)):
				if y + dy < end_y:
					for lx in range(cx - 1, cx + 2):
						if lx >= 0 and lx < w:
							image.set_pixel(lx, y + dy, line_color)
	elif has_horizontal and not has_vertical:
		# Straight horizontal road (east-west) - horizontal dashed line
		var start_x = 0 if has_west else edge_width
		var end_x = w if has_east else w - edge_width

		for x in range(start_x, end_x, dash_len + gap_len):
			for dx in range(min(dash_len, end_x - x)):
				if x + dx < end_x:
					for ly in range(cy - 1, cy + 2):
						if ly >= 0 and ly < h:
							image.set_pixel(x + dx, ly, line_color)
	elif connection_count == 1:
		# Dead-end road - draw line toward the connection
		if has_north:
			for y in range(0, cy, dash_len + gap_len):
				for dy in range(min(dash_len, cy - y)):
					for lx in range(cx - 1, cx + 2):
						if lx >= 0 and lx < w:
							image.set_pixel(lx, y + dy, line_color)
		elif has_south:
			for y in range(cy, h, dash_len + gap_len):
				for dy in range(min(dash_len, h - y)):
					for lx in range(cx - 1, cx + 2):
						if lx >= 0 and lx < w:
							image.set_pixel(lx, y + dy, line_color)
		elif has_east:
			for x in range(cx, w, dash_len + gap_len):
				for dx in range(min(dash_len, w - x)):
					for ly in range(cy - 1, cy + 2):
						if ly >= 0 and ly < h:
							image.set_pixel(x + dx, ly, line_color)
		elif has_west:
			for x in range(0, cx, dash_len + gap_len):
				for dx in range(min(dash_len, cx - x)):
					for ly in range(cy - 1, cy + 2):
						if ly >= 0 and ly < h:
							image.set_pixel(x + dx, ly, line_color)
	else:
		# Isolated tile (no connections) - draw crosshatch pattern
		var edge_col = Color(0.35, 0.35, 0.38)
		for x in range(w):
			for y in range(h):
				if (x + y) % 16 < 2:
					image.set_pixel(x, y, edge_col)


func _draw_power_line(image: Image, w: int, h: int, _base_color: Color, neighbors: Dictionary = {}) -> void:
	image.fill(Color(0, 0, 0, 0))  # Transparent background

	# Improved visibility: brighter pole and wire colors
	var pole_color = Color(0.55, 0.48, 0.35)
	var wire_color = Color(0.35, 0.35, 0.38)
	var wire_highlight = Color(0.45, 0.45, 0.50)  # Slight glow effect

	var cx: int = int(w * 0.5)
	var cy: int = int(h * 0.5)

	# Determine orientation based on road neighbors
	var has_north = neighbors.get("north", 0) == 1
	var has_south = neighbors.get("south", 0) == 1
	var has_east = neighbors.get("east", 0) == 1
	var has_west = neighbors.get("west", 0) == 1

	var has_vertical = has_north or has_south
	var has_horizontal = has_east or has_west

	# Draw wires based on road direction
	# For vertical roads (north-south): wires run vertically
	# For horizontal roads (east-west): wires run horizontally
	var is_vertical_road = has_vertical and not has_horizontal

	# Draw pole base (small square in center - top-down view of pole)
	for x in range(cx - 5, cx + 6):
		for y in range(cy - 5, cy + 6):
			if x >= 0 and x < w and y >= 0 and y < h:
				image.set_pixel(x, y, pole_color)

	if is_vertical_road:
		# Vertical road: wires run north-south, crossbar runs east-west
		# Draw horizontal crossbar (perpendicular to wires)
		for x in range(cx - 16, cx + 17):
			for y in range(cy - 3, cy + 4):
				if x >= 0 and x < w and y >= 0 and y < h:
					image.set_pixel(x, y, pole_color)

		# Draw vertical wires (running north-south) - 2px width with highlight
		for y in range(h):
			for x_offset in [cx - 12, cx + 12]:
				for lw in range(-1, 2):  # 3px width for visibility
					var px = x_offset + lw
					if px >= 0 and px < w:
						var c = wire_highlight if lw == 0 else wire_color
						image.set_pixel(px, y, c)
	else:
		# Horizontal road (or intersection): wires run east-west, crossbar runs north-south
		# Draw vertical crossbar (perpendicular to wires)
		for y in range(cy - 16, cy + 17):
			for x in range(cx - 3, cx + 4):
				if x >= 0 and x < w and y >= 0 and y < h:
					image.set_pixel(x, y, pole_color)

		# Draw horizontal wires (running east-west) - 2px width with highlight
		for x in range(w):
			for y_offset in [cy - 12, cy + 12]:
				for lw in range(-1, 2):  # 3px width for visibility
					var py = y_offset + lw
					if py >= 0 and py < h:
						var c = wire_highlight if lw == 0 else wire_color
						image.set_pixel(x, py, c)


func _draw_water_pipe(image: Image, w: int, h: int, _base_color: Color, neighbors: Dictionary = {}) -> void:
	image.fill(Color(0, 0, 0, 0))  # Transparent

	# Cyan color scheme for better visibility on blue water tiles
	var pipe_color = Color(0.25, 0.72, 0.85)
	var highlight = Color(0.40, 0.85, 0.95)
	var shadow = Color(0.18, 0.55, 0.68)

	var cx: int = int(w * 0.5)
	var cy: int = int(h * 0.5)
	var pipe_radius: int = 9

	# Determine connections
	var has_north = neighbors.get("north", 0) == 1
	var has_south = neighbors.get("south", 0) == 1
	var has_east = neighbors.get("east", 0) == 1
	var has_west = neighbors.get("west", 0) == 1

	var has_vertical = has_north or has_south
	var has_horizontal = has_east or has_west

	# Draw pipe segments based on connections
	# North segment
	if has_north:
		for y in range(0, cy + pipe_radius):
			for x in range(cx - pipe_radius, cx + pipe_radius + 1):
				if x >= 0 and x < w and y >= 0 and y < h:
					var dist = abs(x - cx)
					var c = _get_pipe_color(dist, pipe_radius, highlight, pipe_color, shadow)
					image.set_pixel(x, y, c)

	# South segment
	if has_south:
		for y in range(cy - pipe_radius, h):
			for x in range(cx - pipe_radius, cx + pipe_radius + 1):
				if x >= 0 and x < w and y >= 0 and y < h:
					var dist = abs(x - cx)
					var c = _get_pipe_color(dist, pipe_radius, highlight, pipe_color, shadow)
					image.set_pixel(x, y, c)

	# East segment
	if has_east:
		for x in range(cx - pipe_radius, w):
			for y in range(cy - pipe_radius, cy + pipe_radius + 1):
				if x >= 0 and x < w and y >= 0 and y < h:
					var dist = abs(y - cy)
					var c = _get_pipe_color(dist, pipe_radius, highlight, pipe_color, shadow)
					image.set_pixel(x, y, c)

	# West segment
	if has_west:
		for x in range(0, cx + pipe_radius):
			for y in range(cy - pipe_radius, cy + pipe_radius + 1):
				if x >= 0 and x < w and y >= 0 and y < h:
					var dist = abs(y - cy)
					var c = _get_pipe_color(dist, pipe_radius, highlight, pipe_color, shadow)
					image.set_pixel(x, y, c)

	# If no connections, draw horizontal by default
	if not has_vertical and not has_horizontal:
		for x in range(w):
			for y in range(cy - pipe_radius, cy + pipe_radius + 1):
				if y >= 0 and y < h:
					var dist = abs(y - cy)
					var c = _get_pipe_color(dist, pipe_radius, highlight, pipe_color, shadow)
					image.set_pixel(x, y, c)

	# Draw center junction if needed (for corners and intersections)
	if has_vertical and has_horizontal:
		for x in range(cx - pipe_radius, cx + pipe_radius + 1):
			for y in range(cy - pipe_radius, cy + pipe_radius + 1):
				if x >= 0 and x < w and y >= 0 and y < h:
					var dist = min(abs(x - cx), abs(y - cy))
					var c = _get_pipe_color(dist, pipe_radius, highlight, pipe_color, shadow)
					image.set_pixel(x, y, c)


func _get_pipe_color(dist: int, radius: int, highlight: Color, pipe_color: Color, shadow: Color) -> Color:
	if dist <= 2:
		return highlight
	elif dist <= 5:
		return pipe_color
	else:
		return shadow


func _draw_power_plant(image: Image, w: int, h: int, base_color: Color, id: String) -> void:
	# Background
	_fill_with_gradient(image, w, h, base_color.darkened(0.2), base_color)

	if "coal" in id:
		_draw_coal_plant(image, w, h, base_color)
	elif "gas" in id:
		_draw_gas_plant(image, w, h, base_color)
	elif "oil" in id:
		_draw_oil_plant(image, w, h, base_color)
	elif "nuclear" in id:
		_draw_nuclear_plant(image, w, h, base_color)
	elif "wind_turbine" in id:
		_draw_wind_turbine(image, w, h, base_color)
	elif "wind_farm" in id:
		_draw_wind_farm(image, w, h, base_color)
	elif "solar_plant" in id:
		_draw_solar_plant(image, w, h, base_color)
	elif "solar_farm" in id:
		_draw_solar_farm(image, w, h, base_color)
	elif "battery" in id:
		_draw_battery_farm(image, w, h, base_color)
	else:
		# Generic power plant
		var building_color = base_color.darkened(0.1)
		_draw_rect(image, 8, h - 45, w - 16, 40, building_color)

	# Border
	_draw_rect_outline(image, 2, 2, w - 4, h - 4, base_color.lightened(0.2))


func _draw_coal_plant(image: Image, w: int, h: int, _base_color: Color) -> void:
	# Coal: Industrial gray-brown - visible but still industrial
	var building_color = Color(0.40, 0.38, 0.35)
	var stack_color = Color(0.50, 0.47, 0.42)
	var smoke_color = Color(0.55, 0.52, 0.48, 0.85)  # Lighter smoke for visibility

	# Main building
	_draw_rect(image, 10, int(h * 0.5), w - 20, int(h * 0.5) - 10, building_color)
	_draw_rect(image, 15, int(h * 0.5) - 20, int(w / 3.0), int(h * 0.5) + 10, building_color.darkened(0.1))

	# Smokestacks (3 of them for 4x4)
	var stack_positions = [int(w * 0.25), int(w * 0.5), 3*int(w * 0.25)]
	for i in range(3):
		var sx = stack_positions[i] - 8
		_draw_rect(image, sx, 15, 16, int(h * 0.5) - 10, stack_color)
		# Smoke puffs
		_draw_circle(image, sx + 8, 12, 10, smoke_color)
		_draw_circle(image, sx + 12, 8, 7, smoke_color.lightened(0.1))

	# Coal pile
	_draw_rect(image, w - 60, h - 40, 45, 25, Color(0.25, 0.23, 0.20))


func _draw_gas_plant(image: Image, w: int, h: int, _base_color: Color) -> void:
	# Gas: Clean blue-gray steel - modern industrial look
	var building_color = Color(0.50, 0.55, 0.62)
	var turbine_color = Color(0.62, 0.68, 0.75)

	# Main building
	_draw_rect(image, 15, int(h / 3.0), w - 30, int(h * 2.0 / 3.0) - 15, building_color)

	# Gas turbines (cylindrical shapes)
	for i in range(2):
		var tx = 30 + i * (int(w * 0.5) - 20)
		_draw_rect(image, tx, int(h * 0.25), int(w / 3.0) - 20, int(h * 0.25), turbine_color)
		_draw_rect(image, tx + 5, int(h * 0.25) - 10, int(w / 3.0) - 30, 15, turbine_color.lightened(0.1))

	# Small exhaust stack
	_draw_rect(image, w - 40, 20, 12, int(h / 3.0), Color(0.5, 0.5, 0.52))


func _draw_oil_plant(image: Image, w: int, h: int, _base_color: Color) -> void:
	# Oil: Dark rusty brown - petroleum industrial aesthetic
	var building_color = Color(0.30, 0.22, 0.18)
	var tank_color = Color(0.42, 0.32, 0.25)
	var stack_color = Color(0.38, 0.30, 0.22)

	# Main building
	_draw_rect(image, 10, int(h * 0.5), int(w * 0.5) - 10, int(h * 0.5) - 10, building_color)

	# Oil storage tanks (cylindrical)
	_draw_circle(image, 3*int(w * 0.25), int(h * 0.5) + 20, 35, tank_color)
	_draw_circle(image, 3*int(w * 0.25) - 40, int(h * 0.5) + 35, 25, tank_color.darkened(0.1))

	# Smokestacks
	_draw_rect(image, 20, 15, 18, int(h * 0.5) - 10, stack_color)
	_draw_rect(image, 50, 25, 14, int(h * 0.5) - 20, stack_color)

	# Smoke
	var smoke_color = Color(0.4, 0.4, 0.4, 0.6)
	_draw_circle(image, 29, 12, 12, smoke_color)


func _draw_nuclear_plant(image: Image, w: int, h: int, _base_color: Color) -> void:
	# Nuclear: Light blue-gray concrete - distinctive clean energy look
	var building_color = Color(0.72, 0.75, 0.80)
	var dome_color = Color(0.78, 0.82, 0.88)
	var tower_color = Color(0.68, 0.72, 0.78)

	# Main building
	_draw_rect(image, 20, int(h * 0.5), w - 40, int(h * 0.5) - 15, building_color)

	# Reactor domes (2 of them)
	_draw_circle(image, int(w / 3.0), int(h * 0.5) - 5, 40, dome_color)
	_draw_circle(image, int(w * 2.0 / 3.0), int(h * 0.5) - 5, 40, dome_color)

	# Cooling towers (iconic hyperbolic shape approximation)
	var tower_x1 = w - 55
	var tower_x2 = 25
	for tx in [tower_x1, tower_x2]:
		# Draw cooling tower shape
		for y in range(15, int(h * 0.5) + 20):
			var t = float(y - 15) / float(int(h * 0.5))
			var tower_width = int(15 + 10 * (t * t - t + 0.5))
			for x in range(-tower_width, tower_width + 1):
				var px = tx + x
				if px >= 0 and px < w and y >= 0 and y < h:
					image.set_pixel(px, y, tower_color)

	# Steam from cooling towers
	var steam_color = Color(0.9, 0.9, 0.95, 0.5)
	_draw_circle(image, tower_x1, 10, 15, steam_color)
	_draw_circle(image, tower_x2, 12, 12, steam_color)


func _draw_wind_turbine(image: Image, w: int, h: int, _base_color: Color) -> void:
	image.fill(Color(0, 0, 0, 0))  # Transparent background

	var pole_color = Color(0.85, 0.85, 0.88)
	var blade_color = Color(0.9, 0.9, 0.92)

	var cx: int = int(w * 0.5)
	var hub_y = 15

	# Tower/pole
	for y in range(hub_y, h - 5):
		var tower_width = 2 + int((float(y - hub_y) / float(h - hub_y - 5)) * 3)
		for x in range(-tower_width, tower_width + 1):
			if cx + x >= 0 and cx + x < w:
				image.set_pixel(cx + x, y, pole_color)

	# Hub
	_draw_circle(image, cx, hub_y, 4, Color(0.7, 0.7, 0.72))

	# Blades (3 blades at 120 degree angles)
	var blade_length = 22
	var angles = [270, 30, 150]  # degrees
	for angle in angles:
		var rad = deg_to_rad(angle)
		for i in range(blade_length):
			var bx = cx + int(cos(rad) * i)
			var by = hub_y + int(sin(rad) * i)
			var blade_width = 2 if i < int(blade_length * 0.5) else 1
			for bw in range(-blade_width, blade_width + 1):
				var px = bx + int(sin(rad) * bw)
				var py = by - int(cos(rad) * bw)
				if px >= 0 and px < w and py >= 0 and py < h:
					image.set_pixel(px, py, blade_color)


func _draw_wind_farm(image: Image, w: int, h: int, _base_color: Color) -> void:
	# Light ground
	_fill_with_gradient(image, w, h, Color(0.75, 0.8, 0.75), Color(0.7, 0.75, 0.7))

	var pole_color = Color(0.85, 0.85, 0.88)
	var blade_color = Color(0.92, 0.92, 0.95)

	# Draw 4 turbines in a grid
	var positions = [
		Vector2i(int(w * 0.25), int(h * 0.25)),
		Vector2i(3*int(w * 0.25), int(h * 0.25)),
		Vector2i(int(w * 0.25), 3*int(h * 0.25)),
		Vector2i(3*int(w * 0.25), 3*int(h * 0.25))
	]

	for pos in positions:
		var cx = pos.x
		var cy = pos.y
		var hub_y = cy - 15
		var ground_y = cy + 15

		# Tower
		for y in range(hub_y, ground_y):
			var tw = 1 + int((float(y - hub_y) / float(ground_y - hub_y)) * 2)
			for x in range(-tw, tw + 1):
				if cx + x >= 0 and cx + x < w and y >= 0 and y < h:
					image.set_pixel(cx + x, y, pole_color)

		# Hub and blades
		_draw_circle(image, cx, hub_y, 3, Color(0.7, 0.7, 0.72))
		var blade_length = 12
		var angles = [270, 30, 150]
		for angle in angles:
			var rad = deg_to_rad(angle)
			for i in range(blade_length):
				var bx = cx + int(cos(rad) * i)
				var by = hub_y + int(sin(rad) * i)
				if bx >= 0 and bx < w and by >= 0 and by < h:
					image.set_pixel(bx, by, blade_color)

	_draw_rect_outline(image, 2, 2, w - 4, h - 4, Color(0.6, 0.65, 0.6, 0.5))


func _draw_solar_plant(image: Image, w: int, h: int, _base_color: Color) -> void:
	# Ground
	_fill_with_gradient(image, w, h, Color(0.65, 0.6, 0.5), Color(0.6, 0.55, 0.45))

	var panel_color = Color(0.15, 0.2, 0.4)
	var frame_color = Color(0.5, 0.5, 0.55)
	var cell_color = Color(0.1, 0.15, 0.35)

	# Grid of solar panels
	var panel_w = int((w - 30) / 5.0)
	var panel_h = int((h - 30) / 5.0)
	for row in range(5):
		for col in range(5):
			var px = 12 + col * (panel_w + 2)
			var py = 12 + row * (panel_h + 2)
			_draw_rect(image, px, py, panel_w, panel_h, panel_color)
			_draw_rect_outline(image, px, py, panel_w, panel_h, frame_color)
			# Cell lines
			_draw_rect(image, px + int(panel_w * 0.5), py + 2, 1, panel_h - 4, cell_color)


func _draw_solar_farm(image: Image, w: int, h: int, _base_color: Color) -> void:
	# Ground
	_fill_with_gradient(image, w, h, Color(0.55, 0.5, 0.4), Color(0.5, 0.45, 0.35))

	var panel_color = Color(0.12, 0.18, 0.38)
	var frame_color = Color(0.45, 0.45, 0.5)

	# Rows of tilted panels
	var panel_w = int((w - 20) / 4.0)
	var panel_h = int((h - 25) / 4.0)
	for row in range(4):
		for col in range(4):
			var px = 8 + col * (panel_w + 2)
			var py = 10 + row * (panel_h + 3)
			_draw_rect(image, px, py, panel_w, panel_h, panel_color)
			_draw_rect(image, px, py, panel_w, 3, frame_color)  # Top edge highlight


func _draw_battery_farm(image: Image, w: int, h: int, _base_color: Color) -> void:
	# Concrete pad
	_fill_with_gradient(image, w, h, Color(0.5, 0.5, 0.48), Color(0.45, 0.45, 0.43))

	var container_color = Color(0.3, 0.65, 0.4)
	var accent_color = Color(0.2, 0.5, 0.3)
	var vent_color = Color(0.25, 0.25, 0.28)

	# Battery containers (shipping container style)
	var container_w = int((w - 20) * 0.5)
	var container_h: int = int((h - 20) * 0.5)

	for row in range(2):
		for col in range(2):
			var cx = 8 + col * (container_w + 4)
			var cy = 8 + row * (container_h + 4)
			_draw_rect(image, cx, cy, container_w, container_h, container_color)
			_draw_rect(image, cx, cy, container_w, 6, accent_color)  # Top stripe
			# Vents
			for v in range(3):
				_draw_rect(image, cx + 5 + v * 12, cy + container_h - 15, 8, 10, vent_color)

	# Status LEDs
	var led_color = Color(0.2, 0.9, 0.3)
	_draw_rect(image, int(w * 0.5) - 10, int(h * 0.5) - 3, 4, 4, led_color)
	_draw_rect(image, int(w * 0.5) + 6, int(h * 0.5) - 3, 4, 4, led_color)


func _draw_water_facility(image: Image, w: int, h: int, base_color: Color, id: String) -> void:
	_fill_with_gradient(image, w, h, base_color.darkened(0.2), base_color)

	if "tower" in id:
		# Water tower - cylindrical tank on legs
		var tank_color = Color(0.5, 0.6, 0.7)
		var leg_color = Color(0.4, 0.4, 0.42)

		# Legs
		_draw_rect(image, 15, h - 30, 6, 25, leg_color)
		_draw_rect(image, w - 21, h - 30, 6, 25, leg_color)

		# Tank
		_draw_rect(image, 8, 10, w - 16, 30, tank_color)
		_draw_rect(image, 6, 8, w - 12, 6, tank_color.lightened(0.1))
	else:
		# Treatment plant - rectangular with pools
		var building_col = base_color.darkened(0.1)
		var pool_col = Color(0.3, 0.5, 0.7)

		_draw_rect(image, 8, 8, w - 16, int(h / 3.0), building_col)

		# Pools
		_draw_rect(image, 12, int(h / 3.0) + 8, int(w * 0.5) - 16, int(h * 0.5) - 8, pool_col)
		_draw_rect(image, int(w * 0.5) + 4, int(h / 3.0) + 8, int(w * 0.5) - 16, int(h * 0.5) - 8, pool_col)

	_draw_rect_outline(image, 2, 2, w - 4, h - 4, base_color.lightened(0.2))


func _draw_residential(image: Image, w: int, h: int, base_color: Color, level: int) -> void:
	_fill_with_gradient(image, w, h, Color(0.25, 0.35, 0.2), Color(0.3, 0.4, 0.25))

	var house_color = base_color
	var roof_color = base_color.darkened(0.3)
	var window_color = Color(0.9, 0.85, 0.5)

	match level:
		1:
			# Small houses
			_draw_house(image, 10, h - 40, 25, 30, house_color, roof_color, window_color)
			if w > 80:
				_draw_house(image, w - 35, h - 35, 25, 25, house_color.darkened(0.05), roof_color, window_color)
		2:
			# Medium apartments
			_draw_rect(image, 8, 15, w - 16, h - 25, house_color)
			_draw_rect(image, 8, 10, w - 16, 8, roof_color)
			# Windows grid
			for row in range(3):
				for col in range(3):
					_draw_rect(image, 15 + col * 25, 25 + row * 20, 8, 10, window_color)
		3:
			# High-rise
			_draw_rect(image, 12, 8, w - 24, h - 15, house_color)
			_draw_rect(image, 10, 5, w - 20, 6, roof_color)
			# Many windows
			for row in range(5):
				for col in range(4):
					_draw_rect(image, 18 + col * 20, 15 + row * 18, 6, 8, window_color)

	_draw_rect_outline(image, 2, 2, w - 4, h - 4, Color(0.2, 0.3, 0.15, 0.5))


func _draw_commercial(image: Image, w: int, h: int, base_color: Color, level: int) -> void:
	_fill_with_gradient(image, w, h, Color(0.3, 0.3, 0.35), Color(0.35, 0.35, 0.4))

	var building_color = base_color
	var window_color = Color(0.7, 0.85, 0.95)
	var sign_color = Color(0.9, 0.3, 0.3)

	match level:
		1:
			# Small shop
			_draw_rect(image, 10, h - 45, w - 20, 40, building_color)
			_draw_rect(image, 15, h - 40, w - 30, 20, window_color)
			_draw_rect(image, 20, h - 50, w - 40, 8, sign_color)
		2:
			# Medium store
			_draw_rect(image, 8, 20, w - 16, h - 28, building_color)
			for col in range(3):
				_draw_rect(image, 15 + col * 30, 30, 20, 25, window_color)
			_draw_rect(image, 12, 15, w - 24, 8, sign_color)
		3:
			# Large mall
			_draw_rect(image, 6, 12, w - 12, h - 18, building_color)
			# Glass facade
			_draw_rect(image, 10, 20, w - 20, h - 35, window_color.darkened(0.1))
			# Entrance
			_draw_rect(image, int(w * 0.5) - 15, h - 30, 30, 25, Color(0.2, 0.2, 0.25))
			_draw_rect(image, 10, 8, w - 20, 10, sign_color)

	_draw_rect_outline(image, 2, 2, w - 4, h - 4, base_color.lightened(0.2))


func _draw_industrial(image: Image, w: int, h: int, base_color: Color, level: int) -> void:
	_fill_with_gradient(image, w, h, Color(0.35, 0.32, 0.25), Color(0.4, 0.35, 0.28))

	var building_color = base_color
	var metal_color = Color(0.5, 0.5, 0.52)

	match level:
		1:
			# Small factory
			_draw_rect(image, 8, h - 40, w - 16, 35, building_color)
			# Smokestack
			_draw_rect(image, w - 25, 15, 10, h - 50, metal_color)
		2:
			# Warehouse
			_draw_rect(image, 6, 15, w - 12, h - 22, building_color)
			# Roof ridges
			for i in range(3):
				_draw_triangle_roof(image, 8 + i * 35, 15, 30, 12, metal_color)
			# Loading door
			_draw_rect(image, 15, h - 35, 25, 28, Color(0.3, 0.3, 0.32))
		3:
			# Large plant
			_draw_rect(image, 5, 20, w - 10, h - 26, building_color)
			# Multiple stacks
			for i in range(3):
				_draw_rect(image, 12 + i * 35, 5, 12, 20, metal_color)
			# Windows
			for col in range(5):
				_draw_rect(image, 12 + col * 22, 30, 15, 10, Color(0.6, 0.6, 0.4))

	_draw_rect_outline(image, 2, 2, w - 4, h - 4, base_color.lightened(0.15))


func _draw_park(image: Image, w: int, h: int, _base_color: Color, size: Vector2i) -> void:
	# Grass background
	_fill_with_gradient(image, w, h, Color(0.2, 0.5, 0.25), Color(0.25, 0.55, 0.3))

	var tree_color = Color(0.15, 0.45, 0.2)
	var trunk_color = Color(0.4, 0.3, 0.2)
	var path_color = Color(0.55, 0.5, 0.4)

	# Draw path
	_draw_rect(image, int(w * 0.5) - 4, 0, 8, h, path_color)
	if size.x > 1:
		_draw_rect(image, 0, int(h * 0.5) - 4, w, 8, path_color)

	# Draw trees
	if size.x == 1:
		_draw_tree(image, int(w * 0.5), int(h / 3.0), 12, tree_color, trunk_color)
	else:
		_draw_tree(image, int(w * 0.25), int(h * 0.25), 15, tree_color, trunk_color)
		_draw_tree(image, 3*int(w * 0.25), int(h * 0.25), 18, tree_color.darkened(0.1), trunk_color)
		_draw_tree(image, int(w * 0.25), 3*int(h * 0.25), 16, tree_color.lightened(0.05), trunk_color)
		_draw_tree(image, 3*int(w * 0.25), 3*int(h * 0.25), 14, tree_color, trunk_color)

	_draw_rect_outline(image, 1, 1, w - 2, h - 2, Color(0.3, 0.5, 0.35, 0.5))


func _draw_data_center(image: Image, w: int, h: int, base_color: Color, tier: int) -> void:
	_fill_with_gradient(image, w, h, base_color.darkened(0.3), base_color.darkened(0.1))

	var building_color = base_color
	var accent_color = Color(0.2, 0.7, 0.8)
	var led_color = Color(0.2, 0.9, 0.4)

	# Main building
	_draw_rect(image, 6, 10, w - 12, h - 16, building_color)

	# Server rack indicators (LED lights)
	var rows = 2 + tier
	var cols = 3 + tier
	for row in range(rows):
		for col in range(cols):
			var lx: int = 15 + int(col * (w - 30) / float(cols))
			var ly: int = 20 + int(row * (h - 40) / float(rows))
			_draw_rect(image, lx, ly, 3, 3, led_color)

	# Accent stripes
	_draw_rect(image, 6, h - 12, w - 12, 4, accent_color)
	_draw_rect(image, 6, 10, w - 12, 3, accent_color)

	# Tier indicator
	for i in range(tier):
		_draw_rect(image, 10 + i * 8, h - 20, 5, 5, accent_color)

	_draw_rect_outline(image, 4, 8, w - 8, h - 12, accent_color.darkened(0.2))


func _draw_service_building(image: Image, w: int, h: int, base_color: Color, service_type: String) -> void:
	_fill_with_gradient(image, w, h, base_color.darkened(0.2), base_color)

	var building_color = base_color.lightened(0.1)
	var accent_color: Color

	match service_type:
		"fire":
			accent_color = Color(0.9, 0.2, 0.1)
			_draw_rect(image, 8, 15, w - 16, h - 22, building_color)
			# Garage door
			_draw_rect(image, 15, h - 35, w - 30, 28, Color(0.8, 0.15, 0.1))
			# Siren
			_draw_circle(image, int(w * 0.5), 10, 6, accent_color)
		"police":
			accent_color = Color(0.2, 0.3, 0.8)
			_draw_rect(image, 8, 12, w - 16, h - 18, building_color)
			# Badge/star shape hint
			_draw_rect(image, int(w * 0.5) - 8, 8, 16, 16, accent_color)
			# Entrance
			_draw_rect(image, int(w * 0.5) - 12, h - 30, 24, 25, Color(0.3, 0.3, 0.35))
		"education":
			accent_color = Color(0.8, 0.7, 0.2)
			_draw_rect(image, 10, 20, w - 20, h - 28, building_color)
			# Bell tower
			_draw_rect(image, int(w * 0.5) - 8, 8, 16, 15, building_color.darkened(0.1))
			# Windows
			for col in range(3):
				_draw_rect(image, 18 + col * 28, 30, 15, 12, Color(0.7, 0.8, 0.9))
		_:
			accent_color = base_color.lightened(0.3)
			_draw_rect(image, 10, 15, w - 20, h - 22, building_color)

	_draw_rect_outline(image, 3, 3, w - 6, h - 6, accent_color)


# Helper drawing functions (optimized for performance)
func _fill_with_gradient(image: Image, w: int, h: int, top_color: Color, bottom_color: Color) -> void:
	# Use fill_rect for horizontal bands (much faster than pixel-by-pixel)
	var band_height: int = maxi(1, int(h / 16.0))  # Divide into ~16 bands for smooth gradient
	for band in range(0, h, band_height):
		var t = float(band + int(band_height * 0.5)) / float(h)
		var color = top_color.lerp(bottom_color, t)
		var band_h = mini(band_height, h - band)
		image.fill_rect(Rect2i(0, band, w, band_h), color)


func _draw_rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	# Clamp to image bounds
	var img_w = image.get_width()
	var img_h = image.get_height()
	var x1 = maxi(0, x)
	var y1 = maxi(0, y)
	var x2 = mini(img_w, x + w)
	var y2 = mini(img_h, y + h)
	if x2 > x1 and y2 > y1:
		image.fill_rect(Rect2i(x1, y1, x2 - x1, y2 - y1), color)


func _draw_rect_outline(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for px in range(x, x + w):
		if px >= 0 and px < image.get_width():
			if y >= 0 and y < image.get_height():
				image.set_pixel(px, y, color)
			if y + h - 1 >= 0 and y + h - 1 < image.get_height():
				image.set_pixel(px, y + h - 1, color)
	for py in range(y, y + h):
		if py >= 0 and py < image.get_height():
			if x >= 0 and x < image.get_width():
				image.set_pixel(x, py, color)
			if x + w - 1 >= 0 and x + w - 1 < image.get_width():
				image.set_pixel(x + w - 1, py, color)


func _draw_circle(image: Image, cx: int, cy: int, radius: int, color: Color) -> void:
	for x in range(cx - radius, cx + radius + 1):
		for y in range(cy - radius, cy + radius + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= radius * radius:
				if x >= 0 and x < image.get_width() and y >= 0 and y < image.get_height():
					image.set_pixel(x, y, color)


func _draw_house(image: Image, x: int, y: int, w: int, h: int, wall_color: Color, roof_color: Color, window_color: Color) -> void:
	# Walls
	_draw_rect(image, x, y + int(h / 3.0), w, h - int(h / 3.0), wall_color)
	# Roof
	_draw_triangle_roof(image, x, y + int(h / 3.0), w, int(h / 3.0), roof_color)
	# Window
	_draw_rect(image, x + int(w / 3.0), y + int(h * 0.5), int(w * 0.25), int(h * 0.25), window_color)
	# Door
	_draw_rect(image, x + int(w * 0.5), y + h - int(h / 3.0), int(w * 0.25), int(h / 3.0), wall_color.darkened(0.3))


func _draw_triangle_roof(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for row in range(h):
		var half_width = int((1.0 - float(row) / float(h)) * int(w * 0.5))
		var cx = x + int(w * 0.5)
		for px in range(cx - half_width, cx + half_width + 1):
			if px >= 0 and px < image.get_width() and y + row >= 0 and y + row < image.get_height():
				image.set_pixel(px, y + row, color)


func _draw_tree(image: Image, cx: int, cy: int, size: int, leaf_color: Color, trunk_color: Color) -> void:
	# Trunk
	_draw_rect(image, cx - 2, cy, 4, size, trunk_color)
	# Foliage (circle)
	_draw_circle(image, cx, cy - int(size * 0.5), int(size * 0.5) + 2, leaf_color)


func _draw_curved_lane(image: Image, w: int, h: int, has_north: bool, has_south: bool, has_east: bool, has_west: bool, line_color: Color) -> void:
	var radius = int(w * 0.5)
	var dash_len = 8
	var line_width = 3

	# Determine which corner this is and draw appropriate curve
	if has_north and has_east:
		# Corner: north to east (bottom-left quadrant of circle centered at top-right)
		_draw_corner_arc(image, w, 0, radius, 90.0, 180.0, line_color, line_width, dash_len)
	elif has_north and has_west:
		# Corner: north to west (bottom-right quadrant of circle centered at top-left)
		_draw_corner_arc(image, 0, 0, radius, 0.0, 90.0, line_color, line_width, dash_len)
	elif has_south and has_east:
		# Corner: south to east (top-left quadrant of circle centered at bottom-right)
		_draw_corner_arc(image, w, h, radius, 180.0, 270.0, line_color, line_width, dash_len)
	elif has_south and has_west:
		# Corner: south to west (top-right quadrant of circle centered at bottom-left)
		_draw_corner_arc(image, 0, h, radius, 270.0, 360.0, line_color, line_width, dash_len)


func _draw_corner_arc(image: Image, corner_x: int, corner_y: int, radius: int, start_deg: float, end_deg: float, color: Color, width: int, dash_len: int) -> void:
	var steps = 32
	var dash_on = true
	var dash_counter = 0

	for i in range(steps + 1):
		var t = float(i) / float(steps)
		var angle = deg_to_rad(start_deg + t * (end_deg - start_deg))
		var px = corner_x + cos(angle) * radius
		var py = corner_y + sin(angle) * radius

		# Dashing logic
		dash_counter += 1
		if dash_counter >= int(dash_len * 0.5):
			dash_counter = 0
			dash_on = not dash_on

		if dash_on:
			# Draw a small circle at this point for line width
			var half_width: int = int(width * 0.5)
			for dx in range(-half_width, half_width + 1):
				for dy in range(-half_width, half_width + 1):
					var ix = int(px) + dx
					var iy = int(py) + dy
					if ix >= 0 and ix < image.get_width() and iy >= 0 and iy < image.get_height():
						if dx*dx + dy*dy <= half_width * half_width + 1:
							image.set_pixel(ix, iy, color)


# New building type renderers

func _draw_farm(image: Image, w: int, h: int, _base_color: Color) -> void:
	# Field background
	_fill_with_gradient(image, w, h, Color(0.6, 0.55, 0.25), Color(0.55, 0.5, 0.2))

	# Crop rows
	var row_color = Color(0.4, 0.55, 0.25)
	for row in range(0, h, 12):
		_draw_rect(image, 10, row, w - 20, 6, row_color)

	# Farmhouse
	var house_color = Color(0.7, 0.5, 0.3)
	_draw_rect(image, 10, 10, 40, 35, house_color)
	_draw_triangle_roof(image, 8, 10, 44, 20, Color(0.5, 0.3, 0.2))

	# Barn
	var barn_color = Color(0.6, 0.2, 0.15)
	_draw_rect(image, w - 60, 15, 50, 45, barn_color)
	_draw_rect(image, w - 55, 35, 20, 25, Color(0.3, 0.15, 0.1))  # Door

	_draw_rect_outline(image, 2, 2, w - 4, h - 4, Color(0.5, 0.45, 0.2, 0.5))


func _draw_bus_stop(image: Image, w: int, h: int, base_color: Color) -> void:
	# Sidewalk background
	image.fill(Color(0.5, 0.5, 0.48))

	# Shelter
	var shelter_color = Color(0.3, 0.5, 0.3)
	_draw_rect(image, 10, 15, w - 20, 35, shelter_color)
	_draw_rect(image, 12, 40, w - 24, 15, Color(0.2, 0.2, 0.22))  # Bench

	# Bus sign
	_draw_rect(image, int(w * 0.5) - 3, 5, 6, 25, Color(0.4, 0.4, 0.42))
	_draw_circle(image, int(w * 0.5), 8, 6, Color(0.2, 0.6, 0.3))

	_draw_rect_outline(image, 2, 2, w - 4, h - 4, base_color)


func _draw_bus_depot(image: Image, w: int, h: int, base_color: Color) -> void:
	_fill_with_gradient(image, w, h, Color(0.4, 0.4, 0.38), Color(0.35, 0.35, 0.33))

	# Main building
	var building_color = Color(0.3, 0.5, 0.35)
	_draw_rect(image, 10, 10, w - 20, int(h * 0.5), building_color)

	# Bus bays
	var bay_color = Color(0.25, 0.25, 0.28)
	for i in range(3):
		_draw_rect(image, 15 + i * 35, int(h * 0.5) + 10, 30, 40, bay_color)

	# Buses
	var bus_color = Color(0.2, 0.5, 0.25)
	_draw_rect(image, 20, int(h * 0.5) + 15, 20, 30, bus_color)
	_draw_rect(image, 90, int(h * 0.5) + 20, 20, 25, bus_color)

	_draw_rect_outline(image, 2, 2, w - 4, h - 4, base_color.lightened(0.2))


func _draw_subway_station(image: Image, w: int, h: int, _base_color: Color) -> void:
	_fill_with_gradient(image, w, h, Color(0.35, 0.35, 0.45), Color(0.3, 0.3, 0.4))

	# Station entrance building
	var building_color = Color(0.4, 0.4, 0.55)
	_draw_rect(image, 15, 15, w - 30, h - 30, building_color)

	# Entrance stairs (going down)
	var stair_color = Color(0.25, 0.25, 0.3)
	_draw_rect(image, int(w * 0.5) - 20, int(h * 0.5) - 10, 40, 35, stair_color)

	# Subway symbol (M or S)
	var symbol_color = Color(0.2, 0.5, 0.8)
	_draw_circle(image, int(w * 0.5), 25, 15, symbol_color)

	# Rails indicator
	_draw_rect(image, 10, h - 20, w - 20, 4, Color(0.5, 0.5, 0.52))
	_draw_rect(image, 10, h - 12, w - 20, 4, Color(0.5, 0.5, 0.52))

	_draw_rect_outline(image, 2, 2, w - 4, h - 4, symbol_color)


func _draw_rail_station(image: Image, w: int, h: int, base_color: Color) -> void:
	_fill_with_gradient(image, w, h, Color(0.45, 0.4, 0.35), Color(0.4, 0.35, 0.3))

	# Platform
	var platform_color = Color(0.5, 0.48, 0.45)
	_draw_rect(image, 5, int(h * 0.5), w - 10, int(h * 0.5) - 10, platform_color)

	# Station building
	var building_color = Color(0.55, 0.45, 0.35)
	_draw_rect(image, 15, 10, int(w * 0.5) - 10, int(h * 0.5) - 5, building_color)
	_draw_triangle_roof(image, 12, 10, int(w * 0.5) - 4, 20, Color(0.4, 0.3, 0.25))

	# Rails
	var rail_color = Color(0.4, 0.4, 0.42)
	_draw_rect(image, 0, h - 15, w, 5, rail_color)
	_draw_rect(image, 0, h - 8, w, 5, rail_color)

	# Clock tower
	_draw_rect(image, w - 40, 5, 20, 40, building_color.lightened(0.1))
	_draw_circle(image, w - 30, 15, 8, Color(0.9, 0.9, 0.85))

	_draw_rect_outline(image, 2, 2, w - 4, h - 4, base_color.lightened(0.2))


func _draw_airport(image: Image, w: int, h: int, _base_color: Color) -> void:
	# Tarmac
	_fill_with_gradient(image, w, h, Color(0.35, 0.35, 0.38), Color(0.3, 0.3, 0.33))

	# Runway
	var runway_color = Color(0.25, 0.25, 0.28)
	_draw_rect(image, 20, int(h * 0.5) - 15, w - 40, 30, runway_color)

	# Runway markings
	var marking_color = Color(0.9, 0.9, 0.85)
	for i in range(0, w - 60, 30):
		_draw_rect(image, 30 + i, int(h * 0.5) - 2, 15, 4, marking_color)

	# Terminal building
	var terminal_color = Color(0.5, 0.55, 0.6)
	_draw_rect(image, 10, 10, int(w * 0.5), int(h / 3.0), terminal_color)

	# Control tower
	_draw_rect(image, w - 50, 15, 25, 50, Color(0.6, 0.6, 0.65))
	_draw_rect(image, w - 55, 10, 35, 15, Color(0.4, 0.6, 0.7))

	# Parked plane
	_draw_rect(image, int(w * 0.5) + 30, int(h * 0.5) - 8, 40, 16, Color(0.9, 0.9, 0.95))
	_draw_rect(image, int(w * 0.5) + 50, int(h * 0.5) - 20, 8, 40, Color(0.85, 0.85, 0.9))

	_draw_rect_outline(image, 2, 2, w - 4, h - 4, Color(0.5, 0.5, 0.55))


func _draw_seaport(image: Image, w: int, h: int, _base_color: Color) -> void:
	# Water (bottom half)
	_fill_with_gradient(image, w, h, Color(0.3, 0.4, 0.55), Color(0.25, 0.35, 0.5))

	# Dock/pier
	var dock_color = Color(0.45, 0.4, 0.35)
	_draw_rect(image, 0, 0, w, int(h * 0.5), dock_color)

	# Warehouse
	var warehouse_color = Color(0.5, 0.45, 0.4)
	_draw_rect(image, 10, 10, int(w / 3.0), int(h / 3.0), warehouse_color)

	# Crane
	var crane_color = Color(0.8, 0.5, 0.2)
	_draw_rect(image, int(w * 0.5), 5, 8, int(h * 0.5) - 5, crane_color)
	_draw_rect(image, int(w * 0.5) - 20, 8, 50, 8, crane_color)

	# Containers
	var colors = [Color(0.8, 0.3, 0.2), Color(0.2, 0.5, 0.8), Color(0.3, 0.7, 0.3)]
	for i in range(3):
		_draw_rect(image, w - 80 + i * 22, 15, 18, 30, colors[i])

	# Ship
	var ship_color = Color(0.4, 0.4, 0.45)
	_draw_rect(image, int(w * 0.25), int(h * 0.5) + 20, int(w * 0.5), int(h * 0.25), ship_color)
	_draw_rect(image, int(w * 0.25) + 20, int(h * 0.5) + 5, int(w * 0.25), 20, Color(0.9, 0.9, 0.85))

	_draw_rect_outline(image, 2, 2, w - 4, h - 4, Color(0.4, 0.5, 0.6))


func _draw_landmark(image: Image, w: int, h: int, base_color: Color, id: String) -> void:
	_fill_with_gradient(image, w, h, base_color.darkened(0.2), base_color)

	if "mayor" in id:
		# Mayor's house - nice mansion
		var house_color = Color(0.85, 0.8, 0.7)
		_draw_rect(image, 15, int(h / 3.0), w - 30, int(h * 2.0 / 3.0) - 10, house_color)
		_draw_triangle_roof(image, 10, int(h / 3.0), w - 20, int(h * 0.25), Color(0.5, 0.35, 0.25))
		# Columns
		for i in range(4):
			_draw_rect(image, 25 + i * 25, int(h / 3.0) + 10, 8, int(h / 3.0), Color(0.9, 0.88, 0.85))
		# Door
		_draw_rect(image, int(w * 0.5) - 10, h - 35, 20, 28, Color(0.4, 0.25, 0.15))

	elif "city_hall" in id:
		# City Hall - grand building with dome
		var building_color = Color(0.8, 0.78, 0.75)
		_draw_rect(image, 10, int(h / 3.0), w - 20, int(h * 2.0 / 3.0) - 10, building_color)
		# Dome
		_draw_circle(image, int(w * 0.5), int(h * 0.25) + 10, int(w / 6.0), Color(0.6, 0.65, 0.7))
		# Steps
		_draw_rect(image, 20, h - 20, w - 40, 15, Color(0.7, 0.68, 0.65))
		# Columns
		for i in range(6):
			_draw_rect(image, 20 + i * 28, int(h / 3.0), 6, int(h * 0.5), Color(0.85, 0.83, 0.8))

	elif "stadium" in id:
		# Stadium - oval arena
		var arena_color = Color(0.55, 0.6, 0.65)
		_draw_circle(image, int(w * 0.5), int(h * 0.5), int(min(w, h) * 0.5) - 10, arena_color)
		# Field
		_draw_circle(image, int(w * 0.5), int(h * 0.5), int(min(w, h) / 3.0) - 5, Color(0.3, 0.6, 0.35))
		# Stands
		_draw_rect_outline(image, int(w * 0.25), int(h * 0.25), int(w * 0.5), int(h * 0.5), Color(0.4, 0.4, 0.45))

	elif "university" in id:
		# University - academic buildings
		var building_color = Color(0.65, 0.5, 0.35)
		# Main hall
		_draw_rect(image, int(w * 0.25), int(h * 0.25), int(w * 0.5), int(h * 0.5), building_color)
		_draw_triangle_roof(image, int(w * 0.25) - 5, int(h * 0.25), int(w * 0.5) + 10, int(h * 0.2), Color(0.5, 0.35, 0.25))
		# Tower
		_draw_rect(image, int(w * 0.5) - 15, 10, 30, int(h / 3.0), building_color.lightened(0.1))
		# Clock
		_draw_circle(image, int(w * 0.5), 25, 10, Color(0.9, 0.9, 0.85))
		# Side buildings
		var side_w: int = int(w * 0.2)
		_draw_rect(image, 10, int(h * 0.5), side_w, int(h / 3.0), building_color.darkened(0.1))
		_draw_rect(image, w - side_w - 10, int(h * 0.5), side_w, int(h / 3.0), building_color.darkened(0.1))

	else:
		# Generic landmark
		_draw_rect(image, 10, 10, w - 20, h - 20, base_color.lightened(0.1))
		_draw_circle(image, int(w * 0.5), int(h * 0.5), int(min(w, h) * 0.25), Color(0.9, 0.8, 0.3))

	_draw_rect_outline(image, 2, 2, w - 4, h - 4, base_color.lightened(0.3))
