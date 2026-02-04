extends TestBase
## Tests for LRU TextureCache helper.

const TextureCache = preload("res://src/systems/texture_cache.gd")


class DummyValue extends RefCounted:
	var label: String
	func _init(value: String) -> void:
		label = value


func test_lru_eviction_respects_recent_access() -> void:
	var cache = TextureCache.new(2)
	var a = DummyValue.new("a")
	var b = DummyValue.new("b")
	var c = DummyValue.new("c")

	cache.put("a", a)
	cache.put("b", b)
	# Access a so b becomes least-recently-used
	assert_eq(cache.fetch("a"), a)

	cache.put("c", c)
	assert_not_null(cache.fetch("a"))
	assert_not_null(cache.fetch("c"))
	assert_null(cache.fetch("b"))


func test_stats_track_hits_and_misses() -> void:
	var cache = TextureCache.new(2)
	cache.put("a", DummyValue.new("a"))
	assert_not_null(cache.fetch("a"))
	assert_null(cache.fetch("missing"))

	var stats = cache.get_stats()
	assert_eq(stats.hits, 1)
	assert_eq(stats.misses, 1)
	assert_eq(stats.size, 1)
	assert_eq(stats.max_size, 2)


func test_clear_resets_cache_and_stats() -> void:
	var cache = TextureCache.new(1)
	cache.put("a", DummyValue.new("a"))
	cache.fetch("a")
	cache.fetch("missing")

	cache.clear()
	var stats = cache.get_stats()
	assert_eq(stats.size, 0)
	assert_eq(stats.hits, 0)
	assert_eq(stats.misses, 0)
