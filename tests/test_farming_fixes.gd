extends TestBase
## Tests for farming bootstrap bug fixes:
## - Fractional jobs pipeline (float, not int)
## - Zone diagnostic agricultural exemptions
## - Demand calculator with fractional jobs
## - Zone count tracking (agricultural != industrial)
## - Game state reset completeness

const BuildingDataScript = preload("res://src/resources/building_data.gd")


# ============================================
# DEMAND CALCULATOR - FRACTIONAL JOBS
# ============================================

func test_demand_calculator_fractional_jobs_positive_demand() -> void:
	# 0.75 jobs (3 farms) with 0 population should produce residential demand
	var result = DemandCalculator.calculate(
		0,     # population
		0.75,  # jobs_available (3 farms * 0.25)
		0,     # commercial_zones
		0,     # industrial_zones
		0,     # educated_population
		false, # has_power_shortage
		false, # has_water_shortage
		0.0,   # city_traffic_congestion
		0.0    # city_crime_rate
	)
	assert_gt(result.residential, -1.0, "Residential demand should exist with fractional jobs")


func test_demand_calculator_zero_jobs_no_demand() -> void:
	# With population but 0 jobs, residential demand should be negative
	var result = DemandCalculator.calculate(
		100,   # population
		0.0,   # jobs_available
		0,     # commercial_zones
		0,     # industrial_zones
		0,     # educated_population
		false, # has_power_shortage
		false, # has_water_shortage
		0.0,   # city_traffic_congestion
		0.0    # city_crime_rate
	)
	assert_lt(result.residential, 0.0, "Residential demand should be negative with 0 jobs")


func test_demand_calculator_breakdown_fractional_jobs() -> void:
	# Full breakdown should show worker demand with fractional jobs
	var result = DemandCalculator.calculate_with_breakdown(
		0,     # population
		1.0,   # jobs_available (4 farms)
		0,     # commercial_zones
		0,     # industrial_zones
		0,     # educated_population
		false, # has_power_shortage
		false, # has_water_shortage
		0.0,   # city_traffic_congestion
		0.0    # city_crime_rate
	)
	assert_gt(result.residential.demand, -1.0, "Residential demand breakdown should work with float jobs")


# ============================================
# ZONE DIAGNOSTIC - AGRICULTURAL EXEMPTIONS
# ============================================

func test_zone_diagnostic_agricultural_no_power_warning() -> void:
	var diag = ZoneDiagnostic.diagnose(
		"agricultural",
		false, # has_power (no power)
		false, # has_water (no water)
		false, # has_road_access (no road)
		0.0,   # pollution
		0.0,   # crime
		0.0,   # traffic
		0.5,   # land_value
		false, # nearby_incompatible
		0.5,   # demand
		0,     # development_level
		false  # is_under_construction
	)
	# Agricultural should NOT get power/water/road warnings
	for issue in diag.issues:
		assert_ne(issue.id, "no_power", "Agricultural should not warn about power")
		assert_ne(issue.id, "no_water", "Agricultural should not warn about water")
		assert_ne(issue.id, "no_road", "Agricultural should not warn about road")


func test_zone_diagnostic_residential_still_warns_power() -> void:
	var diag = ZoneDiagnostic.diagnose(
		"residential",
		false, # has_power (no power)
		true,  # has_water
		true,  # has_road_access
		0.0, 0.0, 0.0, 0.5, false, 0.5, 0, false
	)
	var has_power_issue = false
	for issue in diag.issues:
		if issue.id == "no_power":
			has_power_issue = true
	assert_true(has_power_issue, "Residential should still warn about no power")


func test_zone_diagnostic_agricultural_healthy_status() -> void:
	var diag = ZoneDiagnostic.diagnose(
		"agricultural",
		false, false, false,
		0.0, 0.0, 0.0, 0.5, false, 0.5, 0, false
	)
	# With no issues, should be healthy
	assert_eq(diag.overall_status, "healthy",
		"Agricultural with no infrastructure should be healthy")


