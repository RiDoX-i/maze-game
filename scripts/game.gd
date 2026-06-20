extends Node2D

## Orchestrates a single maze: generate -> render -> position player -> run the
## countdown -> detect win/lose -> drive the GameState transitions. On a full
## run reset it hands off to the game-over scene.

const GAME_OVER_SCENE := "res://scenes/game_over.tscn"
const EXIT_REACH_RADIUS := 16.0   ## How close (px) to the exit centre counts as escaped.
const TRANSITION_DELAY := 0.45    ## Brief pause between mazes so feedback registers.

@onready var _renderer: MazeRenderer = $MazeRenderer
@onready var _player: PlayerController = $Player
@onready var _camera: Camera2D = $Camera2D
@onready var _hud = $UI/HUD

var _time_left: float = 0.0
var _exit_world := Vector2.ZERO
var _running := false


func _ready() -> void:
	_start_maze()


func _physics_process(delta: float) -> void:
	if not _running:
		return

	_time_left -= delta
	_hud.set_time(_time_left)

	if _player.global_position.distance_to(_exit_world) <= EXIT_REACH_RADIUS:
		_on_win()
	elif _time_left <= 0.0:
		_on_lose()


func _start_maze() -> void:
	var dims := GameState.get_maze_dimensions()
	var maze := MazeGenerator.generate(dims.x, dims.y, -1, GameState.get_branchiness())
	_renderer.render(maze, GameState.current_tier)

	_player.place_at(_renderer.cell_center_world(maze.start))
	_player.set_footstep_surface(MazeTheme.for_tier(GameState.current_tier).get("step", "stone"))
	_player.active = true
	_exit_world = _renderer.cell_center_world(maze.exit)

	# World distance per solution step is two grid tiles (cell centre to centre).
	var step_px := _renderer.tile_size() * 2.0
	_time_left = TimerManager.compute_for_maze(maze, GameState.current_tier, step_px, _player.speed)
	_hud.set_time(_time_left)

	_fit_camera(maze)
	_running = true


func _on_win() -> void:
	_end_round()
	GameState.on_maze_won()
	_queue_next_maze()


func _on_lose() -> void:
	_end_round()
	var run_over := GameState.on_maze_lost()
	if run_over:
		get_tree().change_scene_to_file(GAME_OVER_SCENE)
	else:
		_queue_next_maze()


func _end_round() -> void:
	_running = false
	_player.active = false


func _queue_next_maze() -> void:
	# Small delay so heart/win feedback is visible before regenerating.
	var timer := get_tree().create_timer(TRANSITION_DELAY)
	timer.timeout.connect(_start_maze)


func _fit_camera(maze: MazeGenerator.MazeData) -> void:
	# Centre the camera on the maze and zoom so the whole thing fits the screen.
	var maze_px := _renderer.pixel_size()
	_camera.position = maze_px * 0.5
	var viewport := get_viewport_rect().size
	var margin := 1.12  # leave a little breathing room around the edges
	var zoom_factor: float = minf(
		viewport.x / (maze_px.x * margin),
		viewport.y / (maze_px.y * margin)
	)
	_camera.zoom = Vector2(zoom_factor, zoom_factor)
