extends Node
class_name AudioManager
## Lightweight audio manager that maps game events to sound effects
## Actual AudioStreamPlayer nodes are created when audio assets are added.

# Event-to-sound mapping
const EVENT_SOUNDS: Dictionary = {
	"building_placed": "place",
	"building_demolished": "demolish",
	"rocks_cleared": "demolish",
	"trees_cleared": "demolish",
	"zone_cleared": "demolish",
	"beach_cleared": "demolish",
	"zone_painted": "zone",
	"path_built": "place",
	"data_center_placed_success": "upgrade",
	"insufficient_funds": "error",
	"ordinance_enacted": "confirm",
	"ordinance_repealed": "confirm",
	"advisor_message": "notify",
	"disaster_started": "alert",
}

# Volume controls
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var _muted: bool = false

# Tracking for tests and debug
var _last_sound_played: String = ""


func _ready() -> void:
	Events.simulation_event.connect(_on_simulation_event)
	Events.building_placed.connect(_on_building_placed)
	Events.building_removed.connect(_on_building_removed)


func _on_simulation_event(event_type: String, _data: Dictionary) -> void:
	var sound = EVENT_SOUNDS.get(event_type, "")
	if sound != "":
		play_sound(sound)


func _on_building_placed(_cell: Vector2i, _building) -> void:
	play_sound("place")


func _on_building_removed(_cell: Vector2i, _building) -> void:
	play_sound("demolish")


## Play a named sound effect. No-op if muted or no audio stream loaded.
func play_sound(sound_name: String) -> void:
	if _muted:
		return

	_last_sound_played = sound_name

	# When audio assets are added, this will look up and play an AudioStreamPlayer
	# For now, this is a no-op beyond tracking the sound name for testability.


func set_master_volume(volume: float) -> void:
	master_volume = clampf(volume, 0.0, 1.0)


func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)


func set_muted(muted: bool) -> void:
	_muted = muted


func is_muted() -> bool:
	return _muted
