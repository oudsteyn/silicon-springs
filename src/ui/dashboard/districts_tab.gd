extends DashboardTabBase
class_name DashboardDistrictsTab
## Districts tab for the city dashboard - shows district-level metrics


func build_content(container: VBoxContainer) -> void:
	var district_system = _get_system("district")

	if not district_system or not district_system.has_method("get_districts"):
		_show_no_districts_message(container)
		return

	var districts = district_system.get_districts()
	if districts.size() == 0:
		_show_no_districts_message(container)
		return

	container.add_child(_create_section_header("District Overview"))

	# Summary stats
	var summary_row = HBoxContainer.new()
	summary_row.add_theme_constant_override("separation", 12)
	container.add_child(summary_row)

	summary_row.add_child(_create_stat_card(
		"Districts",
		str(districts.size()),
		"Total defined",
		COLOR_NEUTRAL
	))

	# Total population in districts
	var total_pop = 0
	for district in districts.values():
		total_pop += district.population if "population" in district else 0

	summary_row.add_child(_create_stat_card(
		"District Pop",
		_format_number(total_pop),
		"%d%% of city" % int(float(total_pop) / max(1, GameState.population) * 100),
		COLOR_NEUTRAL
	))

	# District list
	container.add_child(_create_section_header("Districts"))

	for district_id in districts:
		var district = districts[district_id]
		_add_district_row(container, district)


func _show_no_districts_message(container: VBoxContainer) -> void:
	container.add_child(_create_section_header("Districts"))

	var msg = Label.new()
	msg.text = "No districts defined yet.\n\nUse the District tool to create and manage city districts with custom policies."
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg.add_theme_font_size_override("font_size", 12)
	msg.add_theme_color_override("font_color", COLOR_NEUTRAL)
	container.add_child(msg)


func _add_district_row(container: VBoxContainer, district: Dictionary) -> void:
	var row = PanelContainer.new()
	var stylebox = StyleBoxFlat.new()
	stylebox.bg_color = Color(0.12, 0.14, 0.18, 0.8)
	stylebox.set_corner_radius_all(ThemeConstants.RADIUS_SMALL)
	stylebox.content_margin_left = ThemeConstants.PADDING_NORMAL + 2
	stylebox.content_margin_right = ThemeConstants.PADDING_NORMAL + 2
	stylebox.content_margin_top = ThemeConstants.PADDING_NORMAL
	stylebox.content_margin_bottom = ThemeConstants.PADDING_NORMAL
	row.add_theme_stylebox_override("panel", stylebox)
	container.add_child(row)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	row.add_child(hbox)

	# District name
	var name_label = Label.new()
	name_label.text = district.get("name", "Unnamed District")
	name_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_NORMAL)
	name_label.custom_minimum_size = Vector2(150, 0)
	hbox.add_child(name_label)

	# Population
	var pop_label = Label.new()
	pop_label.text = "Pop: %s" % _format_number(district.get("population", 0))
	pop_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SMALL)
	pop_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	hbox.add_child(pop_label)

	# Land value
	var lv_label = Label.new()
	lv_label.text = "LV: $%s" % _format_number(district.get("avg_land_value", 0))
	lv_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SMALL)
	lv_label.add_theme_color_override("font_color", COLOR_NEUTRAL)
	hbox.add_child(lv_label)

	# Happiness
	var happiness = district.get("happiness", 0.5)
	var happy_label = Label.new()
	happy_label.text = "Happy: %d%%" % int(happiness * 100)
	happy_label.add_theme_font_size_override("font_size", ThemeConstants.FONT_SMALL)
	happy_label.add_theme_color_override("font_color", COLOR_GOOD if happiness >= 0.7 else (COLOR_WARNING if happiness >= 0.4 else COLOR_CRITICAL))
	hbox.add_child(happy_label)
