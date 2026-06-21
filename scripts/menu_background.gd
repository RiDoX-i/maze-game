extends Control

## Scrolling parallax backdrop for the main menu, so the whole world slides past
## under the running character (instead of a static image behind a moving floor).
## Layers, back to front: dusk sky gradient, twinkling stars, far hills, near
## hills, and a continuous ground strip the runner stands on. All procedural.

const RUNNER_X := 360.0      ## Mascot's fixed x (see main_menu.tscn).
const GROUND_Y := 780.0      ## Screen y of the ground surface (mascot's feet).
const SCROLL := 70.0         ## Base scroll speed (px/sec); layers scale this.
const STAR_COUNT := 70
const STAR_VWIDTH := 900.0   ## Virtual width the stars tile across.

var _grad: ImageTexture
var _stars: Array = []       ## [{x,y,phase}]
var _scroll := 0.0
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # smooth sky; rects unaffected
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 24681357
	_build_gradient()
	for _i in STAR_COUNT:
		_stars.append({
			"x": _rng.randf() * STAR_VWIDTH,
			"y": _rng.randf() * (GROUND_Y * 0.72),
			"phase": _rng.randf() * TAU,
		})


func _process(delta: float) -> void:
	_scroll += delta * SCROLL
	_time += delta
	queue_redraw()


func _build_gradient() -> void:
	var top := Color("#161033")
	var bottom := Color("#5b3a8c")   # warm purple horizon glow
	var h := 128
	var img := Image.create(1, h, false, Image.FORMAT_RGBA8)
	for y in h:
		img.set_pixel(0, y, top.lerp(bottom, float(y) / float(h - 1)))
	_grad = ImageTexture.create_from_image(img)


func _draw() -> void:
	# Sky.
	if _grad != null:
		draw_texture_rect(_grad, Rect2(0, 0, size.x, GROUND_Y), false)

	# Stars (slow drift + twinkle).
	for star in _stars:
		var sx := fposmod(float(star["x"]) - _scroll * 0.12, STAR_VWIDTH)
		if sx > size.x:
			continue
		var twinkle: float = 0.45 + 0.35 * sin(_time * 2.0 + float(star["phase"]))
		draw_rect(Rect2(sx, float(star["y"]), 2, 2), Color(0.85, 0.88, 1.0, twinkle))

	# Parallax hills.
	_draw_hills(120.0, 70.0, 60.0, 0.25, Color("#2e2358"), Color("#463a78"))
	_draw_hills(86.0, 130.0, 90.0, 0.55, Color("#20193f"), Color("#38305f"))

	# Ground strip with scrolling seams + a lit top edge.
	draw_rect(Rect2(0, GROUND_Y, size.x, size.y - GROUND_Y), Color("#2c2348"))
	draw_rect(Rect2(0, GROUND_Y, size.x, 5), Color("#4a3c6e"))
	var seam := 48.0
	var off := fposmod(_scroll, seam)
	var x := -off
	while x <= size.x:
		draw_line(Vector2(x, GROUND_Y), Vector2(x, size.y), Color("#191230"), 1.0)
		x += seam

	# Runner contact shadow.
	draw_circle(Vector2(RUNNER_X, GROUND_Y - 2.0), 34.0, Color(0, 0, 0, 0.28))


func _draw_hills(block_w: float, base_h: float, var_h: float, speed: float,
		body: Color, lit: Color) -> void:
	var off := fposmod(_scroll * speed, block_w)
	var x := -off
	while x <= size.x:
		var col := floori((x + _scroll * speed) / block_w)
		var noise := float(absi((col * 2654435761) ^ 0x9e3779b9) % 1000) / 1000.0
		var h := base_h + noise * var_h
		var top := GROUND_Y - h
		draw_rect(Rect2(x, top, block_w + 1.0, h), body)
		draw_rect(Rect2(x, top, block_w + 1.0, 4.0), lit)
		x += block_w
