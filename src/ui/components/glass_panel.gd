extends PanelContainer
class_name GlassPanel

@export var corner_radius: int = 16
@export var tint_color: Color = Color(0.10, 0.14, 0.18, 0.22)
@export var border_color: Color = Color(1.0, 1.0, 1.0, 0.16)
@export var intro_duration: float = 0.18

var _intro_played: bool = false


func _ready() -> void:
	apply_glass_style()
	_play_intro_if_needed()


func apply_glass_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = tint_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	add_theme_stylebox_override("panel", style)


func _play_intro_if_needed() -> void:
	if _intro_played:
		return
	_intro_played = true
	modulate.a = 0.0
	position.y += 8.0
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, intro_duration)
	tween.parallel().tween_property(self, "position:y", position.y - 8.0, intro_duration)
