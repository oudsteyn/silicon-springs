extends Node
class_name AdvisorSystem
## Provides contextual advice to the player based on city conditions

signal advice_ready(advisor: String, message: String, priority: int)

# Advisor types
enum AdvisorType { CITY, FINANCE, UTILITY, SAFETY, ENVIRONMENT, TRANSPORT }

const ADVISOR_NAMES = {
	AdvisorType.CITY: "City Planner",
	AdvisorType.FINANCE: "Financial Advisor",
	AdvisorType.UTILITY: "Utility Manager",
	AdvisorType.SAFETY: "Safety Director",
	AdvisorType.ENVIRONMENT: "Environmental Advisor",
	AdvisorType.TRANSPORT: "Transportation Advisor"
}

# Advice cooldowns to avoid spam
var advice_cooldowns: Dictionary = {}
const ADVICE_COOLDOWN: int = 6  # Months between same advice

# Track issued advice this session to avoid repetition
var issued_advice: Dictionary = {}


func _ready() -> void:
	Events.month_tick.connect(_on_month_tick)


func _on_month_tick() -> void:
	_update_cooldowns()
	_check_all_conditions()


func _update_cooldowns() -> void:
	for key in advice_cooldowns.keys():
		advice_cooldowns[key] -= 1
		if advice_cooldowns[key] <= 0:
			advice_cooldowns.erase(key)


func _check_all_conditions() -> void:
	_check_finance_conditions()
	_check_utility_conditions()
	_check_safety_conditions()
	_check_city_conditions()
	_check_environment_conditions()
	_check_transport_conditions()


func _give_advice(advisor: AdvisorType, advice_id: String, message: String, priority: int = 1) -> void:
	# Check cooldown
	var key = "%d_%s" % [advisor, advice_id]
	if advice_cooldowns.has(key):
		return

	# Set cooldown
	advice_cooldowns[key] = ADVICE_COOLDOWN

	# Emit signal
	advice_ready.emit(ADVISOR_NAMES[advisor], message, priority)


func _check_finance_conditions() -> void:
	# Budget warnings
	if GameState.budget < 0:
		_give_advice(AdvisorType.FINANCE, "negative_budget",
			"Our budget is in the red! Consider raising taxes or cutting services.", 3)
	elif GameState.budget < 5000:
		_give_advice(AdvisorType.FINANCE, "low_budget",
			"Budget reserves are running low. Plan for emergencies.", 2)

	# Income vs expenses
	var net = GameState.monthly_income - GameState.monthly_expenses
	if net < -500:
		_give_advice(AdvisorType.FINANCE, "high_deficit",
			"We're running a significant deficit of $%d/month. This is unsustainable." % abs(net), 3)
	elif net < 0:
		_give_advice(AdvisorType.FINANCE, "deficit",
			"Monthly expenses exceed income. Consider cost-cutting measures.", 2)

	# Tax suggestions
	if GameState.tax_rate < 0.08 and GameState.budget < 20000:
		_give_advice(AdvisorType.FINANCE, "low_tax",
			"Tax rates are below average. A small increase could help balance the budget.", 1)
	elif GameState.tax_rate > 0.15 and GameState.happiness < 0.5:
		_give_advice(AdvisorType.FINANCE, "high_tax",
			"High tax rates are hurting citizen happiness. Consider reducing taxes.", 2)


func _check_utility_conditions() -> void:
	# Power
	if GameState.has_power_shortage():
		var deficit = GameState.power_demand - GameState.power_supply
		_give_advice(AdvisorType.UTILITY, "power_shortage",
			"Power shortage of %.0f MW! Build more power plants immediately." % deficit, 3)
	elif GameState.power_supply > 0 and GameState.power_demand / GameState.power_supply > 0.9:
		_give_advice(AdvisorType.UTILITY, "power_near_capacity",
			"Power grid is at 90%% capacity. Plan for expansion soon.", 2)

	# Water
	if GameState.has_water_shortage():
		var deficit = GameState.water_demand - GameState.water_supply
		_give_advice(AdvisorType.UTILITY, "water_shortage",
			"Water shortage of %.0f ML! Citizens need water infrastructure." % deficit, 3)
	elif GameState.water_supply > 0 and GameState.water_demand / GameState.water_supply > 0.9:
		_give_advice(AdvisorType.UTILITY, "water_near_capacity",
			"Water supply is nearly maxed out. Build more water facilities.", 2)


func _check_safety_conditions() -> void:
	# This would need service_coverage access - simplified version
	if GameState.population > 100 and GameState.get_building_count("fire_station") == 0:
		_give_advice(AdvisorType.SAFETY, "no_fire",
			"The city has no fire protection! Build a fire station before disaster strikes.", 3)

	if GameState.population > 200 and GameState.get_building_count("police_station") == 0:
		_give_advice(AdvisorType.SAFETY, "no_police",
			"We need law enforcement! Crime is unchecked without a police station.", 3)