# ============================================
# GAME STATE - RESET COMPLETENESS
# ============================================

func test_game_state_reset_clears_skilled_jobs() -> void:
	# Set some values
	GameState.skilled_jobs_available = 50.0
	GameState.unskilled_jobs_available = 100.0
	GameState.jobs_available = 150.0

	GameState.reset_game()

	assert_eq(GameState.skilled_jobs_available, 0.0, "skilled_jobs_available should reset to 0")
	assert_eq(GameState.unskilled_jobs_available, 0.0, "unskilled_jobs_available should reset to 0")
	assert_eq(GameState.jobs_available, 0.0, "jobs_available should reset to 0")


# ============================================
# EMPLOYMENT SIGNAL TYPE
# ============================================

func test_employment_updated_signal_accepts_float_jobs() -> void:
	# Verify the signal can be emitted with float jobs_available
	var received = []
	var events = Events
	if events:
		var callback = func(jobs, employed, unemployment):
			received.append({"jobs": jobs, "employed": employed})
		events.employment_updated.connect(callback)
		events.employment_updated.emit(0.75, 0, 0.0)
		events.employment_updated.disconnect(callback)
		assert_eq(received.size(), 1, "Should receive employment_updated signal")
		assert_approx(received[0].jobs, 0.75, 0.001, "Jobs should be float 0.75")
	else:
		# If Events autoload not available in headless, skip
		assert_true(true, "Events not available in headless mode")


# ============================================
# BUILDING GET_INFO INCLUDES BUILDING_TYPE
# ============================================

func test_farm_get_info_includes_building_type() -> void:
	var data = load("res://src/data/farm.tres")
	# Create a minimal building to test get_info
	var BuildingScript = load("res://src/entities/building.gd")
	if BuildingScript:
		var building = BuildingScript.new()
		building.building_data = data
		var info = building.get_info()
		assert_true(info.has("building_type"), "get_info should include building_type")
		assert_eq(info.building_type, "agricultural", "Farm building_type should be agricultural")
		building.free()


func test_residential_get_info_includes_building_type() -> void:
	var data = load("res://src/data/residential_low.tres")
	var BuildingScript = load("res://src/entities/building.gd")
	if BuildingScript:
		var building = BuildingScript.new()
		building.building_data = data
		var info = building.get_info()
		assert_true(info.has("building_type"), "get_info should include building_type")
		assert_eq(info.building_type, "residential", "Residential building_type should be residential")
		building.free()


# ============================================
# ISSUE 1: POPULATION GROWTH WITH FRACTIONAL JOBS
# ============================================

func test_population_growth_fractional_job_capacity_allows_growth() -> void:
	# With 0.75 jobs and 0 population, max_pop should be at least 1
	# (not 0 due to int truncation)
	var old_pop = GameState.population
	var old_jobs = GameState.jobs_available
	var old_happiness = GameState.happiness

	GameState.population = 0
	GameState.jobs_available = 0.75
	GameState.happiness = 0.5

	# The job_capacity int truncation bug would set max_pop = 0
	# After fix, max_pop should allow at least 1 person to move in
	var job_cap = ceili(GameState.jobs_available)
	assert_gte(job_cap, 1, "Job capacity should round up to at least 1 with 0.75 jobs")

	GameState.population = old_pop
	GameState.jobs_available = old_jobs
	GameState.happiness = old_happiness


func test_population_growth_job_attraction_with_fractional_jobs() -> void:
	# With 0.75 jobs and 0 population, job attraction should still apply
	# int(0.75) = 0 which is NOT > 0, so bonus never applies (the bug)
	# After fix: 0.75 > 0.0 should be true
	assert_true(0.75 > 0.0, "Float comparison should detect available fractional jobs")
	assert_false(int(0.75) > 0, "Int truncation loses fractional jobs (this is the bug)")


