extends Node
class_name OrdinanceSystem
## Manages city ordinances (policies) that affect various aspects of the simulation

signal ordinance_enacted(ordinance_id: String)
signal ordinance_repealed(ordinance_id: String)

# Active ordinances
var active_ordinances: Dictionary = {}  # {id: true}

# Ordinance definitions
const ORDINANCES: Dictionary = {
	# Safety & Services
	"volunteer_fire": {
		"name": "Volunteer Fire Department",
		"description": "Reduce fire station costs by 25% but slightly decrease effectiveness.",
		"category": "safety",
		"monthly_cost": 0,
		"cost_modifier": -0.25,  # Reduces fire station maintenance
		"effects": {"fire_coverage": -0.1}
	},
	"neighborhood_watch": {
		"name": "Neighborhood Watch",
		"description": "Reduce crime by 15% citywide through community involvement.",
		"category": "safety",
		"monthly_cost": 50,
		"effects": {"crime_reduction": 0.15}
	},
	"smoke_detectors": {
		"name": "Mandatory Smoke Detectors",
		"description": "Reduce fire damage by 20% in all buildings.",
		"category": "safety",
		"monthly_cost": 100,
		"effects": {"fire_damage_reduction": 0.2}
	},

	# Environment
	"clean_air": {
		"name": "Clean Air Act",
		"description": "Reduce pollution from power plants by 30%, increases maintenance costs.",
		"category": "environment",
		"monthly_cost": 200,
		"effects": {"pollution_reduction": 0.3, "power_plant_cost": 0.2}
	},
	"water_conservation": {
		"name": "Water Conservation",
		"description": "Reduce water consumption by 15% citywide.",
		"category": "environment",
		"monthly_cost": 75,
		"effects": {"water_consumption": -0.15}
	},
	"recycling_program": {
		"name": "Recycling Program",
		"description": "Slight happiness boost and reduced industrial pollution.",
		"category": "environment",
		"monthly_cost": 100,
		"effects": {"happiness": 0.02, "industrial_pollution": -0.2}
	},
	"carbon_tax": {
		"name": "Carbon Tax",
		"description": "Reduces pollution from power plants by 40%, but increases their maintenance costs by 30%.",
		"category": "environment",
		"monthly_cost": 300,
		"effects": {"power_plant_pollution_reduction": 0.4, "power_plant_maintenance": 0.3}
	},
	"green_energy_bonus": {
		"name": "Green Energy Bonus",
		"description": "When city has 100% renewable power, earn +$100/month per clean energy building (solar, wind, nuclear).",
		"category": "environment",
		"monthly_cost": 0,
		"effects": {"clean_energy_bonus": 100}
	},
	"environmental_protection": {
		"name": "Environmental Protection Act",
		"description": "Reduces all pollution by 25% and boosts park effectiveness by 25%.",
		"category": "environment",
		"monthly_cost": 400,
		"effects": {"pollution_reduction": 0.25, "park_effectiveness": 0.25}
	},

	# Economy & Taxes
	"tax_incentive": {
		"name": "Business Tax Incentive",
		"description": "Boost commercial demand by 20%, reduce commercial tax income by 15%.",
		"category": "economy",
		"monthly_cost": 0,
		"effects": {"commercial_demand": 0.2, "commercial_tax": -0.15}
	},
	"industrial_zone": {
		"name": "Industrial Free Zone",
		"description": "Boost industrial demand by 25%, but increase pollution.",
		"category": "economy",
		"monthly_cost": 0,
		"effects": {"industrial_demand": 0.25, "industrial_pollution": 0.15}
	},
	"tech_incentive": {
		"name": "Tech Industry Incentive",
		"description": "Attract more data centers. Requires university.",
		"category": "economy",
		"monthly_cost": 300,
		"requires": ["university"],
		"effects": {"data_center_attraction": 0.3}
	},

	# Education
	"free_school_lunch": {
		"name": "Free School Lunch Program",
		"description": "Improve education effectiveness by 10%.",
		"category": "education",
		"monthly_cost": 150,
		"effects": {"education_rate": 0.1}
	},
	"literacy_program": {
		"name": "Adult Literacy Program",
		"description": "Slowly improve education of existing population.",
		"category": "education",
		"monthly_cost": 100,
		"effects": {"adult_education": 0.05}
	},

	# Transportation
	"free_transit": {
		"name": "Free Public Transit",
		"description": "Reduce traffic congestion significantly, high cost.",
		"category": "transportation",
		"monthly_cost": 500,
		"effects": {"traffic_reduction": 0.3, "happiness": 0.03}
	},
	"carpool_incentive": {
		"name": "Carpool Incentive",
		"description": "Reduce traffic by 10% through carpooling programs.",
		"category": "transportation",
		"monthly_cost": 50,
		"effects": {"traffic_reduction": 0.1}
	},

	# Quality of Life
	"public_parks": {
		"name": "Public Parks Maintenance",
		"description": "Increase happiness from parks by 50%.",
		"category": "quality",
		"monthly_cost": 100,
		"effects": {"park_effectiveness": 0.5}
	},
	"community_events": {
		"name": "Community Events",
		"description": "Monthly festivals and events boost happiness.",
		"category": "quality",
		"monthly_cost": 200,
		"effects": {"happiness": 0.05}
	},
	"homeless_shelter": {
		"name": "Homeless Shelter Program",
		"description": "Improves happiness and reduces crime slightly.",
		"category": "quality",
		"monthly_cost": 150,
		"effects": {"happiness": 0.02, "crime_reduction": 0.05}
	}
}


