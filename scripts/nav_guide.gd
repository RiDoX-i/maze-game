class_name NavGuide
extends Node2D

## Navigation aid for swipe / corridor-follow play. Draws:
##   * a small dot at every JUNCTION cell — the points where a run stops and the
##     player makes a decision;
##   * while the player is running, a flowing dashed line from the player to the
##     next decision point (where the current corridor-run will stop), capped with
##     a target ring.
## Only used in swipe modes; cleared otherwise. Reads the live run path from the
## player each frame. Drawn above the maze, below the player.

const DOT_COLOR := Color("#bfe9ff")
const HEADING_COLOR := Color("#ffe89a")
const DASH := 7.0
const GAP := 6.0

var _renderer: MazeRenderer
var _player: PlayerController
var _junctions: Array[Vector2] = []
var _heading: Array = []          ## World points: player -> stop cell.
var _active := false
var _t := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Precompute junction positions for this maze and start tracking the player.
func setup(maze, renderer: MazeRenderer, player: PlayerController) -> void:
	_renderer = renderer
	_player = player
	_junctions.clear()
	for cy in maze.height:
		for cx in maze.width:
			var cell := Vector2i(cx, cy)
			if cell == maze.start or cell == maze.exit:
				continue
			if SlideMotion.open_dirs(maze, cell).size() >= 3:
				_junctions.append(renderer.cell_center_world(cell))
	_active = true
	queue_redraw()


func clear() -> void:
	_active = false
	_heading = []
	_junctions.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	_heading = _player.run_path_points() if _player != null and is_instance_valid(_player) else []
	queue_redraw()


func _draw() -> void:
	if not _active:
		return

	# Decision-point dots.
	for p in _junctions:
		draw_circle(p, 5.5, Color(DOT_COLOR.r, DOT_COLOR.g, DOT_COLOR.b, 0.22))
		draw_circle(p, 2.6, Color(DOT_COLOR.r, DOT_COLOR.g, DOT_COLOR.b, 0.85))

	# Heading guide: flowing dashed line to the next stop, with a target ring.
	if _heading.size() >= 2:
		var offset := fmod(_t * 26.0, DASH + GAP)
		for i in range(1, _heading.size()):
			_dashed(_heading[i - 1], _heading[i], HEADING_COLOR, offset)
		var goal: Vector2 = _heading[_heading.size() - 1]
		var pulse := 5.0 + 1.5 * sin(_t * 6.0)
		draw_arc(goal, pulse, 0.0, TAU, 16, HEADING_COLOR, 2.0)


## A dashed segment from [param a] to [param b]; [param phase] scrolls the dashes.
func _dashed(a: Vector2, b: Vector2, color: Color, phase: float) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var dir := (b - a) / length
	var d := -phase
	while d < length:
		var s := maxf(d, 0.0)
		var e := minf(d + DASH, length)
		if e > s:
			draw_line(a + dir * s, a + dir * e, color, 2.0)
		d += DASH + GAP
