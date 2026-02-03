class_name HappinessCalculator
## Pure static calculator for city happiness
## Returns both final value and detailed breakdown for UI transparency

## Input data structure for happiness calculation
class HappinessInput:
	var power_ratio: float = 1.0
	var water_ratio: float = 1.0
	var service_coverage: float = 0.5
	var employment_ratio: float = 1.0
	var budget: int = 0
	var pollution_score: float = 1.0  # 1.0 = clean, 0.0 = heavily polluted
	var polluted_residential_count: int = 0
	var park_bonus: float = 0.0
	var park_effectiveness_modifier: float = 1.0
	var ordinance_happiness_bonus: float = 0.0
	var traffic_score: float = 1.0  # 1.0 = no traffic, 0.0 = gridlock
	var noise_penalty: float = 0.0
	var zoning_penalty: float = 0.0
	var natural_environment_score: float = 0.5  # 0.0 = barren, 1.0 = lush nature
	var climate_comfort: float = 1.0  # 1.0 = comfortable, 0.0 = extreme
	var aqi: float = 0.0  # Air Quality Index (0-500, EPA scale)
	var weather_comfort: float = 1.0  # 0.0 = miserable, 1.0 = perfect weather
	var is_drought: bool = false  # Extended water shortage from dry weather
	var power_outage_severity: float = 0.0  # 0.0 = no outage, 1.0 = total blackout

## Single factor in the happiness breakdown
class HappinessFactor:
	var id: String
	var name: String
	var icon: String
	var raw_value: float  # The input value (0-1)
	var weight: int  # How many times it's counted
	var contribution: float  # Total contribution to sum
	var status: String  # "good", "warning", "critical"

	func _init(p_id: String, p_name: String, p_icon: String, p_value: float, p_weight: int) -> void:
		id = p_id
		name = p_name
		icon = p_icon
		raw_value = clampf(p_value, 0.0, 1.0)
		weight = p_weight
		contribution = raw_value * weight

		# Determine status
		if raw_value >= 0.7:
			status = "good"
		elif raw_value >= 0.4:
			status = "warning"
		else:
			status = "critical"

## Result of happiness calculation with full breakdown
class HappinessResult:
	var happiness: float = 0.5
	var factors: Array[HappinessFactor] = []
	var bottleneck: HappinessFactor = null
	var total_weight: int = 0
	var total_contribution: float = 0.0

	func get_factor(id: String) -> HappinessFactor:
		for factor in factors:
			if factor.id == id:
				return factor
		return null

	func get_factors_by_status(status: String) -> Array[HappinessFactor]:
		var result: Array[HappinessFactor] = []
		for factor in factors:
			if factor.status == status:
				result.append(factor)
		return result

	func get_critical_factors() -> Array[HappinessFactor]:
		return get_factors_by_status("critical")

	func get_warning_factors() -> Array[HappinessFactor]:
		return get_factors_by_status("warning")


