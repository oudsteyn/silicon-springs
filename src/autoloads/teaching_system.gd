extends Node
class_name TeachingSystemClass
## Provides contextual teaching moments for new players
## Watches game state and triggers helpful tips at appropriate times

signal teaching_moment_triggered(moment_id: String, message: String)

# Teaching moments with their trigger conditions
const TEACHING_MOMENTS: Dictionary = {
	# Early game guidance
	"first_resident": {
		"message": "Your first resident has arrived! They need jobs to stay employed.",
		"type": "success",
		"priority": 1,
		"one_time": true
	},
	"need_jobs": {
		"message": "Residents need jobs! Build commercial or industrial zones to create employment.",
		"type": "warning",
		"priority": 2,
		"cooldown": 180  # 3 minutes
	},
	"need_housing": {
		"message": "Workers are available but no housing! Zone residential areas to attract residents.",
		"type": "info",
		"priority": 2,
		"cooldown": 180
	},
	"need_power": {
		"message": "Your city needs power! Build a power plant and connect it with power lines.",
		"type": "warning",
		"priority": 3,
		"cooldown": 120
	},
	"need_water": {
		"message": "Water supply is critical! Build a water pump and lay water pipes.",
		"type": "warning",
		"priority": 3,
		"cooldown": 120
	},
	"power_shortage": {
		"message": "Power shortage! Your city needs more power generation.",
		"type": "error",
		"priority": 3,
		"cooldown": 60
	},
	"water_shortage": {
		"message": "Water shortage! Your city needs more water supply.",
		"type": "error",
		"priority": 3,
		"cooldown": 60
	},

	# Service coverage
	"fire_risk": {
		"message": "Buildings without fire coverage are at risk! Build a fire station.",
		"type": "warning",
		"priority": 2,
		"cooldown": 300
	},
	"crime_rising": {
		"message": "Crime is rising! Build a police station to protect your residents.",
		"type": "warning",
		"priority": 2,
		"cooldown": 300
	},
	"education_needed": {
		"message": "Your residents need education! Build schools to unlock skilled jobs.",
		"type": "info",
		"priority": 1,
		"cooldown": 300
	},

	# Economy
	"budget_tip": {
		"message": "Tip: Watch your budget! Maintenance costs add up as your city grows.",
		"type": "info",
		"priority": 1,
		"cooldown": 600
	},
	"negative_income": {
		"message": "Expenses exceed income! Consider raising taxes or reducing services.",
		"type": "warning",
		"priority": 2,
		"cooldown": 120
	},

	# Zones
	"zone_not_developing": {
		"message": "Zones need power, water, and road access to develop.",
		"type": "info",
		"priority": 1,
		"cooldown": 300
	},
	"industrial_pollution": {
		"message": "Industrial zones cause pollution. Keep them away from residential areas!",
		"type": "info",
		"priority": 1,
		"one_time": true
	},

	# Data centers
	"data_center_ready": {
		"message": "Your city can now support a Data Center! Check the requirements in the build menu.",
		"type": "success",
		"priority": 2,
		"one_time": true
	},

	# Milestones
	"first_100_pop": {
		"message": "100 residents! Your village is growing. New buildings are now available!",
		"type": "success",
		"priority": 2,
		"one_time": true
	},
	"first_1000_pop": {
		"message": "1,000 residents! You're building a real city now!",
		"type": "success",
		"priority": 2,
		"one_time": true
	},

	# Traffic
	"traffic_congestion": {
		"message": "Traffic is building up! Consider building public transit or wider roads.",
		"type": "info",
		"priority": 1,
		"cooldown": 300
	},

	# Happiness
	"happiness_low": {
		"message": "Happiness is low! Check power, water, jobs, and pollution levels.",
		"type": "warning",
		"priority": 2,
		"cooldown": 180
	},
	"happiness_tip": {
		"message": "Tip: Parks increase happiness and land value for nearby residents!",
		"type": "info",
		"priority": 1,
		"one_time": true
	}
}

# Tracking
var _shown_one_time: Dictionary = {}  # moment_id: true
var _last_shown_time: Dictionary = {}  # moment_id: timestamp
var _enabled: bool = true

# Check intervals
var _check_timer: float = 0.0
const CHECK_INTERVAL: float = 5.0  # Check every 5 seconds

# Tracking for specific triggers
var _had_first_resident: bool = false
var _had_first_job: bool = false
var _placed_first_industrial: bool = false
var _reached_100_pop: bool = false
var _reached_1000_pop: bool = false


func _ready() -> void:
	# Connect to relevant events
	Events.population_changed.connect(_on_population_changed)
	Events.building_placed.connect(_on_building_placed)
	Events.power_updated.connect(_on_power_updated)
	Events.water_updated.connect(_on_water_updated)
	Events.happiness_changed.connect(_on_happiness_changed)
	Events.month_tick.connect(_on_month_tick)

	# Connect to difficulty changes
	if GameConfig:
		GameConfig.difficulty_changed.connect(_on_difficulty_changed)


func _on_difficulty_changed(difficulty: GameConfigClass.Difficulty) -> void:
	# Disable teaching in sandbox mode (experienced players)
	_enabled = difficulty != GameConfigClass.Difficulty.SANDBOX


func _process(delta: float) -> void:
	if not _enabled:
		return

	_check_timer += delta
	if _check_timer >= CHECK_INTERVAL:
		_check_timer = 0.0
		_check_periodic_conditions()


