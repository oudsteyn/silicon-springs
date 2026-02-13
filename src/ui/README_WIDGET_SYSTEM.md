Modular HUD Widget System (Godot 4.3+)

Overview
- `UIEventBus` is the observer hub for UI-safe signals.
- `HUDStateStore` coalesces high-frequency simulation snapshots and emits throttled deltas.
- `WidgetController` provides uniform bind/unbind lifecycle.
- Widgets (`budget_widget`, `population_widget`, `city_stat_chip`) subscribe only to needed signals.
- `GlassPanel` supplies rounded translucent panel styling and subtle intro animation.

Suggested autoloads
- `res://src/ui/autoloads/ui_event_bus.gd` as `UIEventBus`
- `res://src/ui/autoloads/hud_state_store.gd` as `HUDStateStore`

Performance defaults
- Store push interval: `100 ms` (10 Hz)
- Delta-only emits for budget, population, happiness.
- Widgets update labels only when values change.

Styling
- Use `res://src/ui/themes/modern_glass_theme.tres` for consistent glassmorphism visuals.
