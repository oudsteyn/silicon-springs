class_name TerrainInterface
extends RefCounted
## Abstract interface for terrain systems
##
## GridSystem uses this interface to check terrain constraints without
## tight coupling to the specific TerrainSystem implementation.
##
## Any terrain system should implement these methods to integrate with
## the building placement system.

## Result structure for buildability checks
class BuildableResult:
	var can_build: bool = true
	var reason: String = ""

	static func ok() -> BuildableResult:
		var result = BuildableResult.new()
		result.can_build = true
		return result

	static func fail(reason: String) -> BuildableResult:
		var result = BuildableResult.new()
		result.can_build = false
		result.reason = reason
		return result


## Check if a cell is buildable for a given building type
## Override this in concrete implementations
static func is_buildable(_cell: Vector2i, _building_data) -> BuildableResult:
	push_error("TerrainInterface.is_buildable must be overridden")
	return BuildableResult.fail("Not implemented")


## Get the elevation at a cell (-3 to +5 range typically)
## Override this in concrete implementations
static func get_elevation(_cell: Vector2i) -> int:
	push_error("TerrainInterface.get_elevation must be overridden")
	return 0


## Check if a cell has water
## Override this in concrete implementations
static func has_water(_cell: Vector2i) -> bool:
	push_error("TerrainInterface.has_water must be overridden")
	return false


## Get terrain features at a cell (trees, rocks, etc.)
## Override this in concrete implementations
static func get_features(_cell: Vector2i) -> Array:
	push_error("TerrainInterface.get_features must be overridden")
	return []
