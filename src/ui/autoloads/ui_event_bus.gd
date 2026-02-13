extends Node
class_name UIEventBus

signal budget_changed(balance: int, income: int, expenses: int)
signal population_changed(population: int)
signal happiness_changed(value: float)
signal ui_tick(delta_ms: int)
