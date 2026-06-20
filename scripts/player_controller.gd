class_name PlayerController
extends CharacterBody2D

## Continuous (analog) player movement with wall collision.
##
## Combines two input sources so the game is playable on both desktop and
## mobile:
##   * keyboard move_* actions (registered at runtime by GameState)
##   * a virtual joystick in the "joystick" group, if present
##
## Movement can be frozen between mazes / on game over via [member active].

@export var speed: float = 275.0  ## 1.25x the original 220.

const STRIDE_PX := 90.0  ## Distance walked between footsteps (~3 steps/sec at speed).

var active: bool = false
var _joystick: Node = null
var _step_player: AudioStreamPlayer
var _step_surface := "stone"
var _last_pos := Vector2.ZERO
var _stride_acc := 0.0


func _ready() -> void:
	add_to_group("player")
	_step_player = AudioStreamPlayer.new()
	_step_player.bus = "Master"
	_step_player.volume_db = -7.0
	add_child(_step_player)
	_last_pos = global_position


## Set the ground surface for footstep audio (called per maze by the game).
func set_footstep_surface(surface: String) -> void:
	_step_surface = surface
	_step_player.stream = FootstepForge.get_step(surface)


func _physics_process(_delta: float) -> void:
	if not active:
		velocity = Vector2.ZERO
		return
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var stick := _resolve_joystick()
	if stick != null:
		dir += stick.get_output()
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity = dir * speed
	move_and_slide()
	_update_footsteps()


func _update_footsteps() -> void:
	_stride_acc += global_position.distance_to(_last_pos)
	_last_pos = global_position
	if _stride_acc >= STRIDE_PX and velocity.length() > 10.0:
		_stride_acc = 0.0
		if _step_player.stream == null:
			set_footstep_surface(_step_surface)
		_step_player.pitch_scale = randf_range(0.92, 1.09)
		_step_player.play()


## Find the joystick lazily and cache it. Done here (not in _ready) because the
## joystick joins the "joystick" group in its own _ready, which may run after the
## player's. By the first physics frame every node is ready, so this is safe.
func _resolve_joystick() -> Node:
	if _joystick != null and is_instance_valid(_joystick):
		return _joystick
	for s in get_tree().get_nodes_in_group("joystick"):
		if s.has_method("get_output"):
			_joystick = s
			return _joystick
	return null


## Snap the player to a world position and stop motion.
func place_at(world_pos: Vector2) -> void:
	global_position = world_pos
	velocity = Vector2.ZERO
	_last_pos = world_pos       # avoid a teleport-sized stride on respawn
	_stride_acc = 0.0
