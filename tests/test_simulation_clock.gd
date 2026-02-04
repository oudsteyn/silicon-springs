extends TestBase
## Tests for SimulationClock.

const SimulationClock = preload("res://src/systems/simulation_clock.gd")


func test_advance_ticks_after_threshold() -> void:
	var clock = SimulationClock.new([0.0, 2.0, 1.0], ["Paused", "Slow", "Fast"], 1)
	assert_false(clock.advance(1.0))
	assert_approx(clock.tick_timer, 1.0, 0.0001)

	assert_true(clock.advance(1.1))
	assert_approx(clock.tick_timer, 0.1, 0.0001)


func test_pause_and_speed_clamp() -> void:
	var clock = SimulationClock.new([0.0, 5.0], ["Paused", "Slow"], 1)
	clock.set_speed(0)
	assert_true(clock.is_paused)
	assert_eq(clock.get_speed_name(), "Paused")

	clock.toggle_pause()
	assert_false(clock.is_paused)

	clock.set_speed(99)
	assert_eq(clock.current_speed, 1)
	assert_eq(clock.get_speed_name(), "Slow")

	# Paused clocks do not advance
	clock.set_speed(0)
	clock.tick_timer = 0.0
	assert_false(clock.advance(10.0))
	assert_approx(clock.tick_timer, 0.0, 0.0001)
