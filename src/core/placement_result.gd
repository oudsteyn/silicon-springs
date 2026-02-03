class_name PlacementResult
extends RefCounted
## Typed result classes for building placement validation
##
## These classes replace magic dictionary keys with type-safe result objects,
## providing compile-time safety and better IDE autocompletion.


## Main placement validation result
var can_place: bool = true
var reasons: Array[String] = []
var cost: int = 0
var warnings: Array[String] = []


## Create a successful placement result
static func success(placement_cost: int = 0) -> PlacementResult:
	var result = PlacementResult.new()
	result.can_place = true
	result.cost = placement_cost
	return result


## Create a failed placement result with a reason
static func failure(reason: String) -> PlacementResult:
	var result = PlacementResult.new()
	result.can_place = false
	result.reasons.append(reason)
	return result


## Add a failure reason (sets can_place to false)
func add_failure(reason: String) -> PlacementResult:
	can_place = false
	reasons.append(reason)
	return self


## Add a warning (doesn't prevent placement)
func add_warning(warning: String) -> PlacementResult:
	warnings.append(warning)
	return self


## Merge another result into this one
func merge(other: PlacementResult) -> PlacementResult:
	if not other.can_place:
		can_place = false
	reasons.append_array(other.reasons)
	warnings.append_array(other.warnings)
	cost = maxi(cost, other.cost)
	return self


## Convert to dictionary for backward compatibility
func to_dict() -> Dictionary:
	return {
		"can_place": can_place,
		"reasons": reasons,
		"cost": cost,
		"warnings": warnings
	}


# =============================================================================
# ROAD ACCESS RESULT
# =============================================================================

class RoadAccessResult extends RefCounted:
	var has_access: bool = false
	var has_any_road: bool = false
	var road_type: String = ""
	var reason: String = ""

	static func with_access(found_road_type: String) -> RoadAccessResult:
		var result = RoadAccessResult.new()
		result.has_access = true
		result.has_any_road = true
		result.road_type = found_road_type
		return result

	static func no_access(failure_reason: String, has_road: bool = false) -> RoadAccessResult:
		var result = RoadAccessResult.new()
		result.has_access = false
		result.has_any_road = has_road
		result.reason = failure_reason
		return result

	func to_dict() -> Dictionary:
		return {
			"has_access": has_access,
			"has_any_road": has_any_road,
			"road_type": road_type,
			"reason": reason
		}


# =============================================================================
# FAR COMPLIANCE RESULT
# =============================================================================

class FARComplianceResult extends RefCounted:
	var compliant: bool = true
	var current_far: float = 0.0
	var max_far: float = 0.0
	var reason: String = ""

	static func is_compliant(far_value: float, max_value: float) -> FARComplianceResult:
		var result = FARComplianceResult.new()
		result.compliant = true
		result.current_far = far_value
		result.max_far = max_value
		return result

	static func not_compliant(far_value: float, max_value: float, failure_reason: String) -> FARComplianceResult:
		var result = FARComplianceResult.new()
		result.compliant = false
		result.current_far = far_value
		result.max_far = max_value
		result.reason = failure_reason
		return result

	func to_dict() -> Dictionary:
		return {
			"compliant": compliant,
			"current_far": current_far,
			"max_far": max_far,
			"reason": reason
		}


# =============================================================================
# NEIGHBOR INFO RESULT
# =============================================================================

class NeighborInfo extends RefCounted:
	var north: int = 0
	var south: int = 0
	var east: int = 0
	var west: int = 0

	var has_north: bool:
		get: return north == 1
	var has_south: bool:
		get: return south == 1
	var has_east: bool:
		get: return east == 1
	var has_west: bool:
		get: return west == 1
	var has_vertical: bool:
		get: return has_north or has_south
	var has_horizontal: bool:
		get: return has_east or has_west
	var connection_count: int:
		get: return north + south + east + west

	static func from_dict(neighbors: Dictionary) -> NeighborInfo:
		var result = NeighborInfo.new()
		result.north = neighbors.get("north", 0)
		result.south = neighbors.get("south", 0)
		result.east = neighbors.get("east", 0)
		result.west = neighbors.get("west", 0)
		return result

	func to_dict() -> Dictionary:
		return {
			"north": north,
			"south": south,
			"east": east,
			"west": west
		}
