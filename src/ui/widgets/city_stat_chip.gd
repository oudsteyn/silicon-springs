extends GlassPanel

@onready var title_label: Label = %TitleLabel
@onready var value_label: Label = %ValueLabel


func set_stat(title: String, value: String) -> void:
	title_label.text = title
	value_label.text = value
