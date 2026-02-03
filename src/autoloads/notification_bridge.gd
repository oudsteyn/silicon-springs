extends Node
class_name NotificationBridgeClass
## Bridges simulation events to UI notifications
## Keeps simulation logic UI-agnostic by translating events to user-facing messages

# Message templates for simulation events
const EVENT_MESSAGES: Dictionary = {
	# Financial events
	"insufficient_funds": {"message": "Cannot afford ${cost}", "type": "error"},
	"budget_warning": {"message": "Warning: Budget in the red!", "type": "warning"},
	"budget_critical": {"message": "Debt continues - cut expenses!", "type": "warning"},
	"bankruptcy": {"message": "BANKRUPTCY! City services failing!", "type": "error"},

	# Disaster events
	"disaster_fire": {"message": "Fire at ({cell_x}, {cell_y})!", "type": "warning"},
	"disaster_fire_major": {"message": "Major fire outbreak!", "type": "error"},
	"disaster_earthquake": {"message": "Earthquake! Buildings damaged!", "type": "error"},
	"disaster_tornado": {"message": "Tornado touchdown!", "type": "error"},
	"disaster_flood": {"message": "Flooding in low-lying areas!", "type": "error"},
	"disaster_meteor": {"message": "Meteor strike! Catastrophic damage!", "type": "error"},
	"disaster_monster": {"message": "Giant monster attacking the city!", "type": "error"},
	"disaster_ended": {"message": "{disaster_type} disaster has ended.", "type": "info"},
	"buildings_collapsed": {"message": "{count} buildings collapsed!", "type": "error"},

	# Weather events
	"front_passage": {"message": "{type} front passing through - expect weather changes.", "type": "info"},
	"front_approaching": {"message": "{type} front approaching in {days} days.", "type": "info"},
	"pressure_falling": {"message": "Barometric pressure falling - unsettled weather ahead.", "type": "info"},
	"storm_started": {"message": "Storm warning! Severe weather approaching.", "type": "warning"},
	"storm_ended": {"message": "Storm has passed. Conditions improving.", "type": "info"},
	"storm_damage": {"message": "Storm causing infrastructure damage!", "type": "warning"},
	"storm_building_damage": {"message": "Storm damaged {count} buildings!", "type": "warning"},
	"flood_started": {"message": "Flood warning! Low-lying areas at risk.", "type": "error"},
	"flood_ended": {"message": "Flood waters have receded.", "type": "info"},
	"flood_damage": {"message": "Flooding affecting buildings in low areas!", "type": "warning"},
	"flood_building_damage": {"message": "Flood damaged {count} buildings!", "type": "warning"},
	"water_pressure_low": {"message": "Water pressure dropping to {pressure}%. Consider adding water towers or pumping stations.", "type": "warning"},
	"water_pressure_critical": {"message": "Critical water pressure ({pressure}%)! Distant buildings losing water service.", "type": "error"},
	"water_pressure_restored": {"message": "Water pressure restored to normal levels.", "type": "success"},
	"heat_wave_started": {"message": "Heat wave warning! Extreme temperatures expected. Cooling costs and water demand will increase.", "type": "warning"},
	"heat_wave_ended": {"message": "Heat wave has ended. Temperatures and water demand returning to normal.", "type": "info"},
	"high_water_demand": {"message": "Hot weather increasing water demand by {percent}%.", "type": "info"},
	"cold_snap_started": {"message": "Cold snap warning! Dangerously low temperatures. Heating costs will increase.", "type": "warning"},
	"cold_snap_ended": {"message": "Cold snap has ended. Temperatures moderating.", "type": "info"},
	"climate_report": {"message": "Climate report: +{warming:.1f}C warming over {years} years.", "type": "info"},

	# Air quality events
	"air_quality_changed": {"message": "Air quality changed to {category}.", "type": "info"},
	"smog_alert_started": {"message": "SMOG ALERT! Air quality is {category}. Limit outdoor activities.", "type": "warning"},
	"smog_alert_ended": {"message": "Smog alert lifted. Air quality improving.", "type": "success"},
	"inversion_started": {"message": "Temperature inversion detected. Pollution may accumulate.", "type": "info"},
	"inversion_ended": {"message": "Temperature inversion has lifted. Air mixing resumed.", "type": "info"},
	"rain_clearing_pollution": {"message": "Rain is washing pollutants from the air.", "type": "info"},

	# Wildfire events
	"wildfire_started": {"message": "Regional wildfire detected! Smoke affecting air quality.", "type": "warning"},
	"wildfire_ongoing": {"message": "Wildfire continues (day {duration}). Air quality degraded.", "type": "warning"},
	"wildfire_ended": {"message": "{message}", "type": "success"},

	# Ordinance events
	"ordinance_enacted": {"message": "Ordinance enacted: {name}", "type": "success"},
	"ordinance_repealed": {"message": "Ordinance repealed: {name}", "type": "info"},
	"ordinance_requirement_failed": {"message": "{reason}", "type": "error"},
	"green_energy_bonus": {"message": "Green Energy Bonus: +${amount}", "type": "success"},

	# Building events
	"building_repair_success": {"message": "Building repaired!", "type": "success"},
	"building_repair_failed": {"message": "Cannot afford repairs!", "type": "error"},
	"building_repair_batch": {"message": "Repaired {count} buildings!", "type": "success"},
	"building_upgrade_success": {"message": "{name} upgraded to level {level}!", "type": "success"},
	"building_upgrade_failed": {"message": "Cannot afford upgrade!", "type": "error"},
	"building_abandoned": {"message": "{name} abandoned due to lack of utilities!", "type": "warning"},
	"building_on_fire": {"message": "{name} is on fire!", "type": "error"},
	"building_destroyed": {"message": "{name} destroyed!", "type": "error"},
	"building_constructed": {"message": "{name} construction complete!", "type": "success"},

	# District events
	"district_created": {"message": "Created district: {name}", "type": "success"},
	"district_renamed": {"message": "Renamed district to: {name}", "type": "info"},
	"district_deleted": {"message": "Deleted district: {name}", "type": "info"},
	"district_overlay_set": {"message": "Set {name} as {overlay} district", "type": "success"},
	"district_tax_changed": {"message": "Tax rate changed in {name}", "type": "info"},

	# Growth boundary events
	"growth_boundary_expanded": {"message": "Growth boundary expanded! New area available for development.", "type": "success"},
	"growth_boundary_shrunk": {"message": "Growth boundary reduced. Some areas are now outside city limits.", "type": "warning"},
	"growth_boundary_locked": {"message": "Cannot modify growth boundary: {reason}", "type": "error"},
	"territory_annexed": {"message": "Annexed {tiles} tiles for ${cost}", "type": "success"},
	"greenbelt_designated": {"message": "Designated {tiles} tiles as greenbelt", "type": "success"},
	"greenbelt_removed": {"message": "Removed greenbelt protection from {tiles} tiles (residents unhappy)", "type": "warning"},

	# Infrastructure events
	"infrastructure_degraded": {"message": "Infrastructure aging: {count} buildings need repairs.", "type": "warning"},
	"infrastructure_critical": {"message": "Critical: {count} buildings at risk of failure!", "type": "error"},
	"infrastructure_failure": {"message": "{type} at {cell} needs replacement!", "type": "warning"},
	"infrastructure_repaired": {"message": "Repaired {name} for ${cost}", "type": "success"},
	"power_line_degradation": {"message": "Degraded power lines losing {loss_rate}% of power.", "type": "warning"},
	"water_pipe_leaks": {"message": "Aging pipes leaking {loss_rate}% of water supply.", "type": "warning"},

	# Storm power outage events
	"storm_power_outage": {"message": "{message}", "type": "error"},
	"power_restoration_progress": {"message": "{message}", "type": "info"},
	"power_fully_restored": {"message": "{message}", "type": "success"},

	# Drought events
	"drought_started": {"message": "Drought conditions! Water supply reduced. Conservation measures in effect.", "type": "warning"},
	"drought_worsening": {"message": "Drought intensifying. Water restrictions tightened.", "type": "error"},
	"drought_ended": {"message": "Drought has ended. Water supply returning to normal.", "type": "success"},
	"water_restrictions": {"message": "Water restrictions active: {percent}% reduction in supply.", "type": "warning"},

	# Save/Load events
	"game_saved": {"message": "Game saved: {name}", "type": "success"},
	"game_loaded": {"message": "Game loaded: {name}", "type": "success"},
	"game_save_failed": {"message": "Failed to save game", "type": "error"},
	"game_load_failed": {"message": "No save file found", "type": "error"},

	# Overlay events
	"overlay_changed": {"message": "Overlay: {mode}", "type": "info"},

	# UI action feedback events (from orchestration layer)
	"day_night_toggled": {"message": "Day/night cycle {state}", "type": "info"},
	"zone_painted": {"message": "Zoned {count} cells", "type": "info"},
	"zone_mode_entered": {"message": "Zone painting mode - drag to paint", "type": "info"},
	"building_demolished": {"message": "{name} demolished (+${refund})", "type": "info"},
	"data_center_placed_success": {"message": "Data Center placed! +{score} score", "type": "success"},
	"data_center_requirement_failed": {"message": "{requirement}", "type": "error"},
	"disaster_debug_hint": {"message": "Disasters: Shift+1=Fire, 2=Quake, 3=Tornado, 4=Flood, 5=Meteor, 6=Monster", "type": "info"},
	"options_coming_soon": {"message": "Options coming soon", "type": "info"},

	# Difficulty/game start events
	"difficulty_changed": {"message": "Difficulty set to {name}", "type": "info"},
	"game_started": {"message": "Starting new city on {difficulty} difficulty", "type": "success"},

	# Unlock/progression events
	"tier_unlocked": {"message": "{name} tier reached! New buildings available.", "type": "success"},
	"building_unlocked": {"message": "New building unlocked: {name}", "type": "success"},
	"milestone_approaching": {"message": "{remaining} more residents until {tier_name} tier!", "type": "info"},

	# Generic fallback
	"generic_info": {"message": "{message}", "type": "info"},
	"generic_warning": {"message": "{message}", "type": "warning"},
	"generic_error": {"message": "{message}", "type": "error"},
	"generic_success": {"message": "{message}", "type": "success"},
}