func _check_periodic_conditions() -> void:
	# Check for various conditions that warrant teaching moments

	# Need jobs (have residents but no jobs)
	if GameState.population > 0 and GameState.jobs_available == 0:
		_trigger_moment("need_jobs")

	# Need housing (have jobs but few residents)
	if GameState.jobs_available > 10 and GameState.population < GameState.jobs_available * 0.3:
		_trigger_moment("need_housing")

	# Power needed (have buildings but no power)
	if GameState.power_demand > 0 and GameState.power_supply == 0:
		_trigger_moment("need_power")

	# Water needed
	if GameState.water_demand > 0 and GameState.water_supply == 0:
		_trigger_moment("need_water")

	# Negative cash flow
	if GameState.monthly_expenses > GameState.monthly_income and GameState.monthly_income > 0:
		_trigger_moment("negative_income")

	# Low happiness
	if GameState.happiness < 0.3 and GameState.population > 50:
		_trigger_moment("happiness_low")

	# Traffic congestion
	if GameState.city_traffic_congestion > 0.6:
		_trigger_moment("traffic_congestion")

	# High crime
	if GameState.city_crime_rate > 0.3 and GameState.population > 100:
		_trigger_moment("crime_rising")


func _on_population_changed(population: int, _delta: int) -> void:
	if not _enabled:
		return

	# First resident
	if population >= 1 and not _had_first_resident:
		_had_first_resident = true
		_trigger_moment("first_resident")

	# Population milestones
	if population >= 100 and not _reached_100_pop:
		_reached_100_pop = true
		_trigger_moment("first_100_pop")

	if population >= 1000 and not _reached_1000_pop:
		_reached_1000_pop = true
		_trigger_moment("first_1000_pop")

	# Check data center readiness at population thresholds
	if population >= 10 and not _shown_one_time.has("data_center_ready"):
		# Check if they have enough power/water
		if GameState.power_supply >= 5 and GameState.water_supply >= 100:
			_trigger_moment("data_center_ready")


func _on_building_placed(_cell: Vector2i, building: Node2D) -> void:
	if not _enabled or not building or not building.building_data:
		return

	var building_type = building.building_data.building_type

	# First industrial zone placed - warn about pollution
	if building_type in ["industrial", "industrial_low", "industrial_med", "industrial_high"]:
		if not _placed_first_industrial:
			_placed_first_industrial = true
			# Delay the tip slightly so it doesn't overlap with placement
			get_tree().create_timer(2.0).timeout.connect(func():
				_trigger_moment("industrial_pollution")
			)

	# First park - happiness tip
	if building_type == "park":
		_trigger_moment("happiness_tip")


func _on_power_updated(supply: float, demand: float) -> void:
	if not _enabled:
		return

	if demand > supply and demand > 0:
		_trigger_moment("power_shortage")


func _on_water_updated(supply: float, demand: float) -> void:
	if not _enabled:
		return

	if demand > supply and demand > 0:
		_trigger_moment("water_shortage")


func _on_happiness_changed(_happiness: float) -> void:
	# This is handled in periodic check
	pass


func _on_month_tick() -> void:
	if not _enabled:
		return

	# Budget tip after first few months
	if GameState.total_months == 3:
		_trigger_moment("budget_tip")

	# Education tip after population grows
	if GameState.population >= 200 and GameState.education_rate < 0.1:
		_trigger_moment("education_needed")


func _trigger_moment(moment_id: String) -> void:
	if not TEACHING_MOMENTS.has(moment_id):
		return

	var moment = TEACHING_MOMENTS[moment_id]

	# Check if one-time and already shown
	if moment.get("one_time", false) and _shown_one_time.has(moment_id):
		return

	# Check cooldown
	var cooldown = moment.get("cooldown", 0)
	if cooldown > 0:
		var current_time = Time.get_ticks_msec() / 1000.0
		var last_time = _last_shown_time.get(moment_id, 0.0)
		if current_time - last_time < cooldown:
			return
		_last_shown_time[moment_id] = current_time

	# Mark one-time moments as shown
	if moment.get("one_time", false):
		_shown_one_time[moment_id] = true

	# Emit the teaching moment
	teaching_moment_triggered.emit(moment_id, moment.message)

	# Also emit as simulation event for notification system
	Events.simulation_event.emit("generic_" + moment.type, {"message": moment.message})


## Reset all teaching moments (for new game)
func reset() -> void:
	_shown_one_time.clear()
	_last_shown_time.clear()
	_had_first_resident = false
	_had_first_job = false
	_placed_first_industrial = false
	_reached_100_pop = false
	_reached_1000_pop = false


## Disable teaching system
func disable() -> void:
	_enabled = false


## Enable teaching system
func enable() -> void:
	_enabled = true


## Check if teaching system is enabled
func is_enabled() -> bool:
	return _enabled


## Mark a teaching moment as shown (for loading saved games)
func mark_shown(moment_id: String) -> void:
	if TEACHING_MOMENTS.has(moment_id):
		var moment = TEACHING_MOMENTS[moment_id]
		if moment.get("one_time", false):
			_shown_one_time[moment_id] = true


## Get list of all shown one-time moments (for saving)
func get_shown_moments() -> Array:
	return _shown_one_time.keys()


## Load shown moments from save data
func load_shown_moments(moments: Array) -> void:
	for moment_id in moments:
		if typeof(moment_id) == TYPE_STRING:
			mark_shown(moment_id)
