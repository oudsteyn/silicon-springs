extends Resource
class_name DataCenterTier
## Defines requirements for a data center tier

@export var tier: int = 1
@export var display_name: String = ""
@export var description: String = ""

# Power requirement (available MW after other consumption)
@export var power_required: float = 5.0

# Water requirement (available ML after other consumption)
@export var water_required: float = 100.0

# Population requirements
@export var population_required: int = 10
@export var education_rate_required: float = 0.0  # 0.0 to 1.0

# Service coverage requirements
@export var requires_fire_coverage: bool = true
@export var requires_police_coverage: bool = false
@export var requires_full_coverage: bool = false  # All services

# Infrastructure requirements
@export var requires_road_access: bool = true

# Score value when placed
@export var score_value: int = 100

# Building cost and maintenance
@export var build_cost: int = 10000
@export var monthly_maintenance: int = 500

# Resource consumption
@export var power_consumption: float = 5.0
@export var water_consumption: float = 50.0


func check_requirements(at_cell: Vector2i, service_coverage: Node) -> Dictionary:
	## Returns a dictionary with requirement status
	var result = {
		"met": true,
		"power": false,
		"water": false,
		"population": false,
		"education": false,
		"fire_coverage": false,
		"police_coverage": false,
		"messages": []
	}

	# Check power
	var available_power = GameState.get_available_power()
	result.power = available_power >= power_required
	if not result.power:
		result.met = false
		result.messages.append("Need %d MW available (have %d)" % [int(power_required), int(available_power)])

	# Check water
	var available_water = GameState.get_available_water()
	result.water = available_water >= water_required
	if not result.water:
		result.met = false
		result.messages.append("Need %d ML available (have %d)" % [int(water_required), int(available_water)])

	# Check population
	result.population = GameState.population >= population_required
	if not result.population:
		result.met = false
		result.messages.append("Need %d population (have %d)" % [population_required, GameState.population])

	# Check education
	if education_rate_required > 0:
		result.education = GameState.education_rate >= education_rate_required
		if not result.education:
			result.met = false
			result.messages.append("Need %d%% educated (have %d%%)" % [int(education_rate_required * 100), int(GameState.education_rate * 100)])
	else:
		result.education = true

	# Check service coverage at location
	if service_coverage:
		if requires_fire_coverage:
			result.fire_coverage = service_coverage.has_fire_coverage(at_cell)
			if not result.fire_coverage:
				result.met = false
				result.messages.append("Needs fire station coverage")

		if requires_police_coverage:
			result.police_coverage = service_coverage.has_police_coverage(at_cell)
			if not result.police_coverage:
				result.met = false
				result.messages.append("Needs police station coverage")
	else:
		result.fire_coverage = not requires_fire_coverage
		result.police_coverage = not requires_police_coverage

	return result


func get_requirements_text() -> String:
	var lines: Array[String] = []
	lines.append("Power: %d MW available" % int(power_required))
	lines.append("Water: %d ML available" % int(water_required))
	lines.append("Population: %d" % population_required)

	if education_rate_required > 0:
		lines.append("Education: %d%%" % int(education_rate_required * 100))

	if requires_fire_coverage:
		lines.append("Fire coverage at site")
	if requires_police_coverage:
		lines.append("Police coverage at site")

	return "\n".join(lines)