## Calculate happiness from input data
## Returns HappinessResult with value and full breakdown
static func calculate(input: HappinessInput) -> HappinessResult:
	var result = HappinessResult.new()

	# Power availability (weight: 2)
	result.factors.append(HappinessFactor.new(
		"power", "Power Supply", "⚡",
		input.power_ratio, 2
	))

	# Water availability (weight: 2)
	result.factors.append(HappinessFactor.new(
		"water", "Water Supply", "💧",
		input.water_ratio, 2
	))

	# Service coverage (weight: 1)
	result.factors.append(HappinessFactor.new(
		"services", "City Services", "🏛️",
		input.service_coverage, 1
	))

	# Employment (weight: 2)
	result.factors.append(HappinessFactor.new(
		"employment", "Employment", "💼",
		input.employment_ratio, 2
	))

	# Budget health (weight: 1)
	var budget_score: float
	if input.budget < 0:
		budget_score = 0.0
	elif input.budget < 1000:
		budget_score = 0.3
	else:
		budget_score = 1.0
	result.factors.append(HappinessFactor.new(
		"budget", "City Budget", "💰",
		budget_score, 1
	))

	# Pollution (weight: 2, plus extra penalty if many polluted residential)
	var pollution_weight = 2
	if input.polluted_residential_count > 5:
		pollution_weight = 3
		# Adjust pollution score for extra penalty
		var extra_penalty = maxf(0.3, 1.0 - input.polluted_residential_count * 0.05)
		input.pollution_score = (input.pollution_score * 2 + extra_penalty) / 3.0
	result.factors.append(HappinessFactor.new(
		"pollution", "Air Quality", "🌫️",
		input.pollution_score, pollution_weight
	))

	# Parks and amenities (weight: 1, only if positive)
	var effective_park_bonus = input.park_bonus * input.park_effectiveness_modifier
	if effective_park_bonus > 0:
		var park_value = clampf(0.5 + effective_park_bonus, 0.0, 1.0)
		result.factors.append(HappinessFactor.new(
			"parks", "Parks & Recreation", "🌳",
			park_value, 1
		))

	# Ordinance bonuses (weight: 1, only if positive)
	if input.ordinance_happiness_bonus > 0:
		var ordinance_value = clampf(0.5 + input.ordinance_happiness_bonus, 0.0, 1.0)
		result.factors.append(HappinessFactor.new(
			"ordinances", "City Policies", "📜",
			ordinance_value, 1
		))

	# Traffic (weight: 1)
	result.factors.append(HappinessFactor.new(
		"traffic", "Traffic Flow", "🚗",
		input.traffic_score, 1
	))

	# Road noise penalty (weight: 1, only if penalty exists)
	if input.noise_penalty > 0:
		result.factors.append(HappinessFactor.new(
			"noise", "Noise Levels", "🔊",
			1.0 - input.noise_penalty, 1
		))

	# Zoning incompatibility (weight: 1, only if penalty exists)
	if input.zoning_penalty > 0:
		result.factors.append(HappinessFactor.new(
			"zoning", "Neighborhood Quality", "🏘️",
			1.0 - input.zoning_penalty, 1
		))

	# Natural environment (weight: 1, if there's meaningful nature)
	if input.natural_environment_score > 0.2:
		result.factors.append(HappinessFactor.new(
			"nature", "Natural Environment", "🌲",
			input.natural_environment_score, 1
		))

	# Climate comfort (weight: 1, if there's discomfort)
	if input.climate_comfort < 0.9:
		result.factors.append(HappinessFactor.new(
			"climate", "Climate Comfort", "🌡️",
			input.climate_comfort, 1
		))

	# Health impacts from poor air quality (weight: 2 when unhealthy)
	# AQI 0-50 = Good (no penalty), 51-100 = Moderate (slight), 101+ = Unhealthy (significant)
	if input.aqi > 50:
		var health_score = 1.0
		if input.aqi <= 100:
			# Moderate: 0.95-1.0
			health_score = 1.0 - ((input.aqi - 50) / 50.0) * 0.05
		elif input.aqi <= 150:
			# Unhealthy for Sensitive Groups: 0.75-0.95
			health_score = 0.95 - ((input.aqi - 100) / 50.0) * 0.2
		elif input.aqi <= 200:
			# Unhealthy: 0.5-0.75
			health_score = 0.75 - ((input.aqi - 150) / 50.0) * 0.25
		elif input.aqi <= 300:
			# Very Unhealthy: 0.25-0.5
			health_score = 0.5 - ((input.aqi - 200) / 100.0) * 0.25
		else:
			# Hazardous: 0.0-0.25
			health_score = maxf(0.0, 0.25 - ((input.aqi - 300) / 200.0) * 0.25)

		var health_weight = 1 if input.aqi <= 100 else 2  # Higher weight for unhealthy air
		result.factors.append(HappinessFactor.new(
			"health", "Public Health", "🏥",
			health_score, health_weight
		))

	# Weather comfort (weight: 1, adds to mood when weather is nice, hurts when bad)
	if input.weather_comfort < 0.8 or input.weather_comfort > 0.95:
		result.factors.append(HappinessFactor.new(
			"weather", "Weather", "☀️",
			input.weather_comfort, 1
		))

	# Drought stress (weight: 1, when water restrictions are active)
	if input.is_drought:
		result.factors.append(HappinessFactor.new(
			"drought", "Water Restrictions", "🏜️",
			0.4, 1  # Drought is stressful
		))

	# Power outage impact (weight: 2 during severe outages)
	if input.power_outage_severity > 0.1:
		var outage_score = 1.0 - input.power_outage_severity
		var outage_weight = 1 if input.power_outage_severity < 0.5 else 2
		result.factors.append(HappinessFactor.new(
			"outage", "Power Outage", "🔌",
			outage_score, outage_weight
		))

	# Calculate totals
	for factor in result.factors:
		result.total_weight += factor.weight
		result.total_contribution += factor.contribution

	# Calculate final happiness
	if result.total_weight > 0:
		result.happiness = result.total_contribution / result.total_weight
	else:
		result.happiness = 0.5

	# Find bottleneck (lowest raw_value factor, excluding bonuses)
	var lowest_value: float = 1.0
	for factor in result.factors:
		# Skip bonus-only factors for bottleneck detection
		if factor.id in ["parks", "ordinances"]:
			continue
		if factor.raw_value < lowest_value:
			lowest_value = factor.raw_value
			result.bottleneck = factor

	return result


