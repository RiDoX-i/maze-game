class_name GameSettings
extends RefCounted

## Persisted player settings. Currently: the control scheme per game mode, so the
## player can pick swipe (corridor-follow) or the analog joystick independently for
## CLASSIC, ENDLESS and TRAP. Defaults match the built-in behaviour (swipe for the
## campaign/endless runs, joystick for the trap dodger). Stored as JSON under
## user:// (mirrors the other persistence helpers); all access is static.

const SAVE_PATH := "user://settings.json"
const SWIPE := "swipe"
const JOYSTICK := "joystick"

const MODE_KEYS := ["classic", "endless", "trap"]
const DEFAULTS := {"classic": SWIPE, "endless": SWIPE, "trap": JOYSTICK}

static var _controls: Dictionary = {}
static var _loaded := false


## Control scheme ("swipe"/"joystick") for a mode key ("classic"/"endless"/"trap").
static func control_for(mode_key: String) -> String:
	_ensure_loaded()
	return _controls.get(mode_key, DEFAULTS.get(mode_key, SWIPE))


static func is_swipe(mode_key: String) -> bool:
	return control_for(mode_key) == SWIPE


## Set and persist a mode's control scheme (normalised to a known value).
static func set_control(mode_key: String, scheme: String) -> void:
	_ensure_loaded()
	_controls[mode_key] = SWIPE if scheme == SWIPE else JOYSTICK
	_save()


## Restore defaults (tests / future settings reset).
static func reset() -> void:
	_controls = DEFAULTS.duplicate()
	_loaded = true
	_save()


# --- Internals -------------------------------------------------------------

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_controls = DEFAULTS.duplicate()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var raw := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("controls"):
		var saved = parsed["controls"]
		if typeof(saved) == TYPE_DICTIONARY:
			for key in MODE_KEYS:
				if saved.has(key):
					_controls[key] = SWIPE if str(saved[key]) == SWIPE else JOYSTICK


static func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameSettings: could not open %s for writing" % SAVE_PATH)
		return
	file.store_string(JSON.stringify({"controls": _controls}))
	file.close()
