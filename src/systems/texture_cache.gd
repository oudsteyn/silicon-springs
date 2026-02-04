extends RefCounted
class_name TextureCache
## Simple LRU cache with hit/miss stats.

var _cache: Dictionary = {}
var _access_order: Array[String] = []
var _hits: int = 0
var _misses: int = 0
var _max_size: int = 0


func _init(max_size: int = 500) -> void:
	_max_size = max_size


func put(key: String, value) -> void:
	if _cache.has(key):
		_access_order.erase(key)
	elif _cache.size() >= _max_size and _access_order.size() > 0:
		var oldest_key = _access_order.pop_front()
		_cache.erase(oldest_key)

	_cache[key] = value
	_access_order.append(key)


func fetch(key: String):
	if _cache.has(key):
		_hits += 1
		_access_order.erase(key)
		_access_order.append(key)
		return _cache[key]

	_misses += 1
	return null


func clear() -> void:
	_cache.clear()
	_access_order.clear()
	_hits = 0
	_misses = 0


func get_stats() -> Dictionary:
	var total_requests = _hits + _misses
	var hit_rate = 0.0
	if total_requests > 0:
		hit_rate = float(_hits) / float(total_requests)
	return {
		"size": _cache.size(),
		"max_size": _max_size,
		"hits": _hits,
		"misses": _misses,
		"hit_rate": hit_rate
	}
