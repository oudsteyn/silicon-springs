extends Node
## Global signal bus for decoupled communication between systems
## Signals here are emitted from other classes (event bus pattern)

# ============================================
# DOMAIN EVENTS (Rich aggregated events)
# ============================================

## Power system state change with complete context
@warning_ignore("unused_signal")
signal power_state_changed(event: DomainEvents.PowerStateChanged)

## Water system state change with complete context
@warning_ignore("unused_signal")
signal water_state_changed(event: DomainEvents.WaterStateChanged)

## Budget tick with breakdown and context
@warning_ignore("unused_signal")
signal budget_tick(event: DomainEvents.BudgetTickEvent)

## Zone development change with context
@warning_ignore("unused_signal")
signal zone_development_changed(event: DomainEvents.ZoneStateChanged)

## Population state change with all metrics
@warning_ignore("unused_signal")
signal population_state_changed(event: DomainEvents.PopulationStateChanged)

## Service coverage state change
@warning_ignore("unused_signal")
signal service_state_changed(event: DomainEvents.ServiceStateChanged)

## Weather state change with all conditions
@warning_ignore("unused_signal")
signal weather_state_changed(event: DomainEvents.WeatherStateChanged)

## Storm outage event
@warning_ignore("unused_signal")
signal storm_outage_changed(event: DomainEvents.StormOutageEvent)

## Disaster event
@warning_ignore("unused_signal")
signal disaster_occurred(event: DomainEvents.DisasterEvent)

# ============================================
# LEGACY SIGNALS (maintained for backward compatibility)
# These will be deprecated in future versions. Prefer domain events above.
# ============================================

# Building events (no domain event equivalent yet - still primary)
@warning_ignore("unused_signal")
signal building_placed(cell: Vector2i, building: Node2D)
@warning_ignore("unused_signal")
signal building_removed(cell: Vector2i, building: Node2D)
@warning_ignore("unused_signal")
signal building_selected(building: Node2D)
@warning_ignore("unused_signal")
signal building_deselected()
@warning_ignore("unused_signal")
signal building_upgraded(building: Node2D, new_level: int)
@warning_ignore("unused_signal")
signal building_abandoned(building: Node2D)
@warning_ignore("unused_signal")
signal building_constructed(building: Node2D)

# Resource events
## @deprecated Use power_state_changed domain event instead
@warning_ignore("unused_signal")
signal power_updated(supply: float, demand: float)
## @deprecated Use water_state_changed domain event instead
@warning_ignore("unused_signal")
signal water_updated(supply: float, demand: float)
## @deprecated Use budget_tick domain event instead
@warning_ignore("unused_signal")
signal budget_updated(balance: int, income: int, expenses: int)

# Simulation events
@warning_ignore("unused_signal")
signal month_tick()
@warning_ignore("unused_signal")
signal year_tick()
@warning_ignore("unused_signal")
signal simulation_speed_changed(speed: int)
@warning_ignore("unused_signal")
signal simulation_paused(paused: bool)

# Coverage events
@warning_ignore("unused_signal")
signal coverage_updated(service_type: String)
@warning_ignore("unused_signal")
signal pollution_updated()

# Game events
@warning_ignore("unused_signal")
signal random_event_occurred(event_type: String, cell: Vector2i)
@warning_ignore("unused_signal")
signal fire_started(cell: Vector2i)
@warning_ignore("unused_signal")
signal fire_extinguished(cell: Vector2i)
@warning_ignore("unused_signal")
signal crime_occurred(cell: Vector2i)

# Population events
## @deprecated Use population_state_changed domain event instead
@warning_ignore("unused_signal")
signal population_changed(new_population: int, delta: int)
## @deprecated Use population_state_changed domain event instead
@warning_ignore("unused_signal")
signal happiness_changed(new_happiness: float)
## @deprecated Use population_state_changed domain event instead
@warning_ignore("unused_signal")
signal education_changed(education_rate: float)
## @deprecated Use population_state_changed domain event instead
@warning_ignore("unused_signal")
signal employment_updated(jobs: float, employed: int, unemployment: float)

# Financial events
@warning_ignore("unused_signal")
signal bankruptcy_warning(months_in_debt: int)

# Demand events
@warning_ignore("unused_signal")
signal demand_updated(residential: float, commercial: float, industrial: float)

# Data center events
@warning_ignore("unused_signal")
signal data_center_placed(tier: int, cell: Vector2i)
@warning_ignore("unused_signal")
signal tier_requirements_met(tier: int)
@warning_ignore("unused_signal")
signal tier_requirements_lost(tier: int)
@warning_ignore("unused_signal")
signal score_updated(new_score: int, delta: int)

# Landmark events
@warning_ignore("unused_signal")
signal landmark_unlocked(landmark_id: String, population_threshold: int)

# UI events
@warning_ignore("unused_signal")
signal build_mode_entered(building_id: String)
@warning_ignore("unused_signal")
signal build_mode_exited()
@warning_ignore("unused_signal")
signal demolish_mode_entered()
@warning_ignore("unused_signal")
signal demolish_mode_exited()
@warning_ignore("unused_signal")
signal tool_changed(tool: int)
@warning_ignore("unused_signal")
signal info_panel_requested(data: Dictionary)
@warning_ignore("unused_signal")
signal notification_requested(message: String, type: String)

