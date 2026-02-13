extends TestBase

const PopupScene = preload("res://src/ui/hud/building_info_popup.tscn")

class FakeBus extends Node:
	signal building_stats_changed(building_id: String, payload: Dictionary)

func test_update_building_stats_refreshes_visible_values() -> void:
	var bus = FakeBus.new()
	var popup = PopupScene.instantiate()
	popup.set_event_bus(bus)
	add_child(bus)
	add_child(popup)

	popup.show_building("b-1", {"name": "Clinic", "workers": 3, "workers_capacity": 10, "efficiency": 0.5, "upkeep": 120})
	bus.building_stats_changed.emit("b-1", {"workers": 7, "workers_capacity": 10, "efficiency": 0.8})

	assert_eq((popup.get_node("Margin/VBox/Workers") as Label).text, "7 / 10")
	assert_eq((popup.get_node("Margin/VBox/Efficiency") as Label).text, "80%")

	popup.free()
	bus.free()


func test_set_event_bus_rebinds_and_disconnects_old_bus() -> void:
	var bus_a = FakeBus.new()
	var bus_b = FakeBus.new()
	var popup = PopupScene.instantiate()
	popup.set_event_bus(bus_a)
	add_child(bus_a)
	add_child(bus_b)
	add_child(popup)

	popup.show_building("b-1", {"name": "Clinic", "workers": 1, "workers_capacity": 10, "efficiency": 0.5, "upkeep": 120})
	bus_a.building_stats_changed.emit("b-1", {"workers": 3, "workers_capacity": 10, "efficiency": 0.6})

	popup.set_event_bus(bus_b)
	bus_a.building_stats_changed.emit("b-1", {"workers": 9, "workers_capacity": 10, "efficiency": 0.9})
	bus_b.building_stats_changed.emit("b-1", {"workers": 5, "workers_capacity": 10, "efficiency": 0.7})

	assert_eq((popup.get_node("Margin/VBox/Workers") as Label).text, "5 / 10")
	assert_eq((popup.get_node("Margin/VBox/Efficiency") as Label).text, "70%")

	popup.free()
	bus_a.free()
	bus_b.free()


func test_set_event_bus_same_bus_does_not_duplicate_connections() -> void:
	var bus = FakeBus.new()
	var popup = PopupScene.instantiate()
	popup.set_event_bus(bus)
	add_child(bus)
	add_child(popup)

	popup.set_event_bus(bus)
	popup.set_event_bus(bus)

	assert_eq(bus.building_stats_changed.get_connections().size(), 1)

	popup.free()
	bus.free()


func test_action_buttons_enable_only_when_building_selected() -> void:
	var popup = PopupScene.instantiate()
	add_child(popup)

	var upgrade_button := popup.get_node("Margin/VBox/Actions/UpgradeButton") as Button
	var demolish_button := popup.get_node("Margin/VBox/Actions/DemolishButton") as Button
	assert_true(upgrade_button.disabled)
	assert_true(demolish_button.disabled)

	popup.hide_building()
	assert_true(upgrade_button.disabled)
	assert_true(demolish_button.disabled)

	popup.show_building("b-42", {"name": "Depot"})
	assert_false(upgrade_button.disabled)
	assert_false(demolish_button.disabled)

	popup.free()