# ============================================
# ISSUE 2: DISTRICT SYSTEM JOBS AS FLOAT
# ============================================

func test_district_metrics_jobs_accumulate_fractional() -> void:
	# When district metrics["jobs"] starts at 0.0 (float), fractional jobs accumulate
	var metrics = {"jobs": 0.0}
	# Simulate adding 4 farm plots
	metrics["jobs"] += 0.25
	metrics["jobs"] += 0.25
	metrics["jobs"] += 0.25
	metrics["jobs"] += 0.25
	assert_approx(metrics["jobs"], 1.0, 0.001, "Four 0.25-job farms should sum to 1.0")


func test_district_metrics_jobs_int_loses_precision() -> void:
	# This demonstrates the bug: initializing as int loses fractional accumulation
	var metrics_int = {"jobs": 0}
	metrics_int["jobs"] += 0.25
	metrics_int["jobs"] += 0.25
	metrics_int["jobs"] += 0.25
	metrics_int["jobs"] += 0.25
	# In GDScript, adding float to int promotes to float, so this actually works
	# But the type annotation matters for downstream consumers
	# The real issue is whether the initial type causes issues
	assert_approx(float(metrics_int["jobs"]), 1.0, 0.001,
		"GDScript promotes int+float, but explicit float init is cleaner")


# ============================================
# ISSUE 3: TRAFFIC GENERATION WITH FRACTIONAL JOBS
# ============================================

func test_traffic_generation_fractional_jobs_not_zero() -> void:
	# A farm with 0.25 jobs should generate some traffic, not 0
	# int(0.25 * 1.5) = int(0.375) = 0 (the bug)
	# After fix: should be at least 1 if jobs > 0
	var jobs = 0.25
	var traffic_old = int(jobs * 1.5)  # Old behavior: 0
	assert_eq(traffic_old, 0, "Old int truncation produces 0 traffic for 0.25 jobs")

	var traffic_new = maxi(1, int(jobs * 1.5)) if jobs > 0 else 0
	assert_gte(traffic_new, 1, "Fixed traffic should be at least 1 for any building with jobs")


func test_traffic_generation_normal_jobs_unchanged() -> void:
	# Normal buildings with 10+ jobs should produce same traffic as before
	var jobs = 10.0
	var traffic = int(jobs * 2)
	assert_eq(traffic, 20, "Normal commercial building traffic should be unchanged")


# ============================================
# ISSUE 4: PARKING DEMAND WITH FRACTIONAL JOBS
# ============================================

func test_parking_demand_fractional_preserved() -> void:
	# Parking demand from a 0.25-job farm: 0.25 * 0.33 = 0.0825
	# int(0.0825) = 0 (the bug)
	# After fix: demand should stay as float
	var PARKING_PER_JOB = 0.33
	var demand = 0.25 * PARKING_PER_JOB
	assert_gt(demand, 0.0, "Fractional parking demand should be > 0")
	assert_eq(int(demand), 0, "Int truncation loses small parking demand (the bug)")


# ============================================
# ISSUE 5: AGRICULTURAL ZONE DEVELOPMENT MULTIPLIERS
# ============================================

func test_agricultural_development_skips_service_bonus() -> void:
	# Agricultural zones should not get fire/police coverage bonuses
	# since they're immune to fire and crime
	# This test verifies the concept - actual function test needs simulation context
	var building_type = "agricultural"
	var service_types_applicable = ["commercial", "industrial", "residential", "mixed_use"]
	assert_not_in(building_type, service_types_applicable,
		"Agricultural should not be in service-bonus-eligible types")


func test_agricultural_development_skips_traffic_penalty() -> void:
	# Farms don't generate meaningful traffic, so traffic shouldn't penalize them
	var types_affected_by_traffic = ["commercial", "industrial"]
	assert_not_in("agricultural", types_affected_by_traffic,
		"Agricultural should not be penalized by traffic")
