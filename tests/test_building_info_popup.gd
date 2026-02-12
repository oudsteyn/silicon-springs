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