func _ready() -> void:
	Events.month_tick.connect(_on_month_tick)


func is_enacted(ordinance_id: String) -> bool:
	return active_ordinances.has(ordinance_id)


func can_enact(ordinance_id: String) -> Dictionary:
	var result = {"can_enact": true, "reasons": []}

	if not ORDINANCES.has(ordinance_id):
		result.can_enact = false
		result.reasons.append("Unknown ordinance")
		return result

	if is_enacted(ordinance_id):
		result.can_enact = false
		result.reasons.append("Already enacted")
		return result

	var ordinance = ORDINANCES[ordinance_id]

	# Check requirements
	if ordinance.has("requires"):
		for req in ordinance.requires:
			if not _check_requirement(req):
				result.can_enact = false
				result.reasons.append("Requires: %s" % req)

	return result


func _check_requirement(req: String) -> bool:
	match req:
		"university":
			return GameState.is_landmark_unlocked("university") and GameState.get_building_count("university") > 0
		_:
			return true


func enact_ordinance(ordinance_id: String) -> bool:
	var check = can_enact(ordinance_id)
	if not check.can_enact:
		for reason in check.reasons:
			Events.simulation_event.emit("ordinance_requirement_failed", {"reason": reason})
		return false

	active_ordinances[ordinance_id] = true
	ordinance_enacted.emit(ordinance_id)

	var ordinance = ORDINANCES[ordinance_id]
	Events.simulation_event.emit("ordinance_enacted", {"name": ordinance.name, "id": ordinance_id})
	return true


func repeal_ordinance(ordinance_id: String) -> bool:
	if not is_enacted(ordinance_id):
		return false

	active_ordinances.erase(ordinance_id)
	ordinance_repealed.emit(ordinance_id)

	var ordinance = ORDINANCES[ordinance_id]
	Events.simulation_event.emit("ordinance_repealed", {"name": ordinance.name, "id": ordinance_id})
	return true


func get_total_monthly_cost() -> int:
	var total = 0
	for ordinance_id in active_ordinances:
		if ORDINANCES.has(ordinance_id):
			total += ORDINANCES[ordinance_id].monthly_cost
	return total


# Clean energy building IDs (no pollution_radius, renewable sources)
const CLEAN_ENERGY_BUILDINGS: Array = [
	"solar_farm", "solar_plant", "wind_farm", "wind_turbine", "nuclear_plant"
]

# Dirty power plant IDs (have pollution_radius)
const DIRTY_POWER_PLANTS: Array = [
	"coal_plant", "gas_plant", "oil_plant"
]


func get_clean_energy_building_count() -> int:
	var count = 0
	for building_id in CLEAN_ENERGY_BUILDINGS:
		count += GameState.get_building_count(building_id)
	return count


func get_dirty_power_plant_count() -> int:
	var count = 0
	for building_id in DIRTY_POWER_PLANTS:
		count += GameState.get_building_count(building_id)
	return count


func is_city_100_percent_renewable() -> bool:
	# City is 100% renewable if there are no dirty power plants
	# and there is at least one clean energy building
	return get_dirty_power_plant_count() == 0 and get_clean_energy_building_count() > 0


func get_green_energy_bonus_income() -> int:
	if not is_enacted("green_energy_bonus"):
		return 0
	if not is_city_100_percent_renewable():
		return 0
	var bonus_per_building = int(get_effect("clean_energy_bonus"))
	return get_clean_energy_building_count() * bonus_per_building


func get_effect(effect_name: String) -> float:
	var total = 0.0
	for ordinance_id in active_ordinances:
		if ORDINANCES.has(ordinance_id):
			var effects = ORDINANCES[ordinance_id].get("effects", {})
			if effects.has(effect_name):
				total += effects[effect_name]
	return total


func get_all_ordinances() -> Dictionary:
	return ORDINANCES


func get_ordinances_by_category(category: String) -> Array:
	var result: Array = []
	for id in ORDINANCES:
		if ORDINANCES[id].category == category:
			result.append({"id": id, "data": ORDINANCES[id]})
	return result


func get_active_ordinances() -> Array:
	var result: Array = []
	for id in active_ordinances:
		if ORDINANCES.has(id):
			result.append({"id": id, "data": ORDINANCES[id]})
	return result


func _on_month_tick() -> void:
	# Apply monthly costs
	var cost = get_total_monthly_cost()
	if cost > 0:
		GameState.spend(cost)

	# Apply green energy bonus income
	var green_bonus = get_green_energy_bonus_income()
	if green_bonus > 0:
		GameState.earn(green_bonus)
		Events.simulation_event.emit("green_energy_bonus", {"amount": green_bonus})
