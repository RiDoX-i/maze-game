class_name PlayerController
extends CharacterBody2D

## Swipe / corridor-follow movement.
##
## A swipe (or an arrow/WASD press) picks a cardinal direction; the runner then
## glides along the maze corridor — auto-turning at bends — and stops only at a
## junction, a dead-end, or the exit (see [SlideMotion]). One swipe flows the
## character all the way down a winding passage instead of stopping at every turn.
##
## [member glide_speed] is the player's chosen speed (from [PlayerProgress]) and
## drives actual motion; [member base_speed] is the fixed reference the timer uses
## so a faster character genuinely gains time. Movement is frozen between mazes
## via [member active]. The footstep audio system is unchanged.

@export var base_speed: float = 320.0  ## Fixed reference for the time budget (never upgraded).
@export var glide_speed: float = 320.0 ## Actual run speed (set from the unlocked speed tier).
@export_range(-24.0, 3.0, 0.5) var footstep_volume_db := -8.0  ## Soft taps sit low in the mix.
@export var debug_footsteps := false ## Print each trigger and bus state when diagnosing audio.

const STRIDE_PX := 76.0  ## Running cadence: footfall every this many px travelled.
const STEP_VOICES := 2   ## Alternate feet so one sound never cuts off the other.
const ARRIVE_EPS := 1.5  ## Snap distance (px) when reaching a waypoint.

var active: bool = false
## true  = swipe / corridor-follow (CLASSIC + ENDLESS).
## false = analog joystick + continuous movement (TRAP only).
var swipe_mode: bool = true

# Corridor-slide state. _path holds the FULL run (origin at [0] .. stop cell);
# _idx is the waypoint currently moving toward; _dir_sign is +1 forward / -1 when
# the player cancelled the run and is retracing back to the origin.
var _maze: MazeGenerator.MazeData
var _renderer: MazeRenderer
var _cell := Vector2i.ZERO
var _path: Array[Vector2i] = []
var _idx := 0
var _dir_sign := 1
var _slide_dir := Vector2i.ZERO        ## Initial swipe direction (for cancel detection).
var _sliding := false
var _swipe: Node = null
var _joystick: Node = null             ## TRAP-mode analog stick.

# Footstep audio.
var _step_players: Array[AudioStreamPlayer] = []
var _step_streams: Array[AudioStreamWAV] = []
var _step_surface := "stone"
var _step_index := 0
var _step_rng := RandomNumberGenerator.new()
var _last_pos := Vector2.ZERO
var _stride_acc := 0.0


func _ready() -> void:
	add_to_group("player")
	_step_rng.randomize()
	for voice_index in STEP_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "FootstepVoice%d" % (voice_index + 1)
		voice.bus = "Master"
		voice.volume_db = footstep_volume_db
		add_child(voice)
		_step_players.append(voice)
	_last_pos = global_position


## Bind the maze/renderer for this round and place the runner at the start cell.
func begin_maze(maze: MazeGenerator.MazeData, renderer: MazeRenderer) -> void:
	_maze = maze
	_renderer = renderer
	_cell = maze.start
	_end_slide()
	velocity = Vector2.ZERO
	if renderer != null:
		var p := renderer.cell_center_world(maze.start)
		global_position = p
		_last_pos = p


## Begin a slide in [param dir] (called by swipe signal or keyboard). While already
## running, a swipe OPPOSITE the travel direction cancels the run and retraces back
## to the decision point it started from; other directions are ignored mid-run.
func request_direction(dir: Vector2i) -> void:
	if not active or _maze == null or _renderer == null:
		return
	if _sliding:
		_maybe_cancel(dir)
		return
	var cells := SlideMotion.compute(_maze, _cell, dir)
	if cells.is_empty():
		return
	_path = [_cell]
	_path.append_array(cells)
	_idx = 1
	_dir_sign = 1
	_slide_dir = dir
	_sliding = true


## Reverse an in-progress run if the swipe points back against travel (or against
## the run's initial direction). Once reversing, ignore further swipes — the
## runner returns all the way to the origin decision point and stops.
func _maybe_cancel(dir: Vector2i) -> void:
	if _dir_sign < 0:
		return
	var heading := _current_heading()
	if dir == -heading or dir == -_slide_dir:
		_dir_sign = -1
		_idx -= 1                       # aim at the cell behind us, then back to origin


## Cardinal direction the runner is currently moving (from velocity).
func _current_heading() -> Vector2i:
	if velocity.length() < 1.0:
		return Vector2i.ZERO
	if absf(velocity.x) >= absf(velocity.y):
		return Vector2i(1, 0) if velocity.x > 0.0 else Vector2i(-1, 0)
	return Vector2i(0, 1) if velocity.y > 0.0 else Vector2i(0, -1)


func _end_slide() -> void:
	_sliding = false
	_path.clear()
	_idx = 0
	_dir_sign = 1
	_slide_dir = Vector2i.ZERO
	velocity = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if not active:
		velocity = Vector2.ZERO
		_last_pos = global_position
		return

	if swipe_mode:
		_ensure_swipe_connected()
		var kd := _keyboard_dir()
		if kd != Vector2i.ZERO:
			request_direction(kd)   # starts a run when idle, or cancels when opposite
		if _sliding:
			_advance_slide(delta)
		else:
			velocity = Vector2.ZERO
	else:
		_continuous_move()

	_update_footsteps()


