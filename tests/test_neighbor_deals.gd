extends TestBase
## Tests for NeighborDeals system

const NeighborDealsScript = preload("res://src/systems/neighbor_deals.gd")

var _to_free: Array = []


func before_each() -> void:
	GameState.reset_game()


func after_each() -> void:
	for i in range(_to_free.size() - 1, -1, -1):
		var instance = _to_free[i]
		if is_instance_valid(instance):
			instance.free()
	_to_free.clear()


func _track(instance):
	_to_free.append(instance)
	return instance


func test_set_power_buy_activates_deal() -> void:
	var deals = _track(NeighborDealsScript.new())

	deals.set_power_buy(true, 10.0)

	assert_true(deals.active_deals.power_buy.active)
	assert_approx(deals.get_effective_power_bought(), 10.0)


func test_set_power_buy_clamps_to_available() -> void:
	var deals = _track(NeighborDealsScript.new())
	deals.neighbor_power_available = 20.0

	deals.set_power_buy(true, 50.0)

	assert_approx(deals.active_deals.power_buy.amount, 20.0, 0.01)


func test_set_power_sell_emits_deal_changed() -> void:
	var deals = _track(NeighborDealsScript.new())
	var emitted: Array = []
	deals.deal_changed.connect(func(t): emitted.append(t))

	deals.set_power_sell(true, 5.0)

	assert_eq(emitted.size(), 1)
	assert_eq(emitted[0], "power_sell")


func test_effective_power_sold_zero_when_inactive() -> void:
	var deals = _track(NeighborDealsScript.new())

	assert_approx(deals.get_effective_power_sold(), 0.0)


func test_effective_water_bought_capped_by_neighbor() -> void:
	var deals = _track(NeighborDealsScript.new())
	deals.neighbor_water_available = 100.0
	deals.set_water_buy(true, 200.0)

	assert_approx(deals.get_effective_water_bought(), 100.0)


func test_get_monthly_deal_cost_aggregates() -> void:
	var deals = _track(NeighborDealsScript.new())
	deals.active_deals.power_buy.price_per_unit = 5.0
	deals.active_deals.water_buy.price_per_unit = 4.0
	deals.neighbor_power_available = 100.0
	deals.neighbor_water_available = 100.0

	deals.set_power_buy(true, 10.0)
	deals.set_water_buy(true, 10.0)

	# 10 * 5 + 10 * 4 = 90
	assert_eq(deals.get_monthly_deal_cost(), 90)


func test_get_monthly_deal_income_aggregates() -> void:
	var deals = _track(NeighborDealsScript.new())
	deals.active_deals.power_sell.price_per_unit = 3.0
	deals.active_deals.water_sell.price_per_unit = 2.0
	deals.neighbor_power_demand = 100.0
	deals.neighbor_water_demand = 100.0
	# Ensure GameState has available power/water so set_*_sell doesn't clamp to 0
	GameState.power_supply = 100.0
	GameState.power_demand = 0.0
	GameState.water_supply = 100.0
	GameState.water_demand = 0.0

	deals.set_power_sell(true, 10.0)
	deals.set_water_sell(true, 10.0)

	# 10 * 3 + 10 * 2 = 50
	assert_eq(deals.get_monthly_deal_income(), 50)


func test_cancel_all_deals_deactivates_everything() -> void:
	var deals = _track(NeighborDealsScript.new())
	deals.set_power_buy(true, 10.0)
	deals.set_water_sell(true, 5.0)

	deals.cancel_all_deals()

	assert_false(deals.active_deals.power_buy.active)
	assert_false(deals.active_deals.power_sell.active)
	assert_false(deals.active_deals.water_buy.active)
	assert_false(deals.active_deals.water_sell.active)


func test_get_deal_summary_structure() -> void:
	var deals = _track(NeighborDealsScript.new())
	var summary = deals.get_deal_summary()

	assert_true(summary.has("power_buy"))
	assert_true(summary.has("power_sell"))
	assert_true(summary.has("water_buy"))
	assert_true(summary.has("water_sell"))
	assert_true(summary.power_buy.has("active"))
	assert_true(summary.power_buy.has("amount"))
	assert_true(summary.power_buy.has("price"))


func test_save_and_load_round_trip() -> void:
	var deals = _track(NeighborDealsScript.new())
	GameState.water_supply = 100.0
	GameState.water_demand = 0.0
	deals.set_power_buy(true, 15.0)
	deals.set_water_sell(true, 8.0)

	var save_data = deals.get_save_data()
	var deals2 = _track(NeighborDealsScript.new())
	deals2.load_save_data(save_data)

	assert_true(deals2.active_deals.power_buy.active)
	assert_approx(deals2.active_deals.power_buy.amount, 15.0)
	assert_true(deals2.active_deals.water_sell.active)
	assert_approx(deals2.active_deals.water_sell.amount, 8.0)


func test_apply_deal_effects_spends_and_earns() -> void:
	var deals = _track(NeighborDealsScript.new())
	GameState.budget = 10000
	deals.active_deals.power_buy.price_per_unit = 5.0
	deals.neighbor_power_available = 100.0
	deals.set_power_buy(true, 10.0)

	deals._apply_deal_effects()

	# Should have spent 10 * 5 = 50
	assert_eq(GameState.budget, 10000 - 50)
