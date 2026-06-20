class_name TouchJoystick
extends Control

## Self-contained on-screen analog stick for touch movement.
##
## Lives in a CanvasLayer (screen space) and belongs to the "joystick" group so
## the player can find it. Reports a normalised Vector2 via [method get_output]
## (zero when idle). Works with mouse too (project enables touch-from-mouse) for
## desktop testing.

@export var radius: float = 90.0       ## Max knob travel from the base centre.
@export var dead_zone: float = 0.15    ## Outputs below this magnitude read as 0.

const COLOR_BASE := Color(1, 1, 1, 0.12)
const COLOR_KNOB := Color(1, 1, 1, 0.35)

var _output := Vector2.ZERO
var _touch_index := -1                 ## Active finger id, -1 = idle.
var _base_pos := Vector2.ZERO          ## Base centre, in local coords.
var _knob_pos := Vector2.ZERO


func _ready() -> void:
	add_to_group("joystick")
	_reset()


func get_output() -> Vector2:
	return _output


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_index = event.index
			_base_pos = event.position
			_knob_pos = event.position
			_update_output()
			queue_redraw()
		elif event.index == _touch_index:
			_reset()
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == _touch_index:
		_knob_pos = event.position
		var offset := _knob_pos - _base_pos
		if offset.length() > radius:
			offset = offset.normalized() * radius
			_knob_pos = _base_pos + offset
		_update_output()
		queue_redraw()


func _update_output() -> void:
	var offset := (_knob_pos - _base_pos) / radius
	if offset.length() < dead_zone:
		_output = Vector2.ZERO
	else:
		_output = offset


func _reset() -> void:
	_touch_index = -1
	_output = Vector2.ZERO
	# Park the visual at the bottom-left "home" position.
	_base_pos = Vector2(radius + 24.0, size.y - radius - 24.0)
	_knob_pos = _base_pos


func _draw() -> void:
	draw_circle(_base_pos, radius, COLOR_BASE)
	draw_circle(_knob_pos, radius * 0.45, COLOR_KNOB)
