extends Node

signal economy_changed(money: int)
signal population_changed(population: int)
signal happiness_changed(happiness: float)

signal finance_snapshot_updated(balance: int, income: int, expenses: int)
signal finance_panel_toggled(visible: bool)

signal build_mode_changed(mode_id: String)
signal building_selected(building_id: String, payload: Dictionary)
signal building_deselected()
signal building_stats_changed(building_id: String, payload: Dictionary)


func _ready() -> void:
	if not build_mode_changed.is_connected(_process_build_mode_request):
		build_mode_changed.connect(_process_build_mode_request)

	var events = get_node_or_null("/root/Events")
	if events == null:
		return

	if not events.budget_updated.is_connected(_on_budget_updated):
		events.budget_updated.connect(_on_budget_updated)
	if not events.population_changed.is_connected(_on_population_changed):
		events.population_changed.connect(_on_population_changed)
	if not events.happiness_changed.is_connected(_on_happiness_changed):
		events.happiness_changed.connect(_on_happiness_changed)
	if not events.build_mode_entered.is_connected(_on_build_mode_entered):
		events.build_mode_entered.connect(_on_build_mode_entered)
	if not events.building_selected.is_connected(_on_building_selected):
		events.building_selected.connect(_on_building_selected)
	if not events.building_deselected.is_connected(_on_building_deselected):
		events.building_deselected.connect(_on_building_deselected)
	if not events.building_info_ready.is_connected(_on_building_info_ready):
		events.building_info_ready.connect(_on_building_info_ready)


func _on_budget_updated(balance: int, income: int, expenses: int) -> void:
	economy_changed.emit(balance)
	finance_snapshot_updated.emit(balance, income, expenses)


func _on_population_changed(new_population: int, _delta: int) -> void:
	population_changed.emit(new_population)


func _on_happiness_changed(new_happiness: float) -> void:
	happiness_changed.emit(new_happiness)


func _on_build_mode_entered(mode_id: String) -> void:
	build_mode_changed.emit(mode_id)


func _process_build_mode_request(mode_id: String) -> void:
	var events = get_node_or_null("/root/Events")
	if events == null:
		return

	var mapped_id = _map_build_mode_to_building_id(mode_id)
	# Avoid feeding already-normalized ids back into Events, which causes
	# recursive build_mode_entered -> build_mode_changed loops.
	if mapped_id != "" and mapped_id != mode_id:
		events.build_mode_entered.emit(mapped_id)


func _on_building_selected(building: Node2D) -> void:
	if building == null:
		return

	var building_id = str(building.get_instance_id())
	var payload = _make_payload(building)
	building_selected.emit(building_id, payload)


func _on_building_deselected() -> void:
	building_deselected.emit()


func _on_building_info_ready(building: Node2D, info: Dictionary) -> void:
	if building == null:
		return
	building_stats_changed.emit(str(building.get_instance_id()), info)


func _make_payload(building: Node2D) -> Dictionary:
	var payload: Dictionary = {}
	var building_data = building.get("building_data")
	if building_data:
		payload["name"] = building_data.display_name if building_data.get("display_name") else "Building"
		payload["upkeep"] = building_data.maintenance_cost if building_data.get("maintenance_cost") else 0

	payload["status"] = "Operational" if building.get("is_operational") else "Offline"
	payload["workers"] = building.get("workers") if building.get("workers") != null else 0
	payload["workers_capacity"] = building.get("workers_required") if building.get("workers_required") != null else 0
	payload["efficiency"] = building.get("efficiency") if building.get("efficiency") != null else 0.0
	return payload


func _map_build_mode_to_building_id(mode_id: String) -> String:
	match mode_id:
		"roads":
			return "road"
		"zoning":
			return "residential_zone"
		"utilities":
			return "power_line"
		"services":
			return "police_station"
		_:
			return mode_id