# Grid events
@warning_ignore("unused_signal")
signal cell_hovered(cell: Vector2i)
@warning_ignore("unused_signal")
signal cell_clicked(cell: Vector2i, button: int)

# === COMMAND SIGNALS (UI → Simulation) ===
# These allow UI to request actions without direct system access
@warning_ignore("unused_signal")
signal build_requested(building_id: String, cell: Vector2i)
@warning_ignore("unused_signal")
signal demolish_requested(cell: Vector2i)
@warning_ignore("unused_signal")
signal zone_requested(zone_type: int, cells: Array)
@warning_ignore("unused_signal")
signal upgrade_requested(building: Node2D)

# === QUERY SIGNALS (UI → Orchestrator → UI) ===
# Request/response pattern for UI data needs
@warning_ignore("unused_signal")
signal cell_info_requested(cell: Vector2i)
@warning_ignore("unused_signal")
signal cell_info_ready(cell: Vector2i, info: Dictionary)
@warning_ignore("unused_signal")
signal building_info_requested(building: Node2D)
@warning_ignore("unused_signal")
signal building_info_ready(building: Node2D, info: Dictionary)
@warning_ignore("unused_signal")
signal building_catalog_requested()
@warning_ignore("unused_signal")
signal building_catalog_ready(catalog: Dictionary)
@warning_ignore("unused_signal")
signal expense_breakdown_requested()
@warning_ignore("unused_signal")
signal expense_breakdown_ready(breakdown: Dictionary)

# === SIMULATION EVENTS (Simulation → NotificationBridge → UI) ===
# Pure simulation events - NotificationBridge translates to user-facing notifications
@warning_ignore("unused_signal")
signal simulation_event(event_type: String, data: Dictionary)

# === INFRASTRUCTURE NETWORK EVENTS ===
# Emitted when road/utility networks change topology
# Buildings/renderers listen to update their visuals
@warning_ignore("unused_signal")
signal road_network_changed(cell: Vector2i, added: bool)
@warning_ignore("unused_signal")
signal water_pipe_network_changed(cell: Vector2i, added: bool)
@warning_ignore("unused_signal")
signal power_line_network_changed(cell: Vector2i, added: bool)

# === TERRAIN EVENTS ===
@warning_ignore("unused_signal")
signal terrain_changed(cells: Array)
@warning_ignore("unused_signal")
signal biome_selected(biome_id: String)
@warning_ignore("unused_signal")
signal terrain_tool_selected(tool_id: String)

# === WEATHER EVENTS ===
## @deprecated Use weather_state_changed domain event for comprehensive weather state
@warning_ignore("unused_signal")
signal weather_changed(temperature: float, conditions: String)
@warning_ignore("unused_signal")
signal pressure_changed(pressure: float, trend: String)
@warning_ignore("unused_signal")
signal front_approaching(front_type: String, days: int)
@warning_ignore("unused_signal")
signal front_passage(front_type: String)
@warning_ignore("unused_signal")
signal storm_started()
@warning_ignore("unused_signal")
signal storm_ended()
@warning_ignore("unused_signal")
signal flood_started()
@warning_ignore("unused_signal")
signal flood_ended()
@warning_ignore("unused_signal")
signal heat_wave_started()
@warning_ignore("unused_signal")
signal heat_wave_ended()
@warning_ignore("unused_signal")
signal cold_snap_started()
@warning_ignore("unused_signal")
signal cold_snap_ended()

# === AIR QUALITY EVENTS ===
@warning_ignore("unused_signal")
signal air_quality_changed(aqi: float, category: String)
@warning_ignore("unused_signal")
signal smog_alert_started()
@warning_ignore("unused_signal")
signal smog_alert_ended()
@warning_ignore("unused_signal")
signal inversion_started()
@warning_ignore("unused_signal")
signal inversion_ended()

# === DROUGHT EVENTS ===
@warning_ignore("unused_signal")
signal drought_started(severity: float)
@warning_ignore("unused_signal")
signal drought_ended()
@warning_ignore("unused_signal")
signal drought_severity_changed(severity: float, water_reduction: float)

# === WILDFIRE EVENTS ===
@warning_ignore("unused_signal")
signal wildfire_started(cell: Vector2i, severity: float)
@warning_ignore("unused_signal")
signal wildfire_ended()
@warning_ignore("unused_signal")
signal wildfire_spread(affected_cells: Array)
@warning_ignore("unused_signal")
signal wildfire_risk_changed(risk_level: float)

# === POWER GRID EVENTS ===
## For storm-specific events, prefer storm_outage_changed domain event
@warning_ignore("unused_signal")
signal storm_outage_started(severity: float, affected_percent: float)
@warning_ignore("unused_signal")
signal storm_outage_ended()
@warning_ignore("unused_signal")
signal power_restoration_progress(percent_restored: float)

# === WATER SYSTEM EVENTS ===
@warning_ignore("unused_signal")
signal water_supply_critical(remaining_days: int)
