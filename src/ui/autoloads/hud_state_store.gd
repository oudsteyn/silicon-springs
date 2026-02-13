extends Node
class_name HUDStateStore

@export var push_interval_ms: int = 100

var _event_bus: Node = null
var _last_push_ms: int = -1
var _has_pending: bool = false
var _latest_budget := {"balance": 0, "income": 0, "expenses": 0}
var _latest_population: int = 0
var _latest_happiness: float = 0.0

var _last_emitted_budget := {"balance": null, "income": null, "expenses": null}
var _last_emitted_population = null
var _last_emitted_happiness = null


func _ready() -> void:
	if _event_bus == null:
		_event_bus = get_node_or_null("/root/UIEventBus")


func set_event_bus(bus: Node) -> void:
	_event_bus = bus


func get_event_bus() -> Node:
	return _event_bus


func set_push_interval_ms_for_tests(value: int) -> void:
	push_interval_ms = max(value, 0)


func ingest_simulation_snapshot(snapshot: Dictionary) -> void:
	_latest_budget.balance = int(snapshot.get("balance", _latest_budget.balance))
	_latest_budget.income = int(snapshot.get("income", _latest_budget.income))
	_latest_budget.expenses = int(snapshot.get("expenses", _latest_budget.expenses))
	_latest_population = int(snapshot.get("population", _latest_population))
	_latest_happiness = float(snapshot.get("happiness", _latest_happiness))
	_has_pending = true


func _process(_delta: float) -> void:
	pump()


func pump(now_ms: int = -1) -> bool:
	if not _has_pending:
		return false

	var tick = now_ms if now_ms >= 0 else Time.get_ticks_msec()
	if _last_push_ms >= 0 and (tick - _last_push_ms) < push_interval_ms:
		return false

	_last_push_ms = tick
	_emit_deltas()
	_has_pending = false
	return true


func _emit_deltas() -> void:
	if _event_bus == null:
		return

	var budget_changed = _latest_budget.balance != _last_emitted_budget.balance \
		or _latest_budget.income != _last_emitted_budget.income \
		or _latest_budget.expenses != _last_emitted_budget.expenses
	if budget_changed and _event_bus.has_signal("budget_changed"):
		_event_bus.budget_changed.emit(_latest_budget.balance, _latest_budget.income, _latest_budget.expenses)
		_last_emitted_budget = {
			"balance": _latest_budget.balance,
			"income": _latest_budget.income,
			"expenses": _latest_budget.expenses
		}

	if _latest_population != _last_emitted_population and _event_bus.has_signal("population_changed"):
		_event_bus.population_changed.emit(_latest_population)
		_last_emitted_population = _latest_population

	if _latest_happiness != _last_emitted_happiness and _event_bus.has_signal("happiness_changed"):
		_event_bus.happiness_changed.emit(_latest_happiness)
		_last_emitted_happiness = _latest_happiness

	if _event_bus.has_signal("ui_tick"):
		_event_bus.ui_tick.emit(push_interval_ms)
