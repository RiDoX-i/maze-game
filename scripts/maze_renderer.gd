class_name MazeRenderer
extends Node2D

## Turns a [MazeGenerator.MazeData] into something visible and collidable, with
## a per-tier pixel-art theme (see [MazeTheme] / [TileForge]).
##
## Draw order: this node draws the tiled floor (and start/exit markers) in
## [method _draw]; a child wall layer draws the wall tiles on top so an animated
## ShaderMaterial can be applied to walls only (electric / lava themes).
##
## Collision is one StaticBody2D whose wall tiles are merged into horizontal runs
## to keep the shape count low (the main perf lever for large mazes).

const TILE := 32  ## Pixel size of one expanded-grid tile.

const COLOR_START := Color("#57f3a0")
const COLOR_EXIT := Color("#ffd166")

const WALL_LAYER := preload("res://scripts/maze_wall_layer.gd")
const ENERGY_SHADER := preload("res://shaders/energy_wall.gdshader")

# Generated textures are cached across mazes/instances (deterministic per theme).
static var _tex_cache: Dictionary = {}

var _maze: MazeGenerator.MazeData
var _floor_tex: Texture2D
var _wall_body: StaticBody2D
var _wall_layer: Node2D
var _energy_mat: ShaderMaterial
var _accent := Color.WHITE   ## Per-chapter tint applied to floor + walls (not markers).


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ensure_wall_layer()


## Render the given maze using the theme for [param tier]. [param accent] is a
## subtle per-chapter tint applied to the floor + walls (markers stay pure).
## Rebuilds visuals and collision.
func render(maze: MazeGenerator.MazeData, tier: int = 1, accent: Color = Color.WHITE) -> void:
	_maze = maze
	_accent = accent
	_ensure_wall_layer()

	var theme := MazeTheme.for_tier(tier)
	var tex := _get_textures(theme.id)
	_floor_tex = tex.floor
	_wall_layer.setup(maze, tex.walls, TILE)
	_wall_layer.material = _theme_material(theme)
	_wall_layer.self_modulate = accent

	_build_collision()
	queue_redraw()


## World-space centre of a cell (for placing the player / detecting the exit).
func cell_center_world(cell: Vector2i) -> Vector2:
	if _maze == null:
		return Vector2.ZERO
	var g := _maze.cell_to_grid(cell)
	return Vector2(g.x * TILE + TILE * 0.5, g.y * TILE + TILE * 0.5)


## Total pixel size of the rendered maze.
func pixel_size() -> Vector2:
	if _maze == null:
		return Vector2.ZERO
	return Vector2(_maze.grid_width * TILE, _maze.grid_height * TILE)


func tile_size() -> int:
	return TILE


# --- Internals -------------------------------------------------------------

func _ensure_wall_layer() -> void:
	if _wall_layer != null and is_instance_valid(_wall_layer):
		return
	_wall_layer = WALL_LAYER.new()
	_wall_layer.name = "WallLayer"
	add_child(_wall_layer)


func _get_textures(theme_id: String) -> Dictionary:
	if not _tex_cache.has(theme_id):
		_tex_cache[theme_id] = _load_or_forge(theme_id)
	return _tex_cache[theme_id]


## Prefer hand-editable PNGs under assets/sprites/tiles/<theme>/ (repaint them in
## Aseprite and the game uses them): floor.png + wall_0.png, wall_1.png, ...
## Falls back to the procedural forge so the game always has art.
func _load_or_forge(theme_id: String) -> Dictionary:
	var base := "res://assets/sprites/tiles/%s/" % theme_id
	var floor_path := base + "floor.png"
	if ResourceLoader.exists(floor_path):
		var floor_tex := load(floor_path) as Texture2D
		var walls: Array = []
		var v := 0
		while ResourceLoader.exists(base + "wall_%d.png" % v):
			var wt := load(base + "wall_%d.png" % v) as Texture2D
			if wt != null:
				walls.append(wt)
			v += 1
		if floor_tex != null and not walls.is_empty():
			return {"floor": floor_tex, "walls": walls}
	return TileForge.textures(theme_id)


func _theme_material(theme: Dictionary) -> ShaderMaterial:
	if not theme.get("animated", false):
		return null
	if _energy_mat == null:
		_energy_mat = ShaderMaterial.new()
		_energy_mat.shader = ENERGY_SHADER
	_energy_mat.set_shader_parameter("glow_color", theme.get("glow", Color("#43e2ff")))
	_energy_mat.set_shader_parameter("speed", theme.get("glow_speed", 5.0))
	return _energy_mat


func _draw() -> void:
	if _maze == null:
		return
	# Tiled floor underlay (one draw call, repeats the 32px tile across the maze),
	# tinted by the per-chapter accent.
	if _floor_tex != null:
		draw_texture_rect(_floor_tex, Rect2(Vector2.ZERO, pixel_size()), true, _accent)
	# Start / exit markers (drawn here, below the wall layer; both sit on floor).
	_draw_marker(_maze.start, COLOR_START)
	_draw_marker(_maze.exit, COLOR_EXIT)


## A layered "gateway" marker: faint halo, two rings, a bright core, plus four
## cardinal pixel studs. Chunky and crisp; the exit's living glow comes from its
## PointLight2D beacon (added by the game scene).
func _draw_marker(cell: Vector2i, color: Color) -> void:
	var center := cell_center_world(cell)
	draw_circle(center, TILE * 0.46, Color(color, 0.16))           # outer halo
	draw_circle(center, TILE * 0.34, Color(color, 0.30))           # mid halo
	draw_circle(center, TILE * 0.30, color.darkened(0.25))         # ring body
	draw_circle(center, TILE * 0.20, color)                        # inner ring
	draw_circle(center, TILE * 0.10, Color.WHITE)                  # bright core
	var stud := TILE * 0.07
	for dir in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		draw_circle(center + dir * TILE * 0.30, stud, color.lightened(0.4))


func _build_collision() -> void:
	if _wall_body != null and is_instance_valid(_wall_body):
		_wall_body.queue_free()
	_wall_body = StaticBody2D.new()
	add_child(_wall_body)

	# Merge consecutive wall tiles in each row into one rectangle to cut the
	# number of collision shapes dramatically versus one-shape-per-tile.
	for gy in _maze.grid_height:
		var run_start := -1
		for gx in range(_maze.grid_width + 1):
			var is_wall: bool = gx < _maze.grid_width and _maze.grid[gx][gy] == 1
			if is_wall and run_start == -1:
				run_start = gx
			elif not is_wall and run_start != -1:
				_add_wall_run(run_start, gx, gy)
				run_start = -1


func _add_wall_run(gx_start: int, gx_end: int, gy: int) -> void:
	var length := gx_end - gx_start
	var shape := RectangleShape2D.new()
	shape.size = Vector2(length * TILE, TILE)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(
		gx_start * TILE + length * TILE * 0.5,
		gy * TILE + TILE * 0.5
	)
	_wall_body.add_child(col)