func _ready() -> void:
	Events.simulation_event.connect(_on_simulation_event)


func _on_simulation_event(event_type: String, data: Dictionary) -> void:
	var template = EVENT_MESSAGES.get(event_type)

	if not template:
		# Unknown event type - use generic based on severity in data
		var severity = data.get("severity", "info")
		if severity is int:
			severity = "info"  # Default to info if severity is numeric
		template = EVENT_MESSAGES.get("generic_" + str(severity), EVENT_MESSAGES["generic_info"])
		if not data.has("message"):
			push_warning("NotificationBridge: Unknown event type '%s' with no message" % event_type)
			return

	var message = _format_message(template.message, data)
	var msg_type = data.get("type_override", template.type)

	Events.notification_requested.emit(message, msg_type)


func _format_message(template: String, data: Dictionary) -> String:
	var result = template

	# Replace all {key} placeholders with data values
	for key in data:
		var placeholder = "{%s}" % key
		if result.contains(placeholder):
			result = result.replace(placeholder, str(data[key]))

	# Handle special cell formatting
	if data.has("cell") and data.cell is Vector2i:
		result = result.replace("{cell_x}", str(data.cell.x))
		result = result.replace("{cell_y}", str(data.cell.y))

	return result


## Convenience method for systems to emit events with less boilerplate
static func emit(event_type: String, data: Dictionary = {}) -> void:
	Events.simulation_event.emit(event_type, data)
