extends RefCounted
class_name BuildingLodManager
## Budgeted LOD updater to avoid per-frame spikes.

@export var max_updates_per_frame: int = 24

var _controllers: Array = []
var _cursor: int = 0


func register_controller(controller) -> void:
	if controller == null:
		return
	if controller in _controllers:
		return
	_controllers.append(controller)


func unregister_controller(controller) -> void:
	_controllers.erase(controller)
	if _cursor >= _controllers.size():
		_cursor = 0


func update_budgeted(camera_position: Vector3) -> int:
	if _controllers.is_empty() or max_updates_per_frame <= 0:
		return 0
	var budget = mini(max_updates_per_frame, _controllers.size())
	var updated = 0
	for _i in range(budget):
		if _controllers.is_empty():
			break
		if _cursor >= _controllers.size():
			_cursor = 0
		var controller = _controllers[_cursor]
		_cursor += 1
		if controller == null:
			continue
		if controller.has_method("update_lod"):
			controller.update_lod(camera_position)
			updated += 1
	return updated


func get_controller_count() -> int:
	return _controllers.size()
