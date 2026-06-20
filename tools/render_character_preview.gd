extends SceneTree

## Renders the character's animation frames to a PNG so the sprite can be
## eyeballed without launching the GPU.
## Run: godot --headless --path . --script res://tools/render_character_preview.gd

const CV := preload("res://scripts/character_visual.gd")

const S := 8           ## Upscale per fat-pixel.
const CW := 16         ## Panel width in fat-pixels.
const CH := 22         ## Panel height in fat-pixels.
const ORIGIN := Vector2i(7, 11)
const GAP := 6


func _initialize() -> void:
	# leg_frame, breath, label
	var frames := [[2, 0], [2, -1], [0, 0], [1, 0]]
	var pw := CW * S
	var ph := CH * S
	var sheet := Image.create(GAP + frames.size() * (pw + GAP), GAP * 2 + ph, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("#222634"))

	for i in frames.size():
		var f: Array = frames[i]
		var panel := _render_frame(f[0], f[1])
		sheet.blit_rect(panel, Rect2i(Vector2i.ZERO, panel.get_size()), Vector2i(GAP + i * (pw + GAP), GAP))

	var path := "res://assets/sprites/player/_character_preview.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/sprites/player"))
	sheet.save_png(path)
	print("character preview saved: ", path, " (", sheet.get_width(), "x", sheet.get_height(), ")")
	quit(0)


func _render_frame(leg_frame: int, breath: int) -> Image:
	var img := Image.create(CW * S, CH * S, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for e in CV.sprite_rects(leg_frame, breath):
		var rx: int = (ORIGIN.x + int(e[0])) * S
		var ry: int = (ORIGIN.y + int(e[1])) * S
		var rw: int = int(e[2]) * S
		var rh: int = int(e[3]) * S
		img.fill_rect(Rect2i(rx, ry, rw, rh), e[4])
	return img
