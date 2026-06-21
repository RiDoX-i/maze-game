class_name HighScores
extends RefCounted

## Local persistent leaderboard for CLASSIC mode (highest difficulty tier reached).
##
## Trap Mode is a fixed campaign, so only Classic produces a competitive score.
## Entries are stored as plain JSON under user:// so they survive app restarts on
## every platform (Android/iOS included). All access is static; the board is
## cached in memory after the first read.

const SAVE_PATH := "user://world_records.json"
const MAX_ENTRIES := 10          ## Board keeps the top 10 runs.
const NAME_MAX := 8              ## Characters allowed in an entered name.

static var _entries: Array = []   ## [{name:String, tier:int, ts:int}], tier-desc.
static var _loaded := false
static var last_submitted_rank := 0   ## 1-based rank of the most recent submit (for highlight).


## Top entries, highest tier first. Always returns a copy.
static func entries() -> Array:
	_ensure_loaded()
	return _entries.duplicate(true)


## Highest tier on the board (0 if the board is empty).
static func best_tier() -> int:
	_ensure_loaded()
	return int(_entries[0]["tier"]) if not _entries.is_empty() else 0


## Would a run that reached [param tier] earn a place on the board?
static func qualifies(tier: int) -> bool:
	_ensure_loaded()
	if tier < 1:
		return false
	if _entries.size() < MAX_ENTRIES:
		return true
	return tier > int(_entries[_entries.size() - 1]["tier"])


## True if [param tier] beats the current #1 (a brand-new world record).
static func is_new_best(tier: int) -> bool:
	return tier >= 1 and tier > best_tier()


## Insert a finished run and persist. Returns the entry's 1-based rank (1 = top).
static func submit(name: String, tier: int) -> int:
	_ensure_loaded()
	var entry := {"name": _sanitize(name), "tier": maxi(tier, 1), "ts": int(Time.get_unix_time_from_system())}
	_entries.append(entry)
	_entries.sort_custom(_compare)
	if _entries.size() > MAX_ENTRIES:
		_entries.resize(MAX_ENTRIES)
	_save()
	last_submitted_rank = _entries.find(entry) + 1
	return last_submitted_rank


## Wipe the board (used by tests / a future settings reset).
static func clear() -> void:
	_entries = []
	_loaded = true
	_save()


# --- Internals -------------------------------------------------------------

static func _compare(a: Dictionary, b: Dictionary) -> bool:
	if int(a["tier"]) != int(b["tier"]):
		return int(a["tier"]) > int(b["tier"])   # higher tier ranks first
	return int(a.get("ts", 0)) < int(b.get("ts", 0))  # earlier run wins ties


static func _sanitize(name: String) -> String:
	var clean := ""
	for ch in name.strip_edges().to_upper():
		if ch == " " or ch == "-" or ("A" <= ch and ch <= "Z") or ("0" <= ch and ch <= "9"):
			clean += ch
	clean = clean.substr(0, NAME_MAX).strip_edges()
	return clean if clean != "" else "PLAYER"


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_entries = []
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var raw := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_ARRAY:
		return
	for item in parsed:
		if typeof(item) == TYPE_DICTIONARY and item.has("name") and item.has("tier"):
			_entries.append({
				"name": str(item["name"]),
				"tier": int(item["tier"]),
				"ts": int(item.get("ts", 0)),
			})
	_entries.sort_custom(_compare)
	if _entries.size() > MAX_ENTRIES:
		_entries.resize(MAX_ENTRIES)


static func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("HighScores: could not open %s for writing" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(_entries))
	file.close()
