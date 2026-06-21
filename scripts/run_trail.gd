class_name RunTrail
extends Node2D

## Procedural run VFX trailing behind the player, styled by the unlocked speed
## tier (see [PlayerProgress]): dust -> wind -> fire -> electric -> cosmic. The
## base "dust" tier tints to the floor surface. Drawn in world space (top_level)
## so puffs stay where they were dropped while the player runs on. Same chunky
## look as the rest of the game (small pixel squares).

const MOVE_THRESHOLD := 30.0   ## Min px/sec to count as "running".

## Dust colours per floor surface (matches the biome floors).
const DUST := {
	"grass": Color("#7a6242"), "gravel": Color("#6a6452"), "stone": Color("#8d8a82"),
	"metal": Color("#9aa3ad"), "ice": Color("#bcd6e6"), "ember": Color("#5a3a2a"),
	"sand": Color("#d8c08a"), "mud": Color("#5a5436"), "bone": Color("#c9c2a8"),
	"ash": Color("#6a6260"), "crystal": Color("#b48cf0"), "water": Color("#7fb8c4"),
}

var _player: Node2D
var _vfx := "dust"
var _surface := "stone"
var _parts: Array = []          ## [{pos, t, life, vel, col, size}]
var _last := Vector2.ZERO
var _emit_acc := 0.0
var _moving := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	top_level = true             # draw in world space, independent of the player
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rng.randomize()
	_player = get_parent() as Node2D
	if _player != null:
		_last = _player.global_position


## Set the active VFX (from PlayerProgress) and floor surface (for dust colour).
func set_style(vfx: String, surface: String) -> void:
	_vfx = vfx
	_surface = surface


func _process(delta: float) -> void:
	var vel := Vector2.ZERO
	if _player != null and is_instance_valid(_player):
		vel = (_player.global_position - _last) / maxf(delta, 0.0001)
		_last = _player.global_position
	_moving = vel.length() > MOVE_THRESHOLD

	if _moving:
		var period := 1.0 / _emit_rate()
		_emit_acc += delta
		while _emit_acc >= period:
			_emit_acc -= period
			_spawn(_player.global_position, vel)

	for p in _parts:
		p["t"] = float(p["t"]) + delta
		p["pos"] = Vector2(p["pos"]) + Vector2(p["vel"]) * delta
		p["vel"] = Vector2(p["vel"]) * 0.90
	if not _parts.is_empty():
		_parts = _parts.filter(func(p): return float(p["t"]) < float(p["life"]))
	queue_redraw()


func clear() -> void:
	_parts.clear()
	queue_redraw()


# --- Emission --------------------------------------------------------------

func _emit_rate() -> float:
	match _vfx:
		"fire": return 44.0
		"electric": return 48.0
		"cosmic": return 38.0
		"wind": return 30.0
		_: return 24.0


func _spawn(origin: Vector2, vel: Vector2) -> void:
	var back := (-vel).normalized() if vel.length() > 0.01 else Vector2.UP
	var pos := origin + back * 5.0 + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-2, 7))
	var pvel := back * _rng.randf_range(8, 34) + Vector2(_rng.randf_range(-14, 14), _rng.randf_range(-26, -4))
	_parts.append({
		"pos": pos, "t": 0.0, "life": _life(), "vel": pvel,
		"col": _color(), "size": _size(),
	})


func _life() -> float:
	match _vfx:
		"electric": return _rng.randf_range(0.12, 0.22)
		"fire": return _rng.randf_range(0.22, 0.4)
		"cosmic": return _rng.randf_range(0.35, 0.6)
		"wind": return _rng.randf_range(0.18, 0.32)
		_: return _rng.randf_range(0.3, 0.55)


func _size() -> float:
	match _vfx:
		"electric": return 2.0
		"wind": return 2.0
		"cosmic": return 3.0
		_: return _rng.randf_range(2.0, 4.0)


func _color() -> Color:
	match _vfx:
		"fire":
			return Color("#ff8a2c").lerp(Color("#ffe06a"), _rng.randf())
		"electric":
			return Color("#9becff").lerp(Color("#ffffff"), _rng.randf() * 0.6)
		"cosmic":
			return Color.from_hsv(_rng.randf(), 0.7, 1.0)
		"wind":
			return Color(0.9, 0.93, 1.0)
		_:
			return DUST.get(_surface, Color("#8d8a82"))


# --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	# A subtle aura under the player for the energetic tiers.
	if _moving and _player != null and is_instance_valid(_player) and _vfx in ["fire", "electric", "cosmic"]:
		var aura := _color()
		draw_circle(_player.global_position, 13.0, Color(aura.r, aura.g, aura.b, 0.16))

	for p in _parts:
		var life := float(p["life"])
		var a := clampf(1.0 - float(p["t"]) / maxf(life, 0.001), 0.0, 1.0)
		var col: Color = p["col"]
		var s := float(p["size"])
		var pos: Vector2 = p["pos"]
		draw_rect(Rect2(pos - Vector2(s, s) * 0.5, Vector2(s, s)), Color(col.r, col.g, col.b, a * 0.85), true)
