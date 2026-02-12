extends CanvasLayer

@onready var money_label: Label = %MoneyValue
@onready var pop_label: Label = %PopulationValue
@onready var happ_label: Label = %HappinessValue
@onready var info_popup: Control = %BuildingInfoPopup

func _ready() -> void:
	if has_node("/root/CityEventBus"):
		CityEventBus.economy_changed.connect(_on_economy_changed)
		CityEventBus.population_changed.connect(_on_population_changed)
		CityEventBus.happiness_changed.connect(_on_happiness_changed)
		CityEventBus.building_selected.connect(_on_building_selected)
		CityEventBus.building_deselected.connect(_on_building_deselected)

func _on_economy_changed(money: int) -> void:
	money_label.text = "$%s" % String.num_int64(money)

func _on_population_changed(population: int) -> void:
	pop_label.text = String.num_int64(population)

func _on_happiness_changed(happiness: float) -> void:
	happ_label.text = "%d%%" % int(round(happiness * 100.0))

func _on_building_selected(building_id: String, payload: Dictionary) -> void:
	info_popup.call("show_building", building_id, payload)

func _on_building_deselected() -> void:
	info_popup.call("hide_building")
