extends TestBase
## Tests for AudioManager event routing

const AudioManagerScript = preload("res://src/audio/audio_manager.gd")

var _to_free: Array = []


func after_each() -> void:
	for i in range(_to_free.size() - 1, -1, -1):
		var instance = _to_free[i]
		if is_instance_valid(instance):
			instance.free()
	_to_free.clear()


func _track(instance):
	_to_free.append(instance)
	return instance


func test_event_to_sound_maps_building_placed() -> void:
	assert_eq(AudioManagerScript.EVENT_SOUNDS.get("building_placed", ""), "place")


func test_event_to_sound_maps_building_demolished() -> void:
	assert_eq(AudioManagerScript.EVENT_SOUNDS.get("building_demolished", ""), "demolish")


func test_event_to_sound_maps_zone_painted() -> void:
	assert_eq(AudioManagerScript.EVENT_SOUNDS.get("zone_painted", ""), "zone")


func test_event_to_sound_maps_insufficient_funds() -> void:
	assert_eq(AudioManagerScript.EVENT_SOUNDS.get("insufficient_funds", ""), "error")


func test_play_sound_tracks_last_played() -> void:
	var mgr = _track(AudioManagerScript.new())

	mgr.play_sound("demolish")

	assert_eq(mgr._last_sound_played, "demolish")


func test_set_master_volume_clamps() -> void:
	var mgr = _track(AudioManagerScript.new())

	mgr.set_master_volume(2.5)
	assert_approx(mgr.master_volume, 1.0)

	mgr.set_master_volume(-0.5)
	assert_approx(mgr.master_volume, 0.0)


func test_set_sfx_volume_clamps() -> void:
	var mgr = _track(AudioManagerScript.new())

	mgr.set_sfx_volume(1.5)
	assert_approx(mgr.sfx_volume, 1.0)


func test_mute_prevents_sound() -> void:
	var mgr = _track(AudioManagerScript.new())
	mgr.set_muted(true)

	mgr.play_sound("place")

	assert_eq(mgr._last_sound_played, "", "Should not play when muted")


func test_on_simulation_event_plays_mapped_sound() -> void:
	var mgr = _track(AudioManagerScript.new())

	mgr._on_simulation_event("building_demolished", {})

	assert_eq(mgr._last_sound_played, "demolish")


func test_on_simulation_event_ignores_unmapped() -> void:
	var mgr = _track(AudioManagerScript.new())

	mgr._on_simulation_event("unknown_event_xyz", {})

	assert_eq(mgr._last_sound_played, "")
