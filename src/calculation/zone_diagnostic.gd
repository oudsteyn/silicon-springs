class_name ZoneDiagnostic
## Diagnoses why a zone isn't developing and provides actionable advice

## Diagnostic issue with severity and solution
class Issue:
	var id: String
	var severity: String  # "critical", "major", "minor"
	var problem: String
	var solution: String
	var impact: float  # How much this affects development (0-1)

	func _init(p_id: String, p_severity: String, p_problem: String, p_solution: String, p_impact: float = 0.5) -> void:
		id = p_id
		severity = p_severity
		problem = p_problem
		solution = p_solution
		impact = p_impact

## Full diagnostic result for a zone
class DiagnosticResult:
	var zone_type: String
	var is_developing: bool
	var development_rate: float  # 0-1, how fast it's developing
	var issues: Array[Issue] = []
	var overall_status: String  # "healthy", "slow", "stalled", "blocked"

	func get_critical_issues() -> Array[Issue]:
		var result: Array[Issue] = []
		for issue in issues:
			if issue.severity == "critical":
				result.append(issue)
		return result

	func get_primary_issue() -> Issue:
		if issues.size() == 0:
			return null
		# Return highest impact issue
		var highest: Issue = issues[0]
		for issue in issues:
			if issue.impact > highest.impact:
				highest = issue
		return highest


## Diagnose why a specific zone cell isn't developing
static func diagnose(
	zone_type: String,
	has_power: bool,
	has_water: bool,
	has_road_access: bool,
	pollution_level: float,
	crime_rate: float,
	traffic_congestion: float,
	land_value: float,
	nearby_incompatible_zones: bool,
	city_demand: float,
	_development_level: int,
	is_under_construction: bool
) -> DiagnosticResult:
	var result = DiagnosticResult.new()
	result.zone_type = zone_type
	result.is_developing = is_under_construction
	result.development_rate = 1.0

	# Critical infrastructure requirements
	if not has_power:
		result.issues.append(Issue.new(
			"no_power",
			"critical",
			"No power connection",
			"Build power lines to connect to the grid",
			1.0
		))
		result.development_rate = 0.0

	if not has_water:
		result.issues.append(Issue.new(
			"no_water",
			"critical",
			"No water connection",
			"Build water pipes to connect to water supply",
			1.0
		))
		result.development_rate = 0.0

	if not has_road_access and zone_type != "agricultural":
		result.issues.append(Issue.new(
			"no_road",
			"critical",
			"No road access",
			"Build a road adjacent to this zone",
			1.0
		))
		result.development_rate = 0.0

	# Zone-specific issues
	match zone_type:
		"residential":
			_diagnose_residential(result, pollution_level, crime_rate, nearby_incompatible_zones, city_demand, land_value)
		"commercial":
			_diagnose_commercial(result, crime_rate, traffic_congestion, city_demand, land_value)
		"industrial":
			_diagnose_industrial(result, traffic_congestion, city_demand)

	# Determine overall status
	if result.development_rate <= 0:
		result.overall_status = "blocked"
	elif result.development_rate < 0.3:
		result.overall_status = "stalled"
	elif result.development_rate < 0.7:
		result.overall_status = "slow"
	else:
		result.overall_status = "healthy"

	return result


static func _diagnose_residential(result: DiagnosticResult, pollution: float, crime: float, near_industrial: bool, demand: float, land_value: float) -> void:
	# Pollution severely impacts residential
	if pollution > 0.6:
		result.issues.append(Issue.new(
			"severe_pollution",
			"critical",
			"Area is heavily polluted",
			"Remove nearby industrial zones or add parks/trees",
			0.8
		))
		result.development_rate *= 0.2
	elif pollution > 0.3:
		result.issues.append(Issue.new(
			"moderate_pollution",
			"major",
			"Moderate pollution in area",
			"Consider adding parks or relocating polluting buildings",
			0.5
		))
		result.development_rate *= 0.5

	# Crime impacts residential
	if crime > 0.5:
		result.issues.append(Issue.new(
			"high_crime",
			"major",
			"High crime rate in area",
			"Build a police station nearby",
			0.6
		))
		result.development_rate *= 0.4
	elif crime > 0.3:
		result.issues.append(Issue.new(
			"moderate_crime",
			"minor",
			"Some crime in the area",
			"Police coverage would help development",
			0.3
		))
		result.development_rate *= 0.7

	# Industrial proximity
	if near_industrial:
		result.issues.append(Issue.new(
			"near_industrial",
			"major",
			"Too close to industrial zones",
			"Add commercial buffer zones between residential and industrial",
			0.4
		))
		result.development_rate *= 0.6

	# Low demand
	if demand < 0:
		result.issues.append(Issue.new(
			"low_demand",
			"minor",
			"Low residential demand",
			"Create more jobs (commercial/industrial) to attract residents",
			0.3
		))
		result.development_rate *= 0.5

	# Low land value affects high-density development
	if land_value < 0.3:
		result.issues.append(Issue.new(
			"low_land_value",
			"minor",
			"Low land value slows development",
			"Build parks and services to increase land value",
			0.2
		))
		result.development_rate *= 0.8