func _check_city_conditions() -> void:
	# Population growth
	if GameState.population == 0 and GameState.residential_zones > 0:
		_give_advice(AdvisorType.CITY, "no_population",
			"Residential zones are empty. Ensure power, water, and jobs are available.", 2)

	# Employment
	if GameState.unemployment_rate > 0.2:
		_give_advice(AdvisorType.CITY, "high_unemployment",
			"Unemployment is at %.0f%%! Build commercial or industrial zones for jobs." % (GameState.unemployment_rate * 100), 2)

	# Education
	if GameState.population > 500 and GameState.education_rate < 0.3:
		_give_advice(AdvisorType.CITY, "low_education",
			"Education rate is only %.0f%%. Build schools to improve workforce quality." % (GameState.education_rate * 100), 2)

	# Happiness
	if GameState.happiness < 0.3:
		_give_advice(AdvisorType.CITY, "very_unhappy",
			"Citizens are very unhappy! Check services, jobs, and utilities.", 3)
	elif GameState.happiness < 0.5:
		_give_advice(AdvisorType.CITY, "unhappy",
			"Happiness is below average. Parks and services can help.", 1)

	# Demand
	if GameState.residential_demand > 0.7:
		_give_advice(AdvisorType.CITY, "high_res_demand",
			"High residential demand! Zone more residential areas.", 1)
	if GameState.commercial_demand > 0.7:
		_give_advice(AdvisorType.CITY, "high_com_demand",
			"Commercial demand is high! Businesses want to open here.", 1)
	if GameState.industrial_demand > 0.7:
		_give_advice(AdvisorType.CITY, "high_ind_demand",
			"Industrial demand is strong! Zone industrial areas for jobs.", 1)


func _check_environment_conditions() -> void:
	# Would need pollution_system access
	if GameState.get_building_count("coal_plant") > 2:
		_give_advice(AdvisorType.ENVIRONMENT, "too_many_coal",
			"Multiple coal plants are polluting the air. Consider cleaner energy options.", 2)


func _check_transport_conditions() -> void:
	# Would need traffic_system access
	if GameState.population > 1000 and GameState.get_building_count("bus_stop") == 0:
		_give_advice(AdvisorType.TRANSPORT, "no_transit",
			"The city has no public transit! Consider adding bus stops.", 1)


func get_all_current_advice() -> Array:
	var advice: Array = []

	# Generate advice on demand for the advisor panel
	# Budget
	if GameState.budget < 0:
		advice.append({"advisor": "Financial Advisor", "message": "Budget is negative - take action!", "priority": 3})
	elif GameState.budget < 10000:
		advice.append({"advisor": "Financial Advisor", "message": "Build up financial reserves.", "priority": 1})

	# Power
	if GameState.has_power_shortage():
		advice.append({"advisor": "Utility Manager", "message": "Power shortage! Build power plants.", "priority": 3})

	# Water
	if GameState.has_water_shortage():
		advice.append({"advisor": "Utility Manager", "message": "Water shortage! Build water facilities.", "priority": 3})

	# Services
	if GameState.population > 100 and GameState.get_building_count("fire_station") == 0:
		advice.append({"advisor": "Safety Director", "message": "Build a fire station for protection.", "priority": 2})
	if GameState.population > 200 and GameState.get_building_count("police_station") == 0:
		advice.append({"advisor": "Safety Director", "message": "Build a police station to fight crime.", "priority": 2})

	# Growth
	if GameState.residential_demand > 0.5:
		advice.append({"advisor": "City Planner", "message": "Residential demand is high - zone more housing.", "priority": 1})
	if GameState.commercial_demand > 0.5:
		advice.append({"advisor": "City Planner", "message": "Commercial demand is high - zone shopping areas.", "priority": 1})
	if GameState.industrial_demand > 0.5:
		advice.append({"advisor": "City Planner", "message": "Industrial demand is high - zone factories.", "priority": 1})

	# Happiness
	if GameState.happiness < 0.4:
		advice.append({"advisor": "City Planner", "message": "Happiness is low - add parks and services.", "priority": 2})

	# Education
	if GameState.population > 500 and GameState.education_rate < 0.3:
		advice.append({"advisor": "City Planner", "message": "Education is lacking - build schools.", "priority": 2})

	# Data centers
	if GameState.population >= 100 and GameState.get_total_data_centers() == 0:
		advice.append({"advisor": "City Planner", "message": "City is ready for a data center! Check requirements.", "priority": 1})

	# Sort by priority (highest first)
	advice.sort_custom(func(a, b): return a.priority > b.priority)

	return advice
