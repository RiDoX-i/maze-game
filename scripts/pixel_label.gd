@tool
class_name PixelLabel
extends Control

## Draws a string with the built-in [PixelFont] at an integer scale, crisp and
## pixelated. Tintable, with left/centre/right alignment. Use anywhere a Label
## would go for UI text.

enum Align { LEFT, CENTER, RIGHT }

@export var text: String = "TEXT":
	set(v):
		text = v
		_refresh()
@export var color: Color = Color.WHITE:
	set(v):
		color = v
		queue_redraw()
@export var pixel_scale: int = 4:
	set(v):
		pixel_scale = maxi(v, 1)
		_refresh()
@export var align: Align = Align.LEFT:
	set(v):
		align = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_refresh()


func _line_width_px(line: String) -> int:
	return line.length() * PixelFont.advance() * pixel_scale


func _max_width_px() -> int:
	var widest := 0
	for line in text.split("\n"):
		widest = maxi(widest, _line_width_px(line))
	return widest


func _line_advance_px() -> int:
	# Glyph height plus a small inter-line gap (scales with the label).
	return PixelFont.GH * pixel_scale + pixel_scale


func _refresh() -> void:
	var lines := text.split("\n")
	var height := lines.size() * PixelFont.GH * pixel_scale + maxi(lines.size() - 1, 0) * pixel_scale
	custom_minimum_size = Vector2(_max_width_px(), height)
	update_minimum_size()
	queue_redraw()


func _draw() -> void:
	var atlas := PixelFont.atlas()
	var glyph := Vector2(PixelFont.GW * pixel_scale, PixelFont.GH * pixel_scale)
	var step := PixelFont.advance() * pixel_scale
	var y := 0.0
	for line in text.split("\n"):
		var total := _line_width_px(line)
		var x := 0.0
		match align:
			Align.CENTER:
				x = (size.x - total) * 0.5
			Align.RIGHT:
				x = size.x - total
		for i in line.length():
			var src := PixelFont.glyph_rect(line[i])
			draw_texture_rect_region(atlas, Rect2(x, y, glyph.x, glyph.y), src, color)
			x += step
		y += _line_advance_px()
