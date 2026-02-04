class_name TestHelpers
extends RefCounted
## Shared test helpers for common setup.


static func create_grid_system(parent: Node = null) -> Node:
	var grid_system = GridSystem.new()
	grid_system._building_registry.load_registry()
	if parent:
		parent.add_child(grid_system)
	return grid_system