## Convenience method to calculate with smooth lerping
static func calculate_smoothed(input: HappinessInput, current_happiness: float, lerp_rate: float = 0.3) -> HappinessResult:
	var result = calculate(input)
	result.happiness = lerpf(current_happiness, result.happiness, lerp_rate)
	return result


## Get a human-readable summary of happiness issues
static func get_issues_summary(result: HappinessResult) -> String:
	var issues: PackedStringArray = []

	for factor in result.get_critical_factors():
		issues.append(factor.name + " is critical!")

	for factor in result.get_warning_factors():
		issues.append(factor.name + " needs attention")

	if issues.size() == 0:
		return "Your residents are happy!"

	return "\n".join(issues)


## Get advice for improving a specific factor
static func get_factor_advice(factor_id: String) -> String:
	match factor_id:
		"power":
			return "Build more power plants or reduce demand by demolishing buildings."
		"water":
			return "Build water pumps and expand your pipe network."
		"services":
			return "Build fire stations, police stations, and hospitals for better coverage."
		"employment":
			return "Zone more commercial and industrial areas to create jobs."
		"budget":
			return "Increase tax revenue or reduce expenses. Check the Budget panel."
		"pollution":
			return "Reduce industrial zones near residential areas. Plant trees and parks."
		"parks":
			return "Build parks near residential zones to boost happiness."
		"traffic":
			return "Build wider roads, add public transit, or spread out destinations."
		"noise":
			return "Add buffer zones between highways and residential areas."
		"zoning":
			return "Separate industrial zones from residential with commercial buffers."
		"nature":
			return "Preserve trees and water features. Build near natural areas."
		"climate":
			return "Extreme temperatures affect comfort. Ensure adequate heating/cooling infrastructure."
		"health":
			return "Poor air quality is affecting public health. Reduce industrial pollution, plant trees, or wait for weather to clear the air."
		"weather":
			return "Weather conditions are affecting resident mood. This will pass naturally."
		"drought":
			return "Water restrictions during drought. Expand water infrastructure and wait for rain."
		"outage":
			return "Power outages are disrupting life. Repair damaged infrastructure and diversify power sources."
		_:
			return "Check your city's infrastructure and services."
