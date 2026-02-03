class_name SystemGroup
extends Node
## Groups related systems together for organization and control
## Provides pause/resume functionality for system groups

@export var group_name: String = ""

## Pause all child systems (stop processing)
func pause_systems() -> void:
	for child in get_children():
		if child.has_method("set_process"):
			child.set_process(false)
		if child.has_method("set_physics_process"):
			child.set_physics_process(false)


## Resume all child systems (start processing)
func resume_systems() -> void:
	for child in get_children():
		if child.has_method("set_process"):
			child.set_process(true)
		if child.has_method("set_physics_process"):
			child.set_physics_process(true)


## Get a system by name from this group
func get_system(system_name: String) -> Node:
	return get_node_or_null(system_name)


## Check if this group contains a system
func has_system(system_name: String) -> bool:
	return has_node(system_name)


## Get all systems in this group
func get_all_systems() -> Array[Node]:
	var systems: Array[Node] = []
	for child in get_children():
		systems.append(child)
	return systems


## Get the count of systems in this group
func get_system_count() -> int:
	return get_child_count()
