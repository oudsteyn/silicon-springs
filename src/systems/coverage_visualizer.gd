extends Node2D
class_name CoverageVisualizer
## Draws coverage radius overlays for service buildings

var coverage_tiles: Array[ColorRect] = []
var current_radius: int = 0
var current_center: Vector2i = Vector2i.ZERO
var current_color: Color = Color.RED

# Colors for different service types
const COLORS = {
	"fire": Color(1.0, 0.3, 0.3, 0.2),      # Red
	"police": Color(0.3, 0.3, 1.0, 0.2),    # Blue
	"education": Color(0.3, 1.0, 0.3, 0.2)  # Green
}


func _ready() -> void:
	visible = false


func show_coverage(center: Vector2i, radius: int, service_type: String) -> void:
	clear_coverage()

	if radius <= 0:
		return

	current_center = center
	current_radius = radius
	current_color = COLORS.get(service_type, Color(1, 1, 1, 0.2))

	# Create tiles for coverage area
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var distance = sqrt(x * x + y * y)
			if distance <= radius:
				var tile = ColorRect.new()
				tile.size = Vector2(GridConstants.CELL_SIZE, GridConstants.CELL_SIZE)
				tile.position = Vector2((center.x + x) * GridConstants.CELL_SIZE, (center.y + y) * GridConstants.CELL_SIZE)

				# Fade color based on distance
				var alpha = (1.0 - (distance / float(radius))) * 0.3
				tile.color = Color(current_color.r, current_color.g, current_color.b, alpha)

				add_child(tile)
				coverage_tiles.append(tile)

	visible = true


func update_center(new_center: Vector2i) -> void:
	if current_radius <= 0:
		return

	var offset = Vector2(new_center - current_center) * GridConstants.CELL_SIZE
	for tile in coverage_tiles:
		tile.position += offset

	current_center = new_center


func clear_coverage() -> void:
	for tile in coverage_tiles:
		tile.queue_free()
	coverage_tiles.clear()
	visible = false


func show_coverage_for_building_data(center: Vector2i, building_data) -> void:
	if building_data and building_data.coverage_radius > 0:
		show_coverage(center, building_data.coverage_radius, building_data.service_type)
	else:
		clear_coverage()
