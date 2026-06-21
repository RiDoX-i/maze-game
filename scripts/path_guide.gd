extends Node2D

## A temporary glowing trail from a point to the maze exit, shown after collecting
## a guide orb. It lingers only long enough to run the route at the player's
## speed, then fades out. Drawn in world space.

const COLOR := Color("#ff5fe0")

var _points: PackedVector2Array = PackedVector2Array()
var _time_left := 0.0
var _t := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 4
	visible = false


## Show the trail through [param points] (start -> exit) for [param duration] sec.
func show_path(points: Array, duration: float) -> void:
	_points = PackedVector2Array(points)
	_time_left = maxf(duration, 0.1)
	_t = 0.0
	visible = _points.size() >= 2
	queue_redraw()


func clear_path() -> void:
	_points = PackedVector2Array()
	_time_left = 0.0
	visible = false
	queue_redraw()


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left -= delta
	_t += delta
	if _time_left <= 0.0:
		clear_path()
	else:
		queue_redraw()


func _draw() -> void:
	if _points.size() < 2:
		return
	var fade := clampf(_time_left / 1.0, 0.25, 1.0)   # fade out near the end
	# Soft underlay + bright core line.
	draw_polyline(_points, Color(COLOR, 0.25 * fade), 9.0, true)
	draw_polyline(_points, Color(COLOR, 0.85 * fade), 4.0, true)
	# Flowing dots travelling toward the exit.
	for i in _points.size():
		var phase := fposmod(_t * 2.0 - i * 0.35, 1.0)
		if phase < 0.5:
			draw_circle(_points[i], 2.5, Color(1, 1, 1, (0.9 - phase) * fade))
	# Highlight the exit end.
	var goal := _points[_points.size() - 1]
	draw_arc(goal, 10.0 + sin(_t * 6.0) * 2.0, 0.0, TAU, 20, Color(COLOR, fade), 2.0)
