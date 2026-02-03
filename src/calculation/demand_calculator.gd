class_name DemandCalculator
## Pure calculation logic for zone demand indicators
## Returns both demand values and detailed breakdowns for UI transparency

## Single factor affecting demand
class DemandFactor:
	var id: String
	var name: String
	var effect: float  # Positive = increases demand, negative = decreases
	var description: String

	func _init(p_id: String, p_name: String, p_effect: float, p_desc: String) -> void:
		id = p_id
		name = p_name
		effect = p_effect
		description = p_desc

## Detailed breakdown for a single zone type
class ZoneDemandBreakdown:
	var zone_type: String
	var demand: float  # Final clamped value (-1.0 to 1.0)
	var base_demand: float  # Before penalties
	var factors: Array[DemandFactor] = []
	var status: String  # "high", "medium", "low", "negative"
	var summary: String  # Human-readable explanation

	func get_positive_factors() -> Array[DemandFactor]:
		var result: Array[DemandFactor] = []
		for factor in factors:
			if factor.effect > 0:
				result.append(factor)
		return result

	func get_negative_factors() -> Array[DemandFactor]:
		var result: Array[DemandFactor] = []
		for factor in factors:
			if factor.effect < 0:
				result.append(factor)
		return result

## Full demand calculation result
class DemandResult:
	var residential: ZoneDemandBreakdown
	var commercial: ZoneDemandBreakdown
	var industrial: ZoneDemandBreakdown

	func _init() -> void:
		residential = ZoneDemandBreakdown.new()
		residential.zone_type = "residential"
		commercial = ZoneDemandBreakdown.new()
		commercial.zone_type = "commercial"
		industrial = ZoneDemandBreakdown.new()
		industrial.zone_type = "industrial"

	## Get simple dictionary (for backwards compatibility)
	func to_dict() -> Dictionary:
		return {
			"residential": residential.demand,
			"commercial": commercial.demand,
			"industrial": industrial.demand
		}


## Calculate demand with full breakdown for all zone types
static func calculate_with_breakdown(
	population: int,
	jobs_available: int,
	commercial_zones: int,
	industrial_zones: int,
	educated_population: int,
	has_power_shortage: bool,
	has_water_shortage: bool,
	city_traffic_congestion: float,
	city_crime_rate: float
) -> DemandResult:
	var result = DemandResult.new()

	# Calculate each zone type
	_calculate_residential_breakdown(result.residential, population, jobs_available)
	_calculate_commercial_breakdown(result.commercial, population, commercial_zones)
	_calculate_industrial_breakdown(result.industrial, population, educated_population, commercial_zones, industrial_zones)

	# Apply shared penalties
	_apply_infrastructure_penalties(result, has_power_shortage, has_water_shortage)
	_apply_traffic_penalty(result, city_traffic_congestion)
	_apply_crime_penalty(result.commercial, city_crime_rate)

	# Finalize all zones
	_finalize_zone(result.residential)
	_finalize_zone(result.commercial)
	_finalize_zone(result.industrial)

	return result


## Simple calculate (backwards compatible)
static func calculate(
	population: int,
	jobs_available: int,
	commercial_zones: int,
	industrial_zones: int,
	educated_population: int,
	has_power_shortage: bool,
	has_water_shortage: bool,
	city_traffic_congestion: float,
	city_crime_rate: float
) -> Dictionary:
	var result = calculate_with_breakdown(
		population, jobs_available, commercial_zones, industrial_zones,
		educated_population, has_power_shortage, has_water_shortage,
		city_traffic_congestion, city_crime_rate
	)
	return result.to_dict()


static func _calculate_residential_breakdown(zone: ZoneDemandBreakdown, population: int, jobs_available: int) -> void:
	# Residential demand: high if jobs > population (workers needed)
	if jobs_available > 0:
		var worker_ratio = float(population) / float(jobs_available)
		if worker_ratio < 1.0:
			zone.base_demand = 1.0 - worker_ratio
			zone.factors.append(DemandFactor.new(
				"jobs_need_workers",
				"Jobs Need Workers",
				zone.base_demand,
				"%d jobs available with only %d residents" % [jobs_available, population]
			))
		else:
			zone.base_demand = -0.2
			zone.factors.append(DemandFactor.new(
				"worker_surplus",
				"Worker Surplus",
				-0.2,
				"More residents than jobs available"
			))
	elif population > 0:
		zone.base_demand = -0.5
		zone.factors.append(DemandFactor.new(
			"no_jobs",
			"No Jobs Available",
			-0.5,
			"Residents have no employment opportunities"
		))
	else:
		zone.base_demand = 0.0
		zone.factors.append(DemandFactor.new(
			"starting_city",
			"New City",
			0.0,
			"Build commercial/industrial to create jobs first"
		))


static func _calculate_commercial_breakdown(zone: ZoneDemandBreakdown, population: int, commercial_zones: int) -> void:
	# Commercial demand: based on population needing goods/services
	if population > 0:
		var commercial_ratio = float(commercial_zones * 50) / float(population)  # 50 customers per zone
		if commercial_ratio < 1.0:
			zone.base_demand = 1.0 - commercial_ratio
			zone.factors.append(DemandFactor.new(
				"customers_need_shops",
				"Customers Need Shops",
				zone.base_demand,
				"%d residents want more shopping options" % population
			))
		else:
			zone.base_demand = -0.2
			zone.factors.append(DemandFactor.new(
				"shop_surplus",
				"Shop Surplus",
				-0.2,
				"More shops than customers can support"
			))
	elif commercial_zones > 0:
		zone.base_demand = -0.5
		zone.factors.append(DemandFactor.new(
			"no_customers",
			"No Customers",
			-0.5,
			"Commercial zones need residential population"
		))
	else:
		zone.base_demand = 0.0
		zone.factors.append(DemandFactor.new(
			"starting_city",
			"New City",
			0.0,
			"Build residential zones to attract customers"
		))


