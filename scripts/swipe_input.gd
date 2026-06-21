class_name SwipeInput
extends Control

## Full-screen swipe detector for touch movement. Belongs to the "swipe_input"
## group so the player can find it, and emits [signal swiped] with a cardinal
## direction once a drag passes a small threshold. One swipe fires once; the
## finger must lift before another swipe registers. Works with the mouse too
## (the project emulates touch from mouse) for desktop testing.
##
## Sits below the HUD in the UI layer, so on-screen buttons (pause) still receive
## their taps — only the empty play area produces swipes.

signal swiped(dir: Vector2i)

@export var threshold: float = 40.0   ## Min drag distance (px) to count as a swipe.

var _touch_index := -1
var _start := Vector2.ZERO
var _fired := false


func _ready() -> void:
	add_to_group("swipe_input")
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_index = event.index
			_start = event.position
			_fired = false
		elif event.index == _touch_index:
			_touch_index = -1
			_fired = false
	elif event is InputEventScreenDrag and event.index == _touch_index and not _fired:
		var delta := event.position - _start
		if delta.length() >= threshold:
			_fired = true
			swiped.emit(_to_cardinal(delta))


## Dominant-axis cardinal direction of a drag vector.
static func _to_cardinal(delta: Vector2) -> Vector2i:
	if absf(delta.x) >= absf(delta.y):
		return Vector2i(1, 0) if delta.x > 0.0 else Vector2i(-1, 0)
	return Vector2i(0, 1) if delta.y > 0.0 else Vector2i(0, -1)
