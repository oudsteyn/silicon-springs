extends RefCounted
class_name DashboardTabBase
## Base class for dashboard tab components
## Provides common utilities for building tab content

# Status indicator colors
var COLOR_GOOD: Color:
	get: return ThemeConstants.STATUS_GOOD
var COLOR_WARNING: Color:
	get: return ThemeConstants.STATUS_WARNING
var COLOR_CRITICAL: Color:
	get: return ThemeConstants.STATUS_CRITICAL
var COLOR_NEUTRAL: Color:
	get: return ThemeConstants.STATUS_NEUTRAL


## Override in subclass to build tab content
func build_content(_container: VBoxContainer) -> void:
	push_warning("DashboardTabBase: build_content() not implemented")


## Create a section header label
func _create_section_header(text: String) -> Label:
	var header = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", ThemeConstants.FONT_MEDIUM)
	header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	return header


## Create a stat card for overview displays
func _create_stat_card(title: String, value: String, subtitle: String, color: Color) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(130, 70)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.12, 0.14, 0.18, 0.9)
	stylebox.set_corner_radius_all(ThemeConstants.RADIUS_MEDIUM)
	stylebox.content_margin_left = ThemeConstants.PADDING_NORMAL + 2
	stylebox.content_margin_right = ThemeConstants.PADDING_NORMAL + 2
	stylebox.content_margin_top = ThemeConstants.PADDING_NORMAL
	stylebox.content_margin_bottom = ThemeConstants.PADDING_NORMAL
	card.add_theme_stylebox_override("panel", stylebox)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	var title_label = Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SMALL)
	title_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	vbox.add_child(title_label)

	var value_label = Label.new()
	value_label.text = value
	value_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_LARGE)
	value_label.add_theme_color_override("font_color", color)
	vbox.add_child(value_label)

	var sub_label = Label.new()
	sub_label.text = subtitle
	sub_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SMALL - 1)
	sub_label.add_theme_color_override("font_color", color.darkened(0.2))
	vbox.add_child(sub_label)

	return card


## Add a stat row to a grid
func _add_stat_row(grid: GridContainer, label_text: String, value_text: String, color: Color = Color.WHITE) -> void:
	var label = Label.new()
	label.text = label_text + ":"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	grid.add_child(label)

	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", color if color != Color.WHITE else Color(0.9, 0.9, 0.95))
	grid.add_child(value)

	# Spacer for 3-column layout
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	grid.add_child(spacer)


## Create a progress bar for condition/status displays
func _create_condition_bar(value: float) -> ProgressBar:
	var bar = ProgressBar.new()
	bar.custom_minimum_size = Vector2(200, 16)
	bar.value = value
	bar.show_percentage = true
	if value < 40:
		bar.modulate = COLOR_CRITICAL
	elif value < 70:
		bar.modulate = COLOR_WARNING
	else:
		bar.modulate = COLOR_GOOD
	return bar


## Format a number with thousands separators
func _format_number(num: int) -> String:
	var num_str = str(num)
	var result = ""
	var count = 0
	for i in range(num_str.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = num_str[i] + result
		count += 1
	return result


## Get system reference safely
func _get_system(system_name: String) -> Node:
	if Simulation and Simulation.has_method("_get_system"):
		return Simulation._get_system(system_name)
	return null
