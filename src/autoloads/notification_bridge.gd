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

# Events that are typically informational and should only surface if explicitly severe.
const LOW_IMPACT_EVENTS: Dictionary = {
	"front_passage": true,
	"front_approaching": true,
	"pressure_falling": true,
	"air_quality_changed": true,
	"inversion_started": true,
	"inversion_ended": true,
	"rain_clearing_pollution": true,
	"climate_report": true,
	"overlay_changed": true,
	"zone_painted": true,
	"zone_mode_entered": true,
	"measurement_started": true,
	"measurement_ended": true,
	"measurement_mode_changed": true,
	"disaster_debug_hint": true,
	"options_coming_soon": true
}

# Events that are always relevant to city operations.
const ALWAYS_NOTIFY_EVENTS: Dictionary = {
	"insufficient_funds": true,
	"budget_warning": true,
	"budget_critical": true,
	"bankruptcy": true,
	"disaster_fire": true,
	"disaster_fire_major": true,
	"disaster_earthquake": true,
	"disaster_tornado": true,
	"disaster_flood": true,
	"disaster_meteor": true,
	"disaster_monster": true,
	"buildings_collapsed": true,
	"storm_damage": true,
	"storm_building_damage": true,
	"flood_started": true,
	"flood_damage": true,
	"flood_building_damage": true,
	"water_pressure_low": true,
	"water_pressure_critical": true,
	"water_pressure_restored": true,
	"wildfire_started": true,
	"wildfire_ended": true,
	"drought_started": true,
	"drought_worsening": true,
	"drought_ended": true,
	"building_abandoned": true,
	"building_on_fire": true,
	"building_destroyed": true,
	"building_constructed": true,
	"infrastructure_degraded": true,
	"infrastructure_critical": true,
	"infrastructure_failure": true,
	"infrastructure_repaired": true,
	"power_line_degradation": true,
	"water_pipe_leaks": true
}

## Weather/status chatter that should only surface when there is direct city impact.
const WEATHER_CONTEXT_EVENTS: Dictionary = {
	"front_passage": true,
	"front_approaching": true,
	"pressure_falling": true,
	"storm_started": true,
	"storm_ended": true,
	"flood_started": true,
	"flood_ended": true,
	"heat_wave_started": true,
	"heat_wave_ended": true,
	"cold_snap_started": true,
	"cold_snap_ended": true,
	"high_water_demand": true,
	"climate_report": true,
	"air_quality_changed": true,
	"inversion_started": true,
	"inversion_ended": true,
	"rain_clearing_pollution": true,
	"wildfire_ongoing": true
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
	if not _should_emit_city_impact_notification(event_type, data, str(msg_type)):
		return

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


func _should_emit_city_impact_notification(event_type: String, data: Dictionary, msg_type: String) -> bool:
	if ALWAYS_NOTIFY_EVENTS.has(event_type):
		return true
	if WEATHER_CONTEXT_EVENTS.has(event_type):
		return _has_direct_city_impact_payload(data)
	if LOW_IMPACT_EVENTS.has(event_type):
		# Only show low-impact events if explicitly escalated.
		return msg_type == "warning" or msg_type == "error"

	# Generic impact heuristics for event payloads.
	if data.has("count") and int(data.get("count", 0)) <= 0:
		return false
	if data.has("affected_percent") and float(data.get("affected_percent", 0.0)) <= 0.0:
		return false
	if data.has("active") and not bool(data.get("active", false)):
		return false
	if data.has("severity") and (data.get("severity") is float or data.get("severity") is int):
		if float(data.get("severity", 0.0)) <= 0.0:
			return false

	# Keep success/error signals for direct player actions (save/load/building ops).
	if msg_type == "success" or msg_type == "error" or msg_type == "warning":
		return true
	return false


func _has_direct_city_impact_payload(data: Dictionary) -> bool:
	if data.has("count") and int(data.get("count", 0)) > 0:
		return true
	if data.has("affected_buildings") and int(data.get("affected_buildings", 0)) > 0:
		return true
	if data.has("damaged_buildings") and int(data.get("damaged_buildings", 0)) > 0:
		return true
	if data.has("population_affected") and int(data.get("population_affected", 0)) > 0:
		return true
	if data.has("affected_percent") and float(data.get("affected_percent", 0.0)) > 0.0:
		return true
	if data.has("has_shortage") and bool(data.get("has_shortage", false)):
		return true
	return false
