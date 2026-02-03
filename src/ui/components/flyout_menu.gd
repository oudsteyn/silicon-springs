extends Control
class_name FlyoutMenu
## Reusable cascading flyout menu component
## Supports categories with nested items, auto-closes on click-away

signal item_selected(item_id: String, item_data: Dictionary)
signal closed()

const FLYOUT_WIDTH: int = 150
const ITEM_HEIGHT: int = 32
const HOVER_DELAY: float = 0.2
const ANIMATION_DURATION: float = 0.15

# Menu data structure
# items = [
#   {id: "category1", label: "Category", icon: "...", children: [...]},
#   {id: "item1", label: "Item", icon: "...", cost: 1000, data: {...}}
# ]
var items: Array[Dictionary] = []
var flyout_id: String = ""

# Visual components
var panel: PanelContainer
var items_container: VBoxContainer
var _item_buttons: Dictionary = {}  # id: Button

# Sub-flyout management
var _active_submenu: FlyoutMenu = null
var _hover_timer: Timer = null
var _hovered_item_id: String = ""
var _parent_flyout: FlyoutMenu = null
var _animation_tween: Tween = null

# Position
var spawn_position: Vector2 = Vector2.ZERO
var spawn_direction: int = 1  # 1 = right, -1 = left

# Timing for click-outside detection (prevents immediate close on same-frame clicks)
var _spawn_time: int = 0
const CLICK_IGNORE_MS: int = 100  # Ignore clicks within 100ms of spawn


func _ready() -> void:
	_spawn_time = Time.get_ticks_msec()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_setup_hover_timer()


func _exit_tree() -> void:
	# Kill any running animation
	if _animation_tween and _animation_tween.is_valid():
		_animation_tween.kill()
		_animation_tween = null
	# Ensure submenu is cleaned up when this flyout is removed
	if _active_submenu and is_instance_valid(_active_submenu):
		_active_submenu.queue_free()
		_active_submenu = null
	if _hover_timer:
		_hover_timer.stop()


func _setup_hover_timer() -> void:
	_hover_timer = Timer.new()
	_hover_timer.one_shot = true
	_hover_timer.wait_time = HOVER_DELAY
	_hover_timer.timeout.connect(_on_hover_timer_timeout)
	add_child(_hover_timer)


func setup(menu_items: Array[Dictionary], id: String = "", spawn_pos: Vector2 = Vector2.ZERO, direction: int = 1) -> void:
	items = menu_items
	flyout_id = id
	spawn_position = spawn_pos
	spawn_direction = direction
	_build_menu()


