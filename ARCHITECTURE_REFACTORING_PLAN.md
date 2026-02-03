# Architecture Refactoring Plan: Simulation/UI Separation

## Status: ✅ COMPLETE

All phases of the architecture refactoring have been implemented. The simulation layer is now fully decoupled from the UI layer.

---

## Completed Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      UI LAYER                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ StatusPill   │  │ ToolPalette  │  │ InfoPanel    │      │
│  │ (read-only)  │  │ (commands)   │  │ (read-only)  │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
│         │                 │                 │               │
│         │ listen          │ emit            │ query         │
└─────────┼─────────────────┼─────────────────┼───────────────┘
          │                 │                 │
          ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│                    EVENT BUS (Events.gd)                    │
│  ┌────────────────────┐  ┌────────────────────┐            │
│  │ Simulation Events  │  │   Command Signals  │            │
│  │ - simulation_event │  │ - build_requested  │            │
│  │ - power_updated    │  │ - demolish_requested│           │
│  │ - month_tick       │  │ - zone_requested   │            │
│  └────────────────────┘  └────────────────────┘            │
│  ┌────────────────────┐  ┌────────────────────┐            │
│  │  Query Requests    │  │  Query Responses   │            │
│  │ - cell_info_req    │  │ - cell_info_ready  │            │
│  │ - building_info_req│  │ - building_info_ready│          │
│  │ - catalog_requested│  │ - catalog_ready    │            │
│  │ - expense_breakdown│  │ - expense_ready    │            │
│  └────────────────────┘  └────────────────────┘            │
└─────────────────────────────────────────────────────────────┘
          │                 │                 │
          ▼                 ▼                 ▼
┌─────────────────────────────────────────────────────────────┐
│              NOTIFICATION BRIDGE                            │
│  ┌──────────────────────────────────────────────────┐      │
│  │         notification_bridge.gd                    │      │
│  │  - Translates simulation_event → notification     │      │
│  │  - 40+ event type templates                       │      │
│  │  - Keeps simulation UI-agnostic                   │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                 ORCHESTRATION LAYER                         │
│  ┌──────────────────────────────────────────────────┐      │
│  │              GameWorld (scenes/game_world.gd)    │      │
│  │  - Query handlers (aggregates system data)       │      │
│  │  - Command handlers (executes user actions)      │      │
│  │  - Validates before execution                    │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                 SIMULATION LAYER                            │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐   │
│  │PowerSystem│ │WaterSystem│ │GridSystem │ │ZoningSystem│  │
│  └───────────┘ └───────────┘ └───────────┘ └───────────┘   │
│  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐   │
│  │Traffic    │ │Pollution  │ │LandValue  │ │Disaster   │   │
│  └───────────┘ └───────────┘ └───────────┘ └───────────┘   │
│                                                             │
│  - Pure simulation logic                                    │
│  - Emits simulation_event only (NO notification_requested) │
│  - No direct UI dependencies                               │
└─────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│                    DATA LAYER                               │
│  ┌──────────────────────────────────────────────────┐      │
│  │              GameState (autoloads/game_state.gd) │      │
│  │  - Pure data container                           │      │
│  │  - Batch update support (begin_batch/end_batch)  │      │
│  │  - Calculation logic extracted to calculators    │      │
│  └──────────────────────────────────────────────────┘      │
│  ┌──────────────────────────────────────────────────┐      │
│  │         DemandCalculator (calculation/)          │      │
│  │  - Pure static calculation functions             │      │
│  │  - No side effects, fully testable               │      │
│  └──────────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## Completed Phases

### Phase 1: NotificationBridge Pattern ✅

**Created:** `src/autoloads/notification_bridge.gd`

- Translates `simulation_event` signals to user-facing `notification_requested`
- 40+ event type templates for all game events
- Keeps simulation layer UI-agnostic

**Refactored Systems:**
- `grid_system.gd` - Uses `simulation_event` for insufficient funds
- `disaster_system.gd` - Uses `simulation_event` for all disaster notifications
- `ordinance_system.gd` - Uses `simulation_event` for enact/repeal
- `infrastructure_age_system.gd` - Uses `simulation_event` for repairs
- `growth_boundary_system.gd` - Uses `simulation_event` for annexation
- `district_system.gd` - Uses `simulation_event` for district CRUD
- All other simulation systems

