class_name BaseSystem
extends Node
## Base class for all game systems that participate in dependency injection

## Override to return a unique identifier for this system
func get_system_id() -> String:
	return ""

## Override to return list of system IDs this system depends on
func get_dependencies() -> Array[String]:
	return []

## Override to return list of system IDs this system optionally depends on
func get_optional_dependencies() -> Array[String]:
	return []

## Called by SystemManager after all dependencies have been injected.
## Override this instead of _ready() for initialization that requires other systems.
func system_initialize() -> void:
	pass

## Returns metadata for SystemManager registration
func get_metadata() -> Dictionary:
	return {
		"system_id": get_system_id(),
		"dependencies": get_dependencies(),
		"optional_dependencies": get_optional_dependencies()
	}
