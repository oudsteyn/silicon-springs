extends Resource
class_name RoadIntersectionLibrary
## Registry for pre-authored junction pieces keyed by topology and lane class.

@export var t_junction_2lane: PackedScene
@export var x_junction_2lane: PackedScene
@export var corner_2lane: PackedScene
@export var t_junction_4lane: PackedScene
@export var x_junction_4lane: PackedScene
@export var corner_4lane: PackedScene
@export var roundabout_small: PackedScene


func get_junction(kind: String, lane_count: int = 2) -> PackedScene:
	var normalized = kind.to_lower()
	if normalized == "roundabout":
		return roundabout_small
	if lane_count >= 4:
		if normalized == "corner":
			return corner_4lane
		if normalized == "t":
			return t_junction_4lane
		if normalized == "x":
			return x_junction_4lane
	else:
		if normalized == "corner":
			return corner_2lane
		if normalized == "t":
			return t_junction_2lane
		if normalized == "x":
			return x_junction_2lane
	return null