func _build_menu() -> void:
	# Clear existing
	if panel:
		panel.queue_free()
	_item_buttons.clear()

	# Create panel
	panel = PanelContainer.new()
	panel.custom_minimum_size.x = FLYOUT_WIDTH

	# Use centralized panel style with shadow
	var style = UIManager.get_panel_style(ThemeConstants.RADIUS_MEDIUM)
	style.set_content_margin_all(ThemeConstants.MARGIN_SMALL)
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = ThemeConstants.SHADOW_SIZE_SMALL
	style.shadow_offset = Vector2(2, 2)
	panel.add_theme_stylebox_override("panel", style)

	# Items container
	items_container = VBoxContainer.new()
	items_container.add_theme_constant_override("separation", 2)
	panel.add_child(items_container)

	# Add items
	for item in items:
		_add_menu_item(item)

	# Position the panel
	panel.position = spawn_position
	add_child(panel)

	# Animate in (track tween for cleanup)
	panel.modulate.a = 0
	panel.scale = Vector2(0.95, 0.95)
	_animation_tween = create_tween()
	_animation_tween.set_parallel(true)
	_animation_tween.tween_property(panel, "modulate:a", 1.0, ANIMATION_DURATION)
	_animation_tween.tween_property(panel, "scale", Vector2.ONE, ANIMATION_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_animation_tween.chain().tween_callback(func(): _animation_tween = null)


func _add_menu_item(item: Dictionary) -> void:
	var btn = Button.new()
	btn.custom_minimum_size.y = ITEM_HEIGHT
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true

	# Check if item is locked
	var is_locked = item.get("locked", false)
	var unlock_pop = item.get("unlock_population", 0)

	# Build label with optional icon
	var label_text = ""
	if item.has("icon"):
		label_text = item.icon + "  "

	# Add lock icon for locked items
	if is_locked:
		label_text = "🔒 "

	label_text += item.get("label", item.get("id", "???"))

	# Add arrow for items with children
	if item.has("children") and item.children.size() > 0:
		btn.text = label_text
		# Add arrow indicator
		var arrow = Label.new()
		arrow.text = ">"
		arrow.add_theme_color_override("font_color", UIManager.COLORS.text_dim)
		arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		arrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# We'll add the arrow differently - append to text for now
		btn.text = label_text + "  >"
	else:
		btn.text = label_text
		# Add cost or unlock requirement
		if is_locked:
			btn.text += "  (%d pop)" % unlock_pop
		elif item.has("cost"):
			btn.text += "  $%s" % UIManager.format_number(item.cost)

	# Style based on lock state
	var text_color = UIManager.COLORS.text if not is_locked else UIManager.COLORS.text_dim
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_font_size_override("font_size", 12)

	# Use centralized button styles
	var style_normal = UIManager.get_button_normal_style()
	style_normal.bg_color = Color.TRANSPARENT
	style_normal.set_border_width_all(0)
	style_normal.set_content_margin_all(ThemeConstants.MARGIN_NORMAL)
	btn.add_theme_stylebox_override("normal", style_normal)

	if is_locked:
		# Locked items have muted hover state
		var style_hover = UIManager.get_button_hover_style()
		style_hover.bg_color = Color(0.15, 0.15, 0.15, 0.3)
		style_hover.set_content_margin_all(ThemeConstants.RADIUS_MEDIUM)
		btn.add_theme_stylebox_override("hover", style_hover)
		btn.add_theme_stylebox_override("pressed", style_hover)

		# Set tooltip explaining how to unlock
		btn.tooltip_text = "Unlocks at %d population" % unlock_pop
	else:
		var style_hover = UIManager.get_button_hover_style()
		style_hover.bg_color = UIManager.COLORS.accent.darkened(0.4)
		style_hover.set_content_margin_all(ThemeConstants.RADIUS_MEDIUM)
		btn.add_theme_stylebox_override("hover", style_hover)

		var style_pressed = UIManager.get_button_pressed_style()
		style_pressed.bg_color = UIManager.COLORS.accent.darkened(0.2)
		style_pressed.set_content_margin_all(ThemeConstants.RADIUS_MEDIUM)
		btn.add_theme_stylebox_override("pressed", style_pressed)

	# Connect signals
	var item_id = item.get("id", "")
	btn.pressed.connect(_on_item_pressed.bind(item_id, item))
	btn.mouse_entered.connect(_on_item_hover_start.bind(item_id, item))
	btn.mouse_exited.connect(_on_item_hover_end.bind(item_id))

	_item_buttons[item_id] = btn
	items_container.add_child(btn)


func _on_item_pressed(item_id: String, item: Dictionary) -> void:
	# If has children, toggle submenu on click
	if item.has("children") and item.children.size() > 0:
		if _active_submenu and _active_submenu.flyout_id == item_id:
			_close_submenu()
		else:
			_show_submenu(item_id, item)
		return

	# Check if item is locked
	if item.get("locked", false):
		# Show feedback that item is locked
		var unlock_pop = item.get("unlock_population", 0)
		var current_pop = GameState.population if GameState else 0
		var remaining = unlock_pop - current_pop
		Events.simulation_event.emit("generic_info", {
			"message": "Need %d more residents to unlock %s" % [remaining, item.get("label", "this")]
		})
		return  # Don't close menu, just show message

	# Otherwise, emit selection and close
	item_selected.emit(item_id, item)
	close_menu()


func _on_item_hover_start(item_id: String, item: Dictionary) -> void:
	_hovered_item_id = item_id

	# If item has children, start hover timer
	if item.has("children") and item.children.size() > 0:
		_hover_timer.start()
	else:
		# Close any open submenu if hovering non-parent item
		if _active_submenu:
			_close_submenu()


func _on_item_hover_end(item_id: String) -> void:
	if _hovered_item_id == item_id:
		_hovered_item_id = ""
		_hover_timer.stop()


func _on_hover_timer_timeout() -> void:
	if _hovered_item_id.is_empty():
		return

	# Find the item data
	for item in items:
		if item.get("id") == _hovered_item_id:
			if item.has("children") and item.children.size() > 0:
				_show_submenu(_hovered_item_id, item)
			break


func _show_submenu(item_id: String, item: Dictionary) -> void:
	# Close existing submenu
	_close_submenu()

	# Get button position
	var btn = _item_buttons.get(item_id)
	if not btn:
		return

	# Calculate submenu position
	var btn_global_pos = btn.global_position
	var submenu_x = btn_global_pos.x + btn.size.x + 4
	var submenu_y = btn_global_pos.y

	# Check if it would go off screen
	var screen_size = get_viewport().get_visible_rect().size
	if submenu_x + FLYOUT_WIDTH > screen_size.x:
		submenu_x = btn_global_pos.x - FLYOUT_WIDTH - 4

	# Create submenu
	_active_submenu = FlyoutMenu.new()
	_active_submenu._parent_flyout = self

	# Convert children to proper typed array
	var children: Array[Dictionary] = []
	for child in item.children:
		children.append(child)

	_active_submenu.setup(children, item_id, Vector2(submenu_x, submenu_y), spawn_direction)
	_active_submenu.item_selected.connect(_on_submenu_item_selected)
	_active_submenu.closed.connect(_on_submenu_closed)

	get_parent().add_child(_active_submenu)


func _close_submenu() -> void:
	if _active_submenu:
		# Disconnect signals first to prevent callbacks during cleanup
		if _active_submenu.item_selected.is_connected(_on_submenu_item_selected):
			_active_submenu.item_selected.disconnect(_on_submenu_item_selected)
		if _active_submenu.closed.is_connected(_on_submenu_closed):
			_active_submenu.closed.disconnect(_on_submenu_closed)
		_active_submenu.close_menu()
		_active_submenu = null


func _on_submenu_item_selected(item_id: String, item_data: Dictionary) -> void:
	# Propagate up
	item_selected.emit(item_id, item_data)
	close_menu()


func _on_submenu_closed() -> void:
	_active_submenu = null


func close_menu() -> void:
	# Close any submenu first
	_close_submenu()

	# Kill any running animation first
	if _animation_tween and _animation_tween.is_valid():
		_animation_tween.kill()
		_animation_tween = null

	# Animate out
	if panel:
		_animation_tween = create_tween()
		_animation_tween.tween_property(panel, "modulate:a", 0.0, ANIMATION_DURATION * 0.5)
		_animation_tween.tween_callback(queue_free)

	closed.emit()


func _input(event: InputEvent) -> void:
	# Close on click outside (with small delay to prevent same-frame close)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			# Ignore clicks within spawn delay (prevents closing when clicking tool button)
			if Time.get_ticks_msec() - _spawn_time < CLICK_IGNORE_MS:
				return
			if panel and not _is_point_in_menu(event.global_position):
				close_menu()


func _is_point_in_menu(point: Vector2) -> bool:
	# Check this menu
	if panel:
		var rect = Rect2(panel.global_position, panel.size)
		if rect.has_point(point):
			return true

	# Check submenu
	if _active_submenu and _active_submenu._is_point_in_menu(point):
		return true

	# Check parent's submenu (if we are a submenu)
	if _parent_flyout:
		return false  # Let parent handle this

	return false


# Helper to create a separator item
static func create_separator() -> Dictionary:
	return {"id": "_separator", "type": "separator"}


# Helper to create a standard item
static func create_item(id: String, label: String, icon: String = "", cost: int = 0, data: Dictionary = {}) -> Dictionary:
	var item = {"id": id, "label": label}
	if not icon.is_empty():
		item["icon"] = icon
	if cost > 0:
		item["cost"] = cost
	if data.size() > 0:
		item["data"] = data
	return item


# Helper to create a category with children
static func create_category(id: String, label: String, icon: String, children: Array[Dictionary]) -> Dictionary:
	return {"id": id, "label": label, "icon": icon, "children": children}