static func _calculate_industrial_breakdown(
	zone: ZoneDemandBreakdown,
	population: int,
	educated_population: int,
	commercial_zones: int,
	industrial_zones: int
) -> void:
	# Industrial demand: provides jobs and goods for commercial
	var uneducated_pop = population - educated_population

	if uneducated_pop > 0:
		var industrial_jobs = industrial_zones * 20  # 20 jobs per industrial
		var uneducated_job_ratio = float(industrial_jobs) / float(uneducated_pop)
		if uneducated_job_ratio < 0.8:
			var job_demand = 0.8 - uneducated_job_ratio
			zone.factors.append(DemandFactor.new(
				"need_factory_jobs",
				"Factory Jobs Needed",
				job_demand,
				"%d uneducated workers need industrial jobs" % uneducated_pop
			))

	# Commercial also needs industrial goods
	if commercial_zones > 0:
		var industrial_supply = float(industrial_zones) / float(commercial_zones)
		if industrial_supply < 0.5:  # Need ~1 industrial per 2 commercial
			var goods_demand = 0.5 - industrial_supply
			zone.factors.append(DemandFactor.new(
				"need_goods",
				"Goods Supply Needed",
				goods_demand,
				"%d commercial zones need industrial goods" % commercial_zones
			))

	# Calculate base demand from factors
	var max_positive = 0.0
	for factor in zone.factors:
		if factor.effect > max_positive:
			max_positive = factor.effect
	zone.base_demand = max_positive

	if zone.factors.size() == 0:
		zone.factors.append(DemandFactor.new(
			"balanced",
			"Supply Balanced",
			0.0,
			"Industrial supply meets current demand"
		))


static func _apply_infrastructure_penalties(result: DemandResult, has_power_shortage: bool, has_water_shortage: bool) -> void:
	if has_power_shortage:
		var penalty = DemandFactor.new(
			"power_shortage",
			"Power Shortage",
			-0.3,
			"No one wants to build without electricity"
		)
		result.residential.factors.append(penalty)
		result.commercial.factors.append(penalty)
		result.industrial.factors.append(penalty)

	if has_water_shortage:
		var penalty = DemandFactor.new(
			"water_shortage",
			"Water Shortage",
			-0.3,
			"Buildings need water to develop"
		)
		result.residential.factors.append(penalty)
		result.commercial.factors.append(penalty)
		result.industrial.factors.append(penalty)


static func _apply_traffic_penalty(result: DemandResult, city_traffic_congestion: float) -> void:
	if city_traffic_congestion > 0.5:
		var penalty = (city_traffic_congestion - 0.5) * 0.6  # Up to 30% penalty
		var factor = DemandFactor.new(
			"traffic_congestion",
			"Traffic Problems",
			-penalty,
			"Heavy traffic discourages business development"
		)
		result.commercial.factors.append(factor)
		result.industrial.factors.append(factor)


static func _apply_crime_penalty(zone: ZoneDemandBreakdown, city_crime_rate: float) -> void:
	if city_crime_rate > 0.2:
		var penalty = (city_crime_rate - 0.2) * 0.5  # Up to 40% penalty
		zone.factors.append(DemandFactor.new(
			"high_crime",
			"High Crime Rate",
			-penalty,
			"Businesses avoid high-crime areas"
		))


static func _finalize_zone(zone: ZoneDemandBreakdown) -> void:
	# Sum all factors
	var total = zone.base_demand
	for factor in zone.factors:
		if factor.id != "jobs_need_workers" and factor.id != "customers_need_shops" and factor.id != "need_factory_jobs" and factor.id != "need_goods":
			total += factor.effect

	zone.demand = clampf(total, -1.0, 1.0)

	# Determine status
	if zone.demand > 0.5:
		zone.status = "high"
	elif zone.demand > 0.0:
		zone.status = "medium"
	elif zone.demand > -0.3:
		zone.status = "low"
	else:
		zone.status = "negative"

	# Generate summary
	zone.summary = _generate_summary(zone)


static func _generate_summary(zone: ZoneDemandBreakdown) -> String:
	var positive = zone.get_positive_factors()
	var negative = zone.get_negative_factors()

	if zone.demand > 0.5:
		if positive.size() > 0:
			return "High demand: " + positive[0].description
		return "High demand for %s zones" % zone.zone_type
	elif zone.demand > 0:
		return "Moderate demand for %s zones" % zone.zone_type
	elif zone.demand > -0.3:
		if negative.size() > 0:
			return "Low demand: " + negative[0].description
		return "Low demand for %s zones" % zone.zone_type
	else:
		if negative.size() > 0:
			return "No demand: " + negative[0].description
		return "Oversupply of %s zones" % zone.zone_type


## Get tooltip text for a zone demand bar
static func get_demand_tooltip(zone: ZoneDemandBreakdown) -> String:
	var lines: PackedStringArray = []

	lines.append("%s Demand: %+d%%" % [zone.zone_type.capitalize(), int(zone.demand * 100)])
	lines.append("")

	var positive = zone.get_positive_factors()
	var negative = zone.get_negative_factors()

	if positive.size() > 0:
		lines.append("Increasing demand:")
		for factor in positive:
			lines.append("  + %s" % factor.name)

	if negative.size() > 0:
		lines.append("Decreasing demand:")
		for factor in negative:
			lines.append("  - %s" % factor.name)

	lines.append("")
	lines.append(zone.summary)

	return "\n".join(lines)
