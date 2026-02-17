extends Resource
class_name BuildingData
## Defines properties for a building type

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export_multiline var tooltip: String = ""

# Categorization
@export_enum("infrastructure", "power", "water", "service", "zone", "data_center") var category: String = "infrastructure"
@export_enum("road", "collector", "arterial", "highway", "power_line", "water_pipe", "generator", "water_source", "police", "fire", "education", "residential", "commercial", "industrial", "heavy_industrial", "mixed_use", "data_center", "hospital", "library", "community_center", "agricultural", "park", "bus_stop", "bus_depot", "subway_station", "rail_station", "airport", "seaport", "landmark") var building_type: String = "road"

# Costs
@export var build_cost: int = 100
@export var monthly_maintenance: int = 0

# Size and Density
@export var size: Vector2i = Vector2i(1, 1)
@export var floors: int = 1  # Number of floors (for FAR calculation)
@export var floor_area_ratio: float = 0.0  # FAR = (floors * footprint) / lot_size. 0 = auto-calculate

# Resource production/consumption
@export var power_production: float = 0.0  # MW
@export var power_consumption: float = 0.0  # MW
@export var water_production: float = 0.0  # ML
@export var water_consumption: float = 0.0  # ML

# Energy storage (for batteries, pumped hydro, etc.)
@export var energy_storage_capacity: float = 0.0  # MWh (megawatt-hours)
@export var storage_charge_rate: float = 0.0  # MW max charge rate
@export var storage_discharge_rate: float = 0.0  # MW max discharge rate
@export var storage_efficiency: float = 0.9  # Round-trip efficiency (0.0-1.0)

# Service coverage
@export var coverage_radius: int = 0  # In tiles
@export_enum("none", "fire", "police", "education", "health", "recreation") var service_type: String = "none"

# Population
@export var population_capacity: int = 0
@export var jobs_provided: float = 0.0
@export_range(0.0, 1.0) var skilled_jobs_ratio: float = 0.0  # Percentage of jobs requiring education

# Data center specific
@export var data_center_tier: int = 0
@export var score_value: int = 0

# Placement rules
@export var requires_road_adjacent: bool = true
@export var requires_power: bool = true
@export var requires_water: bool = false

# Visual
@export var color: Color = Color.WHITE  # Placeholder color until sprites
@export var sprite_path: String = ""

# Effects
@export var pollution_radius: int = 0
@export var happiness_modifier: float = 0.0  # Applied to nearby tiles

# Road properties (for road hierarchy)
@export var conducts_utilities: bool = true  # Whether this road type conducts power/water
@export var road_capacity: int = 100  # Vehicles per road tile per month
@export var road_speed: float = 1.0  # Speed multiplier (1.0 = normal)
@export var noise_radius: int = 0  # Noise pollution radius for highways/arterials
@export var allows_direct_access: bool = true  # Can buildings connect directly to this road type?

# Parking
@export var parking_spaces_required: int = 0  # Spaces needed (based on jobs/residents)
@export var parking_spaces_provided: int = 0  # Spaces this building provides (for garages, lots)

# Environmental
@export var is_green_building: bool = false  # Uses less power/water
@export var tree_coverage: int = 0  # Number of trees (for parks)


func get_monthly_cost() -> int:
	return monthly_maintenance


func get_resource_summary() -> String:
	var parts: Array[String] = []

	if power_production > 0:
		parts.append("+%d MW" % int(power_production))
	if power_consumption > 0:
		parts.append("-%d MW" % int(power_consumption))
	if water_production > 0:
		parts.append("+%d ML" % int(water_production))
	if water_consumption > 0:
		parts.append("-%d ML" % int(water_consumption))

	return ", ".join(parts) if parts.size() > 0 else "None"


func get_requirements_text() -> String:
	var reqs: Array[String] = []

	if requires_road_adjacent:
		reqs.append("Adjacent to road")
	if requires_power:
		reqs.append("Power connection")
	if requires_water:
		reqs.append("Water connection")

	return ", ".join(reqs) if reqs.size() > 0 else "None"


## Get total floor area in square cells
func get_floor_area() -> int:
	return size.x * size.y * floors


## Get effective FAR (Floor Area Ratio)
## FAR = total floor area / lot footprint
func get_far() -> float:
	if floor_area_ratio > 0:
		return floor_area_ratio
	# Auto-calculate based on floors
	return float(floors)


## Get lot footprint (ground-level area)
func get_footprint() -> int:
	return size.x * size.y
