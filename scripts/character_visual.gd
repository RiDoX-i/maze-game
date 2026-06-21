class_name CharacterVisual
extends Node2D

## Simple animated pixel-art character drawn procedurally (chunky "fat pixels",
## no texture needed). Yellow hair, blue shirt. Animates:
##   * idle  -> gentle head "breathing" bob
##   * moving -> faster body hop + alternating legs
##   * faces left/right based on travel direction
##
## The sprite layout is a data list (see [method sprite_rects]) so it can be
## rendered both to the canvas (here) and to a preview image (tools/).

const PX := 2.0   ## Size of one fat pixel.

const C_HAIR := Color("#ffd23f")
const C_HAIR_D := Color("#e0a91f")
const C_SKIN := Color("#f2c79b")
const C_EYE := Color("#20242e")
const C_SHIRT := Color("#3aa0d8")
const C_SHIRT_D := Color("#2b7fb0")
const C_PANTS := Color("#394150")
const C_SHOE := Color("#23272f")

## Force the running animation with no physics body (used by the main menu, where
## the character runs in place above a scrolling surface).
@export var auto_run := false

var _body: CharacterBody2D
var _t := 0.0
var _run := 0.0
var _facing := 1.0
var _leg_frame := 2   ## 0/1 = running strides, 2 = idle.
var _breath := 0      ## head bob offset (logical px).


func _ready() -> void:
	_body = get_parent() as CharacterBody2D
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	_t += delta
	var moving := false
	if auto_run:
		moving = true
		_facing = 1.0
	else:
		var speed := 0.0
		if _body != null:
			speed = _body.velocity.length()
			if absf(_body.velocity.x) > 8.0:
				_facing = signf(_body.velocity.x)
		moving = speed > 12.0

	if moving:
		_run += delta * 11.0
		_leg_frame = int(_run) % 2
		position.y = -absf(sin(_run * PI)) * PX   # body hop
		_breath = 0
	else:
		_leg_frame = 2
		position.y = 0.0
		_breath = -1 if sin(_t * 3.0) > 0.0 else 0

	scale.x = _facing
	queue_redraw()


func _draw() -> void:
	for e in sprite_rects(_leg_frame, _breath):
		draw_rect(Rect2(e[0] * PX, e[1] * PX, e[2] * PX, e[3] * PX), e[4], true)


## Sprite as a list of [lx, ly, w, h, Color] rects in logical fat-pixels,
## centred on the origin. [param leg_frame]: 0/1 strides, else idle.
static func sprite_rects(leg_frame: int, breath: int) -> Array:
	var r: Array = []
	var legs: Array
	match leg_frame:
		0: legs = [[-2, 4], [0, 3]]
		1: legs = [[-2, 3], [0, 4]]
		_: legs = [[-2, 4], [0, 4]]
	for l in legs:
		r.append([l[0], 1, 2, int(l[1]) - 1, C_PANTS])
		r.append([l[0], l[1], 2, 1, C_SHOE])

	r.append([-3, -3, 6, 4, C_SHIRT])     # torso
	r.append([2, -3, 1, 4, C_SHIRT_D])    # torso shade
	r.append([-4, -3, 1, 3, C_SKIN])      # left arm
	r.append([3, -3, 1, 3, C_SKIN])       # right arm

	r.append([-3, -5 + breath, 6, 2, C_SKIN])    # face
	r.append([-2, -4 + breath, 1, 1, C_EYE])     # eyes
	r.append([1, -4 + breath, 1, 1, C_EYE])
	r.append([-4, -7 + breath, 8, 2, C_HAIR])    # hair bangs
	r.append([-3, -8 + breath, 6, 1, C_HAIR])    # hair top
	r.append([-4, -5 + breath, 1, 1, C_HAIR_D])  # side locks
	r.append([3, -5 + breath, 1, 1, C_HAIR_D])
	return r