static func _diagnose_commercial(result: DiagnosticResult, crime: float, traffic: float, demand: float, land_value: float) -> void:
	# Crime severely impacts commercial
	if crime > 0.4:
		result.issues.append(Issue.new(
			"high_crime",
			"critical",
			"High crime deters businesses",
			"Build police stations to reduce crime",
			0.7
		))
		result.development_rate *= 0.3
	elif crime > 0.2:
		result.issues.append(Issue.new(
			"moderate_crime",
			"major",
			"Crime affects business confidence",
			"Improve police coverage",
			0.4
		))
		result.development_rate *= 0.6

	# Traffic impacts commercial
	if traffic > 0.7:
		result.issues.append(Issue.new(
			"severe_traffic",
			"major",
			"Heavy traffic hurts business",
			"Build wider roads or public transit",
			0.5
		))
		result.development_rate *= 0.5
	elif traffic > 0.5:
		result.issues.append(Issue.new(
			"moderate_traffic",
			"minor",
			"Traffic congestion in area",
			"Consider road improvements",
			0.3
		))
		result.development_rate *= 0.7

	# Low demand
	if demand < 0:
		result.issues.append(Issue.new(
			"low_demand",
			"minor",
			"Low commercial demand",
			"Grow population to create more customers",
			0.3
		))
		result.development_rate *= 0.5

	# Land value affects commercial
	if land_value < 0.4:
		result.issues.append(Issue.new(
			"low_land_value",
			"minor",
			"Low land value area",
			"Improve nearby residential areas and add parks",
			0.2
		))
		result.development_rate *= 0.8


static func _diagnose_industrial(result: DiagnosticResult, traffic: float, demand: float) -> void:
	# Traffic impacts industrial (goods delivery)
	if traffic > 0.7:
		result.issues.append(Issue.new(
			"severe_traffic",
			"major",
			"Heavy traffic impedes goods movement",
			"Build highways or improve road network",
			0.5
		))
		result.development_rate *= 0.5
	elif traffic > 0.5:
		result.issues.append(Issue.new(
			"moderate_traffic",
			"minor",
			"Traffic slowing deliveries",
			"Consider road improvements",
			0.2
		))
		result.development_rate *= 0.8

	# Low demand
	if demand < 0:
		result.issues.append(Issue.new(
			"low_demand",
			"minor",
			"Low industrial demand",
			"Build more commercial zones that need goods",
			0.3
		))
		result.development_rate *= 0.5


## Get a human-readable summary of the diagnostic
static func get_summary(result: DiagnosticResult) -> String:
	if result.issues.size() == 0:
		return "Zone is developing normally"

	var primary = result.get_primary_issue()
	if primary:
		if primary.severity == "critical":
			return "Blocked: " + primary.problem
		else:
			return "Slowed: " + primary.problem

	return "Development is impaired"


## Get status color for UI
static func get_status_color(result: DiagnosticResult) -> Color:
	match result.overall_status:
		"healthy":
			return Color(0.3, 0.75, 0.5, 1)  # Green
		"slow":
			return Color(0.85, 0.65, 0.25, 1)  # Yellow
		"stalled":
			return Color(0.85, 0.5, 0.25, 1)  # Orange
		"blocked":
			return Color(0.85, 0.3, 0.3, 1)  # Red
		_:
			return Color(0.6, 0.65, 0.7, 1)  # Gray
