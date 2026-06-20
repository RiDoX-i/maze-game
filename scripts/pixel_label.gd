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


func _text_width_px() -> int:
	return text.length() * PixelFont.advance() * pixel_scale


func _refresh() -> void:
	custom_minimum_size = Vector2(_text_width_px(), PixelFont.GH * pixel_scale)
	update_minimum_size()
	queue_redraw()


func _draw() -> void:
	var atlas := PixelFont.atlas()
	var total := _text_width_px()
	var x := 0.0
	match align:
		Align.CENTER:
			x = (size.x - total) * 0.5
		Align.RIGHT:
			x = size.x - total
	var step := PixelFont.advance() * pixel_scale
	for i in text.length():
		var src := PixelFont.glyph_rect(text[i])
		var dest := Rect2(x, 0, PixelFont.GW * pixel_scale, PixelFont.GH * pixel_scale)
		draw_texture_rect_region(atlas, dest, src, color)
		x += step
