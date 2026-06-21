class_name PlayerProgress
extends RefCounted

## Persistent meta-progression: total XP earned and the player's chosen speed.
##
## Winning any map grants XP (see [method xp_for_win]); accumulated XP unlocks
## faster speed tiers, each with its own running VFX. Unlocks are CUMULATIVE
## thresholds (never spent), so the fastest tier is a long-term goal. Stored as
## JSON under user:// (mirrors [HighScores] / [CampaignProgress]); all static.

const SAVE_PATH := "user://player_progress.json"

## Five speeds, ascending. `speed` is px/sec; `vfx` selects the run trail style;
## `unlock_xp` is the cumulative XP needed (steep toward the top — "a bit hard").
const SPEEDS := [
	{"name": "RUNNER",   "speed": 320.0, "vfx": "dust",     "unlock_xp": 0},
	{"name": "SPRINTER", "speed": 385.0, "vfx": "wind",     "unlock_xp": 150},
	{"name": "BLAZE",    "speed": 455.0, "vfx": "fire",     "unlock_xp": 500},
	{"name": "VOLT",     "speed": 540.0, "vfx": "electric", "unlock_xp": 1200},
	{"name": "MYTHIC",   "speed": 640.0, "vfx": "cosmic",   "unlock_xp": 2500},
]

static var _xp: int = -1          ## -1 = not loaded yet.
static var _selected: int = 0


## XP awarded for clearing a map of difficulty [param tier]: 10, 15, 20, …
static func xp_for_win(tier: int) -> int:
	return 10 + (maxi(tier, 1) - 1) * 5


static func total_xp() -> int:
	_ensure_loaded()
	return _xp


## Add XP and persist. Returns the indices of any speed tiers newly unlocked by
## this gain (for a celebratory announce).
static func add_xp(amount: int) -> Array:
	_ensure_loaded()
	var before := _xp
	_xp += maxi(amount, 0)
	var newly: Array = []
	for i in SPEEDS.size():
		var need: int = int(SPEEDS[i]["unlock_xp"])
		if before < need and _xp >= need:
			newly.append(i)
	_save()
	return newly


static func is_unlocked(index: int) -> bool:
	_ensure_loaded()
	if index < 0 or index >= SPEEDS.size():
		return false
	return _xp >= int(SPEEDS[index]["unlock_xp"])


## Remaining XP needed to unlock [param index] (0 if already unlocked).
static func xp_to_unlock(index: int) -> int:
	_ensure_loaded()
	if index < 0 or index >= SPEEDS.size():
		return 0
	return maxi(int(SPEEDS[index]["unlock_xp"]) - _xp, 0)


static func highest_unlocked() -> int:
	_ensure_loaded()
	var best := 0
	for i in SPEEDS.size():
		if _xp >= int(SPEEDS[i]["unlock_xp"]):
			best = i
	return best


static func selected_index() -> int:
	_ensure_loaded()
	if not is_unlocked(_selected):
		_selected = highest_unlocked()
	return _selected


## Select a speed (only if unlocked). Returns true on success.
static func select_speed(index: int) -> bool:
	_ensure_loaded()
	if not is_unlocked(index):
		return false
	_selected = index
	_save()
	return true


static func current() -> Dictionary:
	return SPEEDS[selected_index()]


static func current_speed() -> float:
	return float(current()["speed"])


static func current_vfx() -> String:
	return str(current()["vfx"])


## Wipe progress (tests / future settings reset).
static func reset() -> void:
	_xp = 0
	_selected = 0
	_save()


# --- Internals -------------------------------------------------------------

static func _ensure_loaded() -> void:
	if _xp >= 0:
		return
	_xp = 0
	_selected = 0
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var raw := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		_xp = maxi(int(parsed.get("xp", 0)), 0)
		_selected = clampi(int(parsed.get("speed", 0)), 0, SPEEDS.size() - 1)


static func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("PlayerProgress: could not open %s for writing" % SAVE_PATH)
		return
	file.store_string(JSON.stringify({"xp": _xp, "speed": _selected}))
	file.close()