---

### Phase 2: InfoPanel Decoupling ✅

**Query Signals Added:**
- `cell_info_requested` / `cell_info_ready`
- `building_info_requested` / `building_info_ready`

**Changes:**
- Removed direct system references from `info_panel.gd`
- GameWorld aggregates data from systems and responds to queries
- InfoPanel uses event-driven pattern for all data

---

### Phase 3: ToolPalette Decoupling ✅

**Query Signals Added:**
- `building_catalog_requested` / `building_catalog_ready`

**Changes:**
- Removed `grid_system` reference from `tool_palette.gd`
- ToolPalette requests building catalog via events
- GameWorld provides catalog data

---

### Phase 4: BudgetPanel Decoupling ✅

**Query Signals Added:**
- `expense_breakdown_requested` / `expense_breakdown_ready`

**Changes:**
- Removed `grid_system` reference from `budget_panel.gd`
- BudgetPanel requests expense data via events
- GameWorld aggregates maintenance costs by category

---

### Phase 5: GameState Refactoring ✅

**Created:** `src/calculation/demand_calculator.gd`
- Extracted demand calculation logic from GameState
- Pure static functions, no side effects
- Fully testable

**Batch Update Support:**
- Added `begin_batch()` / `end_batch()` methods
- Property setters use `_emit_or_queue()` helper
- Simulation uses batch mode during monthly tick

---

### Phase 6: Command Signal Implementation ✅

**Command Signals (in Events.gd):**
- `build_requested(building_id, cell)`
- `demolish_requested(cell)`
- `zone_requested(zone_type, cells)`

**Command Handlers (in GameWorld):**
- `_on_build_requested()` - Validates and executes placement
- `_on_demolish_requested()` - Validates and executes demolition
- `_on_zone_requested()` - Validates and executes zoning

**Benefits:**
- Enables replay/undo functionality
- Supports multiplayer synchronization
- Allows scripted/automated actions

---

### Phase 7: Full Event Consistency ✅

**Converted all `notification_requested` calls to `simulation_event`:**
- `main.gd` - Save/load feedback
- `game_world.gd` - Day/night toggle, zone painting, demolish, data center placement

**Only `notification_bridge.gd` emits `notification_requested`** (as intended)

---

## Verification Checklist ✅

| Check | Status |
|-------|--------|
| No UI component directly references simulation systems | ✅ |
| No simulation system emits `notification_requested` | ✅ |
| All UI updates are event-driven | ✅ |
| InfoPanel uses query signals | ✅ |
| ToolPalette uses query signals | ✅ |
| BudgetPanel uses query signals | ✅ |
| GameState calculation logic extracted | ✅ |
| Batch update support in GameState | ✅ |
| Command signals implemented | ✅ |
| All notifications go through NotificationBridge | ✅ |

---

## Key Files Modified

### New Files Created
- `src/autoloads/notification_bridge.gd` - Event to notification translation
- `src/calculation/demand_calculator.gd` - Extracted calculation logic

### Core Files Modified
- `src/autoloads/events.gd` - Added query and command signals
- `src/autoloads/game_state.gd` - Added batch update support, uses DemandCalculator
- `src/autoloads/simulation.gd` - Uses batch mode during monthly tick
- `scenes/game_world.gd` - Added query and command handlers
- `scenes/main.gd` - Removed direct system wiring, uses simulation_event

### UI Files Refactored
- `src/ui/info_panel.gd` - Event-driven, no direct system access
- `src/ui/components/tool_palette.gd` - Event-driven catalog
- `src/ui/budget_panel.gd` - Event-driven expense breakdown

---

## Benefits Achieved

1. **Testability** - Simulation logic testable without UI
2. **Headless Mode** - Can run simulation without rendering
3. **Multiple UIs** - Could add console UI, mobile UI, etc.
4. **Replay/Undo** - Command pattern enables action replay
5. **Networking** - Commands can be serialized for multiplayer
6. **Maintainability** - Clear boundaries, easier to modify
7. **Performance** - UI updates batched, not per-property