## TRAP mode: free analog movement from the joystick + keyboard, with wall slide.
func _continuous_move() -> void:
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var stick := _resolve_joystick()
	if stick != null:
		dir += stick.get_output()
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity = dir * glide_speed
	move_and_slide()


## Find the joystick lazily (it joins the "joystick" group in its own _ready).
func _resolve_joystick() -> Node:
	if _joystick != null and is_instance_valid(_joystick):
		return _joystick
	for s in get_tree().get_nodes_in_group("joystick"):
		if s.has_method("get_output"):
			_joystick = s
			return _joystick
	return null


## Glide toward the current waypoint; on arrival step the index by the direction
## sign (forward to the stop cell, or backward to the origin when cancelled).
func _advance_slide(delta: float) -> void:
	if _idx < 0 or _idx >= _path.size():
		_end_slide()
		return
	var target := _renderer.cell_center_world(_path[_idx])
	var to := target - global_position
	var dist := to.length()
	var step := glide_speed * delta
	if dist <= maxf(step, ARRIVE_EPS):
		global_position = target
		_cell = _path[_idx]
		_idx += _dir_sign
		if _idx < 0 or _idx >= _path.size():
			_end_slide()
		else:
			velocity = (_renderer.cell_center_world(_path[_idx]) - global_position).normalized() * glide_speed
	else:
		var heading := to / dist
		velocity = heading * glide_speed
		global_position += heading * step


## World points of the current run (player position -> remaining cells in travel
## order), for the navigation heading guide. Follows the reverse path after a
## cancel. Empty when idle / not in swipe mode.
func run_path_points() -> Array:
	if not _sliding or _renderer == null:
		return []
	var pts: Array = [global_position]
	if _dir_sign > 0:
		for i in range(_idx, _path.size()):
			pts.append(_renderer.cell_center_world(_path[i]))
	else:
		for i in range(_idx, -1, -1):
			pts.append(_renderer.cell_center_world(_path[i]))
	return pts


func _keyboard_dir() -> Vector2i:
	if Input.is_action_pressed("move_up"):
		return Vector2i(0, -1)
	if Input.is_action_pressed("move_down"):
		return Vector2i(0, 1)
	if Input.is_action_pressed("move_left"):
		return Vector2i(-1, 0)
	if Input.is_action_pressed("move_right"):
		return Vector2i(1, 0)
	return Vector2i.ZERO


## Find the swipe input (joins its group in _ready, possibly after us) and wire it.
func _ensure_swipe_connected() -> void:
	if _swipe != null and is_instance_valid(_swipe):
		return
	for s in get_tree().get_nodes_in_group("swipe_input"):
		if s.has_signal("swiped"):
			_swipe = s
			if not s.swiped.is_connected(request_direction):
				s.swiped.connect(request_direction)
			return


# --- Footsteps (unchanged behaviour) ---------------------------------------

## Set the ground surface for footstep audio (called per maze by the game).
func set_footstep_surface(surface: String) -> void:
	_step_surface = surface if FootstepForge.supports(surface) else "stone"
	_step_streams = FootstepForge.get_steps(_step_surface)
	_step_index = 0


## A single spawn/landing sound confirms the SFX path before the player moves.
func play_spawn_step() -> void:
	if _step_streams.is_empty():
		set_footstep_surface(_step_surface)
	_play_footstep()


func _update_footsteps() -> void:
	_stride_acc += global_position.distance_to(_last_pos)
	_last_pos = global_position
	if _stride_acc >= STRIDE_PX and velocity.length() > 10.0:
		_stride_acc -= STRIDE_PX
		if _step_streams.is_empty():
			set_footstep_surface(_step_surface)
		_play_footstep()


func _play_footstep() -> void:
	var voice := _step_players[_step_index % _step_players.size()]
	var step_stream := _step_streams[_step_index % _step_streams.size()]
	voice.stream = step_stream
	# Keep variation restrained: enough life to avoid repetition, never cartoonish.
	voice.pitch_scale = _step_rng.randf_range(0.975, 1.03)
	voice.volume_db = footstep_volume_db + _step_rng.randf_range(-0.5, 0.4)
	voice.play()
	if debug_footsteps:
		var master_index := AudioServer.get_bus_index("Master")
		print("FOOTSTEP surface=%s variant=%d bytes=%d playing=%s master_muted=%s master_db=%.1f" % [
			_step_surface,
			_step_index % _step_streams.size(),
			step_stream.data.size(),
			voice.playing,
			AudioServer.is_bus_mute(master_index),
			AudioServer.get_bus_volume_db(master_index),
		])
	_step_index += 1


## Snap the player to a world position and stop motion.
func place_at(world_pos: Vector2) -> void:
	global_position = world_pos
	velocity = Vector2.ZERO
	_end_slide()
	_last_pos = world_pos       # avoid a teleport-sized stride on respawn
	_stride_acc = STRIDE_PX * 0.75  # first running step is heard almost immediately
