# Data Center City Builder

A city simulation game built with Godot 4.6 where players build and manage a city with the ultimate goal of constructing data centers.

## Features

### City Simulation
- **Zoning System**: Residential, commercial, and industrial zones with multiple density levels
- **Infrastructure**: Roads, power lines, water pipes
- **Utilities**: Power plants (coal, solar, wind, nuclear), water towers, treatment plants
- **Services**: Police, fire stations, hospitals, schools, universities
- **Economy**: Tax collection, building maintenance, population growth

### Data Centers
- Three tiers of data centers with increasing requirements
- Requirements include power, water, population, education, and service coverage
- Score points by building and maintaining data centers

### Systems
- Power grid with supply/demand tracking
- Water network management
- Traffic simulation
- Pollution and land value calculations
- Day/night cycle
- Random disasters (fire, earthquake, tornado, flood)

## Controls

### Mouse
- **Left-click**: Select/place buildings
- **Right-click**: Cancel action
- **Middle-click + drag**: Pan camera
- **Scroll wheel**: Zoom in/out

### Keyboard
- **Q**: Select tool
- **B**: Open build menu
- **X**: Demolish mode
- **D**: Dashboard
- **Space**: Pan mode (hold)
- **1-7**: Toggle overlays
- **ESC**: Cancel/close

## UI Components

- **Status Pill** (top-left): Budget, population, date, speed controls
- **Tool Palette** (left edge): Build, zone, demolish, overlays, settings
- **Mini Minimap** (bottom-right): City overview with navigation
- **Info Panel** (right edge): Building/cell details

## Architecture

The game uses an event-driven architecture with clear separation between simulation and UI layers:

- **Event Bus** (`Events.gd`): Central hub for all signals - simulation events, commands, and queries
- **Notification Bridge**: Translates simulation events into user-facing notifications
- **Command Pattern**: Build, demolish, and zone actions go through command signals
- **Query Pattern**: UI components request data via query signals, enabling loose coupling

## Project Structure

```
├── assets/
│   ├── buildings/      # Building sprites
│   ├── tiles/          # Tile assets
│   └── ui/             # Theme resources
├── data/
│   └── terrain_templates/
├── scenes/             # Main scene files
├── src/
│   ├── autoloads/      # Global singletons
│   │   ├── events.gd           # Event bus
│   │   ├── game_state.gd       # Game data
│   │   ├── simulation.gd       # Simulation orchestrator
│   │   ├── notification_bridge.gd
│   │   └── ui_manager.gd
│   ├── calculation/    # Pure calculation logic
│   ├── core/           # Core utilities
│   ├── data/           # Building data resources (.tres)
│   ├── entities/       # Building entity
│   ├── resources/      # Custom resource definitions
│   ├── systems/        # Game systems (power, water, traffic, etc.)
│   └── ui/
│       ├── components/ # Reusable UI components
│       ├── dashboard/  # Dashboard panels
│       └── grid/       # Grid-related UI
├── tests/              # Test files
└── project.godot
```

## Requirements

- Godot 4.6+

## Tests

Run the full test suite headless:

```bash
godot --headless -s tests/run_headless.gd
```

For verbose runs without the resource-load spam:

```bash
scripts/run_tests_verbose.sh
```

## License

MIT
