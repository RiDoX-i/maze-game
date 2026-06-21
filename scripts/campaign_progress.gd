class_name CampaignProgress
extends RefCounted

## Local persistent progress for the CLASSIC campaign (1000 ordered levels).
##
## Only ONE level is playable at a time: the lowest uncompleted one. Winning it
## marks it completed (it can never be replayed) and unlocks the next. Stored as
## plain JSON under user:// so it survives app restarts on every platform. All
## access is static; the value is cached after the first read.
##
## TOTAL_LEVELS is duplicated here (not read from GameState) so this stays a pure,
## autoload-independent unit testable from the headless test runner.

const SAVE_PATH := "user://campaign_progress.json"
const TOTAL_LEVELS := 1000

static var _completed: int = -1   ## -1 = not loaded yet.


## Number of levels beaten so far (0..TOTAL_LEVELS).
static func levels_completed() -> int:
	_ensure_loaded()
	return _completed


## The single playable level: the lowest uncompleted one (capped at the last).
static func current_level() -> int:
	_ensure_loaded()
	return mini(_completed + 1, TOTAL_LEVELS)


## Has [param level] already been beaten? (Completed levels cannot be replayed.)
static func is_completed(level: int) -> bool:
	_ensure_loaded()
	return level <= _completed


## Is [param level] the one the player may currently play?
static func is_unlocked(level: int) -> bool:
	return level == current_level() and not is_campaign_complete()


## Have all 1000 levels been cleared?
static func is_campaign_complete() -> bool:
	_ensure_loaded()
	return _completed >= TOTAL_LEVELS


## Record a win for [param level]. Only advances when it is the current playable
## level (so you cannot skip ahead or re-complete an old one). Returns true if
## this completion finished the whole campaign.
static func complete_level(level: int) -> bool:
	_ensure_loaded()
	if level == _completed + 1 and _completed < TOTAL_LEVELS:
		_completed += 1
		_save()
	return is_campaign_complete()


## Wipe all progress (used by tests / a future settings reset).
static func reset() -> void:
	_completed = 0
	_save()


# --- Internals -------------------------------------------------------------

static func _ensure_loaded() -> void:
	if _completed >= 0:
		return
	_completed = 0
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var raw := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("completed"):
		_completed = clampi(int(parsed["completed"]), 0, TOTAL_LEVELS)


static func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("CampaignProgress: could not open %s for writing" % SAVE_PATH)
		return
	file.store_string(JSON.stringify({"completed": _completed}))
	file.close()
