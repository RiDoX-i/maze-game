extends Control

## Friendly, themed backdrop drawn behind the maze (replaces the flat grey).
##
## A soft vertical gradient (coloured per difficulty theme) plus a few slowly
## drifting motes so the empty border around the maze feels alive instead of
## dead grey. Cheap: one stretched gradient texture + a handful of circles.

const MOTE_COUNT := 14

# Friendly top/bottom gradient colours per maze theme id.
const PALETTES := {
	"grove":    [Color("#8fd6ad"), Color("#2f6e57")],
	"cavern":   [Color("#5b82a6"), Color("#1d2e44")],
	"fortress": [Color("#d8b27a"), Color("#6e4f33")],
	"circuit":  [Color("#56b6ec"), Color("#16314f")],
	"frost":    [Color("#b4ddf2"), Color("#4a6e94")],
	"ember":    [Color("#f2ab63"), Color("#6e2f24")],
}

var _grad_tex: ImageTexture
var _motes: Array = []   ## [{pos:Vector2, vel:float, r:float, a:float}]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # smooth gradient
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()
	set_palette("grove")
	resized.connect(_seed_motes)
	_seed_motes()


## Recolour the backdrop for a maze theme id (see [MazeTheme]).
func set_palette(theme_id: String) -> void:
	var pair: Array = PALETTES.get(theme_id, PALETTES["grove"])
	_build_gradient(pair[0], pair[1])
	queue_redraw()


func _build_gradient(top: Color, bottom: Color) -> void:
	var h := 128
	var img := Image.create(1, h, false, Image.FORMAT_RGBA8)
	for y in h:
		img.set_pixel(0, y, top.lerp(bottom, float(y) / float(h - 1)))
	_grad_tex = ImageTexture.create_from_image(img)


func _seed_motes() -> void:
	_motes.clear()
	var area := size if size != Vector2.ZERO else Vector2(720, 1280)
	for _i in MOTE_COUNT:
		_motes.append({
			"pos": Vector2(_rng.randf() * area.x, _rng.randf() * area.y),
			"vel": _rng.randf_range(6.0, 18.0),
			"r": _rng.randf_range(1.5, 3.5),
			"a": _rng.randf_range(0.05, 0.18),
		})


func _process(delta: float) -> void:
	var area := size if size != Vector2.ZERO else Vector2(720, 1280)
	for mote in _motes:
		mote["pos"].y -= mote["vel"] * delta
		if mote["pos"].y < -4.0:
			mote["pos"] = Vector2(_rng.randf() * area.x, area.y + 4.0)
	queue_redraw()


func _draw() -> void:
	if _grad_tex != null:
		draw_texture_rect(_grad_tex, Rect2(Vector2.ZERO, size), false)
	for mote in _motes:
		draw_circle(mote["pos"], mote["r"], Color(1, 1, 1, mote["a"]))
