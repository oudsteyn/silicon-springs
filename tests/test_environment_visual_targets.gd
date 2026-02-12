extends TestBase

const EnvironmentResource = preload("res://src/graphics/environments/city_day_night_environment.tres")

func test_baseline_environment_within_target_ranges() -> void:
	var env = EnvironmentResource
	assert_true(env.ssao_enabled)
	assert_true(env.ssr_enabled)
	assert_true(env.volumetric_fog_enabled)
	assert_gte(env.tonemap_exposure, 0.95)
	assert_lte(env.tonemap_exposure, 1.25)
	assert_gte(env.tonemap_white, 1.0)
	assert_lte(env.tonemap_white, 1.5)
	assert_gte(env.volumetric_fog_density, 0.008)
	assert_lte(env.volumetric_fog_density, 0.03)
