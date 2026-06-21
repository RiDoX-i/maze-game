extends Node2D

## Pickups for Classic mode. Two kinds:
##   "time"  -> +5 seconds when touched (blue coins, placed on the correct route).
##   "guide" -> rare orb (magenta); restarts the timer AND reveals the path to the
##              exit for a while. Can spawn anywhere reachable, not just on-route.
## Drawn in world space, gently bobbing, picked up on contact.

const PICKUP_RADIUS := 18.0
const BONUS_SECONDS := 5.0
const TIME_COLOR := Color("#39b6ff")    ## +5s coins (blue) — distinct from gold exit.
const GUIDE_COLOR := Color("#ff5fe0")   ## rare guide orb (magenta).

var _coins: Array = []   ## [{pos:Vector2, t:float, kind:String}]


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Place pickups for the current maze. Both args are arrays of world positions.
func setup(time_positions: Array, guide_positions: Array) -> void:
	_coins.clear()
	for p in time_positions:
		_coins.append({"pos": p, "t": randf() * TAU, "kind": "time"})
	for p in guide_positions:
		_coins.append({"pos": p, "t": randf() * TAU, "kind": "guide"})
	queue_redraw()


func clear_coins() -> void:
	_coins.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _coins.is_empty():
		return
	for coin in _coins:
		coin["t"] = float(coin["t"]) + delta
	queue_redraw()


## Collect any pickups within reach; returns the kinds collected this call.
func collect_at(world_pos: Vector2) -> Array:
	if _coins.is_empty():
		return []
	var taken: Array = []
	var kept: Array = []
	for coin in _coins:
		if Vector2(coin["pos"]).distance_to(world_pos) <= PICKUP_RADIUS:
			taken.append(String(coin["kind"]))
		else:
			kept.append(coin)
	if not taken.is_empty():
		_coins = kept
		queue_redraw()
	return taken


func _draw() -> void:
	for coin in _coins:
		var bob := sin(float(coin["t"]) * 3.0) * 2.0
		var p := Vector2(coin["pos"]) + Vector2(0, bob)
		if String(coin["kind"]) == "guide":
			_draw_guide(p, float(coin["t"]))
		else:
			_draw_time_coin(p)


func _draw_time_coin(p: Vector2) -> void:
	draw_circle(p + Vector2(0, 3), 7.0, Color(0, 0, 0, 0.25))   # shadow
	draw_circle(p, 9.0, TIME_COLOR)                             # body
	draw_arc(p, 9.0, 0.0, TAU, 18, Color("#1d6fb0"), 2.0)       # rim
	# Little clock hands to read as "+time".
	draw_line(p, p + Vector2(0, -5), Color.WHITE, 1.5)
	draw_line(p, p + Vector2(4, 0), Color.WHITE, 1.5)
	draw_circle(p + Vector2(-2.5, -2.5), 2.0, Color("#d6f0ff"))  # glint


func _draw_guide(p: Vector2, t: float) -> void:
	var pulse := 1.0 + sin(t * 4.0) * 0.18
	draw_circle(p + Vector2(0, 3), 8.0, Color(0, 0, 0, 0.25))           # shadow
	draw_circle(p, 11.0 * pulse, Color(GUIDE_COLOR, 0.20))              # halo
	draw_arc(p, 10.0 * pulse, 0.0, TAU, 22, GUIDE_COLOR, 2.0)          # ring
	draw_circle(p, 5.0, GUIDE_COLOR)                                    # core
	# Compass-y cross.
	draw_line(p + Vector2(0, -8), p + Vector2(0, 8), Color.WHITE, 1.0)
	draw_line(p + Vector2(-8, 0), p + Vector2(8, 0), Color.WHITE, 1.0)
