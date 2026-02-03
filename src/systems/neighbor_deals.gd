extends Node
## Manages power and water deals with neighboring cities

signal deal_changed(deal_type: String)

# Deal types
enum DealType { POWER_BUY, POWER_SELL, WATER_BUY, WATER_SELL }

# Active deals
var active_deals: Dictionary = {
	"power_buy": {"active": false, "amount": 0.0, "price_per_unit": 5.0},
	"power_sell": {"active": false, "amount": 0.0, "price_per_unit": 3.0},
	"water_buy": {"active": false, "amount": 0.0, "price_per_unit": 4.0},
	"water_sell": {"active": false, "amount": 0.0, "price_per_unit": 2.5}
}

# Neighbor availability (random fluctuation)
var neighbor_power_available: float = 50.0  # MW they can sell
var neighbor_power_demand: float = 30.0     # MW they want to buy
var neighbor_water_available: float = 500.0 # ML they can sell
var neighbor_water_demand: float = 300.0    # ML they want to buy

# Prices fluctuate slightly
const BASE_POWER_BUY_PRICE: float = 5.0   # $/MW/month
const BASE_POWER_SELL_PRICE: float = 3.0
const BASE_WATER_BUY_PRICE: float = 4.0   # $/ML/month
const BASE_WATER_SELL_PRICE: float = 2.5


func _ready() -> void:
	Events.month_tick.connect(_on_month_tick)
	Events.year_tick.connect(_on_year_tick)


func _on_month_tick() -> void:
	_apply_deal_effects()


func _on_year_tick() -> void:
	_update_neighbor_conditions()


func _update_neighbor_conditions() -> void:
	# Neighbors' availability changes over time
	neighbor_power_available = 30 + randf() * 40  # 30-70 MW
	neighbor_power_demand = 20 + randf() * 30     # 20-50 MW
	neighbor_water_available = 300 + randf() * 400  # 300-700 ML
	neighbor_water_demand = 200 + randf() * 300     # 200-500 ML

	# Price fluctuation (+-20%)
	active_deals.power_buy.price_per_unit = BASE_POWER_BUY_PRICE * (0.8 + randf() * 0.4)
	active_deals.power_sell.price_per_unit = BASE_POWER_SELL_PRICE * (0.8 + randf() * 0.4)
	active_deals.water_buy.price_per_unit = BASE_WATER_BUY_PRICE * (0.8 + randf() * 0.4)
	active_deals.water_sell.price_per_unit = BASE_WATER_SELL_PRICE * (0.8 + randf() * 0.4)


func _apply_deal_effects() -> void:
	var monthly_cost = 0
	var monthly_income = 0

	# Power buying - adds to supply
	if active_deals.power_buy.active:
		var amount = min(active_deals.power_buy.amount, neighbor_power_available)
		monthly_cost += int(amount * active_deals.power_buy.price_per_unit)

	# Power selling - removes from supply
	if active_deals.power_sell.active:
		var amount = min(active_deals.power_sell.amount, neighbor_power_demand)
		monthly_income += int(amount * active_deals.power_sell.price_per_unit)

	# Water buying
	if active_deals.water_buy.active:
		var amount = min(active_deals.water_buy.amount, neighbor_water_available)
		monthly_cost += int(amount * active_deals.water_buy.price_per_unit)

	# Water selling
	if active_deals.water_sell.active:
		var amount = min(active_deals.water_sell.amount, neighbor_water_demand)
		monthly_income += int(amount * active_deals.water_sell.price_per_unit)

	# Apply financial effects
	if monthly_cost > 0:
		GameState.spend(monthly_cost)
	if monthly_income > 0:
		GameState.earn(monthly_income)


func get_effective_power_bought() -> float:
	if not active_deals.power_buy.active:
		return 0.0
	return min(active_deals.power_buy.amount, neighbor_power_available)


func get_effective_power_sold() -> float:
	if not active_deals.power_sell.active:
		return 0.0
	return min(active_deals.power_sell.amount, neighbor_power_demand)


func get_effective_water_bought() -> float:
	if not active_deals.water_buy.active:
		return 0.0
	return min(active_deals.water_buy.amount, neighbor_water_available)


func get_effective_water_sold() -> float:
	if not active_deals.water_sell.active:
		return 0.0
	return min(active_deals.water_sell.amount, neighbor_water_demand)


func set_power_buy(active: bool, amount: float) -> void:
	active_deals.power_buy.active = active
	active_deals.power_buy.amount = clamp(amount, 0, neighbor_power_available)
	deal_changed.emit("power_buy")


func set_power_sell(active: bool, amount: float) -> void:
	active_deals.power_sell.active = active
	active_deals.power_sell.amount = clamp(amount, 0, GameState.get_available_power())
	deal_changed.emit("power_sell")


func set_water_buy(active: bool, amount: float) -> void:
	active_deals.water_buy.active = active
	active_deals.water_buy.amount = clamp(amount, 0, neighbor_water_available)
	deal_changed.emit("water_buy")


func set_water_sell(active: bool, amount: float) -> void:
	active_deals.water_sell.active = active
	active_deals.water_sell.amount = clamp(amount, 0, GameState.get_available_water())
	deal_changed.emit("water_sell")


func get_monthly_deal_cost() -> int:
	var cost = 0
	if active_deals.power_buy.active:
		cost += int(get_effective_power_bought() * active_deals.power_buy.price_per_unit)
	if active_deals.water_buy.active:
		cost += int(get_effective_water_bought() * active_deals.water_buy.price_per_unit)
	return cost


func get_monthly_deal_income() -> int:
	var income = 0
	if active_deals.power_sell.active:
		income += int(get_effective_power_sold() * active_deals.power_sell.price_per_unit)
	if active_deals.water_sell.active:
		income += int(get_effective_water_sold() * active_deals.water_sell.price_per_unit)
	return income


func get_deal_summary() -> Dictionary:
	return {
		"power_buy": {
			"active": active_deals.power_buy.active,
			"amount": get_effective_power_bought(),
			"price": active_deals.power_buy.price_per_unit,
			"available": neighbor_power_available
		},
		"power_sell": {
			"active": active_deals.power_sell.active,
			"amount": get_effective_power_sold(),
			"price": active_deals.power_sell.price_per_unit,
			"demand": neighbor_power_demand
		},
		"water_buy": {
			"active": active_deals.water_buy.active,
			"amount": get_effective_water_bought(),
			"price": active_deals.water_buy.price_per_unit,
			"available": neighbor_water_available
		},
		"water_sell": {
			"active": active_deals.water_sell.active,
			"amount": get_effective_water_sold(),
			"price": active_deals.water_sell.price_per_unit,
			"demand": neighbor_water_demand
		}
	}


func cancel_all_deals() -> void:
	active_deals.power_buy.active = false
	active_deals.power_sell.active = false
	active_deals.water_buy.active = false
	active_deals.water_sell.active = false
	deal_changed.emit("all")


func get_save_data() -> Dictionary:
	return active_deals.duplicate(true)


func load_save_data(data: Dictionary) -> void:
	if data.has("power_buy"):
		active_deals.power_buy = data.power_buy.duplicate()
	if data.has("power_sell"):
		active_deals.power_sell = data.power_sell.duplicate()
	if data.has("water_buy"):
		active_deals.water_buy = data.water_buy.duplicate()
	if data.has("water_sell"):
		active_deals.water_sell = data.water_sell.duplicate()
