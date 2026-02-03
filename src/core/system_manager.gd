class_name SystemManager
extends Node
## Centralized dependency resolution and system access manager
## Uses topological sort for initialization order based on system dependencies

signal systems_initialized()
signal system_registered(system_id: String)

## Metadata class for system registration
class SystemMetadata extends RefCounted:
	var system_id: String
	var dependencies: Array[String]
	var optional_dependencies: Array[String]

	func _init(id: String = "", deps: Array[String] = [], opt_deps: Array[String] = []) -> void:
		system_id = id
		dependencies = deps
		optional_dependencies = opt_deps

var _systems: Dictionary = {}  # {id: Node}
var _metadata: Dictionary = {}  # {id: SystemMetadata}
var _initialized: bool = false


## Register a system with its metadata
func register_system(system: Node, metadata: SystemMetadata) -> void:
	if not metadata or metadata.system_id.is_empty():
		push_error("SystemManager: Cannot register system with empty ID")
		return

	if _systems.has(metadata.system_id):
		push_warning("SystemManager: System '%s' already registered, replacing" % metadata.system_id)

	_systems[metadata.system_id] = system
	_metadata[metadata.system_id] = metadata
	system_registered.emit(metadata.system_id)


## Register a system using BaseSystem's get_metadata() method
func register_base_system(system: BaseSystem) -> void:
	var meta = system.get_metadata()
	var metadata = SystemMetadata.new(
		meta.system_id,
		meta.dependencies,
		meta.optional_dependencies
	)
	register_system(system, metadata)


## Get a system by its ID
func get_system(system_id: String) -> Node:
	return _systems.get(system_id)


## Check if a system is registered
func has_system(system_id: String) -> bool:
	return _systems.has(system_id)


## Get all registered system IDs
func get_registered_systems() -> Array[String]:
	var result: Array[String] = []
	for id in _systems.keys():
		result.append(id)
	return result


## Initialize all systems in dependency order
## Returns true if successful, false if there are circular dependencies or missing required deps
func initialize_all() -> bool:
	if _initialized:
		push_warning("SystemManager: Systems already initialized")
		return true

	# Validate dependencies
	var validation = _validate_dependencies()
	if not validation.valid:
		push_error("SystemManager: Dependency validation failed: %s" % validation.error)
		return false

	# Topological sort
	var order = _topological_sort()
	if order.is_empty() and _systems.size() > 0:
		push_error("SystemManager: Circular dependency detected")
		return false

	# Inject dependencies and initialize in order
	for system_id in order:
		var system = _systems[system_id]
		var metadata = _metadata[system_id]

		# Inject required dependencies
		for dep_id in metadata.dependencies:
			_inject_dependency(system, dep_id)

		# Inject optional dependencies (if available)
		for dep_id in metadata.optional_dependencies:
			if _systems.has(dep_id):
				_inject_dependency(system, dep_id)

		# Call system_initialize if the system extends BaseSystem
		if system.has_method("system_initialize"):
			system.system_initialize()

	_initialized = true
	systems_initialized.emit()
	return true


## Validate that all required dependencies exist
func _validate_dependencies() -> Dictionary:
	for system_id in _metadata:
		var metadata = _metadata[system_id]
		for dep_id in metadata.dependencies:
			if not _systems.has(dep_id):
				return {
					"valid": false,
					"error": "System '%s' requires '%s' which is not registered" % [system_id, dep_id]
				}
	return {"valid": true, "error": ""}


## Topological sort using Kahn's algorithm
## Returns empty array on circular dependency; use get_circular_dependency_info() for details
func _topological_sort() -> Array[String]:
	var result: Array[String] = []
	var in_degree: Dictionary = {}
	var queue: Array[String] = []

	# Initialize in-degree for all systems
	for system_id in _systems:
		in_degree[system_id] = 0

	# Calculate in-degrees based on dependencies
	for system_id in _metadata:
		var metadata = _metadata[system_id]
		# Only count required dependencies for ordering
		for dep_id in metadata.dependencies:
			if in_degree.has(system_id):
				in_degree[system_id] += 1
		# Optional dependencies also affect order if present
		for dep_id in metadata.optional_dependencies:
			if _systems.has(dep_id):
				in_degree[system_id] += 1

	# Find all systems with no dependencies
	for system_id in in_degree:
		if in_degree[system_id] == 0:
			queue.append(system_id)

	# Process queue
	while queue.size() > 0:
		var current = queue.pop_front()
		result.append(current)

		# Reduce in-degree for systems that depend on current
		for system_id in _metadata:
			var metadata = _metadata[system_id]
			var depends_on_current = current in metadata.dependencies
			var optionally_depends = current in metadata.optional_dependencies and _systems.has(current)

			if depends_on_current or optionally_depends:
				in_degree[system_id] -= 1
				if in_degree[system_id] == 0:
					queue.append(system_id)

	# Check for cycle
	if result.size() != _systems.size():
		_report_circular_dependency(result, in_degree)
		return []

	return result


## Report detailed information about circular dependencies
func _report_circular_dependency(sorted: Array[String], in_degree: Dictionary) -> void:
	# Find systems that weren't sorted (they're in the cycle)
	var unsorted: Array[String] = []
	for system_id in _systems:
		if system_id not in sorted:
			unsorted.append(system_id)

	# Build detailed error message
	var error_msg = "Circular dependency detected involving systems: %s\n" % str(unsorted)
	error_msg += "Dependency chains:\n"

	for system_id in unsorted:
		var metadata = _metadata[system_id]
		var deps_in_cycle: Array[String] = []
		for dep_id in metadata.dependencies:
			if dep_id in unsorted:
				deps_in_cycle.append(dep_id)
		for dep_id in metadata.optional_dependencies:
			if dep_id in unsorted and _systems.has(dep_id):
				deps_in_cycle.append(dep_id + " (optional)")

		var remaining_deps = in_degree.get(system_id, 0)
		if deps_in_cycle.size() > 0:
			error_msg += "  %s (unresolved: %d) -> %s\n" % [system_id, remaining_deps, str(deps_in_cycle)]

	push_error("SystemManager: %s" % error_msg)

	# Also assert in debug builds to catch this early
	assert(false, "SystemManager: Circular dependency detected - see above for details")


## Inject a dependency into a system using set_X_system() convention
func _inject_dependency(system: Node, dep_id: String) -> void:
	var dep_system = _systems.get(dep_id)
	if not dep_system:
		return

	# Try common setter naming conventions
	var setter_names = [
		"set_%s_system" % dep_id,
		"set_%s" % dep_id,
		"initialize"
	]

	for setter_name in setter_names:
		if system.has_method(setter_name):
			# Special case for initialize which might take multiple args
			if setter_name == "initialize":
				# Skip - this is handled by system_initialize()
				continue
			system.call(setter_name, dep_system)
			return

	# Store as property if no setter found
	var prop_names = [
		"%s_system" % dep_id,
		dep_id
	]

	for prop_name in prop_names:
		if prop_name in system:
			system.set(prop_name, dep_system)
			return


## Check if systems have been initialized
func is_initialized() -> bool:
	return _initialized


## Reset the manager (for testing or reloading)
func reset() -> void:
	_systems.clear()
	_metadata.clear()
	_initialized = false
