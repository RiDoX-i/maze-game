extends Node2D

## Pixel-font speech bubble that floats above the player's head. Used for the
## occasional "I GUESS ITS THE WRONG PATH" hint. Draws in world space (child of
## the player) using the shared [PixelFont], so it stays crisp and pixelated and
## scales naturally with the camera.

const PX := 1.6              ## Size of one font pixel (world units).
const HEAD_OFFSET := 20.0    ## How far above the origin the bubble tail sits.
const PAD := 5.0
const LINE_GAP := 2.0

const BG := Color("#201a3a")
const BORDER := Color("#6c5cef")
const TEXT := Color("#fff3c4")

var _lines: PackedStringArray = []
var _time_left := 0.0
var _duration := 1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	z_index = 50


## Show [param text] (newlines split into lines) for [param seconds].
func say(text: String, seconds: float = 2.4) -> void:
	_lines = text.split("\n", false)
	_duration = seconds
	_time_left = seconds
	visible = true
	queue_redraw()


func is_active() -> bool:
	return _time_left > 0.0


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left -= delta
	# Gentle bob while shown; fade out over the last 0.5s.
	modulate.a = clampf(_time_left / 0.5, 0.0, 1.0)
	if _time_left <= 0.0:
		visible = false
	queue_redraw()


func _glyph_h() -> float:
	return PixelFont.GH * PX


func _line_w(line: String) -> float:
	return line.length() * PixelFont.advance() * PX


func _draw() -> void:
	if _lines.is_empty():
		return
	var widest := 0.0
	for line in _lines:
		widest = maxf(widest, _line_w(line))
	var inner_h := _lines.size() * _glyph_h() + (_lines.size() - 1) * LINE_GAP
	var box := Vector2(widest + PAD * 2.0, inner_h + PAD * 2.0)
	var top_left := Vector2(-box.x * 0.5, -HEAD_OFFSET - box.y)

	# Bubble body + chunky border + a little downward tail.
	var rect := Rect2(top_left, box)
	draw_rect(rect, BG, true)
	draw_rect(rect.grow(2.0), BORDER, false, 2.0)
	var tail_y := top_left.y + box.y
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, tail_y), Vector2(5, tail_y), Vector2(0, tail_y + 7.0),
	]), BG)

	# Text, line by line, centred.
	var atlas := PixelFont.atlas()
	var glyph_w := PixelFont.GW * PX
	var step := PixelFont.advance() * PX
	var y := top_left.y + PAD
	for line in _lines:
		var x := -_line_w(line) * 0.5
		for i in line.length():
			var src := PixelFont.glyph_rect(line[i])
			draw_texture_rect_region(atlas, Rect2(x, y, glyph_w, _glyph_h()), src, TEXT)
			x += step
		y += _glyph_h() + LINE_GAP
