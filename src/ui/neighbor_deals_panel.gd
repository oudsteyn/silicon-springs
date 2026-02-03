extends PanelContainer
class_name NeighborDealsPanel
## UI panel for managing power and water deals with neighbors

signal closed()

var neighbor_deals: Node = null

@onready var close_button: Button = $MarginContainer/VBox/TitleBar/CloseButton
@onready var deals_container: VBoxContainer = $MarginContainer/VBox/ScrollContainer/DealsContainer
@onready var summary_label: Label = $MarginContainer/VBox/SummaryLabel


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	visible = false
	_apply_styling()


func _apply_styling() -> void:
	# Apply centralized panel styling
	var style = UIManager.get_modal_style()
	add_theme_stylebox_override("panel", style)

	# Style summary label
	if summary_label:
		summary_label.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
		summary_label.add_theme_font_size_override("font_size", 12)


func set_neighbor_deals(system: Node) -> void:
	neighbor_deals = system
	neighbor_deals.deal_changed.connect(_on_deal_changed)


func show_panel() -> void:
	_refresh_ui()
	visible = true


func hide_panel() -> void:
	visible = false


func _refresh_ui() -> void:
	if not neighbor_deals:
		return

	# Clear existing
	for child in deals_container.get_children():
		child.queue_free()

	var summary = neighbor_deals.get_deal_summary()

	# Power Buy
	_create_deal_row(
		"Buy Power",
		summary.power_buy,
		"MW available from neighbor: %.0f" % summary.power_buy.available,
		func(active, amount): neighbor_deals.set_power_buy(active, amount)
	)

	# Power Sell
	_create_deal_row(
		"Sell Power",
		summary.power_sell,
		"Neighbor wants: %.0f MW" % summary.power_sell.demand,
		func(active, amount): neighbor_deals.set_power_sell(active, amount)
	)

	# Separator
	var sep = HSeparator.new()
	deals_container.add_child(sep)

	# Water Buy
	_create_deal_row(
		"Buy Water",
		summary.water_buy,
		"ML available from neighbor: %.0f" % summary.water_buy.available,
		func(active, amount): neighbor_deals.set_water_buy(active, amount)
	)

	# Water Sell
	_create_deal_row(
		"Sell Water",
		summary.water_sell,
		"Neighbor wants: %.0f ML" % summary.water_sell.demand,
		func(active, amount): neighbor_deals.set_water_sell(active, amount)
	)

	_update_summary()


func _create_deal_row(title: String, data: Dictionary, availability_text: String, callback: Callable) -> void:
	var vbox = VBoxContainer.new()

	# Title row
	var title_hbox = HBoxContainer.new()

	var checkbox = CheckBox.new()
	checkbox.text = title
	checkbox.button_pressed = data.active
	title_hbox.add_child(checkbox)

	var price_label = Label.new()
	price_label.text = " ($%.1f/unit)" % data.price
	price_label.modulate = Color(0.7, 0.7, 0.7)
	title_hbox.add_child(price_label)

	vbox.add_child(title_hbox)

	# Amount row
	var amount_hbox = HBoxContainer.new()

	var amount_label = Label.new()
	amount_label.text = "Amount: "
	amount_hbox.add_child(amount_label)

	var slider = HSlider.new()
	slider.min_value = 0
	slider.max_value = data.get("available", data.get("demand", 100))
	slider.value = data.amount
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.editable = data.active
	amount_hbox.add_child(slider)

	var value_label = Label.new()
	value_label.text = "%.0f" % data.amount
	value_label.custom_minimum_size.x = 50
	amount_hbox.add_child(value_label)

	vbox.add_child(amount_hbox)

	# Availability text
	var avail_label = Label.new()
	avail_label.text = availability_text
	avail_label.modulate = Color(0.6, 0.6, 0.6)
	avail_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(avail_label)

	deals_container.add_child(vbox)

	# Connect signals
	checkbox.toggled.connect(func(pressed):
		slider.editable = pressed
		callback.call(pressed, slider.value)
		_update_summary()
	)

	slider.value_changed.connect(func(value):
		value_label.text = "%.0f" % value
		if checkbox.button_pressed:
			callback.call(true, value)
		_update_summary()
	)


func _update_summary() -> void:
	if not neighbor_deals:
		return

	var cost = neighbor_deals.get_monthly_deal_cost()
	var income = neighbor_deals.get_monthly_deal_income()
	var net = income - cost

	var net_str = ""
	if net >= 0:
		net_str = "+$%d/mo" % net
		summary_label.modulate = Color.GREEN
	else:
		net_str = "-$%d/mo" % abs(net)
		summary_label.modulate = Color.RED

	summary_label.text = "Monthly: Cost $%d | Income $%d | Net: %s" % [cost, income, net_str]


func _on_deal_changed(_deal_type: String) -> void:
	if visible:
		_update_summary()


func _on_close_pressed() -> void:
	hide_panel()
	closed.emit()
