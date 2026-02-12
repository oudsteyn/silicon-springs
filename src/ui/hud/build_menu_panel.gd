extends PanelContainer

signal build_category_selected(category_id: String)

@onready var roads_button: Button = $Margin/Row/Roads
@onready var zoning_button: Button = $Margin/Row/Zoning
@onready var utilities_button: Button = $Margin/Row/Utilities
@onready var services_button: Button = $Margin/Row/Services

func _ready() -> void:
	roads_button.pressed.connect(_on_roads_pressed)
	zoning_button.pressed.connect(_on_zoning_pressed)
	utilities_button.pressed.connect(_on_utilities_pressed)
	services_button.pressed.connect(_on_services_pressed)

func _emit_category(category_id: String) -> void:
	build_category_selected.emit(category_id)


func _on_roads_pressed() -> void:
	_emit_category("roads")


func _on_zoning_pressed() -> void:
	_emit_category("zoning")


func _on_utilities_pressed() -> void:
	_emit_category("utilities")


func _on_services_pressed() -> void:
	_emit_category("services")
